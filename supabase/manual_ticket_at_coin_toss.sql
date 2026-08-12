-- ============================================================================
-- CORRECTIF : ticket Combat Manuel débité au tirage au sort, pas au 1er tour
-- ============================================================================
-- Bug rapporté : le compteur de tickets baissait de 2 au lieu de 1 par
-- combat Manuel. Cause : le ticket était réellement débité côté serveur au
-- 1er tour joué (autobattle_resolve_manual_round), mais le client appliquait
-- déjà une mise à jour optimiste du compteur dès le tirage au sort (voir
-- handleStartManualBattle) — reculer après le tirage au sort SANS jamais
-- jouer de tour, puis relancer un tirage au sort sur ce même niveau,
-- recalculait le nouveau total à partir d'un compteur déjà artificiellement
-- réduit côté client, faisant apparaître -2 au lieu de -1.
--
-- Correctif (suit la demande explicite : le ticket doit être dépensé au
-- moment précis où le tirage au sort a lieu — avant ça, le joueur peut
-- reculer gratuitement en changeant de pokémon ; après, c'est définitif) :
-- le débit réel passe d'autobattle_resolve_manual_round à
-- autobattle_start_manual_battle. Le 1er tour ne touche plus du tout aux
-- tickets. La colonne autobattle_manual_battles.ticket_debited (qui servait
-- à garantir un débit unique entre les deux appels) est supprimée, devenue
-- inutile : il n'y a plus qu'UN SEUL point de débit.
--
-- Remplace intégralement autobattle_start_manual_battle et
-- autobattle_resolve_manual_round (CREATE OR REPLACE FUNCTION exige le corps
-- complet). Si vous avez déjà exécuté battle_fixes_batch2.sql, ce fichier le
-- remplace pour la partie Combat Manuel uniquement (le reste — auto engine,
-- opponent_ability_nom_5..10 — reste valide, inchangé).
-- ============================================================================

ALTER TABLE autobattle_manual_battles DROP COLUMN IF EXISTS ticket_debited;

-- reculer AVANT ce point (pendant le choix du pokémon) ne coûte rien, mais
-- une fois le tirage lancé c'est définitif, même si le joueur recule ensuite
-- sans jouer un seul tour (voir requirement) : autobattle_resolve_manual_
-- round ne touche plus du tout aux tickets. Toute ligne déjà existante pour
-- ce joueur/niveau (combat terminé, ou abandonné en cours) est TOUJOURS
-- purgée ici et remplacée par un combat neuf — voir le même requirement que
-- le correctif p_is_new_battle précédent, désormais porté par ce point
-- d'entrée plutôt que par le 1er tour.
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
  v_row            autobattle_manual_battles%ROWTYPE;
  v_ticket_item_nom text := 'Ticket Combat';
  v_player_max_hp  integer;
  v_first_attacker text;
  v_result         jsonb;
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

  SELECT * INTO v_pp FROM player_pokemon WHERE id = p_player_pokemon_id AND player_id = p_player_id;
  IF v_pp IS NULL OR v_pp.in_daycare THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;

  SELECT * INTO v_player_species FROM pokemon WHERE nom = v_pp.pokemon_nom;
  IF v_player_species IS NULL THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;

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
  v_first_attacker := CASE WHEN random() < 0.5 THEN 'player' ELSE 'opponent' END;
  v_result := jsonb_build_object('status', 'ok', 'first_attacker', v_first_attacker);

  INSERT INTO autobattle_manual_battles (
    player_id, level_id, variant_id, player_pokemon_id, first_attacker, turn_no,
    player_hp, player_max_hp, opponent_hp, last_idempotency_key, last_result
  ) VALUES (
    p_player_id, p_level_id, v_variant.id, p_player_pokemon_id, v_first_attacker, 0,
    GREATEST(1, v_player_max_hp), GREATEST(1, v_player_max_hp), v_level.opponent_hp, p_idempotency_key, v_result
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION autobattle_start_manual_battle(bigint, bigint, bigint, uuid) TO anon, authenticated;

DROP FUNCTION IF EXISTS autobattle_resolve_manual_round(bigint, bigint, bigint, text, uuid);
DROP FUNCTION IF EXISTS autobattle_resolve_manual_round(bigint, bigint, bigint, text, uuid, boolean);
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
  v_turn_no             integer;
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
  v_player_invuln_granted_turn integer;
  v_opponent_invulnerable     boolean;
  v_opponent_invuln_granted_turn integer;
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
  v_player_cancel_heal_duration   integer;
  v_player_percent_hp_damage_percent integer;
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
  v_opponent_cancel_heal_duration   integer;
  v_opponent_percent_hp_damage_percent integer;
  v_rewards             jsonb := '[]'::jsonb;
  v_reward              record;
  v_max_level_index     integer;
  v_variant_completed   boolean := false;
  v_next_level_index    integer;
  v_new_xp              integer;
  v_max_xp              integer;
  v_result              jsonb;
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
  IF NOT (p_ability_nom = ANY(v_pp.moves)) THEN
    RETURN jsonb_build_object('status', 'ineligible_ability');
  END IF;

  SELECT * INTO v_player_species FROM pokemon WHERE nom = v_pp.pokemon_nom;
  IF v_player_species IS NULL OR NOT EXISTS (SELECT 1 FROM attacks WHERE nom = p_ability_nom) THEN
    RETURN jsonb_build_object('status', 'ineligible_ability');
  END IF;
  IF EXISTS (SELECT 1 FROM autobattle_banned_attacks WHERE attack_nom = p_ability_nom) THEN
    RETURN jsonb_build_object('status', 'ineligible_ability');
  END IF;

  SELECT * INTO v_opponent_species FROM pokemon WHERE nom = v_level.opponent_pokemon_nom;
  IF v_opponent_species IS NULL OR NOT EXISTS (SELECT 1 FROM attacks WHERE nom = v_level.opponent_ability_nom) THEN
    RETURN jsonb_build_object('status', 'invalid_level');
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
  v_player_invuln_granted_turn := v_row.player_invuln_granted_turn;
  v_opponent_invulnerable := v_row.opponent_invulnerable;
  v_opponent_invuln_granted_turn := v_row.opponent_invuln_granted_turn;
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

  -- Capacité RÉELLEMENT jouée par le joueur ce tour : celle mémorisée s'il
  -- est en cours de préparation (prepare_release, voir plus haut), sinon
  -- celle tout juste choisie (déjà validée ci-dessus).
  v_effective_player_ability_nom := CASE WHEN v_player_preparing THEN v_player_preparing_ability_nom ELSE p_ability_nom END;
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

  -- Expiration des modificateurs actifs (comparés au numéro de tour absolu,
  -- comme en mode Auto) : vérifiée avant de résoudre quoi que ce soit ce tour.
  IF v_player_damage_mod_expires IS NOT NULL AND v_turn_no > v_player_damage_mod_expires THEN
    v_player_damage_mod_amount := 0; v_player_damage_mod_expires := NULL;
  END IF;
  IF v_player_precision_mod_expires IS NOT NULL AND v_turn_no > v_player_precision_mod_expires THEN
    v_player_precision_mod_amount := 0; v_player_precision_mod_expires := NULL;
  END IF;
  IF v_opponent_damage_mod_expires IS NOT NULL AND v_turn_no > v_opponent_damage_mod_expires THEN
    v_opponent_damage_mod_amount := 0; v_opponent_damage_mod_expires := NULL;
  END IF;
  IF v_opponent_precision_mod_expires IS NOT NULL AND v_turn_no > v_opponent_precision_mod_expires THEN
    v_opponent_precision_mod_amount := 0; v_opponent_precision_mod_expires := NULL;
  END IF;
  IF v_player_heal_dot_expires IS NOT NULL AND v_turn_no > v_player_heal_dot_expires THEN
    v_player_heal_dot_amount := NULL; v_player_heal_dot_expires := NULL;
  END IF;
  IF v_opponent_heal_dot_expires IS NOT NULL AND v_turn_no > v_opponent_heal_dot_expires THEN
    v_opponent_heal_dot_amount := NULL; v_opponent_heal_dot_expires := NULL;
  END IF;
  IF v_player_heal_disabled_expires IS NOT NULL AND v_turn_no > v_player_heal_disabled_expires THEN
    v_player_heal_disabled_expires := NULL;
  END IF;
  IF v_opponent_heal_disabled_expires IS NOT NULL AND v_turn_no > v_opponent_heal_disabled_expires THEN
    v_opponent_heal_disabled_expires := NULL;
  END IF;

  -- Super efficace : la capacité utilisée doit être du MÊME type que le
  -- pokémon qui l'utilise, en plus d'être favorable dans la table de types
  -- (voir même remarque en mode Auto, autobattle_resolve_battle) — recalculé
  -- CHAQUE round ici (contrairement au mode Auto, figé pour tout le combat)
  -- puisque la capacité jouée change à chaque tour.
  v_player_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (v_player_species.super_efficace_1), (v_player_species.super_efficace_2),
      (v_player_species.super_efficace_3), (v_player_species.super_efficace_4)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(v_opponent_species.type))
  ) AND lower(trim(v_ability.type)) = lower(trim(v_player_species.type));
  v_player_damage := (COALESCE(v_player_species.degats_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'DMG'))
    * (CASE WHEN v_player_type_bonus THEN 2 ELSE 1 END) + COALESCE(v_ability.degats_base, 0);
  v_player_damage_original := v_player_damage;

  v_opponent_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (v_opponent_species.super_efficace_1), (v_opponent_species.super_efficace_2),
      (v_opponent_species.super_efficace_3), (v_opponent_species.super_efficace_4)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(v_player_species.type))
  ) AND lower(trim(v_opponent_ability.type)) = lower(trim(v_opponent_species.type));
  v_opponent_damage := COALESCE(v_level.opponent_base_damage, 0) * (CASE WHEN v_opponent_type_bonus THEN 2 ELSE 1 END)
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
         heal_dot_amount, heal_dot_duration_turns, cancel_heal_duration_turns, percent_hp_damage_percent
    INTO v_player_turn_effect, v_player_repeat_max, v_player_heal_type, v_player_heal_amount, v_player_heal_percent, v_player_status_reversed,
         v_player_recoil_type, v_player_recoil_min, v_player_recoil_max, v_player_recoil_percent, v_player_invuln_grant,
         v_player_bonus_type, v_player_bonus_multiplier, v_player_bonus_flat, v_player_bonus_min, v_player_bonus_max,
         v_player_bonus_condition, v_player_bonus_dice_value, v_player_bonus_status_filter,
         v_player_stat_mod_target, v_player_stat_mod_stat, v_player_stat_mod_value_type, v_player_stat_mod_flat, v_player_stat_mod_min, v_player_stat_mod_max, v_player_stat_mod_percent,
         v_player_stat_mod_duration_type, v_player_stat_mod_duration_turns, v_player_stat_mod_max_uses,
         v_player_heal_dot_config_amount, v_player_heal_dot_config_turns, v_player_cancel_heal_duration, v_player_percent_hp_damage_percent
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_player_ability_nom;
  v_player_status_reversed := COALESCE(v_player_status_reversed, false);
  v_player_invuln_grant := COALESCE(v_player_invuln_grant, false);

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, cancel_heal_duration_turns, percent_hp_damage_percent
    INTO v_opponent_turn_effect, v_opponent_repeat_max, v_opponent_heal_type, v_opponent_heal_amount, v_opponent_heal_percent, v_opponent_status_reversed,
         v_opponent_recoil_type, v_opponent_recoil_min, v_opponent_recoil_max, v_opponent_recoil_percent, v_opponent_invuln_grant,
         v_opponent_bonus_type, v_opponent_bonus_multiplier, v_opponent_bonus_flat, v_opponent_bonus_min, v_opponent_bonus_max,
         v_opponent_bonus_condition, v_opponent_bonus_dice_value, v_opponent_bonus_status_filter,
         v_opponent_stat_mod_target, v_opponent_stat_mod_stat, v_opponent_stat_mod_value_type, v_opponent_stat_mod_flat, v_opponent_stat_mod_min, v_opponent_stat_mod_max, v_opponent_stat_mod_percent,
         v_opponent_stat_mod_duration_type, v_opponent_stat_mod_duration_turns, v_opponent_stat_mod_max_uses,
         v_opponent_heal_dot_config_amount, v_opponent_heal_dot_config_turns, v_opponent_cancel_heal_duration, v_opponent_percent_hp_damage_percent
    FROM autobattle_ability_rules WHERE attack_nom = v_opponent_ability_nom_round;
  v_opponent_status_reversed := COALESCE(v_opponent_status_reversed, false);
  v_opponent_invuln_grant := COALESCE(v_opponent_invuln_grant, false);

  v_attacker := v_first_attacker;
  v_block_remaining := NULL;

  -- Boucle identique dans son fonctionnement à celle d'autobattle_resolve_
  -- battle (voir ce commentaire pour le détail de chaque effet), bornée ici
  -- à s'arrêter dès que v_flips atteint 2 (un tour complet joué par chacun
  -- des deux camps, rafales/passes/préparations internes comprises) au lieu
  -- de tourner jusqu'à la victoire/défaite.
  LOOP
    v_turn_no := v_turn_no + 1;

    IF v_player_invulnerable AND v_player_invuln_granted_turn IS NOT NULL AND v_turn_no > v_player_invuln_granted_turn THEN
      v_player_invulnerable := false;
      IF v_attacker = 'opponent' THEN
        v_player_invuln_pending_miss := true;
      END IF;
    END IF;
    IF v_opponent_invulnerable AND v_opponent_invuln_granted_turn IS NOT NULL AND v_turn_no > v_opponent_invuln_granted_turn THEN
      v_opponent_invulnerable := false;
      IF v_attacker = 'player' THEN
        v_opponent_invuln_pending_miss := true;
      END IF;
    END IF;

    IF v_player_damage_mod_expires IS NOT NULL AND v_turn_no > v_player_damage_mod_expires THEN
      v_player_damage_mod_amount := 0; v_player_damage_mod_expires := NULL;
    END IF;
    IF v_player_precision_mod_expires IS NOT NULL AND v_turn_no > v_player_precision_mod_expires THEN
      v_player_precision_mod_amount := 0; v_player_precision_mod_expires := NULL;
    END IF;
    IF v_opponent_damage_mod_expires IS NOT NULL AND v_turn_no > v_opponent_damage_mod_expires THEN
      v_opponent_damage_mod_amount := 0; v_opponent_damage_mod_expires := NULL;
    END IF;
    IF v_opponent_precision_mod_expires IS NOT NULL AND v_turn_no > v_opponent_precision_mod_expires THEN
      v_opponent_precision_mod_amount := 0; v_opponent_precision_mod_expires := NULL;
    END IF;
    IF v_player_heal_dot_expires IS NOT NULL AND v_turn_no > v_player_heal_dot_expires THEN
      v_player_heal_dot_amount := NULL; v_player_heal_dot_expires := NULL;
    END IF;
    IF v_opponent_heal_dot_expires IS NOT NULL AND v_turn_no > v_opponent_heal_dot_expires THEN
      v_opponent_heal_dot_amount := NULL; v_opponent_heal_dot_expires := NULL;
    END IF;
    IF v_player_heal_disabled_expires IS NOT NULL AND v_turn_no > v_player_heal_disabled_expires THEN
      v_player_heal_disabled_expires := NULL;
    END IF;
    IF v_opponent_heal_disabled_expires IS NOT NULL AND v_turn_no > v_opponent_heal_disabled_expires THEN
      v_opponent_heal_disabled_expires := NULL;
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

      IF v_attacker = 'player' AND v_player_status IN ('paralysis', 'frozen') THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', true,
          'status_tick', true, 'status', v_player_status, 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        v_player_status := NULL;
        v_attacker := 'opponent';
        v_flips := v_flips + 1;
        IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
        IF v_flips >= 2 THEN EXIT; END IF;
        CONTINUE;
      ELSIF v_attacker = 'opponent' AND v_opponent_status IN ('paralysis', 'frozen') THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', true,
          'status_tick', true, 'status', v_opponent_status, 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        v_opponent_status := NULL;
        v_attacker := 'player';
        v_flips := v_flips + 1;
        IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
        IF v_flips >= 2 THEN EXIT; END IF;
        CONTINUE;

      -- Sommeil : le dé décide DIRECTEMENT du sort de CE tick — guéri, aucun
      -- effet cette fois-ci et le tour se joue normalement ; pas guéri, le
      -- tour est passé (voir autobattle_resolve_battle pour le détail du
      -- raisonnement — peut donc n'avoir eu AUCUN impact, comportement voulu).
      ELSIF v_attacker = 'player' AND v_player_status = 'sleep' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', NOT v_status_cured,
          'status_tick', true, 'status', 'sleep', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_status_cured THEN
          v_player_status := NULL;
        ELSE
          v_attacker := 'opponent';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_status = 'sleep' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', NOT v_status_cured,
          'status_tick', true, 'status', 'sleep', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_status_cured THEN
          v_opponent_status := NULL;
        ELSE
          v_attacker := 'player';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
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

      ELSIF v_attacker = 'player' AND v_player_status = 'poison' THEN
        v_player_hp := v_player_hp - 3;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 3, 'skipped', false,
          'status_tick', true, 'status', 'poison', 'status_cured', false,
          'attacker_hp_after', GREATEST(0, v_player_hp), 'defender_hp_after', GREATEST(0, v_opponent_hp),
          'ko', v_player_hp <= 0
        ));
        IF v_player_hp <= 0 THEN v_outcome := 'lose'; EXIT; END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_status = 'poison' THEN
        v_opponent_hp := v_opponent_hp - 3;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 3, 'skipped', false,
          'status_tick', true, 'status', 'poison', 'status_cured', false,
          'attacker_hp_after', GREATEST(0, v_opponent_hp), 'defender_hp_after', GREATEST(0, v_player_hp),
          'ko', v_opponent_hp <= 0
        ));
        IF v_opponent_hp <= 0 THEN v_outcome := 'win'; EXIT; END IF;

      ELSIF v_attacker = 'player' AND v_player_status = 'fear' THEN
        v_status_precision_penalty := 5;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
          'status_tick', true, 'status', 'fear', 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        v_player_status := NULL;
      ELSIF v_attacker = 'opponent' AND v_opponent_status = 'fear' THEN
        v_status_precision_penalty := 5;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
          'status_tick', true, 'status', 'fear', 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        v_opponent_status := NULL;

      -- Confusion : comme le sommeil, un dé décide DIRECTEMENT du sort de CE
      -- tick — guérie, aucune pénalité cette fois-ci ; pas guérie, la
      -- pénalité s'applique à l'attaque qui suit immédiatement. Ne fait
      -- JAMAIS passer le tour (à la différence du sommeil) — peut donc
      -- n'avoir eu AUCUN impact si la guérison tombe dès le premier jet,
      -- comportement voulu (voir autobattle_resolve_battle).
      ELSIF v_attacker = 'player' AND v_player_status = 'confusion' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
          'status_tick', true, 'status', 'confusion', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_status_cured THEN v_player_status := NULL; ELSE v_status_precision_penalty := 5; END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_status = 'confusion' THEN
        v_status_roll := 1 + floor(random() * 6)::integer;
        v_status_cured := v_status_roll >= 4;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
          'status_tick', true, 'status', 'confusion', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_status_cured THEN v_opponent_status := NULL; ELSE v_status_precision_penalty := 5; END IF;
      END IF;

      IF v_attacker = 'player' AND v_player_heal_dot_amount IS NOT NULL
         AND (v_player_heal_disabled_expires IS NULL OR v_turn_no > v_player_heal_disabled_expires) THEN
        v_player_hp := LEAST(v_player_max_hp, v_player_hp + v_player_heal_dot_amount);
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
          'heal_dot_tick', true, 'heal', v_player_heal_dot_amount,
          'attacker_hp_after', v_player_hp, 'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_player_status = 'poison' THEN v_player_status := NULL; END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_heal_dot_amount IS NOT NULL
         AND (v_opponent_heal_disabled_expires IS NULL OR v_turn_no > v_opponent_heal_disabled_expires) THEN
        v_opponent_hp := LEAST(v_level.opponent_hp, v_opponent_hp + v_opponent_heal_dot_amount);
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
          'heal_dot_tick', true, 'heal', v_opponent_heal_dot_amount,
          'attacker_hp_after', v_opponent_hp, 'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_opponent_status = 'poison' THEN v_opponent_status := NULL; END IF;
      END IF;

      IF v_attacker = 'player' AND v_player_turn_effect = 'skip' THEN
        IF v_player_skip_pending THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', true,
            'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
          ));
          v_player_skip_pending := false;
          v_attacker := 'opponent';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
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
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        ELSE
          v_block_remaining := 1;
          v_opponent_skip_pending := true;
        END IF;
      ELSIF v_attacker = 'player' AND v_player_turn_effect = 'repeat_until_fail' THEN
        v_block_remaining := GREATEST(1, COALESCE(v_player_repeat_max, 6));
      ELSIF v_attacker = 'opponent' AND v_opponent_turn_effect = 'repeat_until_fail' THEN
        v_block_remaining := GREATEST(1, COALESCE(v_opponent_repeat_max, 6));
      ELSIF v_attacker = 'player' AND v_player_turn_effect = 'prepare_release' THEN
        IF v_player_preparing THEN
          v_player_preparing := false;
          v_player_preparing_ability_nom := NULL;
          v_block_remaining := 1;
        ELSE
          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', true, 'preparing', true,
            'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
          );
          IF v_player_invuln_grant THEN
            v_player_invulnerable := true;
            v_player_invuln_granted_turn := v_turn_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry);
          v_player_preparing := true;
          v_player_preparing_ability_nom := v_effective_player_ability_nom;
          v_attacker := 'opponent';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;
      ELSIF v_attacker = 'opponent' AND v_opponent_turn_effect = 'prepare_release' THEN
        IF v_opponent_preparing THEN
          v_opponent_preparing := false;
          v_opponent_preparing_ability_nom := NULL;
          v_block_remaining := 1;
        ELSE
          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', true, 'preparing', true,
            'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
          );
          IF v_opponent_invuln_grant THEN
            v_opponent_invulnerable := true;
            v_opponent_invuln_granted_turn := v_turn_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry);
          v_opponent_preparing := true;
          v_opponent_preparing_ability_nom := v_opponent_ability_nom_round;
          v_attacker := 'player';
          v_flips := v_flips + 1;
          IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
          IF v_flips >= 2 THEN EXIT; END IF;
          CONTINUE;
        END IF;
      ELSE
        v_block_remaining := autobattle_ability_burst(CASE WHEN v_attacker = 'player' THEN v_effective_player_ability_nom ELSE v_opponent_ability_nom_round END);
        IF v_block_remaining = 0 THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', v_attacker, 'damage', 0, 'skipped', true,
            'defender_hp_after', CASE WHEN v_attacker = 'player' THEN GREATEST(0, v_opponent_hp) ELSE GREATEST(0, v_player_hp) END,
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
      -- Voir la même remarque en mode Auto (autobattle_resolve_battle) : ne
      -- bloque que si la capacité jouée affecte réellement l'adversaire,
      -- consomme le flag (1 tour adverse) dans les deux cas.
      IF v_opponent_invuln_pending_miss AND (
        v_ability.deals_damage
        OR (v_ability.status_effect IS NOT NULL AND NOT v_player_status_reversed)
        OR v_player_stat_mod_target = 'opponent'
        OR v_player_cancel_heal_duration IS NOT NULL
      ) THEN
        v_opponent_invuln_pending_miss := false;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true, 'invulnerable_miss', true,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_player_turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
      ELSE
        v_opponent_invuln_pending_miss := false;
        v_missed := (NOT v_player_never_miss) AND
          random() >= ((CASE WHEN v_precision_enabled THEN GREATEST(0, COALESCE(v_ability.precision, 10) - v_status_precision_penalty + v_player_precision_mod_amount) ELSE 10 END * 10) / 100.0);

        IF v_missed THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true,
            'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
          ));
          IF v_player_turn_effect = 'repeat_until_fail' THEN
            v_block_remaining := 1;
          END IF;
        ELSE
          -- Capacités non-offensives (voir même remarque en mode Auto,
          -- autobattle_resolve_battle) : pas de dégâts, système % PV / bonus
          -- conditionnels ignorés aussi.
          IF v_ability.deals_damage THEN
            v_hit_dice := CASE WHEN v_ability.degats_de IS NOT NULL AND v_ability.degats_de > 0
              THEN 1 + floor(random() * v_ability.degats_de)::integer ELSE 0 END;
            v_hit_damage := GREATEST(0, v_player_damage + v_hit_dice + v_player_damage_mod_amount);

            v_percent_hp_damage_applied := v_player_percent_hp_damage_percent IS NOT NULL;
            IF v_percent_hp_damage_applied THEN
              v_hit_damage := GREATEST(0, floor(v_opponent_hp * v_player_percent_hp_damage_percent / 100.0)::integer);
            END IF;

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
          ELSE
            v_hit_dice := 0;
            v_hit_damage := 0;
            v_percent_hp_damage_applied := false;
          END IF;
          v_player_used_ability := true;

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
            v_heal_amt := v_player_damage_original + v_heal_dice;
          END IF;

          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', v_hit_damage, 'damage_before_dice', v_player_damage,
            'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', v_opponent_hp <= 0
          );
          IF v_percent_hp_damage_applied THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('percent_hp_damage', true);
          END IF;
          IF v_heal_amt IS NOT NULL AND v_heal_amt > 0 AND (v_player_heal_disabled_expires IS NULL OR v_turn_no > v_player_heal_disabled_expires) THEN
            v_player_hp := LEAST(v_player_max_hp, v_player_hp + v_heal_amt);
            v_turn_entry := v_turn_entry || jsonb_build_object('heal', v_heal_amt, 'attacker_hp_after', v_player_hp);
            IF v_player_status = 'poison' THEN
              v_player_status := NULL;
              v_turn_entry := v_turn_entry || jsonb_build_object('status_cured_by_heal', true);
            END IF;
          ELSIF v_heal_amt IS NOT NULL AND v_heal_amt > 0 THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('heal_blocked', true);
          END IF;
          IF v_ability.status_effect IS NOT NULL AND random() * 100 < v_ability.status_chance THEN
            IF v_player_status_reversed THEN
              v_player_status := v_ability.status_effect;
            ELSE
              v_opponent_status := v_ability.status_effect;
            END IF;
            v_turn_entry := v_turn_entry || jsonb_build_object('status_applied', v_ability.status_effect, 'status_applied_reversed', v_player_status_reversed);
          END IF;
          IF v_player_stat_mod_target IS NOT NULL THEN
            v_player_stat_mod_key := v_effective_player_ability_nom;
            v_player_stat_mod_uses_used_for_key := COALESCE((v_player_stat_mod_uses ->> v_player_stat_mod_key)::integer, 0);
            IF v_player_stat_mod_max_uses IS NULL OR v_player_stat_mod_uses_used_for_key < v_player_stat_mod_max_uses THEN
              v_stat_mod_amount := CASE
                WHEN v_player_stat_mod_value_type = 'flat' THEN COALESCE(v_player_stat_mod_flat, 0)
                WHEN v_player_stat_mod_value_type = 'range' THEN v_player_stat_mod_min + floor(random() * (v_player_stat_mod_max - v_player_stat_mod_min + 1))::integer
                WHEN v_player_stat_mod_value_type = 'percent' THEN
                  floor((CASE WHEN v_player_stat_mod_target = 'self' THEN v_player_damage_original ELSE v_opponent_damage_original END)
                    * COALESCE(v_player_stat_mod_percent, 0) / 100.0)::integer
                ELSE 0
              END;
              v_stat_mod_amount := CASE WHEN v_player_stat_mod_target = 'opponent' THEN -abs(v_stat_mod_amount) ELSE abs(v_stat_mod_amount) END;
              -- v_turn_no avance de 1 à CHAQUE itération de boucle (joueur ET
              -- adversaire confondus, voir plus haut), donc "1 tour" pour le
              -- lanceur (son PROCHAIN tour, pas celui-ci — voir requirement)
              -- correspond à 2 incréments de v_turn_no en alternance normale
              -- (son tour de repli, puis le tour adverse, puis son tour
              -- suivant) : d'où × 2 ci-dessous, plutôt qu'un simple + N qui
              -- expirerait le bonus AVANT même d'avoir pu servir une fois.
              v_stat_mod_expiry := CASE WHEN v_player_stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_turn_no + 2 * COALESCE(v_player_stat_mod_duration_turns, 1) END;
              IF v_player_stat_mod_target = 'self' AND v_player_stat_mod_stat = 'damage' THEN
                v_player_damage_mod_amount := v_stat_mod_amount; v_player_damage_mod_expires := v_stat_mod_expiry;
              ELSIF v_player_stat_mod_target = 'self' AND v_player_stat_mod_stat = 'precision' THEN
                v_player_precision_mod_amount := v_stat_mod_amount; v_player_precision_mod_expires := v_stat_mod_expiry;
              ELSIF v_player_stat_mod_target = 'opponent' AND v_player_stat_mod_stat = 'damage' THEN
                v_opponent_damage_mod_amount := v_stat_mod_amount; v_opponent_damage_mod_expires := v_stat_mod_expiry;
              ELSIF v_player_stat_mod_target = 'opponent' AND v_player_stat_mod_stat = 'precision' THEN
                v_opponent_precision_mod_amount := v_stat_mod_amount; v_opponent_precision_mod_expires := v_stat_mod_expiry;
              END IF;
              v_player_stat_mod_uses := jsonb_set(v_player_stat_mod_uses, ARRAY[v_player_stat_mod_key], to_jsonb(v_player_stat_mod_uses_used_for_key + 1));
              v_turn_entry := v_turn_entry || jsonb_build_object('stat_mod_applied', jsonb_build_object(
                'target', v_player_stat_mod_target, 'stat', v_player_stat_mod_stat, 'amount', v_stat_mod_amount, 'duration_type', v_player_stat_mod_duration_type
              ));
            ELSE
              v_turn_entry := v_turn_entry || jsonb_build_object('stat_mod_limit_reached', true);
            END IF;
          END IF;
          IF v_player_heal_dot_config_amount IS NOT NULL THEN
            v_player_heal_dot_amount := v_player_heal_dot_config_amount;
            v_player_heal_dot_expires := v_turn_no + v_player_heal_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('heal_dot_granted', true);
          END IF;
          IF v_player_cancel_heal_duration IS NOT NULL THEN
            v_opponent_heal_disabled_expires := v_turn_no + v_player_cancel_heal_duration;
            v_turn_entry := v_turn_entry || jsonb_build_object('cancel_heal_applied', true);
          END IF;
          IF v_player_invuln_grant AND v_player_turn_effect <> 'prepare_release' THEN
            v_player_invulnerable := true;
            v_player_invuln_granted_turn := v_turn_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
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
      -- capacité affecte réellement le joueur, et consomme le flag (1 tour
      -- adverse) dans les deux cas.
      IF v_player_invuln_pending_miss AND (
        v_opponent_ability.deals_damage
        OR (v_opponent_ability.status_effect IS NOT NULL AND NOT v_opponent_status_reversed)
        OR v_opponent_stat_mod_target = 'opponent'
        OR v_opponent_cancel_heal_duration IS NOT NULL
      ) THEN
        v_player_invuln_pending_miss := false;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'missed', true, 'invulnerable_miss', true,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_opponent_turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
      ELSE
        v_player_invuln_pending_miss := false;
        v_missed := (NOT v_opponent_never_miss) AND
          random() >= ((CASE WHEN v_precision_enabled THEN GREATEST(0, COALESCE(v_opponent_ability.precision, 10) - v_status_precision_penalty + v_opponent_precision_mod_amount) ELSE 10 END * 10) / 100.0);

        IF v_missed THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'missed', true,
            'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
          ));
          IF v_opponent_turn_effect = 'repeat_until_fail' THEN
            v_block_remaining := 1;
          END IF;
        ELSE
          -- Capacités non-offensives (voir même remarque côté joueur) : pas
          -- de dégâts, système % PV / bonus conditionnels ignorés aussi.
          IF v_opponent_ability.deals_damage THEN
            v_hit_dice := CASE WHEN v_opponent_ability.degats_de IS NOT NULL AND v_opponent_ability.degats_de > 0
              THEN 1 + floor(random() * v_opponent_ability.degats_de)::integer ELSE 0 END;
            v_hit_damage := GREATEST(0, v_opponent_damage + v_hit_dice + v_opponent_damage_mod_amount);

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
          ELSE
            v_hit_dice := 0;
            v_hit_damage := 0;
            v_percent_hp_damage_applied := false;
          END IF;
          v_opponent_used_ability := true;

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
            v_heal_amt := v_opponent_damage_original + v_heal_dice;
          END IF;

          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', v_hit_damage, 'damage_before_dice', v_opponent_damage,
            'defender_hp_after', GREATEST(0, v_player_hp), 'ko', v_player_hp <= 0
          );
          IF v_percent_hp_damage_applied THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('percent_hp_damage', true);
          END IF;
          IF v_heal_amt IS NOT NULL AND v_heal_amt > 0 AND (v_opponent_heal_disabled_expires IS NULL OR v_turn_no > v_opponent_heal_disabled_expires) THEN
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
            v_opponent_stat_mod_key := v_opponent_ability_nom_round;
            v_opponent_stat_mod_uses_used_for_key := COALESCE((v_opponent_stat_mod_uses ->> v_opponent_stat_mod_key)::integer, 0);
            IF v_opponent_stat_mod_max_uses IS NULL OR v_opponent_stat_mod_uses_used_for_key < v_opponent_stat_mod_max_uses THEN
              v_stat_mod_amount := CASE
                WHEN v_opponent_stat_mod_value_type = 'flat' THEN COALESCE(v_opponent_stat_mod_flat, 0)
                WHEN v_opponent_stat_mod_value_type = 'range' THEN v_opponent_stat_mod_min + floor(random() * (v_opponent_stat_mod_max - v_opponent_stat_mod_min + 1))::integer
                WHEN v_opponent_stat_mod_value_type = 'percent' THEN
                  floor((CASE WHEN v_opponent_stat_mod_target = 'self' THEN v_opponent_damage_original ELSE v_player_damage_original END)
                    * COALESCE(v_opponent_stat_mod_percent, 0) / 100.0)::integer
                ELSE 0
              END;
              v_stat_mod_amount := CASE WHEN v_opponent_stat_mod_target = 'opponent' THEN -abs(v_stat_mod_amount) ELSE abs(v_stat_mod_amount) END;
              v_stat_mod_expiry := CASE WHEN v_opponent_stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_turn_no + 2 * COALESCE(v_opponent_stat_mod_duration_turns, 1) END;
              IF v_opponent_stat_mod_target = 'self' AND v_opponent_stat_mod_stat = 'damage' THEN
                v_opponent_damage_mod_amount := v_stat_mod_amount; v_opponent_damage_mod_expires := v_stat_mod_expiry;
              ELSIF v_opponent_stat_mod_target = 'self' AND v_opponent_stat_mod_stat = 'precision' THEN
                v_opponent_precision_mod_amount := v_stat_mod_amount; v_opponent_precision_mod_expires := v_stat_mod_expiry;
              ELSIF v_opponent_stat_mod_target = 'opponent' AND v_opponent_stat_mod_stat = 'damage' THEN
                v_player_damage_mod_amount := v_stat_mod_amount; v_player_damage_mod_expires := v_stat_mod_expiry;
              ELSIF v_opponent_stat_mod_target = 'opponent' AND v_opponent_stat_mod_stat = 'precision' THEN
                v_player_precision_mod_amount := v_stat_mod_amount; v_player_precision_mod_expires := v_stat_mod_expiry;
              END IF;
              v_opponent_stat_mod_uses := jsonb_set(v_opponent_stat_mod_uses, ARRAY[v_opponent_stat_mod_key], to_jsonb(v_opponent_stat_mod_uses_used_for_key + 1));
              v_turn_entry := v_turn_entry || jsonb_build_object('stat_mod_applied', jsonb_build_object(
                'target', v_opponent_stat_mod_target, 'stat', v_opponent_stat_mod_stat, 'amount', v_stat_mod_amount, 'duration_type', v_opponent_stat_mod_duration_type
              ));
            ELSE
              v_turn_entry := v_turn_entry || jsonb_build_object('stat_mod_limit_reached', true);
            END IF;
          END IF;
          IF v_opponent_heal_dot_config_amount IS NOT NULL THEN
            v_opponent_heal_dot_amount := v_opponent_heal_dot_config_amount;
            v_opponent_heal_dot_expires := v_turn_no + v_opponent_heal_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('heal_dot_granted', true);
          END IF;
          IF v_opponent_cancel_heal_duration IS NOT NULL THEN
            v_player_heal_disabled_expires := v_turn_no + v_opponent_cancel_heal_duration;
            v_turn_entry := v_turn_entry || jsonb_build_object('cancel_heal_applied', true);
          END IF;
          IF v_opponent_invuln_grant AND v_opponent_turn_effect <> 'prepare_release' THEN
            v_opponent_invulnerable := true;
            v_opponent_invuln_granted_turn := v_turn_no;
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
      v_flips := v_flips + 1;
    END IF;

    IF v_turn_no > 5000 THEN v_outcome := 'lose'; EXIT; END IF;
    IF v_flips >= 2 THEN EXIT; END IF;
  END LOOP;

  IF v_outcome = 'win' THEN
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
    'player_ability_nom', v_effective_player_ability_nom
  );

  IF v_outcome IS NULL THEN
    UPDATE autobattle_manual_battles SET
      turn_no = v_turn_no, player_hp = v_player_hp, opponent_hp = v_opponent_hp,
      player_status = v_player_status, opponent_status = v_opponent_status,
      player_damage_mod_amount = v_player_damage_mod_amount, player_damage_mod_expires = v_player_damage_mod_expires,
      player_precision_mod_amount = v_player_precision_mod_amount, player_precision_mod_expires = v_player_precision_mod_expires,
      opponent_damage_mod_amount = v_opponent_damage_mod_amount, opponent_damage_mod_expires = v_opponent_damage_mod_expires,
      opponent_precision_mod_amount = v_opponent_precision_mod_amount, opponent_precision_mod_expires = v_opponent_precision_mod_expires,
      player_heal_dot_amount = v_player_heal_dot_amount, player_heal_dot_expires = v_player_heal_dot_expires,
      opponent_heal_dot_amount = v_opponent_heal_dot_amount, opponent_heal_dot_expires = v_opponent_heal_dot_expires,
      player_heal_disabled_expires = v_player_heal_disabled_expires, opponent_heal_disabled_expires = v_opponent_heal_disabled_expires,
      player_invulnerable = v_player_invulnerable, player_invuln_granted_turn = v_player_invuln_granted_turn,
      opponent_invulnerable = v_opponent_invulnerable, opponent_invuln_granted_turn = v_opponent_invuln_granted_turn,
      player_used_ability = v_player_used_ability, player_took_damage = v_player_took_damage,
      opponent_used_ability = v_opponent_used_ability, opponent_took_damage = v_opponent_took_damage,
      player_skip_pending = v_player_skip_pending, opponent_skip_pending = v_opponent_skip_pending,
      player_preparing = v_player_preparing, opponent_preparing = v_opponent_preparing,
      player_preparing_ability_nom = v_player_preparing_ability_nom, opponent_preparing_ability_nom = v_opponent_preparing_ability_nom,
      opponent_ability_cycle_index = v_opponent_ability_cycle_index,
      player_stat_mod_uses = v_player_stat_mod_uses, opponent_stat_mod_uses = v_opponent_stat_mod_uses,
      turn_log = turn_log || v_turns, last_idempotency_key = p_idempotency_key, last_result = v_result
    WHERE id = v_row.id;
  ELSE
    UPDATE autobattle_manual_battles SET
      turn_no = v_turn_no, player_hp = v_player_hp, opponent_hp = v_opponent_hp,
      outcome = v_outcome, turn_log = turn_log || v_turns,
      last_idempotency_key = p_idempotency_key, last_result = v_result
    WHERE id = v_row.id;
  END IF;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION autobattle_resolve_manual_round(bigint, bigint, bigint, text, uuid) TO anon, authenticated;
