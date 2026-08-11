-- ============================================================================
-- Migration autonome : style d'animation par capacite ("normal" ou "soft")
-- sur autobattle_ability_rules, reglable dans l'admin Combat Auto/Manuel.
--
-- Purement visuel (AutoBattleScreen) : n'affecte JAMAIS la resolution du
-- combat cote serveur, donc aucune fonction SQL a mettre a jour ici — juste
-- la nouvelle colonne. A executer UNE FOIS dans l'editeur SQL Supabase
-- (idempotent, peut etre relance sans risque).
-- ============================================================================

-- Style d'animation de l'attaque côté client (AutoBattleScreen) — PUREMENT
-- visuel, aucun effet sur la résolution du combat (jamais lu par les RPC
-- autobattle_resolve_battle/autobattle_resolve_manual_round). 'normal'
-- (défaut) = bond habituel vers l'adversaire. 'soft' = le pokémon reste sur
-- place (léger grossissement/rétrécissement à la place du déplacement) —
-- pensé pour les capacités auto-ciblées (soin, buff sur soi…) où un bond
-- vers l'adversaire n'a pas de sens, mais réglable pour n'importe quelle
-- capacité (voir AdminAutoBattleAbilityRulesPanel).
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS animation_style text NOT NULL DEFAULT 'normal';
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_animation_style_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_animation_style_check
  CHECK (animation_style IN ('normal', 'soft'));
