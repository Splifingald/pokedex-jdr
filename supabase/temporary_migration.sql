-- ============================================================
-- MIGRATION TEMPORAIRE — Conditions de déverrouillage des parcours (JcE)
-- ============================================================
-- À COLLER TEL QUEL dans le SQL Editor de Supabase (fichier de travail
-- régénéré à chaque tâche — voir CLAUDE.md). Les mêmes changements sont déjà
-- dans supabase/schema.sql, qui reste la source de vérité.
--
-- Entièrement idempotent : à jouer même si une version précédente de cette
-- migration a déjà été passée (la colonne target_variant_id et le type de
-- condition 'variant_completed' sont des ajouts postérieurs).
--
-- Ce qui est ajouté : un parcours de Combat Auto peut désormais exiger des
-- conditions EN PLUS de sa bascule d'activation. La bascule reste le premier
-- filtre (parcours désactivé = jamais accessible) ; activée, elle est suivie
-- des conditions, qui doivent TOUTES être remplies (ET) :
--   * objet possédé (une ligne par objet, aucune quantité exigée) ;
--   * N pokémon découverts au Pokédex (Pokédex global, partagé) ;
--   * N pokémon DE CE PARCOURS découverts (liste déduite automatiquement des
--     niveaux du parcours, rien à saisir) ;
--   * un autre parcours TERMINÉ par ce joueur (tous ses niveaux gagnés).
-- Aucune condition = parcours disponible dès qu'il est activé (cas actuel de
-- tous les parcours existants : cette migration ne change donc rien tant que
-- l'admin n'ajoute pas de condition).
--
-- Rien n'est mémorisé : l'état est recalculé à chaque lecture, donc consommer
-- un objet requis referme le parcours. Côté joueur, un parcours verrouillé est
-- MASQUÉ de la liste.
--
-- Contenu : la table autobattle_variant_unlock_conditions (+ RLS + Realtime),
-- la fonction autobattle_variant_unlocked, et les deux fonctions de combat qui
-- l'appellent — autobattle_resolve_battle (Combat Auto) et
-- autobattle_start_manual_battle (démarrage d'un Combat Manuel), qui renvoient
-- désormais le statut variant_locked. autobattle_resolve_manual_round n'est
-- VOLONTAIREMENT pas gardée : un combat manuel déjà engagé doit toujours
-- pouvoir se terminer.
-- ============================================================

-- Conditions de DÉVERROUILLAGE du parcours, EN PLUS de la bascule `enabled`
-- (autobattle_variants.enabled) : la bascule reste le premier filtre — un
-- parcours désactivé n'est jamais déverrouillable, quelles que soient ses
-- conditions. Un parcours activé SANS aucune ligne ici est immédiatement
-- disponible (cas par défaut).
--
-- Plusieurs lignes = ET (toutes doivent être remplies), et on peut mélanger
-- les types librement. condition_type :
--   'item_owned'            le joueur possède l'objet item_nom (quantité > 0,
--                           la quantité exacte n'est jamais demandée) — une
--                           ligne par objet exigé.
--   'pokedex_count'         au moins `amount` pokémon découverts au Pokédex.
--                           Le Pokédex est GLOBAL (discovered_pokemon, partagé
--                           par tous les joueurs) : cette condition l'est donc
--                           aussi, contrairement à 'item_owned' qui dépend de
--                           l'inventaire du joueur.
--   'variant_pokedex_count' idem mais restreint aux espèces figurant dans les
--                           niveaux DE CE PARCOURS (autobattle_levels.
--                           opponent_pokemon_nom) — aucune saisie d'espèces :
--                           la liste suit automatiquement les niveaux.
--   'variant_completed'     le joueur a TERMINÉ le parcours target_variant_id
--                           (tous ses niveaux, autobattle_player_variant_
--                           progress.variant_completed) — condition PAR JOUEUR,
--                           comme 'item_owned'.
--
-- Jamais mémorisé : l'état verrouillé/déverrouillé est recalculé à chaque
-- lecture (voir autobattle_variant_unlocked), donc consommer un objet requis
-- referme le parcours. Côté joueur, un parcours verrouillé est masqué de la
-- liste, pas grisé (voir AutoBattlePopup).
CREATE TABLE IF NOT EXISTS autobattle_variant_unlock_conditions (
  id             bigserial PRIMARY KEY,
  variant_id     bigint NOT NULL REFERENCES autobattle_variants(id) ON DELETE CASCADE,
  condition_type text NOT NULL,
  item_nom       text,
  amount         integer,
  target_variant_id bigint REFERENCES autobattle_variants(id) ON DELETE CASCADE,
  sort_order     integer NOT NULL DEFAULT 0,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_autobattle_variant_unlock_conditions_variant_id
  ON autobattle_variant_unlock_conditions(variant_id);
-- Parcours EXIGÉ par une condition 'variant_completed'. ON DELETE CASCADE :
-- supprimer le parcours exigé emporte la condition — une exigence sans cible
-- serait ininterprétable (et, laissée à NULL, déverrouillerait silencieusement
-- le parcours qu'elle protégeait).
ALTER TABLE autobattle_variant_unlock_conditions
  ADD COLUMN IF NOT EXISTS target_variant_id bigint REFERENCES autobattle_variants(id) ON DELETE CASCADE;

ALTER TABLE autobattle_variant_unlock_conditions DROP CONSTRAINT IF EXISTS autobattle_variant_unlock_conditions_type_check;
ALTER TABLE autobattle_variant_unlock_conditions ADD CONSTRAINT autobattle_variant_unlock_conditions_type_check
  CHECK (condition_type IN ('item_owned', 'pokedex_count', 'variant_pokedex_count', 'variant_completed'));
-- Champs obligatoires par type — l'UI admin envoie toujours un groupe
-- cohérent, ces contraintes ne font qu'empêcher une condition inexploitable
-- (un objet vide serait impossible à remplir, un compte NULL toujours rempli).
ALTER TABLE autobattle_variant_unlock_conditions DROP CONSTRAINT IF EXISTS autobattle_variant_unlock_conditions_fields;
ALTER TABLE autobattle_variant_unlock_conditions ADD CONSTRAINT autobattle_variant_unlock_conditions_fields
  CHECK (
    (condition_type = 'item_owned' AND item_nom IS NOT NULL AND item_nom <> '')
    OR (condition_type IN ('pokedex_count', 'variant_pokedex_count') AND amount IS NOT NULL AND amount >= 1)
    -- target_variant_id <> variant_id : un parcours qui exigerait sa propre
    -- complétion serait définitivement inatteignable.
    OR (condition_type = 'variant_completed' AND target_variant_id IS NOT NULL AND target_variant_id <> variant_id)
  );

ALTER TABLE autobattle_variant_unlock_conditions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read autobattle_variant_unlock_conditions" ON autobattle_variant_unlock_conditions;
DROP POLICY IF EXISTS "Public insert autobattle_variant_unlock_conditions" ON autobattle_variant_unlock_conditions;
DROP POLICY IF EXISTS "Public update autobattle_variant_unlock_conditions" ON autobattle_variant_unlock_conditions;
DROP POLICY IF EXISTS "Public delete autobattle_variant_unlock_conditions" ON autobattle_variant_unlock_conditions;
CREATE POLICY "Public read autobattle_variant_unlock_conditions"   ON autobattle_variant_unlock_conditions FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_variant_unlock_conditions" ON autobattle_variant_unlock_conditions FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_variant_unlock_conditions" ON autobattle_variant_unlock_conditions FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete autobattle_variant_unlock_conditions" ON autobattle_variant_unlock_conditions FOR DELETE TO anon USING (true);

-- Diffusion Realtime — comme les autres tables du Combat Auto : l'ajout ou le
-- retrait d'une condition par l'admin se voit sans recharger la page.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
      AND tablename = 'autobattle_variant_unlock_conditions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE autobattle_variant_unlock_conditions;
  END IF;
END $$;

-- Le parcours p_variant_id est-il DÉVERROUILLÉ pour ce joueur ? Ne regarde QUE
-- les conditions (autobattle_variant_unlock_conditions), jamais la bascule
-- `enabled` — les deux gardes sont volontairement distinctes côté appelant.
-- Aucune condition = TRUE (cas par défaut). Toutes les conditions doivent être
-- remplies (ET). Recalculé à chaque appel, rien n'est mémorisé.
CREATE OR REPLACE FUNCTION autobattle_variant_unlocked(p_variant_id bigint, p_player_id bigint)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_cond  record;
  v_count integer;
BEGIN
  FOR v_cond IN
    SELECT * FROM autobattle_variant_unlock_conditions WHERE variant_id = p_variant_id
  LOOP
    IF v_cond.condition_type = 'item_owned' THEN
      -- Possession seule : quantity > 0, aucune quantité exigée.
      IF NOT EXISTS (
        SELECT 1 FROM player_items
        WHERE player_id = p_player_id AND item_nom = v_cond.item_nom AND quantity > 0
      ) THEN
        RETURN false;
      END IF;

    ELSIF v_cond.condition_type = 'pokedex_count' THEN
      -- Jointure sur pokemon : discovered_pokemon référence par NOM sans FK et
      -- peut garder des lignes orphelines après un réimport CSV — on compte ce
      -- que le Pokédex affiche réellement, comme le client.
      SELECT count(*) INTO v_count
        FROM discovered_pokemon d
        JOIN pokemon p ON p.nom = d.pokemon_nom;
      IF v_count < COALESCE(v_cond.amount, 0) THEN
        RETURN false;
      END IF;

    ELSIF v_cond.condition_type = 'variant_completed' THEN
      -- Complétion PAR JOUEUR du parcours exigé (drapeau posé par
      -- autobattle_resolve_battle / autobattle_resolve_manual_round au dernier
      -- niveau gagné). Aucune ligne de progression = parcours jamais joué.
      IF NOT EXISTS (
        SELECT 1 FROM autobattle_player_variant_progress
        WHERE player_id = p_player_id
          AND variant_id = v_cond.target_variant_id
          AND variant_completed = true
      ) THEN
        RETURN false;
      END IF;

    ELSIF v_cond.condition_type = 'variant_pokedex_count' THEN
      -- Espèces DISTINCTES des niveaux du parcours (le même pokémon sur deux
      -- niveaux ne compte qu'une fois, comme le maximum affiché en admin).
      SELECT count(DISTINCT l.opponent_pokemon_nom) INTO v_count
        FROM autobattle_levels l
        JOIN discovered_pokemon d ON d.pokemon_nom = l.opponent_pokemon_nom
       WHERE l.variant_id = p_variant_id
         AND COALESCE(l.opponent_pokemon_nom, '') <> '';
      IF v_count < COALESCE(v_cond.amount, 0) THEN
        RETURN false;
      END IF;
    END IF;
  END LOOP;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION autobattle_variant_unlocked(bigint, bigint) TO anon, authenticated;

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
  -- Type d'espèce PROPRE à chaque camp (Métamorph = celui qu'il a copié) : ce
  -- que la victime « est », et non ce qu'elle affronte — c'est lui qui décide
  -- des immunités de statut de type (autobattle_status_type_immune).
  v_player_self_type     text;
  v_opponent_self_type   text;
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
  -- Conditions de déverrouillage (voir autobattle_variant_unlock_conditions) :
  -- garde SÉPARÉE de `enabled`, et volontairement absente de
  -- autobattle_resolve_manual_round — un combat manuel déjà engagé doit
  -- toujours pouvoir se terminer, même si le joueur consomme entre deux tours
  -- l'objet qui déverrouillait le parcours.
  IF NOT autobattle_variant_unlocked(v_variant.id, p_player_id) THEN
    RETURN jsonb_build_object('status', 'variant_locked');
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
  -- Type PROPRE de chacun : celui du camp d'en face quand il est Métamorph
  -- (mêmes expressions que les ticks de météo plus bas, qui visent déjà le
  -- pokémon lui-même et non sa cible).
  v_player_self_type := CASE WHEN v_is_metamorph THEN v_opponent_species.type ELSE v_player_species.type END;
  v_opponent_self_type := CASE WHEN v_is_opponent_metamorph THEN v_player_species.type ELSE v_opponent_species.type END;
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
        v_player_hp, v_player_max_hp, v_opponent_status, v_player_status, v_opponent_talents, 0, v_weather, v_opponent_self_type);
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
        v_talent_res := autobattle_talent_status_guard(v_opponent_talents, v_opponent_talent_state, 'opponent', v_talent_inflict, v_opponent_hp, 0, v_opponent_self_type);
        v_opponent_talent_state := v_talent_res -> 'state';
        v_turns := v_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_opponent_status := v_talent_inflict;
        END IF;
      END IF;
    ELSE
      v_talent_res := autobattle_talent_act(v_opponent_talents, v_opponent_talent_state, 'opponent', 'battle_start', v_opponent_ability.type,
        v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_player_talents, 0, v_weather, v_player_self_type);
      v_opponent_talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
      -- Voir le même commentaire côté joueur.
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'opponent', v_opponent_hp, 0);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_turns := v_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(v_player_talents, v_player_talent_state, 'player', v_talent_inflict, v_player_hp, 0, v_player_self_type);
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
          v_player_status_dot_status, v_player_status_dot_chance, v_player_talents, v_player_talent_state, v_player_self_type);
        v_player_status := v_dot_res ->> 'status';
        v_player_talent_state := v_dot_res -> 'state';
        v_turns := v_turns || (v_dot_res -> 'turns');
        IF jsonb_array_length(v_dot_res -> 'turns') > 0 THEN v_turn_no := v_turn_no + 1; END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_status_dot_status IS NOT NULL AND v_opponent_status IS NULL THEN
        v_dot_res := autobattle_status_dot_tick('opponent', v_turn_no, v_opponent_hp, v_opponent_status,
          v_opponent_status_dot_status, v_opponent_status_dot_chance, v_opponent_talents, v_opponent_talent_state, v_opponent_self_type);
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
        v_player_hp, v_player_max_hp, v_opponent_status, v_player_status, v_opponent_talents, v_turn_no, v_weather, v_opponent_self_type);
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
        v_talent_res := autobattle_talent_status_guard(v_opponent_talents, v_opponent_talent_state, 'opponent', v_talent_inflict, v_opponent_hp, v_turn_no, v_opponent_self_type);
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
              v_player_hp, v_player_max_hp, v_opponent_status, v_player_status, v_opponent_talents, v_turn_no, v_weather, v_opponent_self_type);
            v_player_talent_state := v_talent_res -> 'state';
            v_turns := v_turns || (v_talent_res -> 'turns');
            v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'player', v_player_hp, v_turn_no);
            v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
            v_turns := v_turns || (v_weather_res -> 'turns');
            v_talent_inflict := v_talent_res ->> 'inflict_status';
            IF v_talent_inflict IS NOT NULL THEN
              v_talent_res := autobattle_talent_status_guard(v_opponent_talents, v_opponent_talent_state, 'opponent', v_talent_inflict, v_opponent_hp, v_turn_no, v_opponent_self_type);
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
              CASE WHEN v_player_status_reversed THEN v_player_hp ELSE v_opponent_hp END, v_turn_no,
              CASE WHEN v_player_status_reversed THEN v_player_self_type ELSE v_opponent_self_type END);
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
        v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_player_talents, v_turn_no, v_weather, v_player_self_type);
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
        v_talent_res := autobattle_talent_status_guard(v_player_talents, v_player_talent_state, 'player', v_talent_inflict, v_player_hp, v_turn_no, v_player_self_type);
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
              v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_player_talents, v_turn_no, v_weather, v_player_self_type);
            v_opponent_talent_state := v_talent_res -> 'state';
            v_turns := v_turns || (v_talent_res -> 'turns');
            v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'opponent', v_opponent_hp, v_turn_no);
            v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
            v_turns := v_turns || (v_weather_res -> 'turns');
            v_talent_inflict := v_talent_res ->> 'inflict_status';
            IF v_talent_inflict IS NOT NULL THEN
              v_talent_res := autobattle_talent_status_guard(v_player_talents, v_player_talent_state, 'player', v_talent_inflict, v_player_hp, v_turn_no, v_player_self_type);
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
              CASE WHEN v_opponent_status_reversed THEN v_opponent_hp ELSE v_player_hp END, v_turn_no,
              CASE WHEN v_opponent_status_reversed THEN v_opponent_self_type ELSE v_player_self_type END);
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

CREATE OR REPLACE FUNCTION autobattle_start_manual_battle(
  p_player_id bigint,
  p_level_id bigint,
  p_player_pokemon_id bigint,
  p_idempotency_key uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_level          record;
  v_variant        record;
  v_progress       record;
  v_pp             record;
  v_player_species record;
  -- Type d'espèce de l'adversaire du niveau : sert aux immunités de statut de
  -- type des talents « à l'entrée en combat » (autobattle_status_type_immune),
  -- le reste du combat étant résolu par autobattle_resolve_manual_round.
  v_opponent_type  text;
  v_row            autobattle_manual_battles%ROWTYPE;
  v_ticket_item_nom text := 'Ticket Combat';
  v_player_max_hp  integer;
  v_first_attacker text;
  v_result         jsonb;
  -- Talents actifs dès le début du combat (voir autobattle_talent_open) :
  -- résolus ICI et pas au 1er tour, pour que leur animation soit jouée AVANT
  -- que le joueur choisisse sa première capacité (voir ManualBattleScreen).
  v_talent_start        jsonb;
  v_talent_res          jsonb;
  v_start_turns         jsonb := '[]'::jsonb;
  v_player_talents      jsonb;
  v_opponent_talents    jsonb;
  v_player_talent_state jsonb;
  v_opponent_talent_state jsonb;
  v_player_status       text;
  v_opponent_status     text;
  v_talent_inflict      text;
  v_side                text;
  v_talents_enabled     boolean;
  -- Météo (voir autobattle_weathers) : un talent 'set_weather' déclenché « à
  -- l'entrée en combat » la pose dès ici, et elle est persistée sur la ligne.
  v_weather_enabled     boolean;
  v_weather             jsonb;
  v_weather_res         jsonb;
BEGIN
  SELECT * INTO v_level FROM autobattle_levels WHERE id = p_level_id;
  IF v_level IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;

  SELECT * INTO v_variant FROM autobattle_variants WHERE id = v_level.variant_id;
  IF v_variant IS NULL OR v_variant.enabled = false THEN
    RETURN jsonb_build_object('status', 'variant_disabled');
  END IF;
  -- Conditions de déverrouillage (voir autobattle_variant_unlock_conditions) :
  -- garde SÉPARÉE de `enabled`, et volontairement absente de
  -- autobattle_resolve_manual_round — un combat manuel déjà engagé doit
  -- toujours pouvoir se terminer, même si le joueur consomme entre deux tours
  -- l'objet qui déverrouillait le parcours.
  IF NOT autobattle_variant_unlocked(v_variant.id, p_player_id) THEN
    RETURN jsonb_build_object('status', 'variant_locked');
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

  SELECT * INTO v_pp FROM player_pokemon WHERE id = p_player_pokemon_id AND player_id = p_player_id;
  IF v_pp IS NULL OR v_pp.in_daycare THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;

  SELECT * INTO v_player_species FROM pokemon WHERE nom = v_pp.pokemon_nom;
  IF v_player_species IS NULL THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;
  SELECT type INTO v_opponent_type FROM pokemon WHERE nom = v_level.opponent_pokemon_nom;

  SELECT * INTO v_row FROM autobattle_manual_battles
    WHERE player_id = p_player_id AND level_id = p_level_id FOR UPDATE;

  -- Rejeu idempotent : redémarrage redemandé (retry réseau) → même réponse,
  -- sans re-tirer first_attacker ni re-débiter de ticket.
  IF v_row.id IS NOT NULL AND v_row.last_idempotency_key = p_idempotency_key THEN
    RETURN v_row.last_result;
  END IF;

  IF v_row.id IS NOT NULL THEN
    DELETE FROM autobattle_manual_battles WHERE id = v_row.id;
  END IF;

  -- Le ticket est débité ICI, au moment du tirage au sort — PAS au 1er tour
  -- réellement joué (voir requirement : "avant [le tirage au sort] le joueur
  -- peut encore reculer", donc gratuit ; une fois le tirage lancé, c'est
  -- définitif, y compris si le joueur recule ensuite sans jouer un seul
  -- tour). autobattle_resolve_manual_round ne touche plus du tout aux
  -- tickets.
  UPDATE player_items SET quantity = quantity - 1
    WHERE player_id = p_player_id AND item_nom = v_ticket_item_nom AND quantity >= 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'no_ticket');
  END IF;

  v_player_max_hp := COALESCE(v_player_species.pv_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'PV');
  -- Bascule globale des talents (voir autobattle_config.talents_enabled), puis
  -- filtre 'cancel_talents' (voir autobattle_talents_effective) : appliqué avant
  -- la priorité d'initiative et l'annonce d'ouverture juste en dessous.
  SELECT talents_enabled INTO v_talents_enabled FROM autobattle_config WHERE id = 1;
  v_talents_enabled := COALESCE(v_talents_enabled, true);
  v_player_talents := autobattle_talents_vs(v_pp.pokemon_nom, v_level.opponent_pokemon_nom, v_talents_enabled);
  v_opponent_talents := autobattle_talents_vs(v_level.opponent_pokemon_nom, v_pp.pokemon_nom, v_talents_enabled);
  -- Bascule globale de la météo (voir autobattle_config.weather_enabled).
  SELECT weather_enabled INTO v_weather_enabled FROM autobattle_config WHERE id = 1;
  v_weather_enabled := COALESCE(v_weather_enabled, true);

  v_first_attacker := CASE WHEN random() < 0.5 THEN 'player' ELSE 'opponent' END;
  -- Talent 'priority' : remplace le tirage au sort (voir autobattle_resolve_battle).
  IF autobattle_talent_priority(v_player_talents) <> autobattle_talent_priority(v_opponent_talents) THEN
    v_first_attacker := CASE WHEN autobattle_talent_priority(v_player_talents) > autobattle_talent_priority(v_opponent_talents)
      THEN 'player' ELSE 'opponent' END;
  END IF;

  v_talent_start := autobattle_talent_open(v_player_talents, 'player', GREATEST(1, v_player_max_hp));
  v_start_turns := v_start_turns || (v_talent_start -> 'turns');
  v_player_talent_state := v_talent_start -> 'state';
  v_talent_start := autobattle_talent_open(v_opponent_talents, 'opponent', v_level.opponent_hp);
  v_start_turns := v_start_turns || (v_talent_start -> 'turns');
  v_opponent_talent_state := v_talent_start -> 'state';

  -- Talent 'inflict_status' déclenché « à l'entrée en combat », dans l'ordre de
  -- jeu — le statut est persisté sur la ligne de combat, le 1er round le voit.
  -- La cible passe par autobattle_talent_status_guard comme en cours de combat
  -- (voir autobattle_resolve_manual_round) : l'immunité est déjà gérée dans
  -- autobattle_talent_act, mais pas 'auto_cure_first_status'.
  FOREACH v_side IN ARRAY (CASE WHEN v_first_attacker = 'player' THEN ARRAY['player', 'opponent'] ELSE ARRAY['opponent', 'player'] END) LOOP
    IF v_side = 'player' THEN
      v_talent_res := autobattle_talent_act(v_player_talents, v_player_talent_state, 'player', 'battle_start', NULL,
        GREATEST(1, v_player_max_hp), GREATEST(1, v_player_max_hp), v_opponent_status, v_player_status, v_opponent_talents, 0, v_weather, v_opponent_type);
      v_player_talent_state := v_talent_res -> 'state';
      v_start_turns := v_start_turns || (v_talent_res -> 'turns');
      -- Météo levée « à l'entrée en combat » : persistée sur la ligne de combat,
      -- le 1er round la verra donc dès son tick d'ouverture.
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'player', GREATEST(1, v_player_max_hp), 0);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_start_turns := v_start_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(v_opponent_talents, v_opponent_talent_state, 'opponent', v_talent_inflict, v_level.opponent_hp, 0, v_opponent_type);
        v_opponent_talent_state := v_talent_res -> 'state';
        v_start_turns := v_start_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_opponent_status := v_talent_inflict;
        END IF;
      END IF;
    ELSE
      v_talent_res := autobattle_talent_act(v_opponent_talents, v_opponent_talent_state, 'opponent', 'battle_start', NULL,
        v_level.opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_player_talents, 0, v_weather, v_player_species.type);
      v_opponent_talent_state := v_talent_res -> 'state';
      v_start_turns := v_start_turns || (v_talent_res -> 'turns');
      -- Voir le même commentaire côté joueur.
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'opponent', v_level.opponent_hp, 0);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_start_turns := v_start_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(v_player_talents, v_player_talent_state, 'player', v_talent_inflict, GREATEST(1, v_player_max_hp), 0, v_player_species.type);
        v_player_talent_state := v_talent_res -> 'state';
        v_start_turns := v_start_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_player_status := v_talent_inflict;
        END IF;
      END IF;
    END IF;
  END LOOP;

  -- Le sprite copié par le talent 'transform' n'est PAS renvoyé ici : le client
  -- le dérive lui-même dès l'ouverture (il connaît déjà les talents et les deux
  -- espèces, voir ManualBattleScreen), ce qui évite d'attendre le 1er round.
  v_result := jsonb_build_object('status', 'ok', 'first_attacker', v_first_attacker, 'turns', v_start_turns);

  INSERT INTO autobattle_manual_battles (
    player_id, level_id, variant_id, player_pokemon_id, first_attacker, turn_no,
    player_hp, player_max_hp, opponent_hp, last_idempotency_key, last_result,
    turn_log, player_talent_state, opponent_talent_state, player_status, opponent_status,
    weather_id
  ) VALUES (
    p_player_id, p_level_id, v_variant.id, p_player_pokemon_id, v_first_attacker, 0,
    GREATEST(1, v_player_max_hp), GREATEST(1, v_player_max_hp), v_level.opponent_hp, p_idempotency_key, v_result,
    v_start_turns, v_player_talent_state, v_opponent_talent_state, v_player_status, v_opponent_status,
    autobattle_weather_id(v_weather)
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION autobattle_start_manual_battle(bigint, bigint, bigint, uuid) TO anon, authenticated;
