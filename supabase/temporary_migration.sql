-- Migration temporaire — À COLLER TEL QUEL dans le SQL Editor Supabase.
-- (Fichier de travail régénéré à chaque tâche, voir CLAUDE.md.)
--
-- Objet : nouveaux effets spéciaux de capacité pour Combat Auto / Combat
-- Manuel / PvP —
--   • rythme des tours : « Joue 2 fois au prochain tour »
--     (turn_effect = 'charge_double_next') et « Passe premier et rejoue »
--     (turn_effect = 'first_and_replay') ;
--   • « Continue sur sa lancée » : la capacité se rejoue automatiquement
--     pendant N tours, avec un bonus de dégâts cumulatif (keep_going_*) ;
--   • bouclier « Prévention » : annule les dégâts additionnels dus à
--     l'efficacité de type pendant N tours (prevention_duration_turns) ;
--   • modificateur de dégâts restreint à un type de capacité
--     (stat_mod_type_filter) ;
--   • soin passif « jusqu'au réveil » (heal_dot_until_awake) ;
--   • capacité utilisable malgré sommeil/paralysie/gel (ignore_status_block).
--
-- Contient aussi deux corrections dans le moteur existant :
--   • le soin passif tique désormais aussi pendant un tour passé à dormir
--     (il ne tiquait que sur paralysie/gel) ;
--   • l'invulnérabilité (invulnerable_next_turn) n'était jamais accordée aux
--     capacités SANS effet de tour : la comparaison `turn_effect <>
--     'prepare_release'` vaut NULL quand turn_effect est NULL, ce qui rendait
--     la condition fausse. Remplacée par IS DISTINCT FROM.
--
-- Rejouable sans risque (idempotent).

-- ============================================================
-- 1. Nouvelles colonnes de configuration (autobattle_ability_rules)
-- ============================================================
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_turn_effect_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_turn_effect_check
  CHECK (turn_effect IS NULL OR turn_effect IN (
    'skip', 'play_twice', 'play_three', 'play_random', 'repeat_until_fail', 'prepare_release',
    'charge_double_next', 'first_and_replay'
  ));
-- Filtre de TYPE sur le modificateur de stat (stat_mod_*, uniquement pour
-- stat = 'damage') : NULL = le modificateur s'applique à toutes les capacités
-- (comportement historique), sinon il ne s'applique QUE lorsque la capacité
-- jouée est de ce type élémentaire (attacks.type, comparé sans casse ni
-- espaces superflus). C'est ce qui permet un buff du genre "+10 dégâts sur
-- les capacités Feu" : le montant reste flat/fourchette/% comme avant, seul
-- le champ d'application change. Le filtre voyage avec le modificateur ACTIF
-- (colonnes *_damage_mod_type_filter des tables d'état), pas avec la capacité
-- qui attaque — voir autobattle_resolve_round_core.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_type_filter text;

-- Bouclier "Prévention" : sur un coup réussi, protège son utilisateur des
-- dégâts ADDITIONNELS dus à l'efficacité de type (super efficace) pendant
-- prevention_duration_turns tours de combat (compteur global, comme
-- l'Anti-Soin). Concrètement, tant qu'il est actif, une attaque adverse qui
-- bénéficie du bonus de type retombe à ses dégâts normaux (le x2 sur la
-- composante espèce+XP est retiré) — le reste du coup (dé, dégâts de la
-- capacité, bonus conditionnels) est inchangé. Ce n'est donc PAS une
-- invulnérabilité : le coup touche toujours.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS prevention_duration_turns integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_prevention_duration_turns_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_prevention_duration_turns_check
  CHECK (prevention_duration_turns IS NULL OR prevention_duration_turns >= 1);

-- "Continue sur sa lancée" : une fois utilisée, la capacité est
-- automatiquement REJOUÉE pendant keep_going_turns tours supplémentaires de
-- son utilisateur (le joueur ne choisit plus rien pendant ce temps en Combat
-- Manuel/PvP, la capacité est forcée — voir le champ player_forced_ability_nom
-- renvoyé par autobattle_resolve_manual_round). Chaque réutilisation ajoute un
-- bonus de dégâts CUMULATIF : la 1ère utilisation n'en a aucun, la 2e en a un,
-- la 3e le double, etc. Le bonus unitaire est soit un montant fixe
-- (keep_going_bonus_type = 'flat'), soit un pourcentage des dégâts de base de
-- son utilisateur ('percent_damage'). La chaîne s'interrompt au premier RATÉ
-- (précision manquée, ou cible invulnérable) : la capacité cesse alors d'être
-- imposée et le tour suivant redevient un choix libre.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS keep_going_turns integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS keep_going_bonus_type text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS keep_going_bonus_flat integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS keep_going_bonus_percent integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_keep_going_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_keep_going_fields
  CHECK (
    keep_going_turns IS NULL
    OR (
      keep_going_turns >= 1
      AND (keep_going_bonus_type IS NULL OR keep_going_bonus_type IN ('flat', 'percent_damage'))
      AND (keep_going_bonus_type <> 'flat' OR keep_going_bonus_flat IS NOT NULL)
      AND (keep_going_bonus_type <> 'percent_damage' OR (keep_going_bonus_percent IS NOT NULL AND keep_going_bonus_percent >= 1))
    )
  );

-- Soin passif "jusqu'au réveil" : au lieu d'une durée en tours, l'effet dure
-- tant que son utilisateur est ENDORMI (statut 'sleep') et s'éteint au tour
-- où il se réveille (ce tour-là ne soigne plus). Typiquement combiné avec un
-- statut inversé Sommeil sur la même capacité (genre "Repos"). Exclusif de
-- heal_dot_duration_turns, qui reste NULL dans ce cas.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS heal_dot_until_awake boolean NOT NULL DEFAULT false;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_heal_dot_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_heal_dot_fields
  CHECK (
    (heal_dot_type IS NULL AND heal_dot_amount IS NULL AND heal_dot_percent IS NULL AND heal_dot_duration_turns IS NULL)
    OR (
      (
        (heal_dot_until_awake AND heal_dot_duration_turns IS NULL)
        OR (NOT heal_dot_until_awake AND heal_dot_duration_turns IS NOT NULL AND heal_dot_duration_turns >= 1)
      )
      AND (
        ((heal_dot_type IS NULL OR heal_dot_type = 'flat') AND heal_dot_amount IS NOT NULL AND heal_dot_amount > 0 AND heal_dot_percent IS NULL)
        OR (heal_dot_type IN ('percent_max_hp', 'percent_damage') AND heal_dot_percent IS NOT NULL AND heal_dot_percent >= 1 AND heal_dot_percent <= 100 AND heal_dot_amount IS NULL)
      )
    )
  );

-- Capacité utilisable malgré UN statut bloquant précis (genre "Ronflement",
-- utilisable en dormant mais pas en étant paralysé) : NULL = désactivé,
-- sinon 'paralysis', 'sleep' ou 'frozen' — et seul CE statut-là cesse de
-- faire passer le tour de son utilisateur, les deux autres continuent de le
-- bloquer normalement. Le tick de statut a quand même lieu — paralysie/gel se
-- dissipent après ce tour, le sommeil garde son dé de réveil. La brûlure et
-- le poison ne sont pas concernés : ils n'ont jamais bloqué le tour.
-- Première version de cet effet : un booléen couvrant les 3 statuts d'un coup.
-- Converti ici (la colonne n'a jamais porté de configuration utile sous cette
-- forme) plutôt que migré, mais uniquement si elle est encore booléenne —
-- rejouer ce fichier sur une base à jour ne doit rien effacer.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'autobattle_ability_rules' AND column_name = 'ignore_status_block'
      AND data_type = 'boolean'
  ) THEN
    ALTER TABLE autobattle_ability_rules DROP COLUMN ignore_status_block;
  END IF;
END $$;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS ignore_status_block text;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_ignore_status_block_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_ignore_status_block_check
  CHECK (ignore_status_block IS NULL OR ignore_status_block IN ('paralysis', 'sleep', 'frozen'));

-- ============================================================
-- 2. Nouvelles colonnes d'état de combat (une par camp et par mode)
-- ============================================================
-- État persisté des effets ajoutés après coup (voir autobattle_ability_rules
-- et autobattle_combatant_state, dont ces colonnes sont le miroir côté
-- Combat Manuel) : double tour en attente (turn_effect 'charge_double_next'),
-- bouclier Prévention, filtre de type du modificateur de dégâts actif, soin
-- passif "jusqu'au réveil", et chaîne "Continue sur sa lancée" (capacité
-- verrouillée + compteurs).
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_double_turn_pending boolean NOT NULL DEFAULT false;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_double_turn_pending boolean NOT NULL DEFAULT false;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_prevention_expires integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_prevention_expires integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_damage_mod_type_filter text;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_damage_mod_type_filter text;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_heal_dot_until_awake boolean NOT NULL DEFAULT false;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_heal_dot_until_awake boolean NOT NULL DEFAULT false;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_keep_going_ability_nom text;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_keep_going_ability_nom text;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_keep_going_remaining integer NOT NULL DEFAULT 0;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_keep_going_remaining integer NOT NULL DEFAULT 0;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_keep_going_count integer NOT NULL DEFAULT 0;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_keep_going_count integer NOT NULL DEFAULT 0;

-- Mêmes colonnes d'état ajoutées après coup que sur autobattle_manual_battles
-- (voir le commentaire là-bas) : double tour en attente, bouclier Prévention,
-- filtre de type du modificateur de dégâts, soin passif "jusqu'au réveil" et
-- chaîne "Continue sur sa lancée".
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_double_turn_pending boolean NOT NULL DEFAULT false;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_double_turn_pending boolean NOT NULL DEFAULT false;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_prevention_expires integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_prevention_expires integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_damage_mod_type_filter text;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_damage_mod_type_filter text;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_heal_dot_until_awake boolean NOT NULL DEFAULT false;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_heal_dot_until_awake boolean NOT NULL DEFAULT false;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_keep_going_ability_nom text;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_keep_going_ability_nom text;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_keep_going_remaining integer NOT NULL DEFAULT 0;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_keep_going_remaining integer NOT NULL DEFAULT 0;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_keep_going_count integer NOT NULL DEFAULT 0;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_keep_going_count integer NOT NULL DEFAULT 0;

-- Mêmes colonnes d'état ajoutées après coup que sur pvp_battles / autobattle_
-- manual_battles (voir le commentaire là-bas).
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_double_turn_pending boolean NOT NULL DEFAULT false;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_double_turn_pending boolean NOT NULL DEFAULT false;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_prevention_expires integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_prevention_expires integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_damage_mod_type_filter text;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_damage_mod_type_filter text;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_heal_dot_until_awake boolean NOT NULL DEFAULT false;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_heal_dot_until_awake boolean NOT NULL DEFAULT false;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_keep_going_ability_nom text;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_keep_going_ability_nom text;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_keep_going_remaining integer NOT NULL DEFAULT 0;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_keep_going_remaining integer NOT NULL DEFAULT 0;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_keep_going_count integer NOT NULL DEFAULT 0;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_keep_going_count integer NOT NULL DEFAULT 0;
ALTER TABLE pvp_trial_battles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read pvp_trial_battles" ON pvp_trial_battles;
CREATE POLICY "Public read pvp_trial_battles" ON pvp_trial_battles FOR SELECT TO anon USING (true);
DROP POLICY IF EXISTS "Public insert pvp_trial_battles" ON pvp_trial_battles;
CREATE POLICY "Public insert pvp_trial_battles" ON pvp_trial_battles FOR INSERT TO anon WITH CHECK (true);
DROP POLICY IF EXISTS "Public update pvp_trial_battles" ON pvp_trial_battles;
CREATE POLICY "Public update pvp_trial_battles" ON pvp_trial_battles FOR UPDATE TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Public delete pvp_trial_battles" ON pvp_trial_battles;
CREATE POLICY "Public delete pvp_trial_battles" ON pvp_trial_battles FOR DELETE TO anon USING (true);

-- ============================================================
-- 3. Types partagés du moteur de résolution
-- (DROP ... CASCADE supprime au passage autobattle_resolve_round_core, qui est
-- recréée juste après — les autres fonctions ne dépendent du type que dans
-- leur corps plpgsql, jamais dans leur signature.)
-- ============================================================
DROP TYPE IF EXISTS autobattle_combatant_state CASCADE;
CREATE TYPE autobattle_combatant_state AS (
  hp                     integer,
  max_hp                 integer,
  status                 text,
  damage_mod_amount      integer,
  damage_mod_expires     integer,
  precision_mod_amount   integer,
  precision_mod_expires  integer,
  heal_dot_amount        integer,
  heal_dot_expires       integer,
  heal_disabled_expires  integer,
  invulnerable           boolean,
  invuln_granted_round   integer,
  stat_mod_uses          jsonb,
  used_ability           boolean,
  took_damage            boolean,
  skip_pending           boolean,
  preparing              boolean,
  preparing_ability_nom  text,
  -- Effets ajoutés après coup (voir autobattle_ability_rules) :
  -- double_turn_pending  = 'charge_double_next' a été chargé au tour précédent,
  --                        le prochain tour de ce camp joue deux fois.
  -- prevention_expires   = bouclier Prévention actif jusqu'à ce numéro de round.
  -- damage_mod_type_filter = type élémentaire auquel le modificateur de dégâts
  --                        actif est restreint (NULL = toutes les capacités).
  -- heal_dot_until_awake = le soin passif actif dure "jusqu'au réveil" au lieu
  --                        d'un nombre de tours (heal_dot_expires reste NULL).
  -- keep_going_*         = chaîne "Continue sur sa lancée" en cours : capacité
  --                        verrouillée, nombre de réutilisations forcées qu'il
  --                        reste, et numéro de l'utilisation en cours (1 = la
  --                        première, sans bonus).
  double_turn_pending    boolean,
  prevention_expires     integer,
  damage_mod_type_filter text,
  heal_dot_until_awake   boolean,
  keep_going_ability_nom text,
  keep_going_remaining   integer,
  keep_going_count       integer
);

-- Capacité effectivement jouée ce round par un camp (résolue par l'appelant :
-- espèce/instantané + attacks + autobattle_ability_rules) — le type_bonus
-- (avantage de type) est déjà appliqué dans base_damage par l'appelant, pas
-- recalculé ici (voir autobattle_resolve_manual_round/pvp_resolve_round).
-- Le champ type_bonus ci-dessous permet toutefois de le RETIRER pour
-- heal_type='use_stats' (voir plus bas) : un soin basé sur les stats ne doit
-- jamais être doublé par l'efficacité de type, contrairement aux dégâts.
DROP TYPE IF EXISTS autobattle_combatant_ability CASCADE;
CREATE TYPE autobattle_combatant_ability AS (
  ability_nom                text,
  base_damage                integer, -- dégâts avant dé (espèce/instantané + bonus XP, ×2 si type favorable, + dégâts de base de la capacité)
  damage_species_xp          integer, -- composante espèce+XP seule (détail du calcul, voir AutoBattleTurn.damage_species_xp)
  type_bonus                 boolean, -- ce camp est-il en efficacité de type favorable (×2 déjà inclus dans base_damage) ? sert uniquement à le retirer pour heal_type='use_stats'
  precision                  integer,
  degats_de                  integer,
  deals_damage               boolean,
  status_effect               text,
  status_chance               integer,
  turn_effect                 text,
  repeat_max                  integer,
  heal_type                   text,
  heal_amount                 integer,
  heal_percent                 integer,
  status_reversed              boolean,
  recoil_type                  text,
  recoil_min                   integer,
  recoil_max                   integer,
  recoil_percent                integer,
  invuln_grant                  boolean,
  bonus_type                    text,
  bonus_multiplier              numeric,
  bonus_flat                    integer,
  bonus_min                     integer,
  bonus_max                     integer,
  bonus_condition                text,
  bonus_dice_value               integer,
  bonus_status_filter            text,
  stat_mod_target                 text,
  stat_mod_stat                   text,
  stat_mod_value_type             text,
  stat_mod_flat                   integer,
  stat_mod_min                    integer,
  stat_mod_max                    integer,
  stat_mod_percent                integer,
  stat_mod_duration_type          text,
  stat_mod_duration_turns         integer,
  stat_mod_max_uses               integer,
  heal_dot_config_amount          integer,
  heal_dot_config_turns           integer,
  heal_dot_config_type            text,
  heal_dot_config_percent         integer,
  cancel_heal_duration            integer,
  percent_hp_damage_percent       integer,
  -- Type élémentaire de la capacité (attacks.type) — sert au filtre de type
  -- du modificateur de dégâts (stat_mod_type_filter), pas au bonus super
  -- efficace (déjà résolu en amont par l'appelant, voir type_bonus).
  ability_type                    text,
  stat_mod_type_filter            text,
  prevention_duration             integer,
  keep_going_turns                integer,
  keep_going_bonus_type           text,
  keep_going_bonus_flat           integer,
  keep_going_bonus_percent        integer,
  heal_dot_until_awake            boolean,
  -- Statut bloquant (un seul) que cette capacité ignore — voir
  -- autobattle_ability_rules.ignore_status_block.
  ignore_status_block             text
);

DROP TYPE IF EXISTS autobattle_round_result CASCADE;
CREATE TYPE autobattle_round_result AS (
  player_state    autobattle_combatant_state,
  opponent_state  autobattle_combatant_state,
  turns           jsonb,
  outcome         text,
  turn_no         integer,
  round_no        integer,
  -- Camp qui doit agir en PREMIER au round suivant : normalement identique à
  -- p_first_attacker, sauf quand un camp a gagné une action supplémentaire
  -- ('charge_double_next' libéré, ou 'first_and_replay') — il reprend alors la
  -- main dès le début du round suivant, ce qui lui donne deux actions
  -- consécutives sans que l'adversaire ne joue entre les deux. L'appelant doit
  -- persister cette valeur dans sa colonne first_attacker.
  next_first_attacker text
);

-- ============================================================
-- 4. Moteur de résolution partagé (Combat Manuel + PvP + essai PvP)
-- ============================================================
CREATE OR REPLACE FUNCTION autobattle_resolve_round_core(
  p_turn_no integer,
  p_round_no integer,
  p_first_attacker text, -- 'player' | 'opponent' — qui agit en premier CE round
  p_player autobattle_combatant_state,
  p_opponent autobattle_combatant_state,
  p_player_ability autobattle_combatant_ability,
  p_opponent_ability autobattle_combatant_ability,
  p_precision_enabled boolean
)
RETURNS autobattle_round_result
LANGUAGE plpgsql
AS $$
DECLARE
  v_player   autobattle_combatant_state := p_player;
  v_opponent autobattle_combatant_state := p_opponent;
  v_turn_no  integer := p_turn_no;
  v_round_no integer := p_round_no;
  v_attacker text;
  v_flips integer := 0;
  v_block_remaining integer;
  v_turn_entry jsonb;
  v_turns jsonb := '[]'::jsonb;
  v_outcome text;
  v_hit_dice integer;
  v_hit_damage integer;
  v_heal_amt integer;
  v_heal_dice integer;
  v_recoil_amt integer;
  v_missed boolean;
  v_status_roll integer;
  v_status_cured boolean;
  v_status_precision_penalty integer := 0;
  v_bonus_condition_met boolean;
  v_percent_hp_damage_applied boolean;
  v_player_never_miss boolean := p_player_ability.precision IS NULL OR p_player_ability.precision = 0;
  v_opponent_never_miss boolean := p_opponent_ability.precision IS NULL OR p_opponent_ability.precision = 0;
  v_stat_mod_amount integer;
  v_stat_mod_expiry integer;
  v_stat_mod_key text;
  v_stat_mod_uses_used_for_key integer;
  v_result autobattle_round_result;
  -- Camp qui reprendra la main au round suivant (voir autobattle_round_result.
  -- next_first_attacker) — inchangé sauf action supplémentaire accordée.
  v_next_first text := p_first_attacker;
  -- La capacité de CE tour ignore-t-elle paralysie/gel/sommeil (voir
  -- autobattle_ability_rules.ignore_status_block) ? Recalculé à chaque tour
  -- pour le camp qui agit.
  v_ignore_block boolean;
  -- Action supplémentaire due au camp (libération d'un 'charge_double_next'
  -- ou 'first_and_replay') : purement local au round, toujours consommée avant
  -- de rendre la main, d'où l'absence de colonne persistée. v_*_extra_used
  -- plafonne à UNE action supplémentaire par camp et par round — sans quoi une
  -- capacité 'first_and_replay' rejouée à l'identique (capacité fixe côté
  -- adversaire) boucler ait indéfiniment.
  v_player_owed boolean := false;
  v_opponent_owed boolean := false;
  v_player_extra_used boolean := false;
  v_opponent_extra_used boolean := false;
  -- Modificateur de dégâts effectivement appliqué ce coup-ci : 0 si un filtre
  -- de type est actif et que la capacité jouée n'est pas de ce type.
  v_damage_mod_applied integer;
  -- Ce coup a-t-il vu son bonus super efficace annulé par la Prévention de la
  -- cible (voir autobattle_ability_rules.prevention_duration_turns) ?
  v_prevention_blocked boolean;
  -- Bonus cumulatif de la chaîne "Continue sur sa lancée" pour ce coup.
  v_keep_going_bonus integer;
BEGIN
  -- Expiration pré-boucle des modificateurs (comparés au numéro de TOUR) —
  -- voir le même commentaire dans l'ancienne autobattle_resolve_manual_round :
  -- vérifiée une 1ère fois ici (avant tout nouveau round_no), puis re-vérifiée
  -- à l'identique en tête de boucle (round_no a pu changer entretemps).
  IF v_player.damage_mod_expires IS NOT NULL AND v_round_no > v_player.damage_mod_expires THEN
    v_player.damage_mod_amount := 0; v_player.damage_mod_expires := NULL; v_player.damage_mod_type_filter := NULL;
  END IF;
  IF v_player.precision_mod_expires IS NOT NULL AND v_round_no > v_player.precision_mod_expires THEN
    v_player.precision_mod_amount := 0; v_player.precision_mod_expires := NULL;
  END IF;
  IF v_opponent.damage_mod_expires IS NOT NULL AND v_round_no > v_opponent.damage_mod_expires THEN
    v_opponent.damage_mod_amount := 0; v_opponent.damage_mod_expires := NULL; v_opponent.damage_mod_type_filter := NULL;
  END IF;
  IF v_opponent.precision_mod_expires IS NOT NULL AND v_round_no > v_opponent.precision_mod_expires THEN
    v_opponent.precision_mod_amount := 0; v_opponent.precision_mod_expires := NULL;
  END IF;
  IF v_player.heal_dot_expires IS NOT NULL AND v_round_no > v_player.heal_dot_expires THEN
    v_player.heal_dot_amount := NULL; v_player.heal_dot_expires := NULL;
  END IF;
  IF v_opponent.heal_dot_expires IS NOT NULL AND v_round_no > v_opponent.heal_dot_expires THEN
    v_opponent.heal_dot_amount := NULL; v_opponent.heal_dot_expires := NULL;
  END IF;
  IF v_player.heal_disabled_expires IS NOT NULL AND v_round_no > v_player.heal_disabled_expires THEN
    v_player.heal_disabled_expires := NULL;
  END IF;
  IF v_opponent.heal_disabled_expires IS NOT NULL AND v_round_no > v_opponent.heal_disabled_expires THEN
    v_opponent.heal_disabled_expires := NULL;
  END IF;
  IF v_player.prevention_expires IS NOT NULL AND v_round_no > v_player.prevention_expires THEN
    v_player.prevention_expires := NULL;
  END IF;
  IF v_opponent.prevention_expires IS NOT NULL AND v_round_no > v_opponent.prevention_expires THEN
    v_opponent.prevention_expires := NULL;
  END IF;
  -- Soin passif "jusqu'au réveil" : s'éteint dès que son propriétaire n'est
  -- plus endormi (le tour du réveil lui-même ne soigne donc pas, voir la
  -- condition de tick plus bas qui exige déjà status = 'sleep').
  IF COALESCE(v_player.heal_dot_until_awake, false) AND COALESCE(v_player.status, '') <> 'sleep' THEN
    v_player.heal_dot_amount := NULL; v_player.heal_dot_until_awake := false;
  END IF;
  IF COALESCE(v_opponent.heal_dot_until_awake, false) AND COALESCE(v_opponent.status, '') <> 'sleep' THEN
    v_opponent.heal_dot_amount := NULL; v_opponent.heal_dot_until_awake := false;
  END IF;

  v_attacker := p_first_attacker;
  v_block_remaining := NULL;

  LOOP
    v_turn_no := v_turn_no + 1;
    IF v_block_remaining IS NULL THEN
      v_round_no := v_round_no + 1;
    END IF;

    IF v_player.invulnerable AND v_player.invuln_granted_round IS NOT NULL AND v_round_no > v_player.invuln_granted_round + 1 THEN
      v_player.invulnerable := false; v_player.invuln_granted_round := NULL;
    END IF;
    IF v_opponent.invulnerable AND v_opponent.invuln_granted_round IS NOT NULL AND v_round_no > v_opponent.invuln_granted_round + 1 THEN
      v_opponent.invulnerable := false; v_opponent.invuln_granted_round := NULL;
    END IF;

    IF v_player.damage_mod_expires IS NOT NULL AND v_round_no > v_player.damage_mod_expires THEN
      v_player.damage_mod_amount := 0; v_player.damage_mod_expires := NULL; v_player.damage_mod_type_filter := NULL;
    END IF;
    IF v_player.precision_mod_expires IS NOT NULL AND v_round_no > v_player.precision_mod_expires THEN
      v_player.precision_mod_amount := 0; v_player.precision_mod_expires := NULL;
    END IF;
    IF v_opponent.damage_mod_expires IS NOT NULL AND v_round_no > v_opponent.damage_mod_expires THEN
      v_opponent.damage_mod_amount := 0; v_opponent.damage_mod_expires := NULL; v_opponent.damage_mod_type_filter := NULL;
    END IF;
    IF v_opponent.precision_mod_expires IS NOT NULL AND v_round_no > v_opponent.precision_mod_expires THEN
      v_opponent.precision_mod_amount := 0; v_opponent.precision_mod_expires := NULL;
    END IF;
    IF v_player.heal_dot_expires IS NOT NULL AND v_round_no > v_player.heal_dot_expires THEN
      v_player.heal_dot_amount := NULL; v_player.heal_dot_expires := NULL;
    END IF;
    IF v_opponent.heal_dot_expires IS NOT NULL AND v_round_no > v_opponent.heal_dot_expires THEN
      v_opponent.heal_dot_amount := NULL; v_opponent.heal_dot_expires := NULL;
    END IF;
    IF v_player.heal_disabled_expires IS NOT NULL AND v_round_no > v_player.heal_disabled_expires THEN
      v_player.heal_disabled_expires := NULL;
    END IF;
    IF v_opponent.heal_disabled_expires IS NOT NULL AND v_round_no > v_opponent.heal_disabled_expires THEN
      v_opponent.heal_disabled_expires := NULL;
    END IF;
    IF v_player.prevention_expires IS NOT NULL AND v_round_no > v_player.prevention_expires THEN
      v_player.prevention_expires := NULL;
    END IF;
    IF v_opponent.prevention_expires IS NOT NULL AND v_round_no > v_opponent.prevention_expires THEN
      v_opponent.prevention_expires := NULL;
    END IF;
    IF COALESCE(v_player.heal_dot_until_awake, false) AND COALESCE(v_player.status, '') <> 'sleep' THEN
      v_player.heal_dot_amount := NULL; v_player.heal_dot_until_awake := false;
    END IF;
    IF COALESCE(v_opponent.heal_dot_until_awake, false) AND COALESCE(v_opponent.status, '') <> 'sleep' THEN
      v_opponent.heal_dot_amount := NULL; v_opponent.heal_dot_until_awake := false;
    END IF;

    IF v_attacker = 'player' THEN
      v_opponent.took_damage := false;
    ELSE
      v_player.took_damage := false;
    END IF;

    IF v_block_remaining IS NULL THEN
      v_status_precision_penalty := 0;
      -- Capacité utilisable malgré UN statut bloquant précis (voir
      -- autobattle_ability_rules.ignore_status_block) : vrai uniquement si le
      -- statut dont souffre le camp qui agit est EXACTEMENT celui configuré —
      -- une capacité "utilisable en dormant" reste bloquée par la paralysie.
      -- NULL des deux côtés (pas de statut, ou effet non configuré) donne NULL,
      -- ramené à faux.
      v_ignore_block := COALESCE(
        (CASE WHEN v_attacker = 'player' THEN p_player_ability.ignore_status_block ELSE p_opponent_ability.ignore_status_block END)
          = (CASE WHEN v_attacker = 'player' THEN v_player.status ELSE v_opponent.status END),
        false);

      IF v_attacker = 'player' AND v_player.status IN ('paralysis', 'frozen') THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', NOT v_ignore_block,
          'status_tick', true, 'status', v_player.status, 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
        ));
        v_player.status := NULL;
        IF NOT v_ignore_block THEN
          -- Paralysie/gel n'empêchent QUE l'usage de la capacité : les effets
          -- passifs (soin par tour) doivent quand même tiquer avant de rendre
          -- la main, sinon un tour sauté annulerait aussi le passif.
          IF v_player.heal_dot_amount IS NOT NULL
             AND (v_player.heal_disabled_expires IS NULL OR v_round_no > v_player.heal_disabled_expires) THEN
            v_player.hp := LEAST(v_player.max_hp, v_player.hp + v_player.heal_dot_amount);
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_player.heal_dot_amount,
              'attacker_hp_after', v_player.hp, 'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
            ));
          END IF;
          v_attacker := 'opponent';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;
        -- ignore_status_block : on enchaîne sur le tour normal (le tick de
        -- soin passif générique plus bas s'applique comme d'habitude).
      ELSIF v_attacker = 'opponent' AND v_opponent.status IN ('paralysis', 'frozen') THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', NOT v_ignore_block,
          'status_tick', true, 'status', v_opponent.status, 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
        ));
        v_opponent.status := NULL;
        IF NOT v_ignore_block THEN
          -- idem côté adverse : le passif tique malgré le tour sauté.
          IF v_opponent.heal_dot_amount IS NOT NULL
             AND (v_opponent.heal_disabled_expires IS NULL OR v_round_no > v_opponent.heal_disabled_expires) THEN
            v_opponent.hp := LEAST(v_opponent.max_hp, v_opponent.hp + v_opponent.heal_dot_amount);
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_opponent.heal_dot_amount,
              'attacker_hp_after', v_opponent.hp, 'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
            ));
          END IF;
          v_attacker := 'player';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;

      ELSIF v_attacker = 'player' AND v_player.status = 'sleep' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', NOT v_status_cured AND NOT v_ignore_block,
          'status_tick', true, 'status', 'sleep', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
        ));
        IF v_status_cured THEN
          v_player.status := NULL;
        ELSIF NOT v_ignore_block THEN
          -- Le soin passif tique aussi pendant le sommeil (même raison que
          -- paralysie/gel ci-dessus) — c'est ce qui rend possible un soin
          -- passif "jusqu'au réveil", qui ne tique par définition QUE sur des
          -- tours passés à dormir.
          IF v_player.heal_dot_amount IS NOT NULL
             AND (v_player.heal_disabled_expires IS NULL OR v_round_no > v_player.heal_disabled_expires) THEN
            v_player.hp := LEAST(v_player.max_hp, v_player.hp + v_player.heal_dot_amount);
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_player.heal_dot_amount,
              'attacker_hp_after', v_player.hp, 'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
            ));
          END IF;
          v_attacker := 'opponent';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent.status = 'sleep' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', NOT v_status_cured AND NOT v_ignore_block,
          'status_tick', true, 'status', 'sleep', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
        ));
        IF v_status_cured THEN
          v_opponent.status := NULL;
        ELSIF NOT v_ignore_block THEN
          IF v_opponent.heal_dot_amount IS NOT NULL
             AND (v_opponent.heal_disabled_expires IS NULL OR v_round_no > v_opponent.heal_disabled_expires) THEN
            v_opponent.hp := LEAST(v_opponent.max_hp, v_opponent.hp + v_opponent.heal_dot_amount);
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_opponent.heal_dot_amount,
              'attacker_hp_after', v_opponent.hp, 'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
            ));
          END IF;
          v_attacker := 'player';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;

      ELSIF v_attacker = 'player' AND v_player.status = 'burn' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_player.hp := v_player.hp - 5;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 5, 'skipped', false,
          'status_tick', true, 'status', 'burn', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'attacker_hp_after', GREATEST(0, v_player.hp), 'defender_hp_after', GREATEST(0, v_opponent.hp),
          'ko', v_player.hp <= 0
        ));
        IF v_status_cured THEN v_player.status := NULL; END IF;
        IF v_player.hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent.status = 'burn' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_opponent.hp := v_opponent.hp - 5;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 5, 'skipped', false,
          'status_tick', true, 'status', 'burn', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'attacker_hp_after', GREATEST(0, v_opponent.hp), 'defender_hp_after', GREATEST(0, v_player.hp),
          'ko', v_opponent.hp <= 0
        ));
        IF v_status_cured THEN v_opponent.status := NULL; END IF;
        IF v_opponent.hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;

      ELSIF v_attacker = 'player' AND v_player.status = 'poison' THEN
        v_player.hp := v_player.hp - 3;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 3, 'skipped', false,
          'status_tick', true, 'status', 'poison', 'status_cured', false,
          'attacker_hp_after', GREATEST(0, v_player.hp), 'defender_hp_after', GREATEST(0, v_opponent.hp),
          'ko', v_player.hp <= 0
        ));
        IF v_player.hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent.status = 'poison' THEN
        v_opponent.hp := v_opponent.hp - 3;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 3, 'skipped', false,
          'status_tick', true, 'status', 'poison', 'status_cured', false,
          'attacker_hp_after', GREATEST(0, v_opponent.hp), 'defender_hp_after', GREATEST(0, v_player.hp),
          'ko', v_opponent.hp <= 0
        ));
        IF v_opponent.hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;

      ELSIF v_attacker = 'player' AND v_player.status = 'fear' THEN
        v_status_precision_penalty := 5;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
          'status_tick', true, 'status', 'fear', 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
        ));
        v_player.status := NULL;
      ELSIF v_attacker = 'opponent' AND v_opponent.status = 'fear' THEN
        v_status_precision_penalty := 5;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
          'status_tick', true, 'status', 'fear', 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
        ));
        v_opponent.status := NULL;

      ELSIF v_attacker = 'player' AND v_player.status = 'confusion' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
          'status_tick', true, 'status', 'confusion', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
        ));
        IF v_status_cured THEN v_player.status := NULL; ELSE v_status_precision_penalty := 5; END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent.status = 'confusion' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
          'status_tick', true, 'status', 'confusion', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
        ));
        IF v_status_cured THEN v_opponent.status := NULL; ELSE v_status_precision_penalty := 5; END IF;
      END IF;

      IF v_attacker = 'player' AND v_player.heal_dot_amount IS NOT NULL
         AND (NOT COALESCE(v_player.heal_dot_until_awake, false) OR COALESCE(v_player.status, '') = 'sleep')
         AND (v_player.heal_disabled_expires IS NULL OR v_round_no > v_player.heal_disabled_expires) THEN
        v_player.hp := LEAST(v_player.max_hp, v_player.hp + v_player.heal_dot_amount);
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
          'heal_dot_tick', true, 'heal', v_player.heal_dot_amount,
          'attacker_hp_after', v_player.hp, 'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
        ));
        IF v_player.status = 'poison' THEN v_player.status := NULL; END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent.heal_dot_amount IS NOT NULL
         AND (NOT COALESCE(v_opponent.heal_dot_until_awake, false) OR COALESCE(v_opponent.status, '') = 'sleep')
         AND (v_opponent.heal_disabled_expires IS NULL OR v_round_no > v_opponent.heal_disabled_expires) THEN
        v_opponent.hp := LEAST(v_opponent.max_hp, v_opponent.hp + v_opponent.heal_dot_amount);
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
          'heal_dot_tick', true, 'heal', v_opponent.heal_dot_amount,
          'attacker_hp_after', v_opponent.hp, 'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
        ));
        IF v_opponent.status = 'poison' THEN v_opponent.status := NULL; END IF;
      END IF;

      -- Chaîne "Continue sur sa lancée" (voir autobattle_ability_rules.
      -- keep_going_turns) : la capacité s'auto-rejoue pendant X tours de son
      -- utilisateur. Le compteur avance ICI, sur toute activation réellement
      -- jouée (touchée OU ratée — l'enchaînement est forcé, un raté ne le
      -- casse pas), mais jamais sur un tour purement passé (statut bloquant),
      -- qui sort de la boucle plus haut. keep_going_count = numéro de
      -- l'utilisation en cours, base du bonus cumulatif (1 = pas de bonus).
      -- La capacité verrouillée est relâchée dès qu'il ne reste plus de
      -- réutilisation, pour qu'un nouveau choix redémarre une chaîne neuve.
      IF v_attacker = 'player' AND p_player_ability.keep_going_turns IS NOT NULL THEN
        IF v_player.keep_going_ability_nom IS DISTINCT FROM p_player_ability.ability_nom THEN
          v_player.keep_going_ability_nom := p_player_ability.ability_nom;
          v_player.keep_going_count := 1;
          v_player.keep_going_remaining := p_player_ability.keep_going_turns;
        ELSE
          v_player.keep_going_count := COALESCE(v_player.keep_going_count, 0) + 1;
          v_player.keep_going_remaining := GREATEST(0, COALESCE(v_player.keep_going_remaining, 0) - 1);
        END IF;
        IF COALESCE(v_player.keep_going_remaining, 0) <= 0 THEN
          v_player.keep_going_ability_nom := NULL;
          v_player.keep_going_remaining := 0;
        END IF;
      ELSIF v_attacker = 'opponent' AND p_opponent_ability.keep_going_turns IS NOT NULL THEN
        IF v_opponent.keep_going_ability_nom IS DISTINCT FROM p_opponent_ability.ability_nom THEN
          v_opponent.keep_going_ability_nom := p_opponent_ability.ability_nom;
          v_opponent.keep_going_count := 1;
          v_opponent.keep_going_remaining := p_opponent_ability.keep_going_turns;
        ELSE
          v_opponent.keep_going_count := COALESCE(v_opponent.keep_going_count, 0) + 1;
          v_opponent.keep_going_remaining := GREATEST(0, COALESCE(v_opponent.keep_going_remaining, 0) - 1);
        END IF;
        IF COALESCE(v_opponent.keep_going_remaining, 0) <= 0 THEN
          v_opponent.keep_going_ability_nom := NULL;
          v_opponent.keep_going_remaining := 0;
        END IF;
      END IF;

      -- Double tour chargé au tour précédent ('charge_double_next') : ce
      -- tour-ci s'utilise NORMALEMENT (avec la capacité librement choisie ce
      -- round, pas forcément celle qui a chargé), puis son utilisateur rejoue
      -- immédiatement — voir la consommation de v_*_owed en fin de boucle.
      IF v_attacker = 'player' AND COALESCE(v_player.double_turn_pending, false) THEN
        v_player.double_turn_pending := false;
        v_player_owed := true;
      ELSIF v_attacker = 'opponent' AND COALESCE(v_opponent.double_turn_pending, false) THEN
        v_opponent.double_turn_pending := false;
        v_opponent_owed := true;
      END IF;

      IF v_attacker = 'player' AND p_player_ability.turn_effect = 'skip' THEN
        IF v_player.skip_pending THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', true,
            'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
          ));
          v_player.skip_pending := false;
          v_attacker := 'opponent';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        ELSE
          v_block_remaining := 1;
          v_player.skip_pending := true;
        END IF;
      ELSIF v_attacker = 'opponent' AND p_opponent_ability.turn_effect = 'skip' THEN
        IF v_opponent.skip_pending THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', true,
            'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
          ));
          v_opponent.skip_pending := false;
          v_attacker := 'player';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        ELSE
          v_block_remaining := 1;
          v_opponent.skip_pending := true;
        END IF;
      ELSIF v_attacker = 'player' AND p_player_ability.turn_effect = 'repeat_until_fail' THEN
        v_block_remaining := GREATEST(1, COALESCE(p_player_ability.repeat_max, 6));
      ELSIF v_attacker = 'opponent' AND p_opponent_ability.turn_effect = 'repeat_until_fail' THEN
        v_block_remaining := GREATEST(1, COALESCE(p_opponent_ability.repeat_max, 6));
      ELSIF v_attacker = 'player' AND p_player_ability.turn_effect = 'prepare_release' THEN
        IF v_player.preparing THEN
          v_player.preparing := false;
          v_player.preparing_ability_nom := NULL;
          v_block_remaining := 1;
        ELSE
          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', true, 'preparing', true,
            'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
          );
          IF p_player_ability.invuln_grant THEN
            v_player.invulnerable := true;
            v_player.invuln_granted_round := v_round_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry);
          v_player.preparing := true;
          v_player.preparing_ability_nom := p_player_ability.ability_nom;
          v_attacker := 'opponent';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;
      ELSIF v_attacker = 'opponent' AND p_opponent_ability.turn_effect = 'prepare_release' THEN
        IF v_opponent.preparing THEN
          v_opponent.preparing := false;
          v_opponent.preparing_ability_nom := NULL;
          v_block_remaining := 1;
        ELSE
          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', true, 'preparing', true,
            'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
          );
          IF p_opponent_ability.invuln_grant THEN
            v_opponent.invulnerable := true;
            v_opponent.invuln_granted_round := v_round_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry);
          v_opponent.preparing := true;
          v_opponent.preparing_ability_nom := p_opponent_ability.ability_nom;
          v_attacker := 'player';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;

      -- 'charge_double_next' : ce tour ne fait RIEN d'autre que se charger
      -- (turn.charging), et c'est le PROCHAIN tour de ce camp qui jouera deux
      -- fois — deux capacités librement choisies en Combat Manuel/PvP, sans
      -- que l'adversaire n'intervienne entre les deux (voir la consommation de
      -- v_*_owed en fin de boucle). Le tour de charge est sauté sans effet
      -- quand une action supplémentaire est déjà due (v_*_owed) : sinon la
      -- 2e action d'un double se contenterait de recharger indéfiniment.
      ELSIF v_attacker = 'player' AND p_player_ability.turn_effect = 'charge_double_next' AND NOT v_player_owed THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', true, 'charging', true,
          'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
        ));
        v_player.double_turn_pending := true;
        v_attacker := 'opponent';
        v_flips := v_flips + 1;
        IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
        IF v_flips >= 2 THEN EXIT; END IF;
        CONTINUE;
      ELSIF v_attacker = 'opponent' AND p_opponent_ability.turn_effect = 'charge_double_next' AND NOT v_opponent_owed THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', true, 'charging', true,
          'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
        ));
        v_opponent.double_turn_pending := true;
        v_attacker := 'player';
        v_flips := v_flips + 1;
        IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
        IF v_flips >= 2 THEN EXIT; END IF;
        CONTINUE;

      -- 'first_and_replay' : la capacité s'utilise normalement mais ne
      -- "consomme" pas le tour — son utilisateur rejoue dans la foulée (avec
      -- un nouveau choix) et prend la main en premier pour la suite du combat.
      ELSIF v_attacker = 'player' AND p_player_ability.turn_effect = 'first_and_replay' THEN
        v_player_owed := true;
        v_next_first := 'player';
        v_block_remaining := 1;
      ELSIF v_attacker = 'opponent' AND p_opponent_ability.turn_effect = 'first_and_replay' THEN
        v_opponent_owed := true;
        v_next_first := 'opponent';
        v_block_remaining := 1;

      ELSE
        v_block_remaining := autobattle_ability_burst(CASE WHEN v_attacker = 'player' THEN p_player_ability.ability_nom ELSE p_opponent_ability.ability_nom END);
        IF v_block_remaining = 0 THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', v_attacker, 'damage', 0, 'skipped', true,
            'defender_hp_after', CASE WHEN v_attacker = 'player' THEN GREATEST(0, v_opponent.hp) ELSE GREATEST(0, v_player.hp) END,
            'ko', false
          ));
          v_attacker := CASE WHEN v_attacker = 'player' THEN 'opponent' ELSE 'player' END;
          v_block_remaining := NULL;
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;
      END IF;
    END IF;

    IF v_attacker = 'player' THEN
      IF v_opponent.invulnerable AND (
        p_player_ability.deals_damage
        OR (p_player_ability.status_effect IS NOT NULL AND NOT p_player_ability.status_reversed)
        OR p_player_ability.stat_mod_target = 'opponent'
        OR p_player_ability.cancel_heal_duration IS NOT NULL
      ) THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true, 'invulnerable_miss', true,
          'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
        ));
        IF p_player_ability.turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
        -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
        -- cesse d'être imposée, le tour suivant redevient un choix libre.
        IF p_player_ability.keep_going_turns IS NOT NULL THEN
          v_player.keep_going_ability_nom := NULL;
          v_player.keep_going_remaining := 0;
        END IF;
      ELSE
        v_missed := (NOT v_player_never_miss) AND
          random() >= ((CASE WHEN p_precision_enabled THEN GREATEST(0, COALESCE(p_player_ability.precision, 10) - v_status_precision_penalty + v_player.precision_mod_amount) ELSE 10 END * 10) / 100.0);

        IF v_missed THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true,
            'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false,
            'precision_mod_amount', v_player.precision_mod_amount
          ));
          IF p_player_ability.turn_effect = 'repeat_until_fail' THEN
            v_block_remaining := 1;
          END IF;
          -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
          -- cesse d'être imposée, le tour suivant redevient un choix libre.
          IF p_player_ability.keep_going_turns IS NOT NULL THEN
            v_player.keep_going_ability_nom := NULL;
            v_player.keep_going_remaining := 0;
          END IF;
        ELSE
          -- Modificateur de dégâts actif : ignoré si son filtre de type (voir
          -- autobattle_ability_rules.stat_mod_type_filter) ne correspond pas
          -- au type de la capacité effectivement jouée ce tour-ci.
          v_damage_mod_applied := CASE
            WHEN v_player.damage_mod_type_filter IS NULL
              OR lower(trim(v_player.damage_mod_type_filter)) = lower(trim(COALESCE(p_player_ability.ability_type, '')))
            THEN v_player.damage_mod_amount ELSE 0 END;
          -- Bouclier Prévention de la cible : annule les dégâts ADDITIONNELS
          -- dus au bonus super efficace (la composante espèce+XP est comptée
          -- une fois au lieu de deux), le reste du coup est inchangé.
          v_prevention_blocked := p_player_ability.type_bonus
            AND v_opponent.prevention_expires IS NOT NULL AND v_round_no <= v_opponent.prevention_expires;
          v_keep_going_bonus := 0;
          IF p_player_ability.deals_damage THEN
            v_hit_dice := CASE WHEN p_player_ability.degats_de IS NOT NULL AND p_player_ability.degats_de > 0
              THEN 1 + floor(random() * p_player_ability.degats_de)::integer ELSE 0 END;
            v_hit_damage := GREATEST(0, p_player_ability.base_damage
              - (CASE WHEN v_prevention_blocked THEN p_player_ability.damage_species_xp ELSE 0 END)
              + v_hit_dice + v_damage_mod_applied);

            v_percent_hp_damage_applied := p_player_ability.percent_hp_damage_percent IS NOT NULL;
            IF v_percent_hp_damage_applied THEN
              v_hit_damage := GREATEST(0, floor(v_opponent.hp * p_player_ability.percent_hp_damage_percent / 100.0)::integer);
            END IF;

            v_bonus_condition_met := p_player_ability.bonus_condition = 'took_damage_last_turn' AND v_player.took_damage
              OR p_player_ability.bonus_condition = 'first_use' AND NOT v_player.used_ability
              OR p_player_ability.bonus_condition = 'dice_equals' AND v_hit_dice = p_player_ability.bonus_dice_value
              OR p_player_ability.bonus_condition = 'has_status' AND v_opponent.status IS NOT NULL AND (p_player_ability.bonus_status_filter IS NULL OR v_opponent.status = p_player_ability.bonus_status_filter);
            IF p_player_ability.bonus_type IS NOT NULL AND v_bonus_condition_met THEN
              IF p_player_ability.bonus_type = 'multiply' THEN
                v_hit_damage := floor(v_hit_damage * COALESCE(p_player_ability.bonus_multiplier, 1))::integer;
              ELSIF p_player_ability.bonus_type = 'flat' THEN
                v_hit_damage := v_hit_damage + COALESCE(p_player_ability.bonus_flat, 0);
              ELSIF p_player_ability.bonus_type = 'range' THEN
                v_hit_damage := v_hit_damage + (p_player_ability.bonus_min + floor(random() * (p_player_ability.bonus_max - p_player_ability.bonus_min + 1))::integer);
              END IF;
              v_hit_damage := GREATEST(0, v_hit_damage);
            END IF;

            -- Bonus cumulatif de la chaîne "Continue sur sa lancée" : rien à
            -- la 1ère utilisation, puis +1 fois le bonus unitaire par
            -- réutilisation (voir keep_going_count, incrémenté plus haut).
            IF p_player_ability.keep_going_turns IS NOT NULL AND COALESCE(v_player.keep_going_count, 0) > 1 THEN
              v_keep_going_bonus := (COALESCE(v_player.keep_going_count, 1) - 1) * (CASE
                WHEN p_player_ability.keep_going_bonus_type = 'percent_damage'
                  THEN floor(p_player_ability.base_damage * COALESCE(p_player_ability.keep_going_bonus_percent, 0) / 100.0)::integer
                ELSE COALESCE(p_player_ability.keep_going_bonus_flat, 0) END);
              v_hit_damage := GREATEST(0, v_hit_damage + v_keep_going_bonus);
            END IF;
          ELSE
            v_hit_dice := 0;
            v_hit_damage := 0;
            v_percent_hp_damage_applied := false;
          END IF;
          -- 'first_and_replay' ne "compte" pas comme une capacité utilisée
          -- (voir autobattle_ability_rules) : la condition de bonus
          -- 'first_use' reste donc vraie pour la vraie attaque qui suit.
          IF p_player_ability.turn_effect IS DISTINCT FROM 'first_and_replay' THEN
            v_player.used_ability := true;
          END IF;

          v_opponent.hp := v_opponent.hp - v_hit_damage;
          v_opponent.took_damage := v_hit_damage > 0;

          v_heal_amt := NULL;
          IF p_player_ability.heal_type = 'static' THEN
            v_heal_amt := COALESCE(p_player_ability.heal_amount, 0);
          ELSIF p_player_ability.heal_type = 'percent_damage' THEN
            v_heal_amt := floor(v_hit_damage * COALESCE(p_player_ability.heal_percent, 0) / 100.0)::integer;
          ELSIF p_player_ability.heal_type = 'use_stats' THEN
            v_heal_dice := CASE WHEN p_player_ability.degats_de IS NOT NULL AND p_player_ability.degats_de > 0
              THEN 1 + floor(random() * p_player_ability.degats_de)::integer ELSE 0 END;
            -- base_damage inclut le bonus de type x2 (super efficace) — un
            -- soin basé sur les stats n'inflige aucun dégât, on retire donc
            -- cette part avant de l'utiliser comme montant de soin (voir
            -- autobattle_combatant_ability.type_bonus).
            v_heal_amt := p_player_ability.base_damage
              - (CASE WHEN p_player_ability.type_bonus THEN p_player_ability.damage_species_xp ELSE 0 END)
              + v_heal_dice;
          END IF;

          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', v_hit_damage, 'damage_before_dice', p_player_ability.base_damage,
            'damage_species_xp', p_player_ability.damage_species_xp, 'damage_dice', v_hit_dice,
            'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', v_opponent.hp <= 0,
            'precision_mod_amount', v_player.precision_mod_amount
          );
          IF v_percent_hp_damage_applied THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('percent_hp_damage', true);
          END IF;
          IF v_prevention_blocked THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('prevention_blocked', true);
          END IF;
          IF v_keep_going_bonus <> 0 THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('keep_going_bonus', v_keep_going_bonus);
          END IF;
          IF v_heal_amt IS NOT NULL AND v_heal_amt > 0 AND (v_player.heal_disabled_expires IS NULL OR v_round_no > v_player.heal_disabled_expires) THEN
            v_player.hp := LEAST(v_player.max_hp, v_player.hp + v_heal_amt);
            v_turn_entry := v_turn_entry || jsonb_build_object('heal', v_heal_amt, 'attacker_hp_after', v_player.hp);
            IF v_player.status = 'poison' THEN
              v_player.status := NULL;
              v_turn_entry := v_turn_entry || jsonb_build_object('status_cured_by_heal', true);
            END IF;
          ELSIF v_heal_amt IS NOT NULL AND v_heal_amt > 0 THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('heal_blocked', true);
          END IF;
          IF p_player_ability.status_effect IS NOT NULL AND random() * 100 < p_player_ability.status_chance THEN
            IF p_player_ability.status_reversed THEN
              v_player.status := p_player_ability.status_effect;
            ELSE
              v_opponent.status := p_player_ability.status_effect;
            END IF;
            v_turn_entry := v_turn_entry || jsonb_build_object('status_applied', p_player_ability.status_effect, 'status_applied_reversed', p_player_ability.status_reversed);
          END IF;
          IF p_player_ability.stat_mod_target IS NOT NULL THEN
            v_stat_mod_key := p_player_ability.ability_nom;
            v_stat_mod_uses_used_for_key := COALESCE((v_player.stat_mod_uses ->> v_stat_mod_key)::integer, 0);
            IF p_player_ability.stat_mod_max_uses IS NULL OR v_stat_mod_uses_used_for_key < p_player_ability.stat_mod_max_uses THEN
              v_stat_mod_amount := CASE
                WHEN p_player_ability.stat_mod_value_type = 'flat' THEN COALESCE(p_player_ability.stat_mod_flat, 0)
                WHEN p_player_ability.stat_mod_value_type = 'range' THEN p_player_ability.stat_mod_min + floor(random() * (p_player_ability.stat_mod_max - p_player_ability.stat_mod_min + 1))::integer
                WHEN p_player_ability.stat_mod_value_type = 'percent' THEN
                  floor((CASE WHEN p_player_ability.stat_mod_target = 'self' THEN p_player_ability.base_damage ELSE p_opponent_ability.base_damage END)
                    * COALESCE(p_player_ability.stat_mod_percent, 0) / 100.0)::integer
                ELSE 0
              END;
              v_stat_mod_amount := CASE WHEN p_player_ability.stat_mod_target = 'opponent' THEN -abs(v_stat_mod_amount) ELSE abs(v_stat_mod_amount) END;
              v_stat_mod_expiry := CASE WHEN p_player_ability.stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_round_no + 2 * COALESCE(p_player_ability.stat_mod_duration_turns, 1) END;
              -- Le filtre de type éventuel (stat_mod_type_filter) voyage avec
              -- le modificateur : il est relu au moment d'infliger des dégâts,
              -- contre le type de la capacité jouée à ce moment-là.
              IF p_player_ability.stat_mod_target = 'self' AND p_player_ability.stat_mod_stat = 'damage' THEN
                v_player.damage_mod_amount := v_stat_mod_amount; v_player.damage_mod_expires := v_stat_mod_expiry;
                v_player.damage_mod_type_filter := p_player_ability.stat_mod_type_filter;
              ELSIF p_player_ability.stat_mod_target = 'self' AND p_player_ability.stat_mod_stat = 'precision' THEN
                v_player.precision_mod_amount := v_stat_mod_amount; v_player.precision_mod_expires := v_stat_mod_expiry;
              ELSIF p_player_ability.stat_mod_target = 'opponent' AND p_player_ability.stat_mod_stat = 'damage' THEN
                v_opponent.damage_mod_amount := v_stat_mod_amount; v_opponent.damage_mod_expires := v_stat_mod_expiry;
                v_opponent.damage_mod_type_filter := p_player_ability.stat_mod_type_filter;
              ELSIF p_player_ability.stat_mod_target = 'opponent' AND p_player_ability.stat_mod_stat = 'precision' THEN
                v_opponent.precision_mod_amount := v_stat_mod_amount; v_opponent.precision_mod_expires := v_stat_mod_expiry;
              END IF;
              v_player.stat_mod_uses := jsonb_set(v_player.stat_mod_uses, ARRAY[v_stat_mod_key], to_jsonb(v_stat_mod_uses_used_for_key + 1));
              v_turn_entry := v_turn_entry || jsonb_build_object('stat_mod_applied', jsonb_build_object(
                'target', p_player_ability.stat_mod_target, 'stat', p_player_ability.stat_mod_stat, 'amount', v_stat_mod_amount, 'duration_type', p_player_ability.stat_mod_duration_type
              ));
            ELSE
              v_turn_entry := v_turn_entry || jsonb_build_object('stat_mod_limit_reached', true);
            END IF;
          END IF;
          IF p_player_ability.heal_dot_config_turns IS NOT NULL OR COALESCE(p_player_ability.heal_dot_until_awake, false) THEN
            -- Montant résolu UNE FOIS ici (pas recalculé à chaque tick) : pour
            -- 'percent_max_hp'/'percent_damage', voir autobattle_ability_rules.
            v_player.heal_dot_amount := CASE
              WHEN p_player_ability.heal_dot_config_type = 'percent_max_hp' THEN floor(v_player.max_hp * COALESCE(p_player_ability.heal_dot_config_percent, 0) / 100.0)::integer
              WHEN p_player_ability.heal_dot_config_type = 'percent_damage' THEN floor(v_hit_damage * COALESCE(p_player_ability.heal_dot_config_percent, 0) / 100.0)::integer
              ELSE COALESCE(p_player_ability.heal_dot_config_amount, 0)
            END;
            -- Variante "jusqu'au réveil" : aucune expiration par tour, c'est
            -- la perte du statut Sommeil qui met fin à l'effet (voir la
            -- condition de tick et les expirations en tête de boucle).
            IF COALESCE(p_player_ability.heal_dot_until_awake, false) THEN
              v_player.heal_dot_until_awake := true;
              v_player.heal_dot_expires := NULL;
            ELSE
              -- x2 : v_round_no est un compteur GLOBAL incrémenté à CHAQUE tour
              -- (les deux camps confondus, voir le même x2 sur stat_mod_expiry
              -- ci-dessus), alors que ce soin ne tique que sur les tours PROPRES
              -- du joueur (un sur deux) — sans le x2, un "3 tours" ne tiquerait
              -- qu'une fois au lieu de trois (bug constaté en jeu).
              v_player.heal_dot_until_awake := false;
              v_player.heal_dot_expires := v_round_no + 2 * p_player_ability.heal_dot_config_turns;
            END IF;
            v_turn_entry := v_turn_entry || jsonb_build_object('heal_dot_granted', true);
          END IF;
          IF p_player_ability.cancel_heal_duration IS NOT NULL THEN
            v_opponent.heal_disabled_expires := v_round_no + 2 * p_player_ability.cancel_heal_duration;
            v_turn_entry := v_turn_entry || jsonb_build_object('cancel_heal_applied', true);
          END IF;
          IF p_player_ability.prevention_duration IS NOT NULL THEN
            v_player.prevention_expires := v_round_no + 2 * p_player_ability.prevention_duration;
            v_turn_entry := v_turn_entry || jsonb_build_object('prevention_granted', true);
          END IF;
          -- Invulnérabilité : déjà accordée au tour de préparation pour
          -- 'prepare_release' (voir plus haut), pas ré-accordée ici. IS
          -- DISTINCT FROM et surtout PAS <> : turn_effect est NULL pour toute
          -- capacité sans effet de tour, et `NULL <> '...'` vaut NULL (donc
          -- faux) — le bouclier n'était alors JAMAIS accordé hors préparation
          -- (bug constaté en jeu).
          IF p_player_ability.invuln_grant AND p_player_ability.turn_effect IS DISTINCT FROM 'prepare_release' THEN
            v_player.invulnerable := true;
            v_player.invuln_granted_round := v_round_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          IF p_player_ability.recoil_type IS NOT NULL THEN
            v_recoil_amt := CASE WHEN p_player_ability.recoil_type = 'range'
              THEN p_player_ability.recoil_min + floor(random() * (p_player_ability.recoil_max - p_player_ability.recoil_min + 1))::integer
              ELSE floor(v_hit_damage * COALESCE(p_player_ability.recoil_percent, 0) / 100.0)::integer END;
            IF v_recoil_amt > 0 THEN
              v_player.hp := v_player.hp - v_recoil_amt;
              v_turn_entry := v_turn_entry || jsonb_build_object('recoil', v_recoil_amt, 'attacker_hp_after', v_player.hp);
            END IF;
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry);

          IF v_opponent.hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
          IF v_player.hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
        END IF;
      END IF;
    ELSE
      IF v_player.invulnerable AND (
        p_opponent_ability.deals_damage
        OR (p_opponent_ability.status_effect IS NOT NULL AND NOT p_opponent_ability.status_reversed)
        OR p_opponent_ability.stat_mod_target = 'opponent'
        OR p_opponent_ability.cancel_heal_duration IS NOT NULL
      ) THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'missed', true, 'invulnerable_miss', true,
          'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
        ));
        IF p_opponent_ability.turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
        -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
        -- cesse d'être imposée, le tour suivant redevient un choix libre.
        IF p_opponent_ability.keep_going_turns IS NOT NULL THEN
          v_opponent.keep_going_ability_nom := NULL;
          v_opponent.keep_going_remaining := 0;
        END IF;
      ELSE
        v_missed := (NOT v_opponent_never_miss) AND
          random() >= ((CASE WHEN p_precision_enabled THEN GREATEST(0, COALESCE(p_opponent_ability.precision, 10) - v_status_precision_penalty + v_opponent.precision_mod_amount) ELSE 10 END * 10) / 100.0);

        IF v_missed THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'missed', true,
            'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false,
            'precision_mod_amount', v_opponent.precision_mod_amount
          ));
          IF p_opponent_ability.turn_effect = 'repeat_until_fail' THEN
            v_block_remaining := 1;
          END IF;
          -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
          -- cesse d'être imposée, le tour suivant redevient un choix libre.
          IF p_opponent_ability.keep_going_turns IS NOT NULL THEN
            v_opponent.keep_going_ability_nom := NULL;
            v_opponent.keep_going_remaining := 0;
          END IF;
        ELSE
          -- Voir les mêmes commentaires côté joueur plus haut.
          v_damage_mod_applied := CASE
            WHEN v_opponent.damage_mod_type_filter IS NULL
              OR lower(trim(v_opponent.damage_mod_type_filter)) = lower(trim(COALESCE(p_opponent_ability.ability_type, '')))
            THEN v_opponent.damage_mod_amount ELSE 0 END;
          v_prevention_blocked := p_opponent_ability.type_bonus
            AND v_player.prevention_expires IS NOT NULL AND v_round_no <= v_player.prevention_expires;
          v_keep_going_bonus := 0;
          IF p_opponent_ability.deals_damage THEN
            v_hit_dice := CASE WHEN p_opponent_ability.degats_de IS NOT NULL AND p_opponent_ability.degats_de > 0
              THEN 1 + floor(random() * p_opponent_ability.degats_de)::integer ELSE 0 END;
            v_hit_damage := GREATEST(0, p_opponent_ability.base_damage
              - (CASE WHEN v_prevention_blocked THEN p_opponent_ability.damage_species_xp ELSE 0 END)
              + v_hit_dice + v_damage_mod_applied);

            v_percent_hp_damage_applied := p_opponent_ability.percent_hp_damage_percent IS NOT NULL;
            IF v_percent_hp_damage_applied THEN
              v_hit_damage := GREATEST(0, floor(v_player.hp * p_opponent_ability.percent_hp_damage_percent / 100.0)::integer);
            END IF;

            v_bonus_condition_met := p_opponent_ability.bonus_condition = 'took_damage_last_turn' AND v_opponent.took_damage
              OR p_opponent_ability.bonus_condition = 'first_use' AND NOT v_opponent.used_ability
              OR p_opponent_ability.bonus_condition = 'dice_equals' AND v_hit_dice = p_opponent_ability.bonus_dice_value
              OR p_opponent_ability.bonus_condition = 'has_status' AND v_player.status IS NOT NULL AND (p_opponent_ability.bonus_status_filter IS NULL OR v_player.status = p_opponent_ability.bonus_status_filter);
            IF p_opponent_ability.bonus_type IS NOT NULL AND v_bonus_condition_met THEN
              IF p_opponent_ability.bonus_type = 'multiply' THEN
                v_hit_damage := floor(v_hit_damage * COALESCE(p_opponent_ability.bonus_multiplier, 1))::integer;
              ELSIF p_opponent_ability.bonus_type = 'flat' THEN
                v_hit_damage := v_hit_damage + COALESCE(p_opponent_ability.bonus_flat, 0);
              ELSIF p_opponent_ability.bonus_type = 'range' THEN
                v_hit_damage := v_hit_damage + (p_opponent_ability.bonus_min + floor(random() * (p_opponent_ability.bonus_max - p_opponent_ability.bonus_min + 1))::integer);
              END IF;
              v_hit_damage := GREATEST(0, v_hit_damage);
            END IF;

            IF p_opponent_ability.keep_going_turns IS NOT NULL AND COALESCE(v_opponent.keep_going_count, 0) > 1 THEN
              v_keep_going_bonus := (COALESCE(v_opponent.keep_going_count, 1) - 1) * (CASE
                WHEN p_opponent_ability.keep_going_bonus_type = 'percent_damage'
                  THEN floor(p_opponent_ability.base_damage * COALESCE(p_opponent_ability.keep_going_bonus_percent, 0) / 100.0)::integer
                ELSE COALESCE(p_opponent_ability.keep_going_bonus_flat, 0) END);
              v_hit_damage := GREATEST(0, v_hit_damage + v_keep_going_bonus);
            END IF;
          ELSE
            v_hit_dice := 0;
            v_hit_damage := 0;
            v_percent_hp_damage_applied := false;
          END IF;
          IF p_opponent_ability.turn_effect IS DISTINCT FROM 'first_and_replay' THEN
            v_opponent.used_ability := true;
          END IF;

          v_player.hp := v_player.hp - v_hit_damage;
          v_player.took_damage := v_hit_damage > 0;

          v_heal_amt := NULL;
          IF p_opponent_ability.heal_type = 'static' THEN
            v_heal_amt := COALESCE(p_opponent_ability.heal_amount, 0);
          ELSIF p_opponent_ability.heal_type = 'percent_damage' THEN
            v_heal_amt := floor(v_hit_damage * COALESCE(p_opponent_ability.heal_percent, 0) / 100.0)::integer;
          ELSIF p_opponent_ability.heal_type = 'use_stats' THEN
            v_heal_dice := CASE WHEN p_opponent_ability.degats_de IS NOT NULL AND p_opponent_ability.degats_de > 0
              THEN 1 + floor(random() * p_opponent_ability.degats_de)::integer ELSE 0 END;
            -- Voir le même commentaire côté joueur plus haut.
            v_heal_amt := p_opponent_ability.base_damage
              - (CASE WHEN p_opponent_ability.type_bonus THEN p_opponent_ability.damage_species_xp ELSE 0 END)
              + v_heal_dice;
          END IF;

          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', v_hit_damage, 'damage_before_dice', p_opponent_ability.base_damage,
            'damage_species_xp', p_opponent_ability.damage_species_xp, 'damage_dice', v_hit_dice,
            'defender_hp_after', GREATEST(0, v_player.hp), 'ko', v_player.hp <= 0,
            'precision_mod_amount', v_opponent.precision_mod_amount
          );
          IF v_percent_hp_damage_applied THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('percent_hp_damage', true);
          END IF;
          IF v_prevention_blocked THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('prevention_blocked', true);
          END IF;
          IF v_keep_going_bonus <> 0 THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('keep_going_bonus', v_keep_going_bonus);
          END IF;
          IF v_heal_amt IS NOT NULL AND v_heal_amt > 0 AND (v_opponent.heal_disabled_expires IS NULL OR v_round_no > v_opponent.heal_disabled_expires) THEN
            v_opponent.hp := LEAST(v_opponent.max_hp, v_opponent.hp + v_heal_amt);
            v_turn_entry := v_turn_entry || jsonb_build_object('heal', v_heal_amt, 'attacker_hp_after', v_opponent.hp);
            IF v_opponent.status = 'poison' THEN
              v_opponent.status := NULL;
              v_turn_entry := v_turn_entry || jsonb_build_object('status_cured_by_heal', true);
            END IF;
          ELSIF v_heal_amt IS NOT NULL AND v_heal_amt > 0 THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('heal_blocked', true);
          END IF;
          IF p_opponent_ability.status_effect IS NOT NULL AND random() * 100 < p_opponent_ability.status_chance THEN
            IF p_opponent_ability.status_reversed THEN
              v_opponent.status := p_opponent_ability.status_effect;
            ELSE
              v_player.status := p_opponent_ability.status_effect;
            END IF;
            v_turn_entry := v_turn_entry || jsonb_build_object('status_applied', p_opponent_ability.status_effect, 'status_applied_reversed', p_opponent_ability.status_reversed);
          END IF;
          IF p_opponent_ability.stat_mod_target IS NOT NULL THEN
            v_stat_mod_key := p_opponent_ability.ability_nom;
            v_stat_mod_uses_used_for_key := COALESCE((v_opponent.stat_mod_uses ->> v_stat_mod_key)::integer, 0);
            IF p_opponent_ability.stat_mod_max_uses IS NULL OR v_stat_mod_uses_used_for_key < p_opponent_ability.stat_mod_max_uses THEN
              v_stat_mod_amount := CASE
                WHEN p_opponent_ability.stat_mod_value_type = 'flat' THEN COALESCE(p_opponent_ability.stat_mod_flat, 0)
                WHEN p_opponent_ability.stat_mod_value_type = 'range' THEN p_opponent_ability.stat_mod_min + floor(random() * (p_opponent_ability.stat_mod_max - p_opponent_ability.stat_mod_min + 1))::integer
                WHEN p_opponent_ability.stat_mod_value_type = 'percent' THEN
                  floor((CASE WHEN p_opponent_ability.stat_mod_target = 'self' THEN p_opponent_ability.base_damage ELSE p_player_ability.base_damage END)
                    * COALESCE(p_opponent_ability.stat_mod_percent, 0) / 100.0)::integer
                ELSE 0
              END;
              v_stat_mod_amount := CASE WHEN p_opponent_ability.stat_mod_target = 'opponent' THEN -abs(v_stat_mod_amount) ELSE abs(v_stat_mod_amount) END;
              v_stat_mod_expiry := CASE WHEN p_opponent_ability.stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_round_no + 2 * COALESCE(p_opponent_ability.stat_mod_duration_turns, 1) END;
              -- Voir le même commentaire côté joueur plus haut.
              IF p_opponent_ability.stat_mod_target = 'self' AND p_opponent_ability.stat_mod_stat = 'damage' THEN
                v_opponent.damage_mod_amount := v_stat_mod_amount; v_opponent.damage_mod_expires := v_stat_mod_expiry;
                v_opponent.damage_mod_type_filter := p_opponent_ability.stat_mod_type_filter;
              ELSIF p_opponent_ability.stat_mod_target = 'self' AND p_opponent_ability.stat_mod_stat = 'precision' THEN
                v_opponent.precision_mod_amount := v_stat_mod_amount; v_opponent.precision_mod_expires := v_stat_mod_expiry;
              ELSIF p_opponent_ability.stat_mod_target = 'opponent' AND p_opponent_ability.stat_mod_stat = 'damage' THEN
                v_player.damage_mod_amount := v_stat_mod_amount; v_player.damage_mod_expires := v_stat_mod_expiry;
                v_player.damage_mod_type_filter := p_opponent_ability.stat_mod_type_filter;
              ELSIF p_opponent_ability.stat_mod_target = 'opponent' AND p_opponent_ability.stat_mod_stat = 'precision' THEN
                v_player.precision_mod_amount := v_stat_mod_amount; v_player.precision_mod_expires := v_stat_mod_expiry;
              END IF;
              v_opponent.stat_mod_uses := jsonb_set(v_opponent.stat_mod_uses, ARRAY[v_stat_mod_key], to_jsonb(v_stat_mod_uses_used_for_key + 1));
              v_turn_entry := v_turn_entry || jsonb_build_object('stat_mod_applied', jsonb_build_object(
                'target', p_opponent_ability.stat_mod_target, 'stat', p_opponent_ability.stat_mod_stat, 'amount', v_stat_mod_amount, 'duration_type', p_opponent_ability.stat_mod_duration_type
              ));
            ELSE
              v_turn_entry := v_turn_entry || jsonb_build_object('stat_mod_limit_reached', true);
            END IF;
          END IF;
          IF p_opponent_ability.heal_dot_config_turns IS NOT NULL OR COALESCE(p_opponent_ability.heal_dot_until_awake, false) THEN
            v_opponent.heal_dot_amount := CASE
              WHEN p_opponent_ability.heal_dot_config_type = 'percent_max_hp' THEN floor(v_opponent.max_hp * COALESCE(p_opponent_ability.heal_dot_config_percent, 0) / 100.0)::integer
              WHEN p_opponent_ability.heal_dot_config_type = 'percent_damage' THEN floor(v_hit_damage * COALESCE(p_opponent_ability.heal_dot_config_percent, 0) / 100.0)::integer
              ELSE COALESCE(p_opponent_ability.heal_dot_config_amount, 0)
            END;
            -- Voir le même commentaire côté joueur ci-dessus (x2 et variante
            -- "jusqu'au réveil").
            IF COALESCE(p_opponent_ability.heal_dot_until_awake, false) THEN
              v_opponent.heal_dot_until_awake := true;
              v_opponent.heal_dot_expires := NULL;
            ELSE
              v_opponent.heal_dot_until_awake := false;
              v_opponent.heal_dot_expires := v_round_no + 2 * p_opponent_ability.heal_dot_config_turns;
            END IF;
            v_turn_entry := v_turn_entry || jsonb_build_object('heal_dot_granted', true);
          END IF;
          IF p_opponent_ability.cancel_heal_duration IS NOT NULL THEN
            v_player.heal_disabled_expires := v_round_no + 2 * p_opponent_ability.cancel_heal_duration;
            v_turn_entry := v_turn_entry || jsonb_build_object('cancel_heal_applied', true);
          END IF;
          IF p_opponent_ability.prevention_duration IS NOT NULL THEN
            v_opponent.prevention_expires := v_round_no + 2 * p_opponent_ability.prevention_duration;
            v_turn_entry := v_turn_entry || jsonb_build_object('prevention_granted', true);
          END IF;
          IF p_opponent_ability.invuln_grant AND p_opponent_ability.turn_effect IS DISTINCT FROM 'prepare_release' THEN
            v_opponent.invulnerable := true;
            v_opponent.invuln_granted_round := v_round_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          IF p_opponent_ability.recoil_type IS NOT NULL THEN
            v_recoil_amt := CASE WHEN p_opponent_ability.recoil_type = 'range'
              THEN p_opponent_ability.recoil_min + floor(random() * (p_opponent_ability.recoil_max - p_opponent_ability.recoil_min + 1))::integer
              ELSE floor(v_hit_damage * COALESCE(p_opponent_ability.recoil_percent, 0) / 100.0)::integer END;
            IF v_recoil_amt > 0 THEN
              v_opponent.hp := v_opponent.hp - v_recoil_amt;
              v_turn_entry := v_turn_entry || jsonb_build_object('recoil', v_recoil_amt, 'attacker_hp_after', v_opponent.hp);
            END IF;
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry);

          IF v_player.hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_opponent.hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
        END IF;
      END IF;
    END IF;

    v_block_remaining := v_block_remaining - 1;
    IF v_block_remaining = 0 THEN
      -- Action supplémentaire due à ce camp ('charge_double_next' libéré ou
      -- 'first_and_replay') : il rejoue au lieu de rendre la main.
      --   • camp 'player' : on ARRÊTE le round ici et il reprendra la main en
      --     tout premier au round suivant — c'est ce qui lui permet de
      --     CHOISIR une seconde capacité (le round suivant est un nouvel appel
      --     RPC), sans que l'adversaire ne joue entre les deux. Sa capacité de
      --     ce round a déjà été consommée, rien n'est perdu.
      --   • camp 'opponent' qui a déjà vu le joueur agir : idem, on s'arrête.
      --   • camp 'opponent' qui a ouvert le round : s'arrêter gâcherait la
      --     capacité que le joueur vient de soumettre pour ce round — il
      --     rejoue donc immédiatement, avec la même capacité (l'adversaire
      --     n'en choisit qu'une par round de toute façon).
      IF v_attacker = 'player' AND v_player_owed AND NOT v_player_extra_used THEN
        v_player_owed := false;
        v_player_extra_used := true;
        v_next_first := 'player';
        EXIT;
      ELSIF v_attacker = 'opponent' AND v_opponent_owed AND NOT v_opponent_extra_used THEN
        v_opponent_owed := false;
        v_opponent_extra_used := true;
        v_next_first := 'opponent';
        IF v_flips >= 1 THEN
          EXIT;
        END IF;
        v_block_remaining := 1;
      ELSE
        v_attacker := CASE WHEN v_attacker = 'player' THEN 'opponent' ELSE 'player' END;
        v_block_remaining := NULL;
        v_flips := v_flips + 1;
      END IF;
    END IF;

    IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
    IF v_flips >= 2 THEN EXIT; END IF;
  END LOOP;

  v_result.player_state := v_player;
  v_result.opponent_state := v_opponent;
  v_result.turns := v_turns;
  v_result.outcome := v_outcome;
  v_result.turn_no := v_turn_no;
  v_result.round_no := v_round_no;
  v_result.next_first_attacker := v_next_first;
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION autobattle_resolve_round_core(integer, integer, text, autobattle_combatant_state, autobattle_combatant_state, autobattle_combatant_ability, autobattle_combatant_ability, boolean) TO anon, authenticated;

-- ============================================================
-- 5. Combat Auto (boucle complète, moteur propre à ce mode)
-- ============================================================
CREATE OR REPLACE FUNCTION autobattle_resolve_battle(
  p_player_id bigint,
  p_level_id bigint,
  p_player_pokemon_id bigint,
  p_ability_nom text,
  p_idempotency_key uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_battle_id           bigint;
  v_level               record;
  v_variant             record;
  v_progress            record;
  v_pp                  record;
  v_player_species      record;
  v_ability             record;
  v_opponent_species    record;
  v_opponent_ability    record;
  v_ticket_item_nom     text := 'Ticket Combat';
  v_player_max_hp       integer;
  v_player_damage       integer;
  v_player_type_bonus   boolean;
  v_opponent_damage     integer;
  v_opponent_type_bonus boolean;
  v_hit_dice            integer;
  v_hit_damage          integer;
  v_player_hp           integer;
  v_opponent_hp         integer;
  v_player_heal_type    text;
  v_player_heal_amount  integer;
  v_player_heal_percent integer;
  v_opponent_heal_type    text;
  v_opponent_heal_amount  integer;
  v_opponent_heal_percent integer;
  v_heal_amt            integer;
  v_heal_dice           integer;
  v_precision_enabled   boolean;
  v_hit_chance          integer;
  v_missed              boolean;
  v_block_remaining     integer;
  v_player_turn_effect    text;
  v_opponent_turn_effect  text;
  v_player_skip_pending   boolean := false;
  v_opponent_skip_pending boolean := false;
  v_player_repeat_max     integer;
  v_opponent_repeat_max   integer;
  v_player_status           text;
  v_opponent_status         text;
  v_status_roll             integer;
  v_status_cured            boolean;
  v_status_precision_penalty integer := 0;
  v_player_status_reversed  boolean;
  v_opponent_status_reversed boolean;
  v_player_never_miss       boolean;
  v_opponent_never_miss     boolean;
  v_player_preparing        boolean := false;
  v_opponent_preparing      boolean := false;
  v_player_invulnerable     boolean := false;
  v_opponent_invulnerable   boolean := false;
  v_player_invuln_granted_round   integer;
  v_opponent_invuln_granted_round integer;
  v_player_invuln_grant     boolean;
  v_opponent_invuln_grant   boolean;
  v_player_used_ability     boolean := false;
  v_opponent_used_ability   boolean := false;
  v_player_took_damage      boolean := false;
  v_opponent_took_damage    boolean := false;
  v_player_recoil_type      text;
  v_player_recoil_min       integer;
  v_player_recoil_max       integer;
  v_player_recoil_percent   integer;
  v_opponent_recoil_type    text;
  v_opponent_recoil_min     integer;
  v_opponent_recoil_max     integer;
  v_opponent_recoil_percent integer;
  v_recoil_amt              integer;
  v_player_bonus_type       text;
  v_player_bonus_multiplier numeric;
  v_player_bonus_flat       integer;
  v_player_bonus_min        integer;
  v_player_bonus_max        integer;
  v_player_bonus_condition  text;
  v_player_bonus_dice_value integer;
  v_player_bonus_status_filter text;
  v_opponent_bonus_type       text;
  v_opponent_bonus_multiplier numeric;
  v_opponent_bonus_flat       integer;
  v_opponent_bonus_min        integer;
  v_opponent_bonus_max        integer;
  v_opponent_bonus_condition  text;
  v_opponent_bonus_dice_value integer;
  v_opponent_bonus_status_filter text;
  v_bonus_condition_met     boolean;
  v_percent_hp_damage_applied boolean;
  -- Modificateur de stat (voir autobattle_ability_rules.stat_mod_*) : config
  -- chargée une fois par côté (celle de la capacité EFFECTIVEMENT utilisée
  -- par ce côté), état actif suivi séparément par (camp affecté, stat) car
  -- une capacité peut cibler l'autre camp (débuff) ou soi-même (buff), et les
  -- deux camps peuvent avoir un modificateur actif simultanément sur des
  -- stats différentes. v_*_mod_expires = NULL tant qu'aucun modificateur
  -- n'est actif, sinon numéro de tour (v_turn_no) au-delà duquel il expire
  -- (999999 = jusqu'à la fin du combat, très au-delà du plafond de 200 tours).
  v_player_stat_mod_target       text;
  v_player_stat_mod_stat         text;
  v_player_stat_mod_value_type   text;
  v_player_stat_mod_flat         integer;
  v_player_stat_mod_min          integer;
  v_player_stat_mod_max          integer;
  v_player_stat_mod_percent      integer;
  v_player_stat_mod_duration_type  text;
  v_player_stat_mod_duration_turns integer;
  v_player_stat_mod_max_uses     integer;
  v_player_stat_mod_uses_used    integer := 0;
  v_opponent_stat_mod_target       text;
  v_opponent_stat_mod_stat         text;
  v_opponent_stat_mod_value_type   text;
  v_opponent_stat_mod_flat         integer;
  v_opponent_stat_mod_min          integer;
  v_opponent_stat_mod_max          integer;
  v_opponent_stat_mod_percent      integer;
  v_opponent_stat_mod_duration_type  text;
  v_opponent_stat_mod_duration_turns integer;
  v_opponent_stat_mod_max_uses     integer;
  v_opponent_stat_mod_uses_used    integer := 0;
  v_player_damage_mod_amount     integer := 0;
  v_player_damage_mod_expires    integer;
  v_player_precision_mod_amount  integer := 0;
  v_player_precision_mod_expires integer;
  v_opponent_damage_mod_amount     integer := 0;
  v_opponent_damage_mod_expires    integer;
  v_opponent_precision_mod_amount  integer := 0;
  v_opponent_precision_mod_expires integer;
  v_stat_mod_amount    integer;
  v_stat_mod_expiry    integer;
  v_player_damage_original   integer;
  v_opponent_damage_original integer;
  -- Composante espèce+XP seule (AVANT le multiplicateur de type), exposée
  -- séparément dans le journal des tours (voir 'damage_species_xp' plus bas)
  -- pour reconstruire le détail du calcul en admin (10 × 2 + 4 + dé...).
  v_player_damage_species_xp   integer;
  v_opponent_damage_species_xp integer;
  -- Soin passif (heal_dot) et Anti-Soin (cancel_heal) — voir
  -- autobattle_ability_rules. Config chargée une fois (côté source), état
  -- actif suivi séparément (côté affecté), même logique d'expiration par
  -- numéro de tour que les modificateurs de stat ci-dessus.
  v_player_heal_dot_config_amount    integer;
  v_player_heal_dot_config_turns     integer;
  v_player_heal_dot_config_type      text;
  v_player_heal_dot_config_percent   integer;
  v_opponent_heal_dot_config_amount  integer;
  v_opponent_heal_dot_config_turns   integer;
  v_opponent_heal_dot_config_type    text;
  v_opponent_heal_dot_config_percent integer;
  v_player_heal_dot_amount    integer;
  v_player_heal_dot_expires   integer;
  v_opponent_heal_dot_amount  integer;
  v_opponent_heal_dot_expires integer;
  v_player_cancel_heal_duration    integer;
  v_opponent_cancel_heal_duration  integer;
  v_player_percent_hp_damage_percent   integer;
  v_opponent_percent_hp_damage_percent integer;
  v_player_heal_disabled_expires   integer;
  v_opponent_heal_disabled_expires integer;
  -- Effets ajoutés après coup (voir autobattle_ability_rules et les mêmes
  -- champs sur autobattle_combatant_state, côté moteur partagé) : config
  -- chargée une fois par camp, état actif suivi séparément. En mode Auto la
  -- capacité est FIXE pour tout le combat, ce qui simplifie deux effets :
  --   • 'charge_double_next' alterne charge / double attaque (les deux
  --     activations rejouent forcément la même capacité, contrairement au
  --     Combat Manuel où le joueur en choisit deux différentes) ;
  --   • 'first_and_replay' se réduit à "attaque deux fois" — l'ordre des
  --     tours est une stricte alternance ici, "passer premier" n'a donc de
  --     sens qu'au tirage initial.
  v_player_stat_mod_type_filter    text;
  v_opponent_stat_mod_type_filter  text;
  v_player_damage_mod_type_filter    text;
  v_opponent_damage_mod_type_filter  text;
  v_player_prevention_duration     integer;
  v_opponent_prevention_duration   integer;
  v_player_prevention_expires      integer;
  v_opponent_prevention_expires    integer;
  v_player_keep_going_turns        integer;
  v_player_keep_going_bonus_type   text;
  v_player_keep_going_bonus_flat   integer;
  v_player_keep_going_bonus_percent integer;
  v_opponent_keep_going_turns      integer;
  v_opponent_keep_going_bonus_type text;
  v_opponent_keep_going_bonus_flat integer;
  v_opponent_keep_going_bonus_percent integer;
  v_player_keep_going_count        integer := 0;
  v_player_keep_going_remaining    integer := 0;
  v_opponent_keep_going_count      integer := 0;
  v_opponent_keep_going_remaining  integer := 0;
  v_player_heal_dot_config_until_awake   boolean;
  v_opponent_heal_dot_config_until_awake boolean;
  v_player_heal_dot_until_awake    boolean := false;
  v_opponent_heal_dot_until_awake  boolean := false;
  v_player_ignore_status_block     text;
  v_opponent_ignore_status_block   text;
  v_player_double_turn_pending     boolean := false;
  v_opponent_double_turn_pending   boolean := false;
  v_ignore_block                   boolean;
  v_damage_mod_applied             integer;
  v_prevention_blocked             boolean;
  v_keep_going_bonus               integer;
  -- Cas très spécial : Métamorph copie l'adversaire au début du combat
  -- (visuel, dégâts, capacité, type — jamais les PV, voir requirement dédié).
  -- v_effective_ability_nom remplace p_ability_nom pour tout ce qui suit la
  -- validation d'éligibilité (le joueur doit quand même choisir une capacité
  -- valide dans son propre movepool pour lancer le combat, mais celle
  -- réellement utilisée devient celle de l'adversaire une fois transformé).
  v_is_metamorph          boolean;
  v_is_opponent_metamorph boolean;
  v_effective_ability_nom text;
  v_effective_opponent_ability_nom text;
  v_player_image_override text;
  v_opponent_image_override text;
  v_player_base_damage_component   integer;
  v_opponent_base_damage_component integer;
  v_turn_entry          jsonb;
  v_coin_player_first   boolean;
  v_attacker            text;
  v_turn_no             integer := 0;
  -- N'avance qu'à chaque VRAI changement de tour (quand v_block_remaining
  -- redevient NULL), contrairement à v_turn_no qui avance à CHAQUE
  -- activation — y compris les rafales play_twice/play_three/repeat_until_
  -- fail/play_random, qui restent TOUTES dans le même tour pour le même
  -- camp (voir requirement : ces effets ne font PAS jouer plusieurs tours,
  -- ils réutilisent la capacité plusieurs fois DANS le même tour). Sert de
  -- base à toutes les durées "en tours" (invulnérabilité, modificateurs de
  -- stat, soin passif, Anti-Soin) pour qu'elles survivent une rafale entière
  -- au lieu d'expirer entre deux activations de la même rafale.
  v_round_no            integer := 0;
  v_turns               jsonb := '[]'::jsonb;
  v_outcome             text;
  v_rewards             jsonb := '[]'::jsonb;
  v_reward              record;
  v_max_level_index     integer;
  v_variant_completed   boolean := false;
  v_next_level_index    integer;
  v_new_xp              integer;
  v_max_xp              integer;
BEGIN
  BEGIN
    INSERT INTO autobattle_battles (player_id, level_id, player_pokemon_id, ability_nom, idempotency_key)
    VALUES (p_player_id, p_level_id, p_player_pokemon_id, p_ability_nom, p_idempotency_key)
    RETURNING id INTO v_battle_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('status', 'duplicate_request');
  END;

  SELECT * INTO v_level FROM autobattle_levels WHERE id = p_level_id;
  IF v_level IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;

  SELECT * INTO v_variant FROM autobattle_variants WHERE id = v_level.variant_id;
  IF v_variant IS NULL OR v_variant.enabled = false THEN
    RETURN jsonb_build_object('status', 'variant_disabled');
  END IF;

  INSERT INTO autobattle_player_variant_progress (player_id, variant_id)
  VALUES (p_player_id, v_variant.id)
  ON CONFLICT (player_id, variant_id) DO NOTHING;

  SELECT * INTO v_progress FROM autobattle_player_variant_progress
    WHERE player_id = p_player_id AND variant_id = v_variant.id FOR UPDATE;

  IF v_progress.variant_completed THEN
    RETURN jsonb_build_object('status', 'variant_completed');
  END IF;
  IF v_progress.current_level_index <> v_level.level_index THEN
    RETURN jsonb_build_object('status', 'wrong_level');
  END IF;

  INSERT INTO autobattle_player_level_state (player_id, level_id)
  VALUES (p_player_id, p_level_id)
  ON CONFLICT (player_id, level_id) DO NOTHING;

  PERFORM 1 FROM autobattle_player_level_state
    WHERE player_id = p_player_id AND level_id = p_level_id FOR UPDATE;

  SELECT * INTO v_pp FROM player_pokemon WHERE id = p_player_pokemon_id AND player_id = p_player_id;
  IF v_pp IS NULL THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;
  IF v_pp.in_daycare THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;
  IF NOT (p_ability_nom = ANY(v_pp.moves)) THEN
    RETURN jsonb_build_object('status', 'ineligible_ability');
  END IF;

  SELECT * INTO v_player_species FROM pokemon WHERE nom = v_pp.pokemon_nom;
  SELECT * INTO v_ability FROM attacks WHERE nom = p_ability_nom;
  -- Éligible dès qu'il y a des dégâts de base OU un dé (au moins un des deux
  -- strictement positif) — une capacité à 0 dégâts de base mais avec un dé
  -- reste utilisable, voir isDamagingAbility côté client (src/lib/autoBattle.ts).
  IF v_player_species IS NULL OR v_ability IS NULL
     OR (COALESCE(v_ability.degats_base, 0) <= 0 AND COALESCE(v_ability.degats_de, 0) <= 0) THEN
    RETURN jsonb_build_object('status', 'ineligible_ability');
  END IF;
  IF EXISTS (SELECT 1 FROM autobattle_banned_attacks WHERE attack_nom = p_ability_nom) THEN
    RETURN jsonb_build_object('status', 'ineligible_ability');
  END IF;

  SELECT * INTO v_opponent_species FROM pokemon WHERE nom = v_level.opponent_pokemon_nom;
  SELECT * INTO v_opponent_ability FROM attacks WHERE nom = v_level.opponent_ability_nom;
  IF v_opponent_species IS NULL OR v_opponent_ability IS NULL THEN
    RETURN jsonb_build_object('status', 'invalid_level');
  END IF;

  -- Débite le ticket seulement une fois toutes les validations passées (rien
  -- n'est dépensé sur un statut d'erreur ci-dessus) — le client fait aussi un
  -- débit optimiste "à l'entrée" et le rembourse sur tout statut <> 'ok'.
  UPDATE player_items SET quantity = quantity - 1
    WHERE player_id = p_player_id AND item_nom = v_ticket_item_nom AND quantity >= 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'no_ticket');
  END IF;

  -- Métamorph : copie le visuel/les dégâts/la capacité/le type de
  -- l'ADVERSAIRE pour tout le combat, jamais ses PV — dans UN SENS COMME
  -- DANS L'AUTRE (Métamorph peut être le pokémon du joueur OU celui
  -- configuré comme adversaire d'un niveau). v_player_max_hp/v_level.
  -- opponent_hp restent toujours calculés sur les VRAIES stats du camp
  -- Métamorph, jamais copiés.
  v_is_metamorph := v_player_species.nom = 'Métamorph';
  v_is_opponent_metamorph := v_opponent_species.nom = 'Métamorph';
  v_effective_ability_nom := p_ability_nom;
  v_player_image_override := NULL;
  IF v_is_metamorph THEN
    v_effective_ability_nom := v_level.opponent_ability_nom;
    SELECT * INTO v_ability FROM attacks WHERE nom = v_effective_ability_nom;
    v_player_image_override := v_opponent_species.image_miniature;
  END IF;
  -- Camp adverse Métamorph : copie la capacité RÉELLEMENT jouée par le
  -- joueur (v_effective_ability_nom, déjà résolue ci-dessus si le joueur
  -- est lui-même Métamorph) plutôt que p_ability_nom, pour un
  -- comportement cohérent même dans le cas absurde d'un double Métamorph.
  v_effective_opponent_ability_nom := v_level.opponent_ability_nom;
  v_opponent_image_override := NULL;
  IF v_is_opponent_metamorph THEN
    v_effective_opponent_ability_nom := v_effective_ability_nom;
    SELECT * INTO v_opponent_ability FROM attacks WHERE nom = v_effective_opponent_ability_nom;
    v_opponent_image_override := COALESCE(v_player_image_override, v_player_species.image_miniature);
  END IF;

  v_player_max_hp := COALESCE(v_player_species.pv_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'PV');
  -- Dégâts de base "espèce" de chaque camp (avant dé/capacité/XP) — celui de
  -- Métamorph est remplacé par celui de l'AUTRE camp le cas échéant.
  v_player_base_damage_component := CASE WHEN v_is_metamorph THEN v_level.opponent_base_damage ELSE v_player_species.degats_base END;
  v_opponent_base_damage_component := CASE WHEN v_is_opponent_metamorph THEN v_player_base_damage_component ELSE v_level.opponent_base_damage END;
  -- Super efficace : en plus de la table de types (ci-dessous), la capacité
  -- utilisée doit être du MÊME type que le pokémon qui l'utilise — un
  -- pokémon peut apprendre des capacités d'autres types, mais celles-ci ne
  -- profitent jamais du bonus super efficace, seulement celles qui
  -- correspondent à son propre type (voir requirement).
  v_player_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (CASE WHEN v_is_metamorph THEN v_opponent_species.super_efficace_1 ELSE v_player_species.super_efficace_1 END),
      (CASE WHEN v_is_metamorph THEN v_opponent_species.super_efficace_2 ELSE v_player_species.super_efficace_2 END),
      (CASE WHEN v_is_metamorph THEN v_opponent_species.super_efficace_3 ELSE v_player_species.super_efficace_3 END),
      (CASE WHEN v_is_metamorph THEN v_opponent_species.super_efficace_4 ELSE v_player_species.super_efficace_4 END)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(CASE WHEN v_is_opponent_metamorph THEN v_player_species.type ELSE v_opponent_species.type END))
  ) AND lower(trim(v_ability.type)) = lower(trim(CASE WHEN v_is_metamorph THEN v_opponent_species.type ELSE v_player_species.type END));
  -- Dégâts de base (avant dé) : bonus de type inclus, jamais redoublé par le
  -- dé. Le dé (attacks.degats_de) est retiré au sort à CHAQUE coup dans la
  -- boucle ci-dessous (1..degats_de inclus), pas une seule fois pour tout le
  -- combat — c'est ce qui lui donne son côté aléatoire "à chaque attaque".
  -- Métamorph part du dégât de BASE de l'adversaire (celui configuré pour ce
  -- niveau) plutôt que du sien, mais garde son propre bonus XP (l'XP reste
  -- une progression personnelle, pas quelque chose "copié").
  v_player_damage_species_xp := COALESCE(v_player_base_damage_component, 0)
    + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'DMG');
  v_player_damage := v_player_damage_species_xp
    * (CASE WHEN v_player_type_bonus THEN 2 ELSE 1 END) + COALESCE(v_ability.degats_base, 0);

  v_opponent_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (CASE WHEN v_is_opponent_metamorph THEN v_player_species.super_efficace_1 ELSE v_opponent_species.super_efficace_1 END),
      (CASE WHEN v_is_opponent_metamorph THEN v_player_species.super_efficace_2 ELSE v_opponent_species.super_efficace_2 END),
      (CASE WHEN v_is_opponent_metamorph THEN v_player_species.super_efficace_3 ELSE v_opponent_species.super_efficace_3 END),
      (CASE WHEN v_is_opponent_metamorph THEN v_player_species.super_efficace_4 ELSE v_opponent_species.super_efficace_4 END)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(CASE WHEN v_is_metamorph THEN v_opponent_species.type ELSE v_player_species.type END))
  ) AND lower(trim(v_opponent_ability.type)) = lower(trim(CASE WHEN v_is_opponent_metamorph THEN v_player_species.type ELSE v_opponent_species.type END));
  v_opponent_damage_species_xp := COALESCE(v_opponent_base_damage_component, 0);
  v_opponent_damage := v_opponent_damage_species_xp * (CASE WHEN v_opponent_type_bonus THEN 2 ELSE 1 END)
    + COALESCE(v_opponent_ability.degats_base, 0);
  -- Référence fixe pour tout le combat, utilisée par stat_mod_value_type =
  -- 'percent' (voir autobattle_ability_rules.stat_mod_percent) — jamais
  -- recalculée même si v_player_damage/v_opponent_damage venaient à changer
  -- (ce qui n'arrive pas : seul le montant final PAR COUP change via
  -- v_*_damage_mod_amount, la base elle-même reste constante).
  v_player_damage_original := v_player_damage;
  v_opponent_damage_original := v_opponent_damage;

  -- Effet de soin éventuel de chaque capacité (statique, % des dégâts
  -- infligés ce tour-là, ou "utilise ses propres stats" — dégâts de base +
  -- un dé indépendant de la capacité elle-même) — indépendant de l'effet sur
  -- le rythme des tours, voir autobattle_ability_rules. NULL si aucune règle
  -- configurée.
  SELECT heal_type, heal_amount, heal_percent, turn_effect, repeat_max_iterations, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_player_heal_type, v_player_heal_amount, v_player_heal_percent, v_player_turn_effect, v_player_repeat_max, v_player_status_reversed,
         v_player_recoil_type, v_player_recoil_min, v_player_recoil_max, v_player_recoil_percent, v_player_invuln_grant,
         v_player_bonus_type, v_player_bonus_multiplier, v_player_bonus_flat, v_player_bonus_min, v_player_bonus_max,
         v_player_bonus_condition, v_player_bonus_dice_value, v_player_bonus_status_filter,
         v_player_stat_mod_target, v_player_stat_mod_stat, v_player_stat_mod_value_type, v_player_stat_mod_flat, v_player_stat_mod_min, v_player_stat_mod_max, v_player_stat_mod_percent,
         v_player_stat_mod_duration_type, v_player_stat_mod_duration_turns, v_player_stat_mod_max_uses,
         v_player_heal_dot_config_amount, v_player_heal_dot_config_turns, v_player_heal_dot_config_type, v_player_heal_dot_config_percent, v_player_cancel_heal_duration, v_player_percent_hp_damage_percent,
         v_player_stat_mod_type_filter, v_player_prevention_duration,
         v_player_keep_going_turns, v_player_keep_going_bonus_type, v_player_keep_going_bonus_flat, v_player_keep_going_bonus_percent,
         v_player_heal_dot_config_until_awake, v_player_ignore_status_block
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_ability_nom;
  v_player_status_reversed := COALESCE(v_player_status_reversed, false);
  v_player_invuln_grant := COALESCE(v_player_invuln_grant, false);
  v_player_heal_dot_config_until_awake := COALESCE(v_player_heal_dot_config_until_awake, false);

  SELECT heal_type, heal_amount, heal_percent, turn_effect, repeat_max_iterations, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_opponent_heal_type, v_opponent_heal_amount, v_opponent_heal_percent, v_opponent_turn_effect, v_opponent_repeat_max, v_opponent_status_reversed,
         v_opponent_recoil_type, v_opponent_recoil_min, v_opponent_recoil_max, v_opponent_recoil_percent, v_opponent_invuln_grant,
         v_opponent_bonus_type, v_opponent_bonus_multiplier, v_opponent_bonus_flat, v_opponent_bonus_min, v_opponent_bonus_max,
         v_opponent_bonus_condition, v_opponent_bonus_dice_value, v_opponent_bonus_status_filter,
         v_opponent_stat_mod_target, v_opponent_stat_mod_stat, v_opponent_stat_mod_value_type, v_opponent_stat_mod_flat, v_opponent_stat_mod_min, v_opponent_stat_mod_max, v_opponent_stat_mod_percent,
         v_opponent_stat_mod_duration_type, v_opponent_stat_mod_duration_turns, v_opponent_stat_mod_max_uses,
         v_opponent_heal_dot_config_amount, v_opponent_heal_dot_config_turns, v_opponent_heal_dot_config_type, v_opponent_heal_dot_config_percent, v_opponent_cancel_heal_duration, v_opponent_percent_hp_damage_percent,
         v_opponent_stat_mod_type_filter, v_opponent_prevention_duration,
         v_opponent_keep_going_turns, v_opponent_keep_going_bonus_type, v_opponent_keep_going_bonus_flat, v_opponent_keep_going_bonus_percent,
         v_opponent_heal_dot_config_until_awake, v_opponent_ignore_status_block
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_opponent_ability_nom;
  v_opponent_status_reversed := COALESCE(v_opponent_status_reversed, false);
  v_opponent_invuln_grant := COALESCE(v_opponent_invuln_grant, false);
  v_opponent_heal_dot_config_until_awake := COALESCE(v_opponent_heal_dot_config_until_awake, false);

  -- Précision "aucune" (NULL ou 0, case vide/"0" dans le CSV) = capacité qui
  -- ne peut JAMAIS rater, immunisée contre peur/confusion ET contre le
  -- désactivateur global précision_enabled — distinct d'une précision
  -- explicite de 10 (100% par défaut mais toujours réductible par un statut).
  v_player_never_miss := v_ability.precision IS NULL OR v_ability.precision = 0;
  v_opponent_never_miss := v_opponent_ability.precision IS NULL OR v_opponent_ability.precision = 0;

  -- Système de précision (requirement : attacks.precision 1-10, NULL = 10 =
  -- 100%, désactivable globalement via autobattle_config.precision_enabled,
  -- auquel cas toute capacité touche systématiquement).
  SELECT precision_enabled INTO v_precision_enabled FROM autobattle_config WHERE id = 1;
  v_precision_enabled := COALESCE(v_precision_enabled, true);

  v_player_hp := GREATEST(1, v_player_max_hp);
  v_opponent_hp := v_level.opponent_hp;
  v_coin_player_first := random() < 0.5;
  v_attacker := CASE WHEN v_coin_player_first THEN 'player' ELSE 'opponent' END;
  v_block_remaining := NULL;
  v_player_status := NULL;
  v_opponent_status := NULL;

  -- Boucle de tours : par défaut chaque côté joue un coup puis cède la main,
  -- mais une capacité peut porter un effet spécial. 'play_twice'/'play_three'/
  -- 'play_random' (via autobattle_ability_burst) font jouer son utilisateur
  -- plusieurs fois d'affilée avant que le tour ne passe à l'autre côté.
  -- 'skip' est différent : ce n'est PAS "ne jamais attaquer" mais une
  -- alternance — la capacité s'utilise normalement, puis le PROCHAIN tour de
  -- ce même côté est passé (v_*_skip_pending), avant de reprendre un cycle
  -- attaque/passe. Suivi indépendamment par côté puisque seul un côté peut
  -- avoir une capacité à effet 'skip'. 'repeat_until_fail' initialise
  -- v_block_remaining à repeat_max_iterations (comme 'play_random'), mais le
  -- PREMIER raté (v_missed, voir plus bas) force v_block_remaining à 1 pour
  -- interrompre la série immédiatement au lieu d'épuiser le compteur.
  LOOP
    v_turn_no := v_turn_no + 1;
    -- v_round_no n'avance que sur un VRAI nouveau tour (v_block_remaining
    -- valait NULL à la fin de l'itération précédente, ou c'est la 1ère) —
    -- une rafale (v_block_remaining non NULL) reste tout entière dans le
    -- même tour. Doit être fait ICI, AVANT les expirations ci-dessous, pour
    -- qu'elles voient déjà la valeur à jour de ce tour.
    IF v_block_remaining IS NULL THEN
      v_round_no := v_round_no + 1;
    END IF;

    -- Le bouclier d'invulnérabilité dure jusqu'au DÉBUT du prochain tour de
    -- son propriétaire (avant que sa capacité ne soit résolue), pas "1
    -- activation" : il bloque donc TOUTE la prochaine rafale adverse s'il y
    -- en a une, voir plus bas (v_player_invulnerable est revérifié à chaque
    -- activation, jamais consommé en un coup). Ici, on ne fait qu'EXPIRER le
    -- bouclier — accordé au tour v_round_no = N, il doit rester actif tout le
    -- tour adverse N+1, et s'éteindre pile au tour N+2 (le prochain tour du
    -- propriétaire), donc dès que v_round_no dépasse N+1. Vérifié à CHAQUE
    -- itération sans exception (sans effet pendant une rafale, où v_round_no
    -- n'a pas encore changé).
    IF v_player_invulnerable AND v_player_invuln_granted_round IS NOT NULL AND v_round_no > v_player_invuln_granted_round + 1 THEN
      v_player_invulnerable := false;
      v_player_invuln_granted_round := NULL;
    END IF;
    IF v_opponent_invulnerable AND v_opponent_invuln_granted_round IS NOT NULL AND v_round_no > v_opponent_invuln_granted_round + 1 THEN
      v_opponent_invulnerable := false;
      v_opponent_invuln_granted_round := NULL;
    END IF;

    -- Expiration des modificateurs de stat / soin passif / Anti-Soin, tous
    -- suivis par NUMÉRO DE TOUR (v_round_no, pas v_turn_no — même raison que
    -- l'invulnérabilité juste au-dessus : une durée "en tours" ne doit pas
    -- pouvoir expirer AU MILIEU d'une rafale, seulement entre deux tours
    -- réels) — vérifié à CHAQUE itération sans exception.
    IF v_player_damage_mod_expires IS NOT NULL AND v_round_no > v_player_damage_mod_expires THEN
      v_player_damage_mod_amount := 0; v_player_damage_mod_expires := NULL; v_player_damage_mod_type_filter := NULL;
    END IF;
    IF v_player_precision_mod_expires IS NOT NULL AND v_round_no > v_player_precision_mod_expires THEN
      v_player_precision_mod_amount := 0; v_player_precision_mod_expires := NULL;
    END IF;
    IF v_opponent_damage_mod_expires IS NOT NULL AND v_round_no > v_opponent_damage_mod_expires THEN
      v_opponent_damage_mod_amount := 0; v_opponent_damage_mod_expires := NULL; v_opponent_damage_mod_type_filter := NULL;
    END IF;
    IF v_opponent_precision_mod_expires IS NOT NULL AND v_round_no > v_opponent_precision_mod_expires THEN
      v_opponent_precision_mod_amount := 0; v_opponent_precision_mod_expires := NULL;
    END IF;
    IF v_player_heal_dot_expires IS NOT NULL AND v_round_no > v_player_heal_dot_expires THEN
      v_player_heal_dot_amount := NULL; v_player_heal_dot_expires := NULL;
    END IF;
    IF v_opponent_heal_dot_expires IS NOT NULL AND v_round_no > v_opponent_heal_dot_expires THEN
      v_opponent_heal_dot_amount := NULL; v_opponent_heal_dot_expires := NULL;
    END IF;
    IF v_player_heal_disabled_expires IS NOT NULL AND v_round_no > v_player_heal_disabled_expires THEN
      v_player_heal_disabled_expires := NULL;
    END IF;
    IF v_opponent_heal_disabled_expires IS NOT NULL AND v_round_no > v_opponent_heal_disabled_expires THEN
      v_opponent_heal_disabled_expires := NULL;
    END IF;
    -- Bouclier Prévention et soin passif "jusqu'au réveil" (voir
    -- autobattle_ability_rules) — même logique que le moteur partagé
    -- autobattle_resolve_round_core.
    IF v_player_prevention_expires IS NOT NULL AND v_round_no > v_player_prevention_expires THEN
      v_player_prevention_expires := NULL;
    END IF;
    IF v_opponent_prevention_expires IS NOT NULL AND v_round_no > v_opponent_prevention_expires THEN
      v_opponent_prevention_expires := NULL;
    END IF;
    IF v_player_heal_dot_until_awake AND COALESCE(v_player_status, '') <> 'sleep' THEN
      v_player_heal_dot_amount := NULL; v_player_heal_dot_until_awake := false;
    END IF;
    IF v_opponent_heal_dot_until_awake AND COALESCE(v_opponent_status, '') <> 'sleep' THEN
      v_opponent_heal_dot_amount := NULL; v_opponent_heal_dot_until_awake := false;
    END IF;

    -- "A subi des dégâts au dernier tour adverse" (bonus_damage_condition
    -- 'took_damage_last_turn') doit refléter EXACTEMENT le tour précédent de
    -- l'attaquant adverse — pas un vieux coup réussi resté vrai depuis
    -- plusieurs tours pendant que l'adversaire préparait/soignait/ratait
    -- entretemps. Remis à faux ICI, à CHAQUE itération sans exception (avant
    -- même de savoir si ce tour est raté/passé/statut/réussi), pour le camp
    -- qui va agir ce tour-ci — seul le vrai coup réussi plus bas le repasse à
    -- vrai le cas échéant ; un raté/tick de statut/tour passé le laisse à
    -- faux, comme attendu.
    IF v_attacker = 'player' THEN
      v_opponent_took_damage := false;
    ELSE
      v_player_took_damage := false;
    END IF;

    IF v_block_remaining IS NULL THEN
      v_status_precision_penalty := 0;
      -- Capacité utilisable malgré UN statut bloquant précis — voir le même
      -- commentaire dans autobattle_resolve_round_core.
      v_ignore_block := COALESCE(
        (CASE WHEN v_attacker = 'player' THEN v_player_ignore_status_block ELSE v_opponent_ignore_status_block END)
          = (CASE WHEN v_attacker = 'player' THEN v_player_status ELSE v_opponent_status END),
        false);

      -- Statut actif infligé par une capacité adverse précédente (voir plus
      -- bas "application du statut après un coup") : traité en tout premier,
      -- avant même l'effet de tour propre à la capacité de ce côté
      -- (turn_effect), car un statut peut annuler ce tour (paralysie/gel/
      -- sommeil), l'affaiblir (peur/confusion) ou infliger des dégâts passifs
      -- (brûlure/poison) indépendamment de ce que fait sa propre capacité.
      -- Un seul statut actif à la fois par côté : en appliquer un nouveau
      -- remplace l'ancien (voir plus bas), pas de cumul.
      IF v_attacker = 'player' AND v_player_status IN ('paralysis', 'frozen') THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', NOT v_ignore_block,
          'status_tick', true, 'status', v_player_status, 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        v_player_status := NULL;
        IF NOT v_ignore_block THEN
          -- Paralysie/gel n'empêchent QUE l'usage de la capacité : les effets
          -- passifs (soin par tour) doivent quand même tiquer avant de rendre
          -- la main, sinon un tour sauté annulerait aussi le passif.
          IF v_player_heal_dot_amount IS NOT NULL
             AND (v_player_heal_disabled_expires IS NULL OR v_round_no > v_player_heal_disabled_expires) THEN
            v_turn_no := v_turn_no + 1;
            v_player_hp := LEAST(v_player_max_hp, v_player_hp + v_player_heal_dot_amount);
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_player_heal_dot_amount,
              'attacker_hp_after', v_player_hp, 'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
            ));
          END IF;
          v_attacker := 'opponent';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        END IF;
        v_turn_no := v_turn_no + 1;
      ELSIF v_attacker = 'opponent' AND v_opponent_status IN ('paralysis', 'frozen') THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', NOT v_ignore_block,
          'status_tick', true, 'status', v_opponent_status, 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        v_opponent_status := NULL;
        IF NOT v_ignore_block THEN
          -- idem côté adverse : le passif tique malgré le tour sauté.
          IF v_opponent_heal_dot_amount IS NOT NULL
             AND (v_opponent_heal_disabled_expires IS NULL OR v_round_no > v_opponent_heal_disabled_expires) THEN
            v_turn_no := v_turn_no + 1;
            v_opponent_hp := LEAST(v_level.opponent_hp, v_opponent_hp + v_opponent_heal_dot_amount);
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_opponent_heal_dot_amount,
              'attacker_hp_after', v_opponent_hp, 'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
            ));
          END IF;
          v_attacker := 'player';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        END IF;
        v_turn_no := v_turn_no + 1;

      -- Sommeil : le dé décide DIRECTEMENT du sort de CE tick — guéri
      -- (status_cured), l'effet n'a jamais lieu cette fois-ci et le tour se
      -- joue normalement (pas de 'skipped', enchaîne sur l'attaque juste en
      -- dessous) ; pas guéri, le tour est passé. Contrairement à la brûlure
      -- (dégâts toujours infligés, dé uniquement pour la prochaine fois), le
      -- sommeil peut donc n'avoir eu AUCUN impact si la guérison tombe dès
      -- le premier jet — comportement voulu, pas un bug.
      ELSIF v_attacker = 'player' AND v_player_status = 'sleep' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', NOT v_status_cured AND NOT v_ignore_block,
          'status_tick', true, 'status', 'sleep', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_status_cured THEN
          v_player_status := NULL;
          v_turn_no := v_turn_no + 1;
        ELSIF v_ignore_block THEN
          v_turn_no := v_turn_no + 1;
        ELSE
          -- Le soin passif tique aussi pendant le sommeil (même raison que
          -- paralysie/gel plus haut) — c'est ce qui rend possible un soin
          -- passif "jusqu'au réveil", qui ne tique que sur des tours dormis.
          IF v_player_heal_dot_amount IS NOT NULL
             AND (v_player_heal_disabled_expires IS NULL OR v_round_no > v_player_heal_disabled_expires) THEN
            v_turn_no := v_turn_no + 1;
            v_player_hp := LEAST(v_player_max_hp, v_player_hp + v_player_heal_dot_amount);
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_player_heal_dot_amount,
              'attacker_hp_after', v_player_hp, 'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
            ));
          END IF;
          v_attacker := 'opponent';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_status = 'sleep' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', NOT v_status_cured AND NOT v_ignore_block,
          'status_tick', true, 'status', 'sleep', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_status_cured THEN
          v_opponent_status := NULL;
          v_turn_no := v_turn_no + 1;
        ELSIF v_ignore_block THEN
          v_turn_no := v_turn_no + 1;
        ELSE
          IF v_opponent_heal_dot_amount IS NOT NULL
             AND (v_opponent_heal_disabled_expires IS NULL OR v_round_no > v_opponent_heal_disabled_expires) THEN
            v_turn_no := v_turn_no + 1;
            v_opponent_hp := LEAST(v_level.opponent_hp, v_opponent_hp + v_opponent_heal_dot_amount);
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_opponent_heal_dot_amount,
              'attacker_hp_after', v_opponent_hp, 'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
            ));
          END IF;
          v_attacker := 'player';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        END IF;

      ELSIF v_attacker = 'player' AND v_player_status = 'burn' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_player_hp := v_player_hp - 5;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 5, 'skipped', false,
          'status_tick', true, 'status', 'burn', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'attacker_hp_after', GREATEST(0, v_player_hp), 'defender_hp_after', GREATEST(0, v_opponent_hp),
          'ko', v_player_hp <= 0
        ));
        IF v_status_cured THEN v_player_status := NULL; END IF;
        IF v_player_hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
        v_turn_no := v_turn_no + 1;
      ELSIF v_attacker = 'opponent' AND v_opponent_status = 'burn' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_opponent_hp := v_opponent_hp - 5;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 5, 'skipped', false,
          'status_tick', true, 'status', 'burn', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'attacker_hp_after', GREATEST(0, v_opponent_hp), 'defender_hp_after', GREATEST(0, v_player_hp),
          'ko', v_opponent_hp <= 0
        ));
        IF v_status_cured THEN v_opponent_status := NULL; END IF;
        IF v_opponent_hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
        v_turn_no := v_turn_no + 1;

      ELSIF v_attacker = 'player' AND v_player_status = 'poison' THEN
        v_player_hp := v_player_hp - 3;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 3, 'skipped', false,
          'status_tick', true, 'status', 'poison', 'status_cured', false,
          'attacker_hp_after', GREATEST(0, v_player_hp), 'defender_hp_after', GREATEST(0, v_opponent_hp),
          'ko', v_player_hp <= 0
        ));
        IF v_player_hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
        v_turn_no := v_turn_no + 1;
      ELSIF v_attacker = 'opponent' AND v_opponent_status = 'poison' THEN
        v_opponent_hp := v_opponent_hp - 3;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 3, 'skipped', false,
          'status_tick', true, 'status', 'poison', 'status_cured', false,
          'attacker_hp_after', GREATEST(0, v_opponent_hp), 'defender_hp_after', GREATEST(0, v_player_hp),
          'ko', v_opponent_hp <= 0
        ));
        IF v_opponent_hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
        v_turn_no := v_turn_no + 1;

      ELSIF v_attacker = 'player' AND v_player_status = 'fear' THEN
        v_status_precision_penalty := 5;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
          'status_tick', true, 'status', 'fear', 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        v_player_status := NULL;
        v_turn_no := v_turn_no + 1;
      ELSIF v_attacker = 'opponent' AND v_opponent_status = 'fear' THEN
        v_status_precision_penalty := 5;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
          'status_tick', true, 'status', 'fear', 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        v_opponent_status := NULL;
        v_turn_no := v_turn_no + 1;

      -- Confusion : comme le sommeil, un dé décide DIRECTEMENT du sort de CE
      -- tick — guérie, aucune pénalité n'est appliquée à l'attaque qui suit
      -- (comme si le camp n'avait pas été confus du tout ce tour-ci) ; pas
      -- guérie, la pénalité de précision s'applique à l'attaque de ce même
      -- camp qui suit immédiatement. Ne fait JAMAIS passer le tour (à la
      -- différence du sommeil) : contrairement à la brûlure (effet toujours
      -- infligé), la confusion peut donc n'avoir eu AUCUN impact si la
      -- guérison tombe dès le premier jet — comportement voulu.
      ELSIF v_attacker = 'player' AND v_player_status = 'confusion' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
          'status_tick', true, 'status', 'confusion', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_status_cured THEN v_player_status := NULL; ELSE v_status_precision_penalty := 5; END IF;
        v_turn_no := v_turn_no + 1;
      ELSIF v_attacker = 'opponent' AND v_opponent_status = 'confusion' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
          'status_tick', true, 'status', 'confusion', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_status_cured THEN v_opponent_status := NULL; ELSE v_status_precision_penalty := 5; END IF;
        v_turn_no := v_turn_no + 1;
      END IF;

      -- Soin passif (heal_dot, voir autobattle_ability_rules) : indépendant
      -- du statut ci-dessus (peut être actif en même temps), s'applique en
      -- plus au tout début du tour propre de ce côté, sans faire passer le
      -- tour ni changer d'attaquant — juste un "tick" de plus qui consomme un
      -- numéro de tour, comme brûlure/poison, sauf qu'il soigne au lieu de
      -- blesser et n'est jamais annulé par un statut. Bloqué si un Anti-Soin
      -- adverse est actif (v_*_heal_disabled_expires).
      IF v_attacker = 'player' AND v_player_heal_dot_amount IS NOT NULL
         AND (NOT v_player_heal_dot_until_awake OR COALESCE(v_player_status, '') = 'sleep')
         AND (v_player_heal_disabled_expires IS NULL OR v_round_no > v_player_heal_disabled_expires) THEN
        v_player_hp := LEAST(v_player_max_hp, v_player_hp + v_player_heal_dot_amount);
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
          'heal_dot_tick', true, 'heal', v_player_heal_dot_amount,
          'attacker_hp_after', v_player_hp, 'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_player_status = 'poison' THEN v_player_status := NULL; END IF;
        v_turn_no := v_turn_no + 1;
      ELSIF v_attacker = 'opponent' AND v_opponent_heal_dot_amount IS NOT NULL
         AND (NOT v_opponent_heal_dot_until_awake OR COALESCE(v_opponent_status, '') = 'sleep')
         AND (v_opponent_heal_disabled_expires IS NULL OR v_round_no > v_opponent_heal_disabled_expires) THEN
        v_opponent_hp := LEAST(v_level.opponent_hp, v_opponent_hp + v_opponent_heal_dot_amount);
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
          'heal_dot_tick', true, 'heal', v_opponent_heal_dot_amount,
          'attacker_hp_after', v_opponent_hp, 'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_opponent_status = 'poison' THEN v_opponent_status := NULL; END IF;
        v_turn_no := v_turn_no + 1;
      END IF;

      -- Chaîne "Continue sur sa lancée" (voir autobattle_ability_rules.
      -- keep_going_turns) : en mode Auto la capacité est la même à chaque
      -- tour, le compteur suit donc simplement le nombre d'utilisations
      -- consécutives — bonus cumulatif jusqu'à épuisement de la chaîne, puis
      -- remise à zéro. keep_going_count = numéro de l'utilisation en cours
      -- (1 = pas de bonus).
      IF v_attacker = 'player' AND v_player_keep_going_turns IS NOT NULL THEN
        IF v_player_keep_going_remaining <= 0 THEN
          v_player_keep_going_count := 1;
          v_player_keep_going_remaining := v_player_keep_going_turns;
        ELSE
          v_player_keep_going_count := v_player_keep_going_count + 1;
          v_player_keep_going_remaining := v_player_keep_going_remaining - 1;
        END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_keep_going_turns IS NOT NULL THEN
        IF v_opponent_keep_going_remaining <= 0 THEN
          v_opponent_keep_going_count := 1;
          v_opponent_keep_going_remaining := v_opponent_keep_going_turns;
        ELSE
          v_opponent_keep_going_count := v_opponent_keep_going_count + 1;
          v_opponent_keep_going_remaining := v_opponent_keep_going_remaining - 1;
        END IF;
      END IF;

      IF v_attacker = 'player' AND v_player_turn_effect = 'skip' THEN
        IF v_player_skip_pending THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', true,
            'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
          ));
          v_player_skip_pending := false;
          v_attacker := 'opponent';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        ELSE
          v_block_remaining := 1;
          v_player_skip_pending := true;
        END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_turn_effect = 'skip' THEN
        IF v_opponent_skip_pending THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', true,
            'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
          ));
          v_opponent_skip_pending := false;
          v_attacker := 'player';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        ELSE
          v_block_remaining := 1;
          v_opponent_skip_pending := true;
        END IF;
      ELSIF v_attacker = 'player' AND v_player_turn_effect = 'repeat_until_fail' THEN
        v_block_remaining := GREATEST(1, COALESCE(v_player_repeat_max, 6));
      ELSIF v_attacker = 'opponent' AND v_opponent_turn_effect = 'repeat_until_fail' THEN
        v_block_remaining := GREATEST(1, COALESCE(v_opponent_repeat_max, 6));
      -- 'prepare_release' : deux tours pour une seule attaque — le premier
      -- ne fait rien d'autre qu'afficher "Préparation" (turn.preparing),
      -- le second joue l'attaque normalement (block=1, comme si de rien
      -- n'était). v_*_preparing retient où on en est d'une activation à
      -- l'autre. Si la capacité rend aussi invulnérable (invulnerable_next_
      -- turn), le bouclier est accordé DÈS la préparation (protège le tour
      -- adverse qui suit immédiatement), pas à la libération — voir plus bas
      -- où l'octroi normal à l'attaque est sauté pour 'prepare_release'
      -- (déjà accordé ici, ne pas le refaire/le repousser à la libération).
      ELSIF v_attacker = 'player' AND v_player_turn_effect = 'prepare_release' THEN
        IF v_player_preparing THEN
          v_player_preparing := false;
          v_block_remaining := 1;
        ELSE
          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', true, 'preparing', true,
            'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
          );
          IF v_player_invuln_grant THEN
            v_player_invulnerable := true;
            v_player_invuln_granted_round := v_round_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry);
          v_player_preparing := true;
          v_attacker := 'opponent';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_turn_effect = 'prepare_release' THEN
        IF v_opponent_preparing THEN
          v_opponent_preparing := false;
          v_block_remaining := 1;
        ELSE
          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', true, 'preparing', true,
            'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
          );
          IF v_opponent_invuln_grant THEN
            v_opponent_invulnerable := true;
            v_opponent_invuln_granted_round := v_round_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry);
          v_opponent_preparing := true;
          v_attacker := 'player';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        END IF;

      -- 'charge_double_next' : un tour de charge (turn.charging, aucun effet)
      -- puis, au prochain tour de ce camp, DEUX activations d'affilée. En
      -- mode Auto la capacité est fixe : les deux activations sont forcément
      -- la même capacité (en Combat Manuel/PvP, le joueur en choisit deux
      -- différentes — voir autobattle_resolve_round_core). Le cycle
      -- recommence ensuite (charge, double, charge, double...).
      ELSIF v_attacker = 'player' AND v_player_turn_effect = 'charge_double_next' THEN
        IF v_player_double_turn_pending THEN
          v_player_double_turn_pending := false;
          v_block_remaining := 2;
        ELSE
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', true, 'charging', true,
            'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
          ));
          v_player_double_turn_pending := true;
          v_attacker := 'opponent';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_turn_effect = 'charge_double_next' THEN
        IF v_opponent_double_turn_pending THEN
          v_opponent_double_turn_pending := false;
          v_block_remaining := 2;
        ELSE
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', true, 'charging', true,
            'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
          ));
          v_opponent_double_turn_pending := true;
          v_attacker := 'player';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        END IF;

      -- 'first_and_replay' : la capacité ne consomme pas le tour, son
      -- utilisateur rejoue dans la foulée. En mode Auto (capacité fixe, ordre
      -- des tours en stricte alternance) cela revient exactement à jouer deux
      -- fois de suite — le volet "passe premier" n'a de sens qu'en Combat
      -- Manuel/PvP, où l'ordre des tours est persisté d'un round à l'autre.
      ELSIF v_attacker = 'player' AND v_player_turn_effect = 'first_and_replay' THEN
        v_block_remaining := 2;
      ELSIF v_attacker = 'opponent' AND v_opponent_turn_effect = 'first_and_replay' THEN
        v_block_remaining := 2;

      ELSE
        v_block_remaining := autobattle_ability_burst(CASE WHEN v_attacker = 'player' THEN v_effective_ability_nom ELSE v_effective_opponent_ability_nom END);
        IF v_block_remaining = 0 THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', v_attacker, 'damage', 0, 'skipped', true,
            'defender_hp_after', CASE WHEN v_attacker = 'player' THEN GREATEST(0, v_opponent_hp) ELSE GREATEST(0, v_player_hp) END,
            'ko', false
          ));
          v_attacker := CASE WHEN v_attacker = 'player' THEN 'opponent' ELSE 'player' END;
          v_block_remaining := NULL;
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        END IF;
      END IF;
    END IF;

    IF v_attacker = 'player' THEN
      -- Invulnérabilité de l'adversaire : rate automatiquement, ignore
      -- précision/statuts entièrement — MAIS seulement si la capacité jouée
      -- affecte réellement l'adversaire (dégâts, statut qui lui est infligé,
      -- modificateur de stat qui le cible, ou Anti-Soin posé sur lui) ; une
      -- capacité auto-ciblée (soin sur soi, buff sur soi, invulnérabilité sur
      -- soi...) n'a rien à bloquer et se résout normalement. RE-vérifié à
      -- CHAQUE activation (jamais "consommé" en un coup, voir v_opponent_
      -- invulnerable ci-dessus) : bloque donc TOUTE une éventuelle rafale
      -- adverse (play_twice/play_three/...), pas seulement son 1er coup —
      -- le bouclier lui-même n'expire que via le compteur de tours plus haut
      -- (v_round_no), au début du prochain tour de son propriétaire.
      IF v_opponent_invulnerable AND (
        v_ability.deals_damage
        OR (v_ability.status_effect IS NOT NULL AND NOT v_player_status_reversed)
        OR v_player_stat_mod_target = 'opponent'
        OR v_player_cancel_heal_duration IS NOT NULL
      ) THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true, 'invulnerable_miss', true,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_player_turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
        -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
        -- cesse d'être imposée, le tour suivant redevient un choix libre.
        IF v_player_keep_going_turns IS NOT NULL THEN
          v_player_keep_going_remaining := 0;
          v_player_keep_going_count := 0;
        END IF;
      ELSE
        v_missed := (NOT v_player_never_miss) AND
          random() >= ((CASE WHEN v_precision_enabled THEN GREATEST(0, COALESCE(v_ability.precision, 10) - v_status_precision_penalty + v_player_precision_mod_amount) ELSE 10 END * 10) / 100.0);

        IF v_missed THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true,
            'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false,
            'precision_mod_amount', v_player_precision_mod_amount
          ));
          -- 'repeat_until_fail' : le premier raté met fin à la série en
          -- cours, même s'il reste des activations dans v_block_remaining —
          -- on force le passage de tour via la décrémentation générique.
          IF v_player_turn_effect = 'repeat_until_fail' THEN
            v_block_remaining := 1;
          END IF;
          -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
          -- cesse d'être imposée, le tour suivant redevient un choix libre.
          IF v_player_keep_going_turns IS NOT NULL THEN
            v_player_keep_going_remaining := 0;
            v_player_keep_going_count := 0;
          END IF;
        ELSE
          -- Capacités non-offensives (attacks.deals_damage = false, voir CSV
          -- "Inflige dégâts") : aucun dégât, même passif (espèce+XP du
          -- pokémon) — les systèmes de modification de dégâts (% PV, bonus
          -- conditionnels) ne s'appliquent donc pas non plus, ils n'auraient
          -- rien à modifier.
          -- Modificateur de dégâts actif : ignoré si son filtre de type (voir
          -- autobattle_ability_rules.stat_mod_type_filter) ne correspond pas
          -- au type de la capacité jouée.
          v_damage_mod_applied := CASE
            WHEN v_player_damage_mod_type_filter IS NULL
              OR lower(trim(v_player_damage_mod_type_filter)) = lower(trim(COALESCE(v_ability.type, '')))
            THEN v_player_damage_mod_amount ELSE 0 END;
          -- Bouclier Prévention de la cible : annule les dégâts ADDITIONNELS
          -- dus au bonus super efficace (la composante espèce+XP est comptée
          -- une fois au lieu de deux), le reste du coup est inchangé.
          v_prevention_blocked := v_player_type_bonus
            AND v_opponent_prevention_expires IS NOT NULL AND v_round_no <= v_opponent_prevention_expires;
          v_keep_going_bonus := 0;
          IF v_ability.deals_damage THEN
            v_hit_dice := CASE WHEN v_ability.degats_de IS NOT NULL AND v_ability.degats_de > 0
              THEN 1 + floor(random() * v_ability.degats_de)::integer ELSE 0 END;
            v_hit_damage := GREATEST(0, v_player_damage
              - (CASE WHEN v_prevention_blocked THEN v_player_damage_species_xp ELSE 0 END)
              + v_hit_dice + v_damage_mod_applied);

            -- Dégâts en % des PV restants (voir autobattle_ability_rules.
            -- percent_hp_damage_percent) : remplace ENTIÈREMENT le calcul
            -- ci-dessus, basé sur les PV ACTUELS de la cible avant ce coup —
            -- les dégâts additionnels conditionnels/contre-coup/soin
            -- s'appliquent ensuite normalement sur ce nouveau total.
            v_percent_hp_damage_applied := v_player_percent_hp_damage_percent IS NOT NULL;
            IF v_percent_hp_damage_applied THEN
              v_hit_damage := GREATEST(0, floor(v_opponent_hp * v_player_percent_hp_damage_percent / 100.0)::integer);
            END IF;

            -- Dégâts additionnels conditionnels (voir bonus_damage_* et les 4
            -- conditions possibles) — appliqués après le dé, avant le
            -- contre-coup.
            v_bonus_condition_met := v_player_bonus_condition = 'took_damage_last_turn' AND v_player_took_damage
              OR v_player_bonus_condition = 'first_use' AND NOT v_player_used_ability
              OR v_player_bonus_condition = 'dice_equals' AND v_hit_dice = v_player_bonus_dice_value
              OR v_player_bonus_condition = 'has_status' AND v_opponent_status IS NOT NULL AND (v_player_bonus_status_filter IS NULL OR v_opponent_status = v_player_bonus_status_filter);
            IF v_player_bonus_type IS NOT NULL AND v_bonus_condition_met THEN
              IF v_player_bonus_type = 'multiply' THEN
                v_hit_damage := floor(v_hit_damage * COALESCE(v_player_bonus_multiplier, 1))::integer;
              ELSIF v_player_bonus_type = 'flat' THEN
                v_hit_damage := v_hit_damage + COALESCE(v_player_bonus_flat, 0);
              ELSIF v_player_bonus_type = 'range' THEN
                v_hit_damage := v_hit_damage + (v_player_bonus_min + floor(random() * (v_player_bonus_max - v_player_bonus_min + 1))::integer);
              END IF;
              v_hit_damage := GREATEST(0, v_hit_damage);
            END IF;

            -- Bonus cumulatif de la chaîne "Continue sur sa lancée" : rien à
            -- la 1ère utilisation, puis +1 fois le bonus unitaire par
            -- réutilisation (voir v_player_keep_going_count plus haut).
            IF v_player_keep_going_turns IS NOT NULL AND v_player_keep_going_count > 1 THEN
              v_keep_going_bonus := (v_player_keep_going_count - 1) * (CASE
                WHEN v_player_keep_going_bonus_type = 'percent_damage'
                  THEN floor(v_player_damage * COALESCE(v_player_keep_going_bonus_percent, 0) / 100.0)::integer
                ELSE COALESCE(v_player_keep_going_bonus_flat, 0) END);
              v_hit_damage := GREATEST(0, v_hit_damage + v_keep_going_bonus);
            END IF;
          ELSE
            v_hit_dice := 0;
            v_hit_damage := 0;
            v_percent_hp_damage_applied := false;
          END IF;
          -- 'first_and_replay' ne "compte" pas comme une capacité utilisée
          -- (voir autobattle_ability_rules) : la condition de bonus
          -- 'first_use' reste donc vraie pour la vraie attaque qui suit.
          IF v_player_turn_effect IS DISTINCT FROM 'first_and_replay' THEN
            v_player_used_ability := true;
          END IF;

          v_opponent_hp := v_opponent_hp - v_hit_damage;
          v_opponent_took_damage := v_hit_damage > 0;

          v_heal_amt := NULL;
          IF v_player_heal_type = 'static' THEN
            v_heal_amt := COALESCE(v_player_heal_amount, 0);
          ELSIF v_player_heal_type = 'percent_damage' THEN
            v_heal_amt := floor(v_hit_damage * COALESCE(v_player_heal_percent, 0) / 100.0)::integer;
          ELSIF v_player_heal_type = 'use_stats' THEN
            v_heal_dice := CASE WHEN v_ability.degats_de IS NOT NULL AND v_ability.degats_de > 0
              THEN 1 + floor(random() * v_ability.degats_de)::integer ELSE 0 END;
            -- PAS v_player_damage_original : ce montant inclut le bonus de
            -- type x2 (super efficace), qui n'a de sens que pour des dégâts
            -- infligés. Un soin basé sur les stats n'inflige aucun dégât, on
            -- reconstruit donc le montant à partir de la composante espèce+XP
            -- SANS multiplicateur de type + la base de la capacité elle-même.
            v_heal_amt := v_player_damage_species_xp + COALESCE(v_ability.degats_base, 0) + v_heal_dice;
          END IF;

          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', v_hit_damage, 'damage_before_dice', v_player_damage,
            'damage_species_xp', v_player_damage_species_xp, 'damage_dice', v_hit_dice,
            'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', v_opponent_hp <= 0,
            'precision_mod_amount', v_player_precision_mod_amount
          );
          IF v_percent_hp_damage_applied THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('percent_hp_damage', true);
          END IF;
          IF v_prevention_blocked THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('prevention_blocked', true);
          END IF;
          IF v_keep_going_bonus <> 0 THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('keep_going_bonus', v_keep_going_bonus);
          END IF;
          IF v_heal_amt IS NOT NULL AND v_heal_amt > 0 AND (v_player_heal_disabled_expires IS NULL OR v_round_no > v_player_heal_disabled_expires) THEN
            v_player_hp := LEAST(v_player_max_hp, v_player_hp + v_heal_amt);
            v_turn_entry := v_turn_entry || jsonb_build_object('heal', v_heal_amt, 'attacker_hp_after', v_player_hp);
            -- Le poison est guéri par n'importe quel soin, quel qu'en soit le
            -- moyen (voir status_effect 'poison') — paralysie/gel/peur/
            -- confusion/sommeil/brûlure ne sont PAS guéris par un soin.
            IF v_player_status = 'poison' THEN
              v_player_status := NULL;
              v_turn_entry := v_turn_entry || jsonb_build_object('status_cured_by_heal', true);
            END IF;
          ELSIF v_heal_amt IS NOT NULL AND v_heal_amt > 0 THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('heal_blocked', true);
          END IF;
          -- Un coup réussi a une chance (status_chance) d'infliger le statut
          -- de la capacité — à l'adversaire normalement, à soi-même si
          -- status_reversed (voir autobattle_ability_rules). Remplace un
          -- statut déjà actif sur la cible le cas échéant (pas de cumul).
          IF v_ability.status_effect IS NOT NULL AND random() * 100 < v_ability.status_chance THEN
            IF v_player_status_reversed THEN
              v_player_status := v_ability.status_effect;
            ELSE
              v_opponent_status := v_ability.status_effect;
            END IF;
            v_turn_entry := v_turn_entry || jsonb_build_object('status_applied', v_ability.status_effect, 'status_applied_reversed', v_player_status_reversed);
          END IF;
          -- Modificateur de stat (voir autobattle_ability_rules.stat_mod_*) :
          -- appliqué (ou réappliqué, écrasant l'ancien montant+durée) sur ce
          -- coup réussi, tant que la limite d'usages n'est pas atteinte —
          -- un usage ne compte que s'il s'applique réellement (jamais sur un
          -- raté, déjà exclu puisqu'on est dans la branche "coup réussi").
          IF v_player_stat_mod_target IS NOT NULL THEN
            IF v_player_stat_mod_max_uses IS NULL OR v_player_stat_mod_uses_used < v_player_stat_mod_max_uses THEN
              v_stat_mod_amount := CASE
                WHEN v_player_stat_mod_value_type = 'flat' THEN COALESCE(v_player_stat_mod_flat, 0)
                WHEN v_player_stat_mod_value_type = 'range' THEN v_player_stat_mod_min + floor(random() * (v_player_stat_mod_max - v_player_stat_mod_min + 1))::integer
                WHEN v_player_stat_mod_value_type = 'percent' THEN
                  floor((CASE WHEN v_player_stat_mod_target = 'self' THEN v_player_damage_original ELSE v_opponent_damage_original END)
                    * COALESCE(v_player_stat_mod_percent, 0) / 100.0)::integer
                ELSE 0
              END;
              v_stat_mod_amount := CASE WHEN v_player_stat_mod_target = 'opponent' THEN -abs(v_stat_mod_amount) ELSE abs(v_stat_mod_amount) END;
              -- v_round_no avance de 1 à CHAQUE tour RÉEL (joueur ET
              -- adversaire confondus, jamais au milieu d'une rafale — voir
              -- DECLARE), donc "1 tour" pour le lanceur (son PROCHAIN tour,
              -- pas celui-ci — voir requirement) correspond à 2 incréments de
              -- v_round_no en alternance normale (son tour, puis le tour
              -- adverse, puis son tour suivant) : d'où × 2 ci-dessous, plutôt
              -- qu'un simple + N qui expirerait le bonus AVANT même d'avoir
              -- pu servir une fois.
              v_stat_mod_expiry := CASE WHEN v_player_stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_round_no + 2 * COALESCE(v_player_stat_mod_duration_turns, 1) END;
              -- Le filtre de type éventuel (stat_mod_type_filter) voyage avec
              -- le modificateur : il est relu au moment d'infliger des dégâts,
              -- contre le type de la capacité jouée à ce moment-là.
              IF v_player_stat_mod_target = 'self' AND v_player_stat_mod_stat = 'damage' THEN
                v_player_damage_mod_amount := v_stat_mod_amount; v_player_damage_mod_expires := v_stat_mod_expiry;
                v_player_damage_mod_type_filter := v_player_stat_mod_type_filter;
              ELSIF v_player_stat_mod_target = 'self' AND v_player_stat_mod_stat = 'precision' THEN
                v_player_precision_mod_amount := v_stat_mod_amount; v_player_precision_mod_expires := v_stat_mod_expiry;
              ELSIF v_player_stat_mod_target = 'opponent' AND v_player_stat_mod_stat = 'damage' THEN
                v_opponent_damage_mod_amount := v_stat_mod_amount; v_opponent_damage_mod_expires := v_stat_mod_expiry;
                v_opponent_damage_mod_type_filter := v_player_stat_mod_type_filter;
              ELSIF v_player_stat_mod_target = 'opponent' AND v_player_stat_mod_stat = 'precision' THEN
                v_opponent_precision_mod_amount := v_stat_mod_amount; v_opponent_precision_mod_expires := v_stat_mod_expiry;
              END IF;
              v_player_stat_mod_uses_used := v_player_stat_mod_uses_used + 1;
              v_turn_entry := v_turn_entry || jsonb_build_object('stat_mod_applied', jsonb_build_object(
                'target', v_player_stat_mod_target, 'stat', v_player_stat_mod_stat, 'amount', v_stat_mod_amount, 'duration_type', v_player_stat_mod_duration_type
              ));
            ELSE
              v_turn_entry := v_turn_entry || jsonb_build_object('stat_mod_limit_reached', true);
            END IF;
          END IF;
          -- Soin passif (heal_dot) : accordé/réaccordé à son utilisateur sur
          -- ce coup réussi, indépendant du soin instantané ci-dessus. Montant
          -- résolu UNE FOIS ici (pas recalculé à chaque tick) : voir
          -- autobattle_ability_rules pour 'percent_max_hp'/'percent_damage'.
          IF v_player_heal_dot_config_turns IS NOT NULL OR v_player_heal_dot_config_until_awake THEN
            v_player_heal_dot_amount := CASE
              WHEN v_player_heal_dot_config_type = 'percent_max_hp' THEN floor(v_player_max_hp * COALESCE(v_player_heal_dot_config_percent, 0) / 100.0)::integer
              WHEN v_player_heal_dot_config_type = 'percent_damage' THEN floor(v_hit_damage * COALESCE(v_player_heal_dot_config_percent, 0) / 100.0)::integer
              ELSE COALESCE(v_player_heal_dot_config_amount, 0)
            END;
            -- x2 : v_round_no est un compteur GLOBAL incrémenté à CHAQUE tour
            -- (les deux camps confondus, voir le même x2 sur v_stat_mod_expiry
            -- plus haut), alors que ce soin ne tique que sur les tours PROPRES
            -- du joueur (un sur deux) — sans le x2, un "3 tours" ne tiquerait
            -- qu'une fois au lieu de trois (bug constaté en jeu).
            -- Variante "jusqu'au réveil" : aucune expiration par tour, c'est
            -- la perte du statut Sommeil qui met fin à l'effet (voir la
            -- condition de tick et les expirations en tête de boucle).
            IF v_player_heal_dot_config_until_awake THEN
              v_player_heal_dot_until_awake := true;
              v_player_heal_dot_expires := NULL;
            ELSE
              v_player_heal_dot_until_awake := false;
              v_player_heal_dot_expires := v_round_no + 2 * v_player_heal_dot_config_turns;
            END IF;
            v_turn_entry := v_turn_entry || jsonb_build_object('heal_dot_granted', true);
          END IF;
          -- Anti-Soin : désactive tous les effets de soin adverses (soin
          -- instantané, soin passif, guérison du poison par un soin) pendant
          -- cancel_heal_duration_turns tours de combat.
          IF v_player_cancel_heal_duration IS NOT NULL THEN
            v_opponent_heal_disabled_expires := v_round_no + 2 * v_player_cancel_heal_duration;
            v_turn_entry := v_turn_entry || jsonb_build_object('cancel_heal_applied', true);
          END IF;
          -- Bouclier Prévention : protège son utilisateur des dégâts
          -- additionnels dus à l'efficacité de type pendant N tours.
          IF v_player_prevention_duration IS NOT NULL THEN
            v_player_prevention_expires := v_round_no + 2 * v_player_prevention_duration;
            v_turn_entry := v_turn_entry || jsonb_build_object('prevention_granted', true);
          END IF;
          -- Invulnérabilité accordée par cette capacité : consommée au
          -- prochain tour adverse (voir plus haut), indépendamment du reste.
          -- Pour 'prepare_release', déjà accordée à la préparation (protège
          -- le tour adverse qui suit immédiatement, pas celui après la
          -- libération) — ne pas la ré-accorder ici dans ce cas.
          -- IS DISTINCT FROM et surtout PAS <> : turn_effect est NULL pour
          -- toute capacité sans effet de tour, et `NULL <> '...'` vaut NULL
          -- (donc faux) — le bouclier n'était alors JAMAIS accordé hors
          -- préparation (bug constaté en jeu).
          IF v_player_invuln_grant AND v_player_turn_effect IS DISTINCT FROM 'prepare_release' THEN
            v_player_invulnerable := true;
            v_player_invuln_granted_round := v_round_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          -- Contre-coup : dégâts sur son propre utilisateur, après tout le
          -- reste (soin/statut/invulnérabilité), basés sur les dégâts FINAUX
          -- (bonus inclus) — voir recoil_type.
          IF v_player_recoil_type IS NOT NULL THEN
            v_recoil_amt := CASE WHEN v_player_recoil_type = 'range'
              THEN v_player_recoil_min + floor(random() * (v_player_recoil_max - v_player_recoil_min + 1))::integer
              ELSE floor(v_hit_damage * COALESCE(v_player_recoil_percent, 0) / 100.0)::integer END;
            IF v_recoil_amt > 0 THEN
              v_player_hp := v_player_hp - v_recoil_amt;
              v_turn_entry := v_turn_entry || jsonb_build_object('recoil', v_recoil_amt, 'attacker_hp_after', v_player_hp);
            END IF;
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry);

          IF v_opponent_hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
          IF v_player_hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
        END IF;
      END IF;
    ELSE
      -- Voir la même remarque côté joueur ci-dessus : ne bloque que si cette
      -- capacité affecte réellement le joueur, re-vérifié à CHAQUE
      -- activation (bloque toute une rafale adverse, pas juste son 1er coup).
      IF v_player_invulnerable AND (
        v_opponent_ability.deals_damage
        OR (v_opponent_ability.status_effect IS NOT NULL AND NOT v_opponent_status_reversed)
        OR v_opponent_stat_mod_target = 'opponent'
        OR v_opponent_cancel_heal_duration IS NOT NULL
      ) THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'missed', true, 'invulnerable_miss', true,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_opponent_turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
        -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
        -- cesse d'être imposée, le tour suivant redevient un choix libre.
        IF v_opponent_keep_going_turns IS NOT NULL THEN
          v_opponent_keep_going_remaining := 0;
          v_opponent_keep_going_count := 0;
        END IF;
      ELSE
        v_missed := (NOT v_opponent_never_miss) AND
          random() >= ((CASE WHEN v_precision_enabled THEN GREATEST(0, COALESCE(v_opponent_ability.precision, 10) - v_status_precision_penalty + v_opponent_precision_mod_amount) ELSE 10 END * 10) / 100.0);

        IF v_missed THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'missed', true,
            'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false,
            'precision_mod_amount', v_opponent_precision_mod_amount
          ));
          IF v_opponent_turn_effect = 'repeat_until_fail' THEN
            v_block_remaining := 1;
          END IF;
          -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
          -- cesse d'être imposée, le tour suivant redevient un choix libre.
          IF v_opponent_keep_going_turns IS NOT NULL THEN
            v_opponent_keep_going_remaining := 0;
            v_opponent_keep_going_count := 0;
          END IF;
        ELSE
          -- Capacités non-offensives (voir même remarque côté joueur) : pas
          -- de dégâts, système % PV / bonus conditionnels ignorés aussi.
          -- Voir les mêmes commentaires côté joueur plus haut.
          v_damage_mod_applied := CASE
            WHEN v_opponent_damage_mod_type_filter IS NULL
              OR lower(trim(v_opponent_damage_mod_type_filter)) = lower(trim(COALESCE(v_opponent_ability.type, '')))
            THEN v_opponent_damage_mod_amount ELSE 0 END;
          v_prevention_blocked := v_opponent_type_bonus
            AND v_player_prevention_expires IS NOT NULL AND v_round_no <= v_player_prevention_expires;
          v_keep_going_bonus := 0;
          IF v_opponent_ability.deals_damage THEN
            v_hit_dice := CASE WHEN v_opponent_ability.degats_de IS NOT NULL AND v_opponent_ability.degats_de > 0
              THEN 1 + floor(random() * v_opponent_ability.degats_de)::integer ELSE 0 END;
            v_hit_damage := GREATEST(0, v_opponent_damage
              - (CASE WHEN v_prevention_blocked THEN v_opponent_damage_species_xp ELSE 0 END)
              + v_hit_dice + v_damage_mod_applied);

            v_percent_hp_damage_applied := v_opponent_percent_hp_damage_percent IS NOT NULL;
            IF v_percent_hp_damage_applied THEN
              v_hit_damage := GREATEST(0, floor(v_player_hp * v_opponent_percent_hp_damage_percent / 100.0)::integer);
            END IF;

            v_bonus_condition_met := v_opponent_bonus_condition = 'took_damage_last_turn' AND v_opponent_took_damage
              OR v_opponent_bonus_condition = 'first_use' AND NOT v_opponent_used_ability
              OR v_opponent_bonus_condition = 'dice_equals' AND v_hit_dice = v_opponent_bonus_dice_value
              OR v_opponent_bonus_condition = 'has_status' AND v_player_status IS NOT NULL AND (v_opponent_bonus_status_filter IS NULL OR v_player_status = v_opponent_bonus_status_filter);
            IF v_opponent_bonus_type IS NOT NULL AND v_bonus_condition_met THEN
              IF v_opponent_bonus_type = 'multiply' THEN
                v_hit_damage := floor(v_hit_damage * COALESCE(v_opponent_bonus_multiplier, 1))::integer;
              ELSIF v_opponent_bonus_type = 'flat' THEN
                v_hit_damage := v_hit_damage + COALESCE(v_opponent_bonus_flat, 0);
              ELSIF v_opponent_bonus_type = 'range' THEN
                v_hit_damage := v_hit_damage + (v_opponent_bonus_min + floor(random() * (v_opponent_bonus_max - v_opponent_bonus_min + 1))::integer);
              END IF;
              v_hit_damage := GREATEST(0, v_hit_damage);
            END IF;

            IF v_opponent_keep_going_turns IS NOT NULL AND v_opponent_keep_going_count > 1 THEN
              v_keep_going_bonus := (v_opponent_keep_going_count - 1) * (CASE
                WHEN v_opponent_keep_going_bonus_type = 'percent_damage'
                  THEN floor(v_opponent_damage * COALESCE(v_opponent_keep_going_bonus_percent, 0) / 100.0)::integer
                ELSE COALESCE(v_opponent_keep_going_bonus_flat, 0) END);
              v_hit_damage := GREATEST(0, v_hit_damage + v_keep_going_bonus);
            END IF;
          ELSE
            v_hit_dice := 0;
            v_hit_damage := 0;
            v_percent_hp_damage_applied := false;
          END IF;
          IF v_opponent_turn_effect IS DISTINCT FROM 'first_and_replay' THEN
            v_opponent_used_ability := true;
          END IF;

          v_player_hp := v_player_hp - v_hit_damage;
          v_player_took_damage := v_hit_damage > 0;

          v_heal_amt := NULL;
          IF v_opponent_heal_type = 'static' THEN
            v_heal_amt := COALESCE(v_opponent_heal_amount, 0);
          ELSIF v_opponent_heal_type = 'percent_damage' THEN
            v_heal_amt := floor(v_hit_damage * COALESCE(v_opponent_heal_percent, 0) / 100.0)::integer;
          ELSIF v_opponent_heal_type = 'use_stats' THEN
            v_heal_dice := CASE WHEN v_opponent_ability.degats_de IS NOT NULL AND v_opponent_ability.degats_de > 0
              THEN 1 + floor(random() * v_opponent_ability.degats_de)::integer ELSE 0 END;
            -- Voir le même commentaire côté joueur plus haut : pas de bonus de
            -- type sur un soin basé sur les stats.
            v_heal_amt := v_opponent_damage_species_xp + COALESCE(v_opponent_ability.degats_base, 0) + v_heal_dice;
          END IF;

          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', v_hit_damage, 'damage_before_dice', v_opponent_damage,
            'damage_species_xp', v_opponent_damage_species_xp, 'damage_dice', v_hit_dice,
            'defender_hp_after', GREATEST(0, v_player_hp), 'ko', v_player_hp <= 0,
            'precision_mod_amount', v_opponent_precision_mod_amount
          );
          IF v_percent_hp_damage_applied THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('percent_hp_damage', true);
          END IF;
          IF v_prevention_blocked THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('prevention_blocked', true);
          END IF;
          IF v_keep_going_bonus <> 0 THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('keep_going_bonus', v_keep_going_bonus);
          END IF;
          IF v_heal_amt IS NOT NULL AND v_heal_amt > 0 AND (v_opponent_heal_disabled_expires IS NULL OR v_round_no > v_opponent_heal_disabled_expires) THEN
            v_opponent_hp := LEAST(v_level.opponent_hp, v_opponent_hp + v_heal_amt);
            v_turn_entry := v_turn_entry || jsonb_build_object('heal', v_heal_amt, 'attacker_hp_after', v_opponent_hp);
            IF v_opponent_status = 'poison' THEN
              v_opponent_status := NULL;
              v_turn_entry := v_turn_entry || jsonb_build_object('status_cured_by_heal', true);
            END IF;
          ELSIF v_heal_amt IS NOT NULL AND v_heal_amt > 0 THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('heal_blocked', true);
          END IF;
          IF v_opponent_ability.status_effect IS NOT NULL AND random() * 100 < v_opponent_ability.status_chance THEN
            IF v_opponent_status_reversed THEN
              v_opponent_status := v_opponent_ability.status_effect;
            ELSE
              v_player_status := v_opponent_ability.status_effect;
            END IF;
            v_turn_entry := v_turn_entry || jsonb_build_object('status_applied', v_opponent_ability.status_effect, 'status_applied_reversed', v_opponent_status_reversed);
          END IF;
          IF v_opponent_stat_mod_target IS NOT NULL THEN
            IF v_opponent_stat_mod_max_uses IS NULL OR v_opponent_stat_mod_uses_used < v_opponent_stat_mod_max_uses THEN
              v_stat_mod_amount := CASE
                WHEN v_opponent_stat_mod_value_type = 'flat' THEN COALESCE(v_opponent_stat_mod_flat, 0)
                WHEN v_opponent_stat_mod_value_type = 'range' THEN v_opponent_stat_mod_min + floor(random() * (v_opponent_stat_mod_max - v_opponent_stat_mod_min + 1))::integer
                WHEN v_opponent_stat_mod_value_type = 'percent' THEN
                  floor((CASE WHEN v_opponent_stat_mod_target = 'self' THEN v_opponent_damage_original ELSE v_player_damage_original END)
                    * COALESCE(v_opponent_stat_mod_percent, 0) / 100.0)::integer
                ELSE 0
              END;
              v_stat_mod_amount := CASE WHEN v_opponent_stat_mod_target = 'opponent' THEN -abs(v_stat_mod_amount) ELSE abs(v_stat_mod_amount) END;
              v_stat_mod_expiry := CASE WHEN v_opponent_stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_round_no + 2 * COALESCE(v_opponent_stat_mod_duration_turns, 1) END;
              -- Voir le même commentaire côté joueur plus haut.
              IF v_opponent_stat_mod_target = 'self' AND v_opponent_stat_mod_stat = 'damage' THEN
                v_opponent_damage_mod_amount := v_stat_mod_amount; v_opponent_damage_mod_expires := v_stat_mod_expiry;
                v_opponent_damage_mod_type_filter := v_opponent_stat_mod_type_filter;
              ELSIF v_opponent_stat_mod_target = 'self' AND v_opponent_stat_mod_stat = 'precision' THEN
                v_opponent_precision_mod_amount := v_stat_mod_amount; v_opponent_precision_mod_expires := v_stat_mod_expiry;
              ELSIF v_opponent_stat_mod_target = 'opponent' AND v_opponent_stat_mod_stat = 'damage' THEN
                v_player_damage_mod_amount := v_stat_mod_amount; v_player_damage_mod_expires := v_stat_mod_expiry;
                v_player_damage_mod_type_filter := v_opponent_stat_mod_type_filter;
              ELSIF v_opponent_stat_mod_target = 'opponent' AND v_opponent_stat_mod_stat = 'precision' THEN
                v_player_precision_mod_amount := v_stat_mod_amount; v_player_precision_mod_expires := v_stat_mod_expiry;
              END IF;
              v_opponent_stat_mod_uses_used := v_opponent_stat_mod_uses_used + 1;
              v_turn_entry := v_turn_entry || jsonb_build_object('stat_mod_applied', jsonb_build_object(
                'target', v_opponent_stat_mod_target, 'stat', v_opponent_stat_mod_stat, 'amount', v_stat_mod_amount, 'duration_type', v_opponent_stat_mod_duration_type
              ));
            ELSE
              v_turn_entry := v_turn_entry || jsonb_build_object('stat_mod_limit_reached', true);
            END IF;
          END IF;
          IF v_opponent_heal_dot_config_turns IS NOT NULL OR v_opponent_heal_dot_config_until_awake THEN
            v_opponent_heal_dot_amount := CASE
              WHEN v_opponent_heal_dot_config_type = 'percent_max_hp' THEN floor(v_level.opponent_hp * COALESCE(v_opponent_heal_dot_config_percent, 0) / 100.0)::integer
              WHEN v_opponent_heal_dot_config_type = 'percent_damage' THEN floor(v_hit_damage * COALESCE(v_opponent_heal_dot_config_percent, 0) / 100.0)::integer
              ELSE COALESCE(v_opponent_heal_dot_config_amount, 0)
            END;
            -- x2 : voir le même commentaire côté joueur plus haut.
            -- Variante "jusqu'au réveil" : aucune expiration par tour, c'est
            -- la perte du statut Sommeil qui met fin à l'effet (voir la
            -- condition de tick et les expirations en tête de boucle).
            IF v_opponent_heal_dot_config_until_awake THEN
              v_opponent_heal_dot_until_awake := true;
              v_opponent_heal_dot_expires := NULL;
            ELSE
              v_opponent_heal_dot_until_awake := false;
              v_opponent_heal_dot_expires := v_round_no + 2 * v_opponent_heal_dot_config_turns;
            END IF;
            v_turn_entry := v_turn_entry || jsonb_build_object('heal_dot_granted', true);
          END IF;
          IF v_opponent_cancel_heal_duration IS NOT NULL THEN
            v_player_heal_disabled_expires := v_round_no + 2 * v_opponent_cancel_heal_duration;
            v_turn_entry := v_turn_entry || jsonb_build_object('cancel_heal_applied', true);
          END IF;
          -- Bouclier Prévention : protège son utilisateur des dégâts
          -- additionnels dus à l'efficacité de type pendant N tours.
          IF v_opponent_prevention_duration IS NOT NULL THEN
            v_opponent_prevention_expires := v_round_no + 2 * v_opponent_prevention_duration;
            v_turn_entry := v_turn_entry || jsonb_build_object('prevention_granted', true);
          END IF;
          IF v_opponent_invuln_grant AND v_opponent_turn_effect IS DISTINCT FROM 'prepare_release' THEN
            v_opponent_invulnerable := true;
            v_opponent_invuln_granted_round := v_round_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          IF v_opponent_recoil_type IS NOT NULL THEN
            v_recoil_amt := CASE WHEN v_opponent_recoil_type = 'range'
              THEN v_opponent_recoil_min + floor(random() * (v_opponent_recoil_max - v_opponent_recoil_min + 1))::integer
              ELSE floor(v_hit_damage * COALESCE(v_opponent_recoil_percent, 0) / 100.0)::integer END;
            IF v_recoil_amt > 0 THEN
              v_opponent_hp := v_opponent_hp - v_recoil_amt;
              v_turn_entry := v_turn_entry || jsonb_build_object('recoil', v_recoil_amt, 'attacker_hp_after', v_opponent_hp);
            END IF;
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry);

          IF v_player_hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_opponent_hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
        END IF;
      END IF;
    END IF;

    v_block_remaining := v_block_remaining - 1;
    IF v_block_remaining = 0 THEN
      v_attacker := CASE WHEN v_attacker = 'player' THEN 'opponent' ELSE 'player' END;
      v_block_remaining := NULL;
    END IF;

    -- Filet de sécurité : si les deux côtés infligent 0 dégât, ou s'ils sont
    -- tous deux configurés en 'skip' (aucun ne peut jamais gagner), on force
    -- une défaite plutôt qu'une boucle infinie.
    IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
  END LOOP;

  IF v_outcome = 'win' THEN
    UPDATE player_pokemon SET battles_won = battles_won + 1 WHERE id = p_player_pokemon_id;

    FOR v_reward IN SELECT * FROM autobattle_level_rewards WHERE level_id = p_level_id ORDER BY sort_order LOOP
      IF v_reward.reward_type = 'xp' THEN
        v_max_xp := autobattle_max_xp(v_pp.pokemon_nom);
        v_new_xp := GREATEST(0, v_pp.xp + v_reward.xp_amount);
        IF v_max_xp IS NOT NULL THEN v_new_xp := LEAST(v_new_xp, v_max_xp); END IF;
        UPDATE player_pokemon SET xp = v_new_xp WHERE id = p_player_pokemon_id;
        v_rewards := v_rewards || jsonb_build_array(jsonb_build_object(
          'reward_type', 'xp', 'xp_amount', v_reward.xp_amount,
          'player_pokemon_id', p_player_pokemon_id, 'xp_before', v_pp.xp, 'xp_after', v_new_xp
        ));
        v_pp.xp := v_new_xp;
      ELSE
        INSERT INTO player_items (player_id, item_nom, quantity)
        VALUES (p_player_id, v_reward.item_nom, v_reward.item_quantity)
        ON CONFLICT (player_id, item_nom) DO UPDATE SET quantity = player_items.quantity + EXCLUDED.quantity;
        v_rewards := v_rewards || jsonb_build_array(jsonb_build_object(
          'reward_type', v_reward.reward_type, 'item_nom', v_reward.item_nom, 'quantity', v_reward.item_quantity
        ));
      END IF;
    END LOOP;

    UPDATE autobattle_player_level_state
      SET discovered = true, discovered_at = COALESCE(discovered_at, now()), completed = true, completed_at = now()
      WHERE player_id = p_player_id AND level_id = p_level_id;

    SELECT MAX(level_index) INTO v_max_level_index FROM autobattle_levels WHERE variant_id = v_variant.id;
    IF v_level.level_index >= v_max_level_index THEN
      v_variant_completed := true;
      v_next_level_index := v_progress.current_level_index;
    ELSE
      v_next_level_index := v_progress.current_level_index + 1;
    END IF;

    UPDATE autobattle_player_variant_progress
      SET current_level_index = v_next_level_index, variant_completed = v_variant_completed,
          completed_at = CASE WHEN v_variant_completed THEN now() ELSE completed_at END
      WHERE player_id = p_player_id AND variant_id = v_variant.id;
  ELSE
    UPDATE autobattle_player_level_state
      SET discovered = true, discovered_at = COALESCE(discovered_at, now())
      WHERE player_id = p_player_id AND level_id = p_level_id;
    v_next_level_index := v_progress.current_level_index;
  END IF;

  UPDATE autobattle_battles
    SET outcome = v_outcome, turn_log = v_turns, rewards_granted = v_rewards
    WHERE id = v_battle_id;

  RETURN jsonb_build_object(
    'status', 'ok',
    'coin_toss_first', CASE WHEN v_coin_player_first THEN 'player' ELSE 'opponent' END,
    'player_max_hp', v_player_max_hp,
    'opponent_hp', v_level.opponent_hp,
    'player_damage_per_hit', v_player_damage,
    'opponent_damage_per_hit', v_opponent_damage,
    'player_type_bonus', v_player_type_bonus,
    'opponent_type_bonus', v_opponent_type_bonus,
    'turns', v_turns,
    'outcome', v_outcome,
    'rewards', v_rewards,
    'variant_completed', v_variant_completed,
    'next_level_index', v_next_level_index,
    'opponent_pokemon_nom', v_level.opponent_pokemon_nom,
    'opponent_ability_nom', v_level.opponent_ability_nom,
    'player_image_override', v_player_image_override,
    'player_ability_nom_override', CASE WHEN v_is_metamorph THEN v_effective_ability_nom ELSE NULL END,
    'opponent_image_override', v_opponent_image_override,
    'opponent_ability_nom_override', CASE WHEN v_is_opponent_metamorph THEN v_effective_opponent_ability_nom ELSE NULL END
  );
END;
$$;

-- ============================================================
-- 6. Combat Manuel (un round par appel)
-- ============================================================
CREATE OR REPLACE FUNCTION autobattle_resolve_manual_round(
  p_player_id bigint,
  p_level_id bigint,
  p_player_pokemon_id bigint,
  p_ability_nom text,
  p_idempotency_key uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_level               record;
  v_variant             record;
  v_progress            record;
  v_pp                  record;
  v_player_species      record;
  v_ability             record;
  v_opponent_species    record;
  v_opponent_ability    record;
  v_row                 autobattle_manual_battles%ROWTYPE;
  v_precision_enabled   boolean;
  v_player_max_hp       integer;
  v_player_hp           integer;
  v_opponent_hp         integer;
  v_player_type_bonus   boolean;
  v_opponent_type_bonus boolean;
  v_player_damage       integer;
  v_opponent_damage     integer;
  v_player_damage_original   integer;
  v_opponent_damage_original integer;
  v_player_damage_species_xp   integer;
  v_opponent_damage_species_xp integer;
  v_turn_no             integer;
  -- Voir le même commentaire dans autobattle_resolve_battle : n'avance qu'à
  -- chaque VRAI changement de tour, jamais au milieu d'une rafale. Persisté
  -- entre les appels RPC (voir autobattle_manual_battles.round_no), comme
  -- turn_no.
  v_round_no            integer;
  v_first_attacker      text;
  v_attacker            text;
  v_flips               integer := 0;
  v_block_remaining     integer;
  v_turn_entry          jsonb;
  v_turns               jsonb := '[]'::jsonb;
  v_outcome             text;
  v_hit_dice            integer;
  v_hit_damage          integer;
  v_heal_amt            integer;
  v_heal_dice           integer;
  v_recoil_amt          integer;
  v_missed              boolean;
  v_status_roll         integer;
  v_status_cured        boolean;
  v_status_precision_penalty integer := 0;
  v_bonus_condition_met boolean;
  v_percent_hp_damage_applied boolean;
  v_player_status                text;
  v_opponent_status              text;
  v_player_never_miss            boolean;
  v_opponent_never_miss          boolean;
  v_player_damage_mod_amount     integer;
  v_player_damage_mod_expires    integer;
  v_player_precision_mod_amount  integer;
  v_player_precision_mod_expires integer;
  v_opponent_damage_mod_amount     integer;
  v_opponent_damage_mod_expires    integer;
  v_opponent_precision_mod_amount  integer;
  v_opponent_precision_mod_expires integer;
  v_player_heal_dot_amount    integer;
  v_player_heal_dot_expires   integer;
  v_opponent_heal_dot_amount  integer;
  v_opponent_heal_dot_expires integer;
  v_player_heal_disabled_expires   integer;
  v_opponent_heal_disabled_expires integer;
  v_player_invulnerable       boolean;
  v_player_invuln_granted_round integer;
  v_opponent_invulnerable     boolean;
  v_opponent_invuln_granted_round integer;
  v_player_invuln_pending_miss   boolean := false;
  v_opponent_invuln_pending_miss boolean := false;
  v_player_used_ability       boolean;
  v_player_took_damage        boolean;
  v_opponent_used_ability     boolean;
  v_opponent_took_damage      boolean;
  v_player_skip_pending       boolean;
  v_opponent_skip_pending     boolean;
  v_player_preparing          boolean;
  v_opponent_preparing        boolean;
  v_player_preparing_ability_nom   text;
  v_opponent_preparing_ability_nom text;
  v_effective_player_ability_nom   text;
  v_is_metamorph              boolean;
  v_player_image_override     text;
  v_is_opponent_metamorph     boolean;
  v_opponent_ability_sequence text[];
  v_opponent_ability_cycle_index integer;
  v_opponent_ability_nom_round   text;
  v_player_stat_mod_uses         jsonb;
  v_opponent_stat_mod_uses       jsonb;
  v_player_stat_mod_key          text;
  v_opponent_stat_mod_key        text;
  v_player_stat_mod_uses_used_for_key   integer;
  v_opponent_stat_mod_uses_used_for_key integer;
  v_stat_mod_amount    integer;
  v_stat_mod_expiry    integer;
  -- Config de la capacité JOUÉE ce tour côté joueur (v_effective_player_
  -- ability_nom, change à chaque tour sauf préparation en cours) :
  v_player_turn_effect   text;
  v_player_repeat_max    integer;
  v_player_heal_type     text;
  v_player_heal_amount   integer;
  v_player_heal_percent  integer;
  v_player_status_reversed boolean;
  v_player_recoil_type   text;
  v_player_recoil_min    integer;
  v_player_recoil_max    integer;
  v_player_recoil_percent integer;
  v_player_invuln_grant  boolean;
  v_player_bonus_type       text;
  v_player_bonus_multiplier numeric;
  v_player_bonus_flat       integer;
  v_player_bonus_min        integer;
  v_player_bonus_max        integer;
  v_player_bonus_condition  text;
  v_player_bonus_dice_value integer;
  v_player_bonus_status_filter text;
  v_player_stat_mod_target       text;
  v_player_stat_mod_stat         text;
  v_player_stat_mod_value_type   text;
  v_player_stat_mod_flat         integer;
  v_player_stat_mod_min          integer;
  v_player_stat_mod_max          integer;
  v_player_stat_mod_percent      integer;
  v_player_stat_mod_duration_type  text;
  v_player_stat_mod_duration_turns integer;
  v_player_stat_mod_max_uses     integer;
  v_player_heal_dot_config_amount integer;
  v_player_heal_dot_config_turns  integer;
  v_player_heal_dot_config_type   text;
  v_player_heal_dot_config_percent integer;
  v_player_cancel_heal_duration   integer;
  v_player_percent_hp_damage_percent integer;
  v_player_stat_mod_type_filter   text;
  v_player_prevention_duration    integer;
  v_player_keep_going_turns       integer;
  v_player_keep_going_bonus_type  text;
  v_player_keep_going_bonus_flat  integer;
  v_player_keep_going_bonus_percent integer;
  v_player_heal_dot_config_until_awake boolean;
  v_player_ignore_status_block    text;
  -- Config de la capacité JOUÉE ce tour côté adversaire (v_opponent_ability_
  -- nom_round, change à chaque nouveau tour sauf préparation en cours) :
  v_opponent_turn_effect   text;
  v_opponent_repeat_max    integer;
  v_opponent_heal_type     text;
  v_opponent_heal_amount   integer;
  v_opponent_heal_percent  integer;
  v_opponent_status_reversed boolean;
  v_opponent_recoil_type   text;
  v_opponent_recoil_min    integer;
  v_opponent_recoil_max    integer;
  v_opponent_recoil_percent integer;
  v_opponent_invuln_grant  boolean;
  v_opponent_bonus_type       text;
  v_opponent_bonus_multiplier numeric;
  v_opponent_bonus_flat       integer;
  v_opponent_bonus_min        integer;
  v_opponent_bonus_max        integer;
  v_opponent_bonus_condition  text;
  v_opponent_bonus_dice_value integer;
  v_opponent_bonus_status_filter text;
  v_opponent_stat_mod_target       text;
  v_opponent_stat_mod_stat         text;
  v_opponent_stat_mod_value_type   text;
  v_opponent_stat_mod_flat         integer;
  v_opponent_stat_mod_min          integer;
  v_opponent_stat_mod_max          integer;
  v_opponent_stat_mod_percent      integer;
  v_opponent_stat_mod_duration_type  text;
  v_opponent_stat_mod_duration_turns integer;
  v_opponent_stat_mod_max_uses     integer;
  v_opponent_heal_dot_config_amount integer;
  v_opponent_heal_dot_config_turns  integer;
  v_opponent_heal_dot_config_type   text;
  v_opponent_heal_dot_config_percent integer;
  v_opponent_cancel_heal_duration   integer;
  v_opponent_percent_hp_damage_percent integer;
  v_opponent_stat_mod_type_filter   text;
  v_opponent_prevention_duration    integer;
  v_opponent_keep_going_turns       integer;
  v_opponent_keep_going_bonus_type  text;
  v_opponent_keep_going_bonus_flat  integer;
  v_opponent_keep_going_bonus_percent integer;
  v_opponent_heal_dot_config_until_awake boolean;
  v_opponent_ignore_status_block    text;
  -- État persisté des effets ajoutés après coup (miroir des colonnes
  -- autobattle_manual_battles.*, voir autobattle_combatant_state).
  v_player_double_turn_pending      boolean;
  v_opponent_double_turn_pending    boolean;
  v_player_prevention_expires       integer;
  v_opponent_prevention_expires     integer;
  v_player_damage_mod_type_filter   text;
  v_opponent_damage_mod_type_filter text;
  v_player_heal_dot_until_awake     boolean;
  v_opponent_heal_dot_until_awake   boolean;
  v_player_keep_going_ability_nom   text;
  v_opponent_keep_going_ability_nom text;
  v_player_keep_going_remaining     integer;
  v_opponent_keep_going_remaining   integer;
  v_player_keep_going_count         integer;
  v_opponent_keep_going_count       integer;
  -- Capacité imposée au joueur pour le PROCHAIN tour (préparation en cours,
  -- tour passé imposé, ou chaîne "Continue sur sa lancée") — renvoyée au
  -- client, qui verrouille alors la grille de sélection dessus.
  v_player_forced_ability_nom       text;
  v_rewards             jsonb := '[]'::jsonb;
  v_reward              record;
  v_max_level_index     integer;
  v_variant_completed   boolean := false;
  v_next_level_index    integer;
  v_new_xp              integer;
  v_max_xp              integer;
  v_result              jsonb;
  -- Marshalling vers/depuis le moteur de résolution partagé (voir
  -- autobattle_resolve_round_core, juste après autobattle_ability_burst) :
  -- remplace l'ancienne boucle inline, réutilisée telle quelle par pvp_resolve_round.
  v_player_state         autobattle_combatant_state;
  v_opponent_state       autobattle_combatant_state;
  v_player_ability_cfg   autobattle_combatant_ability;
  v_opponent_ability_cfg autobattle_combatant_ability;
  v_round_result         autobattle_round_result;
BEGIN
  SELECT * INTO v_level FROM autobattle_levels WHERE id = p_level_id;
  IF v_level IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;

  SELECT * INTO v_variant FROM autobattle_variants WHERE id = v_level.variant_id;
  IF v_variant IS NULL OR v_variant.enabled = false THEN
    RETURN jsonb_build_object('status', 'variant_disabled');
  END IF;
  IF v_variant.game_mode <> 'manual' THEN
    RETURN jsonb_build_object('status', 'wrong_mode');
  END IF;

  INSERT INTO autobattle_player_variant_progress (player_id, variant_id)
  VALUES (p_player_id, v_variant.id)
  ON CONFLICT (player_id, variant_id) DO NOTHING;

  SELECT * INTO v_progress FROM autobattle_player_variant_progress
    WHERE player_id = p_player_id AND variant_id = v_variant.id FOR UPDATE;

  IF v_progress.variant_completed THEN
    RETURN jsonb_build_object('status', 'variant_completed');
  END IF;
  IF v_progress.current_level_index <> v_level.level_index THEN
    RETURN jsonb_build_object('status', 'wrong_level');
  END IF;

  INSERT INTO autobattle_player_level_state (player_id, level_id)
  VALUES (p_player_id, p_level_id)
  ON CONFLICT (player_id, level_id) DO NOTHING;

  PERFORM 1 FROM autobattle_player_level_state
    WHERE player_id = p_player_id AND level_id = p_level_id FOR UPDATE;

  SELECT * INTO v_pp FROM player_pokemon WHERE id = p_player_pokemon_id AND player_id = p_player_id;
  IF v_pp IS NULL THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;
  IF v_pp.in_daycare THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;

  SELECT * INTO v_player_species FROM pokemon WHERE nom = v_pp.pokemon_nom;
  IF v_player_species IS NULL THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;

  SELECT * INTO v_opponent_species FROM pokemon WHERE nom = v_level.opponent_pokemon_nom;
  IF v_opponent_species IS NULL OR NOT EXISTS (SELECT 1 FROM attacks WHERE nom = v_level.opponent_ability_nom) THEN
    RETURN jsonb_build_object('status', 'invalid_level');
  END IF;

  -- Métamorph JOUEUR : le mouvepool "connu" n'est plus le sien mais
  -- l'ensemble des capacités CONFIGURÉES sur ce niveau pour l'adversaire
  -- (jusqu'à 10, voir autobattle_levels.opponent_ability_nom_2..10) — le
  -- joueur choisit toujours laquelle jouer (contrairement à l'adversaire
  -- Métamorph, qui pioche au hasard dans le movepool du joueur, voir plus
  -- bas) : c'est encore SON tour, juste avec un mouvepool copié.
  v_is_metamorph := v_player_species.nom = 'Métamorph';
  v_player_image_override := CASE WHEN v_is_metamorph THEN v_opponent_species.image_miniature ELSE NULL END;
  IF v_is_metamorph THEN
    v_opponent_ability_sequence := array_remove(ARRAY[
      v_level.opponent_ability_nom, v_level.opponent_ability_nom_2, v_level.opponent_ability_nom_3,
      v_level.opponent_ability_nom_4, v_level.opponent_ability_nom_5, v_level.opponent_ability_nom_6,
      v_level.opponent_ability_nom_7, v_level.opponent_ability_nom_8, v_level.opponent_ability_nom_9,
      v_level.opponent_ability_nom_10
    ], NULL);
    IF NOT (p_ability_nom = ANY(v_opponent_ability_sequence)) THEN
      RETURN jsonb_build_object('status', 'ineligible_ability');
    END IF;
  ELSE
    IF NOT (p_ability_nom = ANY(v_pp.moves)) THEN
      RETURN jsonb_build_object('status', 'ineligible_ability');
    END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM attacks WHERE nom = p_ability_nom) THEN
    RETURN jsonb_build_object('status', 'ineligible_ability');
  END IF;
  IF EXISTS (SELECT 1 FROM autobattle_banned_attacks WHERE attack_nom = p_ability_nom) THEN
    RETURN jsonb_build_object('status', 'ineligible_ability');
  END IF;

  SELECT * INTO v_row FROM autobattle_manual_battles
    WHERE player_id = p_player_id AND level_id = p_level_id FOR UPDATE;

  -- Rejeu idempotent : même tour redemandé (retry réseau) → même réponse,
  -- sans re-débiter de ticket ni re-tirer aucun dé. Vérifié EN PREMIER, avant
  -- toute purge, pour qu'un retry du tout premier tour d'un combat renvoie
  -- bien le résultat déjà calculé au lieu d'être traité comme une purge.
  IF v_row.id IS NOT NULL AND v_row.last_idempotency_key = p_idempotency_key THEN
    RETURN v_row.last_result;
  END IF;

  -- Une ligne déjà terminée (outcome renseigné : gagné/perdu, puis réessayé)
  -- pour un NOUVEAU tour est un vestige d'un combat précédent — filet de
  -- sécurité défensif, ne devrait normalement jamais arriver : le point
  -- d'entrée normal d'un nouveau combat est désormais autobattle_start_
  -- manual_battle, qui purge et recrée systématiquement AVANT tout tour joué
  -- (voir son commentaire — c'est lui qui porte la logique "quitter un
  -- combat en cours et en relancer un nouveau ne doit jamais reprendre les
  -- PV/statuts de l'ancien", plus le 1er tour ici).
  IF v_row.id IS NOT NULL AND v_row.outcome IS NOT NULL THEN
    DELETE FROM autobattle_manual_battles WHERE id = v_row.id;
    v_row := NULL;
  END IF;

  -- La ligne doit déjà exister (créée par autobattle_start_manual_battle,
  -- qui décide first_attacker ET débite le ticket AVANT le 1er choix de
  -- capacité — voir son commentaire) : ce tour ne la crée plus lui-même et
  -- ne touche plus du tout aux tickets.
  IF v_row.id IS NULL THEN
    RETURN jsonb_build_object('status', 'not_started');
  END IF;

  -- État persisté (chargé depuis autobattle_start_manual_battle ou un tour
  -- précédent) : copié dans les variables de travail.
  v_player_hp := v_row.player_hp;
  v_player_max_hp := v_row.player_max_hp;
  v_opponent_hp := v_row.opponent_hp;
  v_first_attacker := v_row.first_attacker;
  v_turn_no := v_row.turn_no;
  v_round_no := v_row.round_no;
  v_player_status := v_row.player_status;
  v_opponent_status := v_row.opponent_status;
  v_player_damage_mod_amount := v_row.player_damage_mod_amount;
  v_player_damage_mod_expires := v_row.player_damage_mod_expires;
  v_player_precision_mod_amount := v_row.player_precision_mod_amount;
  v_player_precision_mod_expires := v_row.player_precision_mod_expires;
  v_opponent_damage_mod_amount := v_row.opponent_damage_mod_amount;
  v_opponent_damage_mod_expires := v_row.opponent_damage_mod_expires;
  v_opponent_precision_mod_amount := v_row.opponent_precision_mod_amount;
  v_opponent_precision_mod_expires := v_row.opponent_precision_mod_expires;
  v_player_heal_dot_amount := v_row.player_heal_dot_amount;
  v_player_heal_dot_expires := v_row.player_heal_dot_expires;
  v_opponent_heal_dot_amount := v_row.opponent_heal_dot_amount;
  v_opponent_heal_dot_expires := v_row.opponent_heal_dot_expires;
  v_player_heal_disabled_expires := v_row.player_heal_disabled_expires;
  v_opponent_heal_disabled_expires := v_row.opponent_heal_disabled_expires;
  v_player_invulnerable := v_row.player_invulnerable;
  v_player_invuln_granted_round := v_row.player_invuln_granted_round;
  v_opponent_invulnerable := v_row.opponent_invulnerable;
  v_opponent_invuln_granted_round := v_row.opponent_invuln_granted_round;
  v_player_used_ability := v_row.player_used_ability;
  v_player_took_damage := v_row.player_took_damage;
  v_opponent_used_ability := v_row.opponent_used_ability;
  v_opponent_took_damage := v_row.opponent_took_damage;
  v_player_skip_pending := v_row.player_skip_pending;
  v_opponent_skip_pending := v_row.opponent_skip_pending;
  v_player_preparing := v_row.player_preparing;
  v_opponent_preparing := v_row.opponent_preparing;
  v_player_preparing_ability_nom := v_row.player_preparing_ability_nom;
  v_opponent_preparing_ability_nom := v_row.opponent_preparing_ability_nom;
  v_player_stat_mod_uses := v_row.player_stat_mod_uses;
  v_opponent_stat_mod_uses := v_row.opponent_stat_mod_uses;
  v_player_double_turn_pending := v_row.player_double_turn_pending;
  v_opponent_double_turn_pending := v_row.opponent_double_turn_pending;
  v_player_prevention_expires := v_row.player_prevention_expires;
  v_opponent_prevention_expires := v_row.opponent_prevention_expires;
  v_player_damage_mod_type_filter := v_row.player_damage_mod_type_filter;
  v_opponent_damage_mod_type_filter := v_row.opponent_damage_mod_type_filter;
  v_player_heal_dot_until_awake := v_row.player_heal_dot_until_awake;
  v_opponent_heal_dot_until_awake := v_row.opponent_heal_dot_until_awake;
  v_player_keep_going_ability_nom := v_row.player_keep_going_ability_nom;
  v_opponent_keep_going_ability_nom := v_row.opponent_keep_going_ability_nom;
  v_player_keep_going_remaining := v_row.player_keep_going_remaining;
  v_opponent_keep_going_remaining := v_row.opponent_keep_going_remaining;
  v_player_keep_going_count := v_row.player_keep_going_count;
  v_opponent_keep_going_count := v_row.opponent_keep_going_count;

  -- Capacité RÉELLEMENT jouée par le joueur ce tour : celle mémorisée s'il
  -- est en cours de préparation (prepare_release, voir plus haut), sinon
  -- celle tout juste choisie (déjà validée ci-dessus).
  -- Une chaîne "Continue sur sa lancée" en cours (voir autobattle_ability_
  -- rules.keep_going_turns) verrouille la capacité exactement comme une
  -- préparation : le choix envoyé par le client est ignoré tant qu'il reste
  -- des réutilisations forcées (le client, prévenu par player_forced_ability_
  -- nom au tour précédent, renvoie de toute façon la même).
  v_effective_player_ability_nom := CASE
    WHEN v_player_preparing THEN v_player_preparing_ability_nom
    WHEN COALESCE(v_player_keep_going_remaining, 0) > 0 AND v_player_keep_going_ability_nom IS NOT NULL THEN v_player_keep_going_ability_nom
    ELSE p_ability_nom END;
  SELECT * INTO v_ability FROM attacks WHERE nom = v_effective_player_ability_nom;

  -- Capacité adverse ce tour : mémorisée si en cours de préparation, sinon
  -- pigée dans la séquence configurée (autobattle_levels.opponent_ability_
  -- nom/_2/_3/_4, en boucle — v_opponent_ability_cycle_index avance d'une
  -- position à chaque NOUVEAU tour adverse) — ou, si l'adversaire est
  -- Métamorph, tirée uniformément parmi TOUTES les capacités apprises par le
  -- pokémon du joueur (requirement dédié : copie tout le movepool du joueur
  -- et l'utilise au hasard, un tirage indépendant par nouveau tour).
  v_is_opponent_metamorph := v_opponent_species.nom = 'Métamorph';
  IF v_opponent_preparing THEN
    v_opponent_ability_nom_round := v_opponent_preparing_ability_nom;
    v_opponent_ability_cycle_index := v_row.opponent_ability_cycle_index;
  ELSIF COALESCE(v_opponent_keep_going_remaining, 0) > 0 AND v_opponent_keep_going_ability_nom IS NOT NULL THEN
    -- Chaîne "Continue sur sa lancée" côté adverse : la capacité reste la
    -- même, la séquence configurée n'avance pas pendant ce temps.
    v_opponent_ability_nom_round := v_opponent_keep_going_ability_nom;
    v_opponent_ability_cycle_index := v_row.opponent_ability_cycle_index;
  ELSIF v_is_opponent_metamorph THEN
    v_opponent_ability_nom_round := v_pp.moves[1 + floor(random() * array_length(v_pp.moves, 1))::integer];
    v_opponent_ability_cycle_index := v_row.opponent_ability_cycle_index;
  ELSE
    v_opponent_ability_sequence := array_remove(ARRAY[
      v_level.opponent_ability_nom, v_level.opponent_ability_nom_2, v_level.opponent_ability_nom_3,
      v_level.opponent_ability_nom_4, v_level.opponent_ability_nom_5, v_level.opponent_ability_nom_6,
      v_level.opponent_ability_nom_7, v_level.opponent_ability_nom_8, v_level.opponent_ability_nom_9,
      v_level.opponent_ability_nom_10
    ], NULL);
    v_opponent_ability_cycle_index := v_row.opponent_ability_cycle_index + 1;
    v_opponent_ability_nom_round := v_opponent_ability_sequence[1 + ((v_opponent_ability_cycle_index - 1) % array_length(v_opponent_ability_sequence, 1))];
  END IF;
  SELECT * INTO v_opponent_ability FROM attacks WHERE nom = v_opponent_ability_nom_round;

  -- Expiration des modificateurs actifs (comparés au numéro de TOUR — voir
  -- v_round_no, pas v_turn_no —, comme en mode Auto) : vérifiée avant de
  -- résoudre quoi que ce soit ce tour.
  IF v_player_damage_mod_expires IS NOT NULL AND v_round_no > v_player_damage_mod_expires THEN
    v_player_damage_mod_amount := 0; v_player_damage_mod_expires := NULL;
  END IF;
  IF v_player_precision_mod_expires IS NOT NULL AND v_round_no > v_player_precision_mod_expires THEN
    v_player_precision_mod_amount := 0; v_player_precision_mod_expires := NULL;
  END IF;
  IF v_opponent_damage_mod_expires IS NOT NULL AND v_round_no > v_opponent_damage_mod_expires THEN
    v_opponent_damage_mod_amount := 0; v_opponent_damage_mod_expires := NULL;
  END IF;
  IF v_opponent_precision_mod_expires IS NOT NULL AND v_round_no > v_opponent_precision_mod_expires THEN
    v_opponent_precision_mod_amount := 0; v_opponent_precision_mod_expires := NULL;
  END IF;
  IF v_player_heal_dot_expires IS NOT NULL AND v_round_no > v_player_heal_dot_expires THEN
    v_player_heal_dot_amount := NULL; v_player_heal_dot_expires := NULL;
  END IF;
  IF v_opponent_heal_dot_expires IS NOT NULL AND v_round_no > v_opponent_heal_dot_expires THEN
    v_opponent_heal_dot_amount := NULL; v_opponent_heal_dot_expires := NULL;
  END IF;
  IF v_player_heal_disabled_expires IS NOT NULL AND v_round_no > v_player_heal_disabled_expires THEN
    v_player_heal_disabled_expires := NULL;
  END IF;
  IF v_opponent_heal_disabled_expires IS NOT NULL AND v_round_no > v_opponent_heal_disabled_expires THEN
    v_opponent_heal_disabled_expires := NULL;
  END IF;

  -- Super efficace : la capacité utilisée doit être du MÊME type que le
  -- pokémon qui l'utilise, en plus d'être favorable dans la table de types
  -- (voir même remarque en mode Auto, autobattle_resolve_battle) — recalculé
  -- CHAQUE round ici (contrairement au mode Auto, figé pour tout le combat)
  -- puisque la capacité jouée change à chaque tour. Métamorph JOUEUR : copie
  -- le type et la liste "super efficace" de l'ADVERSAIRE (comme Métamorph
  -- adversaire copie ceux du joueur ci-dessous) — pas les siens propres.
  v_player_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (CASE WHEN v_is_metamorph THEN v_opponent_species.super_efficace_1 ELSE v_player_species.super_efficace_1 END),
      (CASE WHEN v_is_metamorph THEN v_opponent_species.super_efficace_2 ELSE v_player_species.super_efficace_2 END),
      (CASE WHEN v_is_metamorph THEN v_opponent_species.super_efficace_3 ELSE v_player_species.super_efficace_3 END),
      (CASE WHEN v_is_metamorph THEN v_opponent_species.super_efficace_4 ELSE v_player_species.super_efficace_4 END)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(v_opponent_species.type))
  ) AND lower(trim(v_ability.type)) = lower(trim(CASE WHEN v_is_metamorph THEN v_opponent_species.type ELSE v_player_species.type END));
  -- Dégâts de base "espèce" : copie ceux de l'adversaire (SANS bonus XP —
  -- reste une progression personnelle du joueur, jamais copiée, même
  -- principe qu'en mode Auto) au lieu des siens propres.
  v_player_damage_species_xp := (CASE WHEN v_is_metamorph THEN COALESCE(v_opponent_species.degats_base, 0) ELSE COALESCE(v_player_species.degats_base, 0) END)
    + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'DMG');
  v_player_damage := v_player_damage_species_xp
    * (CASE WHEN v_player_type_bonus THEN 2 ELSE 1 END) + COALESCE(v_ability.degats_base, 0);
  v_player_damage_original := v_player_damage;

  -- Métamorph adversaire : copie le type et la liste "super efficace" du
  -- pokémon du JOUEUR (comme en mode Auto, autobattle_resolve_battle) — pas
  -- les siens propres, qui n'ont aucun sens pour Métamorph. Recalculé CHAQUE
  -- round comme v_player_type_bonus ci-dessus (la capacité change à chaque
  -- tour, potentiellement piochée dans un movepool différent).
  v_opponent_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (CASE WHEN v_is_opponent_metamorph THEN v_player_species.super_efficace_1 ELSE v_opponent_species.super_efficace_1 END),
      (CASE WHEN v_is_opponent_metamorph THEN v_player_species.super_efficace_2 ELSE v_opponent_species.super_efficace_2 END),
      (CASE WHEN v_is_opponent_metamorph THEN v_player_species.super_efficace_3 ELSE v_opponent_species.super_efficace_3 END),
      (CASE WHEN v_is_opponent_metamorph THEN v_player_species.super_efficace_4 ELSE v_opponent_species.super_efficace_4 END)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(v_player_species.type))
  ) AND lower(trim(v_opponent_ability.type)) = lower(trim(CASE WHEN v_is_opponent_metamorph THEN v_player_species.type ELSE v_opponent_species.type END));
  -- Dégâts de base "espèce" : copie ceux du joueur (SANS son bonus XP,
  -- progression personnelle jamais "copiée" — même principe qu'en mode Auto)
  -- au lieu du dégât de base configuré sur le niveau.
  v_opponent_damage_species_xp := CASE WHEN v_is_opponent_metamorph THEN COALESCE(v_player_species.degats_base, 0) ELSE COALESCE(v_level.opponent_base_damage, 0) END;
  v_opponent_damage := v_opponent_damage_species_xp * (CASE WHEN v_opponent_type_bonus THEN 2 ELSE 1 END)
    + COALESCE(v_opponent_ability.degats_base, 0);
  v_opponent_damage_original := v_opponent_damage;

  v_player_never_miss := v_ability.precision IS NULL OR v_ability.precision = 0;
  v_opponent_never_miss := v_opponent_ability.precision IS NULL OR v_opponent_ability.precision = 0;
  SELECT precision_enabled INTO v_precision_enabled FROM autobattle_config WHERE id = 1;
  v_precision_enabled := COALESCE(v_precision_enabled, true);

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_player_turn_effect, v_player_repeat_max, v_player_heal_type, v_player_heal_amount, v_player_heal_percent, v_player_status_reversed,
         v_player_recoil_type, v_player_recoil_min, v_player_recoil_max, v_player_recoil_percent, v_player_invuln_grant,
         v_player_bonus_type, v_player_bonus_multiplier, v_player_bonus_flat, v_player_bonus_min, v_player_bonus_max,
         v_player_bonus_condition, v_player_bonus_dice_value, v_player_bonus_status_filter,
         v_player_stat_mod_target, v_player_stat_mod_stat, v_player_stat_mod_value_type, v_player_stat_mod_flat, v_player_stat_mod_min, v_player_stat_mod_max, v_player_stat_mod_percent,
         v_player_stat_mod_duration_type, v_player_stat_mod_duration_turns, v_player_stat_mod_max_uses,
         v_player_heal_dot_config_amount, v_player_heal_dot_config_turns, v_player_heal_dot_config_type, v_player_heal_dot_config_percent, v_player_cancel_heal_duration, v_player_percent_hp_damage_percent,
         v_player_stat_mod_type_filter, v_player_prevention_duration,
         v_player_keep_going_turns, v_player_keep_going_bonus_type, v_player_keep_going_bonus_flat, v_player_keep_going_bonus_percent,
         v_player_heal_dot_config_until_awake, v_player_ignore_status_block
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_player_ability_nom;
  v_player_status_reversed := COALESCE(v_player_status_reversed, false);
  v_player_invuln_grant := COALESCE(v_player_invuln_grant, false);
  v_player_heal_dot_config_until_awake := COALESCE(v_player_heal_dot_config_until_awake, false);

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_opponent_turn_effect, v_opponent_repeat_max, v_opponent_heal_type, v_opponent_heal_amount, v_opponent_heal_percent, v_opponent_status_reversed,
         v_opponent_recoil_type, v_opponent_recoil_min, v_opponent_recoil_max, v_opponent_recoil_percent, v_opponent_invuln_grant,
         v_opponent_bonus_type, v_opponent_bonus_multiplier, v_opponent_bonus_flat, v_opponent_bonus_min, v_opponent_bonus_max,
         v_opponent_bonus_condition, v_opponent_bonus_dice_value, v_opponent_bonus_status_filter,
         v_opponent_stat_mod_target, v_opponent_stat_mod_stat, v_opponent_stat_mod_value_type, v_opponent_stat_mod_flat, v_opponent_stat_mod_min, v_opponent_stat_mod_max, v_opponent_stat_mod_percent,
         v_opponent_stat_mod_duration_type, v_opponent_stat_mod_duration_turns, v_opponent_stat_mod_max_uses,
         v_opponent_heal_dot_config_amount, v_opponent_heal_dot_config_turns, v_opponent_heal_dot_config_type, v_opponent_heal_dot_config_percent, v_opponent_cancel_heal_duration, v_opponent_percent_hp_damage_percent,
         v_opponent_stat_mod_type_filter, v_opponent_prevention_duration,
         v_opponent_keep_going_turns, v_opponent_keep_going_bonus_type, v_opponent_keep_going_bonus_flat, v_opponent_keep_going_bonus_percent,
         v_opponent_heal_dot_config_until_awake, v_opponent_ignore_status_block
    FROM autobattle_ability_rules WHERE attack_nom = v_opponent_ability_nom_round;
  v_opponent_status_reversed := COALESCE(v_opponent_status_reversed, false);
  v_opponent_invuln_grant := COALESCE(v_opponent_invuln_grant, false);
  v_opponent_heal_dot_config_until_awake := COALESCE(v_opponent_heal_dot_config_until_awake, false);

  -- Empaquette l'état/la capacité de chaque camp dans les types partagés
  -- (voir autobattle_resolve_round_core, juste après autobattle_ability_burst
  -- plus haut dans ce fichier) puis délègue la résolution du round à ce
  -- moteur commun — réutilisé tel quel par pvp_resolve_round, aucune
  -- duplication de la boucle de résolution elle-même. Tout ce qui suit
  -- (récompenses/progression) relit les mêmes variables qu'avant ce
  -- changement, simplement réalimentées depuis le résultat du moteur.
  v_player_state.hp := v_player_hp;
  v_player_state.max_hp := v_player_max_hp;
  v_player_state.status := v_player_status;
  v_player_state.damage_mod_amount := v_player_damage_mod_amount;
  v_player_state.damage_mod_expires := v_player_damage_mod_expires;
  v_player_state.precision_mod_amount := v_player_precision_mod_amount;
  v_player_state.precision_mod_expires := v_player_precision_mod_expires;
  v_player_state.heal_dot_amount := v_player_heal_dot_amount;
  v_player_state.heal_dot_expires := v_player_heal_dot_expires;
  v_player_state.heal_disabled_expires := v_player_heal_disabled_expires;
  v_player_state.invulnerable := v_player_invulnerable;
  v_player_state.invuln_granted_round := v_player_invuln_granted_round;
  v_player_state.stat_mod_uses := v_player_stat_mod_uses;
  v_player_state.used_ability := v_player_used_ability;
  v_player_state.took_damage := v_player_took_damage;
  v_player_state.skip_pending := v_player_skip_pending;
  v_player_state.preparing := v_player_preparing;
  v_player_state.preparing_ability_nom := v_player_preparing_ability_nom;
  v_player_state.double_turn_pending := v_player_double_turn_pending;
  v_player_state.prevention_expires := v_player_prevention_expires;
  v_player_state.damage_mod_type_filter := v_player_damage_mod_type_filter;
  v_player_state.heal_dot_until_awake := v_player_heal_dot_until_awake;
  v_player_state.keep_going_ability_nom := v_player_keep_going_ability_nom;
  v_player_state.keep_going_remaining := v_player_keep_going_remaining;
  v_player_state.keep_going_count := v_player_keep_going_count;

  v_opponent_state.hp := v_opponent_hp;
  v_opponent_state.max_hp := v_level.opponent_hp;
  v_opponent_state.status := v_opponent_status;
  v_opponent_state.damage_mod_amount := v_opponent_damage_mod_amount;
  v_opponent_state.damage_mod_expires := v_opponent_damage_mod_expires;
  v_opponent_state.precision_mod_amount := v_opponent_precision_mod_amount;
  v_opponent_state.precision_mod_expires := v_opponent_precision_mod_expires;
  v_opponent_state.heal_dot_amount := v_opponent_heal_dot_amount;
  v_opponent_state.heal_dot_expires := v_opponent_heal_dot_expires;
  v_opponent_state.heal_disabled_expires := v_opponent_heal_disabled_expires;
  v_opponent_state.invulnerable := v_opponent_invulnerable;
  v_opponent_state.invuln_granted_round := v_opponent_invuln_granted_round;
  v_opponent_state.stat_mod_uses := v_opponent_stat_mod_uses;
  v_opponent_state.used_ability := v_opponent_used_ability;
  v_opponent_state.took_damage := v_opponent_took_damage;
  v_opponent_state.skip_pending := v_opponent_skip_pending;
  v_opponent_state.preparing := v_opponent_preparing;
  v_opponent_state.preparing_ability_nom := v_opponent_preparing_ability_nom;
  v_opponent_state.double_turn_pending := v_opponent_double_turn_pending;
  v_opponent_state.prevention_expires := v_opponent_prevention_expires;
  v_opponent_state.damage_mod_type_filter := v_opponent_damage_mod_type_filter;
  v_opponent_state.heal_dot_until_awake := v_opponent_heal_dot_until_awake;
  v_opponent_state.keep_going_ability_nom := v_opponent_keep_going_ability_nom;
  v_opponent_state.keep_going_remaining := v_opponent_keep_going_remaining;
  v_opponent_state.keep_going_count := v_opponent_keep_going_count;

  v_player_ability_cfg.ability_nom := v_effective_player_ability_nom;
  v_player_ability_cfg.base_damage := v_player_damage;
  v_player_ability_cfg.damage_species_xp := v_player_damage_species_xp;
  v_player_ability_cfg.type_bonus := v_player_type_bonus;
  v_player_ability_cfg.precision := v_ability.precision;
  v_player_ability_cfg.degats_de := v_ability.degats_de;
  v_player_ability_cfg.deals_damage := v_ability.deals_damage;
  v_player_ability_cfg.status_effect := v_ability.status_effect;
  v_player_ability_cfg.status_chance := v_ability.status_chance;
  v_player_ability_cfg.turn_effect := v_player_turn_effect;
  v_player_ability_cfg.repeat_max := v_player_repeat_max;
  v_player_ability_cfg.heal_type := v_player_heal_type;
  v_player_ability_cfg.heal_amount := v_player_heal_amount;
  v_player_ability_cfg.heal_percent := v_player_heal_percent;
  v_player_ability_cfg.status_reversed := v_player_status_reversed;
  v_player_ability_cfg.recoil_type := v_player_recoil_type;
  v_player_ability_cfg.recoil_min := v_player_recoil_min;
  v_player_ability_cfg.recoil_max := v_player_recoil_max;
  v_player_ability_cfg.recoil_percent := v_player_recoil_percent;
  v_player_ability_cfg.invuln_grant := v_player_invuln_grant;
  v_player_ability_cfg.bonus_type := v_player_bonus_type;
  v_player_ability_cfg.bonus_multiplier := v_player_bonus_multiplier;
  v_player_ability_cfg.bonus_flat := v_player_bonus_flat;
  v_player_ability_cfg.bonus_min := v_player_bonus_min;
  v_player_ability_cfg.bonus_max := v_player_bonus_max;
  v_player_ability_cfg.bonus_condition := v_player_bonus_condition;
  v_player_ability_cfg.bonus_dice_value := v_player_bonus_dice_value;
  v_player_ability_cfg.bonus_status_filter := v_player_bonus_status_filter;
  v_player_ability_cfg.stat_mod_target := v_player_stat_mod_target;
  v_player_ability_cfg.stat_mod_stat := v_player_stat_mod_stat;
  v_player_ability_cfg.stat_mod_value_type := v_player_stat_mod_value_type;
  v_player_ability_cfg.stat_mod_flat := v_player_stat_mod_flat;
  v_player_ability_cfg.stat_mod_min := v_player_stat_mod_min;
  v_player_ability_cfg.stat_mod_max := v_player_stat_mod_max;
  v_player_ability_cfg.stat_mod_percent := v_player_stat_mod_percent;
  v_player_ability_cfg.stat_mod_duration_type := v_player_stat_mod_duration_type;
  v_player_ability_cfg.stat_mod_duration_turns := v_player_stat_mod_duration_turns;
  v_player_ability_cfg.stat_mod_max_uses := v_player_stat_mod_max_uses;
  v_player_ability_cfg.heal_dot_config_amount := v_player_heal_dot_config_amount;
  v_player_ability_cfg.heal_dot_config_turns := v_player_heal_dot_config_turns;
  v_player_ability_cfg.heal_dot_config_type := v_player_heal_dot_config_type;
  v_player_ability_cfg.heal_dot_config_percent := v_player_heal_dot_config_percent;
  v_player_ability_cfg.cancel_heal_duration := v_player_cancel_heal_duration;
  v_player_ability_cfg.percent_hp_damage_percent := v_player_percent_hp_damage_percent;
  v_player_ability_cfg.ability_type := v_ability.type;
  v_player_ability_cfg.stat_mod_type_filter := v_player_stat_mod_type_filter;
  v_player_ability_cfg.prevention_duration := v_player_prevention_duration;
  v_player_ability_cfg.keep_going_turns := v_player_keep_going_turns;
  v_player_ability_cfg.keep_going_bonus_type := v_player_keep_going_bonus_type;
  v_player_ability_cfg.keep_going_bonus_flat := v_player_keep_going_bonus_flat;
  v_player_ability_cfg.keep_going_bonus_percent := v_player_keep_going_bonus_percent;
  v_player_ability_cfg.heal_dot_until_awake := v_player_heal_dot_config_until_awake;
  v_player_ability_cfg.ignore_status_block := v_player_ignore_status_block;

  v_opponent_ability_cfg.ability_nom := v_opponent_ability_nom_round;
  v_opponent_ability_cfg.base_damage := v_opponent_damage;
  v_opponent_ability_cfg.damage_species_xp := v_opponent_damage_species_xp;
  v_opponent_ability_cfg.type_bonus := v_opponent_type_bonus;
  v_opponent_ability_cfg.precision := v_opponent_ability.precision;
  v_opponent_ability_cfg.degats_de := v_opponent_ability.degats_de;
  v_opponent_ability_cfg.deals_damage := v_opponent_ability.deals_damage;
  v_opponent_ability_cfg.status_effect := v_opponent_ability.status_effect;
  v_opponent_ability_cfg.status_chance := v_opponent_ability.status_chance;
  v_opponent_ability_cfg.turn_effect := v_opponent_turn_effect;
  v_opponent_ability_cfg.repeat_max := v_opponent_repeat_max;
  v_opponent_ability_cfg.heal_type := v_opponent_heal_type;
  v_opponent_ability_cfg.heal_amount := v_opponent_heal_amount;
  v_opponent_ability_cfg.heal_percent := v_opponent_heal_percent;
  v_opponent_ability_cfg.status_reversed := v_opponent_status_reversed;
  v_opponent_ability_cfg.recoil_type := v_opponent_recoil_type;
  v_opponent_ability_cfg.recoil_min := v_opponent_recoil_min;
  v_opponent_ability_cfg.recoil_max := v_opponent_recoil_max;
  v_opponent_ability_cfg.recoil_percent := v_opponent_recoil_percent;
  v_opponent_ability_cfg.invuln_grant := v_opponent_invuln_grant;
  v_opponent_ability_cfg.bonus_type := v_opponent_bonus_type;
  v_opponent_ability_cfg.bonus_multiplier := v_opponent_bonus_multiplier;
  v_opponent_ability_cfg.bonus_flat := v_opponent_bonus_flat;
  v_opponent_ability_cfg.bonus_min := v_opponent_bonus_min;
  v_opponent_ability_cfg.bonus_max := v_opponent_bonus_max;
  v_opponent_ability_cfg.bonus_condition := v_opponent_bonus_condition;
  v_opponent_ability_cfg.bonus_dice_value := v_opponent_bonus_dice_value;
  v_opponent_ability_cfg.bonus_status_filter := v_opponent_bonus_status_filter;
  v_opponent_ability_cfg.stat_mod_target := v_opponent_stat_mod_target;
  v_opponent_ability_cfg.stat_mod_stat := v_opponent_stat_mod_stat;
  v_opponent_ability_cfg.stat_mod_value_type := v_opponent_stat_mod_value_type;
  v_opponent_ability_cfg.stat_mod_flat := v_opponent_stat_mod_flat;
  v_opponent_ability_cfg.stat_mod_min := v_opponent_stat_mod_min;
  v_opponent_ability_cfg.stat_mod_max := v_opponent_stat_mod_max;
  v_opponent_ability_cfg.stat_mod_percent := v_opponent_stat_mod_percent;
  v_opponent_ability_cfg.stat_mod_duration_type := v_opponent_stat_mod_duration_type;
  v_opponent_ability_cfg.stat_mod_duration_turns := v_opponent_stat_mod_duration_turns;
  v_opponent_ability_cfg.stat_mod_max_uses := v_opponent_stat_mod_max_uses;
  v_opponent_ability_cfg.heal_dot_config_amount := v_opponent_heal_dot_config_amount;
  v_opponent_ability_cfg.heal_dot_config_turns := v_opponent_heal_dot_config_turns;
  v_opponent_ability_cfg.heal_dot_config_type := v_opponent_heal_dot_config_type;
  v_opponent_ability_cfg.heal_dot_config_percent := v_opponent_heal_dot_config_percent;
  v_opponent_ability_cfg.cancel_heal_duration := v_opponent_cancel_heal_duration;
  v_opponent_ability_cfg.percent_hp_damage_percent := v_opponent_percent_hp_damage_percent;
  v_opponent_ability_cfg.ability_type := v_opponent_ability.type;
  v_opponent_ability_cfg.stat_mod_type_filter := v_opponent_stat_mod_type_filter;
  v_opponent_ability_cfg.prevention_duration := v_opponent_prevention_duration;
  v_opponent_ability_cfg.keep_going_turns := v_opponent_keep_going_turns;
  v_opponent_ability_cfg.keep_going_bonus_type := v_opponent_keep_going_bonus_type;
  v_opponent_ability_cfg.keep_going_bonus_flat := v_opponent_keep_going_bonus_flat;
  v_opponent_ability_cfg.keep_going_bonus_percent := v_opponent_keep_going_bonus_percent;
  v_opponent_ability_cfg.heal_dot_until_awake := v_opponent_heal_dot_config_until_awake;
  v_opponent_ability_cfg.ignore_status_block := v_opponent_ignore_status_block;

  v_round_result := autobattle_resolve_round_core(
    v_turn_no, v_round_no, v_first_attacker,
    v_player_state, v_opponent_state, v_player_ability_cfg, v_opponent_ability_cfg,
    v_precision_enabled
  );

  v_player_hp := (v_round_result.player_state).hp;
  v_player_status := (v_round_result.player_state).status;
  v_player_damage_mod_amount := (v_round_result.player_state).damage_mod_amount;
  v_player_damage_mod_expires := (v_round_result.player_state).damage_mod_expires;
  v_player_precision_mod_amount := (v_round_result.player_state).precision_mod_amount;
  v_player_precision_mod_expires := (v_round_result.player_state).precision_mod_expires;
  v_player_heal_dot_amount := (v_round_result.player_state).heal_dot_amount;
  v_player_heal_dot_expires := (v_round_result.player_state).heal_dot_expires;
  v_player_heal_disabled_expires := (v_round_result.player_state).heal_disabled_expires;
  v_player_invulnerable := (v_round_result.player_state).invulnerable;
  v_player_invuln_granted_round := (v_round_result.player_state).invuln_granted_round;
  v_player_stat_mod_uses := (v_round_result.player_state).stat_mod_uses;
  v_player_used_ability := (v_round_result.player_state).used_ability;
  v_player_took_damage := (v_round_result.player_state).took_damage;
  v_player_skip_pending := (v_round_result.player_state).skip_pending;
  v_player_preparing := (v_round_result.player_state).preparing;
  v_player_preparing_ability_nom := (v_round_result.player_state).preparing_ability_nom;
  v_player_double_turn_pending := (v_round_result.player_state).double_turn_pending;
  v_player_prevention_expires := (v_round_result.player_state).prevention_expires;
  v_player_damage_mod_type_filter := (v_round_result.player_state).damage_mod_type_filter;
  v_player_heal_dot_until_awake := COALESCE((v_round_result.player_state).heal_dot_until_awake, false);
  v_player_keep_going_ability_nom := (v_round_result.player_state).keep_going_ability_nom;
  v_player_keep_going_remaining := COALESCE((v_round_result.player_state).keep_going_remaining, 0);
  v_player_keep_going_count := COALESCE((v_round_result.player_state).keep_going_count, 0);

  v_opponent_hp := (v_round_result.opponent_state).hp;
  v_opponent_status := (v_round_result.opponent_state).status;
  v_opponent_damage_mod_amount := (v_round_result.opponent_state).damage_mod_amount;
  v_opponent_damage_mod_expires := (v_round_result.opponent_state).damage_mod_expires;
  v_opponent_precision_mod_amount := (v_round_result.opponent_state).precision_mod_amount;
  v_opponent_precision_mod_expires := (v_round_result.opponent_state).precision_mod_expires;
  v_opponent_heal_dot_amount := (v_round_result.opponent_state).heal_dot_amount;
  v_opponent_heal_dot_expires := (v_round_result.opponent_state).heal_dot_expires;
  v_opponent_heal_disabled_expires := (v_round_result.opponent_state).heal_disabled_expires;
  v_opponent_invulnerable := (v_round_result.opponent_state).invulnerable;
  v_opponent_invuln_granted_round := (v_round_result.opponent_state).invuln_granted_round;
  v_opponent_stat_mod_uses := (v_round_result.opponent_state).stat_mod_uses;
  v_opponent_used_ability := (v_round_result.opponent_state).used_ability;
  v_opponent_took_damage := (v_round_result.opponent_state).took_damage;
  v_opponent_skip_pending := (v_round_result.opponent_state).skip_pending;
  v_opponent_preparing := (v_round_result.opponent_state).preparing;
  v_opponent_preparing_ability_nom := (v_round_result.opponent_state).preparing_ability_nom;
  v_opponent_double_turn_pending := (v_round_result.opponent_state).double_turn_pending;
  v_opponent_prevention_expires := (v_round_result.opponent_state).prevention_expires;
  v_opponent_damage_mod_type_filter := (v_round_result.opponent_state).damage_mod_type_filter;
  v_opponent_heal_dot_until_awake := COALESCE((v_round_result.opponent_state).heal_dot_until_awake, false);
  v_opponent_keep_going_ability_nom := (v_round_result.opponent_state).keep_going_ability_nom;
  v_opponent_keep_going_remaining := COALESCE((v_round_result.opponent_state).keep_going_remaining, 0);
  v_opponent_keep_going_count := COALESCE((v_round_result.opponent_state).keep_going_count, 0);

  v_turns := v_round_result.turns;
  v_outcome := v_round_result.outcome;
  v_turn_no := v_round_result.turn_no;
  v_round_no := v_round_result.round_no;
  -- Un camp qui a gagné une action supplémentaire ('charge_double_next'
  -- libéré, 'first_and_replay') reprend la main dès le début du round
  -- suivant — c'est ce qui lui donne deux actions consécutives, et pour
  -- 'first_and_replay' ce qui le fait "passer premier" durablement.
  v_first_attacker := COALESCE(v_round_result.next_first_attacker, v_first_attacker);

  -- Un round peut se terminer AVANT que l'adversaire n'ait joué (le joueur a
  -- gagné une action supplémentaire et reprend la main immédiatement) : sa
  -- séquence de capacités ne doit alors pas avancer, sinon une position serait
  -- sautée sans jamais avoir été jouée.
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_turns) t WHERE t ->> 'attacker' = 'opponent') THEN
    v_opponent_ability_cycle_index := v_row.opponent_ability_cycle_index;
  END IF;

  -- Capacité imposée au joueur au PROCHAIN tour : préparation en cours,
  -- tour passé imposé par l'effet 'skip', ou chaîne "Continue sur sa
  -- lancée" encore active. Le client verrouille sa grille dessus au lieu de
  -- deviner à partir du turn_effect de la capacité jouée.
  v_player_forced_ability_nom := CASE
    WHEN v_outcome IS NOT NULL THEN NULL
    WHEN v_player_preparing THEN v_player_preparing_ability_nom
    WHEN v_player_skip_pending THEN v_effective_player_ability_nom
    WHEN COALESCE(v_player_keep_going_remaining, 0) > 0 THEN v_player_keep_going_ability_nom
    ELSE NULL END;

  IF v_outcome = 'win' THEN
    UPDATE player_pokemon SET battles_won = battles_won + 1 WHERE id = p_player_pokemon_id;

    FOR v_reward IN SELECT * FROM autobattle_level_rewards WHERE level_id = p_level_id ORDER BY sort_order LOOP
      IF v_reward.reward_type = 'xp' THEN
        v_max_xp := autobattle_max_xp(v_pp.pokemon_nom);
        v_new_xp := GREATEST(0, v_pp.xp + v_reward.xp_amount);
        IF v_max_xp IS NOT NULL THEN v_new_xp := LEAST(v_new_xp, v_max_xp); END IF;
        UPDATE player_pokemon SET xp = v_new_xp WHERE id = p_player_pokemon_id;
        v_rewards := v_rewards || jsonb_build_array(jsonb_build_object(
          'reward_type', 'xp', 'xp_amount', v_reward.xp_amount,
          'player_pokemon_id', p_player_pokemon_id, 'xp_before', v_pp.xp, 'xp_after', v_new_xp
        ));
        v_pp.xp := v_new_xp;
      ELSE
        INSERT INTO player_items (player_id, item_nom, quantity)
        VALUES (p_player_id, v_reward.item_nom, v_reward.item_quantity)
        ON CONFLICT (player_id, item_nom) DO UPDATE SET quantity = player_items.quantity + EXCLUDED.quantity;
        v_rewards := v_rewards || jsonb_build_array(jsonb_build_object(
          'reward_type', v_reward.reward_type, 'item_nom', v_reward.item_nom, 'quantity', v_reward.item_quantity
        ));
      END IF;
    END LOOP;

    UPDATE autobattle_player_level_state
      SET discovered = true, discovered_at = COALESCE(discovered_at, now()), completed = true, completed_at = now()
      WHERE player_id = p_player_id AND level_id = p_level_id;

    SELECT MAX(level_index) INTO v_max_level_index FROM autobattle_levels WHERE variant_id = v_variant.id;
    IF v_level.level_index >= v_max_level_index THEN
      v_variant_completed := true;
      v_next_level_index := v_progress.current_level_index;
    ELSE
      v_next_level_index := v_progress.current_level_index + 1;
    END IF;

    UPDATE autobattle_player_variant_progress
      SET current_level_index = v_next_level_index, variant_completed = v_variant_completed,
          completed_at = CASE WHEN v_variant_completed THEN now() ELSE completed_at END
      WHERE player_id = p_player_id AND variant_id = v_variant.id;
  ELSIF v_outcome = 'lose' THEN
    UPDATE autobattle_player_level_state
      SET discovered = true, discovered_at = COALESCE(discovered_at, now())
      WHERE player_id = p_player_id AND level_id = p_level_id;
    v_next_level_index := v_progress.current_level_index;
  END IF;

  v_result := jsonb_build_object(
    'status', 'ok',
    'turn_no', v_turn_no,
    -- Celui du PROCHAIN round : v_first_attacker vient d'être remis à jour
    -- ci-dessus à partir de next_first_attacker, et c'est bien l'ordre à
    -- venir qui intéresse le client (badge "(1er)"/"(2ème)" affiché pendant
    -- qu'il choisit sa prochaine capacité).
    'first_attacker', v_first_attacker,
    'player_hp', GREATEST(0, v_player_hp),
    'player_max_hp', v_player_max_hp,
    'opponent_hp', GREATEST(0, v_opponent_hp),
    'opponent_max_hp', v_level.opponent_hp,
    'player_damage_per_hit', v_player_damage,
    'opponent_damage_per_hit', v_opponent_damage,
    'player_type_bonus', v_player_type_bonus,
    'opponent_type_bonus', v_opponent_type_bonus,
    'turns', v_turns,
    'outcome', v_outcome,
    'rewards', v_rewards,
    'variant_completed', v_variant_completed,
    'next_level_index', v_next_level_index,
    'opponent_pokemon_nom', v_level.opponent_pokemon_nom,
    'opponent_ability_nom', v_opponent_ability_nom_round,
    'player_ability_nom', v_effective_player_ability_nom,
    'player_forced_ability_nom', v_player_forced_ability_nom,
    -- Cas Métamorph adversaire : sprite du joueur copié pour ce combat (voir
    -- même champ en mode Auto, autobattle_resolve_battle) — absent en mode
    -- Manuel jusqu'ici, le client ne pouvait donc jamais afficher le sprite
    -- copié pour l'adversaire (seules les capacités l'étaient).
    'opponent_image_override', CASE WHEN v_is_opponent_metamorph THEN v_player_species.image_miniature ELSE NULL END,
    -- Cas Métamorph JOUEUR : sprite de l'adversaire copié pour ce combat.
    'player_image_override', v_player_image_override
  );

  IF v_outcome IS NULL THEN
    UPDATE autobattle_manual_battles SET
      turn_no = v_turn_no, round_no = v_round_no, player_hp = v_player_hp, opponent_hp = v_opponent_hp,
      player_status = v_player_status, opponent_status = v_opponent_status,
      player_damage_mod_amount = v_player_damage_mod_amount, player_damage_mod_expires = v_player_damage_mod_expires,
      player_precision_mod_amount = v_player_precision_mod_amount, player_precision_mod_expires = v_player_precision_mod_expires,
      opponent_damage_mod_amount = v_opponent_damage_mod_amount, opponent_damage_mod_expires = v_opponent_damage_mod_expires,
      opponent_precision_mod_amount = v_opponent_precision_mod_amount, opponent_precision_mod_expires = v_opponent_precision_mod_expires,
      player_heal_dot_amount = v_player_heal_dot_amount, player_heal_dot_expires = v_player_heal_dot_expires,
      opponent_heal_dot_amount = v_opponent_heal_dot_amount, opponent_heal_dot_expires = v_opponent_heal_dot_expires,
      player_heal_disabled_expires = v_player_heal_disabled_expires, opponent_heal_disabled_expires = v_opponent_heal_disabled_expires,
      player_invulnerable = v_player_invulnerable, player_invuln_granted_round = v_player_invuln_granted_round,
      opponent_invulnerable = v_opponent_invulnerable, opponent_invuln_granted_round = v_opponent_invuln_granted_round,
      player_used_ability = v_player_used_ability, player_took_damage = v_player_took_damage,
      opponent_used_ability = v_opponent_used_ability, opponent_took_damage = v_opponent_took_damage,
      player_skip_pending = v_player_skip_pending, opponent_skip_pending = v_opponent_skip_pending,
      player_preparing = v_player_preparing, opponent_preparing = v_opponent_preparing,
      player_preparing_ability_nom = v_player_preparing_ability_nom, opponent_preparing_ability_nom = v_opponent_preparing_ability_nom,
      first_attacker = v_first_attacker,
      player_double_turn_pending = v_player_double_turn_pending, opponent_double_turn_pending = v_opponent_double_turn_pending,
      player_prevention_expires = v_player_prevention_expires, opponent_prevention_expires = v_opponent_prevention_expires,
      player_damage_mod_type_filter = v_player_damage_mod_type_filter, opponent_damage_mod_type_filter = v_opponent_damage_mod_type_filter,
      player_heal_dot_until_awake = v_player_heal_dot_until_awake, opponent_heal_dot_until_awake = v_opponent_heal_dot_until_awake,
      player_keep_going_ability_nom = v_player_keep_going_ability_nom, opponent_keep_going_ability_nom = v_opponent_keep_going_ability_nom,
      player_keep_going_remaining = v_player_keep_going_remaining, opponent_keep_going_remaining = v_opponent_keep_going_remaining,
      player_keep_going_count = v_player_keep_going_count, opponent_keep_going_count = v_opponent_keep_going_count,
      opponent_ability_cycle_index = v_opponent_ability_cycle_index,
      player_stat_mod_uses = v_player_stat_mod_uses, opponent_stat_mod_uses = v_opponent_stat_mod_uses,
      turn_log = turn_log || v_turns, last_idempotency_key = p_idempotency_key, last_result = v_result
    WHERE id = v_row.id;
  ELSE
    UPDATE autobattle_manual_battles SET
      turn_no = v_turn_no, round_no = v_round_no, player_hp = v_player_hp, opponent_hp = v_opponent_hp,
      outcome = v_outcome, turn_log = turn_log || v_turns,
      last_idempotency_key = p_idempotency_key, last_result = v_result
    WHERE id = v_row.id;
  END IF;

  RETURN v_result;
END;
$$;

-- ============================================================
-- 7. PvP (défi posté) et PvP (combat d'essai admin)
-- ============================================================
CREATE OR REPLACE FUNCTION pvp_resolve_round(
  p_attacker_player_id bigint,
  p_challenge_id bigint,
  p_attacker_player_pokemon_id bigint,
  p_ability_nom text,
  p_idempotency_key uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_challenge              record;
  v_pp                     record;
  v_a_species              record;
  v_ability                record;
  v_d_species              record;
  v_d_ability              record;
  v_row                    pvp_battles%ROWTYPE;
  v_precision_enabled      boolean;
  v_a_type_bonus           boolean;
  v_d_type_bonus           boolean;
  v_a_damage               integer;
  v_d_damage               integer;
  v_a_damage_species_xp    integer;
  v_d_damage_species_xp    integer;
  v_effective_a_ability_nom text;
  v_d_ability_sequence     text[];
  v_d_ability_cycle_index  integer;
  v_d_ability_nom_round    text;
  v_a_state                autobattle_combatant_state;
  v_d_state                autobattle_combatant_state;
  v_a_ability_cfg          autobattle_combatant_ability;
  v_d_ability_cfg          autobattle_combatant_ability;
  v_round_result           autobattle_round_result;
  v_result                 jsonb;
  v_challenger_source_id   bigint;
BEGIN
  SELECT * INTO v_challenge FROM pvp_challenges WHERE id = p_challenge_id;
  IF v_challenge IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;
  IF v_challenge.defender_player_id = p_attacker_player_id THEN
    RETURN jsonb_build_object('status', 'own_challenge');
  END IF;

  SELECT * INTO v_pp FROM player_pokemon WHERE id = p_attacker_player_pokemon_id AND player_id = p_attacker_player_id;
  IF v_pp IS NULL THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;
  IF v_pp.in_daycare THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;
  IF NOT (p_ability_nom = ANY(v_pp.moves)) THEN
    RETURN jsonb_build_object('status', 'ineligible_ability');
  END IF;

  SELECT * INTO v_a_species FROM pokemon WHERE nom = v_pp.pokemon_nom;
  IF v_a_species IS NULL OR NOT EXISTS (SELECT 1 FROM attacks WHERE nom = p_ability_nom) THEN
    RETURN jsonb_build_object('status', 'ineligible_ability');
  END IF;
  IF EXISTS (SELECT 1 FROM autobattle_banned_attacks WHERE attack_nom = p_ability_nom) THEN
    RETURN jsonb_build_object('status', 'ineligible_ability');
  END IF;

  SELECT * INTO v_d_species FROM pokemon WHERE nom = v_challenge.pokemon_nom;
  IF v_d_species IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;

  SELECT * INTO v_row FROM pvp_battles
    WHERE attacker_player_id = p_attacker_player_id AND challenge_id = p_challenge_id FOR UPDATE;

  -- Rejeu idempotent : voir le même commentaire dans l'ancienne
  -- autobattle_resolve_manual_round (moteur partagé, même idiome).
  IF v_row.id IS NOT NULL AND v_row.last_idempotency_key = p_idempotency_key THEN
    RETURN v_row.last_result;
  END IF;

  IF v_row.id IS NOT NULL AND v_row.outcome IS NOT NULL THEN
    DELETE FROM pvp_battles WHERE id = v_row.id;
    v_row := NULL;
  END IF;

  IF v_row.id IS NULL THEN
    RETURN jsonb_build_object('status', 'not_started');
  END IF;

  -- Capacité RÉELLEMENT jouée par l'attaquant ce tour (mémorisée s'il est en
  -- cours de préparation, voir prepare_release).
  -- Une chaîne "Continue sur sa lancée" en cours (voir autobattle_ability_
  -- rules.keep_going_turns) verrouille la capacité comme une préparation.
  v_effective_a_ability_nom := CASE
    WHEN v_row.attacker_preparing THEN v_row.attacker_preparing_ability_nom
    WHEN COALESCE(v_row.attacker_keep_going_remaining, 0) > 0 AND v_row.attacker_keep_going_ability_nom IS NOT NULL THEN v_row.attacker_keep_going_ability_nom
    ELSE p_ability_nom END;
  SELECT * INTO v_ability FROM attacks WHERE nom = v_effective_a_ability_nom;

  -- Capacité défenseur ce tour : mémorisée si en cours de préparation, sinon
  -- pigée dans la boucle des jusqu'à 4 capacités posées (voir pvp_challenges)
  -- — une position par NOUVEAU tour défenseur (même mécanique que
  -- autobattle_levels.opponent_ability_nom_1..10/opponent_ability_cycle_index,
  -- juste bornée à 4 positions).
  IF v_row.defender_preparing THEN
    v_d_ability_nom_round := v_row.defender_preparing_ability_nom;
    v_d_ability_cycle_index := v_row.defender_ability_cycle_index;
  ELSIF COALESCE(v_row.defender_keep_going_remaining, 0) > 0 AND v_row.defender_keep_going_ability_nom IS NOT NULL THEN
    v_d_ability_nom_round := v_row.defender_keep_going_ability_nom;
    v_d_ability_cycle_index := v_row.defender_ability_cycle_index;
  ELSE
    v_d_ability_sequence := v_challenge.ability_noms;
    v_d_ability_cycle_index := v_row.defender_ability_cycle_index + 1;
    v_d_ability_nom_round := v_d_ability_sequence[1 + ((v_d_ability_cycle_index - 1) % array_length(v_d_ability_sequence, 1))];
  END IF;
  SELECT * INTO v_d_ability FROM attacks WHERE nom = v_d_ability_nom_round;

  v_a_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (v_a_species.super_efficace_1), (v_a_species.super_efficace_2),
      (v_a_species.super_efficace_3), (v_a_species.super_efficace_4)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(v_d_species.type))
  ) AND lower(trim(v_ability.type)) = lower(trim(v_a_species.type));
  v_a_damage_species_xp := COALESCE(v_a_species.degats_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'DMG');
  v_a_damage := v_a_damage_species_xp * (CASE WHEN v_a_type_bonus THEN 2 ELSE 1 END) + COALESCE(v_ability.degats_base, 0);

  v_d_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (v_d_species.super_efficace_1), (v_d_species.super_efficace_2),
      (v_d_species.super_efficace_3), (v_d_species.super_efficace_4)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(v_a_species.type))
  ) AND lower(trim(v_d_ability.type)) = lower(trim(v_d_species.type));
  -- Figé au dépôt du défi (voir pvp_challenges.damage_species_xp), pas
  -- recalculé depuis l'XP courante du pokémon réel du défenseur.
  v_d_damage_species_xp := v_challenge.damage_species_xp;
  v_d_damage := v_d_damage_species_xp * (CASE WHEN v_d_type_bonus THEN 2 ELSE 1 END) + COALESCE(v_d_ability.degats_base, 0);

  SELECT precision_enabled INTO v_precision_enabled FROM pvp_config WHERE id = 1;
  v_precision_enabled := COALESCE(v_precision_enabled, true);

  -- Empaquette l'état persisté (pvp_battles) dans les types partagés avec le
  -- moteur de résolution (voir autobattle_resolve_round_core, juste après
  -- autobattle_ability_burst plus haut dans ce fichier — le MÊME moteur que
  -- Combat Auto en mode Manuel, aucune duplication de la boucle elle-même).
  v_a_state.hp := v_row.attacker_hp;
  v_a_state.max_hp := v_row.attacker_max_hp;
  v_a_state.status := v_row.attacker_status;
  v_a_state.damage_mod_amount := v_row.attacker_damage_mod_amount;
  v_a_state.damage_mod_expires := v_row.attacker_damage_mod_expires;
  v_a_state.precision_mod_amount := v_row.attacker_precision_mod_amount;
  v_a_state.precision_mod_expires := v_row.attacker_precision_mod_expires;
  v_a_state.heal_dot_amount := v_row.attacker_heal_dot_amount;
  v_a_state.heal_dot_expires := v_row.attacker_heal_dot_expires;
  v_a_state.heal_disabled_expires := v_row.attacker_heal_disabled_expires;
  v_a_state.invulnerable := v_row.attacker_invulnerable;
  v_a_state.invuln_granted_round := v_row.attacker_invuln_granted_round;
  v_a_state.stat_mod_uses := v_row.attacker_stat_mod_uses;
  v_a_state.used_ability := v_row.attacker_used_ability;
  v_a_state.took_damage := v_row.attacker_took_damage;
  v_a_state.skip_pending := v_row.attacker_skip_pending;
  v_a_state.preparing := v_row.attacker_preparing;
  v_a_state.preparing_ability_nom := v_row.attacker_preparing_ability_nom;
  v_a_state.double_turn_pending := v_row.attacker_double_turn_pending;
  v_a_state.prevention_expires := v_row.attacker_prevention_expires;
  v_a_state.damage_mod_type_filter := v_row.attacker_damage_mod_type_filter;
  v_a_state.heal_dot_until_awake := v_row.attacker_heal_dot_until_awake;
  v_a_state.keep_going_ability_nom := v_row.attacker_keep_going_ability_nom;
  v_a_state.keep_going_remaining := v_row.attacker_keep_going_remaining;
  v_a_state.keep_going_count := v_row.attacker_keep_going_count;

  v_d_state.hp := v_row.defender_hp;
  v_d_state.max_hp := v_challenge.max_hp;
  v_d_state.status := v_row.defender_status;
  v_d_state.damage_mod_amount := v_row.defender_damage_mod_amount;
  v_d_state.damage_mod_expires := v_row.defender_damage_mod_expires;
  v_d_state.precision_mod_amount := v_row.defender_precision_mod_amount;
  v_d_state.precision_mod_expires := v_row.defender_precision_mod_expires;
  v_d_state.heal_dot_amount := v_row.defender_heal_dot_amount;
  v_d_state.heal_dot_expires := v_row.defender_heal_dot_expires;
  v_d_state.heal_disabled_expires := v_row.defender_heal_disabled_expires;
  v_d_state.invulnerable := v_row.defender_invulnerable;
  v_d_state.invuln_granted_round := v_row.defender_invuln_granted_round;
  v_d_state.stat_mod_uses := v_row.defender_stat_mod_uses;
  v_d_state.used_ability := v_row.defender_used_ability;
  v_d_state.took_damage := v_row.defender_took_damage;
  v_d_state.skip_pending := v_row.defender_skip_pending;
  v_d_state.preparing := v_row.defender_preparing;
  v_d_state.preparing_ability_nom := v_row.defender_preparing_ability_nom;
  v_d_state.double_turn_pending := v_row.defender_double_turn_pending;
  v_d_state.prevention_expires := v_row.defender_prevention_expires;
  v_d_state.damage_mod_type_filter := v_row.defender_damage_mod_type_filter;
  v_d_state.heal_dot_until_awake := v_row.defender_heal_dot_until_awake;
  v_d_state.keep_going_ability_nom := v_row.defender_keep_going_ability_nom;
  v_d_state.keep_going_remaining := v_row.defender_keep_going_remaining;
  v_d_state.keep_going_count := v_row.defender_keep_going_count;

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_a_ability_cfg.turn_effect, v_a_ability_cfg.repeat_max, v_a_ability_cfg.heal_type, v_a_ability_cfg.heal_amount, v_a_ability_cfg.heal_percent, v_a_ability_cfg.status_reversed,
         v_a_ability_cfg.recoil_type, v_a_ability_cfg.recoil_min, v_a_ability_cfg.recoil_max, v_a_ability_cfg.recoil_percent, v_a_ability_cfg.invuln_grant,
         v_a_ability_cfg.bonus_type, v_a_ability_cfg.bonus_multiplier, v_a_ability_cfg.bonus_flat, v_a_ability_cfg.bonus_min, v_a_ability_cfg.bonus_max,
         v_a_ability_cfg.bonus_condition, v_a_ability_cfg.bonus_dice_value, v_a_ability_cfg.bonus_status_filter,
         v_a_ability_cfg.stat_mod_target, v_a_ability_cfg.stat_mod_stat, v_a_ability_cfg.stat_mod_value_type, v_a_ability_cfg.stat_mod_flat, v_a_ability_cfg.stat_mod_min, v_a_ability_cfg.stat_mod_max, v_a_ability_cfg.stat_mod_percent,
         v_a_ability_cfg.stat_mod_duration_type, v_a_ability_cfg.stat_mod_duration_turns, v_a_ability_cfg.stat_mod_max_uses,
         v_a_ability_cfg.heal_dot_config_amount, v_a_ability_cfg.heal_dot_config_turns, v_a_ability_cfg.heal_dot_config_type, v_a_ability_cfg.heal_dot_config_percent, v_a_ability_cfg.cancel_heal_duration, v_a_ability_cfg.percent_hp_damage_percent,
         v_a_ability_cfg.stat_mod_type_filter, v_a_ability_cfg.prevention_duration,
         v_a_ability_cfg.keep_going_turns, v_a_ability_cfg.keep_going_bonus_type, v_a_ability_cfg.keep_going_bonus_flat, v_a_ability_cfg.keep_going_bonus_percent,
         v_a_ability_cfg.heal_dot_until_awake, v_a_ability_cfg.ignore_status_block
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_a_ability_nom;
  v_a_ability_cfg.status_reversed := COALESCE(v_a_ability_cfg.status_reversed, false);
  v_a_ability_cfg.invuln_grant := COALESCE(v_a_ability_cfg.invuln_grant, false);
  v_a_ability_cfg.ability_nom := v_effective_a_ability_nom;
  v_a_ability_cfg.base_damage := v_a_damage;
  v_a_ability_cfg.damage_species_xp := v_a_damage_species_xp;
  v_a_ability_cfg.type_bonus := v_a_type_bonus;
  v_a_ability_cfg.precision := v_ability.precision;
  v_a_ability_cfg.degats_de := v_ability.degats_de;
  v_a_ability_cfg.deals_damage := v_ability.deals_damage;
  v_a_ability_cfg.status_effect := v_ability.status_effect;
  v_a_ability_cfg.status_chance := v_ability.status_chance;
  v_a_ability_cfg.ability_type := v_ability.type;

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_d_ability_cfg.turn_effect, v_d_ability_cfg.repeat_max, v_d_ability_cfg.heal_type, v_d_ability_cfg.heal_amount, v_d_ability_cfg.heal_percent, v_d_ability_cfg.status_reversed,
         v_d_ability_cfg.recoil_type, v_d_ability_cfg.recoil_min, v_d_ability_cfg.recoil_max, v_d_ability_cfg.recoil_percent, v_d_ability_cfg.invuln_grant,
         v_d_ability_cfg.bonus_type, v_d_ability_cfg.bonus_multiplier, v_d_ability_cfg.bonus_flat, v_d_ability_cfg.bonus_min, v_d_ability_cfg.bonus_max,
         v_d_ability_cfg.bonus_condition, v_d_ability_cfg.bonus_dice_value, v_d_ability_cfg.bonus_status_filter,
         v_d_ability_cfg.stat_mod_target, v_d_ability_cfg.stat_mod_stat, v_d_ability_cfg.stat_mod_value_type, v_d_ability_cfg.stat_mod_flat, v_d_ability_cfg.stat_mod_min, v_d_ability_cfg.stat_mod_max, v_d_ability_cfg.stat_mod_percent,
         v_d_ability_cfg.stat_mod_duration_type, v_d_ability_cfg.stat_mod_duration_turns, v_d_ability_cfg.stat_mod_max_uses,
         v_d_ability_cfg.heal_dot_config_amount, v_d_ability_cfg.heal_dot_config_turns, v_d_ability_cfg.heal_dot_config_type, v_d_ability_cfg.heal_dot_config_percent, v_d_ability_cfg.cancel_heal_duration, v_d_ability_cfg.percent_hp_damage_percent,
         v_d_ability_cfg.stat_mod_type_filter, v_d_ability_cfg.prevention_duration,
         v_d_ability_cfg.keep_going_turns, v_d_ability_cfg.keep_going_bonus_type, v_d_ability_cfg.keep_going_bonus_flat, v_d_ability_cfg.keep_going_bonus_percent,
         v_d_ability_cfg.heal_dot_until_awake, v_d_ability_cfg.ignore_status_block
    FROM autobattle_ability_rules WHERE attack_nom = v_d_ability_nom_round;
  v_d_ability_cfg.status_reversed := COALESCE(v_d_ability_cfg.status_reversed, false);
  v_d_ability_cfg.invuln_grant := COALESCE(v_d_ability_cfg.invuln_grant, false);
  v_d_ability_cfg.ability_nom := v_d_ability_nom_round;
  v_d_ability_cfg.base_damage := v_d_damage;
  v_d_ability_cfg.damage_species_xp := v_d_damage_species_xp;
  v_d_ability_cfg.type_bonus := v_d_type_bonus;
  v_d_ability_cfg.precision := v_d_ability.precision;
  v_d_ability_cfg.degats_de := v_d_ability.degats_de;
  v_d_ability_cfg.deals_damage := v_d_ability.deals_damage;
  v_d_ability_cfg.status_effect := v_d_ability.status_effect;
  v_d_ability_cfg.status_chance := v_d_ability.status_chance;
  v_d_ability_cfg.ability_type := v_d_ability.type;

  v_round_result := autobattle_resolve_round_core(
    v_row.turn_no, v_row.round_no,
    CASE WHEN v_row.first_attacker = 'attacker' THEN 'player' ELSE 'opponent' END,
    v_a_state, v_d_state, v_a_ability_cfg, v_d_ability_cfg, v_precision_enabled
  );

  -- Voir autobattle_resolve_manual_round : un round peut se terminer avant que
  -- le défenseur n'ait joué (action supplémentaire côté attaquant), sa
  -- séquence de capacités ne doit alors pas avancer.
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_round_result.turns) t WHERE t ->> 'attacker' = 'opponent') THEN
    v_d_ability_cycle_index := v_row.defender_ability_cycle_index;
  END IF;

  v_result := jsonb_build_object(
    'status', 'ok',
    'turn_no', v_round_result.turn_no,
    -- Celui du PROCHAIN round : un camp ayant gagné une action supplémentaire
    -- reprend la main dès son début (voir next_first_attacker).
    'first_attacker', COALESCE(v_round_result.next_first_attacker, CASE WHEN v_row.first_attacker = 'attacker' THEN 'player' ELSE 'opponent' END),
    'player_hp', GREATEST(0, (v_round_result.player_state).hp),
    'player_max_hp', v_row.attacker_max_hp,
    'opponent_hp', GREATEST(0, (v_round_result.opponent_state).hp),
    'opponent_max_hp', v_challenge.max_hp,
    'player_damage_per_hit', v_a_damage,
    'opponent_damage_per_hit', v_d_damage,
    'player_type_bonus', v_a_type_bonus,
    'opponent_type_bonus', v_d_type_bonus,
    'turns', v_round_result.turns,
    'outcome', v_round_result.outcome,
    'opponent_pokemon_nom', v_challenge.pokemon_nom,
    'opponent_ability_nom', v_d_ability_nom_round,
    'player_ability_nom', v_effective_a_ability_nom,
    -- Capacité imposée au joueur au PROCHAIN tour (préparation, tour passé
    -- imposé, ou chaîne "Continue sur sa lancée") — voir le même champ dans
    -- autobattle_resolve_manual_round, le client verrouille sa grille dessus.
    'player_forced_ability_nom', CASE
      WHEN v_round_result.outcome IS NOT NULL THEN NULL
      WHEN (v_round_result.player_state).preparing THEN (v_round_result.player_state).preparing_ability_nom
      WHEN (v_round_result.player_state).skip_pending THEN v_effective_a_ability_nom
      WHEN COALESCE((v_round_result.player_state).keep_going_remaining, 0) > 0 THEN (v_round_result.player_state).keep_going_ability_nom
      ELSE NULL END
  );

  IF v_round_result.outcome IS NULL THEN
    UPDATE pvp_battles SET
      turn_no = v_round_result.turn_no, round_no = v_round_result.round_no,
      attacker_hp = (v_round_result.player_state).hp, defender_hp = (v_round_result.opponent_state).hp,
      attacker_status = (v_round_result.player_state).status, defender_status = (v_round_result.opponent_state).status,
      attacker_damage_mod_amount = (v_round_result.player_state).damage_mod_amount, attacker_damage_mod_expires = (v_round_result.player_state).damage_mod_expires,
      attacker_precision_mod_amount = (v_round_result.player_state).precision_mod_amount, attacker_precision_mod_expires = (v_round_result.player_state).precision_mod_expires,
      defender_damage_mod_amount = (v_round_result.opponent_state).damage_mod_amount, defender_damage_mod_expires = (v_round_result.opponent_state).damage_mod_expires,
      defender_precision_mod_amount = (v_round_result.opponent_state).precision_mod_amount, defender_precision_mod_expires = (v_round_result.opponent_state).precision_mod_expires,
      attacker_heal_dot_amount = (v_round_result.player_state).heal_dot_amount, attacker_heal_dot_expires = (v_round_result.player_state).heal_dot_expires,
      defender_heal_dot_amount = (v_round_result.opponent_state).heal_dot_amount, defender_heal_dot_expires = (v_round_result.opponent_state).heal_dot_expires,
      attacker_heal_disabled_expires = (v_round_result.player_state).heal_disabled_expires, defender_heal_disabled_expires = (v_round_result.opponent_state).heal_disabled_expires,
      attacker_invulnerable = (v_round_result.player_state).invulnerable, attacker_invuln_granted_round = (v_round_result.player_state).invuln_granted_round,
      defender_invulnerable = (v_round_result.opponent_state).invulnerable, defender_invuln_granted_round = (v_round_result.opponent_state).invuln_granted_round,
      attacker_used_ability = (v_round_result.player_state).used_ability, attacker_took_damage = (v_round_result.player_state).took_damage,
      defender_used_ability = (v_round_result.opponent_state).used_ability, defender_took_damage = (v_round_result.opponent_state).took_damage,
      attacker_skip_pending = (v_round_result.player_state).skip_pending, defender_skip_pending = (v_round_result.opponent_state).skip_pending,
      attacker_preparing = (v_round_result.player_state).preparing, defender_preparing = (v_round_result.opponent_state).preparing,
      attacker_preparing_ability_nom = (v_round_result.player_state).preparing_ability_nom, defender_preparing_ability_nom = (v_round_result.opponent_state).preparing_ability_nom,
      attacker_double_turn_pending = (v_round_result.player_state).double_turn_pending, defender_double_turn_pending = (v_round_result.opponent_state).double_turn_pending,
      attacker_prevention_expires = (v_round_result.player_state).prevention_expires, defender_prevention_expires = (v_round_result.opponent_state).prevention_expires,
      attacker_damage_mod_type_filter = (v_round_result.player_state).damage_mod_type_filter, defender_damage_mod_type_filter = (v_round_result.opponent_state).damage_mod_type_filter,
      attacker_heal_dot_until_awake = COALESCE((v_round_result.player_state).heal_dot_until_awake, false), defender_heal_dot_until_awake = COALESCE((v_round_result.opponent_state).heal_dot_until_awake, false),
      attacker_keep_going_ability_nom = (v_round_result.player_state).keep_going_ability_nom, defender_keep_going_ability_nom = (v_round_result.opponent_state).keep_going_ability_nom,
      attacker_keep_going_remaining = COALESCE((v_round_result.player_state).keep_going_remaining, 0), defender_keep_going_remaining = COALESCE((v_round_result.opponent_state).keep_going_remaining, 0),
      attacker_keep_going_count = COALESCE((v_round_result.player_state).keep_going_count, 0), defender_keep_going_count = COALESCE((v_round_result.opponent_state).keep_going_count, 0),
      -- Le camp qui a gagné une action supplémentaire reprend la main au début
      -- du round suivant (voir autobattle_round_result.next_first_attacker).
      first_attacker = CASE WHEN COALESCE(v_round_result.next_first_attacker, 'player') = 'player' THEN 'attacker' ELSE 'defender' END,
      defender_ability_cycle_index = v_d_ability_cycle_index,
      attacker_stat_mod_uses = (v_round_result.player_state).stat_mod_uses, defender_stat_mod_uses = (v_round_result.opponent_state).stat_mod_uses,
      turn_log = turn_log || v_round_result.turns, last_idempotency_key = p_idempotency_key, last_result = v_result
    WHERE id = v_row.id;
  ELSE
    UPDATE pvp_battles SET
      turn_no = v_round_result.turn_no, round_no = v_round_result.round_no,
      attacker_hp = (v_round_result.player_state).hp, defender_hp = (v_round_result.opponent_state).hp,
      defender_ability_cycle_index = v_d_ability_cycle_index,
      outcome = v_round_result.outcome, turn_log = turn_log || v_round_result.turns,
      last_idempotency_key = p_idempotency_key, last_result = v_result
    WHERE id = v_row.id;

    INSERT INTO pvp_challenge_attempts (
      challenge_id, defender_player_id, attacker_player_id, attacker_player_pokemon_id, attacker_pokemon_nom,
      outcome, duration_turns, defender_hp_remaining, idempotency_key
    ) VALUES (
      p_challenge_id, v_challenge.defender_player_id, p_attacker_player_id, p_attacker_player_pokemon_id, v_pp.pokemon_nom,
      v_round_result.outcome,
      -- Jeu au tour par tour : compte les TOURS plutôt que le temps réel
      -- écoulé (voir commentaire de pvp_challenge_attempts). round_no avance
      -- de 1 à chaque nouveau segment de tour (un par camp, jamais au milieu
      -- d'une rafale, voir autobattle_resolve_round_core) — un round complet
      -- (attaquant + défenseur) en avance donc toujours 2, sauf si le combat
      -- se termine PENDANT le tout premier segment d'un round (K.O. dès la
      -- capacité de l'attaquant, avant même que le défenseur n'agisse), d'où
      -- l'arrondi supérieur plutôt qu'une simple division entière.
      CASE WHEN v_round_result.outcome = 'win' THEN GREATEST(1, CEIL(v_round_result.round_no / 2.0)::integer) ELSE NULL END,
      CASE WHEN v_round_result.outcome = 'lose' THEN GREATEST(0, (v_round_result.opponent_state).hp) ELSE NULL END,
      p_idempotency_key
    );

    -- Le Champion vient de tomber : le remplace par le défi régulier déjà
    -- posé par l'attaquant (précondition vérifiée par pvp_start_battle, voir
    -- son commentaire) — voir pvp_promote_to_champion pour le détail (nouvelle
    -- ligne pour le nouveau Champion, tableau des scores vierge, "Champion
    -- depuis" = maintenant ; l'ANCIEN Champion redevient un Challenger normal,
    -- il n'est jamais retiré — voir requirement dédié). Si ce défi a
    -- entretemps disparu (retiré pendant le combat, cas limite), le Champion
    -- est simplement dépossédé sans successeur automatique (même bascule
    -- is_champion = false, redevient Challenger) — un admin peut toujours en
    -- nommer un nouveau depuis AdminPvpPanel.
    IF v_round_result.outcome = 'win' AND v_challenge.is_champion THEN
      SELECT id INTO v_challenger_source_id FROM pvp_challenges
        WHERE defender_player_id = p_attacker_player_id AND active = true AND is_champion = false
        ORDER BY created_at DESC LIMIT 1;
      IF v_challenger_source_id IS NOT NULL THEN
        PERFORM pvp_promote_to_champion(v_challenger_source_id);
      ELSE
        UPDATE pvp_challenges SET is_champion = false WHERE id = p_challenge_id;
      END IF;
    END IF;
  END IF;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION pvp_trial_resolve_round(
  p_player_id bigint,
  p_idempotency_key uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_row                    pvp_trial_battles%ROWTYPE;
  v_pp                     record;
  v_a_species              record;
  v_ability                record;
  v_d_species              record;
  v_d_ability              record;
  v_precision_enabled      boolean;
  v_a_type_bonus           boolean;
  v_d_type_bonus           boolean;
  v_a_damage               integer;
  v_d_damage               integer;
  v_a_damage_species_xp    integer;
  v_a_ability_cycle_index  integer;
  v_a_ability_nom_round    text;
  v_a_state                autobattle_combatant_state;
  v_d_state                autobattle_combatant_state;
  v_a_ability_cfg          autobattle_combatant_ability;
  v_d_ability_cfg          autobattle_combatant_ability;
  v_round_result           autobattle_round_result;
  v_result                 jsonb;
BEGIN
  SELECT * INTO v_row FROM pvp_trial_battles WHERE player_id = p_player_id FOR UPDATE;
  IF v_row.id IS NULL THEN
    RETURN jsonb_build_object('status', 'not_started');
  END IF;

  IF v_row.last_idempotency_key = p_idempotency_key OR v_row.outcome IS NOT NULL THEN
    RETURN v_row.last_result;
  END IF;

  SELECT * INTO v_pp FROM player_pokemon WHERE id = v_row.player_pokemon_id;
  IF v_pp IS NULL THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;
  SELECT * INTO v_a_species FROM pokemon WHERE nom = v_pp.pokemon_nom;
  SELECT * INTO v_d_species FROM pokemon WHERE nom = v_row.dummy_pokemon_nom;
  IF v_a_species IS NULL OR v_d_species IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;

  -- Capacité attaquant ce round : boucle automatique (comme le défenseur en
  -- PvP normal, voir pvp_resolve_round) — jamais choisie interactivement ici.
  IF v_row.attacker_preparing THEN
    v_a_ability_nom_round := v_row.attacker_preparing_ability_nom;
    v_a_ability_cycle_index := v_row.attacker_ability_cycle_index;
  ELSIF COALESCE(v_row.attacker_keep_going_remaining, 0) > 0 AND v_row.attacker_keep_going_ability_nom IS NOT NULL THEN
    v_a_ability_nom_round := v_row.attacker_keep_going_ability_nom;
    v_a_ability_cycle_index := v_row.attacker_ability_cycle_index;
  ELSE
    v_a_ability_cycle_index := v_row.attacker_ability_cycle_index + 1;
    v_a_ability_nom_round := v_row.attacker_ability_noms[1 + ((v_a_ability_cycle_index - 1) % array_length(v_row.attacker_ability_noms, 1))];
  END IF;
  SELECT * INTO v_ability FROM attacks WHERE nom = v_a_ability_nom_round;
  IF v_ability IS NULL THEN
    RETURN jsonb_build_object('status', 'ineligible_ability');
  END IF;

  -- Capacité du pantin : toujours la même (dummy_ability_nom), aucune boucle
  -- nécessaire — même en cas de 'prepare_release'/'skip', la mémorisation
  -- (defender_preparing_ability_nom) retombe de toute façon sur cette seule
  -- capacité.
  SELECT * INTO v_d_ability FROM attacks WHERE nom = v_row.dummy_ability_nom;
  IF v_d_ability IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;

  v_a_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (v_a_species.super_efficace_1), (v_a_species.super_efficace_2),
      (v_a_species.super_efficace_3), (v_a_species.super_efficace_4)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(v_d_species.type))
  ) AND lower(trim(v_ability.type)) = lower(trim(v_a_species.type));
  v_a_damage_species_xp := COALESCE(v_a_species.degats_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'DMG');
  v_a_damage := v_a_damage_species_xp * (CASE WHEN v_a_type_bonus THEN 2 ELSE 1 END) + COALESCE(v_ability.degats_base, 0);

  -- Le pantin n'a pas de "dégâts d'espèce+XP" (n'existe dans aucun roster,
  -- pas de progression) : ses dégâts viennent UNIQUEMENT de la capacité
  -- choisie par l'admin (censée être "anodine") — voir pvp_config.trial_ability_nom.
  v_d_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (v_d_species.super_efficace_1), (v_d_species.super_efficace_2),
      (v_d_species.super_efficace_3), (v_d_species.super_efficace_4)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(v_a_species.type))
  ) AND lower(trim(v_d_ability.type)) = lower(trim(v_d_species.type));
  v_d_damage := (CASE WHEN v_d_type_bonus THEN 2 ELSE 1 END) * 0 + COALESCE(v_d_ability.degats_base, 0);

  SELECT precision_enabled INTO v_precision_enabled FROM pvp_config WHERE id = 1;
  v_precision_enabled := COALESCE(v_precision_enabled, true);

  v_a_state.hp := v_row.attacker_hp;
  v_a_state.max_hp := v_row.attacker_max_hp;
  v_a_state.status := v_row.attacker_status;
  v_a_state.damage_mod_amount := v_row.attacker_damage_mod_amount;
  v_a_state.damage_mod_expires := v_row.attacker_damage_mod_expires;
  v_a_state.precision_mod_amount := v_row.attacker_precision_mod_amount;
  v_a_state.precision_mod_expires := v_row.attacker_precision_mod_expires;
  v_a_state.heal_dot_amount := v_row.attacker_heal_dot_amount;
  v_a_state.heal_dot_expires := v_row.attacker_heal_dot_expires;
  v_a_state.heal_disabled_expires := v_row.attacker_heal_disabled_expires;
  v_a_state.invulnerable := v_row.attacker_invulnerable;
  v_a_state.invuln_granted_round := v_row.attacker_invuln_granted_round;
  v_a_state.stat_mod_uses := v_row.attacker_stat_mod_uses;
  v_a_state.used_ability := v_row.attacker_used_ability;
  v_a_state.took_damage := v_row.attacker_took_damage;
  v_a_state.skip_pending := v_row.attacker_skip_pending;
  v_a_state.preparing := v_row.attacker_preparing;
  v_a_state.preparing_ability_nom := v_row.attacker_preparing_ability_nom;
  v_a_state.double_turn_pending := v_row.attacker_double_turn_pending;
  v_a_state.prevention_expires := v_row.attacker_prevention_expires;
  v_a_state.damage_mod_type_filter := v_row.attacker_damage_mod_type_filter;
  v_a_state.heal_dot_until_awake := v_row.attacker_heal_dot_until_awake;
  v_a_state.keep_going_ability_nom := v_row.attacker_keep_going_ability_nom;
  v_a_state.keep_going_remaining := v_row.attacker_keep_going_remaining;
  v_a_state.keep_going_count := v_row.attacker_keep_going_count;

  v_d_state.hp := v_row.defender_hp;
  v_d_state.max_hp := v_row.dummy_max_hp;
  v_d_state.status := v_row.defender_status;
  v_d_state.damage_mod_amount := v_row.defender_damage_mod_amount;
  v_d_state.damage_mod_expires := v_row.defender_damage_mod_expires;
  v_d_state.precision_mod_amount := v_row.defender_precision_mod_amount;
  v_d_state.precision_mod_expires := v_row.defender_precision_mod_expires;
  v_d_state.heal_dot_amount := v_row.defender_heal_dot_amount;
  v_d_state.heal_dot_expires := v_row.defender_heal_dot_expires;
  v_d_state.heal_disabled_expires := v_row.defender_heal_disabled_expires;
  v_d_state.invulnerable := v_row.defender_invulnerable;
  v_d_state.invuln_granted_round := v_row.defender_invuln_granted_round;
  v_d_state.stat_mod_uses := v_row.defender_stat_mod_uses;
  v_d_state.used_ability := v_row.defender_used_ability;
  v_d_state.took_damage := v_row.defender_took_damage;
  v_d_state.skip_pending := v_row.defender_skip_pending;
  v_d_state.preparing := v_row.defender_preparing;
  v_d_state.preparing_ability_nom := v_row.defender_preparing_ability_nom;
  v_d_state.double_turn_pending := v_row.defender_double_turn_pending;
  v_d_state.prevention_expires := v_row.defender_prevention_expires;
  v_d_state.damage_mod_type_filter := v_row.defender_damage_mod_type_filter;
  v_d_state.heal_dot_until_awake := v_row.defender_heal_dot_until_awake;
  v_d_state.keep_going_ability_nom := v_row.defender_keep_going_ability_nom;
  v_d_state.keep_going_remaining := v_row.defender_keep_going_remaining;
  v_d_state.keep_going_count := v_row.defender_keep_going_count;

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_a_ability_cfg.turn_effect, v_a_ability_cfg.repeat_max, v_a_ability_cfg.heal_type, v_a_ability_cfg.heal_amount, v_a_ability_cfg.heal_percent, v_a_ability_cfg.status_reversed,
         v_a_ability_cfg.recoil_type, v_a_ability_cfg.recoil_min, v_a_ability_cfg.recoil_max, v_a_ability_cfg.recoil_percent, v_a_ability_cfg.invuln_grant,
         v_a_ability_cfg.bonus_type, v_a_ability_cfg.bonus_multiplier, v_a_ability_cfg.bonus_flat, v_a_ability_cfg.bonus_min, v_a_ability_cfg.bonus_max,
         v_a_ability_cfg.bonus_condition, v_a_ability_cfg.bonus_dice_value, v_a_ability_cfg.bonus_status_filter,
         v_a_ability_cfg.stat_mod_target, v_a_ability_cfg.stat_mod_stat, v_a_ability_cfg.stat_mod_value_type, v_a_ability_cfg.stat_mod_flat, v_a_ability_cfg.stat_mod_min, v_a_ability_cfg.stat_mod_max, v_a_ability_cfg.stat_mod_percent,
         v_a_ability_cfg.stat_mod_duration_type, v_a_ability_cfg.stat_mod_duration_turns, v_a_ability_cfg.stat_mod_max_uses,
         v_a_ability_cfg.heal_dot_config_amount, v_a_ability_cfg.heal_dot_config_turns, v_a_ability_cfg.heal_dot_config_type, v_a_ability_cfg.heal_dot_config_percent, v_a_ability_cfg.cancel_heal_duration, v_a_ability_cfg.percent_hp_damage_percent,
         v_a_ability_cfg.stat_mod_type_filter, v_a_ability_cfg.prevention_duration,
         v_a_ability_cfg.keep_going_turns, v_a_ability_cfg.keep_going_bonus_type, v_a_ability_cfg.keep_going_bonus_flat, v_a_ability_cfg.keep_going_bonus_percent,
         v_a_ability_cfg.heal_dot_until_awake, v_a_ability_cfg.ignore_status_block
    FROM autobattle_ability_rules WHERE attack_nom = v_a_ability_nom_round;
  v_a_ability_cfg.status_reversed := COALESCE(v_a_ability_cfg.status_reversed, false);
  v_a_ability_cfg.invuln_grant := COALESCE(v_a_ability_cfg.invuln_grant, false);
  v_a_ability_cfg.ability_nom := v_a_ability_nom_round;
  v_a_ability_cfg.base_damage := v_a_damage;
  v_a_ability_cfg.damage_species_xp := v_a_damage_species_xp;
  v_a_ability_cfg.type_bonus := v_a_type_bonus;
  v_a_ability_cfg.precision := v_ability.precision;
  v_a_ability_cfg.degats_de := v_ability.degats_de;
  v_a_ability_cfg.deals_damage := v_ability.deals_damage;
  v_a_ability_cfg.status_effect := v_ability.status_effect;
  v_a_ability_cfg.status_chance := v_ability.status_chance;
  v_a_ability_cfg.ability_type := v_ability.type;

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_d_ability_cfg.turn_effect, v_d_ability_cfg.repeat_max, v_d_ability_cfg.heal_type, v_d_ability_cfg.heal_amount, v_d_ability_cfg.heal_percent, v_d_ability_cfg.status_reversed,
         v_d_ability_cfg.recoil_type, v_d_ability_cfg.recoil_min, v_d_ability_cfg.recoil_max, v_d_ability_cfg.recoil_percent, v_d_ability_cfg.invuln_grant,
         v_d_ability_cfg.bonus_type, v_d_ability_cfg.bonus_multiplier, v_d_ability_cfg.bonus_flat, v_d_ability_cfg.bonus_min, v_d_ability_cfg.bonus_max,
         v_d_ability_cfg.bonus_condition, v_d_ability_cfg.bonus_dice_value, v_d_ability_cfg.bonus_status_filter,
         v_d_ability_cfg.stat_mod_target, v_d_ability_cfg.stat_mod_stat, v_d_ability_cfg.stat_mod_value_type, v_d_ability_cfg.stat_mod_flat, v_d_ability_cfg.stat_mod_min, v_d_ability_cfg.stat_mod_max, v_d_ability_cfg.stat_mod_percent,
         v_d_ability_cfg.stat_mod_duration_type, v_d_ability_cfg.stat_mod_duration_turns, v_d_ability_cfg.stat_mod_max_uses,
         v_d_ability_cfg.heal_dot_config_amount, v_d_ability_cfg.heal_dot_config_turns, v_d_ability_cfg.heal_dot_config_type, v_d_ability_cfg.heal_dot_config_percent, v_d_ability_cfg.cancel_heal_duration, v_d_ability_cfg.percent_hp_damage_percent,
         v_d_ability_cfg.stat_mod_type_filter, v_d_ability_cfg.prevention_duration,
         v_d_ability_cfg.keep_going_turns, v_d_ability_cfg.keep_going_bonus_type, v_d_ability_cfg.keep_going_bonus_flat, v_d_ability_cfg.keep_going_bonus_percent,
         v_d_ability_cfg.heal_dot_until_awake, v_d_ability_cfg.ignore_status_block
    FROM autobattle_ability_rules WHERE attack_nom = v_row.dummy_ability_nom;
  v_d_ability_cfg.status_reversed := COALESCE(v_d_ability_cfg.status_reversed, false);
  v_d_ability_cfg.invuln_grant := COALESCE(v_d_ability_cfg.invuln_grant, false);
  v_d_ability_cfg.ability_nom := v_row.dummy_ability_nom;
  v_d_ability_cfg.base_damage := v_d_damage;
  v_d_ability_cfg.damage_species_xp := 0;
  v_d_ability_cfg.type_bonus := v_d_type_bonus;
  v_d_ability_cfg.precision := v_d_ability.precision;
  v_d_ability_cfg.degats_de := v_d_ability.degats_de;
  v_d_ability_cfg.deals_damage := v_d_ability.deals_damage;
  v_d_ability_cfg.status_effect := v_d_ability.status_effect;
  v_d_ability_cfg.status_chance := v_d_ability.status_chance;
  v_d_ability_cfg.ability_type := v_d_ability.type;

  v_round_result := autobattle_resolve_round_core(
    v_row.turn_no, v_row.round_no,
    CASE WHEN v_row.first_attacker = 'attacker' THEN 'player' ELSE 'opponent' END,
    v_a_state, v_d_state, v_a_ability_cfg, v_d_ability_cfg, v_precision_enabled
  );

  v_result := jsonb_build_object(
    'status', 'ok',
    'turn_no', v_round_result.turn_no,
    -- Celui du PROCHAIN round : un camp ayant gagné une action supplémentaire
    -- reprend la main dès son début (voir next_first_attacker).
    'first_attacker', COALESCE(v_round_result.next_first_attacker, CASE WHEN v_row.first_attacker = 'attacker' THEN 'player' ELSE 'opponent' END),
    'player_hp', GREATEST(0, (v_round_result.player_state).hp),
    'player_max_hp', v_row.attacker_max_hp,
    'opponent_hp', GREATEST(0, (v_round_result.opponent_state).hp),
    'opponent_max_hp', v_row.dummy_max_hp,
    'player_damage_per_hit', v_a_damage,
    'opponent_damage_per_hit', v_d_damage,
    'player_type_bonus', v_a_type_bonus,
    'opponent_type_bonus', v_d_type_bonus,
    'turns', v_round_result.turns,
    'outcome', v_round_result.outcome,
    'opponent_pokemon_nom', v_row.dummy_pokemon_nom,
    'opponent_ability_nom', v_row.dummy_ability_nom,
    'player_ability_nom', v_a_ability_nom_round
  );

  IF v_round_result.outcome IS NULL THEN
    UPDATE pvp_trial_battles SET
      turn_no = v_round_result.turn_no, round_no = v_round_result.round_no,
      attacker_hp = (v_round_result.player_state).hp, defender_hp = (v_round_result.opponent_state).hp,
      attacker_status = (v_round_result.player_state).status, defender_status = (v_round_result.opponent_state).status,
      attacker_damage_mod_amount = (v_round_result.player_state).damage_mod_amount, attacker_damage_mod_expires = (v_round_result.player_state).damage_mod_expires,
      attacker_precision_mod_amount = (v_round_result.player_state).precision_mod_amount, attacker_precision_mod_expires = (v_round_result.player_state).precision_mod_expires,
      defender_damage_mod_amount = (v_round_result.opponent_state).damage_mod_amount, defender_damage_mod_expires = (v_round_result.opponent_state).damage_mod_expires,
      defender_precision_mod_amount = (v_round_result.opponent_state).precision_mod_amount, defender_precision_mod_expires = (v_round_result.opponent_state).precision_mod_expires,
      attacker_heal_dot_amount = (v_round_result.player_state).heal_dot_amount, attacker_heal_dot_expires = (v_round_result.player_state).heal_dot_expires,
      defender_heal_dot_amount = (v_round_result.opponent_state).heal_dot_amount, defender_heal_dot_expires = (v_round_result.opponent_state).heal_dot_expires,
      attacker_heal_disabled_expires = (v_round_result.player_state).heal_disabled_expires, defender_heal_disabled_expires = (v_round_result.opponent_state).heal_disabled_expires,
      attacker_invulnerable = (v_round_result.player_state).invulnerable, attacker_invuln_granted_round = (v_round_result.player_state).invuln_granted_round,
      defender_invulnerable = (v_round_result.opponent_state).invulnerable, defender_invuln_granted_round = (v_round_result.opponent_state).invuln_granted_round,
      attacker_used_ability = (v_round_result.player_state).used_ability, attacker_took_damage = (v_round_result.player_state).took_damage,
      defender_used_ability = (v_round_result.opponent_state).used_ability, defender_took_damage = (v_round_result.opponent_state).took_damage,
      attacker_skip_pending = (v_round_result.player_state).skip_pending, defender_skip_pending = (v_round_result.opponent_state).skip_pending,
      attacker_preparing = (v_round_result.player_state).preparing, defender_preparing = (v_round_result.opponent_state).preparing,
      attacker_preparing_ability_nom = (v_round_result.player_state).preparing_ability_nom, defender_preparing_ability_nom = (v_round_result.opponent_state).preparing_ability_nom,
      attacker_double_turn_pending = (v_round_result.player_state).double_turn_pending, defender_double_turn_pending = (v_round_result.opponent_state).double_turn_pending,
      attacker_prevention_expires = (v_round_result.player_state).prevention_expires, defender_prevention_expires = (v_round_result.opponent_state).prevention_expires,
      attacker_damage_mod_type_filter = (v_round_result.player_state).damage_mod_type_filter, defender_damage_mod_type_filter = (v_round_result.opponent_state).damage_mod_type_filter,
      attacker_heal_dot_until_awake = COALESCE((v_round_result.player_state).heal_dot_until_awake, false), defender_heal_dot_until_awake = COALESCE((v_round_result.opponent_state).heal_dot_until_awake, false),
      attacker_keep_going_ability_nom = (v_round_result.player_state).keep_going_ability_nom, defender_keep_going_ability_nom = (v_round_result.opponent_state).keep_going_ability_nom,
      attacker_keep_going_remaining = COALESCE((v_round_result.player_state).keep_going_remaining, 0), defender_keep_going_remaining = COALESCE((v_round_result.opponent_state).keep_going_remaining, 0),
      attacker_keep_going_count = COALESCE((v_round_result.player_state).keep_going_count, 0), defender_keep_going_count = COALESCE((v_round_result.opponent_state).keep_going_count, 0),
      -- Le camp qui a gagné une action supplémentaire reprend la main au début
      -- du round suivant (voir autobattle_round_result.next_first_attacker).
      first_attacker = CASE WHEN COALESCE(v_round_result.next_first_attacker, 'player') = 'player' THEN 'attacker' ELSE 'defender' END,
      attacker_ability_cycle_index = v_a_ability_cycle_index,
      attacker_stat_mod_uses = (v_round_result.player_state).stat_mod_uses, defender_stat_mod_uses = (v_round_result.opponent_state).stat_mod_uses,
      turn_log = turn_log || v_round_result.turns, last_idempotency_key = p_idempotency_key, last_result = v_result
    WHERE id = v_row.id;
  ELSE
    UPDATE pvp_trial_battles SET
      turn_no = v_round_result.turn_no, round_no = v_round_result.round_no,
      attacker_hp = (v_round_result.player_state).hp, defender_hp = (v_round_result.opponent_state).hp,
      attacker_ability_cycle_index = v_a_ability_cycle_index,
      outcome = v_round_result.outcome, turn_log = turn_log || v_round_result.turns,
      last_idempotency_key = p_idempotency_key, last_result = v_result
    WHERE id = v_row.id;
  END IF;

  RETURN v_result;
END;
$$;
