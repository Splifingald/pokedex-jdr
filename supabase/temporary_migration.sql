-- ============================================================
-- Mode « En ligne » — suivi des tours et invitation à la bataille
-- ------------------------------------------------------------
-- Deux correctifs, à coller ensemble. Idempotent : ré-exécutable sans erreur.
--   1. La contrainte de turn_order_position n'autorisait que 3 valeurs ; les
--      deux modes compacts en demandent 5.
--   2. online_reset_board() incrémentait battle_generation, ce qui réinvitait
--      tout le monde (« Une bataille commence ! ») à chaque simple remise à
--      zéro du plateau. La génération ne bouge plus qu'à l'entrée en mode
--      bataille, qui est le seul moment où une bataille commence vraiment.
-- ============================================================

ALTER TABLE online_state ADD COLUMN IF NOT EXISTS turn_order_position text NOT NULL DEFAULT 'top';
ALTER TABLE online_state DROP CONSTRAINT IF EXISTS online_state_turn_order_position_check;
ALTER TABLE online_state ADD CONSTRAINT online_state_turn_order_position_check
  CHECK (turn_order_position IN ('top', 'bottom', 'compact_top', 'compact_bottom', 'hidden'));

CREATE OR REPLACE FUNCTION online_reset_board()
RETURNS jsonb
LANGUAGE plpgsql
AS $$
BEGIN
  -- WHERE obligatoire : ce projet Supabase refuse les DELETE sans clause WHERE
  -- (garde-fou « DELETE requires a WHERE clause », le même que contourne déjà
  -- netlify/functions/import-display-assets.js avec .neq('id', 0)).
  DELETE FROM online_tokens WHERE id > 0;
  DELETE FROM online_battle_log WHERE id > 0;
  UPDATE online_state
     SET battle_background_nom = '',
         grid_cols     = 16,
         grid_rows     = 10,
         blocked_cells = '[]'::jsonb,
         colored_cells = '{}'::jsonb,
         -- La vue épurée revient à « tout affiché » à chaque remise à zéro.
         hide_layout   = false,
         turn_order    = '[]'::jsonb,
         turn_active_token_id = NULL,
         endgame_phase   = 'none',
         endgame_outcome = NULL,
         endgame_rewards = '{}'::jsonb,
         endgame_acked   = '[]'::jsonb,
         -- battle_generation n'est VOLONTAIREMENT pas incrémenté ici : une
         -- remise à zéro nettoie le plateau, elle ne lance pas une bataille.
         updated_at    = now()
   WHERE id = 1;
  RETURN jsonb_build_object('status', 'ok');
END;
$$;
