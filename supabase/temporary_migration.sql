-- Migration temporaire — À COLLER TEL QUEL dans le SQL Editor Supabase.
-- (Fichier de travail régénéré à chaque tâche, voir CLAUDE.md.)
--
-- Objet : TALENTS DE POKÉMON — effets passifs PAR ESPÈCE, actifs dans tous les
-- modes de combat (Combat Auto, Combat Manuel, PvP, essai PvP) et pour LES DEUX
-- camps (l'adversaire PNJ d'un parcours bénéficie donc du talent de son espèce).
-- Configurés depuis Admin → Mini-Jeux → Talents (AdminAutoBattleTalentsPanel).
-- Une espèce peut cumuler plusieurs talents.
--
-- Types de talents couverts :
--   • stat_boost             modifie les dégâts ou la précision pour tout le
--                            combat, avec conditions cumulables : type(s) de la
--                            capacité jouée, seuil de PV, statut de l'adversaire,
--                            son propre statut, et « à chaque coup adverse
--                            encaissé » (le bonus est alors CUMULATIF) ;
--   • absorb_first_damage    le premier coup encaissé du combat inflige 0 ;
--   • endure_ko              survit à 1 PV la première fois qu'il devrait tomber
--                            K.O. (attaque, contre-coup, brûlure ou poison) ;
--   • poison_damage_boost /  tous les ticks de poison / de brûlure du combat
--     burn_damage_boost      infligent +X, quel que soit le camp qui les subit ;
--   • priority               remplace le tirage au sort d'ouverture ;
--   • inflict_status         % de chances d'infliger un statut, à l'entrée en
--                            combat / à chaque tour / sur un type de capacité ;
--   • status_immunity        insensible aux statuts listés ;
--   • type_immunity          insensible aux dégâts des types listés ;
--   • type_damage_to_heal    les dégâts des types listés le soignent ;
--   • no_recoil              immunisé au contre-coup de ses propres capacités ;
--   • dice_bonus_damage      +X dégâts quand le dé tombe sur une valeur donnée ;
--   • auto_cure_first_status guérit aussitôt le premier statut subi ;
--   • invulnerable_until_hit invulnérable tant qu'il n'a pas porté un coup ;
--   • heal_below_hp          rend des PV en passant sous un seuil (1 fois).
--
-- Chaque déclenchement produit une entrée dédiée dans le journal de combat
-- (talent_tick), avec l'animation choisie en admin et une phrase d'historique.
-- Les passifs permanents sont annoncés AVANT le premier tour : en Combat Manuel
-- et en PvP, les fonctions de démarrage amorcent turn_log avec ces tours pour que
-- l'animation passe avant la première sélection de capacité.
--
-- Notes de conception :
--   • le moteur ne connaît jamais l'espèce — chaque appelant résout les talents
--     avec autobattle_talents_for() et les passe en jsonb ;
--   • la logique est factorisée en helpers de PHASE (autobattle_talent_open /
--     _act / _defend / _survive / _status_guard…) pour n'être écrite qu'une seule
--     fois malgré les deux moteurs (core partagé + boucle inline du Combat Auto) ;
--   • l'état d'un camp est un objet {"shown": [...], "used": [...], "hits": N}
--     (autobattle_combatant_state.talent_state + colonnes *_talent_state) ;
--   • Métamorph ne copie PAS le talent adverse, il garde le sien ;
--   • le filtre de type des piles de modificateurs de PRÉCISION est désormais
--     évalué comme celui des dégâts (les entrées existantes n'ont pas de filtre,
--     donc aucun changement de comportement sur l'existant).
--
-- Rejouable sans risque (idempotent).

-- ========================================================================
-- 1. Table autobattle_talents (+ reprise du cas Métamorph en talent)
-- ========================================================================

-- Talents (effets passifs PAR ESPÈCE, voir AdminAutoBattleTalentsPanel)
-- ============================================================
-- Pendant par ESPÈCE de autobattle_ability_rules (qui est par CAPACITÉ) : un
-- talent s'applique quelle que soit la capacité jouée, dans TOUS les modes
-- (Combat Auto, Combat Manuel, PvP, essai PvP) et pour LES DEUX camps —
-- l'adversaire PNJ d'un parcours bénéficie donc du talent de son espèce.
-- Plusieurs talents par espèce (clé = id serial, pas pokemon_nom), référence
-- pokemon.nom sans FK comme partout ailleurs dans ce schéma (survit aux
-- réimports CSV).
--
-- pokemon.nom_talent / description_talent (colonnes CSV) restent purement
-- descriptives et ne sont jamais lues par le moteur : elles servent seulement
-- à préremplir `nom` à la création depuis l'UI admin.
--
-- kind — chaque valeur n'utilise qu'un sous-ensemble des colonnes ci-dessous :
--   'stat_boost'           modifie une stat (dégâts ou précision) pour tout le
--                          combat. Conditions cumulables : type de la capacité
--                          jouée (type_filter), % de PV restants (hp_condition/
--                          hp_percent), statut de l'adversaire (opponent_status),
--                          son propre statut (self_status), et « à chaque coup
--                          adverse encaissé » (require_damage_taken : le bonus
--                          est alors CUMULATIF, ×  nombre de coups encaissés).
--                          Seuls les COUPS DIRECTS comptent : ni la brûlure ni
--                          le poison n'incrémentent ce compteur.
--   'absorb_first_damage'  le PREMIER coup DIRECT encaissé du combat inflige 0
--                          (la brûlure et le poison ne le consomment pas).
--   'endure_ko'            la PREMIÈRE fois que le pokémon devrait être K.O., il
--                          reste à 1 PV (attaque, contre-coup, brûlure, poison).
--   'poison_damage_boost'  +amount à CHAQUE tick de poison du combat, quel que
--   'burn_damage_boost'    soit le camp qui le subit (idem brûlure).
--   'priority'             amount = priorité d'initiative (0 par défaut) : la
--                          plus haute joue en premier au 1er tour, à la place du
--                          tirage au sort. Égalité = tirage au sort normal.
--   'inflict_status'       percent % de chances d'infliger status_filter[1] à
--                          l'adversaire, au déclencheur `trigger`. Le
--                          déclencheur 'on_ability_type' exige un COUP DIRECT
--                          qui a porté (capacité offensive, non ratée, dégâts
--                          non nuls) ; 'each_turn' se tente avant la capacité,
--                          qu'elle touche ou non.
--   'status_immunity'      insensible aux statuts listés dans status_filter.
--   'type_immunity'        insensible aux dégâts des types listés (type_filter).
--   'type_damage_to_heal'  les dégâts des types listés soignent au lieu de blesser.
--   'no_recoil'            immunisé au contre-coup de ses propres capacités
--                          (autobattle_ability_rules.recoil_type).
--   'dice_bonus_damage'    +amount aux dégâts quand le dé de la capacité tombe
--                          exactement sur dice_value.
--   'auto_cure_first_status' guérit automatiquement le 1er statut subi du combat.
--   'invulnerable_until_hit' invulnérable tant qu'il n'a pas lui-même porté un
--                          coup infligeant des dégâts.
--   'heal_below_hp'        rend des PV la 1ère fois qu'il passe sous hp_percent %
--                          de ses PV max (montant : value_type/amount/amount_max/
--                          percent).
--   'transform'            copie l'ADVERSAIRE pour tout le combat : sprite, type,
--                          liste « super efficace », dégâts de base et movepool —
--                          jamais les PV, ni l'XP, ni le talent adverse. C'est
--                          l'ancien cas spécial « Métamorph », devenu un talent
--                          ordinaire pour que tout passe par la même mécanique.
--                          Non configurable (comme 'no_recoil') et actif dans les
--                          deux sens (pokémon du joueur OU adversaire d'un
--                          niveau) ; sans effet en PvP, qui n'a jamais géré la
--                          copie. Voir autobattle_resolve_battle.
--   'heavy_sleeper'        « Somnolent » : endormi, il lui faut un 6 EXACT au dé
--                          pour se réveiller, au lieu de 4, 5 ou 6. Handicap en
--                          apparence, mais avantageux avec un soin passif
--                          « jusqu'au réveil ». Non configurable.
--
-- value_type : 'flat' (amount), 'percent_max_hp' (percent) ou 'range'
-- (amount..amount_max) — mutualisé pour tous les montants tirés au sort.
--
-- animation : jouée sur le pokémon lui-même au moment du déclenchement (mêmes
-- identifiants que attacks.animation, voir src/lib/battleAnimations.ts) —
-- NULL = 'idle' côté client.
CREATE TABLE IF NOT EXISTS autobattle_talents (
  id            bigserial PRIMARY KEY,
  pokemon_nom   text NOT NULL,
  nom           text NOT NULL DEFAULT '',
  kind          text NOT NULL DEFAULT 'stat_boost',
  animation     text,
  stat          text,
  amount        integer,
  type_filter   text[],
  hp_condition  text,
  hp_percent    integer,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_autobattle_talents_pokemon_nom ON autobattle_talents(pokemon_nom);

-- Colonnes ajoutées avec la 2e salve de talents (voir kind ci-dessus).
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS value_type text;
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS amount_max integer;
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS percent integer;
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS status_filter text[];
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS opponent_status text;
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS self_status text;
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS require_damage_taken boolean NOT NULL DEFAULT false;
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS trigger text;
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS dice_value integer;
-- Nombre maximum de déclenchements d'un bonus CUMULATIF (require_damage_taken) :
-- NULL = illimité. Au-delà, les coups encaissés n'augmentent plus le bonus.
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS max_uses integer;
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_max_uses_check;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_max_uses_check
  CHECK (max_uses IS NULL OR max_uses >= 1);

ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_kind_check;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_kind_check
  CHECK (kind IN (
    'stat_boost', 'absorb_first_damage', 'endure_ko',
    'poison_damage_boost', 'burn_damage_boost', 'priority', 'inflict_status',
    'status_immunity', 'type_immunity', 'type_damage_to_heal', 'no_recoil',
    'dice_bonus_damage', 'auto_cure_first_status', 'invulnerable_until_hit',
    'heal_below_hp', 'transform', 'heavy_sleeper'));
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_animation_check;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_animation_check
  CHECK (animation IS NULL OR animation IN (
    'idle', 'jump_attack', 'strike', 'stomp', 'beam', 'projectile',
    'multi_projectile', 'bomb', 'round_motion', 'jump', 'fade'));
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_stat_check;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_stat_check
  CHECK (stat IS NULL OR stat IN ('damage', 'precision'));
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_hp_condition_check;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_hp_condition_check
  CHECK (hp_condition IS NULL OR hp_condition IN ('below', 'above'));
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_value_type_check;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_value_type_check
  CHECK (value_type IS NULL OR value_type IN ('flat', 'percent_max_hp', 'range'));
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_trigger_check;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_trigger_check
  CHECK (trigger IS NULL OR trigger IN ('battle_start', 'each_turn', 'on_ability_type'));
-- 'any' = n'importe quel statut, sinon un statut précis (mêmes valeurs que
-- attacks.status_effect).
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_opponent_status_check;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_opponent_status_check
  CHECK (opponent_status IS NULL OR opponent_status IN ('any', 'paralysis', 'fear', 'confusion', 'sleep', 'burn', 'poison', 'frozen'));
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_self_status_check;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_self_status_check
  CHECK (self_status IS NULL OR self_status IN ('any', 'paralysis', 'fear', 'confusion', 'sleep', 'burn', 'poison', 'frozen'));

-- Champs obligatoires par kind — l'UI admin envoie toujours un groupe cohérent,
-- ces contraintes ne font qu'empêcher une configuration inexploitable.
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_stat_boost_fields;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_stat_boost_fields
  CHECK (kind <> 'stat_boost' OR (stat IS NOT NULL AND amount IS NOT NULL));
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_hp_fields;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_hp_fields
  CHECK (
    (hp_condition IS NULL AND (kind <> 'heal_below_hp') AND hp_percent IS NULL)
    OR (kind = 'heal_below_hp' AND hp_percent IS NOT NULL AND hp_percent BETWEEN 1 AND 100)
    OR (hp_condition IS NOT NULL AND hp_percent IS NOT NULL AND hp_percent BETWEEN 1 AND 100)
  );
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_amount_fields;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_amount_fields
  CHECK (kind NOT IN ('poison_damage_boost', 'burn_damage_boost', 'priority', 'dice_bonus_damage') OR amount IS NOT NULL);
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_dice_fields;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_dice_fields
  CHECK (kind <> 'dice_bonus_damage' OR (dice_value IS NOT NULL AND dice_value >= 1));
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_inflict_fields;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_inflict_fields
  CHECK (
    kind <> 'inflict_status'
    OR (percent IS NOT NULL AND percent BETWEEN 1 AND 100
        AND status_filter IS NOT NULL AND array_length(status_filter, 1) >= 1
        AND trigger IS NOT NULL)
  );
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_list_fields;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_list_fields
  CHECK (
    (kind <> 'status_immunity' OR (status_filter IS NOT NULL AND array_length(status_filter, 1) >= 1))
    AND (kind NOT IN ('type_immunity', 'type_damage_to_heal') OR (type_filter IS NOT NULL AND array_length(type_filter, 1) >= 1))
  );
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_heal_fields;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_heal_fields
  CHECK (
    kind <> 'heal_below_hp'
    OR (COALESCE(value_type, 'flat') = 'flat' AND amount IS NOT NULL AND amount > 0)
    OR (value_type = 'percent_max_hp' AND percent IS NOT NULL AND percent BETWEEN 1 AND 100)
    OR (value_type = 'range' AND amount IS NOT NULL AND amount_max IS NOT NULL AND amount_max >= amount AND amount > 0)
  );

ALTER TABLE autobattle_talents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read autobattle_talents" ON autobattle_talents;
DROP POLICY IF EXISTS "Public insert autobattle_talents" ON autobattle_talents;
DROP POLICY IF EXISTS "Public update autobattle_talents" ON autobattle_talents;
DROP POLICY IF EXISTS "Public delete autobattle_talents" ON autobattle_talents;
CREATE POLICY "Public read autobattle_talents"   ON autobattle_talents FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_talents" ON autobattle_talents FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_talents" ON autobattle_talents FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete autobattle_talents" ON autobattle_talents FOR DELETE TO anon USING (true);

-- Reprise du cas spécial « Métamorph », qui était codé en dur sur le nom
-- d'espèce dans les moteurs : il devient un talent ordinaire. Semé ici pour que
-- le comportement existant survive à la migration sans intervention manuelle.
-- Rejouable : ne réinsère rien si l'espèce a déjà un talent de transformation
-- (l'admin reste libre de le renommer, de changer son animation ou de le
-- supprimer ensuite).
INSERT INTO autobattle_talents (pokemon_nom, nom, kind, animation)
SELECT 'Métamorph', 'Morphing', 'transform', 'fade'
WHERE EXISTS (SELECT 1 FROM pokemon WHERE nom = 'Métamorph')
  AND NOT EXISTS (SELECT 1 FROM autobattle_talents WHERE pokemon_nom = 'Métamorph' AND kind = 'transform');

-- ========================================================================
-- 2. Bascule globale des talents (sur le modèle de precision_enabled)
-- ========================================================================

-- À faux, aucun talent n'est lu ni déclenché dans le mode concerné — les
-- configurations de talents restent intactes en base.
ALTER TABLE autobattle_config ADD COLUMN IF NOT EXISTS talents_enabled boolean NOT NULL DEFAULT true;
ALTER TABLE pvp_config ADD COLUMN IF NOT EXISTS talents_enabled boolean NOT NULL DEFAULT true;

-- ========================================================================
-- 3. État de combat : talents déjà déclenchés (une colonne par camp et par mode)
-- ========================================================================

ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_talent_state jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_talent_state jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_talent_state jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_talent_state jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_talent_state jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_talent_state jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Le DEFAULT est passé d'un tableau à un OBJET en cours de développement :
-- ADD COLUMN IF NOT EXISTS ne le corrige pas sur une base déjà migrée.
ALTER TABLE autobattle_manual_battles ALTER COLUMN player_talent_state SET DEFAULT '{}'::jsonb;
ALTER TABLE autobattle_manual_battles ALTER COLUMN opponent_talent_state SET DEFAULT '{}'::jsonb;
ALTER TABLE pvp_battles ALTER COLUMN attacker_talent_state SET DEFAULT '{}'::jsonb;
ALTER TABLE pvp_battles ALTER COLUMN defender_talent_state SET DEFAULT '{}'::jsonb;
ALTER TABLE pvp_trial_battles ALTER COLUMN attacker_talent_state SET DEFAULT '{}'::jsonb;
ALTER TABLE pvp_trial_battles ALTER COLUMN defender_talent_state SET DEFAULT '{}'::jsonb;

-- ========================================================================
-- 4. Helpers de talents (partagés par les deux moteurs)
-- ========================================================================

-- Talents : helpers partagés par LES DEUX moteurs
-- ============================================================
-- Le moteur ne connaît jamais l'espèce (voir le commentaire du core plus bas) :
-- chaque appelant résout les talents de son camp avec autobattle_talents_for et
-- les passe sous forme de tableau jsonb (une entrée = une ligne de la table,
-- clés identiques aux colonnes).
--
-- Les helpers sont regroupés par PHASE de combat plutôt que par talent : chaque
-- phase est un seul appel côté moteur, qui renvoie l'état mis à jour et les
-- éventuelles entrées de journal à insérer. Sans ça, les 15 types de talents
-- devraient être recopiés inline dans les deux moteurs (voir la duplication
-- assumée entre autobattle_resolve_round_core et autobattle_resolve_battle).
--
-- L'état d'un camp (autobattle_combatant_state.talent_state, colonnes
-- *_talent_state) est un objet :
--   {"shown": [ids déjà annoncés], "used": [ids déjà consommés], "hits": N}
-- où `hits` compte les coups ADVERSES encaissés (pas la brûlure ni le poison),
-- pour les bonus de stat cumulatifs (require_damage_taken).

-- p_enabled = bascule globale du mode (autobattle_config.talents_enabled ou
-- pvp_config.talents_enabled, sur le modèle de precision_enabled) : à faux, la
-- fonction renvoie une liste vide et TOUT le système de talents devient inerte
-- sans qu'aucun autre point du moteur n'ait à le savoir — les configurations
-- restent intactes en base.
CREATE OR REPLACE FUNCTION autobattle_talents_for(p_pokemon_nom text, p_enabled boolean DEFAULT true)
RETURNS jsonb
LANGUAGE sql STABLE
AS $$
  SELECT CASE WHEN COALESCE(p_enabled, true) THEN
    COALESCE((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.id) FROM autobattle_talents t WHERE t.pokemon_nom = p_pokemon_nom), '[]'::jsonb)
  ELSE '[]'::jsonb END
$$;

CREATE OR REPLACE FUNCTION autobattle_talent_state_init()
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT '{"shown": [], "used": [], "hits": 0}'::jsonb
$$;

-- p_key vaut 'shown' (déjà annoncé au joueur) ou 'used' (déjà consommé).
CREATE OR REPLACE FUNCTION autobattle_talent_has(p_state jsonb, p_talent jsonb, p_key text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(p_state -> p_key, '[]'::jsonb) @> jsonb_build_array((p_talent ->> 'id')::bigint)
$$;

-- jsonb_set exige un OBJET : on normalise, pour rester tolérant à un état
-- absent ou resté à la valeur par défaut d'une base pas encore migrée.
CREATE OR REPLACE FUNCTION autobattle_talent_mark(p_state jsonb, p_talent jsonb, p_key text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_set(
    CASE WHEN jsonb_typeof(p_state) = 'object' THEN p_state ELSE autobattle_talent_state_init() END,
    ARRAY[p_key],
    COALESCE(p_state -> p_key, '[]'::jsonb) || jsonb_build_array((p_talent ->> 'id')::bigint)
  )
$$;

CREATE OR REPLACE FUNCTION autobattle_talent_hits(p_state jsonb)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE((p_state ->> 'hits')::integer, 0)
$$;

-- Filtre de type : p_empty = ce que vaut une liste vide/absente (true pour un
-- bonus de stat « tous types », false pour une immunité qui doit lister ses types).
CREATE OR REPLACE FUNCTION autobattle_talent_type_match(p_list jsonb, p_type text, p_empty boolean)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN jsonb_typeof(p_list) IS DISTINCT FROM 'array' OR jsonb_array_length(p_list) = 0 THEN p_empty
    ELSE EXISTS (
      SELECT 1 FROM jsonb_array_elements_text(p_list) f
      WHERE lower(trim(f)) = lower(trim(COALESCE(p_type, '')))
    )
  END
$$;

CREATE OR REPLACE FUNCTION autobattle_talent_status_match(p_list jsonb, p_status text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT p_status IS NOT NULL AND jsonb_typeof(p_list) = 'array'
     AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(p_list) f WHERE f = p_status)
$$;

-- Condition « statut » d'un bonus de stat : NULL = pas de condition, 'any' =
-- n'importe quel statut, sinon ce statut précis.
CREATE OR REPLACE FUNCTION autobattle_talent_status_cond(p_cond text, p_status text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT p_cond IS NULL
      OR (p_cond = 'any' AND p_status IS NOT NULL)
      OR p_cond = p_status
$$;

-- Montant tiré d'un talent (soin de 'heal_below_hp') : plat, % des PV max, ou
-- fourchette aléatoire. VOLATILE (random).
CREATE OR REPLACE FUNCTION autobattle_talent_value(p_talent jsonb, p_max_hp integer)
RETURNS integer LANGUAGE sql AS $$
  SELECT GREATEST(0, CASE COALESCE(p_talent ->> 'value_type', 'flat')
    WHEN 'percent_max_hp' THEN floor(COALESCE(p_max_hp, 0) * COALESCE((p_talent ->> 'percent')::integer, 0) / 100.0)::integer
    WHEN 'range' THEN COALESCE((p_talent ->> 'amount')::integer, 0)
      + floor(random() * (COALESCE((p_talent ->> 'amount_max')::integer, 0) - COALESCE((p_talent ->> 'amount')::integer, 0) + 1))::integer
    ELSE COALESCE((p_talent ->> 'amount')::integer, 0)
  END)
$$;

-- Résumé lisible du déclenchement, affiché tel quel dans l'historique de combat
-- (le client n'a pas à reconstruire la phrase, voir AutoBattleTurn.talent_detail).
CREATE OR REPLACE FUNCTION autobattle_talent_detail(p_talent jsonb)
RETURNS text
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE (p_talent ->> 'kind')
    WHEN 'absorb_first_damage' THEN 'absorbe les premiers dégâts reçus'
    WHEN 'endure_ko' THEN 'encaisse le coup fatal et reste à 1 PV'
    WHEN 'poison_damage_boost' THEN 'les dégâts de poison sont augmentés de ' || COALESCE(p_talent ->> 'amount', '0')
    WHEN 'burn_damage_boost' THEN 'les dégâts de brûlure sont augmentés de ' || COALESCE(p_talent ->> 'amount', '0')
    WHEN 'priority' THEN 'priorité d''initiative ' || COALESCE(p_talent ->> 'amount', '0')
    WHEN 'inflict_status' THEN 'peut infliger un statut à l''adversaire (' || COALESCE(p_talent ->> 'percent', '0') || ' %)'
    WHEN 'status_immunity' THEN 'insensible à certains statuts'
    WHEN 'type_immunity' THEN 'insensible aux dégâts de ce type'
    WHEN 'type_damage_to_heal' THEN 'les dégâts de ce type le soignent'
    WHEN 'no_recoil' THEN 'ne subit aucun contre-coup'
    WHEN 'dice_bonus_damage' THEN 'dé à ' || COALESCE(p_talent ->> 'dice_value', '?') || ' : +' || COALESCE(p_talent ->> 'amount', '0') || ' dégâts'
    WHEN 'auto_cure_first_status' THEN 'guérit aussitôt le premier statut subi'
    WHEN 'invulnerable_until_hit' THEN 'invulnérable tant qu''il n''a pas porté un coup'
    WHEN 'heal_below_hp' THEN 'récupère des PV en passant sous ' || COALESCE(p_talent ->> 'hp_percent', '0') || ' % de ses PV'
    WHEN 'transform' THEN 'prend l''apparence et les capacités de son adversaire'
    WHEN 'heavy_sleeper' THEN 'ne se réveille que sur un 6'
    WHEN 'stat_boost' THEN
      (CASE WHEN COALESCE((p_talent ->> 'amount')::integer, 0) >= 0 THEN '+' ELSE '' END)
      || COALESCE(p_talent ->> 'amount', '0')
      || (CASE WHEN (p_talent ->> 'stat') = 'precision' THEN ' précision' ELSE ' dégâts' END)
      || COALESCE(
           (SELECT ' (' || string_agg(f, ', ') || ')'
            FROM jsonb_array_elements_text(
              CASE WHEN jsonb_typeof(p_talent -> 'type_filter') = 'array' THEN p_talent -> 'type_filter' ELSE '[]'::jsonb END
            ) f),
           '')
      || (CASE WHEN COALESCE((p_talent ->> 'require_damage_taken')::boolean, false) THEN ' par coup encaissé' ELSE '' END)
      || (CASE
            WHEN (p_talent ->> 'hp_condition') = 'below' THEN ' quand les PV sont ≤ ' || (p_talent ->> 'hp_percent') || ' %'
            WHEN (p_talent ->> 'hp_condition') = 'above' THEN ' quand les PV sont ≥ ' || (p_talent ->> 'hp_percent') || ' %'
            ELSE '' END)
      || (CASE WHEN (p_talent ->> 'opponent_status') IS NOT NULL THEN ' quand l''adversaire est affecté par un statut' ELSE '' END)
      || (CASE WHEN (p_talent ->> 'self_status') IS NOT NULL THEN ' quand il est lui-même affecté par un statut' ELSE '' END)
    ELSE ''
  END
$$;

-- Entrée de journal d'un déclenchement de talent. `attacker` désigne le camp
-- PROPRIÉTAIRE du talent (pas un attaquant), et defender_hp_after n'a pas de
-- sens ici : il reprend les PV du propriétaire uniquement pour respecter la
-- forme d'AutoBattleTurn. Le client resynchronise les PV sur attacker_hp_after
-- (indispensable pour 'endure_ko' et 'heal_below_hp', qui les modifient).
CREATE OR REPLACE FUNCTION autobattle_talent_turn(p_turn_no integer, p_side text, p_hp integer, p_talent jsonb, p_extra jsonb)
RETURNS jsonb
LANGUAGE sql IMMUTABLE
AS $$
  SELECT jsonb_build_object(
    'turn', p_turn_no,
    'attacker', p_side,
    'damage', 0,
    'defender_hp_after', GREATEST(0, COALESCE(p_hp, 0)),
    'attacker_hp_after', GREATEST(0, COALESCE(p_hp, 0)),
    'ko', false,
    'talent_tick', true,
    'talent_nom', COALESCE(NULLIF(trim(COALESCE(p_talent ->> 'nom', '')), ''), 'Talent'),
    'talent_kind', p_talent ->> 'kind',
    'talent_animation', p_talent ->> 'animation',
    'talent_detail', autobattle_talent_detail(p_talent)
  ) || COALESCE(p_extra, '{}'::jsonb)
$$;

-- ── Bonus de stat ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION autobattle_talent_stat_active(
  p_talent jsonb, p_ability_type text, p_hp integer, p_max_hp integer,
  p_opp_status text, p_self_status text, p_hits integer)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT (p_talent ->> 'kind') = 'stat_boost'
    AND autobattle_talent_type_match(p_talent -> 'type_filter', p_ability_type, true)
    AND (
      (p_talent ->> 'hp_condition') IS NULL
      OR ((p_talent ->> 'hp_condition') = 'below'
          AND COALESCE(p_hp, 0) * 100 <= GREATEST(1, COALESCE(p_max_hp, 1)) * (p_talent ->> 'hp_percent')::integer)
      OR ((p_talent ->> 'hp_condition') = 'above'
          AND COALESCE(p_hp, 0) * 100 >= GREATEST(1, COALESCE(p_max_hp, 1)) * (p_talent ->> 'hp_percent')::integer)
    )
    AND autobattle_talent_status_cond(p_talent ->> 'opponent_status', p_opp_status)
    AND autobattle_talent_status_cond(p_talent ->> 'self_status', p_self_status)
    -- Bonus cumulatif « à chaque coup encaissé » : inactif tant qu'aucun coup
    -- adverse n'a touché (voir hits, incrémenté par autobattle_talent_defend).
    AND (NOT COALESCE((p_talent ->> 'require_damage_taken')::boolean, false) OR COALESCE(p_hits, 0) >= 1)
$$;

CREATE OR REPLACE FUNCTION autobattle_talent_stat_bonus(
  p_talents jsonb, p_state jsonb, p_stat text, p_ability_type text, p_hp integer, p_max_hp integer,
  p_opp_status text, p_self_status text)
RETURNS integer
LANGUAGE sql IMMUTABLE
AS $$
  -- Bonus cumulatif : ×  nombre de coups encaissés, plafonné à max_uses.
  SELECT COALESCE(SUM(
    (t ->> 'amount')::integer
    * (CASE WHEN COALESCE((t ->> 'require_damage_taken')::boolean, false)
            THEN LEAST(autobattle_talent_hits(p_state), COALESCE((t ->> 'max_uses')::integer, autobattle_talent_hits(p_state)))
            ELSE 1 END)
  ), 0)::integer
  FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t
  WHERE (t ->> 'stat') = p_stat
    AND autobattle_talent_stat_active(t, p_ability_type, p_hp, p_max_hp, p_opp_status, p_self_status, autobattle_talent_hits(p_state))
$$;

-- ── Phase 1 : ouverture du combat ────────────────────────────────────────────
-- Annonce (animation + ligne d'historique, tour 0) tous les talents PERMANENTS,
-- c'est-à-dire ceux qui agissent sans condition dès le premier tour. Les talents
-- conditionnels ou ponctuels s'annoncent au moment où ils se déclenchent.
CREATE OR REPLACE FUNCTION autobattle_talent_open(p_talents jsonb, p_side text, p_hp integer)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_state jsonb := autobattle_talent_state_init();
  v_turns jsonb := '[]'::jsonb;
  v_t     jsonb;
BEGIN
  FOR v_t IN SELECT * FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) LOOP
    IF (v_t ->> 'kind') IN ('poison_damage_boost', 'burn_damage_boost', 'status_immunity',
                            'type_immunity', 'type_damage_to_heal', 'no_recoil', 'invulnerable_until_hit',
                            'transform', 'heavy_sleeper')
       OR ((v_t ->> 'kind') = 'priority' AND COALESCE((v_t ->> 'amount')::integer, 0) <> 0)
       OR ((v_t ->> 'kind') = 'stat_boost'
           AND (v_t ->> 'hp_condition') IS NULL
           AND (v_t ->> 'opponent_status') IS NULL
           AND (v_t ->> 'self_status') IS NULL
           AND NOT COALESCE((v_t ->> 'require_damage_taken')::boolean, false))
    THEN
      v_turns := v_turns || jsonb_build_array(autobattle_talent_turn(0, p_side, p_hp, v_t, NULL));
      v_state := autobattle_talent_mark(v_state, v_t, 'shown');
    END IF;
  END LOOP;
  RETURN jsonb_build_object('turns', v_turns, 'state', v_state);
END;
$$;

-- Priorité d'initiative : la plus haute des priorités configurées (0 par défaut).
CREATE OR REPLACE FUNCTION autobattle_talent_priority(p_talents jsonb)
RETURNS integer
LANGUAGE sql IMMUTABLE
AS $$
  SELECT COALESCE(MAX((t ->> 'amount')::integer), 0)::integer
  FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t
  WHERE (t ->> 'kind') = 'priority'
$$;

-- ── Phase 2 : début du tour d'un camp ────────────────────────────────────────
-- Annonce les bonus de stat CONDITIONNELS qui viennent de devenir actifs, puis
-- tente les infligeurs de statut ('inflict_status') dont le déclencheur
-- correspond. p_trigger vaut 'battle_start', 'each_turn' ou 'on_ability_type'.
-- p_opp_talents/p_opp_status servent à respecter l'immunité et à ne pas écraser
-- un statut déjà en place. Renvoie {"state", "turns", "inflict_status"}.
CREATE OR REPLACE FUNCTION autobattle_talent_act(
  p_talents jsonb, p_state jsonb, p_side text, p_trigger text, p_ability_type text,
  p_hp integer, p_max_hp integer, p_opp_status text, p_self_status text,
  p_opp_talents jsonb, p_turn_no integer)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_state   jsonb := COALESCE(p_state, autobattle_talent_state_init());
  v_turns   jsonb := '[]'::jsonb;
  v_status  text;
  v_t       jsonb;
BEGIN
  FOR v_t IN SELECT * FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) LOOP
    -- Les bonus CUMULATIFS s'annoncent eux-mêmes à chaque coup encaissé (voir
    -- autobattle_talent_defend) : les exclure ici évite une annonce en double.
    IF NOT COALESCE((v_t ->> 'require_damage_taken')::boolean, false)
       AND autobattle_talent_stat_active(v_t, p_ability_type, p_hp, p_max_hp, p_opp_status, p_self_status, autobattle_talent_hits(v_state))
       AND NOT autobattle_talent_has(v_state, v_t, 'shown') THEN
      v_turns := v_turns || jsonb_build_array(autobattle_talent_turn(p_turn_no, p_side, p_hp, v_t, NULL));
      v_state := autobattle_talent_mark(v_state, v_t, 'shown');
    END IF;

    IF (v_t ->> 'kind') = 'inflict_status'
       AND (v_t ->> 'trigger') = p_trigger
       AND v_status IS NULL
       AND p_opp_status IS NULL
       AND ((v_t ->> 'trigger') <> 'on_ability_type'
            OR autobattle_talent_type_match(v_t -> 'type_filter', p_ability_type, true))
       AND random() * 100 < COALESCE((v_t ->> 'percent')::integer, 0)
    THEN
      v_status := (v_t -> 'status_filter' ->> 0);
      -- Immunité de la cible : le talent ne se déclenche pas du tout (pas
      -- d'animation ni de ligne d'historique pour un effet sans effet).
      IF EXISTS (
        SELECT 1 FROM jsonb_array_elements(COALESCE(p_opp_talents, '[]'::jsonb)) o
        WHERE (o ->> 'kind') = 'status_immunity' AND autobattle_talent_status_match(o -> 'status_filter', v_status)
      ) THEN
        v_status := NULL;
      ELSE
        -- talent_inflicted_status : le client s'en sert pour afficher le badge
        -- de statut sur l'ADVERSAIRE du porteur (un tour de talent n'est pas un
        -- tour d'attaque, il ne passe donc pas par 'status_applied').
        v_turns := v_turns || jsonb_build_array(
          autobattle_talent_turn(p_turn_no, p_side, p_hp, v_t, jsonb_build_object('talent_inflicted_status', v_status)));
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('state', v_state, 'turns', v_turns, 'inflict_status', v_status);
END;
$$;

-- ── Phase 3 : dégâts reçus ───────────────────────────────────────────────────
-- Applique, dans cet ordre, l'immunité de type, la conversion des dégâts en
-- soin, puis l'absorption du premier coup ; compte le coup encaissé (hits) si
-- des dégâts passent malgré tout. Renvoie {"damage", "heal", "state", "turns"}.
--
-- INVARIANT : cette fonction n'est appelée QUE sur un coup direct (l'attaque
-- d'un camp qui a touché), jamais sur un tick de brûlure ou de poison — ceux-ci
-- ne passent que par autobattle_talent_survive. C'est ce qui garantit que
-- `hits` (et donc les bonus cumulatifs require_damage_taken) et l'absorption du
-- premier coup ne se déclenchent que sur des coups directs. Ne pas appeler
-- cette fonction depuis un tick de statut.
CREATE OR REPLACE FUNCTION autobattle_talent_defend(
  p_talents jsonb, p_state jsonb, p_side text, p_damage integer, p_ability_type text,
  p_hp integer, p_turn_no integer, p_status text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_state  jsonb := COALESCE(p_state, autobattle_talent_state_init());
  v_turns  jsonb := '[]'::jsonb;
  v_damage integer := GREATEST(0, COALESCE(p_damage, 0));
  v_heal   integer := 0;
  v_status text := p_status;
  v_t      jsonb;
BEGIN
  IF v_damage > 0 THEN
    SELECT t INTO v_t FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t
      WHERE (t ->> 'kind') = 'type_damage_to_heal'
        AND autobattle_talent_type_match(t -> 'type_filter', p_ability_type, false)
      ORDER BY (t ->> 'id')::bigint LIMIT 1;
    IF v_t IS NOT NULL THEN
      v_heal := v_damage;
      v_damage := 0;
      -- 'heal' en plus de 'talent_absorbed' : c'est bien un SOIN, le client doit
      -- l'afficher comme tel et en tirer la guérison du poison.
      v_turns := v_turns || jsonb_build_array(
        autobattle_talent_turn(p_turn_no, p_side, p_hp, v_t, jsonb_build_object('talent_absorbed', v_heal, 'heal', v_heal)));
    END IF;
  END IF;

  IF v_damage > 0 THEN
    SELECT t INTO v_t FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t
      WHERE (t ->> 'kind') = 'type_immunity'
        AND autobattle_talent_type_match(t -> 'type_filter', p_ability_type, false)
      ORDER BY (t ->> 'id')::bigint LIMIT 1;
    IF v_t IS NOT NULL THEN
      v_turns := v_turns || jsonb_build_array(autobattle_talent_turn(p_turn_no, p_side, p_hp, v_t, jsonb_build_object('talent_absorbed', v_damage)));
      v_damage := 0;
    END IF;
  END IF;

  IF v_damage > 0 THEN
    SELECT t INTO v_t FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t
      WHERE (t ->> 'kind') = 'absorb_first_damage' AND NOT autobattle_talent_has(v_state, t, 'used')
      ORDER BY (t ->> 'id')::bigint LIMIT 1;
    IF v_t IS NOT NULL THEN
      v_turns := v_turns || jsonb_build_array(autobattle_talent_turn(p_turn_no, p_side, p_hp, v_t, jsonb_build_object('talent_absorbed', v_damage)));
      v_state := autobattle_talent_mark(autobattle_talent_mark(v_state, v_t, 'used'), v_t, 'shown');
      v_damage := 0;
    END IF;
  END IF;

  IF v_damage > 0 THEN
    v_state := jsonb_set(v_state, '{hits}', to_jsonb(autobattle_talent_hits(v_state) + 1));
    -- Bonus cumulatifs : ils augmentent À CE COUP PRÉCIS, donc ils s'annoncent
    -- (animation + ligne d'historique) à CHAQUE fois, pas seulement la première
    -- — tant que le plafond max_uses n'est pas atteint.
    FOR v_t IN SELECT * FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) LOOP
      IF (v_t ->> 'kind') = 'stat_boost'
         AND COALESCE((v_t ->> 'require_damage_taken')::boolean, false)
         AND autobattle_talent_hits(v_state) <= COALESCE((v_t ->> 'max_uses')::integer, autobattle_talent_hits(v_state))
      THEN
        v_turns := v_turns || jsonb_build_array(autobattle_talent_turn(
          p_turn_no, p_side, p_hp, v_t,
          jsonb_build_object(
            'talent_stack', autobattle_talent_hits(v_state),
            -- Détail explicite : le gain de CE coup, et le total accumulé.
            'talent_detail',
              (CASE WHEN (v_t ->> 'amount')::integer >= 0 THEN '+' ELSE '' END) || (v_t ->> 'amount')
              || (CASE WHEN (v_t ->> 'stat') = 'precision' THEN ' précision' ELSE ' dégâts' END)
              || ' (total ' || ((v_t ->> 'amount')::integer * autobattle_talent_hits(v_state))::text || ')')));
        v_state := autobattle_talent_mark(v_state, v_t, 'shown');
      END IF;
    END LOOP;
  END IF;

  -- Le poison est guéri par N'IMPORTE QUEL soin (voir status_effect 'poison') —
  -- y compris celui d'un talent qui convertit les dégâts reçus en soin.
  IF v_heal > 0 AND v_status = 'poison' THEN
    v_status := NULL;
  END IF;

  RETURN jsonb_build_object('damage', v_damage, 'heal', v_heal, 'state', v_state, 'turns', v_turns, 'status', v_status);
END;
$$;

-- ── Phase 4 : survie ─────────────────────────────────────────────────────────
-- À appeler après CHAQUE perte de PV (coup encaissé, contre-coup, brûlure,
-- poison) et AVANT de figer le drapeau 'ko' de l'entrée de tour : encaisse le
-- K.O. ('endure_ko') puis déclenche le soin de seuil ('heal_below_hp').
-- Renvoie {"hp", "state", "turns"}.
CREATE OR REPLACE FUNCTION autobattle_talent_survive(
  p_talents jsonb, p_state jsonb, p_side text, p_hp integer, p_max_hp integer, p_turn_no integer,
  p_status text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_state  jsonb := COALESCE(p_state, autobattle_talent_state_init());
  v_turns  jsonb := '[]'::jsonb;
  v_hp     integer := p_hp;
  v_hp_before_heal integer;
  v_heal   integer;
  v_status text := p_status;
  v_t      jsonb;
BEGIN
  IF v_hp <= 0 THEN
    SELECT t INTO v_t FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t
      WHERE (t ->> 'kind') = 'endure_ko' AND NOT autobattle_talent_has(v_state, t, 'used')
      ORDER BY (t ->> 'id')::bigint LIMIT 1;
    IF v_t IS NOT NULL THEN
      v_hp := 1;
      v_state := autobattle_talent_mark(autobattle_talent_mark(v_state, v_t, 'used'), v_t, 'shown');
      v_turns := v_turns || jsonb_build_array(autobattle_talent_turn(p_turn_no, p_side, v_hp, v_t, NULL));
    END IF;
  END IF;

  IF v_hp > 0 THEN
    SELECT t INTO v_t FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t
      WHERE (t ->> 'kind') = 'heal_below_hp'
        AND NOT autobattle_talent_has(v_state, t, 'used')
        AND v_hp * 100 <= GREATEST(1, COALESCE(p_max_hp, 1)) * (t ->> 'hp_percent')::integer
      ORDER BY (t ->> 'id')::bigint LIMIT 1;
    IF v_t IS NOT NULL THEN
      v_heal := autobattle_talent_value(v_t, p_max_hp);
      v_hp_before_heal := v_hp;
      v_hp := LEAST(GREATEST(1, COALESCE(p_max_hp, 1)), v_hp + v_heal);
      v_state := autobattle_talent_mark(autobattle_talent_mark(v_state, v_t, 'used'), v_t, 'shown');
      v_turns := v_turns || jsonb_build_array(autobattle_talent_turn(p_turn_no, p_side, v_hp, v_t, jsonb_build_object('heal', v_heal)));
      -- Le poison est guéri par N'IMPORTE QUEL soin (voir status_effect 'poison').
      IF v_heal > 0 AND v_status = 'poison' THEN
        v_status := NULL;
      END IF;
    END IF;
  END IF;

  -- hp_before_heal : PV juste après les dégâts (et l'éventuel 'endure_ko'),
  -- AVANT le soin de seuil. L'entrée de tour affiche cette valeur pour que la
  -- chute soit visible ; le tour de talent qui suit remonte les PV, ce qui rend
  -- le soin lisible au lieu de l'escamoter dans le même instant.
  RETURN jsonb_build_object(
    'hp', v_hp, 'hp_before_heal', COALESCE(v_hp_before_heal, v_hp),
    'state', v_state, 'turns', v_turns, 'status', v_status);
END;
$$;

-- ── Phase 5 : statut subi ────────────────────────────────────────────────────
-- Immunité ('status_immunity', permanente) et guérison automatique du premier
-- statut ('auto_cure_first_status', usage unique). Renvoie
-- {"blocked", "state", "turns"} — blocked = le statut ne s'applique pas.
CREATE OR REPLACE FUNCTION autobattle_talent_status_guard(
  p_talents jsonb, p_state jsonb, p_side text, p_status text, p_hp integer, p_turn_no integer)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_state jsonb := COALESCE(p_state, autobattle_talent_state_init());
  v_turns jsonb := '[]'::jsonb;
  v_t     jsonb;
BEGIN
  IF p_status IS NULL THEN
    RETURN jsonb_build_object('blocked', false, 'state', v_state, 'turns', v_turns);
  END IF;

  -- L'immunité est déjà annoncée en ouverture de combat : pas de tour ici, le
  -- statut est simplement ignoré.
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t
    WHERE (t ->> 'kind') = 'status_immunity' AND autobattle_talent_status_match(t -> 'status_filter', p_status)
  ) THEN
    RETURN jsonb_build_object('blocked', true, 'state', v_state, 'turns', v_turns);
  END IF;

  SELECT t INTO v_t FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t
    WHERE (t ->> 'kind') = 'auto_cure_first_status' AND NOT autobattle_talent_has(v_state, t, 'used')
    ORDER BY (t ->> 'id')::bigint LIMIT 1;
  IF v_t IS NOT NULL THEN
    v_state := autobattle_talent_mark(autobattle_talent_mark(v_state, v_t, 'used'), v_t, 'shown');
    v_turns := v_turns || jsonb_build_array(autobattle_talent_turn(p_turn_no, p_side, p_hp, v_t, NULL));
    RETURN jsonb_build_object('blocked', true, 'state', v_state, 'turns', v_turns);
  END IF;

  RETURN jsonb_build_object('blocked', false, 'state', v_state, 'turns', v_turns);
END;
$$;

-- ── Effets ponctuels ─────────────────────────────────────────────────────────

-- Bonus appliqué à CHAQUE tick de brûlure/poison du combat, quel que soit le
-- camp qui le subit : les talents des DEUX camps sont additionnés (requirement).
CREATE OR REPLACE FUNCTION autobattle_talent_tick_bonus(p_a_talents jsonb, p_b_talents jsonb, p_status text)
RETURNS integer
LANGUAGE sql IMMUTABLE
AS $$
  SELECT COALESCE(SUM((t ->> 'amount')::integer), 0)::integer
  FROM jsonb_array_elements(COALESCE(p_a_talents, '[]'::jsonb) || COALESCE(p_b_talents, '[]'::jsonb)) t
  WHERE (t ->> 'kind') = (CASE WHEN p_status = 'poison' THEN 'poison_damage_boost' ELSE 'burn_damage_boost' END)
$$;

-- Bonus de dégâts quand le dé de la capacité tombe sur la valeur configurée.
-- Renvoie {"amount", "turns"} — un tour par talent déclenché (effet ponctuel,
-- réannoncé à chaque fois, contrairement aux passifs permanents).
CREATE OR REPLACE FUNCTION autobattle_talent_dice(
  p_talents jsonb, p_dice integer, p_side text, p_hp integer, p_turn_no integer)
RETURNS jsonb
LANGUAGE sql
AS $$
  SELECT jsonb_build_object(
    'amount', COALESCE((SELECT SUM((t ->> 'amount')::integer) FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t
                        WHERE (t ->> 'kind') = 'dice_bonus_damage' AND (t ->> 'dice_value')::integer = p_dice), 0)::integer,
    'turns', COALESCE((SELECT jsonb_agg(autobattle_talent_turn(p_turn_no, p_side, p_hp, t, NULL) ORDER BY (t ->> 'id')::bigint)
                       FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t
                       WHERE (t ->> 'kind') = 'dice_bonus_damage' AND (t ->> 'dice_value')::integer = p_dice), '[]'::jsonb)
  )
$$;

-- Présence d'un talent d'un kind donné, pour les talents SANS configuration
-- ('no_recoil', 'transform') : leur seule existence suffit à les activer.
CREATE OR REPLACE FUNCTION autobattle_talent_has_kind(p_talents jsonb, p_kind text)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t WHERE (t ->> 'kind') = p_kind)
$$;

-- Bouclier 'invulnerable_until_hit' : actif tant que son porteur n'a pas
-- lui-même infligé de dégâts (le talent est alors marqué 'used').
CREATE OR REPLACE FUNCTION autobattle_talent_shield_active(p_talents jsonb, p_state jsonb)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) t
    WHERE (t ->> 'kind') = 'invulnerable_until_hit' AND NOT autobattle_talent_has(p_state, t, 'used')
  )
$$;

CREATE OR REPLACE FUNCTION autobattle_talent_spend_shield(p_talents jsonb, p_state jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_state jsonb := COALESCE(p_state, autobattle_talent_state_init());
  v_t     jsonb;
BEGIN
  FOR v_t IN SELECT * FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) LOOP
    IF (v_t ->> 'kind') = 'invulnerable_until_hit' AND NOT autobattle_talent_has(v_state, v_t, 'used') THEN
      v_state := autobattle_talent_mark(v_state, v_t, 'used');
    END IF;
  END LOOP;
  RETURN v_state;
END;
$$;

GRANT EXECUTE ON FUNCTION autobattle_talents_for(text, boolean) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_state_init() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_has(jsonb, jsonb, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_mark(jsonb, jsonb, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_hits(jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_type_match(jsonb, text, boolean) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_status_match(jsonb, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_status_cond(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_value(jsonb, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_detail(jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_turn(integer, text, integer, jsonb, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_stat_active(jsonb, text, integer, integer, text, text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_stat_bonus(jsonb, jsonb, text, text, integer, integer, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_open(jsonb, text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_priority(jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_act(jsonb, jsonb, text, text, text, integer, integer, text, text, jsonb, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_defend(jsonb, jsonb, text, integer, text, integer, integer, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_survive(jsonb, jsonb, text, integer, integer, integer, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_status_guard(jsonb, jsonb, text, text, integer, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_tick_bonus(jsonb, jsonb, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_dice(jsonb, integer, text, integer, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_has_kind(jsonb, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_shield_active(jsonb, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_spend_shield(jsonb, jsonb) TO anon, authenticated;

-- ========================================================================
-- 5. Types partagés du moteur (DROP ... CASCADE : recrée aussi les fonctions plus bas)
-- ========================================================================

DROP TYPE IF EXISTS autobattle_combatant_state CASCADE;
CREATE TYPE autobattle_combatant_state AS (
  hp                     integer,
  max_hp                 integer,
  status                 text,
  -- Piles de modificateurs actifs (voir autobattle_mod_total) : cumulables,
  -- chaque entrée gardant sa propre échéance et son propre filtre de type.
  damage_mods            jsonb,
  precision_mods         jsonb,
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
  -- heal_dot_until_awake = le soin passif actif dure "jusqu'au réveil" au lieu
  --                        d'un nombre de tours (heal_dot_expires reste NULL).
  -- keep_going_*         = chaîne "Continue sur sa lancée" en cours : capacité
  --                        verrouillée, nombre de réutilisations forcées qu'il
  --                        reste, et numéro de l'utilisation en cours (1 = la
  --                        première, sans bonus).
  -- talent_state         = ids des talents d'espèce déjà déclenchés ce combat
  --                        (tableau jsonb) : déjà annoncés au joueur, et déjà
  --                        consommés pour les talents à usage unique. Voir
  --                        autobattle_talents et ses helpers plus haut.
  double_turn_pending    boolean,
  prevention_expires     integer,
  heal_dot_until_awake   boolean,
  keep_going_ability_nom text,
  keep_going_remaining   integer,
  keep_going_count       integer,
  talent_state           jsonb
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
  keep_going_until_fail           boolean,
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

-- ========================================================================
-- 6. Moteur de résolution partagé (Combat Manuel + PvP + essai PvP)
-- ========================================================================

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
  p_opponent_talents jsonb DEFAULT '[]'::jsonb
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
BEGIN
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
        v_player.hp, v_player.max_hp, v_opponent.status, v_player.status, p_opponent_talents, v_turn_no);
      v_player.talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
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

      IF (v_opponent.invulnerable OR autobattle_talent_shield_active(p_opponent_talents, v_opponent.talent_state)) AND (
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
        IF p_player_ability.keep_going_turns IS NOT NULL OR COALESCE(p_player_ability.keep_going_until_fail, false) THEN
          v_player.keep_going_ability_nom := NULL;
          v_player.keep_going_remaining := 0;
        END IF;
      ELSE
        -- Talents de précision compris dans le total (donc reportés tels quels
        -- dans 'precision_mod_amount', que le client réutilise pour afficher le
        -- détail du calcul en debug admin).
        v_precision_mod_total := autobattle_mod_total(v_player.precision_mods, v_round_no, p_player_ability.ability_type)
          + autobattle_talent_stat_bonus(p_player_talents, v_player.talent_state, 'precision', p_player_ability.ability_type, v_player.hp, v_player.max_hp, v_opponent.status, v_player.status);
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
            + autobattle_talent_stat_bonus(p_player_talents, v_player.talent_state, 'damage', p_player_ability.ability_type, v_player.hp, v_player.max_hp, v_opponent.status, v_player.status);
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
              v_hit_damage := GREATEST(0, floor(v_opponent.hp * p_player_ability.percent_hp_damage_percent / 100.0)::integer);
            END IF;

            v_bonus_condition_met := p_player_ability.bonus_condition = 'took_damage_last_turn' AND v_player.took_damage
              OR p_player_ability.bonus_condition = 'first_use' AND NOT v_player.used_ability
              OR p_player_ability.bonus_condition = 'dice_equals' AND v_hit_dice = p_player_ability.bonus_dice_value
              OR p_player_ability.bonus_condition = 'has_status' AND v_opponent.status IS NOT NULL AND (p_player_ability.bonus_status_filter IS NULL OR v_opponent.status = p_player_ability.bonus_status_filter)
              OR p_player_ability.bonus_condition = 'self_has_status' AND v_player.status IS NOT NULL AND (p_player_ability.bonus_status_filter IS NULL OR v_player.status = p_player_ability.bonus_status_filter);
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
              v_player.hp, v_player.max_hp, v_opponent.status, v_player.status, p_opponent_talents, v_turn_no);
            v_player.talent_state := v_talent_res -> 'state';
            v_turns := v_turns || (v_talent_res -> 'turns');
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
        v_opponent.hp, v_opponent.max_hp, v_player.status, v_opponent.status, p_player_talents, v_turn_no);
      v_opponent.talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
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

      IF (v_player.invulnerable OR autobattle_talent_shield_active(p_player_talents, v_player.talent_state)) AND (
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
        IF p_opponent_ability.keep_going_turns IS NOT NULL OR COALESCE(p_opponent_ability.keep_going_until_fail, false) THEN
          v_opponent.keep_going_ability_nom := NULL;
          v_opponent.keep_going_remaining := 0;
        END IF;
      ELSE
        v_precision_mod_total := autobattle_mod_total(v_opponent.precision_mods, v_round_no, p_opponent_ability.ability_type)
          + autobattle_talent_stat_bonus(p_opponent_talents, v_opponent.talent_state, 'precision', p_opponent_ability.ability_type, v_opponent.hp, v_opponent.max_hp, v_player.status, v_opponent.status);
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
            + autobattle_talent_stat_bonus(p_opponent_talents, v_opponent.talent_state, 'damage', p_opponent_ability.ability_type, v_opponent.hp, v_opponent.max_hp, v_player.status, v_opponent.status);
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
              v_hit_damage := GREATEST(0, floor(v_player.hp * p_opponent_ability.percent_hp_damage_percent / 100.0)::integer);
            END IF;

            v_bonus_condition_met := p_opponent_ability.bonus_condition = 'took_damage_last_turn' AND v_opponent.took_damage
              OR p_opponent_ability.bonus_condition = 'first_use' AND NOT v_opponent.used_ability
              OR p_opponent_ability.bonus_condition = 'dice_equals' AND v_hit_dice = p_opponent_ability.bonus_dice_value
              OR p_opponent_ability.bonus_condition = 'has_status' AND v_player.status IS NOT NULL AND (p_opponent_ability.bonus_status_filter IS NULL OR v_player.status = p_opponent_ability.bonus_status_filter)
              OR p_opponent_ability.bonus_condition = 'self_has_status' AND v_opponent.status IS NOT NULL AND (p_opponent_ability.bonus_status_filter IS NULL OR v_opponent.status = p_opponent_ability.bonus_status_filter);
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
              v_opponent.hp, v_opponent.max_hp, v_player.status, v_opponent.status, p_player_talents, v_turn_no);
            v_opponent.talent_state := v_talent_res -> 'state';
            v_turns := v_turns || (v_talent_res -> 'turns');
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
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION autobattle_resolve_round_core(integer, integer, text, autobattle_combatant_state, autobattle_combatant_state, autobattle_combatant_ability, autobattle_combatant_ability, boolean, jsonb, jsonb) TO anon, authenticated;

-- ========================================================================
-- 7. Combat Auto (boucle complète, moteur propre à ce mode)
-- ========================================================================

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
  v_talents_enabled     boolean;
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
  SELECT talents_enabled INTO v_talents_enabled FROM autobattle_config WHERE id = 1;
  v_talents_enabled := COALESCE(v_talents_enabled, true);
  v_player_talents := autobattle_talents_for(v_pp.pokemon_nom, v_talents_enabled);
  v_opponent_talents := autobattle_talents_for(v_level.opponent_pokemon_nom, v_talents_enabled);

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
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_player_heal_type, v_player_heal_amount, v_player_heal_percent, v_player_turn_effect, v_player_repeat_max, v_player_status_reversed,
         v_player_recoil_type, v_player_recoil_min, v_player_recoil_max, v_player_recoil_percent, v_player_invuln_grant,
         v_player_bonus_type, v_player_bonus_multiplier, v_player_bonus_flat, v_player_bonus_min, v_player_bonus_max,
         v_player_bonus_condition, v_player_bonus_dice_value, v_player_bonus_status_filter,
         v_player_stat_mod_target, v_player_stat_mod_stat, v_player_stat_mod_value_type, v_player_stat_mod_flat, v_player_stat_mod_min, v_player_stat_mod_max, v_player_stat_mod_percent,
         v_player_stat_mod_duration_type, v_player_stat_mod_duration_turns, v_player_stat_mod_max_uses,
         v_player_heal_dot_config_amount, v_player_heal_dot_config_turns, v_player_heal_dot_config_type, v_player_heal_dot_config_percent, v_player_cancel_heal_duration, v_player_percent_hp_damage_percent,
         v_player_stat_mod_type_filter, v_player_prevention_duration,
         v_player_keep_going_turns, v_player_keep_going_until_fail, v_player_keep_going_bonus_type, v_player_keep_going_bonus_flat, v_player_keep_going_bonus_percent,
         v_player_heal_dot_config_until_awake, v_player_ignore_status_block
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_ability_nom;
  v_player_status_reversed := COALESCE(v_player_status_reversed, false);
  v_player_invuln_grant := COALESCE(v_player_invuln_grant, false);
  v_player_heal_dot_config_until_awake := COALESCE(v_player_heal_dot_config_until_awake, false);
  v_player_keep_going_until_fail := COALESCE(v_player_keep_going_until_fail, false);

  SELECT heal_type, heal_amount, heal_percent, turn_effect, repeat_max_iterations, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_opponent_heal_type, v_opponent_heal_amount, v_opponent_heal_percent, v_opponent_turn_effect, v_opponent_repeat_max, v_opponent_status_reversed,
         v_opponent_recoil_type, v_opponent_recoil_min, v_opponent_recoil_max, v_opponent_recoil_percent, v_opponent_invuln_grant,
         v_opponent_bonus_type, v_opponent_bonus_multiplier, v_opponent_bonus_flat, v_opponent_bonus_min, v_opponent_bonus_max,
         v_opponent_bonus_condition, v_opponent_bonus_dice_value, v_opponent_bonus_status_filter,
         v_opponent_stat_mod_target, v_opponent_stat_mod_stat, v_opponent_stat_mod_value_type, v_opponent_stat_mod_flat, v_opponent_stat_mod_min, v_opponent_stat_mod_max, v_opponent_stat_mod_percent,
         v_opponent_stat_mod_duration_type, v_opponent_stat_mod_duration_turns, v_opponent_stat_mod_max_uses,
         v_opponent_heal_dot_config_amount, v_opponent_heal_dot_config_turns, v_opponent_heal_dot_config_type, v_opponent_heal_dot_config_percent, v_opponent_cancel_heal_duration, v_opponent_percent_hp_damage_percent,
         v_opponent_stat_mod_type_filter, v_opponent_prevention_duration,
         v_opponent_keep_going_turns, v_opponent_keep_going_until_fail, v_opponent_keep_going_bonus_type, v_opponent_keep_going_bonus_flat, v_opponent_keep_going_bonus_percent,
         v_opponent_heal_dot_config_until_awake, v_opponent_ignore_status_block
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_opponent_ability_nom;
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
  -- jeu (le premier à agir applique son statut le premier).
  FOREACH v_talent_side IN ARRAY (CASE WHEN v_coin_player_first THEN ARRAY['player', 'opponent'] ELSE ARRAY['opponent', 'player'] END) LOOP
    IF v_talent_side = 'player' THEN
      v_talent_res := autobattle_talent_act(v_player_talents, v_player_talent_state, 'player', 'battle_start', v_ability.type,
        v_player_hp, v_player_max_hp, v_opponent_status, v_player_status, v_opponent_talents, 0);
      v_player_talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
      IF (v_talent_res ->> 'inflict_status') IS NOT NULL THEN
        v_opponent_status := v_talent_res ->> 'inflict_status';
      END IF;
    ELSE
      v_talent_res := autobattle_talent_act(v_opponent_talents, v_opponent_talent_state, 'opponent', 'battle_start', v_opponent_ability.type,
        v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_player_talents, 0);
      v_opponent_talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
      IF (v_talent_res ->> 'inflict_status') IS NOT NULL THEN
        v_player_status := v_talent_res ->> 'inflict_status';
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
        v_player_hp, v_player_max_hp, v_opponent_status, v_player_status, v_opponent_talents, v_turn_no);
      v_player_talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
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
      IF (v_opponent_invulnerable OR autobattle_talent_shield_active(v_opponent_talents, v_opponent_talent_state)) AND (
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
        IF v_player_keep_going_turns IS NOT NULL OR v_player_keep_going_until_fail THEN
          v_player_keep_going_remaining := 0;
          v_player_keep_going_count := 0;
        END IF;
      ELSE
        v_precision_mod_total := autobattle_mod_total(v_player_precision_mods, v_round_no, v_ability.type)
          + autobattle_talent_stat_bonus(v_player_talents, v_player_talent_state, 'precision', v_ability.type, v_player_hp, v_player_max_hp, v_opponent_status, v_player_status);
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
            + autobattle_talent_stat_bonus(v_player_talents, v_player_talent_state, 'damage', v_ability.type, v_player_hp, v_player_max_hp, v_opponent_status, v_player_status);
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
              v_hit_damage := GREATEST(0, floor(v_opponent_hp * v_player_percent_hp_damage_percent / 100.0)::integer);
            END IF;

            -- Dégâts additionnels conditionnels (voir bonus_damage_* et les
            -- conditions possibles) — appliqués après le dé, avant le
            -- contre-coup. 'has_status' regarde le statut de la CIBLE,
            -- 'self_has_status' celui de l'utilisateur de la capacité.
            v_bonus_condition_met := v_player_bonus_condition = 'took_damage_last_turn' AND v_player_took_damage
              OR v_player_bonus_condition = 'first_use' AND NOT v_player_used_ability
              OR v_player_bonus_condition = 'dice_equals' AND v_hit_dice = v_player_bonus_dice_value
              OR v_player_bonus_condition = 'has_status' AND v_opponent_status IS NOT NULL AND (v_player_bonus_status_filter IS NULL OR v_opponent_status = v_player_bonus_status_filter)
              OR v_player_bonus_condition = 'self_has_status' AND v_player_status IS NOT NULL AND (v_player_bonus_status_filter IS NULL OR v_player_status = v_player_bonus_status_filter);
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
              v_player_hp, v_player_max_hp, v_opponent_status, v_player_status, v_opponent_talents, v_turn_no);
            v_player_talent_state := v_talent_res -> 'state';
            v_turns := v_turns || (v_talent_res -> 'turns');
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
        v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_player_talents, v_turn_no);
      v_opponent_talent_state := v_talent_res -> 'state';
      v_turns := v_turns || (v_talent_res -> 'turns');
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
      IF (v_player_invulnerable OR autobattle_talent_shield_active(v_player_talents, v_player_talent_state)) AND (
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
        IF v_opponent_keep_going_turns IS NOT NULL OR v_opponent_keep_going_until_fail THEN
          v_opponent_keep_going_remaining := 0;
          v_opponent_keep_going_count := 0;
        END IF;
      ELSE
        v_precision_mod_total := autobattle_mod_total(v_opponent_precision_mods, v_round_no, v_opponent_ability.type)
          + autobattle_talent_stat_bonus(v_opponent_talents, v_opponent_talent_state, 'precision', v_opponent_ability.type, v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status);
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
            + autobattle_talent_stat_bonus(v_opponent_talents, v_opponent_talent_state, 'damage', v_opponent_ability.type, v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status);
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
              v_hit_damage := GREATEST(0, floor(v_player_hp * v_opponent_percent_hp_damage_percent / 100.0)::integer);
            END IF;

            v_bonus_condition_met := v_opponent_bonus_condition = 'took_damage_last_turn' AND v_opponent_took_damage
              OR v_opponent_bonus_condition = 'first_use' AND NOT v_opponent_used_ability
              OR v_opponent_bonus_condition = 'dice_equals' AND v_hit_dice = v_opponent_bonus_dice_value
              OR v_opponent_bonus_condition = 'has_status' AND v_player_status IS NOT NULL AND (v_opponent_bonus_status_filter IS NULL OR v_player_status = v_opponent_bonus_status_filter)
              OR v_opponent_bonus_condition = 'self_has_status' AND v_opponent_status IS NOT NULL AND (v_opponent_bonus_status_filter IS NULL OR v_opponent_status = v_opponent_bonus_status_filter);
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
              v_opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_player_talents, v_turn_no);
            v_opponent_talent_state := v_talent_res -> 'state';
            v_turns := v_turns || (v_talent_res -> 'turns');
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
GRANT EXECUTE ON FUNCTION autobattle_xp_bonus(text, integer, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_max_xp(text) TO anon, authenticated;

-- ========================================================================
-- 8. Combat Manuel (démarrage + un round par appel)
-- ========================================================================

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
  v_side                text;
  v_talents_enabled     boolean;
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
  -- Bascule globale des talents (voir autobattle_config.talents_enabled).
  SELECT talents_enabled INTO v_talents_enabled FROM autobattle_config WHERE id = 1;
  v_talents_enabled := COALESCE(v_talents_enabled, true);
  v_player_talents := autobattle_talents_for(v_pp.pokemon_nom, v_talents_enabled);
  v_opponent_talents := autobattle_talents_for(v_level.opponent_pokemon_nom, v_talents_enabled);

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
  FOREACH v_side IN ARRAY (CASE WHEN v_first_attacker = 'player' THEN ARRAY['player', 'opponent'] ELSE ARRAY['opponent', 'player'] END) LOOP
    IF v_side = 'player' THEN
      v_talent_res := autobattle_talent_act(v_player_talents, v_player_talent_state, 'player', 'battle_start', NULL,
        GREATEST(1, v_player_max_hp), GREATEST(1, v_player_max_hp), v_opponent_status, v_player_status, v_opponent_talents, 0);
      v_player_talent_state := v_talent_res -> 'state';
      v_start_turns := v_start_turns || (v_talent_res -> 'turns');
      v_opponent_status := COALESCE(v_talent_res ->> 'inflict_status', v_opponent_status);
    ELSE
      v_talent_res := autobattle_talent_act(v_opponent_talents, v_opponent_talent_state, 'opponent', 'battle_start', NULL,
        v_level.opponent_hp, v_level.opponent_hp, v_player_status, v_opponent_status, v_player_talents, 0);
      v_opponent_talent_state := v_talent_res -> 'state';
      v_start_turns := v_start_turns || (v_talent_res -> 'turns');
      v_player_status := COALESCE(v_talent_res ->> 'inflict_status', v_player_status);
    END IF;
  END LOOP;

  -- Le sprite copié par le talent 'transform' n'est PAS renvoyé ici : le client
  -- le dérive lui-même dès l'ouverture (il connaît déjà les talents et les deux
  -- espèces, voir ManualBattleScreen), ce qui évite d'attendre le 1er round.
  v_result := jsonb_build_object('status', 'ok', 'first_attacker', v_first_attacker, 'turns', v_start_turns);

  INSERT INTO autobattle_manual_battles (
    player_id, level_id, variant_id, player_pokemon_id, first_attacker, turn_no,
    player_hp, player_max_hp, opponent_hp, last_idempotency_key, last_result,
    turn_log, player_talent_state, opponent_talent_state, player_status, opponent_status
  ) VALUES (
    p_player_id, p_level_id, v_variant.id, p_player_pokemon_id, v_first_attacker, 0,
    GREATEST(1, v_player_max_hp), GREATEST(1, v_player_max_hp), v_level.opponent_hp, p_idempotency_key, v_result,
    v_start_turns, v_player_talent_state, v_opponent_talent_state, v_player_status, v_opponent_status
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION autobattle_start_manual_battle(bigint, bigint, bigint, uuid) TO anon, authenticated;

-- Résout UN SEUL tour de combat en mode Manuel (variant.game_mode =
-- 'manual', voir autobattle_manual_battles) : contrairement à
-- autobattle_resolve_battle (tout le combat d'un coup, une capacité fixe
-- pour tout le combat), le joueur choisit une capacité à chaque appel,
-- l'adversaire suit sa séquence configurée (autobattle_levels.opponent_
-- ability_nom/_2/_3/_4, en boucle) ou, s'il s'agit de Métamorph, pioche
-- uniformément parmi TOUTES les capacités apprises par le pokémon du joueur
-- (v_pp.moves) à chaque nouveau tour — voir requirement dédié. L'ordre de
-- résolution (qui joue en premier) est fixé une fois pour toutes au 1er tour
-- (tirage au sort), mais le joueur choisit TOUJOURS sa capacité avant de
-- voir le résultat, que ce soit lui ou l'adversaire qui résout en premier ce
-- tour-là (c'est le client — ManualBattleScreen — qui attend l'input avant
-- d'appeler cette fonction, pas cette fonction qui décide de l'ordre
-- d'input). Contrairement à une version antérieure, les effets de RYTHME
-- des tours (autobattle_ability_rules.turn_effect) sont PLEINEMENT actifs :
-- un appel résout la boucle exacte du mode Auto (autobattle_resolve_battle),
-- juste bornée à s'arrêter après EXACTEMENT 2 changements de camp (v_flips)
-- — c'est-à-dire un "tour complet" pour chaque camp, rafales/passes/
-- préparations internes à ce tour comprises — au lieu de tourner jusqu'à la
-- victoire/défaite ou 200 activations. 'prepare_release' : si un camp est en
-- cours de préparation, sa capacité RÉELLEMENT jouée ce tour reste celle
-- mémorisée (player_preparing_ability_nom/opponent_preparing_ability_nom),
-- pas nécessairement p_ability_nom (le joueur peut cliquer autre chose
-- entretemps, ce choix ne compte que pour le tour SUIVANT).
-- DROP nécessaire avant CREATE OR REPLACE : la signature perd le paramètre
-- p_is_new_battle (voir autobattle_start_manual_battle ci-dessus, qui porte
-- désormais cette responsabilité) — CREATE OR REPLACE ne permet jamais de
-- retirer un paramètre existant, seulement d'en ajouter avec valeur par
-- défaut. Couvre les deux signatures possibles selon l'état de la base.
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
  v_talents_enabled     boolean;
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
  v_player_keep_going_until_fail  boolean;
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
  v_opponent_keep_going_until_fail  boolean;
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
  -- movepool, jamais le talent adverse.
  SELECT talents_enabled INTO v_talents_enabled FROM autobattle_config WHERE id = 1;
  v_talents_enabled := COALESCE(v_talents_enabled, true);
  v_player_talents := autobattle_talents_for(v_pp.pokemon_nom, v_talents_enabled);
  v_opponent_talents := autobattle_talents_for(v_level.opponent_pokemon_nom, v_talents_enabled);

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
  -- talents_enabled a déjà été lu plus haut (le talent 'transform' devait être
  -- connu avant la copie de l'adversaire).
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
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_player_turn_effect, v_player_repeat_max, v_player_heal_type, v_player_heal_amount, v_player_heal_percent, v_player_status_reversed,
         v_player_recoil_type, v_player_recoil_min, v_player_recoil_max, v_player_recoil_percent, v_player_invuln_grant,
         v_player_bonus_type, v_player_bonus_multiplier, v_player_bonus_flat, v_player_bonus_min, v_player_bonus_max,
         v_player_bonus_condition, v_player_bonus_dice_value, v_player_bonus_status_filter,
         v_player_stat_mod_target, v_player_stat_mod_stat, v_player_stat_mod_value_type, v_player_stat_mod_flat, v_player_stat_mod_min, v_player_stat_mod_max, v_player_stat_mod_percent,
         v_player_stat_mod_duration_type, v_player_stat_mod_duration_turns, v_player_stat_mod_max_uses,
         v_player_heal_dot_config_amount, v_player_heal_dot_config_turns, v_player_heal_dot_config_type, v_player_heal_dot_config_percent, v_player_cancel_heal_duration, v_player_percent_hp_damage_percent,
         v_player_stat_mod_type_filter, v_player_prevention_duration,
         v_player_keep_going_turns, v_player_keep_going_until_fail, v_player_keep_going_bonus_type, v_player_keep_going_bonus_flat, v_player_keep_going_bonus_percent,
         v_player_heal_dot_config_until_awake, v_player_ignore_status_block
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_player_ability_nom;
  v_player_status_reversed := COALESCE(v_player_status_reversed, false);
  v_player_invuln_grant := COALESCE(v_player_invuln_grant, false);
  v_player_heal_dot_config_until_awake := COALESCE(v_player_heal_dot_config_until_awake, false);
  v_player_keep_going_until_fail := COALESCE(v_player_keep_going_until_fail, false);

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_opponent_turn_effect, v_opponent_repeat_max, v_opponent_heal_type, v_opponent_heal_amount, v_opponent_heal_percent, v_opponent_status_reversed,
         v_opponent_recoil_type, v_opponent_recoil_min, v_opponent_recoil_max, v_opponent_recoil_percent, v_opponent_invuln_grant,
         v_opponent_bonus_type, v_opponent_bonus_multiplier, v_opponent_bonus_flat, v_opponent_bonus_min, v_opponent_bonus_max,
         v_opponent_bonus_condition, v_opponent_bonus_dice_value, v_opponent_bonus_status_filter,
         v_opponent_stat_mod_target, v_opponent_stat_mod_stat, v_opponent_stat_mod_value_type, v_opponent_stat_mod_flat, v_opponent_stat_mod_min, v_opponent_stat_mod_max, v_opponent_stat_mod_percent,
         v_opponent_stat_mod_duration_type, v_opponent_stat_mod_duration_turns, v_opponent_stat_mod_max_uses,
         v_opponent_heal_dot_config_amount, v_opponent_heal_dot_config_turns, v_opponent_heal_dot_config_type, v_opponent_heal_dot_config_percent, v_opponent_cancel_heal_duration, v_opponent_percent_hp_damage_percent,
         v_opponent_stat_mod_type_filter, v_opponent_prevention_duration,
         v_opponent_keep_going_turns, v_opponent_keep_going_until_fail, v_opponent_keep_going_bonus_type, v_opponent_keep_going_bonus_flat, v_opponent_keep_going_bonus_percent,
         v_opponent_heal_dot_config_until_awake, v_opponent_ignore_status_block
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
  v_player_ability_cfg.keep_going_until_fail := v_player_keep_going_until_fail;
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
  v_opponent_ability_cfg.keep_going_until_fail := v_opponent_keep_going_until_fail;
  v_opponent_ability_cfg.keep_going_bonus_type := v_opponent_keep_going_bonus_type;
  v_opponent_ability_cfg.keep_going_bonus_flat := v_opponent_keep_going_bonus_flat;
  v_opponent_ability_cfg.keep_going_bonus_percent := v_opponent_keep_going_bonus_percent;
  v_opponent_ability_cfg.heal_dot_until_awake := v_opponent_heal_dot_config_until_awake;
  v_opponent_ability_cfg.ignore_status_block := v_opponent_ignore_status_block;

  v_round_result := autobattle_resolve_round_core(
    v_turn_no, v_round_no, v_first_attacker,
    v_player_state, v_opponent_state, v_player_ability_cfg, v_opponent_ability_cfg,
    v_precision_enabled, v_player_talents, v_opponent_talents
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
    'player_image_override', v_player_image_override
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

GRANT EXECUTE ON FUNCTION autobattle_resolve_manual_round(bigint, bigint, bigint, text, uuid) TO anon, authenticated;

-- ========================================================================
-- 9. PvP (défi posté)
-- ========================================================================

CREATE OR REPLACE FUNCTION pvp_start_battle(
  p_attacker_player_id bigint,
  p_challenge_id bigint,
  p_attacker_player_pokemon_id bigint,
  p_idempotency_key uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_challenge         record;
  v_pp                record;
  v_species           record;
  v_row               pvp_battles%ROWTYPE;
  v_attacker_max_hp   integer;
  v_first_attacker    text;
  v_result            jsonb;
  -- Talents actifs dès le début du combat — voir autobattle_start_manual_battle.
  v_talent_start        jsonb;
  v_talent_res          jsonb;
  v_start_turns         jsonb := '[]'::jsonb;
  v_a_talents           jsonb;
  v_d_talents           jsonb;
  v_a_talent_state      jsonb;
  v_d_talent_state      jsonb;
  v_a_status            text;
  v_d_status            text;
  v_side                text;
  v_talents_enabled     boolean;
BEGIN
  SELECT * INTO v_challenge FROM pvp_challenges WHERE id = p_challenge_id;
  IF v_challenge IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;
  IF v_challenge.defender_player_id = p_attacker_player_id THEN
    RETURN jsonb_build_object('status', 'own_challenge');
  END IF;

  -- Affronter le Champion (voir pvp_promote_to_champion) exige d'avoir déjà
  -- posé son propre défi régulier (pas encore Champion soi-même) : c'est CE
  -- pokémon posé qui devient le nouveau Champion en cas de victoire, voir
  -- plus bas dans pvp_resolve_round — message affiché côté client sur la
  -- bannière "Champion Actuel" elle-même (voir PvpChampionBanner).
  IF v_challenge.is_champion AND NOT EXISTS (
    SELECT 1 FROM pvp_challenges
    WHERE defender_player_id = p_attacker_player_id AND active = true AND is_champion = false
  ) THEN
    RETURN jsonb_build_object('status', 'champion_requires_own_challenge');
  END IF;

  SELECT * INTO v_pp FROM player_pokemon WHERE id = p_attacker_player_pokemon_id AND player_id = p_attacker_player_id;
  IF v_pp IS NULL OR v_pp.in_daycare THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;

  SELECT * INTO v_species FROM pokemon WHERE nom = v_pp.pokemon_nom;
  IF v_species IS NULL THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;

  SELECT * INTO v_row FROM pvp_battles
    WHERE attacker_player_id = p_attacker_player_id AND challenge_id = p_challenge_id FOR UPDATE;

  -- Rejeu idempotent : même demande de démarrage redemandée (retry réseau) —
  -- renvoyée telle quelle même si le défi a été retiré entretemps (le combat
  -- a déjà réellement démarré côté serveur la 1ère fois).
  IF v_row.id IS NOT NULL AND v_row.last_idempotency_key = p_idempotency_key THEN
    RETURN v_row.last_result;
  END IF;

  IF NOT v_challenge.active THEN
    RETURN jsonb_build_object('status', 'challenge_inactive');
  END IF;

  IF v_row.id IS NOT NULL THEN
    DELETE FROM pvp_battles WHERE id = v_row.id;
  END IF;

  v_attacker_max_hp := GREATEST(1, COALESCE(v_species.pv_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'PV'));
  v_first_attacker := CASE WHEN random() < 0.5 THEN 'attacker' ELSE 'defender' END;
  -- Le JSON renvoyé au client parle TOUJOURS le vocabulaire 'player'/'opponent'
  -- (comme pvp_resolve_round plus bas et autobattle_start_manual_battle), alors
  -- que la COLONNE pvp_battles.first_attacker garde 'attacker'/'defender' —
  -- renvoyer v_first_attacker brut faisait échouer le test `=== 'player'` côté
  -- client (pile ou face + badge "(1er)"/"(2ème)" de ManualBattleScreen
  -- toujours affichés comme si l'adversaire commençait).
  -- Bascule globale des talents (voir pvp_config.talents_enabled).
  SELECT talents_enabled INTO v_talents_enabled FROM pvp_config WHERE id = 1;
  v_talents_enabled := COALESCE(v_talents_enabled, true);
  v_a_talents := autobattle_talents_for(v_pp.pokemon_nom, v_talents_enabled);
  v_d_talents := autobattle_talents_for(v_challenge.pokemon_nom, v_talents_enabled);
  -- Talent 'priority' : remplace le tirage au sort (voir autobattle_resolve_battle).
  IF autobattle_talent_priority(v_a_talents) <> autobattle_talent_priority(v_d_talents) THEN
    v_first_attacker := CASE WHEN autobattle_talent_priority(v_a_talents) > autobattle_talent_priority(v_d_talents)
      THEN 'attacker' ELSE 'defender' END;
  END IF;

  v_talent_start := autobattle_talent_open(v_a_talents, 'player', v_attacker_max_hp);
  v_start_turns := v_start_turns || (v_talent_start -> 'turns');
  v_a_talent_state := v_talent_start -> 'state';
  v_talent_start := autobattle_talent_open(v_d_talents, 'opponent', v_challenge.max_hp);
  v_start_turns := v_start_turns || (v_talent_start -> 'turns');
  v_d_talent_state := v_talent_start -> 'state';

  FOREACH v_side IN ARRAY (CASE WHEN v_first_attacker = 'attacker' THEN ARRAY['player', 'opponent'] ELSE ARRAY['opponent', 'player'] END) LOOP
    IF v_side = 'player' THEN
      v_talent_res := autobattle_talent_act(v_a_talents, v_a_talent_state, 'player', 'battle_start', NULL,
        v_attacker_max_hp, v_attacker_max_hp, v_d_status, v_a_status, v_d_talents, 0);
      v_a_talent_state := v_talent_res -> 'state';
      v_start_turns := v_start_turns || (v_talent_res -> 'turns');
      v_d_status := COALESCE(v_talent_res ->> 'inflict_status', v_d_status);
    ELSE
      v_talent_res := autobattle_talent_act(v_d_talents, v_d_talent_state, 'opponent', 'battle_start', NULL,
        v_challenge.max_hp, v_challenge.max_hp, v_a_status, v_d_status, v_a_talents, 0);
      v_d_talent_state := v_talent_res -> 'state';
      v_start_turns := v_start_turns || (v_talent_res -> 'turns');
      v_a_status := COALESCE(v_talent_res ->> 'inflict_status', v_a_status);
    END IF;
  END LOOP;

  v_result := jsonb_build_object(
    'status', 'ok',
    'first_attacker', CASE WHEN v_first_attacker = 'attacker' THEN 'player' ELSE 'opponent' END,
    'turns', v_start_turns
  );

  INSERT INTO pvp_battles (
    challenge_id, attacker_player_id, attacker_player_pokemon_id, first_attacker,
    attacker_hp, attacker_max_hp, defender_hp, defender_max_hp,
    started_at, last_idempotency_key, last_result,
    turn_log, attacker_talent_state, defender_talent_state, attacker_status, defender_status
  ) VALUES (
    p_challenge_id, p_attacker_player_id, p_attacker_player_pokemon_id, v_first_attacker,
    v_attacker_max_hp, v_attacker_max_hp, v_challenge.max_hp, v_challenge.max_hp,
    now(), p_idempotency_key, v_result,
    v_start_turns, v_a_talent_state, v_d_talent_state, v_a_status, v_d_status
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION pvp_start_battle(bigint, bigint, bigint, uuid) TO anon, authenticated;
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

  SELECT precision_enabled, talents_enabled INTO v_precision_enabled, v_talents_enabled FROM pvp_config WHERE id = 1;
  v_precision_enabled := COALESCE(v_precision_enabled, true);
  v_talents_enabled := COALESCE(v_talents_enabled, true);

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

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_a_ability_cfg.turn_effect, v_a_ability_cfg.repeat_max, v_a_ability_cfg.heal_type, v_a_ability_cfg.heal_amount, v_a_ability_cfg.heal_percent, v_a_ability_cfg.status_reversed,
         v_a_ability_cfg.recoil_type, v_a_ability_cfg.recoil_min, v_a_ability_cfg.recoil_max, v_a_ability_cfg.recoil_percent, v_a_ability_cfg.invuln_grant,
         v_a_ability_cfg.bonus_type, v_a_ability_cfg.bonus_multiplier, v_a_ability_cfg.bonus_flat, v_a_ability_cfg.bonus_min, v_a_ability_cfg.bonus_max,
         v_a_ability_cfg.bonus_condition, v_a_ability_cfg.bonus_dice_value, v_a_ability_cfg.bonus_status_filter,
         v_a_ability_cfg.stat_mod_target, v_a_ability_cfg.stat_mod_stat, v_a_ability_cfg.stat_mod_value_type, v_a_ability_cfg.stat_mod_flat, v_a_ability_cfg.stat_mod_min, v_a_ability_cfg.stat_mod_max, v_a_ability_cfg.stat_mod_percent,
         v_a_ability_cfg.stat_mod_duration_type, v_a_ability_cfg.stat_mod_duration_turns, v_a_ability_cfg.stat_mod_max_uses,
         v_a_ability_cfg.heal_dot_config_amount, v_a_ability_cfg.heal_dot_config_turns, v_a_ability_cfg.heal_dot_config_type, v_a_ability_cfg.heal_dot_config_percent, v_a_ability_cfg.cancel_heal_duration, v_a_ability_cfg.percent_hp_damage_percent,
         v_a_ability_cfg.stat_mod_type_filter, v_a_ability_cfg.prevention_duration,
         v_a_ability_cfg.keep_going_turns, v_a_ability_cfg.keep_going_until_fail, v_a_ability_cfg.keep_going_bonus_type, v_a_ability_cfg.keep_going_bonus_flat, v_a_ability_cfg.keep_going_bonus_percent,
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
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_d_ability_cfg.turn_effect, v_d_ability_cfg.repeat_max, v_d_ability_cfg.heal_type, v_d_ability_cfg.heal_amount, v_d_ability_cfg.heal_percent, v_d_ability_cfg.status_reversed,
         v_d_ability_cfg.recoil_type, v_d_ability_cfg.recoil_min, v_d_ability_cfg.recoil_max, v_d_ability_cfg.recoil_percent, v_d_ability_cfg.invuln_grant,
         v_d_ability_cfg.bonus_type, v_d_ability_cfg.bonus_multiplier, v_d_ability_cfg.bonus_flat, v_d_ability_cfg.bonus_min, v_d_ability_cfg.bonus_max,
         v_d_ability_cfg.bonus_condition, v_d_ability_cfg.bonus_dice_value, v_d_ability_cfg.bonus_status_filter,
         v_d_ability_cfg.stat_mod_target, v_d_ability_cfg.stat_mod_stat, v_d_ability_cfg.stat_mod_value_type, v_d_ability_cfg.stat_mod_flat, v_d_ability_cfg.stat_mod_min, v_d_ability_cfg.stat_mod_max, v_d_ability_cfg.stat_mod_percent,
         v_d_ability_cfg.stat_mod_duration_type, v_d_ability_cfg.stat_mod_duration_turns, v_d_ability_cfg.stat_mod_max_uses,
         v_d_ability_cfg.heal_dot_config_amount, v_d_ability_cfg.heal_dot_config_turns, v_d_ability_cfg.heal_dot_config_type, v_d_ability_cfg.heal_dot_config_percent, v_d_ability_cfg.cancel_heal_duration, v_d_ability_cfg.percent_hp_damage_percent,
         v_d_ability_cfg.stat_mod_type_filter, v_d_ability_cfg.prevention_duration,
         v_d_ability_cfg.keep_going_turns, v_d_ability_cfg.keep_going_until_fail, v_d_ability_cfg.keep_going_bonus_type, v_d_ability_cfg.keep_going_bonus_flat, v_d_ability_cfg.keep_going_bonus_percent,
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
    v_a_state, v_d_state, v_a_ability_cfg, v_d_ability_cfg, v_precision_enabled,
    -- Talents d'espèce : celle du pokémon de l'attaquant, et celle FIGÉE sur le
    -- défi pour le défenseur (pvp_challenges.pokemon_nom, pas une ligne
    -- player_pokemon vivante).
    autobattle_talents_for(v_pp.pokemon_nom, v_talents_enabled), autobattle_talents_for(v_challenge.pokemon_nom, v_talents_enabled)
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
      ELSE NULL END
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

GRANT EXECUTE ON FUNCTION pvp_resolve_round(bigint, bigint, bigint, text, uuid) TO anon, authenticated;

-- ========================================================================
-- 10. PvP (combat d'essai admin)
-- ========================================================================

CREATE OR REPLACE FUNCTION pvp_trial_start(
  p_player_id bigint,
  p_player_pokemon_id bigint,
  p_ability_noms text[],
  p_player_starts boolean,
  p_idempotency_key uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_config          record;
  v_pp              record;
  v_species         record;
  v_dummy_species   record;
  v_nom             text;
  v_attacker_max_hp integer;
  v_dummy_hp        integer;
  v_first_attacker  text;
  v_result          jsonb;
  -- Talents actifs dès le début du combat — voir autobattle_start_manual_battle.
  -- Pas de talent 'priority' ici : l'ordre vient d'un choix EXPLICITE de
  -- l'admin (p_player_starts), c'est tout l'intérêt de l'écran d'essai.
  v_talent_start    jsonb;
  v_talent_res      jsonb;
  v_start_turns     jsonb := '[]'::jsonb;
  v_a_talents       jsonb;
  v_d_talents       jsonb;
  v_a_talent_state  jsonb;
  v_d_talent_state  jsonb;
  v_a_status        text;
  v_d_status        text;
  v_side            text;
BEGIN
  SELECT * INTO v_config FROM pvp_config WHERE id = 1;

  IF p_ability_noms IS NULL OR array_length(p_ability_noms, 1) IS NULL
     OR array_length(p_ability_noms, 1) < 1 OR array_length(p_ability_noms, 1) > COALESCE(v_config.loadout_max, 4) THEN
    RETURN jsonb_build_object('status', 'invalid_abilities');
  END IF;

  SELECT * INTO v_pp FROM player_pokemon WHERE id = p_player_pokemon_id AND player_id = p_player_id;
  IF v_pp IS NULL OR v_pp.in_daycare THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;

  FOREACH v_nom IN ARRAY p_ability_noms LOOP
    IF NOT (v_nom = ANY(v_pp.moves)) OR NOT EXISTS (SELECT 1 FROM attacks WHERE nom = v_nom)
       OR EXISTS (SELECT 1 FROM autobattle_banned_attacks WHERE attack_nom = v_nom) THEN
      RETURN jsonb_build_object('status', 'invalid_abilities');
    END IF;
  END LOOP;

  SELECT * INTO v_species FROM pokemon WHERE nom = v_pp.pokemon_nom;
  IF v_species IS NULL THEN
    RETURN jsonb_build_object('status', 'ineligible_pokemon');
  END IF;

  IF v_config.trial_pokemon_nom IS NULL OR v_config.trial_pokemon_nom = ''
     OR v_config.trial_ability_nom IS NULL OR v_config.trial_ability_nom = '' THEN
    RETURN jsonb_build_object('status', 'trial_not_configured');
  END IF;
  SELECT * INTO v_dummy_species FROM pokemon WHERE nom = v_config.trial_pokemon_nom;
  IF v_dummy_species IS NULL OR NOT EXISTS (SELECT 1 FROM attacks WHERE nom = v_config.trial_ability_nom) THEN
    RETURN jsonb_build_object('status', 'trial_not_configured');
  END IF;

  v_attacker_max_hp := GREATEST(1, COALESCE(v_species.pv_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'PV'));
  v_dummy_hp := GREATEST(1, COALESCE(v_config.trial_hp, 80));
  v_first_attacker := CASE WHEN p_player_starts THEN 'attacker' ELSE 'defender' END;
  -- Même conversion que pvp_start_battle : la colonne garde 'attacker'/
  -- 'defender', le JSON client parle 'player'/'opponent'.
  -- Bascule globale des talents (voir pvp_config.talents_enabled) : v_config est
  -- déjà chargé ici, pas besoin d'un SELECT dédié.
  v_a_talents := autobattle_talents_for(v_pp.pokemon_nom, COALESCE(v_config.talents_enabled, true));
  v_d_talents := autobattle_talents_for(v_config.trial_pokemon_nom, COALESCE(v_config.talents_enabled, true));

  v_talent_start := autobattle_talent_open(v_a_talents, 'player', v_attacker_max_hp);
  v_start_turns := v_start_turns || (v_talent_start -> 'turns');
  v_a_talent_state := v_talent_start -> 'state';
  v_talent_start := autobattle_talent_open(v_d_talents, 'opponent', v_dummy_hp);
  v_start_turns := v_start_turns || (v_talent_start -> 'turns');
  v_d_talent_state := v_talent_start -> 'state';

  FOREACH v_side IN ARRAY (CASE WHEN v_first_attacker = 'attacker' THEN ARRAY['player', 'opponent'] ELSE ARRAY['opponent', 'player'] END) LOOP
    IF v_side = 'player' THEN
      v_talent_res := autobattle_talent_act(v_a_talents, v_a_talent_state, 'player', 'battle_start', NULL,
        v_attacker_max_hp, v_attacker_max_hp, v_d_status, v_a_status, v_d_talents, 0);
      v_a_talent_state := v_talent_res -> 'state';
      v_start_turns := v_start_turns || (v_talent_res -> 'turns');
      v_d_status := COALESCE(v_talent_res ->> 'inflict_status', v_d_status);
    ELSE
      v_talent_res := autobattle_talent_act(v_d_talents, v_d_talent_state, 'opponent', 'battle_start', NULL,
        v_dummy_hp, v_dummy_hp, v_a_status, v_d_status, v_a_talents, 0);
      v_d_talent_state := v_talent_res -> 'state';
      v_start_turns := v_start_turns || (v_talent_res -> 'turns');
      v_a_status := COALESCE(v_talent_res ->> 'inflict_status', v_a_status);
    END IF;
  END LOOP;

  v_result := jsonb_build_object(
    'status', 'ok',
    'first_attacker', CASE WHEN v_first_attacker = 'attacker' THEN 'player' ELSE 'opponent' END,
    'turns', v_start_turns
  );

  -- Toujours écrasé plutôt que rejeté : contrairement à un vrai défi, il n'y
  -- a rien à préserver d'une tentative d'essai précédente (pas de ticket,
  -- pas d'historique) — voir aussi "quittable à tout moment" (pas de statut
  -- 'déjà en cours' à gérer côté client).
  DELETE FROM pvp_trial_battles WHERE player_id = p_player_id;

  INSERT INTO pvp_trial_battles (
    player_id, player_pokemon_id, attacker_ability_noms,
    dummy_pokemon_nom, dummy_max_hp, dummy_ability_nom,
    first_attacker, attacker_hp, attacker_max_hp, defender_hp, defender_max_hp,
    started_at, last_idempotency_key, last_result,
    turn_log, attacker_talent_state, defender_talent_state, attacker_status, defender_status
  ) VALUES (
    p_player_id, p_player_pokemon_id, p_ability_noms,
    v_config.trial_pokemon_nom, v_dummy_hp, v_config.trial_ability_nom,
    v_first_attacker, v_attacker_max_hp, v_attacker_max_hp, v_dummy_hp, v_dummy_hp,
    now(), p_idempotency_key, v_result,
    v_start_turns, v_a_talent_state, v_d_talent_state, v_a_status, v_d_status
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION pvp_trial_start(bigint, bigint, text[], boolean, uuid) TO anon, authenticated;
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

  SELECT precision_enabled, talents_enabled INTO v_precision_enabled, v_talents_enabled FROM pvp_config WHERE id = 1;
  v_precision_enabled := COALESCE(v_precision_enabled, true);
  v_talents_enabled := COALESCE(v_talents_enabled, true);

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

  SELECT turn_effect, repeat_max_iterations, heal_type, heal_amount, heal_percent, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, heal_dot_type, heal_dot_percent, cancel_heal_duration_turns, percent_hp_damage_percent,
         stat_mod_type_filter, prevention_duration_turns,
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_a_ability_cfg.turn_effect, v_a_ability_cfg.repeat_max, v_a_ability_cfg.heal_type, v_a_ability_cfg.heal_amount, v_a_ability_cfg.heal_percent, v_a_ability_cfg.status_reversed,
         v_a_ability_cfg.recoil_type, v_a_ability_cfg.recoil_min, v_a_ability_cfg.recoil_max, v_a_ability_cfg.recoil_percent, v_a_ability_cfg.invuln_grant,
         v_a_ability_cfg.bonus_type, v_a_ability_cfg.bonus_multiplier, v_a_ability_cfg.bonus_flat, v_a_ability_cfg.bonus_min, v_a_ability_cfg.bonus_max,
         v_a_ability_cfg.bonus_condition, v_a_ability_cfg.bonus_dice_value, v_a_ability_cfg.bonus_status_filter,
         v_a_ability_cfg.stat_mod_target, v_a_ability_cfg.stat_mod_stat, v_a_ability_cfg.stat_mod_value_type, v_a_ability_cfg.stat_mod_flat, v_a_ability_cfg.stat_mod_min, v_a_ability_cfg.stat_mod_max, v_a_ability_cfg.stat_mod_percent,
         v_a_ability_cfg.stat_mod_duration_type, v_a_ability_cfg.stat_mod_duration_turns, v_a_ability_cfg.stat_mod_max_uses,
         v_a_ability_cfg.heal_dot_config_amount, v_a_ability_cfg.heal_dot_config_turns, v_a_ability_cfg.heal_dot_config_type, v_a_ability_cfg.heal_dot_config_percent, v_a_ability_cfg.cancel_heal_duration, v_a_ability_cfg.percent_hp_damage_percent,
         v_a_ability_cfg.stat_mod_type_filter, v_a_ability_cfg.prevention_duration,
         v_a_ability_cfg.keep_going_turns, v_a_ability_cfg.keep_going_until_fail, v_a_ability_cfg.keep_going_bonus_type, v_a_ability_cfg.keep_going_bonus_flat, v_a_ability_cfg.keep_going_bonus_percent,
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
         keep_going_turns, keep_going_until_fail, keep_going_bonus_type, keep_going_bonus_flat, keep_going_bonus_percent,
         heal_dot_until_awake, ignore_status_block
    INTO v_d_ability_cfg.turn_effect, v_d_ability_cfg.repeat_max, v_d_ability_cfg.heal_type, v_d_ability_cfg.heal_amount, v_d_ability_cfg.heal_percent, v_d_ability_cfg.status_reversed,
         v_d_ability_cfg.recoil_type, v_d_ability_cfg.recoil_min, v_d_ability_cfg.recoil_max, v_d_ability_cfg.recoil_percent, v_d_ability_cfg.invuln_grant,
         v_d_ability_cfg.bonus_type, v_d_ability_cfg.bonus_multiplier, v_d_ability_cfg.bonus_flat, v_d_ability_cfg.bonus_min, v_d_ability_cfg.bonus_max,
         v_d_ability_cfg.bonus_condition, v_d_ability_cfg.bonus_dice_value, v_d_ability_cfg.bonus_status_filter,
         v_d_ability_cfg.stat_mod_target, v_d_ability_cfg.stat_mod_stat, v_d_ability_cfg.stat_mod_value_type, v_d_ability_cfg.stat_mod_flat, v_d_ability_cfg.stat_mod_min, v_d_ability_cfg.stat_mod_max, v_d_ability_cfg.stat_mod_percent,
         v_d_ability_cfg.stat_mod_duration_type, v_d_ability_cfg.stat_mod_duration_turns, v_d_ability_cfg.stat_mod_max_uses,
         v_d_ability_cfg.heal_dot_config_amount, v_d_ability_cfg.heal_dot_config_turns, v_d_ability_cfg.heal_dot_config_type, v_d_ability_cfg.heal_dot_config_percent, v_d_ability_cfg.cancel_heal_duration, v_d_ability_cfg.percent_hp_damage_percent,
         v_d_ability_cfg.stat_mod_type_filter, v_d_ability_cfg.prevention_duration,
         v_d_ability_cfg.keep_going_turns, v_d_ability_cfg.keep_going_until_fail, v_d_ability_cfg.keep_going_bonus_type, v_d_ability_cfg.keep_going_bonus_flat, v_d_ability_cfg.keep_going_bonus_percent,
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
    v_a_state, v_d_state, v_a_ability_cfg, v_d_ability_cfg, v_precision_enabled,
    -- Talents d'espèce : le pantin d'essai utilise ceux de l'espèce snapshotée
    -- sur la ligne d'essai (pvp_trial_battles.dummy_pokemon_nom).
    autobattle_talents_for(v_pp.pokemon_nom, v_talents_enabled), autobattle_talents_for(v_row.dummy_pokemon_nom, v_talents_enabled)
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

GRANT EXECUTE ON FUNCTION pvp_trial_resolve_round(bigint, uuid) TO anon, authenticated;
