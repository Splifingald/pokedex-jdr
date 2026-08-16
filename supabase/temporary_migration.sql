-- ============================================================
-- MIGRATION TEMPORAIRE — à coller telle quelle dans le SQL Editor Supabase.
-- Sens explicite des modificateurs de stat des capacités : la CIBLE
-- (adversaire / soi) et le SENS (bonus / malus) deviennent deux réglages
-- indépendants, ce qui autorise notamment le malus qu'une capacité s'inflige
-- à elle-même. Les règles existantes sont converties à l'identique
-- (adversaire = malus, soi = bonus) : aucun combat ne change de comportement.
--
-- Rejouable telle quelle (tout est idempotent). Contenu :
--   1. autobattle_ability_rules.stat_mod_direction (colonne + contrainte + reprise)
--   2. autobattle_combatant_ability.stat_mod_direction (attribut du type)
--   3. autobattle_stat_mod_signed() — signe partagé par les 4 moteurs
--   4. les 5 fonctions de résolution qui lisent/appliquent ce réglage
-- ============================================================

-- 1. Nouveau réglage sur la règle de capacité ------------------------------
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_direction text;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_stat_mod_direction_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_stat_mod_direction_check
  CHECK (stat_mod_direction IS NULL OR stat_mod_direction IN ('buff', 'debuff'));
-- Reprise des règles existantes, écrites quand le sens découlait de la cible :
-- elles gardent exactement le même comportement, désormais explicite.
UPDATE autobattle_ability_rules
   SET stat_mod_direction = CASE WHEN stat_mod_target = 'opponent' THEN 'debuff' ELSE 'buff' END
 WHERE stat_mod_target IS NOT NULL AND stat_mod_direction IS NULL;

-- 2. Même réglage transporté jusqu'au moteur partagé ------------------------
-- ADD ATTRIBUTE plutôt que DROP TYPE ... CASCADE : les fonctions qui portent ce
-- type dans leur signature ne sont pas détruites au passage. L'attribut atterrit
-- en fin de type, exactement comme dans schema.sql.
DO $migration$
BEGIN
  ALTER TYPE autobattle_combatant_ability ADD ATTRIBUTE stat_mod_direction text CASCADE;
EXCEPTION
  WHEN duplicate_column THEN NULL; -- déjà appliquée
END
$migration$;

-- 3. Signe partagé ----------------------------------------------------------
CREATE OR REPLACE FUNCTION autobattle_stat_mod_signed(p_amount integer, p_target text, p_direction text)
RETURNS integer
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE
    WHEN COALESCE(p_direction, CASE WHEN p_target = 'opponent' THEN 'debuff' ELSE 'buff' END) = 'debuff'
      THEN -abs(COALESCE(p_amount, 0))
    ELSE abs(COALESCE(p_amount, 0))
  END
$$;

GRANT EXECUTE ON FUNCTION autobattle_dot_tick(text, integer, integer, integer, integer, integer, text, text, integer, integer, jsonb, jsonb, boolean) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_status_dot_tick(text, integer, integer, text, text, integer, jsonb, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_type_immune(text, text, text, text, integer, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_weight_condition(text, text, integer, numeric, numeric) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_stat_mod_signed(integer, text, text) TO anon, authenticated;

-- autobattle_resolve_round_core ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION autobattle_resolve_round_core(
  p_turn_no integer,
  p_round_no integer,
  p_first_attacker text, -- 'player' | 'opponent' — qui agit en premier CE round
  p_player autobattle_combatant_state,
  p_opponent autobattle_combatant_state,
  p_player_ability autobattle_combatant_ability,
  p_opponent_ability autobattle_combatant_ability,
  p_precision_enabled boolean,
  -- Talents d'espèce des deux camps (voir autobattle_talents_for) : le core ne
  -- connaît jamais l'espèce, c'est l'appelant qui les résout et les passe ici.
  p_player_talents jsonb DEFAULT '[]'::jsonb,
  p_opponent_talents jsonb DEFAULT '[]'::jsonb,
  -- Météo (voir autobattle_weathers) : id en cours au début du round, bascule
  -- globale du mode, et types d'ESPÈCE des deux camps — le core ne connaît pas
  -- l'espèce (même raison que pour les talents), or les effets de terrain
  -- ciblent justement des types de pokémon.
  p_weather_id bigint DEFAULT NULL,
  p_weather_enabled boolean DEFAULT true,
  p_player_pokemon_type text DEFAULT NULL,
  p_opponent_pokemon_type text DEFAULT NULL,
  -- Poids des deux ESPÈCES (pokemon.poids) — même raison que les types
  -- ci-dessus : le core ne connaît pas l'espèce, or la condition de dégâts
  -- additionnels 'weight_ratio' compare justement les deux poids. NULL des
  -- deux côtés (appelant qui ne les fournit pas) = condition jamais remplie.
  p_player_weight numeric DEFAULT NULL,
  p_opponent_weight numeric DEFAULT NULL
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
  -- Immunité de type (voir type_no_effect) : le type de la capacité jouée ce
  -- round ne peut RIEN faire au type d'espèce d'en face. Calculée ici plutôt
  -- que passée par l'appelant : le core connaît déjà les deux types d'espèce
  -- (paramètres météo) et le type de chaque capacité. Traitée comme un raté
  -- automatique (« aucun effet »), au même endroit que l'invulnérabilité, et
  -- uniquement pour les capacités qui visent réellement l'adversaire — une
  -- capacité auto-ciblée reste jouable (requirement).
  -- Recalculée à CHAQUE tour (voir la tête de boucle) et non une fois pour
  -- toutes : un perce-immunité (pierce_immunity_*) peut la lever en cours de
  -- combat, et son échéance se compare au round en cours.
  v_player_type_immune boolean;
  v_opponent_type_immune boolean;
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
  -- ou 'first_and_replay') : purement local au round, puisqu'elle met fin au
  -- round dès qu'elle est accordée — d'où l'absence de colonne persistée, et
  -- l'impossibilité d'en accorder deux dans le même appel.
  v_player_owed boolean := false;
  v_opponent_owed boolean := false;
  -- Totaux des modificateurs de stat ENCORE ACTIFS au moment du coup (somme
  -- des applications empilées, voir autobattle_mod_total) — recalculés à
  -- chaque coup plutôt que stockés, puisque chaque entrée a sa propre
  -- échéance. Le total de dégâts ne retient que les entrées dont le filtre de
  -- type correspond à la capacité jouée.
  v_damage_mod_applied integer;
  v_precision_mod_total integer;
  -- Ce coup a-t-il vu son bonus super efficace annulé par la Prévention de la
  -- cible (voir autobattle_ability_rules.prevention_duration_turns) ?
  v_prevention_blocked boolean;
  -- Bonus cumulatif de la chaîne "Continue sur sa lancée" pour ce coup.
  v_keep_going_bonus integer;
  -- Talents (voir autobattle_talents et ses helpers de phase) :
  -- v_talent_res     = retour du helper de phase en cours ({state, turns, ...}) ;
  -- v_talent_pending = tours de talent à insérer JUSTE APRÈS l'entrée d'attaque
  --                    en cours (le coup s'anime d'abord, le talent réagit) ;
  -- v_talent_heal    = dégâts convertis en soin par 'type_damage_to_heal' ;
  -- v_talent_inflict = statut que le camp qui agit inflige via 'inflict_status'.
  v_talent_res jsonb;
  v_talent_pending jsonb;
  v_talent_heal integer := 0;
  v_talent_inflict text;
  v_hp_shown integer := 0;
  v_tick_damage integer := 0;
  v_talent_dice_bonus integer := 0;
  v_talent_dice_turns jsonb := '[]'::jsonb;
  -- Météo en cours, résolue une fois pour tout le round (voir
  -- autobattle_weather_for) : NULL quand il n'y en a pas, ou quand la bascule
  -- globale du mode est à faux — auquel cas tous les helpers météo sont inertes.
  v_weather jsonb;
  v_weather_res jsonb;
  v_weather_side text;
  -- Retour d'un tick d'effet persistant offensif (voir autobattle_dot_tick) :
  -- dégâts par tour et/ou vol de vie subis par le camp qui ouvre son tour.
  v_dot_res jsonb;
  -- La capacité du camp qui agit exige un statut sur sa cible (voir
  -- autobattle_ability_rules.requires_target_status) et la cible ne l'a pas :
  -- échec automatique de ce coup.
  v_status_req_failed boolean;
BEGIN
  v_weather := autobattle_weather_for(p_weather_id, p_weather_enabled);
  -- Talents déjà déclenchés : un appelant qui ne gère pas encore la colonne
  -- passe NULL, jamais une erreur.
  v_player.talent_state := COALESCE(v_player.talent_state, autobattle_talent_state_init());
  v_opponent.talent_state := COALESCE(v_opponent.talent_state, autobattle_talent_state_init());
  -- Expiration pré-boucle des modificateurs (comparés au numéro de TOUR) —
  -- voir le même commentaire dans l'ancienne autobattle_resolve_manual_round :
  -- vérifiée une 1ère fois ici (avant tout nouveau round_no), puis re-vérifiée
  -- à l'identique en tête de boucle (round_no a pu changer entretemps).
  v_player.damage_mods := autobattle_mod_purge(v_player.damage_mods, v_round_no);
  v_player.precision_mods := autobattle_mod_purge(v_player.precision_mods, v_round_no);
  v_opponent.damage_mods := autobattle_mod_purge(v_opponent.damage_mods, v_round_no);
  v_opponent.precision_mods := autobattle_mod_purge(v_opponent.precision_mods, v_round_no);
  IF v_player.heal_dot_expires IS NOT NULL AND v_round_no > v_player.heal_dot_expires THEN
    v_player.heal_dot_amount := NULL; v_player.heal_dot_expires := NULL;
  END IF;
  IF v_opponent.heal_dot_expires IS NOT NULL AND v_round_no > v_opponent.heal_dot_expires THEN
    v_opponent.heal_dot_amount := NULL; v_opponent.heal_dot_expires := NULL;
  END IF;
  -- Effets persistants OFFENSIFS subis (dégâts/vol de vie par tour) et
  -- perce-immunité accordé : mêmes échéances par numéro de round que le soin
  -- passif juste au-dessus.
  IF v_player.damage_dot_expires IS NOT NULL AND v_round_no > v_player.damage_dot_expires THEN
    v_player.damage_dot_amount := NULL; v_player.damage_dot_expires := NULL;
  END IF;
  IF v_opponent.damage_dot_expires IS NOT NULL AND v_round_no > v_opponent.damage_dot_expires THEN
    v_opponent.damage_dot_amount := NULL; v_opponent.damage_dot_expires := NULL;
  END IF;
  IF v_player.leech_dot_expires IS NOT NULL AND v_round_no > v_player.leech_dot_expires THEN
    v_player.leech_dot_amount := NULL; v_player.leech_dot_expires := NULL;
  END IF;
  IF v_opponent.leech_dot_expires IS NOT NULL AND v_round_no > v_opponent.leech_dot_expires THEN
    v_opponent.leech_dot_amount := NULL; v_opponent.leech_dot_expires := NULL;
  END IF;
  IF v_player.status_dot_expires IS NOT NULL AND v_round_no > v_player.status_dot_expires THEN
    v_player.status_dot_status := NULL; v_player.status_dot_chance := NULL; v_player.status_dot_expires := NULL;
  END IF;
  IF v_opponent.status_dot_expires IS NOT NULL AND v_round_no > v_opponent.status_dot_expires THEN
    v_opponent.status_dot_status := NULL; v_opponent.status_dot_chance := NULL; v_opponent.status_dot_expires := NULL;
  END IF;
  IF v_player.pierce_immunity_expires IS NOT NULL AND v_round_no > v_player.pierce_immunity_expires THEN
    v_player.pierce_immunity_type := NULL; v_player.pierce_immunity_expires := NULL;
  END IF;
  IF v_opponent.pierce_immunity_expires IS NOT NULL AND v_round_no > v_opponent.pierce_immunity_expires THEN
    v_opponent.pierce_immunity_type := NULL; v_opponent.pierce_immunity_expires := NULL;
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

  -- "Passe premier et rejoue" : le camp qui joue cette capacité prend la main
  -- IMMÉDIATEMENT, sans attendre le round suivant — tout l'intérêt de l'effet
  -- est de couper l'herbe sous le pied de l'adversaire, pas de le laisser
  -- frapper une dernière fois avant. Les deux camps ayant déjà
  -- soumis leur capacité quand ce moteur est appelé, il suffit d'inverser
  -- l'ordre d'ouverture du round. Si les DEUX la jouent, l'ordre normal
  -- tranche (aucun ne peut passer devant l'autre).
  v_attacker := p_first_attacker;
  IF p_first_attacker = 'opponent'
     AND p_player_ability.turn_effect = 'first_and_replay'
     AND p_opponent_ability.turn_effect IS DISTINCT FROM 'first_and_replay' THEN
    v_attacker := 'player';
  ELSIF p_first_attacker = 'player'
     AND p_opponent_ability.turn_effect = 'first_and_replay'
     AND p_player_ability.turn_effect IS DISTINCT FROM 'first_and_replay' THEN
    v_attacker := 'opponent';
  END IF;
  v_block_remaining := NULL;

  -- ── Météo : tout premier événement du tour ──────────────────────────────
  -- Un appel à ce moteur = UN tour de combat complet, donc un seul tick météo,
  -- pour les DEUX pokémon (chacun son propre jet), AVANT quoi que ce soit
  -- d'autre : avant l'ordre de passage, avant les ticks de statut, avant les
  -- effets de rythme, avant les capacités. C'est la règle du mode — « les deux
  -- joueurs choisissent leur capacité, et la météo est la première chose qui se
  -- produit ». L'ordre entre les deux camps suit l'ordre de jeu du round.
  IF v_weather IS NOT NULL THEN
    FOREACH v_weather_side IN ARRAY (CASE WHEN v_attacker = 'player' THEN ARRAY['player', 'opponent'] ELSE ARRAY['opponent', 'player'] END) LOOP
      IF v_weather_side = 'player' THEN
        v_weather_res := autobattle_weather_tick(
          v_weather, 'player', p_player_pokemon_type, v_player.hp, v_player.max_hp,
          v_player.status, p_player_talents, v_player.talent_state, v_turn_no + 1);
        v_player.hp := (v_weather_res ->> 'hp')::integer;
        v_player.status := v_weather_res ->> 'status';
        v_player.talent_state := v_weather_res -> 'state';
        v_turns := v_turns || (v_weather_res -> 'turns');
      ELSE
        v_weather_res := autobattle_weather_tick(
          v_weather, 'opponent', p_opponent_pokemon_type, v_opponent.hp, v_opponent.max_hp,
          v_opponent.status, p_opponent_talents, v_opponent.talent_state, v_turn_no + 1);
        v_opponent.hp := (v_weather_res ->> 'hp')::integer;
        v_opponent.status := v_weather_res ->> 'status';
        v_opponent.talent_state := v_weather_res -> 'state';
        v_turns := v_turns || (v_weather_res -> 'turns');
      END IF;
    END LOOP;
    -- La météo peut tuer avant que le tour n'ait commencé : le round s'arrête
    -- là, personne n'agit.
    IF v_player.hp <= 0 THEN
      v_outcome := 'lose';
    ELSIF v_opponent.hp <= 0 THEN
      v_outcome := 'win';
    END IF;
  END IF;

  LOOP
    -- K.O. de météo au tick d'ouverture : aucune activation n'a lieu.
    EXIT WHEN v_outcome IS NOT NULL;
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

    v_player.damage_mods := autobattle_mod_purge(v_player.damage_mods, v_round_no);
    v_player.precision_mods := autobattle_mod_purge(v_player.precision_mods, v_round_no);
    v_opponent.damage_mods := autobattle_mod_purge(v_opponent.damage_mods, v_round_no);
    v_opponent.precision_mods := autobattle_mod_purge(v_opponent.precision_mods, v_round_no);
    IF v_player.heal_dot_expires IS NOT NULL AND v_round_no > v_player.heal_dot_expires THEN
      v_player.heal_dot_amount := NULL; v_player.heal_dot_expires := NULL;
    END IF;
    IF v_opponent.heal_dot_expires IS NOT NULL AND v_round_no > v_opponent.heal_dot_expires THEN
      v_opponent.heal_dot_amount := NULL; v_opponent.heal_dot_expires := NULL;
    END IF;
    -- Voir les mêmes expirations avant la boucle.
    IF v_player.damage_dot_expires IS NOT NULL AND v_round_no > v_player.damage_dot_expires THEN
      v_player.damage_dot_amount := NULL; v_player.damage_dot_expires := NULL;
    END IF;
    IF v_opponent.damage_dot_expires IS NOT NULL AND v_round_no > v_opponent.damage_dot_expires THEN
      v_opponent.damage_dot_amount := NULL; v_opponent.damage_dot_expires := NULL;
    END IF;
    IF v_player.leech_dot_expires IS NOT NULL AND v_round_no > v_player.leech_dot_expires THEN
      v_player.leech_dot_amount := NULL; v_player.leech_dot_expires := NULL;
    END IF;
    IF v_opponent.leech_dot_expires IS NOT NULL AND v_round_no > v_opponent.leech_dot_expires THEN
      v_opponent.leech_dot_amount := NULL; v_opponent.leech_dot_expires := NULL;
    END IF;
    IF v_player.status_dot_expires IS NOT NULL AND v_round_no > v_player.status_dot_expires THEN
      v_player.status_dot_status := NULL; v_player.status_dot_chance := NULL; v_player.status_dot_expires := NULL;
    END IF;
    IF v_opponent.status_dot_expires IS NOT NULL AND v_round_no > v_opponent.status_dot_expires THEN
      v_opponent.status_dot_status := NULL; v_opponent.status_dot_chance := NULL; v_opponent.status_dot_expires := NULL;
    END IF;
    IF v_player.pierce_immunity_expires IS NOT NULL AND v_round_no > v_player.pierce_immunity_expires THEN
      v_player.pierce_immunity_type := NULL; v_player.pierce_immunity_expires := NULL;
    END IF;
    IF v_opponent.pierce_immunity_expires IS NOT NULL AND v_round_no > v_opponent.pierce_immunity_expires THEN
      v_opponent.pierce_immunity_type := NULL; v_opponent.pierce_immunity_expires := NULL;
    END IF;
    -- Immunité de type effective de CE tour, perce-immunité compris (voir
    -- autobattle_type_immune) : la capacité jouée perce déjà l'immunité pour
    -- son propre coup, un perce-immunité encore actif couvre les suivants.
    v_player_type_immune := autobattle_type_immune(
      p_player_ability.ability_type, p_opponent_pokemon_type,
      p_player_ability.pierce_immunity_type, v_player.pierce_immunity_type,
      v_player.pierce_immunity_expires, v_round_no);
    v_opponent_type_immune := autobattle_type_immune(
      p_opponent_ability.ability_type, p_player_pokemon_type,
      p_opponent_ability.pierce_immunity_type, v_opponent.pierce_immunity_type,
      v_opponent.pierce_immunity_expires, v_round_no);
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
      -- Malus de précision de la Peur/Confusion : posé par le tick ci-dessous,
      -- consommé par le tour que ce camp joue juste après, puis remis à zéro
      -- ici au tour suivant. VOULU : si ce tour-là est un tour passé
      -- (préparation d'une capacité en deux temps, charge, effet 'skip',
      -- rafale tirée à 0), le camp n'attaque pas et le malus est simplement
      -- perdu — le statut, lui, a bien été guéri par son tick. Le client fait
      -- exactement pareil (le badge s'éteint sur ce tour passé, voir
      -- AutoBattleScreen).
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

      -- Effets persistants OFFENSIFS subis par le camp qui ouvre son tour
      -- (dégâts par tour et vol de vie par tour, voir autobattle_dot_tick) :
      -- tout premier événement de son tour, avant même son tick de statut, et
      -- une seule fois par tour réel — d'où la place dans ce bloc
      -- v_block_remaining IS NULL, jamais au milieu d'une rafale. Ils tiquent
      -- que le tour soit joué ou non : un tour passé sur paralysie/gel/sommeil
      -- les subit quand même, exactement comme il subit le tick de brûlure et
      -- profite du soin passif. Un tick peut mettre K.O. : le round s'arrête
      -- alors là, sans que personne n'agisse.
      IF v_attacker = 'player' AND (v_player.damage_dot_amount IS NOT NULL OR v_player.leech_dot_amount IS NOT NULL) THEN
        v_dot_res := autobattle_dot_tick(
          'player', v_turn_no, v_player.hp, v_player.max_hp, v_opponent.hp, v_opponent.max_hp,
          v_player.status, v_opponent.status, v_player.damage_dot_amount, v_player.leech_dot_amount,
          p_player_talents, v_player.talent_state,
          v_opponent.heal_disabled_expires IS NOT NULL AND v_round_no <= v_opponent.heal_disabled_expires);
        v_player.hp := (v_dot_res ->> 'hp')::integer;
        v_opponent.hp := (v_dot_res ->> 'other_hp')::integer;
        v_player.status := v_dot_res ->> 'status';
        v_opponent.status := v_dot_res ->> 'other_status';
        v_player.talent_state := v_dot_res -> 'state';
        v_turns := v_turns || (v_dot_res -> 'turns');
        IF v_player.hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
      ELSIF v_attacker = 'opponent' AND (v_opponent.damage_dot_amount IS NOT NULL OR v_opponent.leech_dot_amount IS NOT NULL) THEN
        v_dot_res := autobattle_dot_tick(
          'opponent', v_turn_no, v_opponent.hp, v_opponent.max_hp, v_player.hp, v_player.max_hp,
          v_opponent.status, v_player.status, v_opponent.damage_dot_amount, v_opponent.leech_dot_amount,
          p_opponent_talents, v_opponent.talent_state,
          v_player.heal_disabled_expires IS NOT NULL AND v_round_no <= v_player.heal_disabled_expires);
        v_opponent.hp := (v_dot_res ->> 'hp')::integer;
        v_player.hp := (v_dot_res ->> 'other_hp')::integer;
        v_opponent.status := v_dot_res ->> 'status';
        v_player.status := v_dot_res ->> 'other_status';
        v_opponent.talent_state := v_dot_res -> 'state';
        v_turns := v_turns || (v_dot_res -> 'turns');
        IF v_opponent.hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
      END IF;

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
            -- Le poison est guéri par N'IMPORTE QUEL soin, celui-ci compris.
            IF v_player.status = 'poison' THEN v_player.status := NULL; END IF;
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_player.heal_dot_amount,
              'attacker_hp_after', v_player.hp, 'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
            ));
          END IF;
          -- Un tour entièrement passé à cause d'un statut bloquant (paralysie,
          -- gel, sommeil) met fin à la chaîne "Continue sur sa lancée" : la
          -- capacité cesse d'être imposée, le tour suivant redevient un choix
          -- libre. Une capacité qui IGNORE ce statut (ignore_status_block) ne
          -- passe pas par ici et poursuit donc sa chaîne normalement.
          v_player.keep_going_ability_nom := NULL;
          v_player.keep_going_remaining := 0;
          v_player.keep_going_count := 0;
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
            -- Le poison est guéri par N'IMPORTE QUEL soin, celui-ci compris.
            IF v_opponent.status = 'poison' THEN v_opponent.status := NULL; END IF;
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_opponent.heal_dot_amount,
              'attacker_hp_after', v_opponent.hp, 'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
            ));
          END IF;
          -- Un tour entièrement passé à cause d'un statut bloquant (paralysie,
          -- gel, sommeil) met fin à la chaîne "Continue sur sa lancée" : la
          -- capacité cesse d'être imposée, le tour suivant redevient un choix
          -- libre. Une capacité qui IGNORE ce statut (ignore_status_block) ne
          -- passe pas par ici et poursuit donc sa chaîne normalement.
          v_opponent.keep_going_ability_nom := NULL;
          v_opponent.keep_going_remaining := 0;
          v_opponent.keep_going_count := 0;
          v_attacker := 'player';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;

      ELSIF v_attacker = 'player' AND v_player.status = 'sleep' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        -- Talent 'heavy_sleeper' (« Somnolent ») : il faut exactement 6 pour
        -- se réveiller, au lieu de 4, 5 ou 6.
        v_status_cured := v_status_roll >= (CASE WHEN autobattle_talent_has_kind(p_player_talents, 'heavy_sleeper') THEN 6 ELSE 4 END);
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
            -- Le poison est guéri par N'IMPORTE QUEL soin, celui-ci compris.
            IF v_player.status = 'poison' THEN v_player.status := NULL; END IF;
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_player.heal_dot_amount,
              'attacker_hp_after', v_player.hp, 'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
            ));
          END IF;
          -- Un tour entièrement passé à cause d'un statut bloquant (paralysie,
          -- gel, sommeil) met fin à la chaîne "Continue sur sa lancée" : la
          -- capacité cesse d'être imposée, le tour suivant redevient un choix
          -- libre. Une capacité qui IGNORE ce statut (ignore_status_block) ne
          -- passe pas par ici et poursuit donc sa chaîne normalement.
          v_player.keep_going_ability_nom := NULL;
          v_player.keep_going_remaining := 0;
          v_player.keep_going_count := 0;
          v_attacker := 'opponent';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent.status = 'sleep' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        -- Talent 'heavy_sleeper' (« Somnolent ») : il faut exactement 6 pour
        -- se réveiller, au lieu de 4, 5 ou 6.
        v_status_cured := v_status_roll >= (CASE WHEN autobattle_talent_has_kind(p_opponent_talents, 'heavy_sleeper') THEN 6 ELSE 4 END);
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
            -- Le poison est guéri par N'IMPORTE QUEL soin, celui-ci compris.
            IF v_opponent.status = 'poison' THEN v_opponent.status := NULL; END IF;
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_opponent.heal_dot_amount,
              'attacker_hp_after', v_opponent.hp, 'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
            ));
          END IF;
          -- Un tour entièrement passé à cause d'un statut bloquant (paralysie,
          -- gel, sommeil) met fin à la chaîne "Continue sur sa lancée" : la
          -- capacité cesse d'être imposée, le tour suivant redevient un choix
          -- libre. Une capacité qui IGNORE ce statut (ignore_status_block) ne
          -- passe pas par ici et poursuit donc sa chaîne normalement.
          v_opponent.keep_going_ability_nom := NULL;
          v_opponent.keep_going_remaining := 0;
          v_opponent.keep_going_count := 0;
          v_attacker := 'player';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;

      ELSIF v_attacker = 'player' AND v_player.status = 'burn' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        -- Dégâts du tick, talents 'poison_damage_boost'/'burn_damage_boost'
        -- compris — la MÊME valeur doit alimenter les PV et le journal.
        v_tick_damage := 5 + autobattle_talent_tick_bonus(p_player_talents, p_opponent_talents, 'burn');
        v_player.hp := v_player.hp - v_tick_damage;
        -- Talents : les dégâts passifs peuvent tuer ('endure_ko') et faire passer
        -- sous le seuil de 'heal_below_hp' — évalué AVANT de figer le drapeau 'ko'.
        v_talent_res := autobattle_talent_survive(p_player_talents, v_player.talent_state, 'player', v_player.hp, v_player.max_hp, v_turn_no, v_player.status);
        v_player.hp := (v_talent_res ->> 'hp')::integer;
        v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
        v_player.talent_state := v_talent_res -> 'state';
        -- Un soin de talent guérit le poison, comme tout autre soin.
        v_player.status := v_talent_res ->> 'status';
        v_talent_pending := v_talent_res -> 'turns';
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', v_tick_damage, 'skipped', false,
          'status_tick', true, 'status', 'burn', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'attacker_hp_after', GREATEST(0, v_hp_shown), 'defender_hp_after', GREATEST(0, v_opponent.hp),
          'ko', v_player.hp <= 0
        )) || v_talent_pending;
        IF v_status_cured THEN v_player.status := NULL; END IF;
        IF v_player.hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent.status = 'burn' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        -- Dégâts du tick, talents 'poison_damage_boost'/'burn_damage_boost'
        -- compris — la MÊME valeur doit alimenter les PV et le journal.
        v_tick_damage := 5 + autobattle_talent_tick_bonus(p_player_talents, p_opponent_talents, 'burn');
        v_opponent.hp := v_opponent.hp - v_tick_damage;
        -- Talents : les dégâts passifs peuvent tuer ('endure_ko') et faire passer
        -- sous le seuil de 'heal_below_hp' — évalué AVANT de figer le drapeau 'ko'.
        v_talent_res := autobattle_talent_survive(p_opponent_talents, v_opponent.talent_state, 'opponent', v_opponent.hp, v_opponent.max_hp, v_turn_no, v_opponent.status);
        v_opponent.hp := (v_talent_res ->> 'hp')::integer;
        v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
        v_opponent.talent_state := v_talent_res -> 'state';
        -- Un soin de talent guérit le poison, comme tout autre soin.
        v_opponent.status := v_talent_res ->> 'status';
        v_talent_pending := v_talent_res -> 'turns';
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', v_tick_damage, 'skipped', false,
          'status_tick', true, 'status', 'burn', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'attacker_hp_after', GREATEST(0, v_hp_shown), 'defender_hp_after', GREATEST(0, v_player.hp),
          'ko', v_opponent.hp <= 0
        )) || v_talent_pending;
        IF v_status_cured THEN v_opponent.status := NULL; END IF;
        IF v_opponent.hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;

      ELSIF v_attacker = 'player' AND v_player.status = 'poison' THEN
        -- Dégâts du tick, talents 'poison_damage_boost'/'burn_damage_boost'
        -- compris — la MÊME valeur doit alimenter les PV et le journal.
        v_tick_damage := 3 + autobattle_talent_tick_bonus(p_player_talents, p_opponent_talents, 'poison');
        v_player.hp := v_player.hp - v_tick_damage;
        -- Talents : les dégâts passifs peuvent tuer ('endure_ko') et faire passer
        -- sous le seuil de 'heal_below_hp' — évalué AVANT de figer le drapeau 'ko'.
        v_talent_res := autobattle_talent_survive(p_player_talents, v_player.talent_state, 'player', v_player.hp, v_player.max_hp, v_turn_no, v_player.status);
        v_player.hp := (v_talent_res ->> 'hp')::integer;
        v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
        v_player.talent_state := v_talent_res -> 'state';
        -- Un soin de talent guérit le poison, comme tout autre soin.
        v_player.status := v_talent_res ->> 'status';
        v_talent_pending := v_talent_res -> 'turns';
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', v_tick_damage, 'skipped', false,
          'status_tick', true, 'status', 'poison', 'status_cured', false,
          'attacker_hp_after', GREATEST(0, v_hp_shown), 'defender_hp_after', GREATEST(0, v_opponent.hp),
          'ko', v_player.hp <= 0
        )) || v_talent_pending;
        IF v_player.hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent.status = 'poison' THEN
        -- Dégâts du tick, talents 'poison_damage_boost'/'burn_damage_boost'
        -- compris — la MÊME valeur doit alimenter les PV et le journal.
        v_tick_damage := 3 + autobattle_talent_tick_bonus(p_player_talents, p_opponent_talents, 'poison');
        v_opponent.hp := v_opponent.hp - v_tick_damage;
        -- Talents : les dégâts passifs peuvent tuer ('endure_ko') et faire passer
        -- sous le seuil de 'heal_below_hp' — évalué AVANT de figer le drapeau 'ko'.
        v_talent_res := autobattle_talent_survive(p_opponent_talents, v_opponent.talent_state, 'opponent', v_opponent.hp, v_opponent.max_hp, v_turn_no, v_opponent.status);
        v_opponent.hp := (v_talent_res ->> 'hp')::integer;
        v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
        v_opponent.talent_state := v_talent_res -> 'state';
        -- Un soin de talent guérit le poison, comme tout autre soin.
        v_opponent.status := v_talent_res ->> 'status';
        v_talent_pending := v_talent_res -> 'turns';
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', v_tick_damage, 'skipped', false,
          'status_tick', true, 'status', 'poison', 'status_cured', false,
          'attacker_hp_after', GREATEST(0, v_hp_shown), 'defender_hp_after', GREATEST(0, v_player.hp),
          'ko', v_opponent.hp <= 0
        )) || v_talent_pending;
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
        -- Le poison est guéri par N'IMPORTE QUEL soin, celui-ci compris.
        IF v_player.status = 'poison' THEN v_player.status := NULL; END IF;
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
        -- Le poison est guéri par N'IMPORTE QUEL soin, celui-ci compris.
        IF v_opponent.status = 'poison' THEN v_opponent.status := NULL; END IF;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
          'heal_dot_tick', true, 'heal', v_opponent.heal_dot_amount,
          'attacker_hp_after', v_opponent.hp, 'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
        ));
        IF v_opponent.status = 'poison' THEN v_opponent.status := NULL; END IF;
      END IF;

      -- Tentative de statut persistante subie par le camp qui agit (voir
      -- autobattle_status_dot_tick) : APRÈS son tick de statut, donc un statut
      -- posé ici ne se manifestera qu'à son tour suivant — comme un statut
      -- infligé par une attaque adverse. Le helper ne tente rien s'il a déjà un
      -- statut ; un tour entièrement passé (paralysie/gel/sommeil) n'arrive
      -- jamais jusqu'ici, mais c'est justement un tour où il en a un.
      IF v_attacker = 'player' AND v_player.status_dot_status IS NOT NULL AND v_player.status IS NULL THEN
        v_dot_res := autobattle_status_dot_tick('player', v_turn_no, v_player.hp, v_player.status,
          v_player.status_dot_status, v_player.status_dot_chance, p_player_talents, v_player.talent_state);
        v_player.status := v_dot_res ->> 'status';
        v_player.talent_state := v_dot_res -> 'state';
        v_turns := v_turns || (v_dot_res -> 'turns');
      ELSIF v_attacker = 'opponent' AND v_opponent.status_dot_status IS NOT NULL AND v_opponent.status IS NULL THEN
        v_dot_res := autobattle_status_dot_tick('opponent', v_turn_no, v_opponent.hp, v_opponent.status,
          v_opponent.status_dot_status, v_opponent.status_dot_chance, p_opponent_talents, v_opponent.talent_state);
        v_opponent.status := v_dot_res ->> 'status';
        v_opponent.talent_state := v_dot_res -> 'state';
        v_turns := v_turns || (v_dot_res -> 'turns');
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
      -- keep_going_ability_nom est LA source de vérité de "une chaîne est en
      -- cours" (les appelants s'y fient pour imposer la capacité au tour
      -- suivant) : il n'est vidé qu'à la fin de la chaîne — compteur épuisé
      -- en mode "N tours", ou premier raté dans les deux modes. En mode
      -- "jusqu'à l'échec", keep_going_remaining ne sert donc à rien et reste à 0.
      IF v_attacker = 'player' AND (p_player_ability.keep_going_turns IS NOT NULL OR COALESCE(p_player_ability.keep_going_until_fail, false)) THEN
        IF v_player.keep_going_ability_nom IS DISTINCT FROM p_player_ability.ability_nom THEN
          v_player.keep_going_ability_nom := p_player_ability.ability_nom;
          v_player.keep_going_count := 1;
          v_player.keep_going_remaining := COALESCE(p_player_ability.keep_going_turns, 0);
        ELSE
          v_player.keep_going_count := COALESCE(v_player.keep_going_count, 0) + 1;
          IF NOT COALESCE(p_player_ability.keep_going_until_fail, false) THEN
            v_player.keep_going_remaining := GREATEST(0, COALESCE(v_player.keep_going_remaining, 0) - 1);
          END IF;
        END IF;
        IF NOT COALESCE(p_player_ability.keep_going_until_fail, false) AND COALESCE(v_player.keep_going_remaining, 0) <= 0 THEN
          v_player.keep_going_ability_nom := NULL;
          v_player.keep_going_remaining := 0;
        END IF;
      ELSIF v_attacker = 'opponent' AND (p_opponent_ability.keep_going_turns IS NOT NULL OR COALESCE(p_opponent_ability.keep_going_until_fail, false)) THEN
        IF v_opponent.keep_going_ability_nom IS DISTINCT FROM p_opponent_ability.ability_nom THEN
          v_opponent.keep_going_ability_nom := p_opponent_ability.ability_nom;
          v_opponent.keep_going_count := 1;
          v_opponent.keep_going_remaining := COALESCE(p_opponent_ability.keep_going_turns, 0);
        ELSE
          v_opponent.keep_going_count := COALESCE(v_opponent.keep_going_count, 0) + 1;
          IF NOT COALESCE(p_opponent_ability.keep_going_until_fail, false) THEN
            v_opponent.keep_going_remaining := GREATEST(0, COALESCE(v_opponent.keep_going_remaining, 0) - 1);
          END IF;
        END IF;
        IF NOT COALESCE(p_opponent_ability.keep_going_until_fail, false) AND COALESCE(v_opponent.keep_going_remaining, 0) <= 0 THEN
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
      -- Talents du camp qui agit : annonce des bonus de stat devenus actifs, puis
      -- tentative d'infliger un statut ('inflict_status', déclencheur « à chaque
      -- tour »). Les passifs permanents sont annoncés en tête de combat.
      v_talent_res := autobattle_talent_act(p_player_talents, v_player.talent_state, 'player', 'each_turn', p_player_ability.ability_type,
        v_player.hp, v_player.max_hp, v_opponent.status, v_player.status, p_opponent_talents, v_turn_no, v_weather);
      v_player.talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
      -- Météo levée par un talent 'set_weather' : elle prend effet tout de
      -- suite, mais son tick de début de tour a déjà eu lieu — elle ne
      -- s'appliquera donc qu'au tour suivant, comme toute météo déclenchée en
      -- cours de tour.
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, p_weather_enabled, v_weather, 'player', v_player.hp, v_turn_no);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_turns := v_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      -- Statut infligé par un talent : la cible peut encore le neutraliser
      -- ('status_immunity' est déjà pris en compte, 'auto_cure_first_status' non).
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(p_opponent_talents, v_opponent.talent_state, 'opponent', v_talent_inflict, v_opponent.hp, v_turn_no);
        v_opponent.talent_state := v_talent_res -> 'state';
        v_turns := v_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_opponent.status := v_talent_inflict;
        END IF;
      END IF;

      -- Immunité de type (v_player_type_immune) traitée exactement comme
      -- l'invulnérabilité : même condition « la capacité vise-t-elle vraiment
      -- l'adversaire ? », même tour raté — seul le drapeau renvoyé change
      -- ('no_effect' au lieu d'invulnerable_miss), pour que le client affiche
      -- « Aucun effet ! » plutôt que « Invulnérable ! ».
      -- Capacité conditionnée au statut de la CIBLE (voir
      -- autobattle_ability_rules.requires_target_status) : hors condition, elle
      -- échoue purement et simplement — traité comme un raté, au même endroit
      -- que l'invulnérabilité et l'immunité de type, avec son propre texte.
      v_status_req_failed := p_player_ability.requires_target_status IS NOT NULL
        AND v_opponent.status IS DISTINCT FROM p_player_ability.requires_target_status;
      IF v_status_req_failed
         OR ((v_opponent.invulnerable OR v_player_type_immune OR autobattle_talent_shield_active(p_opponent_talents, v_opponent.talent_state)) AND (
        p_player_ability.deals_damage
        OR (p_player_ability.status_effect IS NOT NULL AND NOT p_player_ability.status_reversed)
        OR p_player_ability.stat_mod_target = 'opponent'
        OR p_player_ability.cancel_heal_duration IS NOT NULL
      )) THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true,
          'invulnerable_miss', NOT v_player_type_immune AND NOT v_status_req_failed,
          'no_effect', v_player_type_immune AND NOT v_status_req_failed,
          'requires_status_failed', v_status_req_failed,
          'requires_status', p_player_ability.requires_target_status,
          'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false
        ));
        IF p_player_ability.turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
        -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
        -- cesse d'être imposée, le tour suivant redevient un choix libre.
        IF p_player_ability.keep_going_turns IS NOT NULL OR COALESCE(p_player_ability.keep_going_until_fail, false) THEN
          v_player.keep_going_ability_nom := NULL;
          v_player.keep_going_remaining := 0;
        END IF;
      ELSE
        -- Talents de précision compris dans le total (donc reportés tels quels
        -- dans 'precision_mod_amount', que le client réutilise pour afficher le
        -- détail du calcul en debug admin).
        v_precision_mod_total := autobattle_mod_total(v_player.precision_mods, v_round_no, p_player_ability.ability_type)
          + autobattle_talent_stat_bonus(p_player_talents, v_player.talent_state, 'precision', p_player_ability.ability_type, v_player.hp, v_player.max_hp, v_opponent.status, v_player.status, v_weather)
          -- Buff/debuff de terrain (voir autobattle_weather_stat_bonus) : compté
          -- dans le même total, donc visible lui aussi dans 'precision_mod_amount'.
          + autobattle_weather_stat_bonus(v_weather, p_player_pokemon_type, p_player_ability.ability_type, 'precision');
        v_missed := (NOT v_player_never_miss) AND
          random() >= ((CASE WHEN p_precision_enabled THEN GREATEST(0, COALESCE(p_player_ability.precision, 10) - v_status_precision_penalty + v_precision_mod_total) ELSE 10 END * 10) / 100.0);

        IF v_missed THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true,
            'defender_hp_after', GREATEST(0, v_opponent.hp), 'ko', false,
            'precision_mod_amount', v_precision_mod_total
          ));
          IF p_player_ability.turn_effect = 'repeat_until_fail' THEN
            v_block_remaining := 1;
          END IF;
          -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
          -- cesse d'être imposée, le tour suivant redevient un choix libre.
          IF p_player_ability.keep_going_turns IS NOT NULL OR COALESCE(p_player_ability.keep_going_until_fail, false) THEN
            v_player.keep_going_ability_nom := NULL;
            v_player.keep_going_remaining := 0;
          END IF;
        ELSE
          -- Modificateur de dégâts actif : ignoré si son filtre de type (voir
          -- autobattle_ability_rules.stat_mod_type_filter) ne correspond pas
          -- au type de la capacité effectivement jouée ce tour-ci.
          v_damage_mod_applied := autobattle_mod_total(v_player.damage_mods, v_round_no, p_player_ability.ability_type)
            + autobattle_talent_stat_bonus(p_player_talents, v_player.talent_state, 'damage', p_player_ability.ability_type, v_player.hp, v_player.max_hp, v_opponent.status, v_player.status, v_weather)
            + autobattle_weather_stat_bonus(v_weather, p_player_pokemon_type, p_player_ability.ability_type, 'damage');
          -- Bouclier Prévention de la cible : annule les dégâts ADDITIONNELS
          -- dus au bonus super efficace (la composante espèce+XP est comptée
          -- une fois au lieu de deux), le reste du coup est inchangé.
          v_prevention_blocked := p_player_ability.type_bonus
            AND v_opponent.prevention_expires IS NOT NULL AND v_round_no <= v_opponent.prevention_expires;
          v_keep_going_bonus := 0;
          IF p_player_ability.deals_damage THEN
            v_hit_dice := CASE WHEN p_player_ability.degats_de IS NOT NULL AND p_player_ability.degats_de > 0
              THEN 1 + floor(random() * p_player_ability.degats_de)::integer ELSE 0 END;
            -- Talent 'dice_bonus_damage' : le dé est tombé sur la valeur configurée.
            v_talent_res := autobattle_talent_dice(p_player_talents, v_hit_dice, 'player', v_player.hp, v_turn_no);
            v_talent_dice_bonus := (v_talent_res ->> 'amount')::integer;
            v_talent_dice_turns := v_talent_res -> 'turns';
            v_hit_damage := GREATEST(0, p_player_ability.base_damage
              - (CASE WHEN v_prevention_blocked THEN p_player_ability.damage_species_xp ELSE 0 END)
              + v_hit_dice + v_damage_mod_applied);

            v_percent_hp_damage_applied := p_player_ability.percent_hp_damage_percent IS NOT NULL;
            IF v_percent_hp_damage_applied THEN
              v_hit_damage := GREATEST(0, floor(
                (CASE WHEN p_player_ability.percent_hp_damage_basis = 'max' THEN v_opponent.max_hp ELSE v_opponent.hp END)
                * p_player_ability.percent_hp_damage_percent / 100.0)::integer);
            END IF;

            v_bonus_condition_met := p_player_ability.bonus_condition = 'took_damage_last_turn' AND v_player.took_damage
              OR p_player_ability.bonus_condition = 'first_use' AND NOT v_player.used_ability
              OR p_player_ability.bonus_condition = 'dice_equals' AND v_hit_dice = p_player_ability.bonus_dice_value
              OR p_player_ability.bonus_condition = 'has_status' AND v_opponent.status IS NOT NULL AND (p_player_ability.bonus_status_filter IS NULL OR v_opponent.status = p_player_ability.bonus_status_filter)
              OR p_player_ability.bonus_condition = 'self_has_status' AND v_player.status IS NOT NULL AND (p_player_ability.bonus_status_filter IS NULL OR v_player.status = p_player_ability.bonus_status_filter)
              -- Comparaison des POIDS des deux espèces (voir
              -- autobattle_weight_condition) : « self » désigne ici le camp qui
              -- attaque, donc le joueur.
              OR p_player_ability.bonus_condition = 'weight_ratio' AND autobattle_weight_condition(
                   p_player_ability.bonus_weight_target, p_player_ability.bonus_weight_comparison,
                   p_player_ability.bonus_weight_percent, p_player_weight, p_opponent_weight);
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
            IF (p_player_ability.keep_going_turns IS NOT NULL OR COALESCE(p_player_ability.keep_going_until_fail, false)) AND COALESCE(v_player.keep_going_count, 0) > 1 THEN
              v_keep_going_bonus := (COALESCE(v_player.keep_going_count, 1) - 1) * (CASE
                WHEN p_player_ability.keep_going_bonus_type = 'percent_damage'
                  THEN floor(p_player_ability.damage_species_xp * COALESCE(p_player_ability.keep_going_bonus_percent, 0) / 100.0)::integer
                ELSE COALESCE(p_player_ability.keep_going_bonus_flat, 0) END);
              v_hit_damage := GREATEST(0, v_hit_damage + v_keep_going_bonus);
            END IF;
            IF v_talent_dice_bonus <> 0 THEN
              v_hit_damage := GREATEST(0, v_hit_damage + v_talent_dice_bonus);
            END IF;
          ELSE
            v_hit_dice := 0;
            v_hit_damage := 0;
            v_percent_hp_damage_applied := false;
            v_talent_dice_bonus := 0;
            v_talent_dice_turns := '[]'::jsonb;
          END IF;
          -- Talent 'inflict_status' déclenché par le TYPE de la capacité jouée :
          -- uniquement sur un COUP DIRECT qui a porté (capacité offensive, non
          -- ratée, dégâts non nuls) — jamais sur une capacité de soutien ni sur
          -- un tick de brûlure/poison, qui ne passent pas par ici.
          IF v_hit_damage > 0 THEN
            v_talent_res := autobattle_talent_act(p_player_talents, v_player.talent_state, 'player', 'on_ability_type', p_player_ability.ability_type,
              v_player.hp, v_player.max_hp, v_opponent.status, v_player.status, p_opponent_talents, v_turn_no, v_weather);
            v_player.talent_state := v_talent_res -> 'state';
            v_turns := v_turns || (v_talent_res -> 'turns');
            v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, p_weather_enabled, v_weather, 'player', v_player.hp, v_turn_no);
            v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
            v_turns := v_turns || (v_weather_res -> 'turns');
            v_talent_inflict := v_talent_res ->> 'inflict_status';
            IF v_talent_inflict IS NOT NULL THEN
              v_talent_res := autobattle_talent_status_guard(p_opponent_talents, v_opponent.talent_state, 'opponent', v_talent_inflict, v_opponent.hp, v_turn_no);
              v_opponent.talent_state := v_talent_res -> 'state';
              v_turns := v_turns || (v_talent_res -> 'turns');
              IF NOT (v_talent_res ->> 'blocked')::boolean THEN
                v_opponent.status := v_talent_inflict;
              END IF;
            END IF;
          END IF;
          -- 'first_and_replay' ne "compte" pas comme une capacité utilisée
          -- (voir autobattle_ability_rules) : la condition de bonus
          -- 'first_use' reste donc vraie pour la vraie attaque qui suit.
          IF p_player_ability.turn_effect IS DISTINCT FROM 'first_and_replay' THEN
            v_player.used_ability := true;
          END IF;

          -- Talents défensifs de la CIBLE : immunité de type, conversion des dégâts en
          -- soin, absorption du premier coup — et comptage du coup encaissé (hits).
          v_talent_res := autobattle_talent_defend(p_opponent_talents, v_opponent.talent_state, 'opponent', v_hit_damage, p_player_ability.ability_type, v_opponent.hp, v_turn_no, v_opponent.status);
          v_hit_damage := (v_talent_res ->> 'damage')::integer;
          v_talent_heal := (v_talent_res ->> 'heal')::integer;
          v_opponent.talent_state := v_talent_res -> 'state';
          -- Des dégâts convertis en soin guérissent le poison, comme tout soin.
          v_opponent.status := v_talent_res ->> 'status';
          v_talent_pending := COALESCE(v_talent_dice_turns, '[]'::jsonb) || (v_talent_res -> 'turns');
          -- Un coup qui inflige réellement des dégâts consomme le bouclier
          -- 'invulnerable_until_hit' de son AUTEUR.
          IF v_hit_damage > 0 THEN
            v_player.talent_state := autobattle_talent_spend_shield(p_player_talents, v_player.talent_state);
          END IF;

          v_opponent.hp := LEAST(v_opponent.max_hp, v_opponent.hp - v_hit_damage + v_talent_heal);
          v_opponent.took_damage := v_hit_damage > 0;

          -- 'endure_ko' / 'heal_below_hp' : évalués AVANT la construction de l'entrée
          -- de tour, qui fige le drapeau 'ko' et defender_hp_after.
          v_talent_res := autobattle_talent_survive(p_opponent_talents, v_opponent.talent_state, 'opponent', v_opponent.hp, v_opponent.max_hp, v_turn_no, v_opponent.status);
          v_opponent.hp := (v_talent_res ->> 'hp')::integer;
          v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
          v_opponent.talent_state := v_talent_res -> 'state';
          -- Un soin de talent guérit le poison, comme tout autre soin.
          v_opponent.status := v_talent_res ->> 'status';
          v_talent_pending := v_talent_pending || (v_talent_res -> 'turns');

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
            'defender_hp_after', GREATEST(0, v_hp_shown), 'ko', v_opponent.hp <= 0,
            'precision_mod_amount', v_precision_mod_total
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
            -- Talents de la CIBLE du statut ('status_immunity', 'auto_cure_first_status') :
            -- la cible est l'utilisateur lui-même si le statut est retourné.
            v_talent_res := autobattle_talent_status_guard(
              CASE WHEN p_player_ability.status_reversed THEN p_player_talents ELSE p_opponent_talents END,
              CASE WHEN p_player_ability.status_reversed THEN v_player.talent_state ELSE v_opponent.talent_state END,
              CASE WHEN p_player_ability.status_reversed THEN 'player' ELSE 'opponent' END,
              p_player_ability.status_effect,
              CASE WHEN p_player_ability.status_reversed THEN v_player.hp ELSE v_opponent.hp END, v_turn_no);
            IF p_player_ability.status_reversed THEN v_player.talent_state := v_talent_res -> 'state';
            ELSE v_opponent.talent_state := v_talent_res -> 'state'; END IF;
            v_talent_pending := COALESCE(v_talent_pending, '[]'::jsonb) || (v_talent_res -> 'turns');
            IF NOT (v_talent_res ->> 'blocked')::boolean THEN
              IF p_player_ability.status_reversed THEN
                v_player.status := p_player_ability.status_effect;
              ELSE
                v_opponent.status := p_player_ability.status_effect;
              END IF;
              v_turn_entry := v_turn_entry || jsonb_build_object('status_applied', p_player_ability.status_effect, 'status_applied_reversed', p_player_ability.status_reversed);
            END IF;
          END IF;
          -- Météo levée par la capacité (façon Danse Pluie) : au même moment que
          -- l'infliction de statut, donc seulement sur une utilisation qui a
          -- touché. Comme pour les talents, elle ne s'appliquera qu'au tour
          -- suivant (le tick de ce tour est déjà passé).
          IF p_player_ability.weather_id IS NOT NULL
             AND random() * 100 < COALESCE(p_player_ability.weather_chance, 0) THEN
            v_weather_res := autobattle_weather_set(p_player_ability.weather_id, p_weather_enabled, v_weather, 'player', v_player.hp, v_turn_no);
            v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
            v_talent_pending := COALESCE(v_talent_pending, '[]'::jsonb) || (v_weather_res -> 'turns');
          END IF;
          -- Le modificateur de stat peut être conditionné à la météo en cours
          -- (voir autobattle_ability_rules.stat_mod_weather_condition) : hors
          -- condition, la capacité est jouée normalement mais n'applique rien.
          IF p_player_ability.stat_mod_target IS NOT NULL
             AND autobattle_weather_cond(p_player_ability.stat_mod_weather_condition, p_player_ability.stat_mod_weather_id, v_weather) THEN
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
              v_stat_mod_amount := autobattle_stat_mod_signed(v_stat_mod_amount, p_player_ability.stat_mod_target, p_player_ability.stat_mod_direction);
              v_stat_mod_expiry := CASE WHEN p_player_ability.stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_round_no + 2 * COALESCE(p_player_ability.stat_mod_duration_turns, 1) END;
              -- Chaque application est EMPILÉE avec sa propre échéance et son
              -- propre filtre de type (relu au moment d'infliger des dégâts,
              -- contre le type de la capacité jouée alors) : réutiliser la
              -- capacité cumule les montants au lieu de les écraser.
              IF p_player_ability.stat_mod_target = 'self' AND p_player_ability.stat_mod_stat = 'damage' THEN
                v_player.damage_mods := COALESCE(v_player.damage_mods, '[]'::jsonb) || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry, 't', p_player_ability.stat_mod_type_filter));
              ELSIF p_player_ability.stat_mod_target = 'self' AND p_player_ability.stat_mod_stat = 'precision' THEN
                v_player.precision_mods := COALESCE(v_player.precision_mods, '[]'::jsonb) || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry));
              ELSIF p_player_ability.stat_mod_target = 'opponent' AND p_player_ability.stat_mod_stat = 'damage' THEN
                v_opponent.damage_mods := COALESCE(v_opponent.damage_mods, '[]'::jsonb) || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry, 't', p_player_ability.stat_mod_type_filter));
              ELSIF p_player_ability.stat_mod_target = 'opponent' AND p_player_ability.stat_mod_stat = 'precision' THEN
                v_opponent.precision_mods := COALESCE(v_opponent.precision_mods, '[]'::jsonb) || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry));
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
          -- Effets persistants OFFENSIFS posés sur la CIBLE (voir
          -- autobattle_ability_rules.damage_dot_*/leech_dot_*) : le montant par
          -- tick est résolu UNE FOIS ici et jamais recalculé — un pourcentage
          -- se compte sur les PV MAX de la VICTIME. Plancher à 1 PV pour qu'un
          -- petit pourcentage sur une petite barre de vie ne donne pas un effet
          -- inerte. x2 sur l'échéance pour la même raison que le soin passif
          -- (compteur de rounds global, tick un tour sur deux). Réutiliser la
          -- capacité repose l'effet à neuf.
          IF p_player_ability.damage_dot_config_turns IS NOT NULL THEN
            v_opponent.damage_dot_amount := GREATEST(1, CASE
              WHEN p_player_ability.damage_dot_config_type = 'percent_max_hp'
                THEN floor(v_opponent.max_hp * COALESCE(p_player_ability.damage_dot_config_percent, 0) / 100.0)::integer
              ELSE COALESCE(p_player_ability.damage_dot_config_amount, 0) END);
            v_opponent.damage_dot_expires := v_round_no + 2 * p_player_ability.damage_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('damage_dot_granted', true);
          END IF;
          IF p_player_ability.leech_dot_config_turns IS NOT NULL THEN
            v_opponent.leech_dot_amount := GREATEST(1, CASE
              WHEN p_player_ability.leech_dot_config_type = 'percent_max_hp'
                THEN floor(v_opponent.max_hp * COALESCE(p_player_ability.leech_dot_config_percent, 0) / 100.0)::integer
              ELSE COALESCE(p_player_ability.leech_dot_config_amount, 0) END);
            v_opponent.leech_dot_expires := v_round_no + 2 * p_player_ability.leech_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('leech_dot_granted', true);
          END IF;
          -- Tentative de statut persistante : le statut guetté et sa
          -- probabilité sont posés tels quels sur la cible, le jet a lieu à
          -- chacun de SES tours (voir autobattle_status_dot_tick).
          IF p_player_ability.status_dot_config_turns IS NOT NULL THEN
            v_opponent.status_dot_status := p_player_ability.status_dot_config_status;
            v_opponent.status_dot_chance := p_player_ability.status_dot_config_chance;
            v_opponent.status_dot_expires := v_round_no + 2 * p_player_ability.status_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('status_dot_granted', true);
          END IF;
          -- Perce-immunité : accordé à son LANCEUR (voir autobattle_type_immune
          -- — le coup en cours en profite déjà, sans quoi une capacité
          -- immunisée ne pourrait jamais toucher pour le poser).
          IF p_player_ability.pierce_immunity_type IS NOT NULL AND p_player_ability.pierce_immunity_turns IS NOT NULL THEN
            v_player.pierce_immunity_type := p_player_ability.pierce_immunity_type;
            v_player.pierce_immunity_expires := v_round_no + 2 * p_player_ability.pierce_immunity_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('pierce_immunity_granted', true);
          END IF;
          -- Purges (voir clear_damage_dot / cure_status / clear_weather) :
          -- elles visent leur LANCEUR — ses propres dégâts sur la durée, ses
          -- propres statuts — sauf la météo, état de TERRAIN partagé qui
          -- disparaît pour les deux camps. Les statuts à dégâts (brûlure,
          -- poison) ne sont PAS concernés par la purge des dégâts sur la
          -- durée : ils relèvent de cure_status.
          IF COALESCE(p_player_ability.clear_damage_dot, false)
             AND (v_player.damage_dot_amount IS NOT NULL OR v_player.leech_dot_amount IS NOT NULL
                  OR v_player.status_dot_status IS NOT NULL) THEN
            v_player.damage_dot_amount := NULL; v_player.damage_dot_expires := NULL;
            v_player.leech_dot_amount := NULL; v_player.leech_dot_expires := NULL;
            v_player.status_dot_status := NULL; v_player.status_dot_chance := NULL; v_player.status_dot_expires := NULL;
            v_turn_entry := v_turn_entry || jsonb_build_object('cleanse_dot', true);
          END IF;
          IF COALESCE(p_player_ability.cure_status, false) AND v_player.status IS NOT NULL THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('cleanse_status', v_player.status);
            v_player.status := NULL;
          END IF;
          IF COALESCE(p_player_ability.clear_weather, false) AND v_weather IS NOT NULL THEN
            v_talent_pending := COALESCE(v_talent_pending, '[]'::jsonb) || jsonb_build_array(
              autobattle_weather_turn(v_turn_no, 'player', v_player.hp, v_weather,
                jsonb_build_object('weather_cleared', true)));
            v_weather := NULL;
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
          IF p_player_ability.recoil_type IS NOT NULL AND NOT autobattle_talent_has_kind(p_player_talents, 'no_recoil') THEN
            v_recoil_amt := CASE WHEN p_player_ability.recoil_type = 'range'
              THEN p_player_ability.recoil_min + floor(random() * (p_player_ability.recoil_max - p_player_ability.recoil_min + 1))::integer
              ELSE floor(v_hit_damage * COALESCE(p_player_ability.recoil_percent, 0) / 100.0)::integer END;
            IF v_recoil_amt > 0 THEN
              v_player.hp := v_player.hp - v_recoil_amt;
              -- Le contre-coup peut tuer son auteur : mêmes talents de survie.
              v_talent_res := autobattle_talent_survive(p_player_talents, v_player.talent_state, 'player', v_player.hp, v_player.max_hp, v_turn_no, v_player.status);
              v_player.hp := (v_talent_res ->> 'hp')::integer;
              v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
              v_player.talent_state := v_talent_res -> 'state';
              -- Un soin de talent guérit le poison, comme tout autre soin.
              v_player.status := v_talent_res ->> 'status';
              v_talent_pending := v_talent_pending || (v_talent_res -> 'turns');
              v_turn_entry := v_turn_entry || jsonb_build_object('recoil', v_recoil_amt, 'attacker_hp_after', v_player.hp);
            END IF;
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry) || COALESCE(v_talent_pending, '[]'::jsonb);

          IF v_opponent.hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
          IF v_player.hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
        END IF;
      END IF;
    ELSE
      -- Talents du camp qui agit : annonce des bonus de stat devenus actifs, puis
      -- tentative d'infliger un statut ('inflict_status', déclencheur « à chaque
      -- tour »). Les passifs permanents sont annoncés en tête de combat.
      v_talent_res := autobattle_talent_act(p_opponent_talents, v_opponent.talent_state, 'opponent', 'each_turn', p_opponent_ability.ability_type,
        v_opponent.hp, v_opponent.max_hp, v_player.status, v_opponent.status, p_player_talents, v_turn_no, v_weather);
      v_opponent.talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
      -- Voir le même commentaire côté joueur plus haut.
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, p_weather_enabled, v_weather, 'opponent', v_opponent.hp, v_turn_no);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_turns := v_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      -- Statut infligé par un talent : la cible peut encore le neutraliser
      -- ('status_immunity' est déjà pris en compte, 'auto_cure_first_status' non).
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(p_player_talents, v_player.talent_state, 'player', v_talent_inflict, v_player.hp, v_turn_no);
        v_player.talent_state := v_talent_res -> 'state';
        v_turns := v_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_player.status := v_talent_inflict;
        END IF;
      END IF;

      -- Immunité de type côté adverse : voir la branche symétrique du camp
      -- joueur plus haut.
      -- Voir la branche symétrique du camp joueur plus haut.
      v_status_req_failed := p_opponent_ability.requires_target_status IS NOT NULL
        AND v_player.status IS DISTINCT FROM p_opponent_ability.requires_target_status;
      IF v_status_req_failed
         OR ((v_player.invulnerable OR v_opponent_type_immune OR autobattle_talent_shield_active(p_player_talents, v_player.talent_state)) AND (
        p_opponent_ability.deals_damage
        OR (p_opponent_ability.status_effect IS NOT NULL AND NOT p_opponent_ability.status_reversed)
        OR p_opponent_ability.stat_mod_target = 'opponent'
        OR p_opponent_ability.cancel_heal_duration IS NOT NULL
      )) THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'missed', true,
          'invulnerable_miss', NOT v_opponent_type_immune AND NOT v_status_req_failed,
          'no_effect', v_opponent_type_immune AND NOT v_status_req_failed,
          'requires_status_failed', v_status_req_failed,
          'requires_status', p_opponent_ability.requires_target_status,
          'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false
        ));
        IF p_opponent_ability.turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
        -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
        -- cesse d'être imposée, le tour suivant redevient un choix libre.
        IF p_opponent_ability.keep_going_turns IS NOT NULL OR COALESCE(p_opponent_ability.keep_going_until_fail, false) THEN
          v_opponent.keep_going_ability_nom := NULL;
          v_opponent.keep_going_remaining := 0;
        END IF;
      ELSE
        v_precision_mod_total := autobattle_mod_total(v_opponent.precision_mods, v_round_no, p_opponent_ability.ability_type)
          + autobattle_talent_stat_bonus(p_opponent_talents, v_opponent.talent_state, 'precision', p_opponent_ability.ability_type, v_opponent.hp, v_opponent.max_hp, v_player.status, v_opponent.status, v_weather)
          + autobattle_weather_stat_bonus(v_weather, p_opponent_pokemon_type, p_opponent_ability.ability_type, 'precision');
        v_missed := (NOT v_opponent_never_miss) AND
          random() >= ((CASE WHEN p_precision_enabled THEN GREATEST(0, COALESCE(p_opponent_ability.precision, 10) - v_status_precision_penalty + v_precision_mod_total) ELSE 10 END * 10) / 100.0);

        IF v_missed THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'missed', true,
            'defender_hp_after', GREATEST(0, v_player.hp), 'ko', false,
            'precision_mod_amount', v_precision_mod_total
          ));
          IF p_opponent_ability.turn_effect = 'repeat_until_fail' THEN
            v_block_remaining := 1;
          END IF;
          -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
          -- cesse d'être imposée, le tour suivant redevient un choix libre.
          IF p_opponent_ability.keep_going_turns IS NOT NULL OR COALESCE(p_opponent_ability.keep_going_until_fail, false) THEN
            v_opponent.keep_going_ability_nom := NULL;
            v_opponent.keep_going_remaining := 0;
          END IF;
        ELSE
          -- Voir les mêmes commentaires côté joueur plus haut.
          v_damage_mod_applied := autobattle_mod_total(v_opponent.damage_mods, v_round_no, p_opponent_ability.ability_type)
            + autobattle_talent_stat_bonus(p_opponent_talents, v_opponent.talent_state, 'damage', p_opponent_ability.ability_type, v_opponent.hp, v_opponent.max_hp, v_player.status, v_opponent.status, v_weather)
            + autobattle_weather_stat_bonus(v_weather, p_opponent_pokemon_type, p_opponent_ability.ability_type, 'damage');
          v_prevention_blocked := p_opponent_ability.type_bonus
            AND v_player.prevention_expires IS NOT NULL AND v_round_no <= v_player.prevention_expires;
          v_keep_going_bonus := 0;
          IF p_opponent_ability.deals_damage THEN
            v_hit_dice := CASE WHEN p_opponent_ability.degats_de IS NOT NULL AND p_opponent_ability.degats_de > 0
              THEN 1 + floor(random() * p_opponent_ability.degats_de)::integer ELSE 0 END;
            -- Talent 'dice_bonus_damage' : le dé est tombé sur la valeur configurée.
            v_talent_res := autobattle_talent_dice(p_opponent_talents, v_hit_dice, 'opponent', v_opponent.hp, v_turn_no);
            v_talent_dice_bonus := (v_talent_res ->> 'amount')::integer;
            v_talent_dice_turns := v_talent_res -> 'turns';
            v_hit_damage := GREATEST(0, p_opponent_ability.base_damage
              - (CASE WHEN v_prevention_blocked THEN p_opponent_ability.damage_species_xp ELSE 0 END)
              + v_hit_dice + v_damage_mod_applied);

            v_percent_hp_damage_applied := p_opponent_ability.percent_hp_damage_percent IS NOT NULL;
            IF v_percent_hp_damage_applied THEN
              v_hit_damage := GREATEST(0, floor(
                (CASE WHEN p_opponent_ability.percent_hp_damage_basis = 'max' THEN v_player.max_hp ELSE v_player.hp END)
                * p_opponent_ability.percent_hp_damage_percent / 100.0)::integer);
            END IF;

            v_bonus_condition_met := p_opponent_ability.bonus_condition = 'took_damage_last_turn' AND v_opponent.took_damage
              OR p_opponent_ability.bonus_condition = 'first_use' AND NOT v_opponent.used_ability
              OR p_opponent_ability.bonus_condition = 'dice_equals' AND v_hit_dice = p_opponent_ability.bonus_dice_value
              OR p_opponent_ability.bonus_condition = 'has_status' AND v_player.status IS NOT NULL AND (p_opponent_ability.bonus_status_filter IS NULL OR v_player.status = p_opponent_ability.bonus_status_filter)
              OR p_opponent_ability.bonus_condition = 'self_has_status' AND v_opponent.status IS NOT NULL AND (p_opponent_ability.bonus_status_filter IS NULL OR v_opponent.status = p_opponent_ability.bonus_status_filter)
              -- Poids : « self » est cette fois l'adversaire, qui attaque.
              OR p_opponent_ability.bonus_condition = 'weight_ratio' AND autobattle_weight_condition(
                   p_opponent_ability.bonus_weight_target, p_opponent_ability.bonus_weight_comparison,
                   p_opponent_ability.bonus_weight_percent, p_opponent_weight, p_player_weight);
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

            IF (p_opponent_ability.keep_going_turns IS NOT NULL OR COALESCE(p_opponent_ability.keep_going_until_fail, false)) AND COALESCE(v_opponent.keep_going_count, 0) > 1 THEN
              v_keep_going_bonus := (COALESCE(v_opponent.keep_going_count, 1) - 1) * (CASE
                WHEN p_opponent_ability.keep_going_bonus_type = 'percent_damage'
                  THEN floor(p_opponent_ability.damage_species_xp * COALESCE(p_opponent_ability.keep_going_bonus_percent, 0) / 100.0)::integer
                ELSE COALESCE(p_opponent_ability.keep_going_bonus_flat, 0) END);
              v_hit_damage := GREATEST(0, v_hit_damage + v_keep_going_bonus);
            END IF;
            IF v_talent_dice_bonus <> 0 THEN
              v_hit_damage := GREATEST(0, v_hit_damage + v_talent_dice_bonus);
            END IF;
          ELSE
            v_hit_dice := 0;
            v_hit_damage := 0;
            v_percent_hp_damage_applied := false;
            v_talent_dice_bonus := 0;
            v_talent_dice_turns := '[]'::jsonb;
          END IF;
          -- Talent 'inflict_status' déclenché par le TYPE de la capacité jouée :
          -- uniquement sur un COUP DIRECT qui a porté (capacité offensive, non
          -- ratée, dégâts non nuls) — jamais sur une capacité de soutien ni sur
          -- un tick de brûlure/poison, qui ne passent pas par ici.
          IF v_hit_damage > 0 THEN
            v_talent_res := autobattle_talent_act(p_opponent_talents, v_opponent.talent_state, 'opponent', 'on_ability_type', p_opponent_ability.ability_type,
              v_opponent.hp, v_opponent.max_hp, v_player.status, v_opponent.status, p_player_talents, v_turn_no, v_weather);
            v_opponent.talent_state := v_talent_res -> 'state';
            v_turns := v_turns || (v_talent_res -> 'turns');
            v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, p_weather_enabled, v_weather, 'opponent', v_opponent.hp, v_turn_no);
            v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
            v_turns := v_turns || (v_weather_res -> 'turns');
            v_talent_inflict := v_talent_res ->> 'inflict_status';
            IF v_talent_inflict IS NOT NULL THEN
              v_talent_res := autobattle_talent_status_guard(p_player_talents, v_player.talent_state, 'player', v_talent_inflict, v_player.hp, v_turn_no);
              v_player.talent_state := v_talent_res -> 'state';
              v_turns := v_turns || (v_talent_res -> 'turns');
              IF NOT (v_talent_res ->> 'blocked')::boolean THEN
                v_player.status := v_talent_inflict;
              END IF;
            END IF;
          END IF;
          IF p_opponent_ability.turn_effect IS DISTINCT FROM 'first_and_replay' THEN
            v_opponent.used_ability := true;
          END IF;

          -- Talents défensifs de la CIBLE : immunité de type, conversion des dégâts en
          -- soin, absorption du premier coup — et comptage du coup encaissé (hits).
          v_talent_res := autobattle_talent_defend(p_player_talents, v_player.talent_state, 'player', v_hit_damage, p_opponent_ability.ability_type, v_player.hp, v_turn_no, v_player.status);
          v_hit_damage := (v_talent_res ->> 'damage')::integer;
          v_talent_heal := (v_talent_res ->> 'heal')::integer;
          v_player.talent_state := v_talent_res -> 'state';
          -- Des dégâts convertis en soin guérissent le poison, comme tout soin.
          v_player.status := v_talent_res ->> 'status';
          v_talent_pending := COALESCE(v_talent_dice_turns, '[]'::jsonb) || (v_talent_res -> 'turns');
          -- Un coup qui inflige réellement des dégâts consomme le bouclier
          -- 'invulnerable_until_hit' de son AUTEUR.
          IF v_hit_damage > 0 THEN
            v_opponent.talent_state := autobattle_talent_spend_shield(p_opponent_talents, v_opponent.talent_state);
          END IF;

          v_player.hp := LEAST(v_player.max_hp, v_player.hp - v_hit_damage + v_talent_heal);
          v_player.took_damage := v_hit_damage > 0;

          -- 'endure_ko' / 'heal_below_hp' : évalués AVANT la construction de l'entrée
          -- de tour, qui fige le drapeau 'ko' et defender_hp_after.
          v_talent_res := autobattle_talent_survive(p_player_talents, v_player.talent_state, 'player', v_player.hp, v_player.max_hp, v_turn_no, v_player.status);
          v_player.hp := (v_talent_res ->> 'hp')::integer;
          v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
          v_player.talent_state := v_talent_res -> 'state';
          -- Un soin de talent guérit le poison, comme tout autre soin.
          v_player.status := v_talent_res ->> 'status';
          v_talent_pending := v_talent_pending || (v_talent_res -> 'turns');

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
            'defender_hp_after', GREATEST(0, v_hp_shown), 'ko', v_player.hp <= 0,
            'precision_mod_amount', v_precision_mod_total
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
            -- Talents de la CIBLE du statut ('status_immunity', 'auto_cure_first_status') :
            -- la cible est l'utilisateur lui-même si le statut est retourné.
            v_talent_res := autobattle_talent_status_guard(
              CASE WHEN p_opponent_ability.status_reversed THEN p_opponent_talents ELSE p_player_talents END,
              CASE WHEN p_opponent_ability.status_reversed THEN v_opponent.talent_state ELSE v_player.talent_state END,
              CASE WHEN p_opponent_ability.status_reversed THEN 'opponent' ELSE 'player' END,
              p_opponent_ability.status_effect,
              CASE WHEN p_opponent_ability.status_reversed THEN v_opponent.hp ELSE v_player.hp END, v_turn_no);
            IF p_opponent_ability.status_reversed THEN v_opponent.talent_state := v_talent_res -> 'state';
            ELSE v_player.talent_state := v_talent_res -> 'state'; END IF;
            v_talent_pending := COALESCE(v_talent_pending, '[]'::jsonb) || (v_talent_res -> 'turns');
            IF NOT (v_talent_res ->> 'blocked')::boolean THEN
              IF p_opponent_ability.status_reversed THEN
                v_opponent.status := p_opponent_ability.status_effect;
              ELSE
                v_player.status := p_opponent_ability.status_effect;
              END IF;
              v_turn_entry := v_turn_entry || jsonb_build_object('status_applied', p_opponent_ability.status_effect, 'status_applied_reversed', p_opponent_ability.status_reversed);
            END IF;
          END IF;
          -- Voir les mêmes commentaires côté joueur plus haut.
          IF p_opponent_ability.weather_id IS NOT NULL
             AND random() * 100 < COALESCE(p_opponent_ability.weather_chance, 0) THEN
            v_weather_res := autobattle_weather_set(p_opponent_ability.weather_id, p_weather_enabled, v_weather, 'opponent', v_opponent.hp, v_turn_no);
            v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
            v_talent_pending := COALESCE(v_talent_pending, '[]'::jsonb) || (v_weather_res -> 'turns');
          END IF;
          IF p_opponent_ability.stat_mod_target IS NOT NULL
             AND autobattle_weather_cond(p_opponent_ability.stat_mod_weather_condition, p_opponent_ability.stat_mod_weather_id, v_weather) THEN
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
              v_stat_mod_amount := autobattle_stat_mod_signed(v_stat_mod_amount, p_opponent_ability.stat_mod_target, p_opponent_ability.stat_mod_direction);
              v_stat_mod_expiry := CASE WHEN p_opponent_ability.stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_round_no + 2 * COALESCE(p_opponent_ability.stat_mod_duration_turns, 1) END;
              -- Voir le même commentaire côté joueur plus haut.
              IF p_opponent_ability.stat_mod_target = 'self' AND p_opponent_ability.stat_mod_stat = 'damage' THEN
                v_opponent.damage_mods := COALESCE(v_opponent.damage_mods, '[]'::jsonb) || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry, 't', p_opponent_ability.stat_mod_type_filter));
              ELSIF p_opponent_ability.stat_mod_target = 'self' AND p_opponent_ability.stat_mod_stat = 'precision' THEN
                v_opponent.precision_mods := COALESCE(v_opponent.precision_mods, '[]'::jsonb) || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry));
              ELSIF p_opponent_ability.stat_mod_target = 'opponent' AND p_opponent_ability.stat_mod_stat = 'damage' THEN
                v_player.damage_mods := COALESCE(v_player.damage_mods, '[]'::jsonb) || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry, 't', p_opponent_ability.stat_mod_type_filter));
              ELSIF p_opponent_ability.stat_mod_target = 'opponent' AND p_opponent_ability.stat_mod_stat = 'precision' THEN
                v_player.precision_mods := COALESCE(v_player.precision_mods, '[]'::jsonb) || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry));
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
          -- Voir les mêmes octrois côté joueur plus haut.
          IF p_opponent_ability.damage_dot_config_turns IS NOT NULL THEN
            v_player.damage_dot_amount := GREATEST(1, CASE
              WHEN p_opponent_ability.damage_dot_config_type = 'percent_max_hp'
                THEN floor(v_player.max_hp * COALESCE(p_opponent_ability.damage_dot_config_percent, 0) / 100.0)::integer
              ELSE COALESCE(p_opponent_ability.damage_dot_config_amount, 0) END);
            v_player.damage_dot_expires := v_round_no + 2 * p_opponent_ability.damage_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('damage_dot_granted', true);
          END IF;
          IF p_opponent_ability.leech_dot_config_turns IS NOT NULL THEN
            v_player.leech_dot_amount := GREATEST(1, CASE
              WHEN p_opponent_ability.leech_dot_config_type = 'percent_max_hp'
                THEN floor(v_player.max_hp * COALESCE(p_opponent_ability.leech_dot_config_percent, 0) / 100.0)::integer
              ELSE COALESCE(p_opponent_ability.leech_dot_config_amount, 0) END);
            v_player.leech_dot_expires := v_round_no + 2 * p_opponent_ability.leech_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('leech_dot_granted', true);
          END IF;
          IF p_opponent_ability.status_dot_config_turns IS NOT NULL THEN
            v_player.status_dot_status := p_opponent_ability.status_dot_config_status;
            v_player.status_dot_chance := p_opponent_ability.status_dot_config_chance;
            v_player.status_dot_expires := v_round_no + 2 * p_opponent_ability.status_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('status_dot_granted', true);
          END IF;
          IF p_opponent_ability.pierce_immunity_type IS NOT NULL AND p_opponent_ability.pierce_immunity_turns IS NOT NULL THEN
            v_opponent.pierce_immunity_type := p_opponent_ability.pierce_immunity_type;
            v_opponent.pierce_immunity_expires := v_round_no + 2 * p_opponent_ability.pierce_immunity_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('pierce_immunity_granted', true);
          END IF;
          IF COALESCE(p_opponent_ability.clear_damage_dot, false)
             AND (v_opponent.damage_dot_amount IS NOT NULL OR v_opponent.leech_dot_amount IS NOT NULL
                  OR v_opponent.status_dot_status IS NOT NULL) THEN
            v_opponent.damage_dot_amount := NULL; v_opponent.damage_dot_expires := NULL;
            v_opponent.leech_dot_amount := NULL; v_opponent.leech_dot_expires := NULL;
            v_opponent.status_dot_status := NULL; v_opponent.status_dot_chance := NULL; v_opponent.status_dot_expires := NULL;
            v_turn_entry := v_turn_entry || jsonb_build_object('cleanse_dot', true);
          END IF;
          IF COALESCE(p_opponent_ability.cure_status, false) AND v_opponent.status IS NOT NULL THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('cleanse_status', v_opponent.status);
            v_opponent.status := NULL;
          END IF;
          IF COALESCE(p_opponent_ability.clear_weather, false) AND v_weather IS NOT NULL THEN
            v_talent_pending := COALESCE(v_talent_pending, '[]'::jsonb) || jsonb_build_array(
              autobattle_weather_turn(v_turn_no, 'opponent', v_opponent.hp, v_weather,
                jsonb_build_object('weather_cleared', true)));
            v_weather := NULL;
          END IF;
          IF p_opponent_ability.invuln_grant AND p_opponent_ability.turn_effect IS DISTINCT FROM 'prepare_release' THEN
            v_opponent.invulnerable := true;
            v_opponent.invuln_granted_round := v_round_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          IF p_opponent_ability.recoil_type IS NOT NULL AND NOT autobattle_talent_has_kind(p_opponent_talents, 'no_recoil') THEN
            v_recoil_amt := CASE WHEN p_opponent_ability.recoil_type = 'range'
              THEN p_opponent_ability.recoil_min + floor(random() * (p_opponent_ability.recoil_max - p_opponent_ability.recoil_min + 1))::integer
              ELSE floor(v_hit_damage * COALESCE(p_opponent_ability.recoil_percent, 0) / 100.0)::integer END;
            IF v_recoil_amt > 0 THEN
              v_opponent.hp := v_opponent.hp - v_recoil_amt;
              -- Le contre-coup peut tuer son auteur : mêmes talents de survie.
              v_talent_res := autobattle_talent_survive(p_opponent_talents, v_opponent.talent_state, 'opponent', v_opponent.hp, v_opponent.max_hp, v_turn_no, v_opponent.status);
              v_opponent.hp := (v_talent_res ->> 'hp')::integer;
              v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
              v_opponent.talent_state := v_talent_res -> 'state';
              -- Un soin de talent guérit le poison, comme tout autre soin.
              v_opponent.status := v_talent_res ->> 'status';
              v_talent_pending := v_talent_pending || (v_talent_res -> 'turns');
              v_turn_entry := v_turn_entry || jsonb_build_object('recoil', v_recoil_amt, 'attacker_hp_after', v_opponent.hp);
            END IF;
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry) || COALESCE(v_talent_pending, '[]'::jsonb);

          IF v_player.hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_opponent.hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
        END IF;
      END IF;
    END IF;

    v_block_remaining := v_block_remaining - 1;
    IF v_block_remaining = 0 THEN
      -- Action supplémentaire due à ce camp ('charge_double_next' libéré ou
      -- 'first_and_replay') : le round S'ARRÊTE ICI et ce camp reprendra la
      -- main en tout premier au round suivant. C'est ce qui donne deux
      -- actions consécutives avec DEUX CAPACITÉS DIFFÉRENTES : le round
      -- suivant est un nouvel appel RPC, où le joueur choisit à nouveau et où
      -- l'adversaire avance d'un cran dans sa séquence configurée (rejouer
      -- ici, dans le même round, condamnerait les deux camps à répéter la
      -- capacité en cours).
      -- Cas particulier : si le camp qui doit rejouer a ouvert le round,
      -- l'AUTRE n'a pas encore agi et sa capacité n'a donc pas servi — les
      -- appelants la réimposent au round suivant (player_forced_ability_nom)
      -- plutôt que de la perdre, voir autobattle_resolve_manual_round.
      IF v_attacker = 'player' AND v_player_owed THEN
        v_player_owed := false;
        v_next_first := 'player';
        EXIT;
      ELSIF v_attacker = 'opponent' AND v_opponent_owed THEN
        v_opponent_owed := false;
        v_next_first := 'opponent';
        EXIT;
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
  -- Météo à persister par l'appelant (colonne weather_id de sa table de combat).
  v_result.weather_id := autobattle_weather_id(v_weather);
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION autobattle_resolve_round_core(integer, integer, text, autobattle_combatant_state, autobattle_combatant_state, autobattle_combatant_ability, autobattle_combatant_ability, boolean, jsonb, jsonb, bigint, boolean, text, text, numeric, numeric) TO anon, authenticated;


-- autobattle_resolve_battle ------------------------------------------------------------------
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
  -- Immunités de type (voir type_no_effect) : recalculées à chaque tour, un
  -- perce-immunité (pierce_immunity_*) pouvant les lever en cours de combat —
  -- seuls les TYPES d'espèce affrontés, eux, sont figés (les deux camps gardent
  -- la même capacité et la même espèce d'un bout à l'autre en mode Auto).
  v_player_type_immune   boolean;
  v_opponent_type_immune boolean;
  -- Type d'espèce que la capacité de chaque camp affronte (Métamorph compris).
  v_player_target_type   text;
  v_opponent_target_type text;
  -- Poids des deux espèces (pokemon.poids) pour la condition de dégâts
  -- additionnels 'weight_ratio' — voir autobattle_weight_condition.
  v_player_weight        numeric;
  v_opponent_weight      numeric;
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
  v_talents_enabled     boolean;
  -- Météo (voir autobattle_weathers) : bascule globale, météo en cours pour tout
  -- le combat, retour du dernier helper de phase, et numéro du tour où le
  -- dernier tick a eu lieu.
  v_weather_enabled     boolean;
  v_weather             jsonb;
  v_weather_res         jsonb;
  v_weather_side        text;
  v_weather_last_tick_round integer;
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
  -- deux camps peuvent avoir des modificateurs actifs simultanément sur des
  -- stats différentes. Les applications s'EMPILENT (voir autobattle_mod_total)
  -- avec chacune son échéance en numéro de round (999999 = jusqu'à la fin du
  -- combat, très au-delà du plafond de 200 tours).
  v_player_stat_mod_target       text;
  v_player_stat_mod_direction    text;
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
  v_opponent_stat_mod_direction    text;
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
  -- Piles de modificateurs actifs (voir autobattle_mod_total) : chaque
  -- application s'ajoute aux précédentes avec sa propre échéance, au lieu de
  -- les écraser.
  v_player_damage_mods           jsonb := '[]'::jsonb;
  v_player_precision_mods        jsonb := '[]'::jsonb;
  v_opponent_damage_mods         jsonb := '[]'::jsonb;
  v_opponent_precision_mods      jsonb := '[]'::jsonb;
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
  v_player_percent_hp_damage_basis     text;
  v_opponent_percent_hp_damage_basis   text;
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
  v_player_prevention_duration     integer;
  v_opponent_prevention_duration   integer;
  v_player_prevention_expires      integer;
  v_opponent_prevention_expires    integer;
  v_player_keep_going_turns        integer;
  v_player_keep_going_until_fail  boolean;
  v_player_keep_going_bonus_type   text;
  v_player_keep_going_bonus_flat   integer;
  v_player_keep_going_bonus_percent integer;
  v_opponent_keep_going_turns      integer;
  v_opponent_keep_going_until_fail  boolean;
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
  -- Effets persistants OFFENSIFS (voir autobattle_ability_rules.damage_dot_* /
  -- leech_dot_*) : config de la capacité de chaque camp d'un côté, effet
  -- SUBI par chaque camp de l'autre — un camp pose l'effet sur l'autre, d'où
  -- les deux jeux de variables (le _config_ du joueur alimente le _amount_ de
  -- l'adversaire, et réciproquement).
  v_player_damage_dot_config_amount    integer;
  v_player_damage_dot_config_turns     integer;
  v_player_damage_dot_config_type      text;
  v_player_damage_dot_config_percent   integer;
  v_opponent_damage_dot_config_amount  integer;
  v_opponent_damage_dot_config_turns   integer;
  v_opponent_damage_dot_config_type    text;
  v_opponent_damage_dot_config_percent integer;
  v_player_leech_dot_config_amount     integer;
  v_player_leech_dot_config_turns      integer;
  v_player_leech_dot_config_type       text;
  v_player_leech_dot_config_percent    integer;
  v_opponent_leech_dot_config_amount   integer;
  v_opponent_leech_dot_config_turns    integer;
  v_opponent_leech_dot_config_type     text;
  v_opponent_leech_dot_config_percent  integer;
  v_player_damage_dot_amount    integer;
  v_player_damage_dot_expires   integer;
  v_opponent_damage_dot_amount  integer;
  v_opponent_damage_dot_expires integer;
  v_player_leech_dot_amount     integer;
  v_player_leech_dot_expires    integer;
  v_opponent_leech_dot_amount   integer;
  v_opponent_leech_dot_expires  integer;
  -- Tentative de statut persistante (voir status_dot_*) : config de la
  -- capacité de chaque camp, puis effet SUBI par chaque camp.
  v_player_status_dot_config_status    text;
  v_player_status_dot_config_chance    integer;
  v_player_status_dot_config_turns     integer;
  v_opponent_status_dot_config_status  text;
  v_opponent_status_dot_config_chance  integer;
  v_opponent_status_dot_config_turns   integer;
  v_player_status_dot_status    text;
  v_player_status_dot_chance    integer;
  v_player_status_dot_expires   integer;
  v_opponent_status_dot_status  text;
  v_opponent_status_dot_chance  integer;
  v_opponent_status_dot_expires integer;
  -- Perce-immunité (voir autobattle_ability_rules.pierce_immunity_*) : config
  -- de la capacité, puis effet actif accordé à son lanceur.
  v_player_pierce_immunity_config_type    text;
  v_player_pierce_immunity_config_turns   integer;
  v_opponent_pierce_immunity_config_type  text;
  v_opponent_pierce_immunity_config_turns integer;
  v_player_pierce_immunity_type      text;
  v_player_pierce_immunity_expires   integer;
  v_opponent_pierce_immunity_type    text;
  v_opponent_pierce_immunity_expires integer;
  -- Statut exigé sur la cible (voir requires_target_status) et réglages de la
  -- condition de dégâts additionnels 'weight_ratio'.
  v_player_requires_target_status   text;
  v_opponent_requires_target_status text;
  v_player_bonus_weight_target      text;
  v_player_bonus_weight_comparison  text;
  v_player_bonus_weight_percent     integer;
  v_opponent_bonus_weight_target     text;
  v_opponent_bonus_weight_comparison text;
  v_opponent_bonus_weight_percent    integer;
  -- Purges de la capacité de chaque camp (voir clear_damage_dot/clear_weather/
  -- cure_status).
  v_player_clear_damage_dot     boolean;
  v_player_clear_weather        boolean;
  v_player_cure_status          boolean;
  v_opponent_clear_damage_dot   boolean;
  v_opponent_clear_weather      boolean;
  v_opponent_cure_status        boolean;
  -- Retour d'un tick d'effet persistant offensif (voir autobattle_dot_tick).
  v_dot_res jsonb;
  -- Échec automatique faute du statut exigé sur la cible (voir plus bas).
  v_status_req_failed boolean;
  -- Météo déclenchée par la capacité, et condition « météo en cours » de son
  -- modificateur de stat (voir autobattle_ability_rules.weather_id).
  v_player_weather_id              bigint;
  v_opponent_weather_id            bigint;
  v_player_weather_chance          integer;
  v_opponent_weather_chance        integer;
  v_player_stat_mod_weather_condition   text;
  v_opponent_stat_mod_weather_condition text;
  v_player_stat_mod_weather_id     bigint;
  v_opponent_stat_mod_weather_id   bigint;
  v_player_double_turn_pending     boolean := false;
  v_opponent_double_turn_pending   boolean := false;
  v_ignore_block                   boolean;
  v_damage_mod_applied             integer;
  v_precision_mod_total            integer;
  v_prevention_blocked             boolean;
  v_keep_going_bonus               integer;
  -- Talents d'espèce (voir autobattle_talents) : ce mode résout tout le combat
  -- en un seul appel, donc rien n'est persisté — de simples locals suffisent.
  -- Métamorph ne copie PAS le talent adverse : chaque camp garde le sien, résolu
  -- sur son espèce d'origine.
  v_player_talents                 jsonb := '[]'::jsonb;
  v_opponent_talents               jsonb := '[]'::jsonb;
  v_player_talent_state            jsonb;
  v_opponent_talent_state          jsonb;
  -- Voir les mêmes variables dans autobattle_resolve_round_core.
  v_talent_start                   jsonb;
  v_talent_res                     jsonb;
  v_talent_pending                 jsonb;
  v_talent_heal                    integer := 0;
  v_talent_inflict                 text;
  v_talent_side                    text;
  v_hp_shown                       integer := 0;
  v_tick_damage                    integer := 0;
  v_talent_dice_bonus              integer := 0;
  v_talent_dice_turns              jsonb := '[]'::jsonb;
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

  -- Talents d'espèce des deux camps (voir autobattle_talents). Résolus ICI, en
  -- amont de tout le reste, parce que le talent 'transform' conditionne la
  -- copie de l'adversaire juste en dessous. Résolus sur l'espèce PROPRE de
  -- chaque camp : un transformé copie visuel/type/dégâts, jamais le talent.
  -- _vs et non _for : le talent 'cancel_talents' d'un camp vide les deux listes
  -- (voir autobattle_talents_effective), y compris avant la copie 'transform'.
  SELECT talents_enabled INTO v_talents_enabled FROM autobattle_config WHERE id = 1;
  v_talents_enabled := COALESCE(v_talents_enabled, true);
  v_player_talents := autobattle_talents_vs(v_pp.pokemon_nom, v_level.opponent_pokemon_nom, v_talents_enabled);
  v_opponent_talents := autobattle_talents_vs(v_level.opponent_pokemon_nom, v_pp.pokemon_nom, v_talents_enabled);
  -- Bascule globale de la météo (voir autobattle_config.weather_enabled). Aucun
  -- combat ne DÉMARRE avec une météo : elle ne peut être levée que par un talent
  -- ou une capacité, et rien n'est conservé d'un combat à l'autre.
  SELECT weather_enabled INTO v_weather_enabled FROM autobattle_config WHERE id = 1;
  v_weather_enabled := COALESCE(v_weather_enabled, true);

  -- Talent 'transform' (anciennement le cas spécial « Métamorph ») : copie le
  -- visuel/les dégâts/la capacité/le type de l'ADVERSAIRE pour tout le combat,
  -- jamais ses PV — dans UN SENS COMME DANS L'AUTRE (le porteur peut être le
  -- pokémon du joueur OU celui configuré comme adversaire d'un niveau).
  -- v_player_max_hp/v_level.opponent_hp restent toujours calculés sur les
  -- VRAIES stats du camp transformé, jamais copiés.
  v_is_metamorph := autobattle_talent_has_kind(v_player_talents, 'transform');
  v_is_opponent_metamorph := autobattle_talent_has_kind(v_opponent_talents, 'transform');
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
  -- Super efficace : TYPE DE LA CAPACITÉ jouée vs TYPE DU DÉFENSEUR (voir
  -- type_super_effective) — plus les colonnes super_efficace_1..4 de l'espèce
  -- attaquante, et plus de condition « la capacité doit être du type de son
  -- lanceur » : n'importe quelle capacité apprise profite du x2 si son propre
  -- type est avantageux (requirement). Métamorph ne change donc plus rien ici
  -- côté attaquant (la capacité copiée porte déjà son type), seulement le type
  -- d'espèce du DÉFENSEUR le cas échéant.
  v_player_type_bonus := type_super_effective(
    v_ability.type,
    CASE WHEN v_is_opponent_metamorph THEN v_player_species.type ELSE v_opponent_species.type END
  );
  -- Immunité de type : la capacité ne peut rien faire à ce défenseur (voir
  -- type_no_effect) — traitée plus bas comme un raté « aucun effet », mais
  -- seulement si elle vise réellement l'adversaire. Seul le TYPE affronté est
  -- figé ici ; l'immunité elle-même est réévaluée à chaque tour dans la boucle
  -- (un perce-immunité peut la lever, voir autobattle_type_immune).
  v_player_target_type := CASE WHEN v_is_opponent_metamorph THEN v_player_species.type ELSE v_opponent_species.type END;
  -- Poids des deux espèces : Métamorph copie le sprite, le type et les dégâts,
  -- jamais le poids — chacun garde le sien.
  v_player_weight := v_player_species.poids;
  v_opponent_weight := v_opponent_species.poids;
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

  -- Même règle côté adverse (type de SA capacité vs type du joueur).
  v_opponent_type_bonus := type_super_effective(
    v_opponent_ability.type,
    CASE WHEN v_is_metamorph THEN v_opponent_species.type ELSE v_player_species.type END
  );
  v_opponent_target_type := CASE WHEN v_is_metamorph THEN v_opponent_species.type ELSE v_player_species.type END;
  v_opponent_damage_species_xp := COALESCE(v_opponent_base_damage_component, 0);
  v_opponent_damage := v_opponent_damage_species_xp * (CASE WHEN v_opponent_type_bonus THEN 2 ELSE 1 END)
    + COALESCE(v_opponent_ability.degats_base, 0);
  -- Référence fixe pour tout le combat, utilisée par stat_mod_value_type =
  -- 'percent' (voir autobattle_ability_rules.stat_mod_percent) — jamais
  -- recalculée même si v_player_damage/v_opponent_damage venaient à changer
  -- (ce qui n'arrive pas : seuls les modificateurs empilés changent le montant
  -- final PAR COUP, la base elle-même reste constante).
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
         stat_mod_target, stat_mod_direction, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block,
         weather_id, weather_chance, stat_mod_weather_condition, stat_mod_weather_id
    INTO v_player_heal_type, v_player_heal_amount, v_player_heal_percent, v_player_turn_effect, v_player_repeat_max, v_player_status_reversed,
         v_player_recoil_type, v_player_recoil_min, v_player_recoil_max, v_player_recoil_percent, v_player_invuln_grant,
         v_player_bonus_type, v_player_bonus_multiplier, v_player_bonus_flat, v_player_bonus_min, v_player_bonus_max,
         v_player_bonus_condition, v_player_bonus_dice_value, v_player_bonus_status_filter,
         v_player_stat_mod_target, v_player_stat_mod_direction, v_player_stat_mod_stat, v_player_stat_mod_value_type, v_player_stat_mod_flat, v_player_stat_mod_min, v_player_stat_mod_max, v_player_stat_mod_percent,
         v_player_stat_mod_duration_type, v_player_stat_mod_duration_turns, v_player_stat_mod_max_uses,
         v_player_heal_dot_config_amount, v_player_heal_dot_config_turns, v_player_heal_dot_config_type, v_player_heal_dot_config_percent, v_player_cancel_heal_duration, v_player_percent_hp_damage_percent,
         v_player_stat_mod_type_filter, v_player_prevention_duration,
         v_player_keep_going_turns, v_player_keep_going_until_fail, v_player_keep_going_bonus_type, v_player_keep_going_bonus_flat, v_player_keep_going_bonus_percent,
         v_player_heal_dot_config_until_awake, v_player_ignore_status_block,
         v_player_weather_id, v_player_weather_chance,
         v_player_stat_mod_weather_condition, v_player_stat_mod_weather_id
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_ability_nom;
  -- Effets ajoutés en dernier (dégâts/vol de vie persistants, perce-immunité,
  -- statut exigé, condition de poids) : lus à part pour ne pas rallonger
  -- encore la liste ci-dessus, même ligne de règle.
  SELECT damage_dot_amount, damage_dot_duration_turns, damage_dot_type, damage_dot_percent,
         leech_dot_amount, leech_dot_duration_turns, leech_dot_type, leech_dot_percent,
         pierce_immunity_type, pierce_immunity_turns, requires_target_status,
         bonus_damage_weight_target, bonus_damage_weight_comparison, bonus_damage_weight_percent,
         clear_damage_dot, clear_weather, cure_status,
         status_dot_status, status_dot_chance, status_dot_duration_turns, percent_hp_damage_basis
    INTO v_player_damage_dot_config_amount, v_player_damage_dot_config_turns, v_player_damage_dot_config_type, v_player_damage_dot_config_percent,
         v_player_leech_dot_config_amount, v_player_leech_dot_config_turns, v_player_leech_dot_config_type, v_player_leech_dot_config_percent,
         v_player_pierce_immunity_config_type, v_player_pierce_immunity_config_turns, v_player_requires_target_status,
         v_player_bonus_weight_target, v_player_bonus_weight_comparison, v_player_bonus_weight_percent,
         v_player_clear_damage_dot, v_player_clear_weather, v_player_cure_status,
         v_player_status_dot_config_status, v_player_status_dot_config_chance, v_player_status_dot_config_turns,
         v_player_percent_hp_damage_basis
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_ability_nom;
  v_player_clear_damage_dot := COALESCE(v_player_clear_damage_dot, false);
  v_player_clear_weather := COALESCE(v_player_clear_weather, false);
  v_player_cure_status := COALESCE(v_player_cure_status, false);
  v_player_status_reversed := COALESCE(v_player_status_reversed, false);
  v_player_invuln_grant := COALESCE(v_player_invuln_grant, false);
  v_player_heal_dot_config_until_awake := COALESCE(v_player_heal_dot_config_until_awake, false);
  v_player_keep_going_until_fail := COALESCE(v_player_keep_going_until_fail, false);

  SELECT heal_type, heal_amount, heal_percent, turn_effect, repeat_max_iterations, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_direction, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block,
         weather_id, weather_chance, stat_mod_weather_condition, stat_mod_weather_id
    INTO v_opponent_heal_type, v_opponent_heal_amount, v_opponent_heal_percent, v_opponent_turn_effect, v_opponent_repeat_max, v_opponent_status_reversed,
         v_opponent_recoil_type, v_opponent_recoil_min, v_opponent_recoil_max, v_opponent_recoil_percent, v_opponent_invuln_grant,
         v_opponent_bonus_type, v_opponent_bonus_multiplier, v_opponent_bonus_flat, v_opponent_bonus_min, v_opponent_bonus_max,
         v_opponent_bonus_condition, v_opponent_bonus_dice_value, v_opponent_bonus_status_filter,
         v_opponent_stat_mod_target, v_opponent_stat_mod_direction, v_opponent_stat_mod_stat, v_opponent_stat_mod_value_type, v_opponent_stat_mod_flat, v_opponent_stat_mod_min, v_opponent_stat_mod_max, v_opponent_stat_mod_percent,
         v_opponent_stat_mod_duration_type, v_opponent_stat_mod_duration_turns, v_opponent_stat_mod_max_uses,
         v_opponent_heal_dot_config_amount, v_opponent_heal_dot_config_turns, v_opponent_heal_dot_config_type, v_opponent_heal_dot_config_percent, v_opponent_cancel_heal_duration, v_opponent_percent_hp_damage_percent,
         v_opponent_stat_mod_type_filter, v_opponent_prevention_duration,
         v_opponent_keep_going_turns, v_opponent_keep_going_until_fail, v_opponent_keep_going_bonus_type, v_opponent_keep_going_bonus_flat, v_opponent_keep_going_bonus_percent,
         v_opponent_heal_dot_config_until_awake, v_opponent_ignore_status_block,
         v_opponent_weather_id, v_opponent_weather_chance,
         v_opponent_stat_mod_weather_condition, v_opponent_stat_mod_weather_id
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_opponent_ability_nom;
  -- Voir le même complément côté joueur juste au-dessus.
  SELECT damage_dot_amount, damage_dot_duration_turns, damage_dot_type, damage_dot_percent,
         leech_dot_amount, leech_dot_duration_turns, leech_dot_type, leech_dot_percent,
         pierce_immunity_type, pierce_immunity_turns, requires_target_status,
         bonus_damage_weight_target, bonus_damage_weight_comparison, bonus_damage_weight_percent,
         clear_damage_dot, clear_weather, cure_status,
         status_dot_status, status_dot_chance, status_dot_duration_turns, percent_hp_damage_basis
    INTO v_opponent_damage_dot_config_amount, v_opponent_damage_dot_config_turns, v_opponent_damage_dot_config_type, v_opponent_damage_dot_config_percent,
         v_opponent_leech_dot_config_amount, v_opponent_leech_dot_config_turns, v_opponent_leech_dot_config_type, v_opponent_leech_dot_config_percent,
         v_opponent_pierce_immunity_config_type, v_opponent_pierce_immunity_config_turns, v_opponent_requires_target_status,
         v_opponent_bonus_weight_target, v_opponent_bonus_weight_comparison, v_opponent_bonus_weight_percent,
         v_opponent_clear_damage_dot, v_opponent_clear_weather, v_opponent_cure_status,
         v_opponent_status_dot_config_status, v_opponent_status_dot_config_chance, v_opponent_status_dot_config_turns,
         v_opponent_percent_hp_damage_basis
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_opponent_ability_nom;
  v_opponent_clear_damage_dot := COALESCE(v_opponent_clear_damage_dot, false);
  v_opponent_clear_weather := COALESCE(v_opponent_clear_weather, false);
  v_opponent_cure_status := COALESCE(v_opponent_cure_status, false);
  v_opponent_status_reversed := COALESCE(v_opponent_status_reversed, false);
  v_opponent_invuln_grant := COALESCE(v_opponent_invuln_grant, false);
  v_opponent_heal_dot_config_until_awake := COALESCE(v_opponent_heal_dot_config_until_awake, false);
  v_opponent_keep_going_until_fail := COALESCE(v_opponent_keep_going_until_fail, false);

  -- Précision "aucune" (NULL ou 0, case vide/"0" dans le CSV) = capacité qui
  -- ne peut JAMAIS rater, immunisée contre peur/confusion ET contre le
  -- désactivateur global précision_enabled — distinct d'une précision
  -- explicite de 10 (100% par défaut mais toujours réductible par un statut).
  v_player_never_miss := v_ability.precision IS NULL OR v_ability.precision = 0;
  v_opponent_never_miss := v_opponent_ability.precision IS NULL OR v_opponent_ability.precision = 0;

  -- Système de précision (requirement : attacks.precision 1-10, NULL = 10 =
  -- 100%, désactivable globalement via autobattle_config.precision_enabled,
  -- auquel cas toute capacité touche systématiquement).
  -- talents_enabled a déjà été lu plus haut (le talent 'transform' devait être
  -- connu avant la copie de l'adversaire).
  SELECT precision_enabled INTO v_precision_enabled FROM autobattle_config WHERE id = 1;
  v_precision_enabled := COALESCE(v_precision_enabled, true);

  v_player_hp := GREATEST(1, v_player_max_hp);
  v_opponent_hp := v_level.opponent_hp;

  v_coin_player_first := random() < 0.5;
  -- Talent 'priority' : la priorité la plus haute joue en premier, quel que soit
  -- le tirage. À égalité (cas courant : 0 partout), le tirage tranche.
  IF autobattle_talent_priority(v_player_talents) <> autobattle_talent_priority(v_opponent_talents) THEN
    v_coin_player_first := autobattle_talent_priority(v_player_talents) > autobattle_talent_priority(v_opponent_talents);
  END IF;
  -- "Passe premier et rejoue" : en mode Auto la capacité est la même à chaque
  -- tour et l'ordre est une stricte alternance — le seul moment où "passer
  -- premier" veut encore dire quelque chose est le tirage d'ouverture, que
  -- l'effet remporte donc d'office (si les deux camps l'ont, le tirage
  -- tranche normalement). v_coin_player_first est mis à jour avec, pour que
  -- l'animation de pile ou face montrée au joueur reste cohérente.
  IF v_player_turn_effect = 'first_and_replay' AND v_opponent_turn_effect IS DISTINCT FROM 'first_and_replay' THEN
    v_coin_player_first := true;
  ELSIF v_opponent_turn_effect = 'first_and_replay' AND v_player_turn_effect IS DISTINCT FROM 'first_and_replay' THEN
    v_coin_player_first := false;
  END IF;
  v_attacker := CASE WHEN v_coin_player_first THEN 'player' ELSE 'opponent' END;
  v_block_remaining := NULL;
  v_player_status := NULL;
  v_opponent_status := NULL;

  -- Talents permanents : annoncés tout de suite, en tête de journal (tour 0) —
  -- donc avant le premier vrai tour.
  v_talent_start := autobattle_talent_open(v_player_talents, 'player', v_player_hp);
  v_turns := v_turns || (v_talent_start -> 'turns');
  v_player_talent_state := v_talent_start -> 'state';
  v_talent_start := autobattle_talent_open(v_opponent_talents, 'opponent', v_opponent_hp);
  v_turns := v_turns || (v_talent_start -> 'turns');
  v_opponent_talent_state := v_talent_start -> 'state';

  -- Talent 'inflict_status' déclenché « à l'entrée en combat », dans l'ordre de
  -- jeu (le premier à agir applique son statut le premier). Comme en cours de
  -- combat, la cible passe par autobattle_talent_status_guard : l'immunité est
  -- déjà gérée dans autobattle_talent_act, mais PAS la guérison automatique du
  -- premier statut ('auto_cure_first_status'), qui doit pouvoir neutraliser
  -- celui-ci aussi — sinon le statut s'applique quand même et le client affiche
  -- un badge que plus rien ne vient retirer (le tour de talent portant
  -- 'talent_inflicted_status' est émis avant que la garde ne se prononce).
  FOREACH v_talent_side IN ARRAY (CASE WHEN v_coin_player_first THEN ARRAY['player', 'opponent'] ELSE ARRAY['opponent', 'player'] END) LOOP
    IF v_talent_side = 'player' THEN
      v_talent_res := autobattle_talent_act(v_player_talents, v_player_talent_state, 'player', 'battle_start', v_ability.type,
        v_player_hp, v_player_max_hp, v_opponent_status, v_player_status, v_opponent_talents, 0, v_weather);
      v_player_talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
      -- Météo levée « à l'entrée en combat » : elle est donc déjà en place au
      -- tout premier tour, tick compris. Le dernier talent à passer son jet
      -- l'emporte (une météo en remplace toujours une autre).
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'player', v_player_hp, 0);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_turns := v_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(v_opponent_talents, v_opponent_talent_state, 'opponent', v_talent_inflict, v_opponent_hp, 0);
        v_opponent_talent_state := v_talent_res -> 'state';
        v_turns := v_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_opponent_status := v_talent_inflict;
        END IF;
      END IF;
    ELSE
      v_talent_res := autobattle_talent_act(v_opponent_talents, v_opponent_talent_state, 'opponent', 'battle_start', v_opponent_ability.type,
        v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_player_talents, 0, v_weather);
      v_opponent_talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
      -- Voir le même commentaire côté joueur.
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'opponent', v_opponent_hp, 0);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_turns := v_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(v_player_talents, v_player_talent_state, 'player', v_talent_inflict, v_player_hp, 0);
        v_player_talent_state := v_talent_res -> 'state';
        v_turns := v_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_player_status := v_talent_inflict;
        END IF;
      END IF;
    END IF;
  END LOOP;
  v_talent_inflict := NULL;

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

    -- ── Météo : tout premier événement du tour ────────────────────────────
    -- Un TOUR DE COMBAT vaut DEUX activations ici (chaque camp joue la sienne,
    -- et v_round_no avance à chacune — c'est le même « ×2 » que les durées de
    -- modificateurs plus bas). La météo, elle, ne tique qu'une fois par tour de
    -- combat, pour les DEUX pokémon : d'où le compteur v_weather_last_tick_
    -- round plutôt qu'un simple test sur v_block_remaining. Insensible aux
    -- rafales (v_round_no n'y bouge pas) comme aux tours passés.
    -- L'ordre entre les deux camps suit celui du tour en cours.
    IF v_weather IS NOT NULL AND v_block_remaining IS NULL
       AND (v_weather_last_tick_round IS NULL OR v_round_no >= v_weather_last_tick_round + 2) THEN
      v_weather_last_tick_round := v_round_no;
      FOREACH v_weather_side IN ARRAY (CASE WHEN v_attacker = 'player' THEN ARRAY['player', 'opponent'] ELSE ARRAY['opponent', 'player'] END) LOOP
        IF v_weather_side = 'player' THEN
          v_weather_res := autobattle_weather_tick(
            v_weather, 'player', CASE WHEN v_is_metamorph THEN v_opponent_species.type ELSE v_player_species.type END,
            v_player_hp, v_player_max_hp, v_player_status, v_player_talents, v_player_talent_state, v_turn_no);
          v_player_hp := (v_weather_res ->> 'hp')::integer;
          v_player_status := v_weather_res ->> 'status';
          v_player_talent_state := v_weather_res -> 'state';
          v_turns := v_turns || (v_weather_res -> 'turns');
        ELSE
          v_weather_res := autobattle_weather_tick(
            v_weather, 'opponent', CASE WHEN v_is_opponent_metamorph THEN v_player_species.type ELSE v_opponent_species.type END,
            v_opponent_hp, v_level.opponent_hp, v_opponent_status, v_opponent_talents, v_opponent_talent_state, v_turn_no);
          v_opponent_hp := (v_weather_res ->> 'hp')::integer;
          v_opponent_status := v_weather_res ->> 'status';
          v_opponent_talent_state := v_weather_res -> 'state';
          v_turns := v_turns || (v_weather_res -> 'turns');
        END IF;
      END LOOP;
      -- La météo peut tuer avant que le tour n'ait commencé.
      IF v_player_hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
      IF v_opponent_hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
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
    v_player_damage_mods := autobattle_mod_purge(v_player_damage_mods, v_round_no);
    v_player_precision_mods := autobattle_mod_purge(v_player_precision_mods, v_round_no);
    v_opponent_damage_mods := autobattle_mod_purge(v_opponent_damage_mods, v_round_no);
    v_opponent_precision_mods := autobattle_mod_purge(v_opponent_precision_mods, v_round_no);
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
    -- Effets persistants OFFENSIFS subis et perce-immunité accordé : mêmes
    -- échéances par numéro de round que le soin passif — voir le moteur
    -- partagé autobattle_resolve_round_core.
    IF v_player_damage_dot_expires IS NOT NULL AND v_round_no > v_player_damage_dot_expires THEN
      v_player_damage_dot_amount := NULL; v_player_damage_dot_expires := NULL;
    END IF;
    IF v_opponent_damage_dot_expires IS NOT NULL AND v_round_no > v_opponent_damage_dot_expires THEN
      v_opponent_damage_dot_amount := NULL; v_opponent_damage_dot_expires := NULL;
    END IF;
    IF v_player_leech_dot_expires IS NOT NULL AND v_round_no > v_player_leech_dot_expires THEN
      v_player_leech_dot_amount := NULL; v_player_leech_dot_expires := NULL;
    END IF;
    IF v_opponent_leech_dot_expires IS NOT NULL AND v_round_no > v_opponent_leech_dot_expires THEN
      v_opponent_leech_dot_amount := NULL; v_opponent_leech_dot_expires := NULL;
    END IF;
    IF v_player_status_dot_expires IS NOT NULL AND v_round_no > v_player_status_dot_expires THEN
      v_player_status_dot_status := NULL; v_player_status_dot_chance := NULL; v_player_status_dot_expires := NULL;
    END IF;
    IF v_opponent_status_dot_expires IS NOT NULL AND v_round_no > v_opponent_status_dot_expires THEN
      v_opponent_status_dot_status := NULL; v_opponent_status_dot_chance := NULL; v_opponent_status_dot_expires := NULL;
    END IF;
    IF v_player_pierce_immunity_expires IS NOT NULL AND v_round_no > v_player_pierce_immunity_expires THEN
      v_player_pierce_immunity_type := NULL; v_player_pierce_immunity_expires := NULL;
    END IF;
    IF v_opponent_pierce_immunity_expires IS NOT NULL AND v_round_no > v_opponent_pierce_immunity_expires THEN
      v_opponent_pierce_immunity_type := NULL; v_opponent_pierce_immunity_expires := NULL;
    END IF;
    -- Immunité de type effective de CE tour, perce-immunité compris.
    v_player_type_immune := autobattle_type_immune(
      v_ability.type, v_player_target_type,
      v_player_pierce_immunity_config_type, v_player_pierce_immunity_type,
      v_player_pierce_immunity_expires, v_round_no);
    v_opponent_type_immune := autobattle_type_immune(
      v_opponent_ability.type, v_opponent_target_type,
      v_opponent_pierce_immunity_config_type, v_opponent_pierce_immunity_type,
      v_opponent_pierce_immunity_expires, v_round_no);

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
      -- Malus de précision de la Peur/Confusion : posé par le tick ci-dessous,
      -- consommé par le tour que ce camp joue juste après, puis remis à zéro
      -- ici au tour suivant. VOULU : si ce tour-là est un tour passé
      -- (préparation d'une capacité en deux temps, charge, effet 'skip',
      -- rafale tirée à 0), le camp n'attaque pas et le malus est simplement
      -- perdu — le statut, lui, a bien été guéri par son tick. Le client fait
      -- exactement pareil (le badge s'éteint sur ce tour passé, voir
      -- AutoBattleScreen).
      v_status_precision_penalty := 0;
      -- Capacité utilisable malgré UN statut bloquant précis — voir le même
      -- commentaire dans autobattle_resolve_round_core.
      v_ignore_block := COALESCE(
        (CASE WHEN v_attacker = 'player' THEN v_player_ignore_status_block ELSE v_opponent_ignore_status_block END)
          = (CASE WHEN v_attacker = 'player' THEN v_player_status ELSE v_opponent_status END),
        false);

      -- Effets persistants OFFENSIFS subis par le camp qui ouvre son tour
      -- (dégâts par tour, vol de vie par tour) : tout premier événement de son
      -- tour, avant même son tick de statut, une seule fois par tour réel et
      -- qu'il agisse ou non ensuite — voir le même bloc dans le moteur partagé
      -- autobattle_resolve_round_core. Un tick peut mettre K.O.
      IF v_attacker = 'player' AND (v_player_damage_dot_amount IS NOT NULL OR v_player_leech_dot_amount IS NOT NULL) THEN
        v_dot_res := autobattle_dot_tick(
          'player', v_turn_no, v_player_hp, v_player_max_hp, v_opponent_hp, v_level.opponent_hp,
          v_player_status, v_opponent_status, v_player_damage_dot_amount, v_player_leech_dot_amount,
          v_player_talents, v_player_talent_state,
          v_opponent_heal_disabled_expires IS NOT NULL AND v_round_no <= v_opponent_heal_disabled_expires);
        v_player_hp := (v_dot_res ->> 'hp')::integer;
        v_opponent_hp := (v_dot_res ->> 'other_hp')::integer;
        v_player_status := v_dot_res ->> 'status';
        v_opponent_status := v_dot_res ->> 'other_status';
        v_player_talent_state := v_dot_res -> 'state';
        v_turns := v_turns || (v_dot_res -> 'turns');
        -- Comme le tick de soin passif plus bas : ces tours consomment un
        -- numéro de tour sans rendre la main ni changer d'attaquant.
        IF jsonb_array_length(v_dot_res -> 'turns') > 0 THEN v_turn_no := v_turn_no + 1; END IF;
        IF v_player_hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
      ELSIF v_attacker = 'opponent' AND (v_opponent_damage_dot_amount IS NOT NULL OR v_opponent_leech_dot_amount IS NOT NULL) THEN
        v_dot_res := autobattle_dot_tick(
          'opponent', v_turn_no, v_opponent_hp, v_level.opponent_hp, v_player_hp, v_player_max_hp,
          v_opponent_status, v_player_status, v_opponent_damage_dot_amount, v_opponent_leech_dot_amount,
          v_opponent_talents, v_opponent_talent_state,
          v_player_heal_disabled_expires IS NOT NULL AND v_round_no <= v_player_heal_disabled_expires);
        v_opponent_hp := (v_dot_res ->> 'hp')::integer;
        v_player_hp := (v_dot_res ->> 'other_hp')::integer;
        v_opponent_status := v_dot_res ->> 'status';
        v_player_status := v_dot_res ->> 'other_status';
        v_opponent_talent_state := v_dot_res -> 'state';
        v_turns := v_turns || (v_dot_res -> 'turns');
        IF jsonb_array_length(v_dot_res -> 'turns') > 0 THEN v_turn_no := v_turn_no + 1; END IF;
        IF v_opponent_hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
      END IF;

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
            -- Le poison est guéri par N'IMPORTE QUEL soin, celui-ci compris.
            IF v_player_status = 'poison' THEN v_player_status := NULL; END IF;
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_player_heal_dot_amount,
              'attacker_hp_after', v_player_hp, 'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
            ));
          END IF;
          -- Un tour entièrement passé à cause d'un statut bloquant (paralysie,
          -- gel, sommeil) met fin à la chaîne "Continue sur sa lancée" : la
          -- capacité cesse d'être imposée, le tour suivant redevient un choix
          -- libre. Une capacité qui IGNORE ce statut (ignore_status_block) ne
          -- passe pas par ici et poursuit donc sa chaîne normalement.
          v_player_keep_going_remaining := 0;
          v_player_keep_going_count := 0;
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
            -- Le poison est guéri par N'IMPORTE QUEL soin, celui-ci compris.
            IF v_opponent_status = 'poison' THEN v_opponent_status := NULL; END IF;
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_opponent_heal_dot_amount,
              'attacker_hp_after', v_opponent_hp, 'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
            ));
          END IF;
          -- Un tour entièrement passé à cause d'un statut bloquant (paralysie,
          -- gel, sommeil) met fin à la chaîne "Continue sur sa lancée" : la
          -- capacité cesse d'être imposée, le tour suivant redevient un choix
          -- libre. Une capacité qui IGNORE ce statut (ignore_status_block) ne
          -- passe pas par ici et poursuit donc sa chaîne normalement.
          v_opponent_keep_going_remaining := 0;
          v_opponent_keep_going_count := 0;
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
        -- Talent 'heavy_sleeper' (« Somnolent ») : il faut exactement 6 pour
        -- se réveiller, au lieu de 4, 5 ou 6.
        v_status_cured := v_status_roll >= (CASE WHEN autobattle_talent_has_kind(v_player_talents, 'heavy_sleeper') THEN 6 ELSE 4 END);
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
            -- Le poison est guéri par N'IMPORTE QUEL soin, celui-ci compris.
            IF v_player_status = 'poison' THEN v_player_status := NULL; END IF;
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_player_heal_dot_amount,
              'attacker_hp_after', v_player_hp, 'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
            ));
          END IF;
          -- Un tour entièrement passé à cause d'un statut bloquant (paralysie,
          -- gel, sommeil) met fin à la chaîne "Continue sur sa lancée" : la
          -- capacité cesse d'être imposée, le tour suivant redevient un choix
          -- libre. Une capacité qui IGNORE ce statut (ignore_status_block) ne
          -- passe pas par ici et poursuit donc sa chaîne normalement.
          v_player_keep_going_remaining := 0;
          v_player_keep_going_count := 0;
          v_attacker := 'opponent';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_status = 'sleep' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        -- Talent 'heavy_sleeper' (« Somnolent ») : il faut exactement 6 pour
        -- se réveiller, au lieu de 4, 5 ou 6.
        v_status_cured := v_status_roll >= (CASE WHEN autobattle_talent_has_kind(v_opponent_talents, 'heavy_sleeper') THEN 6 ELSE 4 END);
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
            -- Le poison est guéri par N'IMPORTE QUEL soin, celui-ci compris.
            IF v_opponent_status = 'poison' THEN v_opponent_status := NULL; END IF;
            v_turns := v_turns || jsonb_build_array(jsonb_build_object(
              'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
              'heal_dot_tick', true, 'heal', v_opponent_heal_dot_amount,
              'attacker_hp_after', v_opponent_hp, 'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
            ));
          END IF;
          -- Un tour entièrement passé à cause d'un statut bloquant (paralysie,
          -- gel, sommeil) met fin à la chaîne "Continue sur sa lancée" : la
          -- capacité cesse d'être imposée, le tour suivant redevient un choix
          -- libre. Une capacité qui IGNORE ce statut (ignore_status_block) ne
          -- passe pas par ici et poursuit donc sa chaîne normalement.
          v_opponent_keep_going_remaining := 0;
          v_opponent_keep_going_count := 0;
          v_attacker := 'player';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        END IF;

      ELSIF v_attacker = 'player' AND v_player_status = 'burn' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        -- Dégâts du tick, talents 'poison_damage_boost'/'burn_damage_boost'
        -- compris — la MÊME valeur doit alimenter les PV et le journal.
        v_tick_damage := 5 + autobattle_talent_tick_bonus(v_player_talents, v_opponent_talents, 'burn');
        v_player_hp := v_player_hp - v_tick_damage;
        -- Talents : les dégâts passifs peuvent tuer ('endure_ko') et faire passer
        -- sous le seuil de 'heal_below_hp' — évalué AVANT de figer le drapeau 'ko'.
        v_talent_res := autobattle_talent_survive(v_player_talents, v_player_talent_state, 'player', v_player_hp, v_player_max_hp, v_turn_no, v_player_status);
        v_player_hp := (v_talent_res ->> 'hp')::integer;
        v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
        v_player_talent_state := v_talent_res -> 'state';
        -- Un soin de talent guérit le poison, comme tout autre soin.
        v_player_status := v_talent_res ->> 'status';
        v_talent_pending := v_talent_res -> 'turns';
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', v_tick_damage, 'skipped', false,
          'status_tick', true, 'status', 'burn', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'attacker_hp_after', GREATEST(0, v_hp_shown), 'defender_hp_after', GREATEST(0, v_opponent_hp),
          'ko', v_player_hp <= 0
        )) || v_talent_pending;
        IF v_status_cured THEN v_player_status := NULL; END IF;
        IF v_player_hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
        v_turn_no := v_turn_no + 1;
      ELSIF v_attacker = 'opponent' AND v_opponent_status = 'burn' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        -- Dégâts du tick, talents 'poison_damage_boost'/'burn_damage_boost'
        -- compris — la MÊME valeur doit alimenter les PV et le journal.
        v_tick_damage := 5 + autobattle_talent_tick_bonus(v_player_talents, v_opponent_talents, 'burn');
        v_opponent_hp := v_opponent_hp - v_tick_damage;
        -- Talents : les dégâts passifs peuvent tuer ('endure_ko') et faire passer
        -- sous le seuil de 'heal_below_hp' — évalué AVANT de figer le drapeau 'ko'.
        v_talent_res := autobattle_talent_survive(v_opponent_talents, v_opponent_talent_state, 'opponent', v_opponent_hp, v_level.opponent_hp, v_turn_no, v_opponent_status);
        v_opponent_hp := (v_talent_res ->> 'hp')::integer;
        v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
        v_opponent_talent_state := v_talent_res -> 'state';
        -- Un soin de talent guérit le poison, comme tout autre soin.
        v_opponent_status := v_talent_res ->> 'status';
        v_talent_pending := v_talent_res -> 'turns';
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', v_tick_damage, 'skipped', false,
          'status_tick', true, 'status', 'burn', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'attacker_hp_after', GREATEST(0, v_hp_shown), 'defender_hp_after', GREATEST(0, v_player_hp),
          'ko', v_opponent_hp <= 0
        )) || v_talent_pending;
        IF v_status_cured THEN v_opponent_status := NULL; END IF;
        IF v_opponent_hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
        v_turn_no := v_turn_no + 1;

      ELSIF v_attacker = 'player' AND v_player_status = 'poison' THEN
        -- Dégâts du tick, talents 'poison_damage_boost'/'burn_damage_boost'
        -- compris — la MÊME valeur doit alimenter les PV et le journal.
        v_tick_damage := 3 + autobattle_talent_tick_bonus(v_player_talents, v_opponent_talents, 'poison');
        v_player_hp := v_player_hp - v_tick_damage;
        -- Talents : les dégâts passifs peuvent tuer ('endure_ko') et faire passer
        -- sous le seuil de 'heal_below_hp' — évalué AVANT de figer le drapeau 'ko'.
        v_talent_res := autobattle_talent_survive(v_player_talents, v_player_talent_state, 'player', v_player_hp, v_player_max_hp, v_turn_no, v_player_status);
        v_player_hp := (v_talent_res ->> 'hp')::integer;
        v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
        v_player_talent_state := v_talent_res -> 'state';
        -- Un soin de talent guérit le poison, comme tout autre soin.
        v_player_status := v_talent_res ->> 'status';
        v_talent_pending := v_talent_res -> 'turns';
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', v_tick_damage, 'skipped', false,
          'status_tick', true, 'status', 'poison', 'status_cured', false,
          'attacker_hp_after', GREATEST(0, v_hp_shown), 'defender_hp_after', GREATEST(0, v_opponent_hp),
          'ko', v_player_hp <= 0
        )) || v_talent_pending;
        IF v_player_hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
        v_turn_no := v_turn_no + 1;
      ELSIF v_attacker = 'opponent' AND v_opponent_status = 'poison' THEN
        -- Dégâts du tick, talents 'poison_damage_boost'/'burn_damage_boost'
        -- compris — la MÊME valeur doit alimenter les PV et le journal.
        v_tick_damage := 3 + autobattle_talent_tick_bonus(v_player_talents, v_opponent_talents, 'poison');
        v_opponent_hp := v_opponent_hp - v_tick_damage;
        -- Talents : les dégâts passifs peuvent tuer ('endure_ko') et faire passer
        -- sous le seuil de 'heal_below_hp' — évalué AVANT de figer le drapeau 'ko'.
        v_talent_res := autobattle_talent_survive(v_opponent_talents, v_opponent_talent_state, 'opponent', v_opponent_hp, v_level.opponent_hp, v_turn_no, v_opponent_status);
        v_opponent_hp := (v_talent_res ->> 'hp')::integer;
        v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
        v_opponent_talent_state := v_talent_res -> 'state';
        -- Un soin de talent guérit le poison, comme tout autre soin.
        v_opponent_status := v_talent_res ->> 'status';
        v_talent_pending := v_talent_res -> 'turns';
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', v_tick_damage, 'skipped', false,
          'status_tick', true, 'status', 'poison', 'status_cured', false,
          'attacker_hp_after', GREATEST(0, v_hp_shown), 'defender_hp_after', GREATEST(0, v_player_hp),
          'ko', v_opponent_hp <= 0
        )) || v_talent_pending;
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
        -- Le poison est guéri par N'IMPORTE QUEL soin, celui-ci compris.
        IF v_player_status = 'poison' THEN v_player_status := NULL; END IF;
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
        -- Le poison est guéri par N'IMPORTE QUEL soin, celui-ci compris.
        IF v_opponent_status = 'poison' THEN v_opponent_status := NULL; END IF;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
          'heal_dot_tick', true, 'heal', v_opponent_heal_dot_amount,
          'attacker_hp_after', v_opponent_hp, 'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_opponent_status = 'poison' THEN v_opponent_status := NULL; END IF;
        v_turn_no := v_turn_no + 1;
      END IF;

      -- Tentative de statut persistante subie par le camp qui agit — voir le
      -- même bloc dans le moteur partagé autobattle_resolve_round_core (jet
      -- APRÈS son tick de statut, donc le statut posé ne mord qu'au tour
      -- suivant ; rien n'est tenté s'il en a déjà un).
      IF v_attacker = 'player' AND v_player_status_dot_status IS NOT NULL AND v_player_status IS NULL THEN
        v_dot_res := autobattle_status_dot_tick('player', v_turn_no, v_player_hp, v_player_status,
          v_player_status_dot_status, v_player_status_dot_chance, v_player_talents, v_player_talent_state);
        v_player_status := v_dot_res ->> 'status';
        v_player_talent_state := v_dot_res -> 'state';
        v_turns := v_turns || (v_dot_res -> 'turns');
        IF jsonb_array_length(v_dot_res -> 'turns') > 0 THEN v_turn_no := v_turn_no + 1; END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_status_dot_status IS NOT NULL AND v_opponent_status IS NULL THEN
        v_dot_res := autobattle_status_dot_tick('opponent', v_turn_no, v_opponent_hp, v_opponent_status,
          v_opponent_status_dot_status, v_opponent_status_dot_chance, v_opponent_talents, v_opponent_talent_state);
        v_opponent_status := v_dot_res ->> 'status';
        v_opponent_talent_state := v_dot_res -> 'state';
        v_turns := v_turns || (v_dot_res -> 'turns');
        IF jsonb_array_length(v_dot_res -> 'turns') > 0 THEN v_turn_no := v_turn_no + 1; END IF;
      END IF;

      -- Chaîne "Continue sur sa lancée" (voir autobattle_ability_rules.
      -- keep_going_turns) : en mode Auto la capacité est la même à chaque
      -- tour, le compteur suit donc simplement le nombre d'utilisations
      -- consécutives — bonus cumulatif jusqu'à épuisement de la chaîne, puis
      -- remise à zéro. keep_going_count = numéro de l'utilisation en cours
      -- (1 = pas de bonus).
      -- Mode "N tours" : keep_going_remaining à 0 marque une chaîne épuisée
      -- (ou jamais commencée), la suivante repart de zéro. Mode "jusqu'à
      -- l'échec" : ce compteur ne sert pas, c'est keep_going_count remis à 0
      -- par un raté (voir plus bas) qui signale la fin de la chaîne.
      IF v_attacker = 'player' AND (v_player_keep_going_turns IS NOT NULL OR v_player_keep_going_until_fail) THEN
        IF NOT v_player_keep_going_until_fail AND v_player_keep_going_remaining <= 0 THEN
          v_player_keep_going_count := 1;
          v_player_keep_going_remaining := v_player_keep_going_turns;
        ELSIF v_player_keep_going_until_fail AND v_player_keep_going_count <= 0 THEN
          v_player_keep_going_count := 1;
        ELSE
          v_player_keep_going_count := v_player_keep_going_count + 1;
          IF NOT v_player_keep_going_until_fail THEN
            v_player_keep_going_remaining := v_player_keep_going_remaining - 1;
          END IF;
        END IF;
      ELSIF v_attacker = 'opponent' AND (v_opponent_keep_going_turns IS NOT NULL OR v_opponent_keep_going_until_fail) THEN
        IF NOT v_opponent_keep_going_until_fail AND v_opponent_keep_going_remaining <= 0 THEN
          v_opponent_keep_going_count := 1;
          v_opponent_keep_going_remaining := v_opponent_keep_going_turns;
        ELSIF v_opponent_keep_going_until_fail AND v_opponent_keep_going_count <= 0 THEN
          v_opponent_keep_going_count := 1;
        ELSE
          v_opponent_keep_going_count := v_opponent_keep_going_count + 1;
          IF NOT v_opponent_keep_going_until_fail THEN
            v_opponent_keep_going_remaining := v_opponent_keep_going_remaining - 1;
          END IF;
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
      -- Talents du camp qui agit : annonce des bonus de stat devenus actifs, puis
      -- tentative d'infliger un statut ('inflict_status', déclencheur « à chaque
      -- tour »). Les passifs permanents sont annoncés en tête de combat.
      v_talent_res := autobattle_talent_act(v_player_talents, v_player_talent_state, 'player', 'each_turn', v_ability.type,
        v_player_hp, v_player_max_hp, v_opponent_status, v_player_status, v_opponent_talents, v_turn_no, v_weather);
      v_player_talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
      -- Météo levée en cours de tour : le tick de ce tour est déjà passé, elle
      -- ne s'appliquera donc qu'au tour suivant.
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'player', v_player_hp, v_turn_no);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_turns := v_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      -- Statut infligé par un talent : la cible peut encore le neutraliser
      -- ('status_immunity' est déjà pris en compte, 'auto_cure_first_status' non).
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(v_opponent_talents, v_opponent_talent_state, 'opponent', v_talent_inflict, v_opponent_hp, v_turn_no);
        v_opponent_talent_state := v_talent_res -> 'state';
        v_turns := v_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_opponent_status := v_talent_inflict;
        END IF;
      END IF;

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
      -- Immunité de type (v_player_type_immune, voir type_no_effect) : même
      -- traitement que l'invulnérabilité — raté automatique, et uniquement
      -- pour une capacité qui vise réellement l'adversaire (une capacité
      -- auto-ciblée se résout normalement). Seul le drapeau change, pour que
      -- le client affiche « Aucun effet ! ».
      -- Capacité conditionnée au statut de la CIBLE (voir
      -- autobattle_ability_rules.requires_target_status) : hors condition, elle
      -- échoue, au même endroit et de la même façon que l'invulnérabilité et
      -- l'immunité de type.
      v_status_req_failed := v_player_requires_target_status IS NOT NULL
        AND v_opponent_status IS DISTINCT FROM v_player_requires_target_status;
      IF v_status_req_failed
         OR ((v_opponent_invulnerable OR v_player_type_immune OR autobattle_talent_shield_active(v_opponent_talents, v_opponent_talent_state)) AND (
        v_ability.deals_damage
        OR (v_ability.status_effect IS NOT NULL AND NOT v_player_status_reversed)
        OR v_player_stat_mod_target = 'opponent'
        OR v_player_cancel_heal_duration IS NOT NULL
      )) THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true,
          'invulnerable_miss', NOT v_player_type_immune AND NOT v_status_req_failed,
          'no_effect', v_player_type_immune AND NOT v_status_req_failed,
          'requires_status_failed', v_status_req_failed,
          'requires_status', v_player_requires_target_status,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_player_turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
        -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
        -- cesse d'être imposée, le tour suivant redevient un choix libre.
        IF v_player_keep_going_turns IS NOT NULL OR v_player_keep_going_until_fail THEN
          v_player_keep_going_remaining := 0;
          v_player_keep_going_count := 0;
        END IF;
      ELSE
        v_precision_mod_total := autobattle_mod_total(v_player_precision_mods, v_round_no, v_ability.type)
          + autobattle_talent_stat_bonus(v_player_talents, v_player_talent_state, 'precision', v_ability.type, v_player_hp, v_player_max_hp, v_opponent_status, v_player_status, v_weather)
          -- Buff/debuff de terrain, compté dans le même total (donc visible
          -- dans 'precision_mod_amount' côté client).
          + autobattle_weather_stat_bonus(v_weather, CASE WHEN v_is_metamorph THEN v_opponent_species.type ELSE v_player_species.type END, v_ability.type, 'precision');
        v_missed := (NOT v_player_never_miss) AND
          random() >= ((CASE WHEN v_precision_enabled THEN GREATEST(0, COALESCE(v_ability.precision, 10) - v_status_precision_penalty + v_precision_mod_total) ELSE 10 END * 10) / 100.0);

        IF v_missed THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true,
            'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false,
            'precision_mod_amount', v_precision_mod_total
          ));
          -- 'repeat_until_fail' : le premier raté met fin à la série en
          -- cours, même s'il reste des activations dans v_block_remaining —
          -- on force le passage de tour via la décrémentation générique.
          IF v_player_turn_effect = 'repeat_until_fail' THEN
            v_block_remaining := 1;
          END IF;
          -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
          -- cesse d'être imposée, le tour suivant redevient un choix libre.
          IF v_player_keep_going_turns IS NOT NULL OR v_player_keep_going_until_fail THEN
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
          v_damage_mod_applied := autobattle_mod_total(v_player_damage_mods, v_round_no, v_ability.type)
            + autobattle_talent_stat_bonus(v_player_talents, v_player_talent_state, 'damage', v_ability.type, v_player_hp, v_player_max_hp, v_opponent_status, v_player_status, v_weather)
            + autobattle_weather_stat_bonus(v_weather, CASE WHEN v_is_metamorph THEN v_opponent_species.type ELSE v_player_species.type END, v_ability.type, 'damage');
          -- Bouclier Prévention de la cible : annule les dégâts ADDITIONNELS
          -- dus au bonus super efficace (la composante espèce+XP est comptée
          -- une fois au lieu de deux), le reste du coup est inchangé.
          v_prevention_blocked := v_player_type_bonus
            AND v_opponent_prevention_expires IS NOT NULL AND v_round_no <= v_opponent_prevention_expires;
          v_keep_going_bonus := 0;
          IF v_ability.deals_damage THEN
            v_hit_dice := CASE WHEN v_ability.degats_de IS NOT NULL AND v_ability.degats_de > 0
              THEN 1 + floor(random() * v_ability.degats_de)::integer ELSE 0 END;
            -- Talent 'dice_bonus_damage' : le dé est tombé sur la valeur configurée.
            v_talent_res := autobattle_talent_dice(v_player_talents, v_hit_dice, 'player', v_player_hp, v_turn_no);
            v_talent_dice_bonus := (v_talent_res ->> 'amount')::integer;
            v_talent_dice_turns := v_talent_res -> 'turns';
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
              v_hit_damage := GREATEST(0, floor(
                (CASE WHEN v_player_percent_hp_damage_basis = 'max' THEN v_level.opponent_hp ELSE v_opponent_hp END)
                * v_player_percent_hp_damage_percent / 100.0)::integer);
            END IF;

            -- Dégâts additionnels conditionnels (voir bonus_damage_* et les
            -- conditions possibles) — appliqués après le dé, avant le
            -- contre-coup. 'has_status' regarde le statut de la CIBLE,
            -- 'self_has_status' celui de l'utilisateur de la capacité.
            v_bonus_condition_met := v_player_bonus_condition = 'took_damage_last_turn' AND v_player_took_damage
              OR v_player_bonus_condition = 'first_use' AND NOT v_player_used_ability
              OR v_player_bonus_condition = 'dice_equals' AND v_hit_dice = v_player_bonus_dice_value
              OR v_player_bonus_condition = 'has_status' AND v_opponent_status IS NOT NULL AND (v_player_bonus_status_filter IS NULL OR v_opponent_status = v_player_bonus_status_filter)
              OR v_player_bonus_condition = 'self_has_status' AND v_player_status IS NOT NULL AND (v_player_bonus_status_filter IS NULL OR v_player_status = v_player_bonus_status_filter)
              -- Comparaison des POIDS des deux espèces (voir
              -- autobattle_weight_condition) : « self » = le camp qui attaque.
              OR v_player_bonus_condition = 'weight_ratio' AND autobattle_weight_condition(
                   v_player_bonus_weight_target, v_player_bonus_weight_comparison,
                   v_player_bonus_weight_percent, v_player_weight, v_opponent_weight);
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
            IF (v_player_keep_going_turns IS NOT NULL OR v_player_keep_going_until_fail) AND v_player_keep_going_count > 1 THEN
              v_keep_going_bonus := (v_player_keep_going_count - 1) * (CASE
                WHEN v_player_keep_going_bonus_type = 'percent_damage'
                  THEN floor(v_player_damage_species_xp * COALESCE(v_player_keep_going_bonus_percent, 0) / 100.0)::integer
                ELSE COALESCE(v_player_keep_going_bonus_flat, 0) END);
              v_hit_damage := GREATEST(0, v_hit_damage + v_keep_going_bonus);
            END IF;
            IF v_talent_dice_bonus <> 0 THEN
              v_hit_damage := GREATEST(0, v_hit_damage + v_talent_dice_bonus);
            END IF;
          ELSE
            v_hit_dice := 0;
            v_hit_damage := 0;
            v_percent_hp_damage_applied := false;
            v_talent_dice_bonus := 0;
            v_talent_dice_turns := '[]'::jsonb;
          END IF;
          -- Talent 'inflict_status' déclenché par le TYPE de la capacité jouée :
          -- uniquement sur un COUP DIRECT qui a porté (capacité offensive, non
          -- ratée, dégâts non nuls) — jamais sur une capacité de soutien ni sur
          -- un tick de brûlure/poison, qui ne passent pas par ici.
          IF v_hit_damage > 0 THEN
            v_talent_res := autobattle_talent_act(v_player_talents, v_player_talent_state, 'player', 'on_ability_type', v_ability.type,
              v_player_hp, v_player_max_hp, v_opponent_status, v_player_status, v_opponent_talents, v_turn_no, v_weather);
            v_player_talent_state := v_talent_res -> 'state';
            v_turns := v_turns || (v_talent_res -> 'turns');
            v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'player', v_player_hp, v_turn_no);
            v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
            v_turns := v_turns || (v_weather_res -> 'turns');
            v_talent_inflict := v_talent_res ->> 'inflict_status';
            IF v_talent_inflict IS NOT NULL THEN
              v_talent_res := autobattle_talent_status_guard(v_opponent_talents, v_opponent_talent_state, 'opponent', v_talent_inflict, v_opponent_hp, v_turn_no);
              v_opponent_talent_state := v_talent_res -> 'state';
              v_turns := v_turns || (v_talent_res -> 'turns');
              IF NOT (v_talent_res ->> 'blocked')::boolean THEN
                v_opponent_status := v_talent_inflict;
              END IF;
            END IF;
          END IF;
          -- 'first_and_replay' ne "compte" pas comme une capacité utilisée
          -- (voir autobattle_ability_rules) : la condition de bonus
          -- 'first_use' reste donc vraie pour la vraie attaque qui suit.
          IF v_player_turn_effect IS DISTINCT FROM 'first_and_replay' THEN
            v_player_used_ability := true;
          END IF;

          -- Talents défensifs de la CIBLE : immunité de type, conversion des dégâts en
          -- soin, absorption du premier coup — et comptage du coup encaissé (hits).
          v_talent_res := autobattle_talent_defend(v_opponent_talents, v_opponent_talent_state, 'opponent', v_hit_damage, v_ability.type, v_opponent_hp, v_turn_no, v_opponent_status);
          v_hit_damage := (v_talent_res ->> 'damage')::integer;
          v_talent_heal := (v_talent_res ->> 'heal')::integer;
          v_opponent_talent_state := v_talent_res -> 'state';
          -- Des dégâts convertis en soin guérissent le poison, comme tout soin.
          v_opponent_status := v_talent_res ->> 'status';
          v_talent_pending := COALESCE(v_talent_dice_turns, '[]'::jsonb) || (v_talent_res -> 'turns');
          -- Un coup qui inflige réellement des dégâts consomme le bouclier
          -- 'invulnerable_until_hit' de son AUTEUR.
          IF v_hit_damage > 0 THEN
            v_player_talent_state := autobattle_talent_spend_shield(v_player_talents, v_player_talent_state);
          END IF;

          v_opponent_hp := LEAST(v_level.opponent_hp, v_opponent_hp - v_hit_damage + v_talent_heal);
          v_opponent_took_damage := v_hit_damage > 0;

          -- 'endure_ko' / 'heal_below_hp' : évalués AVANT la construction de l'entrée
          -- de tour, qui fige le drapeau 'ko' et defender_hp_after.
          v_talent_res := autobattle_talent_survive(v_opponent_talents, v_opponent_talent_state, 'opponent', v_opponent_hp, v_level.opponent_hp, v_turn_no, v_opponent_status);
          v_opponent_hp := (v_talent_res ->> 'hp')::integer;
          v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
          v_opponent_talent_state := v_talent_res -> 'state';
          -- Un soin de talent guérit le poison, comme tout autre soin.
          v_opponent_status := v_talent_res ->> 'status';
          v_talent_pending := v_talent_pending || (v_talent_res -> 'turns');

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
            'defender_hp_after', GREATEST(0, v_hp_shown), 'ko', v_opponent_hp <= 0,
            'precision_mod_amount', v_precision_mod_total
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
            -- Talents de la CIBLE du statut ('status_immunity', 'auto_cure_first_status') :
            -- la cible est l'utilisateur lui-même si le statut est retourné.
            v_talent_res := autobattle_talent_status_guard(
              CASE WHEN v_player_status_reversed THEN v_player_talents ELSE v_opponent_talents END,
              CASE WHEN v_player_status_reversed THEN v_player_talent_state ELSE v_opponent_talent_state END,
              CASE WHEN v_player_status_reversed THEN 'player' ELSE 'opponent' END,
              v_ability.status_effect,
              CASE WHEN v_player_status_reversed THEN v_player_hp ELSE v_opponent_hp END, v_turn_no);
            IF v_player_status_reversed THEN v_player_talent_state := v_talent_res -> 'state';
            ELSE v_opponent_talent_state := v_talent_res -> 'state'; END IF;
            v_talent_pending := COALESCE(v_talent_pending, '[]'::jsonb) || (v_talent_res -> 'turns');
            IF NOT (v_talent_res ->> 'blocked')::boolean THEN
              IF v_player_status_reversed THEN
                v_player_status := v_ability.status_effect;
              ELSE
                v_opponent_status := v_ability.status_effect;
              END IF;
              v_turn_entry := v_turn_entry || jsonb_build_object('status_applied', v_ability.status_effect, 'status_applied_reversed', v_player_status_reversed);
            END IF;
          END IF;
          -- Météo levée par la capacité (façon Danse Pluie) : au même moment que
          -- l'infliction de statut, donc seulement sur un coup qui a touché.
          IF v_player_weather_id IS NOT NULL AND random() * 100 < COALESCE(v_player_weather_chance, 0) THEN
            v_weather_res := autobattle_weather_set(v_player_weather_id, v_weather_enabled, v_weather, 'player', v_player_hp, v_turn_no);
            v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
            v_talent_pending := COALESCE(v_talent_pending, '[]'::jsonb) || (v_weather_res -> 'turns');
          END IF;
          -- Modificateur de stat (voir autobattle_ability_rules.stat_mod_*) :
          -- appliqué (ou réappliqué, écrasant l'ancien montant+durée) sur ce
          -- coup réussi, tant que la limite d'usages n'est pas atteinte —
          -- un usage ne compte que s'il s'applique réellement (jamais sur un
          -- raté, déjà exclu puisqu'on est dans la branche "coup réussi").
          -- Peut être conditionné à la météo en cours (stat_mod_weather_*).
          IF v_player_stat_mod_target IS NOT NULL
             AND autobattle_weather_cond(v_player_stat_mod_weather_condition, v_player_stat_mod_weather_id, v_weather) THEN
            IF v_player_stat_mod_max_uses IS NULL OR v_player_stat_mod_uses_used < v_player_stat_mod_max_uses THEN
              v_stat_mod_amount := CASE
                WHEN v_player_stat_mod_value_type = 'flat' THEN COALESCE(v_player_stat_mod_flat, 0)
                WHEN v_player_stat_mod_value_type = 'range' THEN v_player_stat_mod_min + floor(random() * (v_player_stat_mod_max - v_player_stat_mod_min + 1))::integer
                WHEN v_player_stat_mod_value_type = 'percent' THEN
                  floor((CASE WHEN v_player_stat_mod_target = 'self' THEN v_player_damage_original ELSE v_opponent_damage_original END)
                    * COALESCE(v_player_stat_mod_percent, 0) / 100.0)::integer
                ELSE 0
              END;
              v_stat_mod_amount := autobattle_stat_mod_signed(v_stat_mod_amount, v_player_stat_mod_target, v_player_stat_mod_direction);
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
                v_player_damage_mods := v_player_damage_mods || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry, 't', v_player_stat_mod_type_filter));
              ELSIF v_player_stat_mod_target = 'self' AND v_player_stat_mod_stat = 'precision' THEN
                v_player_precision_mods := v_player_precision_mods || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry));
              ELSIF v_player_stat_mod_target = 'opponent' AND v_player_stat_mod_stat = 'damage' THEN
                v_opponent_damage_mods := v_opponent_damage_mods || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry, 't', v_player_stat_mod_type_filter));
              ELSIF v_player_stat_mod_target = 'opponent' AND v_player_stat_mod_stat = 'precision' THEN
                v_opponent_precision_mods := v_opponent_precision_mods || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry));
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
          -- Effets persistants OFFENSIFS posés sur la CIBLE et perce-immunité
          -- accordé au lanceur — voir les mêmes octrois dans le moteur partagé
          -- autobattle_resolve_round_core.
          IF v_player_damage_dot_config_turns IS NOT NULL THEN
            v_opponent_damage_dot_amount := GREATEST(1, CASE
              WHEN v_player_damage_dot_config_type = 'percent_max_hp'
                THEN floor(v_level.opponent_hp * COALESCE(v_player_damage_dot_config_percent, 0) / 100.0)::integer
              ELSE COALESCE(v_player_damage_dot_config_amount, 0) END);
            v_opponent_damage_dot_expires := v_round_no + 2 * v_player_damage_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('damage_dot_granted', true);
          END IF;
          IF v_player_leech_dot_config_turns IS NOT NULL THEN
            v_opponent_leech_dot_amount := GREATEST(1, CASE
              WHEN v_player_leech_dot_config_type = 'percent_max_hp'
                THEN floor(v_level.opponent_hp * COALESCE(v_player_leech_dot_config_percent, 0) / 100.0)::integer
              ELSE COALESCE(v_player_leech_dot_config_amount, 0) END);
            v_opponent_leech_dot_expires := v_round_no + 2 * v_player_leech_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('leech_dot_granted', true);
          END IF;
          IF v_player_status_dot_config_turns IS NOT NULL THEN
            v_opponent_status_dot_status := v_player_status_dot_config_status;
            v_opponent_status_dot_chance := v_player_status_dot_config_chance;
            v_opponent_status_dot_expires := v_round_no + 2 * v_player_status_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('status_dot_granted', true);
          END IF;
          IF v_player_pierce_immunity_config_type IS NOT NULL AND v_player_pierce_immunity_config_turns IS NOT NULL THEN
            v_player_pierce_immunity_type := v_player_pierce_immunity_config_type;
            v_player_pierce_immunity_expires := v_round_no + 2 * v_player_pierce_immunity_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('pierce_immunity_granted', true);
          END IF;
          -- Purges (voir clear_damage_dot / cure_status / clear_weather) :
          -- elles visent leur LANCEUR — ses propres dégâts sur la durée, ses
          -- propres statuts — sauf la météo, état de TERRAIN partagé qui
          -- disparaît pour les deux camps.
          IF v_player_clear_damage_dot
             AND (v_player_damage_dot_amount IS NOT NULL OR v_player_leech_dot_amount IS NOT NULL
                  OR v_player_status_dot_status IS NOT NULL) THEN
            v_player_damage_dot_amount := NULL; v_player_damage_dot_expires := NULL;
            v_player_leech_dot_amount := NULL; v_player_leech_dot_expires := NULL;
            v_player_status_dot_status := NULL; v_player_status_dot_chance := NULL; v_player_status_dot_expires := NULL;
            v_turn_entry := v_turn_entry || jsonb_build_object('cleanse_dot', true);
          END IF;
          IF v_player_cure_status AND v_player_status IS NOT NULL THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('cleanse_status', v_player_status);
            v_player_status := NULL;
          END IF;
          IF v_player_clear_weather AND v_weather IS NOT NULL THEN
            v_talent_pending := COALESCE(v_talent_pending, '[]'::jsonb) || jsonb_build_array(
              autobattle_weather_turn(v_turn_no, 'player', v_player_hp, v_weather,
                jsonb_build_object('weather_cleared', true)));
            v_weather := NULL;
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
          IF v_player_recoil_type IS NOT NULL AND NOT autobattle_talent_has_kind(v_player_talents, 'no_recoil') THEN
            v_recoil_amt := CASE WHEN v_player_recoil_type = 'range'
              THEN v_player_recoil_min + floor(random() * (v_player_recoil_max - v_player_recoil_min + 1))::integer
              ELSE floor(v_hit_damage * COALESCE(v_player_recoil_percent, 0) / 100.0)::integer END;
            IF v_recoil_amt > 0 THEN
              v_player_hp := v_player_hp - v_recoil_amt;
              -- Le contre-coup peut tuer son auteur : mêmes talents de survie.
              v_talent_res := autobattle_talent_survive(v_player_talents, v_player_talent_state, 'player', v_player_hp, v_player_max_hp, v_turn_no, v_player_status);
              v_player_hp := (v_talent_res ->> 'hp')::integer;
              v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
              v_player_talent_state := v_talent_res -> 'state';
              -- Un soin de talent guérit le poison, comme tout autre soin.
              v_player_status := v_talent_res ->> 'status';
              v_talent_pending := v_talent_pending || (v_talent_res -> 'turns');
              v_turn_entry := v_turn_entry || jsonb_build_object('recoil', v_recoil_amt, 'attacker_hp_after', v_player_hp);
            END IF;
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry) || COALESCE(v_talent_pending, '[]'::jsonb);

          IF v_opponent_hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;
          IF v_player_hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
        END IF;
      END IF;
    ELSE
      -- Talents du camp qui agit : annonce des bonus de stat devenus actifs, puis
      -- tentative d'infliger un statut ('inflict_status', déclencheur « à chaque
      -- tour »). Les passifs permanents sont annoncés en tête de combat.
      v_talent_res := autobattle_talent_act(v_opponent_talents, v_opponent_talent_state, 'opponent', 'each_turn', v_opponent_ability.type,
        v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_player_talents, v_turn_no, v_weather);
      v_opponent_talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
      -- Voir le même commentaire côté joueur plus haut.
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'opponent', v_opponent_hp, v_turn_no);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_turns := v_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      -- Statut infligé par un talent : la cible peut encore le neutraliser
      -- ('status_immunity' est déjà pris en compte, 'auto_cure_first_status' non).
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(v_player_talents, v_player_talent_state, 'player', v_talent_inflict, v_player_hp, v_turn_no);
        v_player_talent_state := v_talent_res -> 'state';
        v_turns := v_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_player_status := v_talent_inflict;
        END IF;
      END IF;

      -- Voir la même remarque côté joueur ci-dessus : ne bloque que si cette
      -- capacité affecte réellement le joueur, re-vérifié à CHAQUE
      -- activation (bloque toute une rafale adverse, pas juste son 1er coup).
      -- Immunité de type côté adverse : voir la branche symétrique du camp
      -- joueur plus haut.
      -- Voir la branche symétrique du camp joueur plus haut.
      v_status_req_failed := v_opponent_requires_target_status IS NOT NULL
        AND v_player_status IS DISTINCT FROM v_opponent_requires_target_status;
      IF v_status_req_failed
         OR ((v_player_invulnerable OR v_opponent_type_immune OR autobattle_talent_shield_active(v_player_talents, v_player_talent_state)) AND (
        v_opponent_ability.deals_damage
        OR (v_opponent_ability.status_effect IS NOT NULL AND NOT v_opponent_status_reversed)
        OR v_opponent_stat_mod_target = 'opponent'
        OR v_opponent_cancel_heal_duration IS NOT NULL
      )) THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'missed', true,
          'invulnerable_miss', NOT v_opponent_type_immune AND NOT v_status_req_failed,
          'no_effect', v_opponent_type_immune AND NOT v_status_req_failed,
          'requires_status_failed', v_status_req_failed,
          'requires_status', v_opponent_requires_target_status,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_opponent_turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
        -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
        -- cesse d'être imposée, le tour suivant redevient un choix libre.
        IF v_opponent_keep_going_turns IS NOT NULL OR v_opponent_keep_going_until_fail THEN
          v_opponent_keep_going_remaining := 0;
          v_opponent_keep_going_count := 0;
        END IF;
      ELSE
        v_precision_mod_total := autobattle_mod_total(v_opponent_precision_mods, v_round_no, v_opponent_ability.type)
          + autobattle_talent_stat_bonus(v_opponent_talents, v_opponent_talent_state, 'precision', v_opponent_ability.type, v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_weather)
          + autobattle_weather_stat_bonus(v_weather, CASE WHEN v_is_opponent_metamorph THEN v_player_species.type ELSE v_opponent_species.type END, v_opponent_ability.type, 'precision');
        v_missed := (NOT v_opponent_never_miss) AND
          random() >= ((CASE WHEN v_precision_enabled THEN GREATEST(0, COALESCE(v_opponent_ability.precision, 10) - v_status_precision_penalty + v_precision_mod_total) ELSE 10 END * 10) / 100.0);

        IF v_missed THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'missed', true,
            'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false,
            'precision_mod_amount', v_precision_mod_total
          ));
          IF v_opponent_turn_effect = 'repeat_until_fail' THEN
            v_block_remaining := 1;
          END IF;
          -- Un raté met fin à la chaîne "Continue sur sa lancée" : la capacité
          -- cesse d'être imposée, le tour suivant redevient un choix libre.
          IF v_opponent_keep_going_turns IS NOT NULL OR v_opponent_keep_going_until_fail THEN
            v_opponent_keep_going_remaining := 0;
            v_opponent_keep_going_count := 0;
          END IF;
        ELSE
          -- Capacités non-offensives (voir même remarque côté joueur) : pas
          -- de dégâts, système % PV / bonus conditionnels ignorés aussi.
          -- Voir les mêmes commentaires côté joueur plus haut.
          v_damage_mod_applied := autobattle_mod_total(v_opponent_damage_mods, v_round_no, v_opponent_ability.type)
            + autobattle_talent_stat_bonus(v_opponent_talents, v_opponent_talent_state, 'damage', v_opponent_ability.type, v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_weather)
            + autobattle_weather_stat_bonus(v_weather, CASE WHEN v_is_opponent_metamorph THEN v_player_species.type ELSE v_opponent_species.type END, v_opponent_ability.type, 'damage');
          v_prevention_blocked := v_opponent_type_bonus
            AND v_player_prevention_expires IS NOT NULL AND v_round_no <= v_player_prevention_expires;
          v_keep_going_bonus := 0;
          IF v_opponent_ability.deals_damage THEN
            v_hit_dice := CASE WHEN v_opponent_ability.degats_de IS NOT NULL AND v_opponent_ability.degats_de > 0
              THEN 1 + floor(random() * v_opponent_ability.degats_de)::integer ELSE 0 END;
            -- Talent 'dice_bonus_damage' : le dé est tombé sur la valeur configurée.
            v_talent_res := autobattle_talent_dice(v_opponent_talents, v_hit_dice, 'opponent', v_opponent_hp, v_turn_no);
            v_talent_dice_bonus := (v_talent_res ->> 'amount')::integer;
            v_talent_dice_turns := v_talent_res -> 'turns';
            v_hit_damage := GREATEST(0, v_opponent_damage
              - (CASE WHEN v_prevention_blocked THEN v_opponent_damage_species_xp ELSE 0 END)
              + v_hit_dice + v_damage_mod_applied);

            v_percent_hp_damage_applied := v_opponent_percent_hp_damage_percent IS NOT NULL;
            IF v_percent_hp_damage_applied THEN
              v_hit_damage := GREATEST(0, floor(
                (CASE WHEN v_opponent_percent_hp_damage_basis = 'max' THEN v_player_max_hp ELSE v_player_hp END)
                * v_opponent_percent_hp_damage_percent / 100.0)::integer);
            END IF;

            v_bonus_condition_met := v_opponent_bonus_condition = 'took_damage_last_turn' AND v_opponent_took_damage
              OR v_opponent_bonus_condition = 'first_use' AND NOT v_opponent_used_ability
              OR v_opponent_bonus_condition = 'dice_equals' AND v_hit_dice = v_opponent_bonus_dice_value
              OR v_opponent_bonus_condition = 'has_status' AND v_player_status IS NOT NULL AND (v_opponent_bonus_status_filter IS NULL OR v_player_status = v_opponent_bonus_status_filter)
              OR v_opponent_bonus_condition = 'self_has_status' AND v_opponent_status IS NOT NULL AND (v_opponent_bonus_status_filter IS NULL OR v_opponent_status = v_opponent_bonus_status_filter)
              -- Poids : « self » est cette fois l'adversaire, qui attaque.
              OR v_opponent_bonus_condition = 'weight_ratio' AND autobattle_weight_condition(
                   v_opponent_bonus_weight_target, v_opponent_bonus_weight_comparison,
                   v_opponent_bonus_weight_percent, v_opponent_weight, v_player_weight);
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

            IF (v_opponent_keep_going_turns IS NOT NULL OR v_opponent_keep_going_until_fail) AND v_opponent_keep_going_count > 1 THEN
              v_keep_going_bonus := (v_opponent_keep_going_count - 1) * (CASE
                WHEN v_opponent_keep_going_bonus_type = 'percent_damage'
                  THEN floor(v_opponent_damage_species_xp * COALESCE(v_opponent_keep_going_bonus_percent, 0) / 100.0)::integer
                ELSE COALESCE(v_opponent_keep_going_bonus_flat, 0) END);
              v_hit_damage := GREATEST(0, v_hit_damage + v_keep_going_bonus);
            END IF;
            IF v_talent_dice_bonus <> 0 THEN
              v_hit_damage := GREATEST(0, v_hit_damage + v_talent_dice_bonus);
            END IF;
          ELSE
            v_hit_dice := 0;
            v_hit_damage := 0;
            v_percent_hp_damage_applied := false;
            v_talent_dice_bonus := 0;
            v_talent_dice_turns := '[]'::jsonb;
          END IF;
          -- Talent 'inflict_status' déclenché par le TYPE de la capacité jouée :
          -- uniquement sur un COUP DIRECT qui a porté (capacité offensive, non
          -- ratée, dégâts non nuls) — jamais sur une capacité de soutien ni sur
          -- un tick de brûlure/poison, qui ne passent pas par ici.
          IF v_hit_damage > 0 THEN
            v_talent_res := autobattle_talent_act(v_opponent_talents, v_opponent_talent_state, 'opponent', 'on_ability_type', v_opponent_ability.type,
              v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_player_talents, v_turn_no, v_weather);
            v_opponent_talent_state := v_talent_res -> 'state';
            v_turns := v_turns || (v_talent_res -> 'turns');
            v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'opponent', v_opponent_hp, v_turn_no);
            v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
            v_turns := v_turns || (v_weather_res -> 'turns');
            v_talent_inflict := v_talent_res ->> 'inflict_status';
            IF v_talent_inflict IS NOT NULL THEN
              v_talent_res := autobattle_talent_status_guard(v_player_talents, v_player_talent_state, 'player', v_talent_inflict, v_player_hp, v_turn_no);
              v_player_talent_state := v_talent_res -> 'state';
              v_turns := v_turns || (v_talent_res -> 'turns');
              IF NOT (v_talent_res ->> 'blocked')::boolean THEN
                v_player_status := v_talent_inflict;
              END IF;
            END IF;
          END IF;
          IF v_opponent_turn_effect IS DISTINCT FROM 'first_and_replay' THEN
            v_opponent_used_ability := true;
          END IF;

          -- Talents défensifs de la CIBLE : immunité de type, conversion des dégâts en
          -- soin, absorption du premier coup — et comptage du coup encaissé (hits).
          v_talent_res := autobattle_talent_defend(v_player_talents, v_player_talent_state, 'player', v_hit_damage, v_opponent_ability.type, v_player_hp, v_turn_no, v_player_status);
          v_hit_damage := (v_talent_res ->> 'damage')::integer;
          v_talent_heal := (v_talent_res ->> 'heal')::integer;
          v_player_talent_state := v_talent_res -> 'state';
          -- Des dégâts convertis en soin guérissent le poison, comme tout soin.
          v_player_status := v_talent_res ->> 'status';
          v_talent_pending := COALESCE(v_talent_dice_turns, '[]'::jsonb) || (v_talent_res -> 'turns');
          -- Un coup qui inflige réellement des dégâts consomme le bouclier
          -- 'invulnerable_until_hit' de son AUTEUR.
          IF v_hit_damage > 0 THEN
            v_opponent_talent_state := autobattle_talent_spend_shield(v_opponent_talents, v_opponent_talent_state);
          END IF;

          v_player_hp := LEAST(v_player_max_hp, v_player_hp - v_hit_damage + v_talent_heal);
          v_player_took_damage := v_hit_damage > 0;

          -- 'endure_ko' / 'heal_below_hp' : évalués AVANT la construction de l'entrée
          -- de tour, qui fige le drapeau 'ko' et defender_hp_after.
          v_talent_res := autobattle_talent_survive(v_player_talents, v_player_talent_state, 'player', v_player_hp, v_player_max_hp, v_turn_no, v_player_status);
          v_player_hp := (v_talent_res ->> 'hp')::integer;
          v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
          v_player_talent_state := v_talent_res -> 'state';
          -- Un soin de talent guérit le poison, comme tout autre soin.
          v_player_status := v_talent_res ->> 'status';
          v_talent_pending := v_talent_pending || (v_talent_res -> 'turns');

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
            'defender_hp_after', GREATEST(0, v_hp_shown), 'ko', v_player_hp <= 0,
            'precision_mod_amount', v_precision_mod_total
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
            -- Talents de la CIBLE du statut ('status_immunity', 'auto_cure_first_status') :
            -- la cible est l'utilisateur lui-même si le statut est retourné.
            v_talent_res := autobattle_talent_status_guard(
              CASE WHEN v_opponent_status_reversed THEN v_opponent_talents ELSE v_player_talents END,
              CASE WHEN v_opponent_status_reversed THEN v_opponent_talent_state ELSE v_player_talent_state END,
              CASE WHEN v_opponent_status_reversed THEN 'opponent' ELSE 'player' END,
              v_opponent_ability.status_effect,
              CASE WHEN v_opponent_status_reversed THEN v_opponent_hp ELSE v_player_hp END, v_turn_no);
            IF v_opponent_status_reversed THEN v_opponent_talent_state := v_talent_res -> 'state';
            ELSE v_player_talent_state := v_talent_res -> 'state'; END IF;
            v_talent_pending := COALESCE(v_talent_pending, '[]'::jsonb) || (v_talent_res -> 'turns');
            IF NOT (v_talent_res ->> 'blocked')::boolean THEN
              IF v_opponent_status_reversed THEN
                v_opponent_status := v_opponent_ability.status_effect;
              ELSE
                v_player_status := v_opponent_ability.status_effect;
              END IF;
              v_turn_entry := v_turn_entry || jsonb_build_object('status_applied', v_opponent_ability.status_effect, 'status_applied_reversed', v_opponent_status_reversed);
            END IF;
          END IF;
          -- Voir les mêmes commentaires côté joueur plus haut.
          IF v_opponent_weather_id IS NOT NULL AND random() * 100 < COALESCE(v_opponent_weather_chance, 0) THEN
            v_weather_res := autobattle_weather_set(v_opponent_weather_id, v_weather_enabled, v_weather, 'opponent', v_opponent_hp, v_turn_no);
            v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
            v_talent_pending := COALESCE(v_talent_pending, '[]'::jsonb) || (v_weather_res -> 'turns');
          END IF;
          IF v_opponent_stat_mod_target IS NOT NULL
             AND autobattle_weather_cond(v_opponent_stat_mod_weather_condition, v_opponent_stat_mod_weather_id, v_weather) THEN
            IF v_opponent_stat_mod_max_uses IS NULL OR v_opponent_stat_mod_uses_used < v_opponent_stat_mod_max_uses THEN
              v_stat_mod_amount := CASE
                WHEN v_opponent_stat_mod_value_type = 'flat' THEN COALESCE(v_opponent_stat_mod_flat, 0)
                WHEN v_opponent_stat_mod_value_type = 'range' THEN v_opponent_stat_mod_min + floor(random() * (v_opponent_stat_mod_max - v_opponent_stat_mod_min + 1))::integer
                WHEN v_opponent_stat_mod_value_type = 'percent' THEN
                  floor((CASE WHEN v_opponent_stat_mod_target = 'self' THEN v_opponent_damage_original ELSE v_player_damage_original END)
                    * COALESCE(v_opponent_stat_mod_percent, 0) / 100.0)::integer
                ELSE 0
              END;
              v_stat_mod_amount := autobattle_stat_mod_signed(v_stat_mod_amount, v_opponent_stat_mod_target, v_opponent_stat_mod_direction);
              v_stat_mod_expiry := CASE WHEN v_opponent_stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_round_no + 2 * COALESCE(v_opponent_stat_mod_duration_turns, 1) END;
              -- Voir le même commentaire côté joueur plus haut.
              IF v_opponent_stat_mod_target = 'self' AND v_opponent_stat_mod_stat = 'damage' THEN
                v_opponent_damage_mods := v_opponent_damage_mods || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry, 't', v_opponent_stat_mod_type_filter));
              ELSIF v_opponent_stat_mod_target = 'self' AND v_opponent_stat_mod_stat = 'precision' THEN
                v_opponent_precision_mods := v_opponent_precision_mods || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry));
              ELSIF v_opponent_stat_mod_target = 'opponent' AND v_opponent_stat_mod_stat = 'damage' THEN
                v_player_damage_mods := v_player_damage_mods || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry, 't', v_opponent_stat_mod_type_filter));
              ELSIF v_opponent_stat_mod_target = 'opponent' AND v_opponent_stat_mod_stat = 'precision' THEN
                v_player_precision_mods := v_player_precision_mods || jsonb_build_array(
                  jsonb_build_object('a', v_stat_mod_amount, 'e', v_stat_mod_expiry));
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
          -- Voir les mêmes octrois et purges côté joueur plus haut.
          IF v_opponent_damage_dot_config_turns IS NOT NULL THEN
            v_player_damage_dot_amount := GREATEST(1, CASE
              WHEN v_opponent_damage_dot_config_type = 'percent_max_hp'
                THEN floor(v_player_max_hp * COALESCE(v_opponent_damage_dot_config_percent, 0) / 100.0)::integer
              ELSE COALESCE(v_opponent_damage_dot_config_amount, 0) END);
            v_player_damage_dot_expires := v_round_no + 2 * v_opponent_damage_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('damage_dot_granted', true);
          END IF;
          IF v_opponent_leech_dot_config_turns IS NOT NULL THEN
            v_player_leech_dot_amount := GREATEST(1, CASE
              WHEN v_opponent_leech_dot_config_type = 'percent_max_hp'
                THEN floor(v_player_max_hp * COALESCE(v_opponent_leech_dot_config_percent, 0) / 100.0)::integer
              ELSE COALESCE(v_opponent_leech_dot_config_amount, 0) END);
            v_player_leech_dot_expires := v_round_no + 2 * v_opponent_leech_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('leech_dot_granted', true);
          END IF;
          IF v_opponent_status_dot_config_turns IS NOT NULL THEN
            v_player_status_dot_status := v_opponent_status_dot_config_status;
            v_player_status_dot_chance := v_opponent_status_dot_config_chance;
            v_player_status_dot_expires := v_round_no + 2 * v_opponent_status_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('status_dot_granted', true);
          END IF;
          IF v_opponent_pierce_immunity_config_type IS NOT NULL AND v_opponent_pierce_immunity_config_turns IS NOT NULL THEN
            v_opponent_pierce_immunity_type := v_opponent_pierce_immunity_config_type;
            v_opponent_pierce_immunity_expires := v_round_no + 2 * v_opponent_pierce_immunity_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('pierce_immunity_granted', true);
          END IF;
          IF v_opponent_clear_damage_dot
             AND (v_opponent_damage_dot_amount IS NOT NULL OR v_opponent_leech_dot_amount IS NOT NULL
                  OR v_opponent_status_dot_status IS NOT NULL) THEN
            v_opponent_damage_dot_amount := NULL; v_opponent_damage_dot_expires := NULL;
            v_opponent_leech_dot_amount := NULL; v_opponent_leech_dot_expires := NULL;
            v_opponent_status_dot_status := NULL; v_opponent_status_dot_chance := NULL; v_opponent_status_dot_expires := NULL;
            v_turn_entry := v_turn_entry || jsonb_build_object('cleanse_dot', true);
          END IF;
          IF v_opponent_cure_status AND v_opponent_status IS NOT NULL THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('cleanse_status', v_opponent_status);
            v_opponent_status := NULL;
          END IF;
          IF v_opponent_clear_weather AND v_weather IS NOT NULL THEN
            v_talent_pending := COALESCE(v_talent_pending, '[]'::jsonb) || jsonb_build_array(
              autobattle_weather_turn(v_turn_no, 'opponent', v_opponent_hp, v_weather,
                jsonb_build_object('weather_cleared', true)));
            v_weather := NULL;
          END IF;
          IF v_opponent_invuln_grant AND v_opponent_turn_effect IS DISTINCT FROM 'prepare_release' THEN
            v_opponent_invulnerable := true;
            v_opponent_invuln_granted_round := v_round_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          IF v_opponent_recoil_type IS NOT NULL AND NOT autobattle_talent_has_kind(v_opponent_talents, 'no_recoil') THEN
            v_recoil_amt := CASE WHEN v_opponent_recoil_type = 'range'
              THEN v_opponent_recoil_min + floor(random() * (v_opponent_recoil_max - v_opponent_recoil_min + 1))::integer
              ELSE floor(v_hit_damage * COALESCE(v_opponent_recoil_percent, 0) / 100.0)::integer END;
            IF v_recoil_amt > 0 THEN
              v_opponent_hp := v_opponent_hp - v_recoil_amt;
              -- Le contre-coup peut tuer son auteur : mêmes talents de survie.
              v_talent_res := autobattle_talent_survive(v_opponent_talents, v_opponent_talent_state, 'opponent', v_opponent_hp, v_level.opponent_hp, v_turn_no, v_opponent_status);
              v_opponent_hp := (v_talent_res ->> 'hp')::integer;
              v_hp_shown := (v_talent_res ->> 'hp_before_heal')::integer;
              v_opponent_talent_state := v_talent_res -> 'state';
              -- Un soin de talent guérit le poison, comme tout autre soin.
              v_opponent_status := v_talent_res ->> 'status';
              v_talent_pending := v_talent_pending || (v_talent_res -> 'turns');
              v_turn_entry := v_turn_entry || jsonb_build_object('recoil', v_recoil_amt, 'attacker_hp_after', v_opponent_hp);
            END IF;
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry) || COALESCE(v_talent_pending, '[]'::jsonb);

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

GRANT EXECUTE ON FUNCTION autobattle_resolve_battle(bigint, bigint, bigint, text, uuid) TO anon, authenticated;


-- autobattle_resolve_manual_round ------------------------------------------------------------------
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
  v_talents_enabled     boolean;
  v_weather_enabled     boolean;
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
  -- Piles de modificateurs de stat (voir autobattle_mod_total) : cumulables,
  -- chaque application gardant sa propre échéance.
  v_player_damage_mods           jsonb;
  v_player_precision_mods        jsonb;
  v_opponent_damage_mods         jsonb;
  v_opponent_precision_mods      jsonb;
  v_player_heal_dot_amount    integer;
  v_player_heal_dot_expires   integer;
  v_opponent_heal_dot_amount  integer;
  v_opponent_heal_dot_expires integer;
  -- Effets persistants offensifs SUBIS par chaque camp et perce-immunité qui
  -- lui est ACCORDÉ (colonnes player_*/opponent_* de autobattle_manual_battles,
  -- miroir des champs de autobattle_combatant_state).
  v_player_damage_dot_amount    integer;
  v_player_damage_dot_expires   integer;
  v_opponent_damage_dot_amount  integer;
  v_opponent_damage_dot_expires integer;
  v_player_leech_dot_amount     integer;
  v_player_leech_dot_expires    integer;
  v_opponent_leech_dot_amount   integer;
  v_opponent_leech_dot_expires  integer;
  v_player_status_dot_status    text;
  v_player_status_dot_chance    integer;
  v_player_status_dot_expires   integer;
  v_opponent_status_dot_status  text;
  v_opponent_status_dot_chance  integer;
  v_opponent_status_dot_expires integer;
  v_player_pierce_immunity_type      text;
  v_player_pierce_immunity_expires   integer;
  v_opponent_pierce_immunity_type    text;
  v_opponent_pierce_immunity_expires integer;
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
  v_player_stat_mod_direction    text;
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
  v_player_keep_going_until_fail  boolean;
  v_player_keep_going_bonus_type  text;
  v_player_keep_going_bonus_flat  integer;
  v_player_keep_going_bonus_percent integer;
  v_player_heal_dot_config_until_awake boolean;
  v_player_ignore_status_block    text;
  -- Météo déclenchée par la capacité, et condition « météo en cours » de son
  -- modificateur de stat (voir autobattle_ability_rules.weather_id).
  v_player_weather_id             bigint;
  v_player_weather_chance         integer;
  v_player_stat_mod_weather_condition text;
  v_player_stat_mod_weather_id    bigint;
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
  v_opponent_stat_mod_direction    text;
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
  v_opponent_keep_going_until_fail  boolean;
  v_opponent_keep_going_bonus_type  text;
  v_opponent_keep_going_bonus_flat  integer;
  v_opponent_keep_going_bonus_percent integer;
  v_opponent_heal_dot_config_until_awake boolean;
  v_opponent_ignore_status_block    text;
  v_opponent_weather_id             bigint;
  v_opponent_weather_chance         integer;
  v_opponent_stat_mod_weather_condition text;
  v_opponent_stat_mod_weather_id    bigint;
  -- État persisté des effets ajoutés après coup (miroir des colonnes
  -- autobattle_manual_battles.*, voir autobattle_combatant_state).
  v_player_double_turn_pending      boolean;
  v_opponent_double_turn_pending    boolean;
  v_player_prevention_expires       integer;
  v_opponent_prevention_expires     integer;
  v_player_heal_dot_until_awake     boolean;
  v_opponent_heal_dot_until_awake   boolean;
  v_player_keep_going_ability_nom   text;
  v_opponent_keep_going_ability_nom text;
  v_player_keep_going_remaining     integer;
  v_opponent_keep_going_remaining   integer;
  v_player_keep_going_count         integer;
  v_opponent_keep_going_count       integer;
  -- Talents d'espèce (voir autobattle_talents) : la liste est relue à chaque
  -- round (une modification admin en cours de combat s'applique donc au round
  -- suivant), l'état "déjà déclenchés" est persisté sur la ligne de combat.
  v_player_talents                  jsonb;
  v_opponent_talents                jsonb;
  v_player_talent_state             jsonb;
  v_opponent_talent_state           jsonb;
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
  --
  -- Talents résolus ICI, en amont : le talent 'transform' (anciennement le cas
  -- spécial « Métamorph ») conditionne toute la copie ci-dessous. Résolus sur
  -- l'espèce PROPRE de chaque camp — un transformé copie visuel/type/dégâts/
  -- movepool, jamais le talent adverse. _vs et non _for : voir
  -- autobattle_talents_effective ('cancel_talents' vide les deux listes, donc
  -- annule aussi la transformation).
  SELECT talents_enabled INTO v_talents_enabled FROM autobattle_config WHERE id = 1;
  v_talents_enabled := COALESCE(v_talents_enabled, true);
  v_player_talents := autobattle_talents_vs(v_pp.pokemon_nom, v_level.opponent_pokemon_nom, v_talents_enabled);
  v_opponent_talents := autobattle_talents_vs(v_level.opponent_pokemon_nom, v_pp.pokemon_nom, v_talents_enabled);
  -- Bascule globale de la météo (voir autobattle_config.weather_enabled).
  SELECT weather_enabled INTO v_weather_enabled FROM autobattle_config WHERE id = 1;
  v_weather_enabled := COALESCE(v_weather_enabled, true);

  v_is_metamorph := autobattle_talent_has_kind(v_player_talents, 'transform');
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
  v_player_damage_mods := v_row.player_damage_mods;
  v_player_precision_mods := v_row.player_precision_mods;
  v_opponent_damage_mods := v_row.opponent_damage_mods;
  v_opponent_precision_mods := v_row.opponent_precision_mods;
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
  v_player_heal_dot_until_awake := v_row.player_heal_dot_until_awake;
  v_opponent_heal_dot_until_awake := v_row.opponent_heal_dot_until_awake;
  v_player_keep_going_ability_nom := v_row.player_keep_going_ability_nom;
  v_opponent_keep_going_ability_nom := v_row.opponent_keep_going_ability_nom;
  v_player_keep_going_remaining := v_row.player_keep_going_remaining;
  v_opponent_keep_going_remaining := v_row.opponent_keep_going_remaining;
  v_player_keep_going_count := v_row.player_keep_going_count;
  v_opponent_keep_going_count := v_row.opponent_keep_going_count;
  v_player_talent_state := COALESCE(v_row.player_talent_state, '{}'::jsonb);
  v_opponent_talent_state := COALESCE(v_row.opponent_talent_state, '{}'::jsonb);
  v_player_damage_dot_amount := v_row.player_damage_dot_amount;
  v_player_damage_dot_expires := v_row.player_damage_dot_expires;
  v_opponent_damage_dot_amount := v_row.opponent_damage_dot_amount;
  v_opponent_damage_dot_expires := v_row.opponent_damage_dot_expires;
  v_player_leech_dot_amount := v_row.player_leech_dot_amount;
  v_player_leech_dot_expires := v_row.player_leech_dot_expires;
  v_opponent_leech_dot_amount := v_row.opponent_leech_dot_amount;
  v_opponent_leech_dot_expires := v_row.opponent_leech_dot_expires;
  v_player_status_dot_status := v_row.player_status_dot_status;
  v_player_status_dot_chance := v_row.player_status_dot_chance;
  v_player_status_dot_expires := v_row.player_status_dot_expires;
  v_opponent_status_dot_status := v_row.opponent_status_dot_status;
  v_opponent_status_dot_chance := v_row.opponent_status_dot_chance;
  v_opponent_status_dot_expires := v_row.opponent_status_dot_expires;
  v_player_pierce_immunity_type := v_row.player_pierce_immunity_type;
  v_player_pierce_immunity_expires := v_row.player_pierce_immunity_expires;
  v_opponent_pierce_immunity_type := v_row.opponent_pierce_immunity_type;
  v_opponent_pierce_immunity_expires := v_row.opponent_pierce_immunity_expires;

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
    WHEN v_player_keep_going_ability_nom IS NOT NULL THEN v_player_keep_going_ability_nom
    ELSE p_ability_nom END;
  SELECT * INTO v_ability FROM attacks WHERE nom = v_effective_player_ability_nom;

  -- Capacité adverse ce tour : mémorisée si en cours de préparation, sinon
  -- pigée dans la séquence configurée (autobattle_levels.opponent_ability_
  -- nom/_2/_3/_4, en boucle — v_opponent_ability_cycle_index avance d'une
  -- position à chaque NOUVEAU tour adverse) — ou, si l'adversaire est
  -- Métamorph, tirée uniformément parmi TOUTES les capacités apprises par le
  -- pokémon du joueur (requirement dédié : copie tout le movepool du joueur
  -- et l'utilise au hasard, un tirage indépendant par nouveau tour).
  v_is_opponent_metamorph := autobattle_talent_has_kind(v_opponent_talents, 'transform');
  IF v_opponent_preparing THEN
    v_opponent_ability_nom_round := v_opponent_preparing_ability_nom;
    v_opponent_ability_cycle_index := v_row.opponent_ability_cycle_index;
  ELSIF v_opponent_keep_going_ability_nom IS NOT NULL THEN
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

  -- Super efficace : TYPE DE LA CAPACITÉ jouée ce round vs TYPE DU DÉFENSEUR
  -- (voir type_super_effective, même règle qu'en mode Auto) — recalculé CHAQUE
  -- round ici, la capacité changeant à chaque tour. Le type du défenseur est
  -- son type EFFECTIF (celui copié par le talent 'transform' le cas échéant),
  -- exactement celui passé au core pour la météo et pour l'immunité de type
  -- (type_no_effect, gérée là-bas) : les trois règles jugent le même type.
  v_player_type_bonus := type_super_effective(
    v_ability.type,
    CASE WHEN v_is_opponent_metamorph THEN v_player_species.type ELSE v_opponent_species.type END
  );
  -- Dégâts de base "espèce" : copie ceux de l'adversaire (SANS bonus XP —
  -- reste une progression personnelle du joueur, jamais copiée, même
  -- principe qu'en mode Auto) au lieu des siens propres.
  v_player_damage_species_xp := (CASE WHEN v_is_metamorph THEN COALESCE(v_opponent_species.degats_base, 0) ELSE COALESCE(v_player_species.degats_base, 0) END)
    + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'DMG');
  v_player_damage := v_player_damage_species_xp
    * (CASE WHEN v_player_type_bonus THEN 2 ELSE 1 END) + COALESCE(v_ability.degats_base, 0);
  v_player_damage_original := v_player_damage;

  -- Même règle côté adverse (type de SA capacité vs type du joueur), recalculée
  -- elle aussi à chaque round — l'adversaire peut piocher une capacité
  -- différente d'un tour à l'autre.
  v_opponent_type_bonus := type_super_effective(
    v_opponent_ability.type,
    CASE WHEN v_is_metamorph THEN v_opponent_species.type ELSE v_player_species.type END
  );
  -- Dégâts de base "espèce" : copie ceux du joueur (SANS son bonus XP,
  -- progression personnelle jamais "copiée" — même principe qu'en mode Auto)
  -- au lieu du dégât de base configuré sur le niveau.
  v_opponent_damage_species_xp := CASE WHEN v_is_opponent_metamorph THEN COALESCE(v_player_species.degats_base, 0) ELSE COALESCE(v_level.opponent_base_damage, 0) END;
  v_opponent_damage := v_opponent_damage_species_xp * (CASE WHEN v_opponent_type_bonus THEN 2 ELSE 1 END)
    + COALESCE(v_opponent_ability.degats_base, 0);
  v_opponent_damage_original := v_opponent_damage;

  v_player_never_miss := v_ability.precision IS NULL OR v_ability.precision = 0;
  v_opponent_never_miss := v_opponent_ability.precision IS NULL OR v_opponent_ability.precision = 0;
  -- talents_enabled a déjà été lu plus haut (le talent 'transform' devait être
  -- connu avant la copie de l'adversaire).
  SELECT precision_enabled INTO v_precision_enabled FROM autobattle_config WHERE id = 1;
  v_precision_enabled := COALESCE(v_precision_enabled, true);

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_direction, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block,
         weather_id, weather_chance, stat_mod_weather_condition, stat_mod_weather_id
    INTO v_player_turn_effect, v_player_repeat_max, v_player_heal_type, v_player_heal_amount, v_player_heal_percent, v_player_status_reversed,
         v_player_recoil_type, v_player_recoil_min, v_player_recoil_max, v_player_recoil_percent, v_player_invuln_grant,
         v_player_bonus_type, v_player_bonus_multiplier, v_player_bonus_flat, v_player_bonus_min, v_player_bonus_max,
         v_player_bonus_condition, v_player_bonus_dice_value, v_player_bonus_status_filter,
         v_player_stat_mod_target, v_player_stat_mod_direction, v_player_stat_mod_stat, v_player_stat_mod_value_type, v_player_stat_mod_flat, v_player_stat_mod_min, v_player_stat_mod_max, v_player_stat_mod_percent,
         v_player_stat_mod_duration_type, v_player_stat_mod_duration_turns, v_player_stat_mod_max_uses,
         v_player_heal_dot_config_amount, v_player_heal_dot_config_turns, v_player_heal_dot_config_type, v_player_heal_dot_config_percent, v_player_cancel_heal_duration, v_player_percent_hp_damage_percent,
         v_player_stat_mod_type_filter, v_player_prevention_duration,
         v_player_keep_going_turns, v_player_keep_going_until_fail, v_player_keep_going_bonus_type, v_player_keep_going_bonus_flat, v_player_keep_going_bonus_percent,
         v_player_heal_dot_config_until_awake, v_player_ignore_status_block,
         v_player_weather_id, v_player_weather_chance,
         v_player_stat_mod_weather_condition, v_player_stat_mod_weather_id
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_player_ability_nom;
  v_player_status_reversed := COALESCE(v_player_status_reversed, false);
  v_player_invuln_grant := COALESCE(v_player_invuln_grant, false);
  v_player_heal_dot_config_until_awake := COALESCE(v_player_heal_dot_config_until_awake, false);
  v_player_keep_going_until_fail := COALESCE(v_player_keep_going_until_fail, false);

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_direction, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block,
         weather_id, weather_chance, stat_mod_weather_condition, stat_mod_weather_id
    INTO v_opponent_turn_effect, v_opponent_repeat_max, v_opponent_heal_type, v_opponent_heal_amount, v_opponent_heal_percent, v_opponent_status_reversed,
         v_opponent_recoil_type, v_opponent_recoil_min, v_opponent_recoil_max, v_opponent_recoil_percent, v_opponent_invuln_grant,
         v_opponent_bonus_type, v_opponent_bonus_multiplier, v_opponent_bonus_flat, v_opponent_bonus_min, v_opponent_bonus_max,
         v_opponent_bonus_condition, v_opponent_bonus_dice_value, v_opponent_bonus_status_filter,
         v_opponent_stat_mod_target, v_opponent_stat_mod_direction, v_opponent_stat_mod_stat, v_opponent_stat_mod_value_type, v_opponent_stat_mod_flat, v_opponent_stat_mod_min, v_opponent_stat_mod_max, v_opponent_stat_mod_percent,
         v_opponent_stat_mod_duration_type, v_opponent_stat_mod_duration_turns, v_opponent_stat_mod_max_uses,
         v_opponent_heal_dot_config_amount, v_opponent_heal_dot_config_turns, v_opponent_heal_dot_config_type, v_opponent_heal_dot_config_percent, v_opponent_cancel_heal_duration, v_opponent_percent_hp_damage_percent,
         v_opponent_stat_mod_type_filter, v_opponent_prevention_duration,
         v_opponent_keep_going_turns, v_opponent_keep_going_until_fail, v_opponent_keep_going_bonus_type, v_opponent_keep_going_bonus_flat, v_opponent_keep_going_bonus_percent,
         v_opponent_heal_dot_config_until_awake, v_opponent_ignore_status_block,
         v_opponent_weather_id, v_opponent_weather_chance,
         v_opponent_stat_mod_weather_condition, v_opponent_stat_mod_weather_id
    FROM autobattle_ability_rules WHERE attack_nom = v_opponent_ability_nom_round;
  v_opponent_status_reversed := COALESCE(v_opponent_status_reversed, false);
  v_opponent_invuln_grant := COALESCE(v_opponent_invuln_grant, false);
  v_opponent_heal_dot_config_until_awake := COALESCE(v_opponent_heal_dot_config_until_awake, false);
  v_opponent_keep_going_until_fail := COALESCE(v_opponent_keep_going_until_fail, false);

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
  v_player_state.damage_mods := v_player_damage_mods;
  v_player_state.precision_mods := v_player_precision_mods;
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
  v_player_state.heal_dot_until_awake := v_player_heal_dot_until_awake;
  v_player_state.keep_going_ability_nom := v_player_keep_going_ability_nom;
  v_player_state.keep_going_remaining := v_player_keep_going_remaining;
  v_player_state.keep_going_count := v_player_keep_going_count;
  v_player_state.talent_state := v_player_talent_state;
  -- Effets persistants offensifs subis et perce-immunité accordé (colonnes
  -- player_*/opponent_* de autobattle_manual_battles, lues plus haut).
  v_player_state.damage_dot_amount := v_player_damage_dot_amount;
  v_player_state.damage_dot_expires := v_player_damage_dot_expires;
  v_player_state.leech_dot_amount := v_player_leech_dot_amount;
  v_player_state.leech_dot_expires := v_player_leech_dot_expires;
  v_player_state.status_dot_status := v_player_status_dot_status;
  v_player_state.status_dot_chance := v_player_status_dot_chance;
  v_player_state.status_dot_expires := v_player_status_dot_expires;
  v_player_state.pierce_immunity_type := v_player_pierce_immunity_type;
  v_player_state.pierce_immunity_expires := v_player_pierce_immunity_expires;

  v_opponent_state.hp := v_opponent_hp;
  v_opponent_state.max_hp := v_level.opponent_hp;
  v_opponent_state.status := v_opponent_status;
  v_opponent_state.damage_mods := v_opponent_damage_mods;
  v_opponent_state.precision_mods := v_opponent_precision_mods;
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
  v_opponent_state.heal_dot_until_awake := v_opponent_heal_dot_until_awake;
  v_opponent_state.keep_going_ability_nom := v_opponent_keep_going_ability_nom;
  v_opponent_state.keep_going_remaining := v_opponent_keep_going_remaining;
  v_opponent_state.keep_going_count := v_opponent_keep_going_count;
  v_opponent_state.talent_state := v_opponent_talent_state;
  v_opponent_state.damage_dot_amount := v_opponent_damage_dot_amount;
  v_opponent_state.damage_dot_expires := v_opponent_damage_dot_expires;
  v_opponent_state.leech_dot_amount := v_opponent_leech_dot_amount;
  v_opponent_state.leech_dot_expires := v_opponent_leech_dot_expires;
  v_opponent_state.status_dot_status := v_opponent_status_dot_status;
  v_opponent_state.status_dot_chance := v_opponent_status_dot_chance;
  v_opponent_state.status_dot_expires := v_opponent_status_dot_expires;
  v_opponent_state.pierce_immunity_type := v_opponent_pierce_immunity_type;
  v_opponent_state.pierce_immunity_expires := v_opponent_pierce_immunity_expires;

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
  v_player_ability_cfg.stat_mod_direction := v_player_stat_mod_direction;
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
  v_player_ability_cfg.keep_going_until_fail := v_player_keep_going_until_fail;
  v_player_ability_cfg.keep_going_bonus_type := v_player_keep_going_bonus_type;
  v_player_ability_cfg.keep_going_bonus_flat := v_player_keep_going_bonus_flat;
  v_player_ability_cfg.keep_going_bonus_percent := v_player_keep_going_bonus_percent;
  v_player_ability_cfg.heal_dot_until_awake := v_player_heal_dot_config_until_awake;
  v_player_ability_cfg.ignore_status_block := v_player_ignore_status_block;
  v_player_ability_cfg.weather_id := v_player_weather_id;
  v_player_ability_cfg.weather_chance := v_player_weather_chance;
  v_player_ability_cfg.stat_mod_weather_condition := v_player_stat_mod_weather_condition;
  v_player_ability_cfg.stat_mod_weather_id := v_player_stat_mod_weather_id;
  -- Effets ajoutés en dernier (dégâts/vol de vie persistants, perce-immunité,
  -- statut exigé, condition de poids, purges) : lus directement dans les
  -- champs du type partagé, sans variable intermédiaire.
  SELECT damage_dot_amount, damage_dot_duration_turns, damage_dot_type, damage_dot_percent,
         leech_dot_amount, leech_dot_duration_turns, leech_dot_type, leech_dot_percent,
         pierce_immunity_type, pierce_immunity_turns, requires_target_status,
         bonus_damage_weight_target, bonus_damage_weight_comparison, bonus_damage_weight_percent,
         clear_damage_dot, clear_weather, cure_status,
         status_dot_status, status_dot_chance, status_dot_duration_turns, percent_hp_damage_basis
    INTO v_player_ability_cfg.damage_dot_config_amount, v_player_ability_cfg.damage_dot_config_turns, v_player_ability_cfg.damage_dot_config_type, v_player_ability_cfg.damage_dot_config_percent,
         v_player_ability_cfg.leech_dot_config_amount, v_player_ability_cfg.leech_dot_config_turns, v_player_ability_cfg.leech_dot_config_type, v_player_ability_cfg.leech_dot_config_percent,
         v_player_ability_cfg.pierce_immunity_type, v_player_ability_cfg.pierce_immunity_turns, v_player_ability_cfg.requires_target_status,
         v_player_ability_cfg.bonus_weight_target, v_player_ability_cfg.bonus_weight_comparison, v_player_ability_cfg.bonus_weight_percent,
         v_player_ability_cfg.clear_damage_dot, v_player_ability_cfg.clear_weather, v_player_ability_cfg.cure_status,
         v_player_ability_cfg.status_dot_config_status, v_player_ability_cfg.status_dot_config_chance, v_player_ability_cfg.status_dot_config_turns,
         v_player_ability_cfg.percent_hp_damage_basis
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_player_ability_nom;

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
  v_opponent_ability_cfg.stat_mod_direction := v_opponent_stat_mod_direction;
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
  v_opponent_ability_cfg.keep_going_until_fail := v_opponent_keep_going_until_fail;
  v_opponent_ability_cfg.keep_going_bonus_type := v_opponent_keep_going_bonus_type;
  v_opponent_ability_cfg.keep_going_bonus_flat := v_opponent_keep_going_bonus_flat;
  v_opponent_ability_cfg.keep_going_bonus_percent := v_opponent_keep_going_bonus_percent;
  v_opponent_ability_cfg.heal_dot_until_awake := v_opponent_heal_dot_config_until_awake;
  v_opponent_ability_cfg.ignore_status_block := v_opponent_ignore_status_block;
  v_opponent_ability_cfg.weather_id := v_opponent_weather_id;
  v_opponent_ability_cfg.weather_chance := v_opponent_weather_chance;
  v_opponent_ability_cfg.stat_mod_weather_condition := v_opponent_stat_mod_weather_condition;
  v_opponent_ability_cfg.stat_mod_weather_id := v_opponent_stat_mod_weather_id;
  -- Voir le même complément côté joueur juste au-dessus.
  SELECT damage_dot_amount, damage_dot_duration_turns, damage_dot_type, damage_dot_percent,
         leech_dot_amount, leech_dot_duration_turns, leech_dot_type, leech_dot_percent,
         pierce_immunity_type, pierce_immunity_turns, requires_target_status,
         bonus_damage_weight_target, bonus_damage_weight_comparison, bonus_damage_weight_percent,
         clear_damage_dot, clear_weather, cure_status,
         status_dot_status, status_dot_chance, status_dot_duration_turns, percent_hp_damage_basis
    INTO v_opponent_ability_cfg.damage_dot_config_amount, v_opponent_ability_cfg.damage_dot_config_turns, v_opponent_ability_cfg.damage_dot_config_type, v_opponent_ability_cfg.damage_dot_config_percent,
         v_opponent_ability_cfg.leech_dot_config_amount, v_opponent_ability_cfg.leech_dot_config_turns, v_opponent_ability_cfg.leech_dot_config_type, v_opponent_ability_cfg.leech_dot_config_percent,
         v_opponent_ability_cfg.pierce_immunity_type, v_opponent_ability_cfg.pierce_immunity_turns, v_opponent_ability_cfg.requires_target_status,
         v_opponent_ability_cfg.bonus_weight_target, v_opponent_ability_cfg.bonus_weight_comparison, v_opponent_ability_cfg.bonus_weight_percent,
         v_opponent_ability_cfg.clear_damage_dot, v_opponent_ability_cfg.clear_weather, v_opponent_ability_cfg.cure_status,
         v_opponent_ability_cfg.status_dot_config_status, v_opponent_ability_cfg.status_dot_config_chance, v_opponent_ability_cfg.status_dot_config_turns,
         v_opponent_ability_cfg.percent_hp_damage_basis
    FROM autobattle_ability_rules WHERE attack_nom = v_opponent_ability_nom_round;

  -- Météo : id en cours (persisté sur la ligne de combat), bascule du mode, et
  -- types d'espèce EFFECTIFS des deux camps — un pokémon transformé (talent
  -- 'transform') a copié le type de l'autre, la météo doit le voir ainsi.
  -- Poids des deux espèces : le talent 'transform' ne copie pas le poids.
  v_round_result := autobattle_resolve_round_core(
    v_turn_no, v_round_no, v_first_attacker,
    v_player_state, v_opponent_state, v_player_ability_cfg, v_opponent_ability_cfg,
    v_precision_enabled, v_player_talents, v_opponent_talents,
    v_row.weather_id, v_weather_enabled,
    CASE WHEN v_is_metamorph THEN v_opponent_species.type ELSE v_player_species.type END,
    CASE WHEN v_is_opponent_metamorph THEN v_player_species.type ELSE v_opponent_species.type END,
    v_player_species.poids, v_opponent_species.poids
  );

  v_player_hp := (v_round_result.player_state).hp;
  v_player_status := (v_round_result.player_state).status;
  v_player_damage_mods := (v_round_result.player_state).damage_mods;
  v_player_precision_mods := (v_round_result.player_state).precision_mods;
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
  v_player_heal_dot_until_awake := COALESCE((v_round_result.player_state).heal_dot_until_awake, false);
  v_player_keep_going_ability_nom := (v_round_result.player_state).keep_going_ability_nom;
  v_player_keep_going_remaining := COALESCE((v_round_result.player_state).keep_going_remaining, 0);
  v_player_keep_going_count := COALESCE((v_round_result.player_state).keep_going_count, 0);
  v_player_talent_state := COALESCE((v_round_result.player_state).talent_state, '[]'::jsonb);
  v_player_damage_dot_amount := (v_round_result.player_state).damage_dot_amount;
  v_player_damage_dot_expires := (v_round_result.player_state).damage_dot_expires;
  v_player_leech_dot_amount := (v_round_result.player_state).leech_dot_amount;
  v_player_leech_dot_expires := (v_round_result.player_state).leech_dot_expires;
  v_player_status_dot_status := (v_round_result.player_state).status_dot_status;
  v_player_status_dot_chance := (v_round_result.player_state).status_dot_chance;
  v_player_status_dot_expires := (v_round_result.player_state).status_dot_expires;
  v_player_pierce_immunity_type := (v_round_result.player_state).pierce_immunity_type;
  v_player_pierce_immunity_expires := (v_round_result.player_state).pierce_immunity_expires;

  v_opponent_hp := (v_round_result.opponent_state).hp;
  v_opponent_status := (v_round_result.opponent_state).status;
  v_opponent_damage_mods := (v_round_result.opponent_state).damage_mods;
  v_opponent_precision_mods := (v_round_result.opponent_state).precision_mods;
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
  v_opponent_heal_dot_until_awake := COALESCE((v_round_result.opponent_state).heal_dot_until_awake, false);
  v_opponent_keep_going_ability_nom := (v_round_result.opponent_state).keep_going_ability_nom;
  v_opponent_keep_going_remaining := COALESCE((v_round_result.opponent_state).keep_going_remaining, 0);
  v_opponent_keep_going_count := COALESCE((v_round_result.opponent_state).keep_going_count, 0);
  v_opponent_talent_state := COALESCE((v_round_result.opponent_state).talent_state, '[]'::jsonb);
  v_opponent_damage_dot_amount := (v_round_result.opponent_state).damage_dot_amount;
  v_opponent_damage_dot_expires := (v_round_result.opponent_state).damage_dot_expires;
  v_opponent_leech_dot_amount := (v_round_result.opponent_state).leech_dot_amount;
  v_opponent_leech_dot_expires := (v_round_result.opponent_state).leech_dot_expires;
  v_opponent_status_dot_status := (v_round_result.opponent_state).status_dot_status;
  v_opponent_status_dot_chance := (v_round_result.opponent_state).status_dot_chance;
  v_opponent_status_dot_expires := (v_round_result.opponent_state).status_dot_expires;
  v_opponent_pierce_immunity_type := (v_round_result.opponent_state).pierce_immunity_type;
  v_opponent_pierce_immunity_expires := (v_round_result.opponent_state).pierce_immunity_expires;

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
    -- Le joueur n'a pas agi de tout le round : l'adversaire a ouvert ET gagné
    -- une action supplémentaire, ce qui a mis fin au round avant son tour
    -- (voir autobattle_resolve_round_core). La capacité qu'il vient de
    -- soumettre n'a donc rien fait — on la lui réimpose au round suivant au
    -- lieu de la lui faire choisir une deuxième fois pour rien.
    WHEN NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_turns) t WHERE t ->> 'attacker' = 'player')
      THEN v_effective_player_ability_nom
    WHEN v_player_preparing THEN v_player_preparing_ability_nom
    WHEN v_player_skip_pending THEN v_effective_player_ability_nom
    WHEN v_player_keep_going_ability_nom IS NOT NULL THEN v_player_keep_going_ability_nom
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
    'player_image_override', v_player_image_override,
    -- Perce-immunité encore actif AU PROCHAIN TOUR côté joueur (voir
    -- pierce_immunity_*) : le client s'en sert pour dégriser les capacités que
    -- l'immunité de ce type bloquerait normalement dans sa grille.
    'player_pierce_immunity_type', CASE
      WHEN v_player_pierce_immunity_expires IS NOT NULL AND v_player_pierce_immunity_expires >= v_round_no + 1
        THEN v_player_pierce_immunity_type ELSE NULL END
  );

  IF v_outcome IS NULL THEN
    UPDATE autobattle_manual_battles SET
      turn_no = v_turn_no, round_no = v_round_no, player_hp = v_player_hp, opponent_hp = v_opponent_hp,
      player_status = v_player_status, opponent_status = v_opponent_status,
      player_damage_mods = v_player_damage_mods, player_precision_mods = v_player_precision_mods,
      opponent_damage_mods = v_opponent_damage_mods, opponent_precision_mods = v_opponent_precision_mods,
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
      player_heal_dot_until_awake = v_player_heal_dot_until_awake, opponent_heal_dot_until_awake = v_opponent_heal_dot_until_awake,
      player_keep_going_ability_nom = v_player_keep_going_ability_nom, opponent_keep_going_ability_nom = v_opponent_keep_going_ability_nom,
      player_keep_going_remaining = v_player_keep_going_remaining, opponent_keep_going_remaining = v_opponent_keep_going_remaining,
      player_keep_going_count = v_player_keep_going_count, opponent_keep_going_count = v_opponent_keep_going_count,
      player_talent_state = v_player_talent_state, opponent_talent_state = v_opponent_talent_state,
      player_damage_dot_amount = v_player_damage_dot_amount, player_damage_dot_expires = v_player_damage_dot_expires,
      opponent_damage_dot_amount = v_opponent_damage_dot_amount, opponent_damage_dot_expires = v_opponent_damage_dot_expires,
      player_leech_dot_amount = v_player_leech_dot_amount, player_leech_dot_expires = v_player_leech_dot_expires,
      opponent_leech_dot_amount = v_opponent_leech_dot_amount, opponent_leech_dot_expires = v_opponent_leech_dot_expires,
      player_status_dot_status = v_player_status_dot_status, player_status_dot_chance = v_player_status_dot_chance,
      player_status_dot_expires = v_player_status_dot_expires,
      opponent_status_dot_status = v_opponent_status_dot_status, opponent_status_dot_chance = v_opponent_status_dot_chance,
      opponent_status_dot_expires = v_opponent_status_dot_expires,
      player_pierce_immunity_type = v_player_pierce_immunity_type, player_pierce_immunity_expires = v_player_pierce_immunity_expires,
      opponent_pierce_immunity_type = v_opponent_pierce_immunity_type, opponent_pierce_immunity_expires = v_opponent_pierce_immunity_expires,
      opponent_ability_cycle_index = v_opponent_ability_cycle_index,
      player_stat_mod_uses = v_player_stat_mod_uses, opponent_stat_mod_uses = v_opponent_stat_mod_uses,
      weather_id = v_round_result.weather_id,
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

GRANT EXECUTE ON FUNCTION autobattle_resolve_manual_round(bigint, bigint, bigint, text, uuid) TO anon, authenticated;


-- pvp_resolve_round ------------------------------------------------------------------
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
  v_talents_enabled        boolean;
  v_weather_enabled        boolean;
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
    WHEN v_row.attacker_keep_going_ability_nom IS NOT NULL THEN v_row.attacker_keep_going_ability_nom
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
  ELSIF v_row.defender_keep_going_ability_nom IS NOT NULL THEN
    v_d_ability_nom_round := v_row.defender_keep_going_ability_nom;
    v_d_ability_cycle_index := v_row.defender_ability_cycle_index;
  ELSE
    v_d_ability_sequence := v_challenge.ability_noms;
    v_d_ability_cycle_index := v_row.defender_ability_cycle_index + 1;
    v_d_ability_nom_round := v_d_ability_sequence[1 + ((v_d_ability_cycle_index - 1) % array_length(v_d_ability_sequence, 1))];
  END IF;
  SELECT * INTO v_d_ability FROM attacks WHERE nom = v_d_ability_nom_round;

  -- Super efficace : TYPE DE LA CAPACITÉ jouée vs TYPE DU DÉFENSEUR (voir
  -- type_super_effective) — plus les colonnes super_efficace_1..4 de l'espèce,
  -- et plus de condition « la capacité doit être du type de son lanceur ».
  -- L'immunité de type (type_no_effect) est gérée par le core, qui reçoit déjà
  -- les deux types d'espèce.
  v_a_type_bonus := type_super_effective(v_ability.type, v_d_species.type);
  v_a_damage_species_xp := COALESCE(v_a_species.degats_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'DMG');
  v_a_damage := v_a_damage_species_xp * (CASE WHEN v_a_type_bonus THEN 2 ELSE 1 END) + COALESCE(v_ability.degats_base, 0);

  -- Même règle côté défenseur (type de SA capacité vs type de l'attaquant).
  v_d_type_bonus := type_super_effective(v_d_ability.type, v_a_species.type);
  -- Figé au dépôt du défi (voir pvp_challenges.damage_species_xp), pas
  -- recalculé depuis l'XP courante du pokémon réel du défenseur.
  v_d_damage_species_xp := v_challenge.damage_species_xp;
  v_d_damage := v_d_damage_species_xp * (CASE WHEN v_d_type_bonus THEN 2 ELSE 1 END) + COALESCE(v_d_ability.degats_base, 0);

  SELECT precision_enabled, talents_enabled, weather_enabled
    INTO v_precision_enabled, v_talents_enabled, v_weather_enabled FROM pvp_config WHERE id = 1;
  v_precision_enabled := COALESCE(v_precision_enabled, true);
  v_talents_enabled := COALESCE(v_talents_enabled, true);
  v_weather_enabled := COALESCE(v_weather_enabled, true);

  -- Empaquette l'état persisté (pvp_battles) dans les types partagés avec le
  -- moteur de résolution (voir autobattle_resolve_round_core, juste après
  -- autobattle_ability_burst plus haut dans ce fichier — le MÊME moteur que
  -- Combat Auto en mode Manuel, aucune duplication de la boucle elle-même).
  v_a_state.hp := v_row.attacker_hp;
  v_a_state.max_hp := v_row.attacker_max_hp;
  v_a_state.status := v_row.attacker_status;
  v_a_state.damage_mods := v_row.attacker_damage_mods;
  v_a_state.precision_mods := v_row.attacker_precision_mods;
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
  v_a_state.heal_dot_until_awake := v_row.attacker_heal_dot_until_awake;
  v_a_state.keep_going_ability_nom := v_row.attacker_keep_going_ability_nom;
  v_a_state.keep_going_remaining := v_row.attacker_keep_going_remaining;
  v_a_state.keep_going_count := v_row.attacker_keep_going_count;
  v_a_state.talent_state := COALESCE(v_row.attacker_talent_state, '[]'::jsonb);
  -- Effets persistants offensifs subis et perce-immunité accordé (voir les
  -- mêmes colonnes côté Combat Manuel, autobattle_resolve_manual_round).
  v_a_state.damage_dot_amount := v_row.attacker_damage_dot_amount;
  v_a_state.damage_dot_expires := v_row.attacker_damage_dot_expires;
  v_a_state.leech_dot_amount := v_row.attacker_leech_dot_amount;
  v_a_state.leech_dot_expires := v_row.attacker_leech_dot_expires;
  v_a_state.status_dot_status := v_row.attacker_status_dot_status;
  v_a_state.status_dot_chance := v_row.attacker_status_dot_chance;
  v_a_state.status_dot_expires := v_row.attacker_status_dot_expires;
  v_a_state.pierce_immunity_type := v_row.attacker_pierce_immunity_type;
  v_a_state.pierce_immunity_expires := v_row.attacker_pierce_immunity_expires;

  v_d_state.hp := v_row.defender_hp;
  v_d_state.max_hp := v_challenge.max_hp;
  v_d_state.status := v_row.defender_status;
  v_d_state.damage_mods := v_row.defender_damage_mods;
  v_d_state.precision_mods := v_row.defender_precision_mods;
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
  v_d_state.heal_dot_until_awake := v_row.defender_heal_dot_until_awake;
  v_d_state.keep_going_ability_nom := v_row.defender_keep_going_ability_nom;
  v_d_state.keep_going_remaining := v_row.defender_keep_going_remaining;
  v_d_state.keep_going_count := v_row.defender_keep_going_count;
  v_d_state.talent_state := COALESCE(v_row.defender_talent_state, '[]'::jsonb);
  v_d_state.damage_dot_amount := v_row.defender_damage_dot_amount;
  v_d_state.damage_dot_expires := v_row.defender_damage_dot_expires;
  v_d_state.leech_dot_amount := v_row.defender_leech_dot_amount;
  v_d_state.leech_dot_expires := v_row.defender_leech_dot_expires;
  v_d_state.status_dot_status := v_row.defender_status_dot_status;
  v_d_state.status_dot_chance := v_row.defender_status_dot_chance;
  v_d_state.status_dot_expires := v_row.defender_status_dot_expires;
  v_d_state.pierce_immunity_type := v_row.defender_pierce_immunity_type;
  v_d_state.pierce_immunity_expires := v_row.defender_pierce_immunity_expires;

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_direction, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block,
         weather_id, weather_chance, stat_mod_weather_condition, stat_mod_weather_id
    INTO v_a_ability_cfg.turn_effect, v_a_ability_cfg.repeat_max, v_a_ability_cfg.heal_type, v_a_ability_cfg.heal_amount, v_a_ability_cfg.heal_percent, v_a_ability_cfg.status_reversed,
         v_a_ability_cfg.recoil_type, v_a_ability_cfg.recoil_min, v_a_ability_cfg.recoil_max, v_a_ability_cfg.recoil_percent, v_a_ability_cfg.invuln_grant,
         v_a_ability_cfg.bonus_type, v_a_ability_cfg.bonus_multiplier, v_a_ability_cfg.bonus_flat, v_a_ability_cfg.bonus_min, v_a_ability_cfg.bonus_max,
         v_a_ability_cfg.bonus_condition, v_a_ability_cfg.bonus_dice_value, v_a_ability_cfg.bonus_status_filter,
         v_a_ability_cfg.stat_mod_target, v_a_ability_cfg.stat_mod_direction, v_a_ability_cfg.stat_mod_stat, v_a_ability_cfg.stat_mod_value_type, v_a_ability_cfg.stat_mod_flat, v_a_ability_cfg.stat_mod_min, v_a_ability_cfg.stat_mod_max, v_a_ability_cfg.stat_mod_percent,
         v_a_ability_cfg.stat_mod_duration_type, v_a_ability_cfg.stat_mod_duration_turns, v_a_ability_cfg.stat_mod_max_uses,
         v_a_ability_cfg.heal_dot_config_amount, v_a_ability_cfg.heal_dot_config_turns, v_a_ability_cfg.heal_dot_config_type, v_a_ability_cfg.heal_dot_config_percent, v_a_ability_cfg.cancel_heal_duration, v_a_ability_cfg.percent_hp_damage_percent,
         v_a_ability_cfg.stat_mod_type_filter, v_a_ability_cfg.prevention_duration,
         v_a_ability_cfg.keep_going_turns, v_a_ability_cfg.keep_going_until_fail, v_a_ability_cfg.keep_going_bonus_type, v_a_ability_cfg.keep_going_bonus_flat, v_a_ability_cfg.keep_going_bonus_percent,
         v_a_ability_cfg.heal_dot_until_awake, v_a_ability_cfg.ignore_status_block,
         v_a_ability_cfg.weather_id, v_a_ability_cfg.weather_chance,
         v_a_ability_cfg.stat_mod_weather_condition, v_a_ability_cfg.stat_mod_weather_id
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_a_ability_nom;
  -- Effets ajoutés en dernier (dégâts/vol de vie persistants, perce-immunité,
  -- statut exigé, condition de poids, purges) — même ligne de règle.
  SELECT damage_dot_amount, damage_dot_duration_turns, damage_dot_type, damage_dot_percent,
         leech_dot_amount, leech_dot_duration_turns, leech_dot_type, leech_dot_percent,
         pierce_immunity_type, pierce_immunity_turns, requires_target_status,
         bonus_damage_weight_target, bonus_damage_weight_comparison, bonus_damage_weight_percent,
         clear_damage_dot, clear_weather, cure_status,
         status_dot_status, status_dot_chance, status_dot_duration_turns, percent_hp_damage_basis
    INTO v_a_ability_cfg.damage_dot_config_amount, v_a_ability_cfg.damage_dot_config_turns, v_a_ability_cfg.damage_dot_config_type, v_a_ability_cfg.damage_dot_config_percent,
         v_a_ability_cfg.leech_dot_config_amount, v_a_ability_cfg.leech_dot_config_turns, v_a_ability_cfg.leech_dot_config_type, v_a_ability_cfg.leech_dot_config_percent,
         v_a_ability_cfg.pierce_immunity_type, v_a_ability_cfg.pierce_immunity_turns, v_a_ability_cfg.requires_target_status,
         v_a_ability_cfg.bonus_weight_target, v_a_ability_cfg.bonus_weight_comparison, v_a_ability_cfg.bonus_weight_percent,
         v_a_ability_cfg.clear_damage_dot, v_a_ability_cfg.clear_weather, v_a_ability_cfg.cure_status,
         v_a_ability_cfg.status_dot_config_status, v_a_ability_cfg.status_dot_config_chance, v_a_ability_cfg.status_dot_config_turns,
         v_a_ability_cfg.percent_hp_damage_basis
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
         stat_mod_target, stat_mod_direction, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block,
         weather_id, weather_chance, stat_mod_weather_condition, stat_mod_weather_id
    INTO v_d_ability_cfg.turn_effect, v_d_ability_cfg.repeat_max, v_d_ability_cfg.heal_type, v_d_ability_cfg.heal_amount, v_d_ability_cfg.heal_percent, v_d_ability_cfg.status_reversed,
         v_d_ability_cfg.recoil_type, v_d_ability_cfg.recoil_min, v_d_ability_cfg.recoil_max, v_d_ability_cfg.recoil_percent, v_d_ability_cfg.invuln_grant,
         v_d_ability_cfg.bonus_type, v_d_ability_cfg.bonus_multiplier, v_d_ability_cfg.bonus_flat, v_d_ability_cfg.bonus_min, v_d_ability_cfg.bonus_max,
         v_d_ability_cfg.bonus_condition, v_d_ability_cfg.bonus_dice_value, v_d_ability_cfg.bonus_status_filter,
         v_d_ability_cfg.stat_mod_target, v_d_ability_cfg.stat_mod_direction, v_d_ability_cfg.stat_mod_stat, v_d_ability_cfg.stat_mod_value_type, v_d_ability_cfg.stat_mod_flat, v_d_ability_cfg.stat_mod_min, v_d_ability_cfg.stat_mod_max, v_d_ability_cfg.stat_mod_percent,
         v_d_ability_cfg.stat_mod_duration_type, v_d_ability_cfg.stat_mod_duration_turns, v_d_ability_cfg.stat_mod_max_uses,
         v_d_ability_cfg.heal_dot_config_amount, v_d_ability_cfg.heal_dot_config_turns, v_d_ability_cfg.heal_dot_config_type, v_d_ability_cfg.heal_dot_config_percent, v_d_ability_cfg.cancel_heal_duration, v_d_ability_cfg.percent_hp_damage_percent,
         v_d_ability_cfg.stat_mod_type_filter, v_d_ability_cfg.prevention_duration,
         v_d_ability_cfg.keep_going_turns, v_d_ability_cfg.keep_going_until_fail, v_d_ability_cfg.keep_going_bonus_type, v_d_ability_cfg.keep_going_bonus_flat, v_d_ability_cfg.keep_going_bonus_percent,
         v_d_ability_cfg.heal_dot_until_awake, v_d_ability_cfg.ignore_status_block,
         v_d_ability_cfg.weather_id, v_d_ability_cfg.weather_chance,
         v_d_ability_cfg.stat_mod_weather_condition, v_d_ability_cfg.stat_mod_weather_id
    FROM autobattle_ability_rules WHERE attack_nom = v_d_ability_nom_round;
  -- Voir le même complément côté attaquant juste au-dessus.
  SELECT damage_dot_amount, damage_dot_duration_turns, damage_dot_type, damage_dot_percent,
         leech_dot_amount, leech_dot_duration_turns, leech_dot_type, leech_dot_percent,
         pierce_immunity_type, pierce_immunity_turns, requires_target_status,
         bonus_damage_weight_target, bonus_damage_weight_comparison, bonus_damage_weight_percent,
         clear_damage_dot, clear_weather, cure_status,
         status_dot_status, status_dot_chance, status_dot_duration_turns, percent_hp_damage_basis
    INTO v_d_ability_cfg.damage_dot_config_amount, v_d_ability_cfg.damage_dot_config_turns, v_d_ability_cfg.damage_dot_config_type, v_d_ability_cfg.damage_dot_config_percent,
         v_d_ability_cfg.leech_dot_config_amount, v_d_ability_cfg.leech_dot_config_turns, v_d_ability_cfg.leech_dot_config_type, v_d_ability_cfg.leech_dot_config_percent,
         v_d_ability_cfg.pierce_immunity_type, v_d_ability_cfg.pierce_immunity_turns, v_d_ability_cfg.requires_target_status,
         v_d_ability_cfg.bonus_weight_target, v_d_ability_cfg.bonus_weight_comparison, v_d_ability_cfg.bonus_weight_percent,
         v_d_ability_cfg.clear_damage_dot, v_d_ability_cfg.clear_weather, v_d_ability_cfg.cure_status,
         v_d_ability_cfg.status_dot_config_status, v_d_ability_cfg.status_dot_config_chance, v_d_ability_cfg.status_dot_config_turns,
         v_d_ability_cfg.percent_hp_damage_basis
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
    v_a_state, v_d_state, v_a_ability_cfg, v_d_ability_cfg, v_precision_enabled,
    -- Talents d'espèce : celle du pokémon de l'attaquant, et celle FIGÉE sur le
    -- défi pour le défenseur (pvp_challenges.pokemon_nom, pas une ligne
    -- player_pokemon vivante). _vs : filtre 'cancel_talents', à repasser à
    -- CHAQUE round puisque les listes sont re-résolues ici.
    autobattle_talents_vs(v_pp.pokemon_nom, v_challenge.pokemon_nom, v_talents_enabled),
    autobattle_talents_vs(v_challenge.pokemon_nom, v_pp.pokemon_nom, v_talents_enabled),
    -- Météo : id persisté sur la ligne de combat, bascule du mode, et types
    -- d'espèce des deux camps (le PvP n'a jamais géré le talent 'transform',
    -- les types sont donc ceux des espèces telles quelles).
    v_row.weather_id, v_weather_enabled, v_a_species.type, v_d_species.type,
    -- Poids des deux espèces (voir la condition de dégâts 'weight_ratio').
    v_a_species.poids, v_d_species.poids
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
      -- Voir autobattle_resolve_manual_round : capacité soumise mais jamais
      -- jouée (le défenseur a ouvert le round et gagné une action
      -- supplémentaire), réimposée au round suivant.
      WHEN NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_round_result.turns) t WHERE t ->> 'attacker' = 'player')
        THEN v_effective_a_ability_nom
      WHEN (v_round_result.player_state).preparing THEN (v_round_result.player_state).preparing_ability_nom
      WHEN (v_round_result.player_state).skip_pending THEN v_effective_a_ability_nom
      WHEN (v_round_result.player_state).keep_going_ability_nom IS NOT NULL THEN (v_round_result.player_state).keep_going_ability_nom
      ELSE NULL END,
    -- Perce-immunité encore actif au prochain tour côté joueur (voir le même
    -- champ dans autobattle_resolve_manual_round).
    'player_pierce_immunity_type', CASE
      WHEN (v_round_result.player_state).pierce_immunity_expires IS NOT NULL
       AND (v_round_result.player_state).pierce_immunity_expires >= v_round_result.round_no + 1
        THEN (v_round_result.player_state).pierce_immunity_type ELSE NULL END
  );

  IF v_round_result.outcome IS NULL THEN
    UPDATE pvp_battles SET
      turn_no = v_round_result.turn_no, round_no = v_round_result.round_no,
      attacker_hp = (v_round_result.player_state).hp, defender_hp = (v_round_result.opponent_state).hp,
      attacker_status = (v_round_result.player_state).status, defender_status = (v_round_result.opponent_state).status,
      attacker_damage_mods = (v_round_result.player_state).damage_mods, attacker_precision_mods = (v_round_result.player_state).precision_mods,
      defender_damage_mods = (v_round_result.opponent_state).damage_mods, defender_precision_mods = (v_round_result.opponent_state).precision_mods,
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
      attacker_heal_dot_until_awake = COALESCE((v_round_result.player_state).heal_dot_until_awake, false), defender_heal_dot_until_awake = COALESCE((v_round_result.opponent_state).heal_dot_until_awake, false),
      attacker_keep_going_ability_nom = (v_round_result.player_state).keep_going_ability_nom, defender_keep_going_ability_nom = (v_round_result.opponent_state).keep_going_ability_nom,
      attacker_keep_going_remaining = COALESCE((v_round_result.player_state).keep_going_remaining, 0), defender_keep_going_remaining = COALESCE((v_round_result.opponent_state).keep_going_remaining, 0),
      attacker_keep_going_count = COALESCE((v_round_result.player_state).keep_going_count, 0), defender_keep_going_count = COALESCE((v_round_result.opponent_state).keep_going_count, 0),
      attacker_talent_state = COALESCE((v_round_result.player_state).talent_state, '[]'::jsonb), defender_talent_state = COALESCE((v_round_result.opponent_state).talent_state, '[]'::jsonb),
      -- Effets persistants offensifs subis et perce-immunité accordé.
      attacker_damage_dot_amount = (v_round_result.player_state).damage_dot_amount, attacker_damage_dot_expires = (v_round_result.player_state).damage_dot_expires,
      defender_damage_dot_amount = (v_round_result.opponent_state).damage_dot_amount, defender_damage_dot_expires = (v_round_result.opponent_state).damage_dot_expires,
      attacker_leech_dot_amount = (v_round_result.player_state).leech_dot_amount, attacker_leech_dot_expires = (v_round_result.player_state).leech_dot_expires,
      defender_leech_dot_amount = (v_round_result.opponent_state).leech_dot_amount, defender_leech_dot_expires = (v_round_result.opponent_state).leech_dot_expires,
      attacker_status_dot_status = (v_round_result.player_state).status_dot_status, attacker_status_dot_chance = (v_round_result.player_state).status_dot_chance,
      attacker_status_dot_expires = (v_round_result.player_state).status_dot_expires,
      defender_status_dot_status = (v_round_result.opponent_state).status_dot_status, defender_status_dot_chance = (v_round_result.opponent_state).status_dot_chance,
      defender_status_dot_expires = (v_round_result.opponent_state).status_dot_expires,
      attacker_pierce_immunity_type = (v_round_result.player_state).pierce_immunity_type, attacker_pierce_immunity_expires = (v_round_result.player_state).pierce_immunity_expires,
      defender_pierce_immunity_type = (v_round_result.opponent_state).pierce_immunity_type, defender_pierce_immunity_expires = (v_round_result.opponent_state).pierce_immunity_expires,
      -- Le camp qui a gagné une action supplémentaire reprend la main au début
      -- du round suivant (voir autobattle_round_result.next_first_attacker).
      first_attacker = CASE WHEN COALESCE(v_round_result.next_first_attacker, 'player') = 'player' THEN 'attacker' ELSE 'defender' END,
      defender_ability_cycle_index = v_d_ability_cycle_index,
      attacker_stat_mod_uses = (v_round_result.player_state).stat_mod_uses, defender_stat_mod_uses = (v_round_result.opponent_state).stat_mod_uses,
      weather_id = v_round_result.weather_id,
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

GRANT EXECUTE ON FUNCTION pvp_resolve_round(bigint, bigint, bigint, text, uuid) TO anon, authenticated;


-- pvp_trial_resolve_round ------------------------------------------------------------------
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
  v_talents_enabled        boolean;
  v_weather_enabled        boolean;
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
  ELSIF v_row.attacker_keep_going_ability_nom IS NOT NULL THEN
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

  -- Super efficace : TYPE DE LA CAPACITÉ jouée vs TYPE DU DÉFENSEUR (voir
  -- type_super_effective) — plus les colonnes super_efficace_1..4 de l'espèce,
  -- et plus de condition « la capacité doit être du type de son lanceur ».
  -- L'immunité de type (type_no_effect) est gérée par le core, qui reçoit déjà
  -- les deux types d'espèce.
  v_a_type_bonus := type_super_effective(v_ability.type, v_d_species.type);
  v_a_damage_species_xp := COALESCE(v_a_species.degats_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'DMG');
  v_a_damage := v_a_damage_species_xp * (CASE WHEN v_a_type_bonus THEN 2 ELSE 1 END) + COALESCE(v_ability.degats_base, 0);

  -- Le pantin n'a pas de "dégâts d'espèce+XP" (n'existe dans aucun roster,
  -- pas de progression) : ses dégâts viennent UNIQUEMENT de la capacité
  -- choisie par l'admin (censée être "anodine") — voir pvp_config.trial_ability_nom.
  -- Même règle côté défenseur (type de SA capacité vs type de l'attaquant).
  v_d_type_bonus := type_super_effective(v_d_ability.type, v_a_species.type);
  v_d_damage := (CASE WHEN v_d_type_bonus THEN 2 ELSE 1 END) * 0 + COALESCE(v_d_ability.degats_base, 0);

  SELECT precision_enabled, talents_enabled, weather_enabled
    INTO v_precision_enabled, v_talents_enabled, v_weather_enabled FROM pvp_config WHERE id = 1;
  v_precision_enabled := COALESCE(v_precision_enabled, true);
  v_talents_enabled := COALESCE(v_talents_enabled, true);
  v_weather_enabled := COALESCE(v_weather_enabled, true);

  v_a_state.hp := v_row.attacker_hp;
  v_a_state.max_hp := v_row.attacker_max_hp;
  v_a_state.status := v_row.attacker_status;
  v_a_state.damage_mods := v_row.attacker_damage_mods;
  v_a_state.precision_mods := v_row.attacker_precision_mods;
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
  v_a_state.heal_dot_until_awake := v_row.attacker_heal_dot_until_awake;
  v_a_state.keep_going_ability_nom := v_row.attacker_keep_going_ability_nom;
  v_a_state.keep_going_remaining := v_row.attacker_keep_going_remaining;
  v_a_state.keep_going_count := v_row.attacker_keep_going_count;
  v_a_state.talent_state := COALESCE(v_row.attacker_talent_state, '[]'::jsonb);
  -- Effets persistants offensifs subis et perce-immunité accordé (voir les
  -- mêmes colonnes côté Combat Manuel, autobattle_resolve_manual_round).
  v_a_state.damage_dot_amount := v_row.attacker_damage_dot_amount;
  v_a_state.damage_dot_expires := v_row.attacker_damage_dot_expires;
  v_a_state.leech_dot_amount := v_row.attacker_leech_dot_amount;
  v_a_state.leech_dot_expires := v_row.attacker_leech_dot_expires;
  v_a_state.status_dot_status := v_row.attacker_status_dot_status;
  v_a_state.status_dot_chance := v_row.attacker_status_dot_chance;
  v_a_state.status_dot_expires := v_row.attacker_status_dot_expires;
  v_a_state.pierce_immunity_type := v_row.attacker_pierce_immunity_type;
  v_a_state.pierce_immunity_expires := v_row.attacker_pierce_immunity_expires;

  v_d_state.hp := v_row.defender_hp;
  v_d_state.max_hp := v_row.dummy_max_hp;
  v_d_state.status := v_row.defender_status;
  v_d_state.damage_mods := v_row.defender_damage_mods;
  v_d_state.precision_mods := v_row.defender_precision_mods;
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
  v_d_state.heal_dot_until_awake := v_row.defender_heal_dot_until_awake;
  v_d_state.keep_going_ability_nom := v_row.defender_keep_going_ability_nom;
  v_d_state.keep_going_remaining := v_row.defender_keep_going_remaining;
  v_d_state.keep_going_count := v_row.defender_keep_going_count;
  v_d_state.talent_state := COALESCE(v_row.defender_talent_state, '[]'::jsonb);
  v_d_state.damage_dot_amount := v_row.defender_damage_dot_amount;
  v_d_state.damage_dot_expires := v_row.defender_damage_dot_expires;
  v_d_state.leech_dot_amount := v_row.defender_leech_dot_amount;
  v_d_state.leech_dot_expires := v_row.defender_leech_dot_expires;
  v_d_state.status_dot_status := v_row.defender_status_dot_status;
  v_d_state.status_dot_chance := v_row.defender_status_dot_chance;
  v_d_state.status_dot_expires := v_row.defender_status_dot_expires;
  v_d_state.pierce_immunity_type := v_row.defender_pierce_immunity_type;
  v_d_state.pierce_immunity_expires := v_row.defender_pierce_immunity_expires;

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_direction, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block,
         weather_id, weather_chance, stat_mod_weather_condition, stat_mod_weather_id
    INTO v_a_ability_cfg.turn_effect, v_a_ability_cfg.repeat_max, v_a_ability_cfg.heal_type, v_a_ability_cfg.heal_amount, v_a_ability_cfg.heal_percent, v_a_ability_cfg.status_reversed,
         v_a_ability_cfg.recoil_type, v_a_ability_cfg.recoil_min, v_a_ability_cfg.recoil_max, v_a_ability_cfg.recoil_percent, v_a_ability_cfg.invuln_grant,
         v_a_ability_cfg.bonus_type, v_a_ability_cfg.bonus_multiplier, v_a_ability_cfg.bonus_flat, v_a_ability_cfg.bonus_min, v_a_ability_cfg.bonus_max,
         v_a_ability_cfg.bonus_condition, v_a_ability_cfg.bonus_dice_value, v_a_ability_cfg.bonus_status_filter,
         v_a_ability_cfg.stat_mod_target, v_a_ability_cfg.stat_mod_direction, v_a_ability_cfg.stat_mod_stat, v_a_ability_cfg.stat_mod_value_type, v_a_ability_cfg.stat_mod_flat, v_a_ability_cfg.stat_mod_min, v_a_ability_cfg.stat_mod_max, v_a_ability_cfg.stat_mod_percent,
         v_a_ability_cfg.stat_mod_duration_type, v_a_ability_cfg.stat_mod_duration_turns, v_a_ability_cfg.stat_mod_max_uses,
         v_a_ability_cfg.heal_dot_config_amount, v_a_ability_cfg.heal_dot_config_turns, v_a_ability_cfg.heal_dot_config_type, v_a_ability_cfg.heal_dot_config_percent, v_a_ability_cfg.cancel_heal_duration, v_a_ability_cfg.percent_hp_damage_percent,
         v_a_ability_cfg.stat_mod_type_filter, v_a_ability_cfg.prevention_duration,
         v_a_ability_cfg.keep_going_turns, v_a_ability_cfg.keep_going_until_fail, v_a_ability_cfg.keep_going_bonus_type, v_a_ability_cfg.keep_going_bonus_flat, v_a_ability_cfg.keep_going_bonus_percent,
         v_a_ability_cfg.heal_dot_until_awake, v_a_ability_cfg.ignore_status_block,
         v_a_ability_cfg.weather_id, v_a_ability_cfg.weather_chance,
         v_a_ability_cfg.stat_mod_weather_condition, v_a_ability_cfg.stat_mod_weather_id
    FROM autobattle_ability_rules WHERE attack_nom = v_a_ability_nom_round;
  -- Effets ajoutés en dernier (dégâts/vol de vie persistants, perce-immunité,
  -- statut exigé, condition de poids, purges) — même ligne de règle.
  SELECT damage_dot_amount, damage_dot_duration_turns, damage_dot_type, damage_dot_percent,
         leech_dot_amount, leech_dot_duration_turns, leech_dot_type, leech_dot_percent,
         pierce_immunity_type, pierce_immunity_turns, requires_target_status,
         bonus_damage_weight_target, bonus_damage_weight_comparison, bonus_damage_weight_percent,
         clear_damage_dot, clear_weather, cure_status,
         status_dot_status, status_dot_chance, status_dot_duration_turns, percent_hp_damage_basis
    INTO v_a_ability_cfg.damage_dot_config_amount, v_a_ability_cfg.damage_dot_config_turns, v_a_ability_cfg.damage_dot_config_type, v_a_ability_cfg.damage_dot_config_percent,
         v_a_ability_cfg.leech_dot_config_amount, v_a_ability_cfg.leech_dot_config_turns, v_a_ability_cfg.leech_dot_config_type, v_a_ability_cfg.leech_dot_config_percent,
         v_a_ability_cfg.pierce_immunity_type, v_a_ability_cfg.pierce_immunity_turns, v_a_ability_cfg.requires_target_status,
         v_a_ability_cfg.bonus_weight_target, v_a_ability_cfg.bonus_weight_comparison, v_a_ability_cfg.bonus_weight_percent,
         v_a_ability_cfg.clear_damage_dot, v_a_ability_cfg.clear_weather, v_a_ability_cfg.cure_status,
         v_a_ability_cfg.status_dot_config_status, v_a_ability_cfg.status_dot_config_chance, v_a_ability_cfg.status_dot_config_turns,
         v_a_ability_cfg.percent_hp_damage_basis
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
         stat_mod_target, stat_mod_direction, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block,
         weather_id, weather_chance, stat_mod_weather_condition, stat_mod_weather_id
    INTO v_d_ability_cfg.turn_effect, v_d_ability_cfg.repeat_max, v_d_ability_cfg.heal_type, v_d_ability_cfg.heal_amount, v_d_ability_cfg.heal_percent, v_d_ability_cfg.status_reversed,
         v_d_ability_cfg.recoil_type, v_d_ability_cfg.recoil_min, v_d_ability_cfg.recoil_max, v_d_ability_cfg.recoil_percent, v_d_ability_cfg.invuln_grant,
         v_d_ability_cfg.bonus_type, v_d_ability_cfg.bonus_multiplier, v_d_ability_cfg.bonus_flat, v_d_ability_cfg.bonus_min, v_d_ability_cfg.bonus_max,
         v_d_ability_cfg.bonus_condition, v_d_ability_cfg.bonus_dice_value, v_d_ability_cfg.bonus_status_filter,
         v_d_ability_cfg.stat_mod_target, v_d_ability_cfg.stat_mod_direction, v_d_ability_cfg.stat_mod_stat, v_d_ability_cfg.stat_mod_value_type, v_d_ability_cfg.stat_mod_flat, v_d_ability_cfg.stat_mod_min, v_d_ability_cfg.stat_mod_max, v_d_ability_cfg.stat_mod_percent,
         v_d_ability_cfg.stat_mod_duration_type, v_d_ability_cfg.stat_mod_duration_turns, v_d_ability_cfg.stat_mod_max_uses,
         v_d_ability_cfg.heal_dot_config_amount, v_d_ability_cfg.heal_dot_config_turns, v_d_ability_cfg.heal_dot_config_type, v_d_ability_cfg.heal_dot_config_percent, v_d_ability_cfg.cancel_heal_duration, v_d_ability_cfg.percent_hp_damage_percent,
         v_d_ability_cfg.stat_mod_type_filter, v_d_ability_cfg.prevention_duration,
         v_d_ability_cfg.keep_going_turns, v_d_ability_cfg.keep_going_until_fail, v_d_ability_cfg.keep_going_bonus_type, v_d_ability_cfg.keep_going_bonus_flat, v_d_ability_cfg.keep_going_bonus_percent,
         v_d_ability_cfg.heal_dot_until_awake, v_d_ability_cfg.ignore_status_block,
         v_d_ability_cfg.weather_id, v_d_ability_cfg.weather_chance,
         v_d_ability_cfg.stat_mod_weather_condition, v_d_ability_cfg.stat_mod_weather_id
    FROM autobattle_ability_rules WHERE attack_nom = v_row.dummy_ability_nom;
  -- Voir le même complément côté attaquant juste au-dessus.
  SELECT damage_dot_amount, damage_dot_duration_turns, damage_dot_type, damage_dot_percent,
         leech_dot_amount, leech_dot_duration_turns, leech_dot_type, leech_dot_percent,
         pierce_immunity_type, pierce_immunity_turns, requires_target_status,
         bonus_damage_weight_target, bonus_damage_weight_comparison, bonus_damage_weight_percent,
         clear_damage_dot, clear_weather, cure_status,
         status_dot_status, status_dot_chance, status_dot_duration_turns, percent_hp_damage_basis
    INTO v_d_ability_cfg.damage_dot_config_amount, v_d_ability_cfg.damage_dot_config_turns, v_d_ability_cfg.damage_dot_config_type, v_d_ability_cfg.damage_dot_config_percent,
         v_d_ability_cfg.leech_dot_config_amount, v_d_ability_cfg.leech_dot_config_turns, v_d_ability_cfg.leech_dot_config_type, v_d_ability_cfg.leech_dot_config_percent,
         v_d_ability_cfg.pierce_immunity_type, v_d_ability_cfg.pierce_immunity_turns, v_d_ability_cfg.requires_target_status,
         v_d_ability_cfg.bonus_weight_target, v_d_ability_cfg.bonus_weight_comparison, v_d_ability_cfg.bonus_weight_percent,
         v_d_ability_cfg.clear_damage_dot, v_d_ability_cfg.clear_weather, v_d_ability_cfg.cure_status,
         v_d_ability_cfg.status_dot_config_status, v_d_ability_cfg.status_dot_config_chance, v_d_ability_cfg.status_dot_config_turns,
         v_d_ability_cfg.percent_hp_damage_basis
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
    v_a_state, v_d_state, v_a_ability_cfg, v_d_ability_cfg, v_precision_enabled,
    -- Talents d'espèce : le pantin d'essai utilise ceux de l'espèce snapshotée
    -- sur la ligne d'essai (pvp_trial_battles.dummy_pokemon_nom). _vs : filtre
    -- 'cancel_talents', voir pvp_resolve_round.
    autobattle_talents_vs(v_pp.pokemon_nom, v_row.dummy_pokemon_nom, v_talents_enabled),
    autobattle_talents_vs(v_row.dummy_pokemon_nom, v_pp.pokemon_nom, v_talents_enabled),
    -- Météo : voir pvp_resolve_round, même mécanique.
    v_row.weather_id, v_weather_enabled, v_a_species.type, v_d_species.type,
    -- Poids des deux espèces (voir la condition de dégâts 'weight_ratio').
    v_a_species.poids, v_d_species.poids
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
    'player_ability_nom', v_a_ability_nom_round,
    -- Voir le même champ dans autobattle_resolve_manual_round.
    'player_pierce_immunity_type', CASE
      WHEN (v_round_result.player_state).pierce_immunity_expires IS NOT NULL
       AND (v_round_result.player_state).pierce_immunity_expires >= v_round_result.round_no + 1
        THEN (v_round_result.player_state).pierce_immunity_type ELSE NULL END
  );

  IF v_round_result.outcome IS NULL THEN
    UPDATE pvp_trial_battles SET
      turn_no = v_round_result.turn_no, round_no = v_round_result.round_no,
      attacker_hp = (v_round_result.player_state).hp, defender_hp = (v_round_result.opponent_state).hp,
      attacker_status = (v_round_result.player_state).status, defender_status = (v_round_result.opponent_state).status,
      attacker_damage_mods = (v_round_result.player_state).damage_mods, attacker_precision_mods = (v_round_result.player_state).precision_mods,
      defender_damage_mods = (v_round_result.opponent_state).damage_mods, defender_precision_mods = (v_round_result.opponent_state).precision_mods,
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
      attacker_heal_dot_until_awake = COALESCE((v_round_result.player_state).heal_dot_until_awake, false), defender_heal_dot_until_awake = COALESCE((v_round_result.opponent_state).heal_dot_until_awake, false),
      attacker_keep_going_ability_nom = (v_round_result.player_state).keep_going_ability_nom, defender_keep_going_ability_nom = (v_round_result.opponent_state).keep_going_ability_nom,
      attacker_keep_going_remaining = COALESCE((v_round_result.player_state).keep_going_remaining, 0), defender_keep_going_remaining = COALESCE((v_round_result.opponent_state).keep_going_remaining, 0),
      attacker_keep_going_count = COALESCE((v_round_result.player_state).keep_going_count, 0), defender_keep_going_count = COALESCE((v_round_result.opponent_state).keep_going_count, 0),
      attacker_talent_state = COALESCE((v_round_result.player_state).talent_state, '[]'::jsonb), defender_talent_state = COALESCE((v_round_result.opponent_state).talent_state, '[]'::jsonb),
      -- Effets persistants offensifs subis et perce-immunité accordé.
      attacker_damage_dot_amount = (v_round_result.player_state).damage_dot_amount, attacker_damage_dot_expires = (v_round_result.player_state).damage_dot_expires,
      defender_damage_dot_amount = (v_round_result.opponent_state).damage_dot_amount, defender_damage_dot_expires = (v_round_result.opponent_state).damage_dot_expires,
      attacker_leech_dot_amount = (v_round_result.player_state).leech_dot_amount, attacker_leech_dot_expires = (v_round_result.player_state).leech_dot_expires,
      defender_leech_dot_amount = (v_round_result.opponent_state).leech_dot_amount, defender_leech_dot_expires = (v_round_result.opponent_state).leech_dot_expires,
      attacker_status_dot_status = (v_round_result.player_state).status_dot_status, attacker_status_dot_chance = (v_round_result.player_state).status_dot_chance,
      attacker_status_dot_expires = (v_round_result.player_state).status_dot_expires,
      defender_status_dot_status = (v_round_result.opponent_state).status_dot_status, defender_status_dot_chance = (v_round_result.opponent_state).status_dot_chance,
      defender_status_dot_expires = (v_round_result.opponent_state).status_dot_expires,
      attacker_pierce_immunity_type = (v_round_result.player_state).pierce_immunity_type, attacker_pierce_immunity_expires = (v_round_result.player_state).pierce_immunity_expires,
      defender_pierce_immunity_type = (v_round_result.opponent_state).pierce_immunity_type, defender_pierce_immunity_expires = (v_round_result.opponent_state).pierce_immunity_expires,
      -- Le camp qui a gagné une action supplémentaire reprend la main au début
      -- du round suivant (voir autobattle_round_result.next_first_attacker).
      first_attacker = CASE WHEN COALESCE(v_round_result.next_first_attacker, 'player') = 'player' THEN 'attacker' ELSE 'defender' END,
      attacker_ability_cycle_index = v_a_ability_cycle_index,
      attacker_stat_mod_uses = (v_round_result.player_state).stat_mod_uses, defender_stat_mod_uses = (v_round_result.opponent_state).stat_mod_uses,
      weather_id = v_round_result.weather_id,
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

GRANT EXECUTE ON FUNCTION pvp_trial_resolve_round(bigint, uuid) TO anon, authenticated;
