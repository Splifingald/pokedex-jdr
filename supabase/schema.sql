-- ============================================================
-- Pokédex RPG — Schéma Supabase
-- À exécuter dans : Supabase Dashboard > SQL Editor
-- ============================================================

-- ============================================================
-- MISE À JOUR : exécuter ces commandes si la table existe déjà
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS cache boolean NOT NULL DEFAULT false;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS code text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS audio_url text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS transport text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS transport_value integer;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_1 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_2 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_3 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_4 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_5 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_6 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_7 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_8 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_9 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_10 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_11 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_12 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_13 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_14 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS attaque_15 text;
-- CREATE POLICY "Public delete discovered" ON discovered_pokemon FOR DELETE TO anon USING (true);
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS xp_10 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS xp_20 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS xp_30 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS xp_40 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS xp_50 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS xp_60 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS xp_70 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS xp_80 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS xp_90 text;
-- ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS xp_100 text;
-- ALTER TABLE player_pokemon DROP COLUMN IF EXISTS max_hp_override;
-- ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS nickname text;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS carte_image_url text NOT NULL DEFAULT '';
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS carte_couleurs_image_url text NOT NULL DEFAULT '';
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS accueil_image_url text NOT NULL DEFAULT '';
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_pokedex_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_photo_capture_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_pokemon_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_inventory_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_map_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE campaign_sessions ADD COLUMN IF NOT EXISTS done boolean NOT NULL DEFAULT false;
-- ALTER TABLE campaign_chapters ADD COLUMN IF NOT EXISTS done boolean NOT NULL DEFAULT false;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_gifting_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS next_gift_at timestamptz;
-- ALTER TABLE gift_lootboxes RENAME COLUMN timer_min_hours TO timer_min;
-- ALTER TABLE gift_lootboxes RENAME COLUMN timer_max_hours TO timer_max;
-- ALTER TABLE gift_lootboxes ADD COLUMN IF NOT EXISTS timer_unit text NOT NULL DEFAULT 'hours' CHECK (timer_unit IN ('hours', 'minutes'));
-- ALTER TABLE campaign_chapters ADD COLUMN IF NOT EXISTS position integer NOT NULL DEFAULT 0;
-- WITH ranked AS (
--   SELECT id, ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY created_at) - 1 AS rn
--   FROM campaign_chapters
-- )
-- UPDATE campaign_chapters c SET position = ranked.rn FROM ranked WHERE ranked.id = c.id;
-- ALTER TABLE campaign_sessions ADD COLUMN IF NOT EXISTS notes jsonb NOT NULL DEFAULT '{"type":"doc","content":[{"type":"paragraph"}]}'::jsonb;
-- ALTER TABLE campaign_chapters ADD COLUMN IF NOT EXISTS notes jsonb NOT NULL DEFAULT '{"type":"doc","content":[{"type":"paragraph"}]}'::jsonb;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_casino_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE casino_config ADD COLUMN IF NOT EXISTS slots_pokeball_weight integer NOT NULL DEFAULT 1;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_minijeux_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE history_events DROP CONSTRAINT IF EXISTS history_events_category_check;
-- ALTER TABLE history_events ADD CONSTRAINT history_events_category_check CHECK (category IN ('inventory', 'pokedex', 'team', 'combat', 'minigame'));
-- ALTER TABLE casino_config ADD COLUMN IF NOT EXISTS slots_superball_weight integer NOT NULL DEFAULT 1;
-- ALTER TABLE casino_config ADD COLUMN IF NOT EXISTS slots_hyperball_weight integer NOT NULL DEFAULT 1;
-- ALTER TABLE casino_config ADD COLUMN IF NOT EXISTS slots_masterball_weight integer NOT NULL DEFAULT 1;
-- ALTER TABLE casino_config ADD COLUMN IF NOT EXISTS dice_opponent_name text NOT NULL DEFAULT 'Le Croupier';
-- ALTER TABLE casino_config ADD COLUMN IF NOT EXISTS dice_opponent_image_url text NOT NULL DEFAULT '';
-- ALTER TABLE casino_config ADD COLUMN IF NOT EXISTS ticket_full_notify_enabled boolean NOT NULL DEFAULT false;
-- ALTER TABLE casino_player_state ADD COLUMN IF NOT EXISTS ticket_full_notified boolean NOT NULL DEFAULT false;
-- ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS gift_notified boolean NOT NULL DEFAULT false;
-- ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS gift_notified_at timestamptz;
-- ALTER TABLE campaign_sessions ADD COLUMN IF NOT EXISTS image_position integer NOT NULL DEFAULT 50;
-- ALTER TABLE campaign_chapters ADD COLUMN IF NOT EXISTS image_position integer NOT NULL DEFAULT 50;
-- Fusion de la table backgrounds dans display_assets (type = 'Background'), et passage du
-- calque objet du mode Affichage d'un slot unique (item_id) à un calque multi comme PNJ/Pokémon.
-- Exécuter dans cet ordre exact, une seule fois :
-- INSERT INTO display_assets (id, nom, type, image_url)
--   SELECT id, nom, 'Background', image_url FROM backgrounds
--   ON CONFLICT (id) DO NOTHING;
-- SELECT setval('display_assets_id_seq', (SELECT COALESCE(MAX(id), 1) FROM display_assets));
-- ALTER TABLE display_state DROP CONSTRAINT display_state_background_id_fkey;
-- ALTER TABLE display_state
--   ADD CONSTRAINT display_state_background_id_fkey
--   FOREIGN KEY (background_id) REFERENCES display_assets(id) ON DELETE SET NULL;
-- ALTER TABLE display_state ADD COLUMN IF NOT EXISTS item_ids jsonb NOT NULL DEFAULT '[]'::jsonb;
-- UPDATE display_state
--   SET item_ids = CASE WHEN item_id IS NOT NULL THEN jsonb_build_array(item_id) ELSE '[]'::jsonb END
--   WHERE id = 1;
-- ALTER TABLE display_state DROP COLUMN item_id;
-- DROP TABLE backgrounds; -- seulement après avoir vérifié que /display et Admin → Affichage sont corrects
-- ALTER TABLE display_state ADD COLUMN IF NOT EXISTS background_url text;
-- ALTER TABLE players ADD COLUMN IF NOT EXISTS full_body_image_url text NOT NULL DEFAULT '';
-- ALTER TABLE players ADD COLUMN IF NOT EXISTS age integer;
-- ALTER TABLE players ADD COLUMN IF NOT EXISTS background_story text NOT NULL DEFAULT '';
-- ALTER TABLE players ADD COLUMN IF NOT EXISTS level integer NOT NULL DEFAULT 1;
-- ALTER TABLE players ADD COLUMN IF NOT EXISTS stat_charisme integer NOT NULL DEFAULT 10;
-- ALTER TABLE players ADD COLUMN IF NOT EXISTS stat_intelligence integer NOT NULL DEFAULT 10;
-- ALTER TABLE players ADD COLUMN IF NOT EXISTS stat_sagesse integer NOT NULL DEFAULT 10;
-- ALTER TABLE players ADD COLUMN IF NOT EXISTS stat_dexterite integer NOT NULL DEFAULT 10;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS stat_points_base integer NOT NULL DEFAULT 40;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS stat_min integer NOT NULL DEFAULT 5;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS stat_max integer NOT NULL DEFAULT 15;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS stat_points_per_level integer NOT NULL DEFAULT 1;
-- ALTER TABLE campaign_sessions ADD COLUMN IF NOT EXISTS position integer NOT NULL DEFAULT 0;
-- WITH ranked AS (
--   SELECT id, ROW_NUMBER() OVER (ORDER BY session_date DESC NULLS LAST, created_at DESC) - 1 AS rn
--   FROM campaign_sessions
-- )
-- UPDATE campaign_sessions c SET position = ranked.rn FROM ranked WHERE ranked.id = c.id;
-- ALTER TABLE display_assets ADD COLUMN IF NOT EXISTS reference text NOT NULL DEFAULT '';
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS map_addon_image_urls jsonb NOT NULL DEFAULT '[]'::jsonb;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_mining_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE mining_config ADD COLUMN IF NOT EXISTS hidden_cell_image_url text NOT NULL DEFAULT '';
-- ALTER TABLE mining_config ADD COLUMN IF NOT EXISTS fill_ratio_pct integer NOT NULL DEFAULT 20;
-- ALTER TABLE mining_config ADD COLUMN IF NOT EXISTS empty_cell_image_url text NOT NULL DEFAULT '';
-- ALTER TABLE mining_config DROP COLUMN IF EXISTS item_count_min;
-- ALTER TABLE mining_config DROP COLUMN IF EXISTS item_count_max;
-- ============================================================

-- Table principale des pokémon
CREATE TABLE IF NOT EXISTS pokemon (
  id                    bigserial PRIMARY KEY,
  numero                text NOT NULL,
  nom                   text NOT NULL UNIQUE,
  type                  text NOT NULL,
  degats_base           integer NOT NULL DEFAULT 0,
  pv_base               integer NOT NULL DEFAULT 0,
  -- Colonnes historiques « Super Efficace 1..4 » du CSV : conservées et
  -- toujours importées (voir AdminPanel), mais PLUS LUES NULLE PART depuis que
  -- l'efficacité se calcule entre le type de la CAPACITÉ et celui du défenseur
  -- (voir type_super_effective plus bas).
  super_efficace_1      text,
  super_efficace_2      text,
  super_efficace_3      text,
  super_efficace_4      text,
  distance_deplacement  integer NOT NULL DEFAULT 0,
  image_miniature       text NOT NULL DEFAULT '',
  image_illustree       text NOT NULL DEFAULT '',
  nom_talent            text,
  description_talent    text,
  chances_capture       text,
  localisation_1        text,
  localisation_2        text,
  localisation_3        text,
  cache                 boolean NOT NULL DEFAULT false,
  code                  text,
  audio_url             text,
  transport             text,
  transport_value       integer,
  attaque_1             text,
  attaque_2             text,
  attaque_3             text,
  attaque_4             text,
  attaque_5             text,
  attaque_6             text,
  attaque_7             text,
  attaque_8             text,
  attaque_9             text,
  attaque_10            text,
  attaque_11            text,
  attaque_12            text,
  attaque_13            text,
  attaque_14            text,
  attaque_15            text,
  xp_10                 text,
  xp_20                 text,
  xp_30                 text,
  xp_40                 text,
  xp_50                 text,
  xp_60                 text,
  xp_70                 text,
  xp_80                 text,
  xp_90                 text,
  xp_100                text
);

-- Table des attaques (référencées par nom depuis pokemon.attaque_1..15, pas de FK)
CREATE TABLE IF NOT EXISTS attacks (
  id             bigserial PRIMARY KEY,
  nom            text NOT NULL UNIQUE,
  type           text NOT NULL,
  degats_base    integer,
  degats_de      integer,
  cible          text,
  distance       integer,
  precision      integer,
  degats_moyens  numeric,
  effet          text
);

-- Lieux de la carte (référencés par couleur depuis l'image de couleurs, pas de FK)
CREATE TABLE IF NOT EXISTS carte_locations (
  id                 bigserial PRIMARY KEY,
  couleur            text NOT NULL UNIQUE,
  titre              text NOT NULL DEFAULT '',
  description        text,
  admin_description  text,
  type               text,
  image_url          text
);

-- Mise à jour si la table existe déjà :
-- ALTER TABLE carte_locations ADD COLUMN IF NOT EXISTS admin_description text;

-- Table des découvertes (état global partagé)
-- Référence par nom (pas de FK) pour survivre aux réimports CSV
CREATE TABLE IF NOT EXISTS discovered_pokemon (
  pokemon_nom   text PRIMARY KEY,
  discovered_at timestamptz NOT NULL DEFAULT now()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_pokemon_numero ON pokemon(numero);

-- ============================================================
-- Row Level Security
-- ============================================================

-- Poids de l'espèce (colonne « Poids » du CSV, en kg — décimales acceptées) :
-- purement informatif à l'affichage, mais lu en combat par la condition de
-- dégâts additionnels 'weight_ratio' (voir autobattle_ability_rules.
-- bonus_damage_weight_*). Colonne CSV facultative : absente = NULL, la
-- condition ne se déclenche alors jamais.
ALTER TABLE pokemon ADD COLUMN IF NOT EXISTS poids numeric;

ALTER TABLE pokemon ENABLE ROW LEVEL SECURITY;
ALTER TABLE attacks ENABLE ROW LEVEL SECURITY;
ALTER TABLE carte_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE discovered_pokemon ENABLE ROW LEVEL SECURITY;

-- pokemon : lecture publique, écriture bloquée pour anon (via Edge Function seulement)
CREATE POLICY "Public read pokemon"
  ON pokemon FOR SELECT
  TO anon
  USING (true);

-- attacks : lecture publique, écriture bloquée pour anon (via Netlify Function seulement)
CREATE POLICY "Public read attacks"
  ON attacks FOR SELECT
  TO anon
  USING (true);

-- carte_locations : lecture publique, écriture bloquée pour anon (via Netlify Function seulement)
CREATE POLICY "Public read carte_locations"
  ON carte_locations FOR SELECT
  TO anon
  USING (true);

-- discovered_pokemon : lecture + insertion publiques
CREATE POLICY "Public read discovered"
  ON discovered_pokemon FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Public insert discovered"
  ON discovered_pokemon FOR INSERT
  TO anon
  WITH CHECK (true);

-- Permettre d'annuler une découverte (bouton "Marquer comme non découvert")
CREATE POLICY "Public delete discovered"
  ON discovered_pokemon FOR DELETE
  TO anon
  USING (true);

-- ============================================================
-- Joueurs, roster et paramètres admin
-- ============================================================

CREATE TABLE IF NOT EXISTS players (
  id                    bigserial PRIMARY KEY,
  name                  text NOT NULL,
  color                 text NOT NULL DEFAULT '#3B82F6',
  image_url             text NOT NULL DEFAULT '',
  is_npc                boolean NOT NULL DEFAULT false,
  full_body_image_url   text NOT NULL DEFAULT '',
  age                   integer,
  background_story      text NOT NULL DEFAULT '',
  level                 integer NOT NULL DEFAULT 1,
  stat_charisme         integer NOT NULL DEFAULT 10,
  stat_intelligence     integer NOT NULL DEFAULT 10,
  stat_sagesse          integer NOT NULL DEFAULT 10,
  stat_dexterite        integer NOT NULL DEFAULT 10,
  created_at            timestamptz NOT NULL DEFAULT now()
);

-- Pokémon possédés (une ligne par instance capturée, pas par espèce :
-- un joueur peut posséder plusieurs fois le même pokémon)
CREATE TABLE IF NOT EXISTS player_pokemon (
  id              bigserial PRIMARY KEY,
  player_id       bigint NOT NULL,
  pokemon_nom     text NOT NULL,     -- référence par nom vers pokemon.nom (pas de FK, survit aux réimports CSV)
  pokemon_numero  text,              -- copie du numéro pour résilience d'affichage
  nickname        text,              -- surnom personnalisé donné par le joueur (affiché à la place de pokemon_nom si défini)
  xp              integer NOT NULL DEFAULT 0,
  moves           text[] NOT NULL DEFAULT '{}',
  in_team         boolean NOT NULL DEFAULT false,
  next_gift_at    timestamptz,       -- prochain cadeau du pokémon (cadeaux Pokémon), NULL = aucun cadeau prévu
  gift_notified   boolean NOT NULL DEFAULT false, -- push déjà envoyé pour ce cadeau, évite les doublons entre passages du cron
  gift_notified_at timestamptz,      -- horodatage du dernier push envoyé pour ce cadeau, sert à renvoyer un rappel 72h après si toujours pas réclamé
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Mise à jour si la table existe déjà :
-- ALTER TABLE players ADD COLUMN IF NOT EXISTS is_npc boolean NOT NULL DEFAULT false;

-- Paramètres admin (une seule ligne, id fixe = 1)
CREATE TABLE IF NOT EXISTS admin_parameters (
  id                        bigint PRIMARY KEY DEFAULT 1,
  max_moves                 integer NOT NULL DEFAULT 4,
  max_team_size             integer NOT NULL DEFAULT 3,
  carte_image_url           text NOT NULL DEFAULT '',
  carte_couleurs_image_url  text NOT NULL DEFAULT '',
  map_addon_image_urls      jsonb NOT NULL DEFAULT '[]'::jsonb,
  accueil_image_url         text NOT NULL DEFAULT '',
  feature_pokedex_enabled        boolean NOT NULL DEFAULT true,
  feature_photo_capture_enabled  boolean NOT NULL DEFAULT true,
  feature_pokemon_enabled        boolean NOT NULL DEFAULT true,
  feature_inventory_enabled      boolean NOT NULL DEFAULT true,
  feature_map_enabled            boolean NOT NULL DEFAULT true,
  feature_gifting_enabled        boolean NOT NULL DEFAULT true,
  feature_casino_enabled         boolean NOT NULL DEFAULT true,
  feature_minijeux_enabled       boolean NOT NULL DEFAULT true,
  feature_mining_enabled         boolean NOT NULL DEFAULT true,
  stat_points_base          integer NOT NULL DEFAULT 40,
  stat_min                  integer NOT NULL DEFAULT 5,
  stat_max                  integer NOT NULL DEFAULT 15,
  stat_points_per_level     integer NOT NULL DEFAULT 1,
  stat_charisme_icon_url        text NOT NULL DEFAULT '',
  stat_charisme_description     text NOT NULL DEFAULT '',
  stat_intelligence_icon_url    text NOT NULL DEFAULT '',
  stat_intelligence_description text NOT NULL DEFAULT '',
  stat_sagesse_icon_url         text NOT NULL DEFAULT '',
  stat_sagesse_description      text NOT NULL DEFAULT '',
  stat_dexterite_icon_url       text NOT NULL DEFAULT '',
  stat_dexterite_description    text NOT NULL DEFAULT '',
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO admin_parameters (id, max_moves, max_team_size)
VALUES (1, 4, 3) ON CONFLICT (id) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_player_pokemon_player_id ON player_pokemon(player_id);

ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_pokemon ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_parameters ENABLE ROW LEVEL SECURITY;

-- players : lecture + écriture publiques (pas d'authentification réelle, app privée entre amis)
CREATE POLICY "Public read players"
  ON players FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Public insert players"
  ON players FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Public update players"
  ON players FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Public delete players"
  ON players FOR DELETE
  TO anon
  USING (true);

-- player_pokemon : lecture + écriture publiques
CREATE POLICY "Public read player_pokemon"
  ON player_pokemon FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Public insert player_pokemon"
  ON player_pokemon FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Public update player_pokemon"
  ON player_pokemon FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Public delete player_pokemon"
  ON player_pokemon FOR DELETE
  TO anon
  USING (true);

-- admin_parameters : lecture + écriture publiques (n'importe quel client peut modifier
-- max_moves / max_team_size, pas seulement l'onglet Admin — voulu, app sans vraie sécurité)
CREATE POLICY "Public read admin_parameters"
  ON admin_parameters FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Public update admin_parameters"
  ON admin_parameters FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

-- ============================================================
-- Objets et inventaire (Sac)
-- ============================================================

-- Catalogue d'objets (importé par CSV via Netlify Function)
CREATE TABLE IF NOT EXISTS items (
  id          bigserial PRIMARY KEY,
  nom         text NOT NULL UNIQUE,
  type        text NOT NULL DEFAULT '',
  rarete      text,
  achat       integer NOT NULL DEFAULT 0,
  vente       integer NOT NULL DEFAULT 0,
  description text,
  image_url   text
);

-- Inventaire par joueur (référence par nom, pas de FK — survit aux réimports)
-- La ligne "Pokedollar" représente l'argent du joueur (pas affichée comme un objet normal)
CREATE TABLE IF NOT EXISTS player_items (
  id          bigserial PRIMARY KEY,
  player_id   bigint NOT NULL,
  item_nom    text NOT NULL,
  quantity    integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (player_id, item_nom)
);
CREATE INDEX IF NOT EXISTS idx_player_items_player_id ON player_items(player_id);

ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_items ENABLE ROW LEVEL SECURITY;

-- items : lecture publique, écriture bloquée pour anon (via Netlify Function seulement)
CREATE POLICY "Public read items"
  ON items FOR SELECT
  TO anon
  USING (true);

-- player_items : lecture + écriture publiques
CREATE POLICY "Public read player_items"
  ON player_items FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Public insert player_items"
  ON player_items FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Public update player_items"
  ON player_items FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Public delete player_items"
  ON player_items FOR DELETE
  TO anon
  USING (true);

-- ============================================================
-- Cadeaux Pokémon (lootboxes)
-- ============================================================

CREATE TABLE IF NOT EXISTS gift_lootboxes (
  id                bigserial PRIMARY KEY,
  nom               text NOT NULL,
  is_default        boolean NOT NULL DEFAULT false,
  timer_min         integer NOT NULL DEFAULT 60,
  timer_max         integer NOT NULL DEFAULT 80,
  timer_unit        text NOT NULL DEFAULT 'hours' CHECK (timer_unit IN ('hours', 'minutes')),
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- Un seul lootbox par défaut à la fois
CREATE UNIQUE INDEX IF NOT EXISTS idx_gift_lootboxes_one_default
  ON gift_lootboxes (is_default) WHERE is_default = true;

-- Contenu pondéré de chaque lootbox : quantité fixe + poids (tirage pondéré à une
-- entrée par cadeau). item_nom référence items.nom ou 'Pokédollar' — pas de FK
-- (survit aux réimports CSV, comme le reste du catalogue).
CREATE TABLE IF NOT EXISTS gift_lootbox_items (
  id           bigserial PRIMARY KEY,
  lootbox_id   bigint NOT NULL REFERENCES gift_lootboxes(id) ON DELETE CASCADE,
  item_nom     text NOT NULL,
  quantity     integer NOT NULL DEFAULT 1,
  weight       integer NOT NULL DEFAULT 1,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_gift_lootbox_items_lootbox_id ON gift_lootbox_items(lootbox_id);

-- Assignation espèce → lootbox : une espèce non listée utilise le lootbox par
-- défaut. pokemon_nom = clé primaire (un seul lootbox par espèce), référence
-- pokemon.nom sans FK (survit aux réimports CSV).
CREATE TABLE IF NOT EXISTS gift_lootbox_species (
  pokemon_nom  text PRIMARY KEY,
  lootbox_id   bigint NOT NULL REFERENCES gift_lootboxes(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_gift_lootbox_species_lootbox_id ON gift_lootbox_species(lootbox_id);

ALTER TABLE gift_lootboxes ENABLE ROW LEVEL SECURITY;
ALTER TABLE gift_lootbox_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE gift_lootbox_species ENABLE ROW LEVEL SECURITY;

-- Lecture + écriture publiques (édité en direct depuis l'onglet Admin, comme
-- admin_parameters/players — app sans vraie sécurité)
CREATE POLICY "Public read gift_lootboxes"
  ON gift_lootboxes FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert gift_lootboxes"
  ON gift_lootboxes FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update gift_lootboxes"
  ON gift_lootboxes FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete gift_lootboxes"
  ON gift_lootboxes FOR DELETE TO anon USING (true);

CREATE POLICY "Public read gift_lootbox_items"
  ON gift_lootbox_items FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert gift_lootbox_items"
  ON gift_lootbox_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update gift_lootbox_items"
  ON gift_lootbox_items FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete gift_lootbox_items"
  ON gift_lootbox_items FOR DELETE TO anon USING (true);

CREATE POLICY "Public read gift_lootbox_species"
  ON gift_lootbox_species FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert gift_lootbox_species"
  ON gift_lootbox_species FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update gift_lootbox_species"
  ON gift_lootbox_species FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete gift_lootbox_species"
  ON gift_lootbox_species FOR DELETE TO anon USING (true);

-- ============================================================
-- Table de rencontres (importée par CSV via Netlify Function)
-- ============================================================

CREATE TABLE IF NOT EXISTS encounters (
  id          bigserial PRIMARY KEY,
  lieu        text NOT NULL,
  pokemon_nom text NOT NULL,
  de          integer,
  commentaire text
);

ALTER TABLE encounters ENABLE ROW LEVEL SECURITY;

-- encounters : lecture publique, écriture bloquée pour anon (via Netlify Function seulement)
CREATE POLICY "Public read encounters"
  ON encounters FOR SELECT
  TO anon
  USING (true);

-- ============================================================
-- Table backgrounds retirée : fusionnée dans display_assets (type = 'Background'),
-- voir la migration commentée plus haut. Les fonds d'écran de l'accueil et du mode
-- Affichage sont désormais tous des lignes display_assets.
-- ============================================================

-- ============================================================
-- Journal de campagne (Sessions / Chapitres)
-- ============================================================

CREATE TABLE IF NOT EXISTS campaign_sessions (
  id           bigserial PRIMARY KEY,
  title        text NOT NULL,
  icon         text NOT NULL DEFAULT '📓',
  session_date date,
  image_url    text,
  image_position integer NOT NULL DEFAULT 50,
  done         boolean NOT NULL DEFAULT false,
  notes        jsonb NOT NULL DEFAULT '{"type":"doc","content":[{"type":"paragraph"}]}'::jsonb,
  position     integer NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS campaign_chapters (
  id           bigserial PRIMARY KEY,
  session_id   bigint NOT NULL REFERENCES campaign_sessions(id) ON DELETE CASCADE,
  title        text NOT NULL,
  icon         text NOT NULL DEFAULT '📄',
  image_url    text,
  image_position integer NOT NULL DEFAULT 50,
  content      jsonb NOT NULL DEFAULT '{"type":"doc","content":[{"type":"paragraph"}]}'::jsonb,
  notes        jsonb NOT NULL DEFAULT '{"type":"doc","content":[{"type":"paragraph"}]}'::jsonb,
  done         boolean NOT NULL DEFAULT false,
  position     integer NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_campaign_chapters_session_id ON campaign_chapters(session_id);

ALTER TABLE campaign_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_chapters ENABLE ROW LEVEL SECURITY;

-- campaign_sessions / campaign_chapters : lecture + écriture publiques
-- (app sans vraie sécurité, édité en direct depuis le client comme players/admin_parameters)
CREATE POLICY "Public read campaign_sessions"
  ON campaign_sessions FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Public insert campaign_sessions"
  ON campaign_sessions FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Public update campaign_sessions"
  ON campaign_sessions FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Public delete campaign_sessions"
  ON campaign_sessions FOR DELETE
  TO anon
  USING (true);

CREATE POLICY "Public read campaign_chapters"
  ON campaign_chapters FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Public insert campaign_chapters"
  ON campaign_chapters FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Public update campaign_chapters"
  ON campaign_chapters FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Public delete campaign_chapters"
  ON campaign_chapters FOR DELETE
  TO anon
  USING (true);

-- ============================================================
-- Casino
-- ============================================================

-- Objet "Ticket Casino" du catalogue (le stock par joueur vit dans player_items,
-- comme Pokédollar). RLS bloque l'écriture anon sur items — cette ligne doit
-- être insérée une fois via le SQL Editor (contourne RLS).
INSERT INTO items (nom, type, achat, vente, description, image_url)
VALUES ('Ticket Casino', 'Monnaie', 0, 0, 'Permet de jouer au Casino.', '/website_icons/icon_casino_ticket.png')
ON CONFLICT (nom) DO NOTHING;

-- Paramètres admin du Casino (une seule ligne, id fixe = 1) — même schéma que
-- admin_parameters : économie des tickets + config des deux jeux (jusqu'à 3,
-- un 3e jeu ajoutera simplement ses propres colonnes préfixées plus tard).
CREATE TABLE IF NOT EXISTS casino_config (
  id                          bigint PRIMARY KEY DEFAULT 1,
  -- Économie des tickets
  ticket_max                  integer NOT NULL DEFAULT 3,
  ticket_regen_amount         integer NOT NULL DEFAULT 24,
  ticket_regen_unit           text NOT NULL DEFAULT 'hours' CHECK (ticket_regen_unit IN ('hours', 'minutes')),
  ticket_buy_cost             integer NOT NULL DEFAULT 100,
  ticket_daily_buy_cap        integer NOT NULL DEFAULT 3,
  ticket_full_notify_enabled  boolean NOT NULL DEFAULT false,
  -- Jeu 1 : Chance de Miaouss (machine à sous)
  slots_enabled               boolean NOT NULL DEFAULT true,
  slots_nom                   text NOT NULL DEFAULT 'Chance de Miaouss',
  slots_icon_url              text NOT NULL DEFAULT '',
  slots_banner_url            text NOT NULL DEFAULT '',
  slots_pokeball_value        integer NOT NULL DEFAULT 10,
  slots_superball_value       integer NOT NULL DEFAULT 20,
  slots_hyperball_value       integer NOT NULL DEFAULT 50,
  slots_masterball_value      integer NOT NULL DEFAULT 200,
  -- Poids relatifs de tirage (probabilité = poids / somme des poids)
  slots_pokeball_weight       integer NOT NULL DEFAULT 1,
  slots_superball_weight      integer NOT NULL DEFAULT 1,
  slots_hyperball_weight      integer NOT NULL DEFAULT 1,
  slots_masterball_weight     integer NOT NULL DEFAULT 1,
  slots_match2_multiplier     integer NOT NULL DEFAULT 3,
  slots_match3_multiplier     integer NOT NULL DEFAULT 10,
  -- Jeu 2 : Dé Chance (dés contre l'IA)
  dice_enabled                boolean NOT NULL DEFAULT true,
  dice_nom                    text NOT NULL DEFAULT 'Dé Chance',
  dice_icon_url               text NOT NULL DEFAULT '',
  dice_banner_url             text NOT NULL DEFAULT '',
  dice_max_rounds             integer NOT NULL DEFAULT 3,
  dice_initial_gain           integer NOT NULL DEFAULT 100,
  dice_ai_target_min          integer NOT NULL DEFAULT 13,
  dice_ai_target_max          integer NOT NULL DEFAULT 17,
  dice_opponent_name          text NOT NULL DEFAULT 'Le Croupier',
  dice_opponent_image_url     text NOT NULL DEFAULT '',
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO casino_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- État casino par joueur : minuteur du prochain ticket gratuit + suivi des
-- achats du jour (plafond quotidien, réinitialisé à minuit local côté client).
CREATE TABLE IF NOT EXISTS casino_player_state (
  player_id             bigint PRIMARY KEY,
  next_ticket_at        timestamptz,
  purchase_count        integer NOT NULL DEFAULT 0,
  purchase_date         date,
  ticket_full_notified  boolean NOT NULL DEFAULT false, -- push "tickets pleins" déjà envoyé, réarmé quand un ticket est dépensé
  created_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE casino_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE casino_player_state ENABLE ROW LEVEL SECURITY;

-- Lecture + écriture publiques (édité en direct depuis l'onglet Admin, comme
-- admin_parameters/gift_lootboxes — app sans vraie sécurité)
CREATE POLICY "Public read casino_config"
  ON casino_config FOR SELECT TO anon USING (true);
CREATE POLICY "Public update casino_config"
  ON casino_config FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read casino_player_state"
  ON casino_player_state FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert casino_player_state"
  ON casino_player_state FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update casino_player_state"
  ON casino_player_state FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- Mini-Jeux (coexiste avec le Casino, économie de tickets séparée)
-- ============================================================

-- Objet "Ticket Trempette" du catalogue (le stock par joueur vit dans
-- player_items, comme Ticket Casino/Pokédollar). RLS bloque l'écriture anon
-- sur items — cette ligne doit être insérée une fois via le SQL Editor.
INSERT INTO items (nom, type, achat, vente, description, image_url)
VALUES ('Ticket Trempette', 'Monnaie', 0, 0, 'Permet de jouer aux Mini-Jeux.', '/website_icons/icon_magikarp_ticket.png')
ON CONFLICT (nom) DO NOTHING;

-- Paramètres admin des Mini-Jeux (une seule ligne, id fixe = 1) — même schéma
-- que casino_config : économie des tickets (Ticket Trempette, indépendante du
-- Casino) + config de chaque mini-jeu via ses propres colonnes préfixées.
CREATE TABLE IF NOT EXISTS minigames_config (
  id                          bigint PRIMARY KEY DEFAULT 1,
  -- Économie des tickets
  ticket_max                  integer NOT NULL DEFAULT 3,
  ticket_regen_amount         integer NOT NULL DEFAULT 24,
  ticket_regen_unit           text NOT NULL DEFAULT 'hours' CHECK (ticket_regen_unit IN ('hours', 'minutes')),
  ticket_buy_cost             integer NOT NULL DEFAULT 0,
  ticket_daily_buy_cap        integer NOT NULL DEFAULT 3,
  ticket_full_notify_enabled  boolean NOT NULL DEFAULT false,
  -- Jeu 1 : Magikarp (tap game)
  magikarp_enabled            boolean NOT NULL DEFAULT true,
  magikarp_nom                text NOT NULL DEFAULT 'Magikarp',
  magikarp_icon_url           text NOT NULL DEFAULT '/website_icons/icon_magikarp_game.png',
  magikarp_banner_url         text NOT NULL DEFAULT '',
  magikarp_numero             text NOT NULL DEFAULT '129',
  magikarp_duration_seconds   integer NOT NULL DEFAULT 10,
  magikarp_star1_taps         integer NOT NULL DEFAULT 20,
  magikarp_star2_taps         integer NOT NULL DEFAULT 30,
  magikarp_star3_taps         integer NOT NULL DEFAULT 50,
  magikarp_star1_xp           integer NOT NULL DEFAULT 5,
  magikarp_star2_xp           integer NOT NULL DEFAULT 10,
  magikarp_star3_xp           integer NOT NULL DEFAULT 20,
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO minigames_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- État Mini-Jeux par joueur : minuteur du prochain ticket gratuit + suivi des
-- achats du jour + meilleurs scores par jeu (une colonne préfixée par jeu).
CREATE TABLE IF NOT EXISTS minigames_player_state (
  player_id             bigint PRIMARY KEY,
  next_ticket_at        timestamptz,
  purchase_count        integer NOT NULL DEFAULT 0,
  purchase_date         date,
  ticket_full_notified  boolean NOT NULL DEFAULT false,
  magikarp_high_score   integer NOT NULL DEFAULT 0,
  created_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE minigames_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE minigames_player_state ENABLE ROW LEVEL SECURITY;

-- Lecture + écriture publiques (édité en direct depuis l'onglet Admin, comme
-- casino_config — app sans vraie sécurité)
CREATE POLICY "Public read minigames_config"
  ON minigames_config FOR SELECT TO anon USING (true);
CREATE POLICY "Public update minigames_config"
  ON minigames_config FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read minigames_player_state"
  ON minigames_player_state FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert minigames_player_state"
  ON minigames_player_state FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update minigames_player_state"
  ON minigames_player_state FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- Notifications Push (Web Push : tickets casino pleins, cadeau pokémon prêt)
-- ============================================================

-- Un abonnement push par (joueur, navigateur/appareil). Un joueur peut avoir
-- plusieurs abonnements (plusieurs appareils installés).
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id          bigserial PRIMARY KEY,
  player_id   bigint NOT NULL,
  endpoint    text NOT NULL UNIQUE,
  p256dh      text NOT NULL,
  auth        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_player_id ON push_subscriptions(player_id);

ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Lecture + écriture publiques, comme le reste de l'app (pas d'authentification
-- réelle). La fonction planifiée qui envoie les push utilise la clé service_role
-- côté serveur et n'est donc pas concernée par ces policies anon.
CREATE POLICY "Public read push_subscriptions"
  ON push_subscriptions FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert push_subscriptions"
  ON push_subscriptions FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update push_subscriptions"
  ON push_subscriptions FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete push_subscriptions"
  ON push_subscriptions FOR DELETE TO anon USING (true);

-- ============================================================
-- Évolutions de Pokémon (catalogue, importé par CSV via Netlify Function)
-- ============================================================

-- Une ligne par option d'évolution possible (une espèce peut avoir plusieurs
-- lignes = évolutions multiples, ex : Évoli). Référence par nom vers pokemon.nom
-- et items.nom, pas de FK — survit aux réimports CSV (même convention que le
-- reste du schéma).
CREATE TABLE IF NOT EXISTS pokemon_evolutions (
  id                  bigserial PRIMARY KEY,
  pokemon_nom         text NOT NULL,
  evolution_nom       text NOT NULL,
  condition_item_nom  text,
  created_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pokemon_evolutions_pokemon_nom ON pokemon_evolutions(pokemon_nom);

ALTER TABLE pokemon_evolutions ENABLE ROW LEVEL SECURITY;

-- Lecture publique, écriture bloquée pour anon (via Netlify Function seulement) —
-- même politique que la table items.
CREATE POLICY "Public read pokemon_evolutions"
  ON pokemon_evolutions FOR SELECT
  TO anon
  USING (true);

-- ============================================================
-- Historique (journal des actions joueurs, onglet Admin → Historique)
-- ============================================================

-- Un événement brut par mutation (pas de coalescing en écriture — le
-- regroupement des lignes proches dans le temps se fait à la lecture, côté
-- client, voir src/lib/historyGrouping.ts). player_id référence players.id
-- sans FK (comme le reste du schéma). payload est spécifique à chaque
-- (category, action_type), voir src/types.ts pour la forme exacte.
CREATE TABLE IF NOT EXISTS history_events (
  id           bigserial PRIMARY KEY,
  player_id    bigint NOT NULL,
  category     text NOT NULL CHECK (category IN ('inventory', 'pokedex', 'team', 'combat', 'minigame')),
  action_type  text NOT NULL,
  payload      jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_history_events_created_at ON history_events(created_at);
CREATE INDEX IF NOT EXISTS idx_history_events_player_id ON history_events(player_id);

ALTER TABLE history_events ENABLE ROW LEVEL SECURITY;

-- Lecture + insertion publiques (app sans vraie sécurité). Pas de policy
-- UPDATE/DELETE : le journal est immuable depuis le client.
CREATE POLICY "Public read history_events"
  ON history_events FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert history_events"
  ON history_events FOR INSERT TO anon WITH CHECK (true);

-- Diffusion Realtime : malgré ce que suggère un commentaire plus bas dans ce
-- fichier (au sujet des tables mining_*), history_events n'était en réalité
-- PAS membre de la publication supabase_realtime — vérifié par un test direct
-- (souscription à un canal INSERT jamais déclenchée après une écriture). C'est
-- la cause d'un bug observé : le panneau Admin → Historique et le
-- rafraîchissement live des événements (ex. objet Fouille tout juste trouvé)
-- ne se mettaient à jour qu'au rechargement complet de la page. Bloc
-- idempotent (sûr à ré-exécuter).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'history_events'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE history_events;
  END IF;
END $$;

-- ============================================================
-- Mode Affichage (écran joueurs : fond, PNJ, Pokémon, objet)
-- ============================================================

-- Images d'affichage importées par CSV via Netlify Function (Nom/Type/Image).
-- Couvre les PNJ (type = 'NPC') et les fonds d'écran (type = 'Background', ex-table
-- backgrounds fusionnée ici) et les futurs types à venir.
CREATE TABLE IF NOT EXISTS display_assets (
  id          bigserial PRIMARY KEY,
  nom         text NOT NULL UNIQUE,
  type        text NOT NULL,
  image_url   text NOT NULL DEFAULT '',
  reference   text NOT NULL DEFAULT ''
);

ALTER TABLE display_assets ENABLE ROW LEVEL SECURITY;

-- display_assets : lecture publique, écriture bloquée pour anon (via Netlify Function seulement)
CREATE POLICY "Public read display_assets"
  ON display_assets FOR SELECT
  TO anon
  USING (true);

-- État courant de l'écran d'affichage (ligne unique, éditée en direct depuis
-- Admin → Affichage, poussée en temps réel via Supabase Realtime).
CREATE TABLE IF NOT EXISTS display_state (
  id             bigserial PRIMARY KEY,
  background_id  bigint REFERENCES display_assets(id) ON DELETE SET NULL,
  background_url text,
  npc_ids        jsonb NOT NULL DEFAULT '[]'::jsonb,
  pokemon_ids    jsonb NOT NULL DEFAULT '[]'::jsonb,
  item_ids       jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO display_state (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

ALTER TABLE display_state ENABLE ROW LEVEL SECURITY;

-- Lecture + écriture publiques (édité en direct depuis l'onglet Admin, comme
-- admin_parameters/casino_config — app sans vraie sécurité)
CREATE POLICY "Public read display_state"
  ON display_state FOR SELECT TO anon USING (true);
CREATE POLICY "Public update display_state"
  ON display_state FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- Fouille (mini-jeu collaboratif de fouille sur grille partagée)
-- ============================================================

-- Objet "Ticket Fouille" du catalogue (le stock par joueur vit dans player_items,
-- comme Ticket Casino/Ticket Trempette/Pokédollar). RLS bloque l'écriture anon
-- sur items — cette ligne doit être insérée une fois via le SQL Editor.
INSERT INTO items (nom, type, achat, vente, description, image_url)
VALUES ('Ticket Fouille', 'Monnaie', 0, 0, 'Permet de creuser dans la zone de Fouille.', '/website_icons/icon_digging_ticket.png')
ON CONFLICT (nom) DO NOTHING;

-- Grilles personnalisées (créées à la main dans Admin → Fouille) : peuvent être
-- mises en file via mining_config.next_custom_grid_id pour forcer la prochaine
-- grille générée (consommée une fois, puis remise à NULL).
CREATE TABLE IF NOT EXISTS mining_custom_grids (
  id            bigserial PRIMARY KEY,
  nom           text NOT NULL,
  size          integer NOT NULL CHECK (size >= 2),
  move_budget   integer NOT NULL CHECK (move_budget >= 1),
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Objets placés sur une grille personnalisée. item_nom référence items.nom,
-- pas de FK (survit aux réimports CSV, comme le reste du catalogue). Pas de
-- contrainte de non-chevauchement en base (comme gift_lootbox_items) — l'éditeur
-- admin l'empêche côté client.
CREATE TABLE IF NOT EXISTS mining_custom_grid_items (
  id               bigserial PRIMARY KEY,
  custom_grid_id   bigint NOT NULL REFERENCES mining_custom_grids(id) ON DELETE CASCADE,
  item_nom         text NOT NULL,
  size             integer NOT NULL CHECK (size BETWEEN 1 AND 4),
  origin_row       integer NOT NULL,
  origin_col       integer NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mining_custom_grid_items_grid ON mining_custom_grid_items(custom_grid_id);

-- Paramètres admin de la Fouille (une seule ligne, id fixe = 1) — même schéma
-- que casino_config/minigames_config pour l'économie des tickets (Ticket Fouille,
-- indépendante du Casino et des Mini-Jeux) + réglages de génération procédurale.
CREATE TABLE IF NOT EXISTS mining_config (
  id                          bigint PRIMARY KEY DEFAULT 1,
  -- Économie des tickets
  ticket_max                  integer NOT NULL DEFAULT 3,
  ticket_regen_amount         integer NOT NULL DEFAULT 24,
  ticket_regen_unit           text NOT NULL DEFAULT 'hours' CHECK (ticket_regen_unit IN ('hours', 'minutes')),
  ticket_buy_cost             integer NOT NULL DEFAULT 0,
  ticket_daily_buy_cap        integer NOT NULL DEFAULT 3,
  ticket_full_notify_enabled  boolean NOT NULL DEFAULT false,
  -- Affichage
  nom                         text NOT NULL DEFAULT 'Fouille',
  icon_url                    text NOT NULL DEFAULT '/website_icons/icon_digging_game.png',
  banner_url                  text NOT NULL DEFAULT '',
  hidden_cell_image_url       text NOT NULL DEFAULT '',
  empty_cell_image_url        text NOT NULL DEFAULT '',
  -- Génération procédurale
  grid_size_min               integer NOT NULL DEFAULT 4,
  grid_size_max               integer NOT NULL DEFAULT 6,
  fill_ratio_pct              integer NOT NULL DEFAULT 20, -- % de cases occupées par des objets, visé (peut être légèrement dépassé)
  move_budget_pct             integer NOT NULL DEFAULT 50, -- % de cases de la grille consommables avant épuisement
  -- Grille personnalisée mise en file pour la prochaine génération (consommée une fois puis NULL)
  next_custom_grid_id         bigint REFERENCES mining_custom_grids(id) ON DELETE SET NULL,
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO mining_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- Bibliothèque d'objets pouvant apparaître sur une grille procédurale : chaque
-- entrée référence un objet du catalogue (item_nom), sa taille sur la grille
-- (toujours carrée, N×N) et son poids de tirage relatif (probabilité =
-- poids / somme des poids, même principe que casino_config/gift_lootbox_items).
CREATE TABLE IF NOT EXISTS mining_item_defs (
  id          bigserial PRIMARY KEY,
  item_nom    text NOT NULL,
  size        integer NOT NULL CHECK (size BETWEEN 1 AND 4),
  weight      integer NOT NULL DEFAULT 1,
  enabled     boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- État Fouille par joueur : minuteur du prochain ticket gratuit + suivi des
-- achats du jour — même schéma que casino_player_state/minigames_player_state.
CREATE TABLE IF NOT EXISTS mining_player_state (
  player_id             bigint PRIMARY KEY,
  next_ticket_at        timestamptz,
  purchase_count        integer NOT NULL DEFAULT 0,
  purchase_date         date,
  ticket_full_notified  boolean NOT NULL DEFAULT false,
  created_at            timestamptz NOT NULL DEFAULT now()
);

-- La grille en cours (une seule active à la fois, partagée par tous les joueurs).
-- Une ligne par grille jouée (l'historique des grilles passées est conservé,
-- is_active bascule à false + ended_at à la fin plutôt qu'une suppression).
CREATE TABLE IF NOT EXISTS mining_grids (
  id               bigserial PRIMARY KEY,
  size             integer NOT NULL,
  move_budget      integer NOT NULL,
  moves_used       integer NOT NULL DEFAULT 0,
  source           text NOT NULL CHECK (source IN ('procedural', 'custom')),
  custom_grid_id   bigint REFERENCES mining_custom_grids(id) ON DELETE SET NULL,
  is_active        boolean NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now(),
  ended_at         timestamptz
);
-- Une seule grille active à la fois — même idiome que gift_lootboxes.is_default
CREATE UNIQUE INDEX IF NOT EXISTS idx_mining_grids_one_active
  ON mining_grids (is_active) WHERE is_active = true;

-- Instances d'objets placés sur la grille active (ou une grille passée) : suit
-- combien de cases de l'objet restent à découvrir, et qui a creusé la dernière
-- (celui-ci reçoit l'objet dans son inventaire).
CREATE TABLE IF NOT EXISTS mining_grid_items (
  id                       bigserial PRIMARY KEY,
  grid_id                  bigint NOT NULL REFERENCES mining_grids(id) ON DELETE CASCADE,
  item_nom                 text NOT NULL,
  size                     integer NOT NULL CHECK (size BETWEEN 1 AND 4),
  origin_row               integer NOT NULL,
  origin_col               integer NOT NULL,
  cells_total              integer NOT NULL,
  cells_remaining          integer NOT NULL,
  completed                boolean NOT NULL DEFAULT false,
  completed_by_player_id   bigint,
  completed_at             timestamptz
);
CREATE INDEX IF NOT EXISTS idx_mining_grid_items_grid ON mining_grid_items(grid_id);

-- Une ligne par case de la grille (et non un blob JSON) : c'est ce qui rend les
-- fouilles simultanées de plusieurs joueurs sûres. Réclamer une case est un
-- UPDATE ... WHERE dug = false atomique sur SA PROPRE ligne — Postgres sérialise
-- les écritures concurrentes sur une même ligne automatiquement, et deux joueurs
-- qui creusent deux cases différentes ne se gênent jamais (lignes différentes).
-- Un blob JSON unique aurait forcé un cycle lecture-modification-écriture côté
-- client, réintroduisant exactement la course qu'on cherche à éviter.
CREATE TABLE IF NOT EXISTS mining_grid_cells (
  id                  bigserial PRIMARY KEY,
  grid_id             bigint NOT NULL REFERENCES mining_grids(id) ON DELETE CASCADE,
  cell_index          integer NOT NULL, -- 0-indexé, row-major : index = row*size + col
  item_id             bigint REFERENCES mining_grid_items(id) ON DELETE SET NULL, -- NULL = case vide
  dug                 boolean NOT NULL DEFAULT false,
  dug_by_player_id    bigint,
  dug_at              timestamptz,
  UNIQUE (grid_id, cell_index)
);
CREATE INDEX IF NOT EXISTS idx_mining_grid_cells_grid ON mining_grid_cells(grid_id);

-- Journal des coups joués sur la grille active, affiché en direct dans le popup
-- Fouille (sous la grille) — distinct de mining_grid_cells pour rester un simple
-- flux append-only (même philosophie que history_events), et distinct de
-- history_events global : seuls les objets complétés sont aussi loggés dans
-- history_events (voir mining_dig_cell ci-dessous), pas chaque case creusée.
CREATE TABLE IF NOT EXISTS mining_moves (
  id                bigserial PRIMARY KEY,
  grid_id           bigint NOT NULL REFERENCES mining_grids(id) ON DELETE CASCADE,
  player_id         bigint NOT NULL,
  cell_index        integer NOT NULL,
  item_id           bigint REFERENCES mining_grid_items(id) ON DELETE SET NULL,
  item_completed    boolean NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mining_moves_grid_created ON mining_moves(grid_id, created_at);

ALTER TABLE mining_custom_grids ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_custom_grid_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_item_defs ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_player_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_grids ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_grid_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_grid_cells ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_moves ENABLE ROW LEVEL SECURITY;

-- Lecture + écriture publiques partout (app sans vraie sécurité, comme le reste
-- du schéma). Les fonctions RPC ci-dessous s'exécutent avec le rôle appelant
-- (anon), pas en SECURITY DEFINER — elles ont donc besoin de ces mêmes policies.
CREATE POLICY "Public read mining_custom_grids"
  ON mining_custom_grids FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert mining_custom_grids"
  ON mining_custom_grids FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update mining_custom_grids"
  ON mining_custom_grids FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete mining_custom_grids"
  ON mining_custom_grids FOR DELETE TO anon USING (true);

CREATE POLICY "Public read mining_custom_grid_items"
  ON mining_custom_grid_items FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert mining_custom_grid_items"
  ON mining_custom_grid_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update mining_custom_grid_items"
  ON mining_custom_grid_items FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete mining_custom_grid_items"
  ON mining_custom_grid_items FOR DELETE TO anon USING (true);

CREATE POLICY "Public read mining_config"
  ON mining_config FOR SELECT TO anon USING (true);
CREATE POLICY "Public update mining_config"
  ON mining_config FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read mining_item_defs"
  ON mining_item_defs FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert mining_item_defs"
  ON mining_item_defs FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update mining_item_defs"
  ON mining_item_defs FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete mining_item_defs"
  ON mining_item_defs FOR DELETE TO anon USING (true);

CREATE POLICY "Public read mining_player_state"
  ON mining_player_state FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert mining_player_state"
  ON mining_player_state FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update mining_player_state"
  ON mining_player_state FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read mining_grids"
  ON mining_grids FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert mining_grids"
  ON mining_grids FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update mining_grids"
  ON mining_grids FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read mining_grid_items"
  ON mining_grid_items FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert mining_grid_items"
  ON mining_grid_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update mining_grid_items"
  ON mining_grid_items FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read mining_grid_cells"
  ON mining_grid_cells FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert mining_grid_cells"
  ON mining_grid_cells FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update mining_grid_cells"
  ON mining_grid_cells FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read mining_moves"
  ON mining_moves FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert mining_moves"
  ON mining_moves FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update mining_moves"
  ON mining_moves FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- ── Fonctions RPC de concurrence ────────────────────────────────
-- Première utilisation de fonctions Postgres côté serveur dans ce schéma —
-- justifié ici uniquement : Fouille est la première fonctionnalité où deux
-- clients indépendants et non authentifiés peuvent légitimement se disputer
-- la même ligne en même temps (une case de grille, un compteur d'objet), et
-- un cycle lecture-modification-écriture multi-étapes côté client ne peut pas
-- être rendu atomique autrement. Les deux fonctions s'exécutent avec le rôle
-- appelant (anon), pas en SECURITY DEFINER, pour rester cohérentes avec la
-- posture "pas de vraie sécurité" du reste de l'app.

-- Retourne l'id de la grille active, en la générant si besoin (aucune grille
-- active, ou grille active épuisée). p_procedural est un layout candidat déjà
-- calculé côté client (voir src/lib/mining.ts::generateProceduralGridLayout) —
-- il n'est utilisé que si aucune grille personnalisée n'est en file d'attente ;
-- sinon il est simplement ignoré (travail JS perdu, sans conséquence).
--
-- pg_advisory_xact_lock sérialise tous les appels concurrents à cette fonction
-- pour la durée de la transaction : ça élimine à la fois la course au tout
-- premier lancement (aucune grille n'existe encore) et la course au
-- renouvellement (la grille active vient de s'épuiser) sans logique de retry —
-- le second appelant, une fois le verrou obtenu, voit simplement la grille déjà
-- fraîchement créée par le premier et la retourne telle quelle.
CREATE OR REPLACE FUNCTION mining_ensure_active_grid(p_procedural jsonb)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
  v_grid_id      bigint;
  v_moves_used   integer;
  v_move_budget  integer;
  v_cleared      boolean;
  v_size         integer;
  v_custom_id    bigint;
  v_source       text;
  v_items        jsonb;
  v_item         jsonb;
  v_item_id      bigint;
  v_item_size    integer;
  v_origin_row   integer;
  v_origin_col   integer;
  v_row          integer;
  v_col          integer;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('mining_grid_generation'));

  SELECT id, moves_used, move_budget INTO v_grid_id, v_moves_used, v_move_budget
  FROM mining_grids WHERE is_active = true FOR UPDATE;

  -- "Terminée" = coups épuisés OU (au moins un objet placé ET tous complétés)
  -- — même condition que côté client (isGridCleared) et que la garde de
  -- mining_dig_cell, pour rester cohérent quel que soit qui déclenche le
  -- renouvellement (le joueur qui vide la grille vs. un tiers via Realtime).
  SELECT EXISTS (SELECT 1 FROM mining_grid_items WHERE grid_id = v_grid_id)
    AND NOT EXISTS (SELECT 1 FROM mining_grid_items WHERE grid_id = v_grid_id AND completed = false)
  INTO v_cleared;

  IF v_grid_id IS NOT NULL AND v_moves_used < v_move_budget AND NOT v_cleared THEN
    RETURN v_grid_id;
  END IF;

  IF v_grid_id IS NOT NULL THEN
    UPDATE mining_grids SET is_active = false, ended_at = now() WHERE id = v_grid_id;
  END IF;

  SELECT next_custom_grid_id INTO v_custom_id FROM mining_config WHERE id = 1;
  IF v_custom_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM mining_custom_grids WHERE id = v_custom_id) THEN
    v_custom_id := NULL;
  END IF;

  IF v_custom_id IS NOT NULL THEN
    v_source := 'custom';
    SELECT size, move_budget INTO v_size, v_move_budget FROM mining_custom_grids WHERE id = v_custom_id;
    SELECT COALESCE(jsonb_agg(jsonb_build_object('item_nom', item_nom, 'size', size, 'origin_row', origin_row, 'origin_col', origin_col)), '[]'::jsonb)
      INTO v_items
      FROM mining_custom_grid_items WHERE custom_grid_id = v_custom_id;
    UPDATE mining_config SET next_custom_grid_id = NULL WHERE id = 1;
  ELSE
    v_source := 'procedural';
    v_custom_id := NULL;
    v_size := (p_procedural->>'size')::int;
    v_move_budget := (p_procedural->>'move_budget')::int;
    v_items := COALESCE(p_procedural->'items', '[]'::jsonb);
  END IF;

  INSERT INTO mining_grids (size, move_budget, source, custom_grid_id, is_active)
  VALUES (v_size, v_move_budget, v_source, v_custom_id, true)
  RETURNING id INTO v_grid_id;

  INSERT INTO mining_grid_cells (grid_id, cell_index)
  SELECT v_grid_id, gs FROM generate_series(0, v_size * v_size - 1) AS gs;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_items)
  LOOP
    v_item_size := (v_item->>'size')::int;
    v_origin_row := (v_item->>'origin_row')::int;
    v_origin_col := (v_item->>'origin_col')::int;

    INSERT INTO mining_grid_items (grid_id, item_nom, size, origin_row, origin_col, cells_total, cells_remaining)
    VALUES (v_grid_id, v_item->>'item_nom', v_item_size, v_origin_row, v_origin_col, v_item_size * v_item_size, v_item_size * v_item_size)
    RETURNING id INTO v_item_id;

    FOR v_row IN 0..(v_item_size - 1) LOOP
      FOR v_col IN 0..(v_item_size - 1) LOOP
        UPDATE mining_grid_cells
        SET item_id = v_item_id
        WHERE grid_id = v_grid_id
          AND cell_index = (v_origin_row + v_row) * v_size + (v_origin_col + v_col);
      END LOOP;
    END LOOP;
  END LOOP;

  RETURN v_grid_id;
END;
$$;

-- Creuse une case pour un joueur : atomique de bout en bout. Consomme un coup
-- (échoue proprement si la grille est épuisée — coups à zéro OU tous les
-- objets déjà trouvés — ou n'est plus active), réclame la case (échoue
-- proprement si un autre joueur vient de la creuser, et rembourse alors le
-- coup consommé), puis si la case appartenait à un objet, décrémente
-- son compteur de cases restantes — le seul appel qui fait passer ce compteur
-- de 1 à 0 est, par construction (verrouillage de ligne Postgres), celui qui
-- reçoit item_completed=true et crédite l'objet dans l'inventaire du joueur.
-- L'historique global (history_events) n'est PAS écrit ici — c'est fait côté
-- client (voir PLAYER_HISTORY_LOGGING.md), uniquement quand item_completed=true.
CREATE OR REPLACE FUNCTION mining_dig_cell(p_grid_id bigint, p_player_id bigint, p_cell_index integer)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_item_id         bigint;
  v_move_id         bigint;
  v_cells_remaining integer;
  v_item_nom        text;
BEGIN
  UPDATE mining_grids
  SET moves_used = moves_used + 1
  WHERE id = p_grid_id AND is_active = true AND moves_used < move_budget
    AND (
      NOT EXISTS (SELECT 1 FROM mining_grid_items WHERE grid_id = p_grid_id)
      OR EXISTS (SELECT 1 FROM mining_grid_items WHERE grid_id = p_grid_id AND completed = false)
    );

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'grid_exhausted');
  END IF;

  UPDATE mining_grid_cells
  SET dug = true, dug_by_player_id = p_player_id, dug_at = now()
  WHERE grid_id = p_grid_id AND cell_index = p_cell_index AND dug = false
  RETURNING item_id INTO v_item_id;

  IF NOT FOUND THEN
    UPDATE mining_grids SET moves_used = moves_used - 1 WHERE id = p_grid_id;
    RETURN jsonb_build_object('status', 'already_dug');
  END IF;

  INSERT INTO mining_moves (grid_id, player_id, cell_index, item_id, item_completed)
  VALUES (p_grid_id, p_player_id, p_cell_index, v_item_id, false)
  RETURNING id INTO v_move_id;

  IF v_item_id IS NULL THEN
    RETURN jsonb_build_object('status', 'ok', 'item_completed', false);
  END IF;

  UPDATE mining_grid_items
  SET cells_remaining = cells_remaining - 1
  WHERE id = v_item_id AND cells_remaining > 0
  RETURNING cells_remaining, item_nom INTO v_cells_remaining, v_item_nom;

  IF NOT FOUND OR v_cells_remaining > 0 THEN
    RETURN jsonb_build_object('status', 'ok', 'item_completed', false);
  END IF;

  UPDATE mining_grid_items
  SET completed = true, completed_by_player_id = p_player_id, completed_at = now()
  WHERE id = v_item_id;

  UPDATE mining_moves SET item_completed = true WHERE id = v_move_id;

  INSERT INTO player_items (player_id, item_nom, quantity)
  VALUES (p_player_id, v_item_nom, 1)
  ON CONFLICT (player_id, item_nom) DO UPDATE SET quantity = player_items.quantity + 1;

  RETURN jsonb_build_object('status', 'ok', 'item_completed', true, 'item_nom', v_item_nom);
END;
$$;

GRANT EXECUTE ON FUNCTION mining_ensure_active_grid(jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mining_dig_cell(bigint, bigint, integer) TO anon, authenticated;

-- Diffusion Realtime : contrairement aux tables plus anciennes de ce schéma
-- (déjà membres de la publication supabase_realtime, activées à la création via
-- le Dashboard), ces tables neuves doivent y être ajoutées explicitement, sinon
-- les hooks useMining*/useMiningActiveGrid ne reçoivent aucune mise à jour en
-- direct (les écritures persistent bien côté serveur, mais un client déjà ouvert
-- ne les voit qu'au prochain remount/refetch). Bloc idempotent (sûr à ré-exécuter).
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'mining_config', 'mining_player_state', 'mining_item_defs',
    'mining_custom_grids', 'mining_custom_grid_items',
    'mining_grids', 'mining_grid_items', 'mining_grid_cells', 'mining_moves'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', t);
    END IF;
  END LOOP;
END $$;

-- ============================================================
-- Pension Pokémon (garderie) — chaque joueur peut y placer 1 pokémon de son PC
-- (jamais de l'équipe), qui gagne de l'XP dans le temps (même compteur
-- player_pokemon.xp que partout ailleurs, donc compatible avec les paliers
-- d'évolution existants) jusqu'à un plafond cumulatif À VIE par instance.
-- Deux pokémon d'un même "groupe d'œufs" (importé par CSV, voir
-- pokemon_egg_groups) présents en même temps produisent un œuf après une
-- durée aléatoire — voir pension_recompute_pairs()/pension_pairs plus bas.
-- ============================================================

ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS in_daycare boolean NOT NULL DEFAULT false;
ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS daycare_placed_at timestamptz;
ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS daycare_last_tick_at timestamptz;
ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS daycare_lifetime_xp integer NOT NULL DEFAULT 0;
ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS daycare_capped boolean NOT NULL DEFAULT false;
ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS daycare_capped_notified boolean NOT NULL DEFAULT false;
-- Instantané de xp au moment du placement (rempli par pension_place) — sert à
-- calculer combien d'XP a été gagnée PENDANT ce séjour précis (xp - ce champ),
-- affiché au joueur à la récupération (voir PensionRetrievedPopup).
ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS daycare_xp_at_placement integer;
-- false uniquement pour un œuf fraîchement produit par pension-tick.js ; le
-- joueur voit alors PensionEggRevealPopup à la prochaine ouverture de la
-- pension, qui remet ce champ à true (voir PensionPopup::unseenEgg). true
-- par défaut pour tout le reste (achats normaux, imports, etc.) — pas de
-- popup à afficher rétroactivement pour les lignes existantes.
ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS egg_reveal_seen boolean NOT NULL DEFAULT true;

-- Combats gagnés par CETTE instance précise (pas l'espèce) — conservé tel
-- quel à travers les évolutions puisque player_pokemon.id ne change jamais
-- lors d'une évolution (seul pokemon_nom est mis à jour). Incrémenté
-- uniquement sur victoire en Combat Auto (auto ET manuel), jamais en PvP (le
-- pokémon défenseur n'est qu'un instantané de pvp_challenges, pas une ligne
-- player_pokemon vivante référencée dans pvp_resolve_round).
ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS battles_won integer NOT NULL DEFAULT 0;

ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_pension_enabled boolean NOT NULL DEFAULT true;

-- Paramètres admin de la Pension (une seule ligne, id fixe = 1) — même schéma
-- que mining_config/casino_config. Pas d'économie de tickets ici (accès
-- gratuit, contrôlé uniquement par admin_parameters.feature_pension_enabled).
-- default_hatch_timer_* sert de repli pour tout groupe sans ligne
-- pension_group_config dédiée (voir pension_recompute_pairs).
CREATE TABLE IF NOT EXISTS pension_config (
  id                        bigint PRIMARY KEY DEFAULT 1,
  nom                       text NOT NULL DEFAULT 'Pension Pokémon',
  icon_url                  text NOT NULL DEFAULT '/website_icons/icon_daycare_game.png',
  banner_url                text NOT NULL DEFAULT '',
  capacity_total            integer NOT NULL DEFAULT 3,
  tick_xp_amount            integer NOT NULL DEFAULT 1,
  tick_interval_amount      integer NOT NULL DEFAULT 2,
  tick_interval_unit        text NOT NULL DEFAULT 'hours' CHECK (tick_interval_unit IN ('hours', 'minutes')),
  default_lifetime_xp_cap   integer NOT NULL DEFAULT 50,
  default_hatch_timer_min   integer NOT NULL DEFAULT 24,
  default_hatch_timer_max   integer NOT NULL DEFAULT 48,
  default_hatch_timer_unit  text NOT NULL DEFAULT 'hours' CHECK (default_hatch_timer_unit IN ('hours', 'minutes')),
  info_text                 text NOT NULL DEFAULT $def$Chaque dresseur ne peut avoir qu'un pokémon en pension.
Il y a des limites d'expérience cumulable en pension.
Les pokémon de dresseurs différents peuvent produire des œufs s'ils sont compatibles — dans ce cas, l'œuf est donné à l'un des deux dresseurs, au hasard.
Les œufs reçus peuvent contenir tout type de pokémon, la dame de la pension s'amuse à les mélanger pour faire des surprises aux dresseurs !$def$,
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO pension_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
-- Texte du popup "Comment fonctionne la Pension ?", désormais paramétrable
-- en admin (voir AdminPensionConfigPanel) plutôt que codé en dur dans
-- PensionInfoPopup. Une ligne = une puce.
ALTER TABLE pension_config ADD COLUMN IF NOT EXISTS info_text text NOT NULL DEFAULT $def$Chaque dresseur ne peut avoir qu'un pokémon en pension.
Il y a des limites d'expérience cumulable en pension.
Les pokémon de dresseurs différents peuvent produire des œufs s'ils sont compatibles — dans ce cas, l'œuf est donné à l'un des deux dresseurs, au hasard.
Les œufs reçus peuvent contenir tout type de pokémon, la dame de la pension s'amuse à les mélanger pour faire des surprises aux dresseurs !$def$;

-- Groupes d'œufs par espèce — importé par CSV (colonnes Pokémon/Groupe 1/Groupe
-- 2/Groupe 3), jusqu'à 3 lignes par espèce. Référence par nom, pas de FK (survit
-- aux réimports, comme pokemon_evolutions). Les valeurs "ALL"/"TOUS"
-- (insensible à la casse) désignent un groupe spécial "universel" (ex : Métamorph)
-- qui peut se reproduire avec n'importe quel autre pokémon ayant un groupe réel —
-- voir pension_recompute_pairs.
CREATE TABLE IF NOT EXISTS pokemon_egg_groups (
  id           bigserial PRIMARY KEY,
  pokemon_nom  text NOT NULL,
  groupe       text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pokemon_egg_groups_pokemon_nom ON pokemon_egg_groups(pokemon_nom);
CREATE INDEX IF NOT EXISTS idx_pokemon_egg_groups_groupe ON pokemon_egg_groups(groupe);

-- Réglages admin par groupe d'œufs — clé primaire = nom du groupe (texte libre
-- venu du CSV). Purement dédié à l'éclosion : hatch_timer_* (NULL = hérite des
-- valeurs par défaut de pension_config) + egg_pool_mode. Les réglages XP
-- (intervalle de tick, plafond à vie) sont un concept séparé, voir
-- pension_xp_groups plus bas — pas de rapport avec les groupes d'œufs. Créée à
-- la volée côté client (usePensionGroups) au premier groupe découvert dans
-- pokemon_egg_groups.
CREATE TABLE IF NOT EXISTS pension_group_config (
  groupe                text PRIMARY KEY,
  hatch_timer_min        integer,
  hatch_timer_max        integer,
  hatch_timer_unit       text CHECK (hatch_timer_unit IN ('hours', 'minutes')),
  created_at             timestamptz NOT NULL DEFAULT now()
);
-- Migration si la table existait déjà avec l'ancien schéma (groupes XP fusionnés
-- avec les groupes d'œufs) :
ALTER TABLE pension_group_config DROP COLUMN IF EXISTS tick_interval_amount;
ALTER TABLE pension_group_config DROP COLUMN IF EXISTS tick_interval_unit;
ALTER TABLE pension_group_config DROP COLUMN IF EXISTS lifetime_xp_cap;

-- Groupes XP — entièrement indépendants des groupes d'œufs : créés et peuplés
-- à la main par l'admin (pas de CSV), une espèce appartient à au plus un
-- groupe XP (pension_xp_group_species, clé primaire = pokemon_nom). Toute
-- espèce non assignée utilise les valeurs par défaut de pension_config
-- (tick_interval_amount/unit, default_lifetime_xp_cap).
CREATE TABLE IF NOT EXISTS pension_xp_groups (
  id                    bigserial PRIMARY KEY,
  nom                   text NOT NULL UNIQUE,
  tick_interval_amount  integer NOT NULL DEFAULT 2,
  tick_interval_unit    text NOT NULL DEFAULT 'hours' CHECK (tick_interval_unit IN ('hours', 'minutes')),
  lifetime_xp_cap       integer NOT NULL DEFAULT 50,
  created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pension_xp_group_species (
  pokemon_nom  text PRIMARY KEY,
  xp_group_id  bigint NOT NULL REFERENCES pension_xp_groups(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pension_xp_group_species_group ON pension_xp_group_species(xp_group_id);

ALTER TABLE pension_xp_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE pension_xp_group_species ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read pension_xp_groups"
  ON pension_xp_groups FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert pension_xp_groups"
  ON pension_xp_groups FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update pension_xp_groups"
  ON pension_xp_groups FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete pension_xp_groups"
  ON pension_xp_groups FOR DELETE TO anon USING (true);

CREATE POLICY "Public read pension_xp_group_species"
  ON pension_xp_group_species FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert pension_xp_group_species"
  ON pension_xp_group_species FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update pension_xp_group_species"
  ON pension_xp_group_species FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete pension_xp_group_species"
  ON pension_xp_group_species FOR DELETE TO anon USING (true);

-- Réserve pondérée d'espèces "œuf" par groupe (même principe que
-- gift_lootbox_items : probabilité = poids / somme des poids). Une espèce n'est
-- "un œuf" que par le fait d'être listée ici — pas de colonne booléenne dédiée
-- sur `pokemon`.
CREATE TABLE IF NOT EXISTS pension_egg_pool (
  id           bigserial PRIMARY KEY,
  groupe       text NOT NULL,
  pokemon_nom  text NOT NULL,
  weight       integer NOT NULL DEFAULT 1,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pension_egg_pool_groupe ON pension_egg_pool(groupe);

-- Appariements en cours pour la production d'œufs. Une paire = 2 pokémon en
-- pension partageant un groupe (ou l'un des deux ayant le groupe spécial
-- ALL/TOUS), avec une durée cible tirée aléatoirement une seule fois à la
-- création de la paire (voir pension_recompute_pairs). pokemon_a_id < pokemon_b_id
-- donne un ordre canonique (pas de doublon A-B/B-A). L'index unique inclut
-- `groupe` : deux instances partageant plusieurs groupes ont une paire (et donc
-- un minuteur d'œuf) indépendante par groupe partagé.
-- fixed_recipient_pokemon_id : non-NULL uniquement pour un appariement
-- impliquant ALL/TOUS — l'œuf va alors toujours au propriétaire de CE pokémon
-- (l'autre, non-ALL), jamais un tirage 50/50.
CREATE TABLE IF NOT EXISTS pension_pairs (
  id                          bigserial PRIMARY KEY,
  pokemon_a_id                bigint NOT NULL REFERENCES player_pokemon(id) ON DELETE CASCADE,
  pokemon_b_id                bigint NOT NULL REFERENCES player_pokemon(id) ON DELETE CASCADE,
  groupe                      text NOT NULL,
  fixed_recipient_pokemon_id  bigint REFERENCES player_pokemon(id) ON DELETE CASCADE,
  paired_since                timestamptz NOT NULL DEFAULT now(),
  target_duration_seconds     integer NOT NULL,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  CHECK (pokemon_a_id < pokemon_b_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_pension_pairs_unique ON pension_pairs(pokemon_a_id, pokemon_b_id, groupe);

ALTER TABLE pension_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE pokemon_egg_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE pension_group_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE pension_egg_pool ENABLE ROW LEVEL SECURITY;
ALTER TABLE pension_pairs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read pension_config"
  ON pension_config FOR SELECT TO anon USING (true);
CREATE POLICY "Public update pension_config"
  ON pension_config FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- pokemon_egg_groups : lecture publique, écriture bloquée pour anon (import CSV
-- via Netlify Function seulement, comme pokemon_evolutions/encounters)
CREATE POLICY "Public read pokemon_egg_groups"
  ON pokemon_egg_groups FOR SELECT TO anon USING (true);

CREATE POLICY "Public read pension_group_config"
  ON pension_group_config FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert pension_group_config"
  ON pension_group_config FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update pension_group_config"
  ON pension_group_config FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read pension_egg_pool"
  ON pension_egg_pool FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert pension_egg_pool"
  ON pension_egg_pool FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update pension_egg_pool"
  ON pension_egg_pool FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete pension_egg_pool"
  ON pension_egg_pool FOR DELETE TO anon USING (true);

CREATE POLICY "Public read pension_pairs"
  ON pension_pairs FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert pension_pairs"
  ON pension_pairs FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update pension_pairs"
  ON pension_pairs FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete pension_pairs"
  ON pension_pairs FOR DELETE TO anon USING (true);

-- ── Fonctions RPC de concurrence ────────────────────────────────
-- Même justification que mining_ensure_active_grid/mining_dig_cell : plusieurs
-- clients anon peuvent se disputer les dernières places de la pension en même
-- temps. Rôle appelant (anon), pas SECURITY DEFINER, cohérent avec le reste du schéma.

-- Recalcule les appariements actifs après chaque place/retrait. Supprime les
-- paires dont un membre est parti, puis recrée les paires manquantes pour
-- chaque combinaison de 2 pokémon en pension : un groupe partagé (hors
-- ALL/TOUS) = une paire par groupe partagé ; un pokémon ALL/TOUS face à un
-- pokémon ayant ≥1 groupe réel = une paire dont le groupe résolu est tiré au
-- hasard une seule fois parmi les groupes réels de l'autre, avec un
-- destinataire d'œuf fixé sur ce dernier ; deux ALL/TOUS ensemble ne
-- s'apparient jamais.
CREATE OR REPLACE FUNCTION pension_recompute_pairs() RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  rec RECORD;
  v_a_groups text[];
  v_b_groups text[];
  v_a_is_all boolean;
  v_b_is_all boolean;
  v_shared text[];
  g text;
  v_resolved_groupe text;
  v_fixed_recipient bigint;
  v_hatch_min integer;
  v_hatch_max integer;
  v_hatch_unit text;
  v_target_seconds integer;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('pension_pairs'));

  DELETE FROM pension_pairs pp
  WHERE NOT EXISTS (SELECT 1 FROM player_pokemon a WHERE a.id = pp.pokemon_a_id AND a.in_daycare = true)
     OR NOT EXISTS (SELECT 1 FROM player_pokemon b WHERE b.id = pp.pokemon_b_id AND b.in_daycare = true);

  FOR rec IN
    SELECT a.id AS a_id, a.pokemon_nom AS a_nom, b.id AS b_id, b.pokemon_nom AS b_nom
    FROM player_pokemon a
    JOIN player_pokemon b ON b.id > a.id AND b.in_daycare = true
    WHERE a.in_daycare = true
  LOOP
    SELECT COALESCE(array_agg(groupe), '{}') INTO v_a_groups FROM pokemon_egg_groups WHERE pokemon_nom = rec.a_nom;
    SELECT COALESCE(array_agg(groupe), '{}') INTO v_b_groups FROM pokemon_egg_groups WHERE pokemon_nom = rec.b_nom;
    v_a_is_all := EXISTS (SELECT 1 FROM unnest(v_a_groups) x WHERE lower(trim(x)) IN ('all', 'tous'));
    v_b_is_all := EXISTS (SELECT 1 FROM unnest(v_b_groups) x WHERE lower(trim(x)) IN ('all', 'tous'));

    IF v_a_is_all AND v_b_is_all THEN
      CONTINUE;
    ELSIF v_a_is_all OR v_b_is_all THEN
      IF v_a_is_all THEN
        SELECT x INTO v_resolved_groupe FROM unnest(v_b_groups) x
          WHERE lower(trim(x)) NOT IN ('all', 'tous') ORDER BY random() LIMIT 1;
        v_fixed_recipient := rec.b_id;
      ELSE
        SELECT x INTO v_resolved_groupe FROM unnest(v_a_groups) x
          WHERE lower(trim(x)) NOT IN ('all', 'tous') ORDER BY random() LIMIT 1;
        v_fixed_recipient := rec.a_id;
      END IF;

      IF v_resolved_groupe IS NULL THEN
        CONTINUE;
      END IF;

      IF EXISTS (SELECT 1 FROM pension_pairs WHERE pokemon_a_id = rec.a_id AND pokemon_b_id = rec.b_id AND groupe = v_resolved_groupe) THEN
        CONTINUE;
      END IF;

      SELECT hatch_timer_min, hatch_timer_max, hatch_timer_unit INTO v_hatch_min, v_hatch_max, v_hatch_unit
        FROM pension_group_config WHERE groupe = v_resolved_groupe;
      IF v_hatch_min IS NULL THEN
        SELECT default_hatch_timer_min, default_hatch_timer_max, default_hatch_timer_unit
          INTO v_hatch_min, v_hatch_max, v_hatch_unit FROM pension_config WHERE id = 1;
      END IF;
      v_target_seconds := GREATEST(1, (v_hatch_min + random() * GREATEST(0, v_hatch_max - v_hatch_min)) * (CASE WHEN v_hatch_unit = 'minutes' THEN 60 ELSE 3600 END))::int;

      INSERT INTO pension_pairs (pokemon_a_id, pokemon_b_id, groupe, fixed_recipient_pokemon_id, paired_since, target_duration_seconds)
      VALUES (rec.a_id, rec.b_id, v_resolved_groupe, v_fixed_recipient, now(), v_target_seconds);
    ELSE
      SELECT array_agg(x) INTO v_shared
      FROM (
        SELECT unnest(v_a_groups) AS x
        INTERSECT
        SELECT unnest(v_b_groups)
      ) s
      WHERE lower(trim(x)) NOT IN ('all', 'tous');

      IF v_shared IS NOT NULL THEN
        FOREACH g IN ARRAY v_shared LOOP
          IF EXISTS (SELECT 1 FROM pension_pairs WHERE pokemon_a_id = rec.a_id AND pokemon_b_id = rec.b_id AND groupe = g) THEN
            CONTINUE;
          END IF;

          SELECT hatch_timer_min, hatch_timer_max, hatch_timer_unit INTO v_hatch_min, v_hatch_max, v_hatch_unit
            FROM pension_group_config WHERE groupe = g;
          IF v_hatch_min IS NULL THEN
            SELECT default_hatch_timer_min, default_hatch_timer_max, default_hatch_timer_unit
              INTO v_hatch_min, v_hatch_max, v_hatch_unit FROM pension_config WHERE id = 1;
          END IF;
          v_target_seconds := GREATEST(1, (v_hatch_min + random() * GREATEST(0, v_hatch_max - v_hatch_min)) * (CASE WHEN v_hatch_unit = 'minutes' THEN 60 ELSE 3600 END))::int;

          INSERT INTO pension_pairs (pokemon_a_id, pokemon_b_id, groupe, fixed_recipient_pokemon_id, paired_since, target_duration_seconds)
          VALUES (rec.a_id, rec.b_id, g, NULL, now(), v_target_seconds);
        END LOOP;
      END IF;
    END IF;
  END LOOP;
END;
$$;

-- Place un pokémon du PC d'un joueur en pension : valide propriété / pas déjà en
-- équipe / pas déjà en pension / jamais atteint son plafond XP à vie / le joueur
-- n'a pas déjà un pokémon en pension / la pension n'est pas pleine, puis
-- recalcule les appariements. pg_advisory_xact_lock sérialise la course à la
-- dernière place disponible entre clients anon concurrents.
CREATE OR REPLACE FUNCTION pension_place(p_player_pokemon_id bigint, p_player_id bigint)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_owner bigint;
  v_in_team boolean;
  v_in_daycare boolean;
  v_capped boolean;
  v_xp integer;
  v_capacity integer;
  v_current_count integer;
  v_player_has_slot integer;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('pension_slots'));

  SELECT player_id, in_team, in_daycare, daycare_capped, xp
    INTO v_owner, v_in_team, v_in_daycare, v_capped, v_xp
    FROM player_pokemon WHERE id = p_player_pokemon_id FOR UPDATE;

  IF v_owner IS NULL OR v_owner <> p_player_id THEN RETURN jsonb_build_object('status', 'not_owner'); END IF;
  IF v_in_team THEN RETURN jsonb_build_object('status', 'must_be_in_pc'); END IF;
  IF v_in_daycare THEN RETURN jsonb_build_object('status', 'already_placed'); END IF;
  IF v_capped THEN RETURN jsonb_build_object('status', 'permanently_capped'); END IF;

  SELECT count(*) INTO v_player_has_slot FROM player_pokemon WHERE player_id = p_player_id AND in_daycare = true;
  IF v_player_has_slot > 0 THEN RETURN jsonb_build_object('status', 'player_slot_taken'); END IF;

  SELECT capacity_total INTO v_capacity FROM pension_config WHERE id = 1;
  SELECT count(*) INTO v_current_count FROM player_pokemon WHERE in_daycare = true;
  IF v_current_count >= v_capacity THEN RETURN jsonb_build_object('status', 'daycare_full'); END IF;

  UPDATE player_pokemon
  SET in_daycare = true, daycare_placed_at = now(), daycare_last_tick_at = now(), daycare_xp_at_placement = v_xp
  WHERE id = p_player_pokemon_id;

  PERFORM pension_recompute_pairs();
  RETURN jsonb_build_object('status', 'ok');
END;
$$;

-- Retire un pokémon de la pension : valide propriété / actuellement en pension,
-- puis recalcule les appariements (toute paire impliquant ce pokémon perd sa
-- progression, conformément à la règle "retrait = remise à zéro de la paire").
CREATE OR REPLACE FUNCTION pension_retrieve(p_player_pokemon_id bigint, p_player_id bigint)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_owner bigint;
  v_in_daycare boolean;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('pension_slots'));

  SELECT player_id, in_daycare INTO v_owner, v_in_daycare
    FROM player_pokemon WHERE id = p_player_pokemon_id FOR UPDATE;

  IF v_owner IS NULL OR v_owner <> p_player_id THEN RETURN jsonb_build_object('status', 'not_owner'); END IF;
  IF NOT v_in_daycare THEN RETURN jsonb_build_object('status', 'not_placed'); END IF;

  UPDATE player_pokemon
  SET in_daycare = false, daycare_placed_at = NULL, daycare_last_tick_at = NULL
  WHERE id = p_player_pokemon_id;

  PERFORM pension_recompute_pairs();
  RETURN jsonb_build_object('status', 'ok');
END;
$$;

GRANT EXECUTE ON FUNCTION pension_recompute_pairs() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION pension_place(bigint, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION pension_retrieve(bigint, bigint) TO anon, authenticated;

-- history_events.category doit accepter la nouvelle catégorie 'daycare'
-- (événements dépôt/retrait/œuf reçu à la Pension)
ALTER TABLE history_events DROP CONSTRAINT IF EXISTS history_events_category_check;
ALTER TABLE history_events ADD CONSTRAINT history_events_category_check
  CHECK (category IN ('inventory', 'pokedex', 'team', 'combat', 'minigame', 'daycare'));

-- Diffusion Realtime — mêmes raisons que le bloc Fouille ci-dessus
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'pension_config', 'pokemon_egg_groups', 'pension_group_config',
    'pension_egg_pool', 'pension_pairs', 'pension_xp_groups', 'pension_xp_group_species'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', t);
    END IF;
  END LOOP;
END $$;

-- Mode de réserve d'œufs par groupe : 'default' (hérite de la réserve par
-- défaut, groupe sentinelle '__default__' dans pension_egg_pool), 'custom'
-- (réserve propre à ce groupe) ou 'none' (ce groupe ne produit jamais d'œuf,
-- même si la réserve par défaut n'est pas vide) — voir pension-tick.js::resolveEggPool.
ALTER TABLE pension_group_config ADD COLUMN IF NOT EXISTS egg_pool_mode text NOT NULL DEFAULT 'default' CHECK (egg_pool_mode IN ('default', 'custom', 'none'));

-- ============================================================
-- Safari (mini-jeu collaboratif : une session partagée de 3 pokémon sauvages,
-- chacun avec sa propre jauge de capture 0-100 ; tous les joueurs voient la
-- même session et les mêmes jauges en direct, mais Baie Framby/Safari Ball
-- sont un inventaire individuel par joueur, comme Ticket Fouille/Pokédollar).
-- Les objets "Baie Framby"/"Safari Ball" existent déjà dans la table items
-- (ajoutés à la main par l'admin) — pas d'INSERT de seed ici, contrairement à
-- Ticket Fouille.
-- ============================================================

ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_safari_enabled boolean NOT NULL DEFAULT true;

-- Paramètres admin du Safari (une seule ligne, id fixe = 1) — même schéma que
-- mining_config/pension_config. Contrairement à Fouille (un seul minuteur de
-- ticket), Safari a DEUX minuteurs de récompense automatique indépendants
-- (Baie Framby / Safari Ball), chacun avec son propre plafond de mise en
-- pause (berry_reward_max/ball_reward_max) — même principe que
-- mining_config.ticket_max mais dédoublé.
CREATE TABLE IF NOT EXISTS safari_config (
  id                            bigint PRIMARY KEY DEFAULT 1,
  nom                           text NOT NULL DEFAULT 'Safari',
  icon_url                      text NOT NULL DEFAULT '/website_icons/icon_safari_game.png',
  banner_url                    text NOT NULL DEFAULT '',
  session_duration_amount       integer NOT NULL DEFAULT 72,
  session_duration_unit         text NOT NULL DEFAULT 'hours' CHECK (session_duration_unit IN ('hours', 'minutes')),
  -- Baie Framby
  berry_min_increase            integer NOT NULL DEFAULT 5,
  berry_max_increase            integer NOT NULL DEFAULT 15,
  berry_reward_amount           integer NOT NULL DEFAULT 1,
  berry_reward_interval_amount  integer NOT NULL DEFAULT 0, -- 0 = récompense automatique désactivée
  berry_reward_interval_unit    text NOT NULL DEFAULT 'hours' CHECK (berry_reward_interval_unit IN ('hours', 'minutes')),
  berry_reward_max              integer NOT NULL DEFAULT 5,
  -- Safari Ball
  ball_reward_amount            integer NOT NULL DEFAULT 1,
  ball_reward_interval_amount   integer NOT NULL DEFAULT 0,
  ball_reward_interval_unit     text NOT NULL DEFAULT 'hours' CHECK (ball_reward_interval_unit IN ('hours', 'minutes')),
  ball_reward_max               integer NOT NULL DEFAULT 3,
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO safari_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- Groupes de pokémon (gérés entièrement dans Admin → Safari, contrairement
-- aux groupes d'œufs de la Pension qui viennent d'un import CSV) : nom +
-- poids de tirage relatif pour la sélection de session (poids / somme des
-- poids, même principe que gift_lootbox_items/mining_item_defs/pension_egg_pool).
CREATE TABLE IF NOT EXISTS safari_groups (
  id           bigserial PRIMARY KEY,
  nom          text NOT NULL,
  weight       integer NOT NULL DEFAULT 1 CHECK (weight >= 0),
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- Pokémon appartenant à un groupe, avec leur propre poids de tirage DANS ce
-- groupe (tirage à deux étages : groupe d'abord, puis pokémon dans le
-- groupe — voir safari_ensure_active_session ci-dessous).
CREATE TABLE IF NOT EXISTS safari_group_pokemon (
  id           bigserial PRIMARY KEY,
  group_id     bigint NOT NULL REFERENCES safari_groups(id) ON DELETE CASCADE,
  pokemon_nom  text NOT NULL,
  weight       integer NOT NULL DEFAULT 1 CHECK (weight >= 1),
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_safari_group_pokemon_group ON safari_group_pokemon(group_id);

-- Zones de la jauge de capture (0-100), propres à CHAQUE groupe (décision
-- produit : un groupe "rare" peut avoir une courbe de capture différente
-- d'un groupe "commun", pas seulement un poids de tirage différent). Doivent
-- couvrir 0-100 sans trou ni chevauchement pour un groupe donné — validé
-- côté client dans l'admin (voir src/lib/safari.ts::validateGaugeAreas),
-- pas de contrainte SQL multi-lignes (même posture que mining_custom_grid_items,
-- qui ne valide pas non plus le non-chevauchement en base).
CREATE TABLE IF NOT EXISTS safari_gauge_areas (
  id              bigserial PRIMARY KEY,
  group_id        bigint NOT NULL REFERENCES safari_groups(id) ON DELETE CASCADE,
  min_value       integer NOT NULL CHECK (min_value >= 0 AND min_value <= 100),
  max_value       integer NOT NULL CHECK (max_value >= 0 AND max_value <= 100 AND max_value > min_value),
  color           text NOT NULL DEFAULT '#f5a623',
  catch_rate_pct  integer NOT NULL DEFAULT 20 CHECK (catch_rate_pct BETWEEN 0 AND 100),
  sort_order      integer NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_safari_gauge_areas_group ON safari_gauge_areas(group_id, sort_order);

-- Session Safari partagée par tous les joueurs (une seule active à la fois —
-- même idiome que mining_grids.is_active). Une ligne par session jouée,
-- is_active bascule à false + ended_at plutôt qu'une suppression.
CREATE TABLE IF NOT EXISTS safari_sessions (
  id           bigserial PRIMARY KEY,
  is_active    boolean NOT NULL DEFAULT true,
  started_at   timestamptz NOT NULL DEFAULT now(),
  expires_at   timestamptz NOT NULL,
  ended_at     timestamptz,
  notified     boolean NOT NULL DEFAULT false -- consommé par la notification de démarrage (send-notifications.js)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_safari_sessions_one_active
  ON safari_sessions (is_active) WHERE is_active = true;

-- Les 3 pokémon d'une session. position_gauge est le seul état mutable en
-- dehors de la résolution — mise à jour exclusivement par safari_throw_berry/
-- safari_throw_ball (jamais recalculée ni envoyée par le client). group_id
-- est conservé pour résoudre la jauge/le taux de capture de CE pokémon
-- précis (chaque groupe a sa propre jauge, voir safari_gauge_areas).
CREATE TABLE IF NOT EXISTS safari_session_pokemon (
  id                     bigserial PRIMARY KEY,
  session_id             bigint NOT NULL REFERENCES safari_sessions(id) ON DELETE CASCADE,
  slot                   integer NOT NULL CHECK (slot BETWEEN 0 AND 2),
  pokemon_nom            text NOT NULL,
  group_id               bigint NOT NULL REFERENCES safari_groups(id),
  position_gauge         integer NOT NULL CHECK (position_gauge BETWEEN 0 AND 100),
  status                 text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'captured', 'fled')),
  captured_by_player_id  bigint,
  resolved_at            timestamptz,
  created_at             timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, slot)
);
CREATE INDEX IF NOT EXISTS idx_safari_session_pokemon_session ON safari_session_pokemon(session_id);

-- Une tentative de Safari Ball par joueur par pokémon par session — la
-- contrainte UNIQUE (pas un simple flag booléen) est ce qui rend "une seule
-- tentative" sûre face à des appels concurrents/doubles clics : un INSERT en
-- conflit = tentative déjà utilisée, voir safari_throw_ball ci-dessous.
CREATE TABLE IF NOT EXISTS safari_ball_attempts (
  id                  bigserial PRIMARY KEY,
  session_pokemon_id  bigint NOT NULL REFERENCES safari_session_pokemon(id) ON DELETE CASCADE,
  player_id           bigint NOT NULL,
  success             boolean NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_pokemon_id, player_id)
);

-- Tirage forcé pour la PROCHAINE session (au plus 3 lignes, une par slot) —
-- même idiome que mining_config.next_custom_grid_id : consommé une seule
-- fois par safari_ensure_active_session() puis vidé. group_id fixe le
-- groupe (donc les zones de jauge) à utiliser pour ce pokémon précis ; il
-- n'a pas besoin d'appartenir à safari_group_pokemon pour ce groupe — c'est
-- justement ce qui permet à l'admin de forcer N'IMPORTE QUEL pokémon existant
-- avec la jauge d'un groupe de son choix.
CREATE TABLE IF NOT EXISTS safari_forced_pokemon (
  slot         integer PRIMARY KEY CHECK (slot BETWEEN 0 AND 2),
  group_id     bigint NOT NULL REFERENCES safari_groups(id) ON DELETE CASCADE,
  pokemon_nom  text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- État Safari par joueur : deux minuteurs de récompense automatique
-- indépendants (contrairement à mining_player_state qui n'en a qu'un).
CREATE TABLE IF NOT EXISTS safari_player_state (
  player_id      bigint PRIMARY KEY,
  next_berry_at  timestamptz,
  next_ball_at   timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- Flux live des actions de la session en cours, affiché sous les 3 pokémon
-- dans SafariPopup — même rôle que mining_moves (distinct de history_events,
-- qui ne reçoit que les événements résumés : lancer de baie, capture, fuite).
CREATE TABLE IF NOT EXISTS safari_moves (
  id                  bigserial PRIMARY KEY,
  session_id          bigint NOT NULL REFERENCES safari_sessions(id) ON DELETE CASCADE,
  session_pokemon_id  bigint REFERENCES safari_session_pokemon(id) ON DELETE SET NULL,
  player_id           bigint NOT NULL,
  action              text NOT NULL CHECK (action IN ('berry', 'ball_success', 'ball_fail')),
  gauge_before        integer,
  gauge_after         integer,
  created_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_safari_moves_session_created ON safari_moves(session_id, created_at);

ALTER TABLE safari_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE safari_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE safari_group_pokemon ENABLE ROW LEVEL SECURITY;
ALTER TABLE safari_gauge_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE safari_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE safari_session_pokemon ENABLE ROW LEVEL SECURITY;
ALTER TABLE safari_ball_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE safari_forced_pokemon ENABLE ROW LEVEL SECURITY;
ALTER TABLE safari_player_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE safari_moves ENABLE ROW LEVEL SECURITY;

-- Lecture + écriture publiques partout (app sans vraie sécurité, comme le
-- reste du schéma). Les fonctions RPC ci-dessous s'exécutent avec le rôle
-- appelant (anon), pas en SECURITY DEFINER — elles ont donc besoin de ces
-- mêmes policies.
CREATE POLICY "Public read safari_config"
  ON safari_config FOR SELECT TO anon USING (true);
CREATE POLICY "Public update safari_config"
  ON safari_config FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read safari_groups"
  ON safari_groups FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert safari_groups"
  ON safari_groups FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update safari_groups"
  ON safari_groups FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete safari_groups"
  ON safari_groups FOR DELETE TO anon USING (true);

CREATE POLICY "Public read safari_group_pokemon"
  ON safari_group_pokemon FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert safari_group_pokemon"
  ON safari_group_pokemon FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update safari_group_pokemon"
  ON safari_group_pokemon FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete safari_group_pokemon"
  ON safari_group_pokemon FOR DELETE TO anon USING (true);

CREATE POLICY "Public read safari_gauge_areas"
  ON safari_gauge_areas FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert safari_gauge_areas"
  ON safari_gauge_areas FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update safari_gauge_areas"
  ON safari_gauge_areas FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete safari_gauge_areas"
  ON safari_gauge_areas FOR DELETE TO anon USING (true);

CREATE POLICY "Public read safari_sessions"
  ON safari_sessions FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert safari_sessions"
  ON safari_sessions FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update safari_sessions"
  ON safari_sessions FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read safari_session_pokemon"
  ON safari_session_pokemon FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert safari_session_pokemon"
  ON safari_session_pokemon FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update safari_session_pokemon"
  ON safari_session_pokemon FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read safari_ball_attempts"
  ON safari_ball_attempts FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert safari_ball_attempts"
  ON safari_ball_attempts FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "Public read safari_forced_pokemon"
  ON safari_forced_pokemon FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert safari_forced_pokemon"
  ON safari_forced_pokemon FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update safari_forced_pokemon"
  ON safari_forced_pokemon FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete safari_forced_pokemon"
  ON safari_forced_pokemon FOR DELETE TO anon USING (true);

CREATE POLICY "Public read safari_player_state"
  ON safari_player_state FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert safari_player_state"
  ON safari_player_state FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update safari_player_state"
  ON safari_player_state FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read safari_moves"
  ON safari_moves FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert safari_moves"
  ON safari_moves FOR INSERT TO anon WITH CHECK (true);

-- ── Fonctions RPC de concurrence ────────────────────────────────
-- Même justification et même posture (rôle appelant anon, pas SECURITY
-- DEFINER) que mining_ensure_active_grid/mining_dig_cell : Safari est
-- cooperative et non authentifiée, donc plusieurs clients peuvent
-- légitimement se disputer la création de session ou la résolution d'un
-- même pokémon en même temps.

-- Retourne l'id de la session active, en la créant si besoin (aucune session
-- active, ou session active expirée). pg_advisory_xact_lock sérialise tous
-- les appels concurrents pour la durée de la transaction — le premier
-- appelant crée la session, tous les autres voient simplement la session
-- fraîchement créée et la retournent telle quelle (même idiome que
-- mining_ensure_active_grid).
--
-- Cette fonction n'est appelée QUE quand un joueur ouvre Safari (montage de
-- SafariPopup) ou quand le 3e pokémon d'une session vient d'être résolu
-- (voir safari_throw_ball) — jamais par un minuteur en arrière-plan. C'est ce
-- qui garantit qu'une session expirée avec des pokémon non résolus reste
-- inactive tant qu'aucun joueur n'ouvre Safari : "expirer" une session ici
-- ne fait que la clôturer, ça ne relance rien tant que le flux ci-dessous
-- n'a pas été exécuté jusqu'au bout par un appelant.
CREATE OR REPLACE FUNCTION safari_ensure_active_session()
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
  v_session_id   bigint;
  v_expires_at   timestamptz;
  v_slot         integer;
  v_group_id     bigint;
  v_pokemon_nom  text;
  v_first_min    integer;
  v_first_max    integer;
  v_picked_noms  text[] := '{}';
  v_forced_count integer;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('safari_session_generation'));

  SELECT id INTO v_session_id FROM safari_sessions
    WHERE is_active = true AND expires_at > now() FOR UPDATE;
  IF v_session_id IS NOT NULL THEN
    RETURN v_session_id;
  END IF;

  -- Session active mais expirée : on la clôture. Aucune nouvelle session
  -- n'est créée automatiquement ici par un minuteur — uniquement parce que
  -- CETTE fonction vient d'être appelée par un joueur qui ouvre Safari.
  UPDATE safari_sessions SET is_active = false, ended_at = now()
    WHERE is_active = true AND expires_at <= now();

  -- Tirage forcé par l'admin (safari_forced_pokemon) : consommé une seule
  -- fois pour la toute prochaine session s'il contient exactement 3 lignes
  -- (une par slot) — sinon ignoré silencieusement (configuration incomplète,
  -- on retombe sur le tirage pondéré normal ci-dessous).
  SELECT count(*) INTO v_forced_count FROM safari_forced_pokemon;

  IF v_forced_count <> 3 THEN
    IF NOT EXISTS (SELECT 1 FROM safari_groups WHERE weight > 0) THEN
      RAISE EXCEPTION 'Aucun groupe Safari avec un poids de tirage > 0 — configuration admin incomplète';
    END IF;
  END IF;

  SELECT (now() + (session_duration_amount ||
      (CASE WHEN session_duration_unit = 'minutes' THEN ' minutes' ELSE ' hours' END))::interval)
    INTO v_expires_at FROM safari_config WHERE id = 1;

  INSERT INTO safari_sessions (is_active, expires_at) VALUES (true, v_expires_at)
    RETURNING id INTO v_session_id;

  FOR v_slot IN 0..2 LOOP
    IF v_forced_count = 3 THEN
      SELECT group_id, pokemon_nom INTO v_group_id, v_pokemon_nom
        FROM safari_forced_pokemon WHERE slot = v_slot;
    ELSE
      -- Tirage pondéré du groupe, puis du pokémon DANS ce groupe — portage SQL
      -- de l'idiome pickWeightedEggSpecies (src/lib/pension.ts) /
      -- pickOneWeighted (src/lib/mining.ts) : somme cumulative des poids sur
      -- une fenêtre, tirage d'un nombre aléatoire dans [0, total).
      SELECT id INTO v_group_id FROM (
        SELECT id, sum(weight) OVER (ORDER BY id) AS cum, sum(weight) OVER () AS total
        FROM safari_groups WHERE weight > 0
      ) w WHERE cum >= random() * w.total ORDER BY cum LIMIT 1;

      IF v_group_id IS NULL THEN
        RAISE EXCEPTION 'Tirage du groupe Safari impossible — configuration admin incomplète';
      END IF;

      IF NOT EXISTS (SELECT 1 FROM safari_group_pokemon WHERE group_id = v_group_id AND weight > 0) THEN
        RAISE EXCEPTION 'Le groupe Safari % n''a aucun pokémon avec un poids > 0', v_group_id;
      END IF;

      -- Exclut les pokémon déjà tirés dans cette session (pas de doublon), sauf
      -- si le groupe tiré n'a plus aucun pokémon disponible hors doublons — dans
      -- ce cas on retombe sur le pool complet du groupe (dernier restant).
      SELECT pokemon_nom INTO v_pokemon_nom FROM (
        SELECT pokemon_nom, sum(weight) OVER (ORDER BY id) AS cum, sum(weight) OVER () AS total
        FROM safari_group_pokemon
        WHERE group_id = v_group_id AND weight > 0 AND NOT (pokemon_nom = ANY(v_picked_noms))
      ) w WHERE cum >= random() * w.total ORDER BY cum LIMIT 1;

      IF v_pokemon_nom IS NULL THEN
        SELECT pokemon_nom INTO v_pokemon_nom FROM (
          SELECT pokemon_nom, sum(weight) OVER (ORDER BY id) AS cum, sum(weight) OVER () AS total
          FROM safari_group_pokemon WHERE group_id = v_group_id AND weight > 0
        ) w WHERE cum >= random() * w.total ORDER BY cum LIMIT 1;
      END IF;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM safari_gauge_areas WHERE group_id = v_group_id) THEN
      RAISE EXCEPTION 'Le groupe Safari % n''a aucune zone de jauge configurée', v_group_id;
    END IF;

    v_picked_noms := array_append(v_picked_noms, v_pokemon_nom);

    SELECT min_value, max_value INTO v_first_min, v_first_max
      FROM safari_gauge_areas WHERE group_id = v_group_id ORDER BY min_value ASC LIMIT 1;

    INSERT INTO safari_session_pokemon (session_id, slot, pokemon_nom, group_id, position_gauge)
    VALUES (
      v_session_id, v_slot, v_pokemon_nom, v_group_id,
      v_first_min + floor(random() * GREATEST(1, v_first_max - v_first_min))::int
    );
  END LOOP;

  IF v_forced_count = 3 THEN
    DELETE FROM safari_forced_pokemon;
  END IF;

  RETURN v_session_id;
END;
$$;

-- Lance une Baie sur un pokémon : atomique de bout en bout. Le verrouillage
-- de ligne (SELECT ... FOR UPDATE) sur CE pokémon précis suffit à rendre
-- l'opération sûre face à des joueurs concurrents — même raisonnement que
-- pour mining_grid_cells (une ligne par ressource contestée = sérialisation
-- automatique par Postgres, pas besoin de verrou global) ; deux joueurs qui
-- lancent une baie sur deux pokémon DIFFÉRENTS ne se bloquent jamais.
CREATE OR REPLACE FUNCTION safari_throw_berry(p_session_pokemon_id bigint, p_player_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_status      text;
  v_before      integer;
  v_after       integer;
  v_session_id  bigint;
  v_min_inc     integer;
  v_max_inc     integer;
  v_delta       integer;
BEGIN
  SELECT status, position_gauge, session_id INTO v_status, v_before, v_session_id
    FROM safari_session_pokemon WHERE id = p_session_pokemon_id FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;
  IF v_status <> 'active' THEN
    RETURN jsonb_build_object('status', 'already_resolved');
  END IF;

  SELECT berry_min_increase, berry_max_increase INTO v_min_inc, v_max_inc FROM safari_config WHERE id = 1;
  v_delta := v_min_inc + floor(random() * GREATEST(1, v_max_inc - v_min_inc + 1))::int;
  v_after := LEAST(100, v_before + v_delta);

  UPDATE safari_session_pokemon SET position_gauge = v_after WHERE id = p_session_pokemon_id;

  INSERT INTO safari_moves (session_id, session_pokemon_id, player_id, action, gauge_before, gauge_after)
  VALUES (v_session_id, p_session_pokemon_id, p_player_id, 'berry', v_before, v_after);

  RETURN jsonb_build_object('status', 'ok', 'gauge_before', v_before, 'gauge_after', v_after);
END;
$$;

-- Tente de capturer un pokémon avec une Safari Ball : l'action terminale et
-- critique en termes de course. Deux garanties distinctes, toutes deux déjà
-- posées par le verrouillage de ligne initial (SELECT ... FOR UPDATE) sur ce
-- pokémon précis, qui est tenu pour toute la durée de la fonction :
--   1) "une seule tentative par joueur" est garanti par la contrainte UNIQUE
--      de safari_ball_attempts (pas par une simple lecture-avant-écriture) ;
--   2) "un seul gagnant si plusieurs joueurs capturent en même temps" est
--      garanti par le verrou de ligne : le premier appelant à l'obtenir voit
--      status='active' et peut résoudre le pokémon ; tout second appelant,
--      une fois le verrou obtenu à son tour, voit déjà status<>'active' et
--      est rejeté — sa tentative reste néanmoins journalisée (comptée).
CREATE OR REPLACE FUNCTION safari_throw_ball(p_session_pokemon_id bigint, p_player_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_status        text;
  v_gauge         integer;
  v_session_id    bigint;
  v_group_id      bigint;
  v_catch_rate    integer;
  v_success       boolean;
  v_new_status    text;
  v_all_resolved  boolean;
BEGIN
  SELECT status, position_gauge, session_id, group_id INTO v_status, v_gauge, v_session_id, v_group_id
    FROM safari_session_pokemon WHERE id = p_session_pokemon_id FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;
  IF v_status <> 'active' THEN
    RETURN jsonb_build_object('status', 'already_resolved');
  END IF;

  IF EXISTS (SELECT 1 FROM safari_ball_attempts WHERE session_pokemon_id = p_session_pokemon_id AND player_id = p_player_id) THEN
    RETURN jsonb_build_object('status', 'already_attempted');
  END IF;

  SELECT catch_rate_pct INTO v_catch_rate FROM safari_gauge_areas
    WHERE group_id = v_group_id AND v_gauge >= min_value AND v_gauge < max_value
    ORDER BY min_value LIMIT 1;
  IF v_catch_rate IS NULL THEN
    -- Cas limite gauge = 100 (borne supérieure exclusive de la dernière
    -- zone) : repli explicite sur la dernière zone de CE groupe.
    SELECT catch_rate_pct INTO v_catch_rate FROM safari_gauge_areas
      WHERE group_id = v_group_id ORDER BY min_value DESC LIMIT 1;
  END IF;

  v_success := random() < (COALESCE(v_catch_rate, 0) / 100.0);

  BEGIN
    INSERT INTO safari_ball_attempts (session_pokemon_id, player_id, success)
      VALUES (p_session_pokemon_id, p_player_id, v_success);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('status', 'already_attempted');
  END;

  v_new_status := CASE WHEN v_success THEN 'captured' ELSE 'fled' END;

  UPDATE safari_session_pokemon
  SET status = v_new_status,
      captured_by_player_id = CASE WHEN v_success THEN p_player_id ELSE NULL END,
      resolved_at = now()
  WHERE id = p_session_pokemon_id;

  INSERT INTO safari_moves (session_id, session_pokemon_id, player_id, action, gauge_before, gauge_after)
  VALUES (v_session_id, p_session_pokemon_id, p_player_id, CASE WHEN v_success THEN 'ball_success' ELSE 'ball_fail' END, v_gauge, v_gauge);

  -- Si les 3 pokémon de la session sont désormais résolus, on démarre
  -- immédiatement une nouvelle session. safari_ensure_active_session()
  -- reprend son propre verrou avisoire, donc pas de risque de double
  -- création même si deux appels y entrent l'un après l'autre pour la même
  -- session tout juste terminée.
  SELECT NOT EXISTS (SELECT 1 FROM safari_session_pokemon WHERE session_id = v_session_id AND status = 'active')
    INTO v_all_resolved;
  IF v_all_resolved THEN
    UPDATE safari_sessions SET is_active = false, ended_at = now() WHERE id = v_session_id;
    PERFORM safari_ensure_active_session();
  END IF;

  RETURN jsonb_build_object('status', 'ok', 'success', v_success);
END;
$$;

GRANT EXECUTE ON FUNCTION safari_ensure_active_session() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION safari_throw_berry(bigint, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION safari_throw_ball(bigint, bigint) TO anon, authenticated;

-- history_events.category doit accepter la nouvelle catégorie 'safari'
-- (lancer de baie, capture, fuite) — même technique que pour 'daycare'.
ALTER TABLE history_events DROP CONSTRAINT IF EXISTS history_events_category_check;
ALTER TABLE history_events ADD CONSTRAINT history_events_category_check
  CHECK (category IN ('inventory', 'pokedex', 'team', 'combat', 'minigame', 'daycare', 'safari'));

-- Diffusion Realtime — mêmes raisons que le bloc Fouille/Pension ci-dessus
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'safari_config', 'safari_groups', 'safari_group_pokemon', 'safari_gauge_areas',
    'safari_sessions', 'safari_session_pokemon', 'safari_ball_attempts',
    'safari_forced_pokemon', 'safari_player_state', 'safari_moves'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', t);
    END IF;
  END LOOP;
END $$;

-- ============================================================
-- Combat Auto (mini-jeu de combat automatique par niveaux)
-- ============================================================
-- Le ticket est unique et codé en dur (comme Fouille/Mini-Jeux/Casino),
-- seul son coût/régénération est configurable en admin — voir
-- autobattle_config ci-dessous. Plusieurs "variantes" (parcours indépendants)
-- peuvent être créées par l'admin ; chaque variante a sa propre séquence de
-- niveaux (opposant + récompenses), jouée séquentiellement par chaque joueur.

CREATE TABLE IF NOT EXISTS autobattle_config (
  id                          bigint PRIMARY KEY DEFAULT 1,
  -- Économie du ticket partagé (Ticket Combat, un seul pour toutes les variantes)
  ticket_max                  integer NOT NULL DEFAULT 3,
  ticket_regen_amount         integer NOT NULL DEFAULT 24,
  ticket_regen_unit           text NOT NULL DEFAULT 'hours' CHECK (ticket_regen_unit IN ('hours', 'minutes')),
  ticket_buy_cost             integer NOT NULL DEFAULT 0,
  ticket_daily_buy_cap        integer NOT NULL DEFAULT 3,
  ticket_full_notify_enabled  boolean NOT NULL DEFAULT false,
  -- Affichage du widget d'accueil partagé (liste des variantes)
  nom                         text NOT NULL DEFAULT 'Combat Auto',
  icon_url                    text NOT NULL DEFAULT '',
  -- Système de précision (voir attacks.precision, 1-10, NULL = 10 par
  -- défaut) : désactivable globalement, auquel cas toute capacité touche
  -- systématiquement (comme précision = 10), voir autobattle_resolve_battle.
  precision_enabled           boolean NOT NULL DEFAULT true,
  -- Icônes affichées en haut à droite de chaque bannière de parcours pour
  -- signaler son mode de jeu (autobattle_variants.game_mode) — partagées par
  -- toutes les variantes, donc ici et pas sur la variante elle-même.
  mode_icon_auto_url          text NOT NULL DEFAULT '',
  mode_icon_manual_url        text NOT NULL DEFAULT '',
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO autobattle_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
-- Si autobattle_config existe déjà (migration précédente déjà appliquée) :
ALTER TABLE autobattle_config ADD COLUMN IF NOT EXISTS precision_enabled boolean NOT NULL DEFAULT true;
-- Bascule globale des talents d'espèce (voir autobattle_talents) — même rôle
-- que precision_enabled : à faux, aucun talent n'est lu ni déclenché, les
-- configurations restant intactes en base.
ALTER TABLE autobattle_config ADD COLUMN IF NOT EXISTS talents_enabled boolean NOT NULL DEFAULT true;
-- Bascule globale de la météo (voir autobattle_weathers) — même rôle : à faux,
-- aucune météo n'est chargée ni levée, et toutes les conditions « météo en
-- cours » se comportent comme « aucune météo ».
ALTER TABLE autobattle_config ADD COLUMN IF NOT EXISTS weather_enabled boolean NOT NULL DEFAULT true;
ALTER TABLE autobattle_config ADD COLUMN IF NOT EXISTS mode_icon_auto_url text NOT NULL DEFAULT '';
ALTER TABLE autobattle_config ADD COLUMN IF NOT EXISTS mode_icon_manual_url text NOT NULL DEFAULT '';

-- Une variante = un parcours indépendant (propre bannière/icône/nom/niveaux/état).
CREATE TABLE IF NOT EXISTS autobattle_variants (
  id            bigserial PRIMARY KEY,
  nom           text NOT NULL DEFAULT '',
  enabled       boolean NOT NULL DEFAULT false,
  icon_url      text NOT NULL DEFAULT '',
  banner_url    text NOT NULL DEFAULT '',
  sort_order    integer NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now()
);
-- Mode de jeu de la variante : 'auto' (existant, le joueur choisit UNE
-- capacité avant le combat, tout se résout d'un coup côté serveur — voir
-- autobattle_resolve_battle) ou 'manual' (le joueur choisit une capacité à
-- CHAQUE tour, un tour à la fois — voir autobattle_resolve_manual_round /
-- autobattle_manual_battles plus bas).
ALTER TABLE autobattle_variants ADD COLUMN IF NOT EXISTS game_mode text NOT NULL DEFAULT 'auto';
ALTER TABLE autobattle_variants DROP CONSTRAINT IF EXISTS autobattle_variants_game_mode_check;
ALTER TABLE autobattle_variants ADD CONSTRAINT autobattle_variants_game_mode_check
  CHECK (game_mode IN ('auto', 'manual'));
-- PNJ "visage" du parcours (players.id, typiquement un PNJ mais rien ne
-- l'impose) : purement cosmétique, sert à donner un adversaire incarné au
-- tirage au sort d'ouverture (voir AutoBattleCoinToss) au lieu d'un simple
-- "VS". NULL = aucun PNJ, le client retombe alors sur la miniature de
-- l'espèce affrontée. Pas de FK vers players (convention du schéma) : un
-- joueur supprimé laisse un id orphelin, que le client traite comme NULL.
ALTER TABLE autobattle_variants ADD COLUMN IF NOT EXISTS npc_player_id bigint;

-- Un niveau = un combat prédéfini dans une variante, joué séquentiellement.
-- opponent_pokemon_nom / opponent_ability_nom référencent pokemon.nom /
-- attacks.nom par nom (pas de FK, même convention que tout le schéma) — les
-- stats de l'opposant (hp/base_damage) sont propres à ce niveau et ne
-- modifient jamais la ligne globale pokemon/attacks correspondante.
CREATE TABLE IF NOT EXISTS autobattle_levels (
  id                    bigserial PRIMARY KEY,
  variant_id            bigint NOT NULL REFERENCES autobattle_variants(id) ON DELETE CASCADE,
  level_index           integer NOT NULL,
  opponent_pokemon_nom  text NOT NULL,
  opponent_hp           integer NOT NULL DEFAULT 1 CHECK (opponent_hp > 0),
  opponent_base_damage  integer NOT NULL DEFAULT 0 CHECK (opponent_base_damage >= 0),
  opponent_ability_nom  text NOT NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (variant_id, level_index)
);
CREATE INDEX IF NOT EXISTS idx_autobattle_levels_variant ON autobattle_levels(variant_id, level_index);

-- Mode Manuel uniquement (variant.game_mode = 'manual', voir autobattle_
-- variants) : l'adversaire peut jouer jusqu'à 10 capacités au lieu d'une
-- seule, toujours déclenchées dans le MÊME ordre, en boucle — une position
-- par NOUVEAU tour adverse (voir autobattle_resolve_manual_round —
-- opponent_ability_cycle_index, sur autobattle_manual_battles, détermine
-- laquelle des 10 est jouée ; sans effet si l'adversaire est Métamorph, qui
-- pioche alors au hasard dans le movepool du joueur, voir requirement
-- dédié). opponent_ability_nom (existante) reste la 1ʳᵉ position de la
-- séquence — inchangée pour le mode Auto, qui n'utilise toujours qu'elle
-- seule. _2 à _10 restent NULL en mode Auto (ignorées) et sont optionnelles
-- même en mode Manuel : seules les positions non-NULL comptent dans la
-- boucle.
ALTER TABLE autobattle_levels ADD COLUMN IF NOT EXISTS opponent_ability_nom_2 text;
ALTER TABLE autobattle_levels ADD COLUMN IF NOT EXISTS opponent_ability_nom_3 text;
ALTER TABLE autobattle_levels ADD COLUMN IF NOT EXISTS opponent_ability_nom_4 text;
ALTER TABLE autobattle_levels ADD COLUMN IF NOT EXISTS opponent_ability_nom_5 text;
ALTER TABLE autobattle_levels ADD COLUMN IF NOT EXISTS opponent_ability_nom_6 text;
ALTER TABLE autobattle_levels ADD COLUMN IF NOT EXISTS opponent_ability_nom_7 text;
ALTER TABLE autobattle_levels ADD COLUMN IF NOT EXISTS opponent_ability_nom_8 text;
ALTER TABLE autobattle_levels ADD COLUMN IF NOT EXISTS opponent_ability_nom_9 text;
ALTER TABLE autobattle_levels ADD COLUMN IF NOT EXISTS opponent_ability_nom_10 text;

-- Récompense(s) d'un niveau — 1 ou plusieurs lignes. 'badge' et 'item' sont
-- mécaniquement identiques (créditées via player_items) : reward_type ne sert
-- qu'à distinguer l'affichage/le sélecteur admin (un objet marqué comme badge
-- via items.rarete = 'Badge' n'est pas un système à part, voir types.ts).
CREATE TABLE IF NOT EXISTS autobattle_level_rewards (
  id            bigserial PRIMARY KEY,
  level_id      bigint NOT NULL REFERENCES autobattle_levels(id) ON DELETE CASCADE,
  reward_type   text NOT NULL CHECK (reward_type IN ('xp', 'item', 'badge')),
  xp_amount     integer,
  item_nom      text,
  item_quantity integer,
  sort_order    integer NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT autobattle_reward_xp_fields CHECK (reward_type <> 'xp' OR (xp_amount IS NOT NULL AND xp_amount > 0)),
  CONSTRAINT autobattle_reward_item_fields CHECK (reward_type NOT IN ('item', 'badge') OR (item_nom IS NOT NULL AND item_quantity IS NOT NULL AND item_quantity > 0))
);
CREATE INDEX IF NOT EXISTS idx_autobattle_level_rewards_level ON autobattle_level_rewards(level_id);

-- État Combat Auto par joueur : minuteur du prochain ticket gratuit + suivi
-- des achats du jour — même schéma que mining_player_state/casino_player_state.
CREATE TABLE IF NOT EXISTS autobattle_player_state (
  player_id             bigint PRIMARY KEY,
  next_ticket_at        timestamptz,
  purchase_count        integer NOT NULL DEFAULT 0,
  purchase_date         date,
  ticket_full_notified  boolean NOT NULL DEFAULT false,
  created_at            timestamptz NOT NULL DEFAULT now()
);

-- Progression d'un joueur dans une variante : niveau courant (celui qu'il
-- doit jouer ensuite) + statut "variante entièrement terminée".
CREATE TABLE IF NOT EXISTS autobattle_player_variant_progress (
  player_id            bigint NOT NULL,
  variant_id           bigint NOT NULL REFERENCES autobattle_variants(id) ON DELETE CASCADE,
  current_level_index  integer NOT NULL DEFAULT 0,
  variant_completed    boolean NOT NULL DEFAULT false,
  completed_at         timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (player_id, variant_id)
);

-- Découverte/complétion d'un niveau par un joueur : discovered permet de
-- révéler l'opposant une fois le niveau joué au moins une fois (même en cas
-- de défaite, où il reste révélé pour la nouvelle tentative) ; completed
-- passe à true uniquement à la victoire. C'est aussi la ligne verrouillée
-- (SELECT ... FOR UPDATE) par autobattle_resolve_battle pour sérialiser les
-- tentatives concurrentes d'un même joueur sur un même niveau — même idiome
-- que le verrouillage de safari_session_pokemon dans safari_throw_ball.
CREATE TABLE IF NOT EXISTS autobattle_player_level_state (
  player_id      bigint NOT NULL,
  level_id       bigint NOT NULL REFERENCES autobattle_levels(id) ON DELETE CASCADE,
  discovered     boolean NOT NULL DEFAULT false,
  discovered_at  timestamptz,
  completed      boolean NOT NULL DEFAULT false,
  completed_at   timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (player_id, level_id)
);

-- Journal des combats résolus (une ligne par appel à autobattle_resolve_battle
-- qui a dépassé la vérification d'idempotence) : sert à la fois de flux
-- "derniers combats" et de garde anti-double-soumission via
-- idempotency_key UNIQUE (voir la fonction ci-dessous) — même rôle que
-- safari_ball_attempts, mais générique à toute tentative (pas seulement les
-- doublons "même joueur + même cible").
CREATE TABLE IF NOT EXISTS autobattle_battles (
  id                 bigserial PRIMARY KEY,
  player_id          bigint NOT NULL,
  level_id           bigint NOT NULL REFERENCES autobattle_levels(id) ON DELETE CASCADE,
  player_pokemon_id  bigint NOT NULL,
  ability_nom        text NOT NULL,
  outcome            text CHECK (outcome IS NULL OR outcome IN ('win', 'lose')),
  turn_log           jsonb NOT NULL DEFAULT '[]'::jsonb,
  rewards_granted    jsonb,
  idempotency_key    uuid NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (idempotency_key)
);
CREATE INDEX IF NOT EXISTS idx_autobattle_battles_player ON autobattle_battles(player_id, created_at);

-- État vivant (éphémère) d'un combat en mode Manuel (variant.game_mode =
-- 'manual', voir autobattle_resolve_manual_round) : contrairement à
-- autobattle_battles (journal figé, un combat = une ligne écrite une fois),
-- cette table est réécrite à CHAQUE tour tant que le combat n'est pas
-- terminé — une seule ligne active à la fois par (player_id, level_id).
-- first_attacker fixe l'ordre de résolution pour TOUT le combat (tiré au
-- sort une seule fois, au 1er tour) — voir requirement Scénario A/B : le
-- joueur choisit TOUJOURS sa capacité avant de voir quoi que ce soit, que ce
-- soit lui ou l'adversaire qui résout en premier ce tour-là. Un appel RPC
-- résout un "tour" complet des DEUX camps, mais les effets de rythme
-- (turn_effect, voir autobattle_ability_rules) restent PLEINEMENT actifs en
-- mode Manuel (contrairement à une version antérieure de cette table qui
-- les ignorait) : une capacité 'play_twice'/'play_three'/'play_random'/
-- 'repeat_until_fail' peut donc frapper plusieurs fois au sein du tour d'un
-- même camp, 'skip' fait passer un tour sur deux, 'prepare_release' étale
-- une capacité sur 2 tours. turn_no est le compteur d'ACTIVATIONS
-- élémentaires (comme v_turn_no en mode Auto, PAS un compteur d'appels RPC)
-- utilisé pour l'expiration des modificateurs de stat/soin passif/Anti-Soin.
-- player_preparing/opponent_preparing + *_preparing_ability_nom mémorisent
-- la capacité en cours de préparation (prepare_release) pour forcer sa
-- LIBÉRATION au tour suivant de ce camp, même si le joueur choisit une autre
-- capacité entretemps côté client (celle-ci sera simplement utilisée au tour
-- D'APRÈS). opponent_ability_cycle_index avance d'une position (parmi
-- opponent_ability_nom/_2/_3/_4, voir autobattle_levels) à chaque NOUVEAU
-- tour de l'adversaire (pas à chaque frappe d'une rafale, ni à une
-- libération de préparation) — sauf si l'adversaire est Métamorph, auquel
-- cas il pioche uniformément parmi TOUTES les capacités apprises par le
-- pokémon du joueur (v_pp.moves) au lieu de suivre cette séquence, voir
-- requirement dédié. player_stat_mod_uses/opponent_stat_mod_uses sont des
-- cartes {capacité: usages réussis} (pas un entier unique) car la capacité
-- de CHAQUE camp peut changer d'un tour à l'autre en mode Manuel
-- (stat_mod_max_uses se limite par capacité, pas par combat entier).
-- last_idempotency_key + last_result permettent de rejouer la même réponse
-- si le client retente le même tour (perte réseau) — y compris le tour
-- FINAL : la ligne n'est donc jamais supprimée automatiquement à la fin du
-- combat (outcome renseigné), seulement écrasée/redémarrée à zéro par une
-- nouvelle tentative sur ce même niveau (idempotency_key différente).
CREATE TABLE IF NOT EXISTS autobattle_manual_battles (
  id                              bigserial PRIMARY KEY,
  player_id                      bigint NOT NULL,
  level_id                       bigint NOT NULL REFERENCES autobattle_levels(id) ON DELETE CASCADE,
  variant_id                     bigint NOT NULL REFERENCES autobattle_variants(id) ON DELETE CASCADE,
  player_pokemon_id              bigint NOT NULL,
  first_attacker                 text NOT NULL CHECK (first_attacker IN ('player', 'opponent')),
  turn_no                        integer NOT NULL DEFAULT 0,
  -- N'avance qu'à chaque VRAI changement de tour (jamais au milieu d'une
  -- rafale play_twice/play_three/repeat_until_fail/play_random) — voir
  -- autobattle_resolve_manual_round. Base de toutes les durées "en tours"
  -- (invulnérabilité, modificateurs de stat, soin passif, Anti-Soin).
  round_no                       integer NOT NULL DEFAULT 0,
  player_hp                      integer NOT NULL,
  player_max_hp                  integer NOT NULL,
  opponent_hp                    integer NOT NULL,
  player_status                  text,
  opponent_status                text,
  player_damage_mod_amount       integer NOT NULL DEFAULT 0,
  player_damage_mod_expires      integer,
  player_precision_mod_amount    integer NOT NULL DEFAULT 0,
  player_precision_mod_expires   integer,
  opponent_damage_mod_amount     integer NOT NULL DEFAULT 0,
  opponent_damage_mod_expires    integer,
  opponent_precision_mod_amount  integer NOT NULL DEFAULT 0,
  opponent_precision_mod_expires integer,
  player_heal_dot_amount         integer,
  player_heal_dot_expires        integer,
  opponent_heal_dot_amount       integer,
  opponent_heal_dot_expires      integer,
  player_heal_disabled_expires   integer,
  opponent_heal_disabled_expires integer,
  player_invulnerable            boolean NOT NULL DEFAULT false,
  player_invuln_granted_round     integer,
  opponent_invulnerable          boolean NOT NULL DEFAULT false,
  opponent_invuln_granted_round   integer,
  player_stat_mod_uses           jsonb NOT NULL DEFAULT '{}'::jsonb,
  opponent_stat_mod_uses         jsonb NOT NULL DEFAULT '{}'::jsonb,
  player_used_ability             boolean NOT NULL DEFAULT false,
  player_took_damage              boolean NOT NULL DEFAULT false,
  opponent_used_ability           boolean NOT NULL DEFAULT false,
  opponent_took_damage            boolean NOT NULL DEFAULT false,
  player_skip_pending             boolean NOT NULL DEFAULT false,
  opponent_skip_pending           boolean NOT NULL DEFAULT false,
  player_preparing                boolean NOT NULL DEFAULT false,
  opponent_preparing              boolean NOT NULL DEFAULT false,
  player_preparing_ability_nom    text,
  opponent_preparing_ability_nom  text,
  opponent_ability_cycle_index    integer NOT NULL DEFAULT 0,
  turn_log                       jsonb NOT NULL DEFAULT '[]'::jsonb,
  -- NULL tant que le combat est en cours. Une fois gagné/perdu, la ligne
  -- N'EST PAS supprimée (elle reste pour permettre à un retry réseau du
  -- DERNIER tour de rejouer last_result via last_idempotency_key, comme
  -- pour chaque tour intermédiaire) — voir autobattle_resolve_manual_round :
  -- une NOUVELLE tentative de combat sur ce même niveau (idempotency_key
  -- différente ET outcome déjà renseigné) est ce qui déclenche le nettoyage
  -- et le redémarrage à zéro, pas une suppression automatique ici.
  outcome                        text CHECK (outcome IS NULL OR outcome IN ('win', 'lose')),
  last_idempotency_key           uuid,
  last_result                    jsonb,
  created_at                     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (player_id, level_id)
);
ALTER TABLE autobattle_manual_battles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read autobattle_manual_battles" ON autobattle_manual_battles FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_manual_battles" ON autobattle_manual_battles FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_manual_battles" ON autobattle_manual_battles FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete autobattle_manual_battles" ON autobattle_manual_battles FOR DELETE TO anon USING (true);

-- La refonte de l'invulnérabilité (voir CREATE OR REPLACE FUNCTION
-- autobattle_resolve_manual_round plus bas) est passée d'un suivi par TOUR
-- (player_invuln_granted_turn/opponent_invuln_granted_turn, noms d'origine
-- de cette table) à un suivi par ROUND (player_invuln_granted_round/
-- opponent_invuln_granted_round, ce que le code lit désormais) sans que la
-- colonne soit jamais renommée sur les bases déjà déployées — laissant la
-- table dans un état incompatible avec la fonction (erreur Postgres 42703
-- "record v_row has no field player_invuln_granted_round"). Renomme si
-- l'ancien nom existe encore ; les ADD COLUMN IF NOT EXISTS couvrent le cas
-- d'une base neuve (où seul le nouveau nom existe, via le CREATE TABLE
-- ci-dessus) ou déjà renommée (no-op).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'autobattle_manual_battles' AND column_name = 'player_invuln_granted_turn') THEN
    ALTER TABLE autobattle_manual_battles RENAME COLUMN player_invuln_granted_turn TO player_invuln_granted_round;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'autobattle_manual_battles' AND column_name = 'opponent_invuln_granted_turn') THEN
    ALTER TABLE autobattle_manual_battles RENAME COLUMN opponent_invuln_granted_turn TO opponent_invuln_granted_round;
  END IF;
END $$;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_invuln_granted_round integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_invuln_granted_round integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS round_no integer NOT NULL DEFAULT 0;

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

-- Effets persistants offensifs SUBIS par chaque camp (dégâts par tour, vol de
-- vie par tour) et perce-immunité ACCORDÉ à chaque camp — voir
-- autobattle_ability_rules.damage_dot_*/leech_dot_*/pierce_immunity_* et les
-- champs de même nom dans autobattle_combatant_state.
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_damage_dot_amount integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_damage_dot_expires integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_damage_dot_amount integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_damage_dot_expires integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_leech_dot_amount integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_leech_dot_expires integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_leech_dot_amount integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_leech_dot_expires integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_pierce_immunity_type text;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_pierce_immunity_expires integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_pierce_immunity_type text;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_pierce_immunity_expires integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_status_dot_status text;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_status_dot_chance integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_status_dot_expires integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_status_dot_status text;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_status_dot_chance integer;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_status_dot_expires integer;

-- Piles de modificateurs de stat (voir autobattle_mod_total) : remplacent les
-- colonnes *_damage_mod_amount/_expires/_type_filter et *_precision_mod_amount/
-- _expires, qui ne portaient qu'UN modificateur écrasable par camp et par stat.
-- Les anciennes colonnes sont laissées en place (inutilisées) plutôt que
-- supprimées, pour ne pas casser un combat déjà en cours au moment de la
-- migration.
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_damage_mods jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_damage_mods jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_precision_mods jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_precision_mods jsonb NOT NULL DEFAULT '[]'::jsonb;

-- Talents d'espèce déjà déclenchés (voir autobattle_talents / talent_state).
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS player_talent_state jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS opponent_talent_state jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Météo en cours (voir autobattle_weathers) : état de TERRAIN, une seule pour
-- les deux camps, d'où une colonne unique et non un couple player/opponent.
-- NULL = aucune météo. Pas de FK : une météo supprimée en cours de combat doit
-- juste devenir inerte, pas faire échouer le round suivant.
ALTER TABLE autobattle_manual_battles ADD COLUMN IF NOT EXISTS weather_id bigint;

ALTER TABLE autobattle_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE autobattle_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE autobattle_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE autobattle_level_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE autobattle_player_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE autobattle_player_variant_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE autobattle_player_level_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE autobattle_battles ENABLE ROW LEVEL SECURITY;

-- Lecture + écriture publiques partout (app sans vraie sécurité, comme le
-- reste du schéma). autobattle_resolve_battle s'exécute avec le rôle
-- appelant (anon), pas en SECURITY DEFINER — elle a donc besoin de ces
-- mêmes policies pour toucher player_items/player_pokemon/history_events.
CREATE POLICY "Public read autobattle_config" ON autobattle_config FOR SELECT TO anon USING (true);
CREATE POLICY "Public update autobattle_config" ON autobattle_config FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read autobattle_variants" ON autobattle_variants FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_variants" ON autobattle_variants FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_variants" ON autobattle_variants FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete autobattle_variants" ON autobattle_variants FOR DELETE TO anon USING (true);

CREATE POLICY "Public read autobattle_levels" ON autobattle_levels FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_levels" ON autobattle_levels FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_levels" ON autobattle_levels FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete autobattle_levels" ON autobattle_levels FOR DELETE TO anon USING (true);

CREATE POLICY "Public read autobattle_level_rewards" ON autobattle_level_rewards FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_level_rewards" ON autobattle_level_rewards FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_level_rewards" ON autobattle_level_rewards FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete autobattle_level_rewards" ON autobattle_level_rewards FOR DELETE TO anon USING (true);

CREATE POLICY "Public read autobattle_player_state" ON autobattle_player_state FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_player_state" ON autobattle_player_state FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_player_state" ON autobattle_player_state FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Public read autobattle_player_variant_progress" ON autobattle_player_variant_progress FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_player_variant_progress" ON autobattle_player_variant_progress FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_player_variant_progress" ON autobattle_player_variant_progress FOR UPDATE TO anon USING (true) WITH CHECK (true);
-- Nécessaire pour la réinitialisation admin d'une variante (tous joueurs), voir AdminAutoBattleVariantsPanel.
CREATE POLICY "Public delete autobattle_player_variant_progress" ON autobattle_player_variant_progress FOR DELETE TO anon USING (true);

CREATE POLICY "Public read autobattle_player_level_state" ON autobattle_player_level_state FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_player_level_state" ON autobattle_player_level_state FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_player_level_state" ON autobattle_player_level_state FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete autobattle_player_level_state" ON autobattle_player_level_state FOR DELETE TO anon USING (true);

CREATE POLICY "Public read autobattle_battles" ON autobattle_battles FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_battles" ON autobattle_battles FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_battles" ON autobattle_battles FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- Capacités bannies (trop puissantes pour ce mode de jeu) : liste gérée
-- librement par l'admin, référencée par nom (pas de FK, même convention que
-- tout le schéma) — exclut la capacité à la fois du choix du joueur et de
-- celui de l'adversaire (voir autobattle_resolve_battle et les filtres
-- côté client dans src/lib/autoBattle.ts).
CREATE TABLE IF NOT EXISTS autobattle_banned_attacks (
  attack_nom  text PRIMARY KEY,
  created_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE autobattle_banned_attacks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read autobattle_banned_attacks" ON autobattle_banned_attacks FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_banned_attacks" ON autobattle_banned_attacks FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public delete autobattle_banned_attacks" ON autobattle_banned_attacks FOR DELETE TO anon USING (true);

-- Effets spéciaux d'une capacité (une ligne par capacité concernée, les deux
-- familles d'effet sont indépendantes et optionnelles) : effet sur le rythme
-- des tours (passe son tour, joue plusieurs fois de suite — reroll à chaque
-- activation pour 'play_random') et/ou effet de soin (montant fixe, ou % des
-- dégâts infligés ce tour-là — soigne l'utilisateur lui-même, après les
-- dégâts, voir autobattle_resolve_battle). Référencée par nom (pas de FK,
-- même convention que tout le schéma).
CREATE TABLE IF NOT EXISTS autobattle_ability_rules (
  attack_nom        text PRIMARY KEY,
  turn_effect       text CHECK (turn_effect IS NULL OR turn_effect IN ('skip', 'play_twice', 'play_three', 'play_random', 'repeat_until_fail', 'prepare_release', 'charge_double_next', 'first_and_replay')),
  turn_random_min   integer,
  turn_random_max   integer,
  -- 'repeat_until_fail' : la capacité continue de s'utiliser tant qu'elle
  -- touche, s'arrête au premier raté (ou à repeat_max_iterations activations
  -- si aucun raté avant), voir autobattle_resolve_battle. 6 par défaut côté
  -- admin (AdminAutoBattleAbilityRulesPanel), pas de défaut SQL forcé.
  repeat_max_iterations integer,
  -- 'use_stats' : pas de montant/pourcentage à configurer, le soin utilise
  -- directement les dégâts de base + un dé de la capacité elle-même (rerollé
  -- indépendamment du dé de dégâts), voir autobattle_resolve_battle.
  heal_type         text CHECK (heal_type IS NULL OR heal_type IN ('static', 'percent_damage', 'use_stats')),
  heal_amount       integer,
  heal_percent      integer,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT autobattle_ability_rules_random_fields CHECK (
    turn_effect <> 'play_random' OR (turn_random_min IS NOT NULL AND turn_random_max IS NOT NULL AND turn_random_min >= 1 AND turn_random_max >= turn_random_min)
  ),
  CONSTRAINT autobattle_ability_rules_repeat_fields CHECK (
    turn_effect <> 'repeat_until_fail' OR (repeat_max_iterations IS NOT NULL AND repeat_max_iterations >= 1)
  ),
  CONSTRAINT autobattle_ability_rules_heal_fields CHECK (
    heal_type IS NULL
    OR heal_type = 'use_stats'
    OR (heal_type = 'static' AND heal_amount IS NOT NULL AND heal_amount > 0)
    OR (heal_type = 'percent_damage' AND heal_percent IS NOT NULL AND heal_percent > 0)
  )
);
ALTER TABLE autobattle_ability_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read autobattle_ability_rules" ON autobattle_ability_rules FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_ability_rules" ON autobattle_ability_rules FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_ability_rules" ON autobattle_ability_rules FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete autobattle_ability_rules" ON autobattle_ability_rules FOR DELETE TO anon USING (true);

-- Statut "mini-jeu" infligé par une capacité (Combat Auto uniquement) —
-- importé depuis le CSV des attaques comme precision/degats_base (colonnes
-- "Mini-game status"/"Status probability"), PAS géré en admin comme
-- autobattle_ability_rules : c'est une donnée propre à la capacité, au même
-- titre que ses dégâts. Se déclenche sur l'adversaire (jamais soi-même) avec
-- status_chance % de chance à chaque coup réussi, voir autobattle_resolve_battle.
ALTER TABLE attacks ADD COLUMN IF NOT EXISTS status_effect text;
ALTER TABLE attacks ADD COLUMN IF NOT EXISTS status_chance integer;
ALTER TABLE attacks DROP CONSTRAINT IF EXISTS attacks_status_effect_check;
ALTER TABLE attacks ADD CONSTRAINT attacks_status_effect_check
  CHECK (status_effect IS NULL OR status_effect IN ('paralysis', 'fear', 'confusion', 'sleep', 'burn', 'poison', 'frozen'));
ALTER TABLE attacks DROP CONSTRAINT IF EXISTS attacks_status_chance_check;
ALTER TABLE attacks ADD CONSTRAINT attacks_status_chance_check
  CHECK (status_effect IS NULL OR (status_chance IS NOT NULL AND status_chance >= 0 AND status_chance <= 100));
-- Certaines capacités ne sont pas offensives du tout (soin pur, buff pur,
-- statut sur soi...) et ne doivent infliger AUCUN dégât, même passif (espèce
-- + XP du pokémon), quand elles sont utilisées — importé depuis le CSV des
-- attaques (colonne "Inflige dégâts", vrai/faux) au même titre que le reste
-- de la capacité, voir autobattle_resolve_battle/autobattle_resolve_manual_round.
ALTER TABLE attacks ADD COLUMN IF NOT EXISTS deals_damage boolean NOT NULL DEFAULT true;
-- Animations d'attaque du Combat Auto/Manuel, importées du CSV des attaques
-- (colonnes "Animation" / "Animation 2") : PUREMENT VISUEL, aucune fonction SQL
-- ne les lit — seul le client s'en sert (voir src/lib/battleAnimations.ts).
-- animation_2 ne concerne que les capacités en deux temps
-- (autobattle_ability_rules.turn_effect = 'prepare_release') : le tour de
-- préparation joue `animation`, celui qui libère le coup joue `animation_2`.
-- NULL (colonne vide dans le CSV, ou libellé non reconnu) = 'jump_attack', le
-- bond historique sur l'adversaire.
ALTER TABLE attacks ADD COLUMN IF NOT EXISTS animation text;
ALTER TABLE attacks ADD COLUMN IF NOT EXISTS animation_2 text;
ALTER TABLE attacks DROP CONSTRAINT IF EXISTS attacks_animation_check;
ALTER TABLE attacks ADD CONSTRAINT attacks_animation_check
  CHECK (animation IS NULL OR animation IN (
    'idle', 'jump_attack', 'strike', 'stomp', 'beam',
    'projectile', 'multi_projectile', 'bomb', 'round_motion', 'jump', 'fade'
  ));
ALTER TABLE attacks DROP CONSTRAINT IF EXISTS attacks_animation_2_check;
ALTER TABLE attacks ADD CONSTRAINT attacks_animation_2_check
  CHECK (animation_2 IS NULL OR animation_2 IN (
    'idle', 'jump_attack', 'strike', 'stomp', 'beam',
    'projectile', 'multi_projectile', 'bomb', 'round_motion', 'jump', 'fade'
  ));
-- Si autobattle_ability_rules existe déjà (migration précédente déjà appliquée) :
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS repeat_max_iterations integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_turn_effect_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_turn_effect_check
  CHECK (turn_effect IS NULL OR turn_effect IN (
    'skip', 'play_twice', 'play_three', 'play_random', 'repeat_until_fail', 'prepare_release',
    'charge_double_next', 'first_and_replay'
  ));
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_repeat_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_repeat_fields
  CHECK (turn_effect <> 'repeat_until_fail' OR (repeat_max_iterations IS NOT NULL AND repeat_max_iterations >= 1));

-- Statut inversé (s'applique à l'utilisateur de la capacité au lieu de sa
-- cible) — le statut lui-même (attacks.status_effect/status_chance) reste
-- une donnée CSV de la capacité, mais ce booléen est un réglage propre au
-- mode de jeu, géré ici comme turn_effect/heal_type (voir
-- AdminAutoBattleAbilityRulesPanel, gated sur attack.status_effect non nul).
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS status_reversed boolean NOT NULL DEFAULT false;

-- Contre-coup : dégâts infligés à l'utilisateur de la capacité lui-même,
-- après les dégâts portés à l'adversaire. 'range' tire un montant entre
-- recoil_min/recoil_max inclus à CHAQUE coup réussi (une valeur "fixe" est
-- juste un 'range' avec min=max, pas de troisième type) ; 'percent_damage'
-- prend un pourcentage des dégâts (bonus inclus) infligés ce coup-là.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS recoil_type text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS recoil_min integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS recoil_max integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS recoil_percent integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_recoil_type_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_recoil_type_check
  CHECK (recoil_type IS NULL OR recoil_type IN ('range', 'percent_damage'));
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_recoil_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_recoil_fields
  CHECK (
    recoil_type IS NULL
    OR (recoil_type = 'range' AND recoil_min IS NOT NULL AND recoil_max IS NOT NULL AND recoil_min >= 0 AND recoil_max >= recoil_min)
    OR (recoil_type = 'percent_damage' AND recoil_percent IS NOT NULL AND recoil_percent > 0)
  );

-- Invulnérabilité : utiliser cette capacité rend son utilisateur invulnérable
-- à la PROCHAINE attaque adverse (rate automatiquement, quelle que soit sa
-- précision ou les statuts en cours) — consommé une fois puis retiré, voir
-- autobattle_resolve_battle.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS invulnerable_next_turn boolean NOT NULL DEFAULT false;

-- Dégâts additionnels conditionnels : appliqués APRÈS les dégâts de base +
-- dé, avant le contre-coup, uniquement si bonus_damage_condition est vérifiée
-- ce coup-ci. 'multiply' multiplie le total (dégâts arrondis à l'entier
-- inférieur) ; 'flat' ajoute un montant fixe ; 'range' ajoute un montant tiré
-- entre bonus_damage_min/max. Une condition est requise dès qu'un type est
-- choisi (pas de bonus inconditionnel — utiliser le dé/dégâts de base pour
-- ça). 'dice_equals' compare au résultat du dé de CETTE capacité
-- (bonus_damage_condition_dice_value, borné par attacks.degats_de, pas 1-6).
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS bonus_damage_type text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS bonus_damage_multiplier numeric;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS bonus_damage_flat integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS bonus_damage_min integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS bonus_damage_max integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS bonus_damage_condition text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS bonus_damage_condition_dice_value integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_bonus_damage_type_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_bonus_damage_type_check
  CHECK (bonus_damage_type IS NULL OR bonus_damage_type IN ('multiply', 'flat', 'range'));
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_bonus_damage_condition_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_bonus_damage_condition_check
  CHECK (bonus_damage_condition IS NULL OR bonus_damage_condition IN ('took_damage_last_turn', 'first_use', 'dice_equals', 'has_status', 'self_has_status', 'weight_ratio'));
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_bonus_damage_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_bonus_damage_fields
  CHECK (
    bonus_damage_type IS NULL
    OR (
      bonus_damage_condition IS NOT NULL
      AND (bonus_damage_condition <> 'dice_equals' OR bonus_damage_condition_dice_value IS NOT NULL)
      AND (bonus_damage_type <> 'multiply' OR (bonus_damage_multiplier IS NOT NULL AND bonus_damage_multiplier > 0))
      AND (bonus_damage_type <> 'flat' OR bonus_damage_flat IS NOT NULL)
      AND (bonus_damage_type <> 'range' OR (bonus_damage_min IS NOT NULL AND bonus_damage_max IS NOT NULL AND bonus_damage_max >= bonus_damage_min))
    )
  );

-- Filtre de statut pour les conditions 'has_status' / 'self_has_status'
-- ci-dessus : NULL = "n'importe quel statut" (comportement historique,
-- inchangé), sinon un statut PRÉCIS parmi les 7 existants — la condition n'est
-- alors vérifiée que si le camp regardé est affecté par CE statut-là
-- spécifiquement, pas un autre. 'has_status' regarde l'ADVERSAIRE (bonus
-- contre une cible affaiblie), 'self_has_status' regarde L'UTILISATEUR de la
-- capacité (bonus quand on frappe en étant soi-même empoisonné, brûlé...).
-- Sans effet (et ignoré côté RPC) pour les autres conditions.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS bonus_damage_status_filter text;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_bonus_damage_status_filter_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_bonus_damage_status_filter_check
  CHECK (bonus_damage_status_filter IS NULL OR bonus_damage_status_filter IN ('paralysis', 'fear', 'confusion', 'sleep', 'burn', 'poison', 'frozen'));

-- Réglages de la condition 'weight_ratio' ci-dessus : comparaison des POIDS
-- des deux espèces (pokemon.poids, importé du CSV) au moment du coup.
--   bonus_damage_weight_target     = qui est comparé À L'AUTRE ('self' = le
--                                    lanceur, 'opponent' = sa cible) ;
--   bonus_damage_weight_comparison = 'greater' (>) ou 'lower' (<) ;
--   bonus_damage_weight_percent    = pourcentage appliqué au poids de L'AUTRE.
-- Lu : « poids(target) <comparaison> percent % du poids de l'autre ». Les trois
-- exemples de référence : self/greater/200 = « le lanceur pèse plus de 200 % du
-- poids de sa cible » ; opponent/lower/100 = « la cible pèse moins que le
-- lanceur » ; opponent/greater/200 = « la cible pèse plus du double du
-- lanceur ». Poids manquant ou nul d'un côté = condition simplement non
-- remplie (aucun bonus), jamais une erreur. Sans effet pour les autres
-- conditions.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS bonus_damage_weight_target text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS bonus_damage_weight_comparison text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS bonus_damage_weight_percent integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_bonus_damage_weight_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_bonus_damage_weight_check
  CHECK (
    (bonus_damage_weight_target IS NULL OR bonus_damage_weight_target IN ('self', 'opponent'))
    AND (bonus_damage_weight_comparison IS NULL OR bonus_damage_weight_comparison IN ('greater', 'lower'))
    AND (bonus_damage_weight_percent IS NULL OR bonus_damage_weight_percent >= 1)
    -- La condition 'weight_ratio' exige ses trois réglages (les autres
    -- conditions les ignorent et peuvent les laisser à NULL).
    AND (bonus_damage_condition IS DISTINCT FROM 'weight_ratio'
      OR (bonus_damage_weight_target IS NOT NULL AND bonus_damage_weight_comparison IS NOT NULL AND bonus_damage_weight_percent IS NOT NULL))
  );

-- Modificateur de stat (dégâts de base ou précision), appliqué sur un coup
-- réussi soit à l'adversaire du lanceur (stat_mod_target = 'opponent'), soit au
-- lanceur lui-même (stat_mod_target = 'self'). La CIBLE et le SENS sont deux
-- réglages indépendants : stat_mod_direction = 'buff' (hausse) ou 'debuff'
-- (baisse) autorise les quatre combinaisons, dont le malus qu'une capacité
-- s'inflige à elle-même (façon Close Combat). NULL = ancien comportement, où le
-- sens découlait de la cible (adversaire = baisse, soi = hausse) : c'est la
-- valeur de repli du moteur, voir autobattle_stat_mod_signed.
-- 'percent' (stat_mod_percent) n'est valable que
-- pour stat = 'damage', calculé sur les dégâts de base DE COMBAT de la cible
-- tels que calculés en tout début de combat (avant tout modificateur), fixes
-- pour tout le combat. Dure stat_mod_duration_turns tours de combat (compteur
-- global de tours, pas propre à un camp) ou jusqu'à la fin du combat
-- (stat_mod_duration_type = 'battle_end'). stat_mod_max_uses plafonne le
-- nombre d'applications RÉUSSIES sur tout le combat (un raté ne compte pas) ;
-- NULL = illimité. Les modificateurs se CUMULENT : chaque application s'empile
-- avec sa propre échéance (voir autobattle_mod_total), donc deux "+2 dégâts
-- pendant 3 tours" joués coup sur coup donnent +4, puis +2 quand le plus ancien
-- expire. autobattle_ability_rules ne stocke toujours aucun état de combat,
-- juste la config : la pile vit dans le RPC et les colonnes *_damage_mods /
-- *_precision_mods des tables de combat.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_target text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_stat text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_value_type text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_flat integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_min integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_max integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_percent integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_duration_type text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_duration_turns integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_max_uses integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_direction text;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_stat_mod_target_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_stat_mod_target_check
  CHECK (stat_mod_target IS NULL OR stat_mod_target IN ('self', 'opponent'));
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_stat_mod_direction_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_stat_mod_direction_check
  CHECK (stat_mod_direction IS NULL OR stat_mod_direction IN ('buff', 'debuff'));
-- Reprise des règles existantes, écrites quand le sens découlait de la cible :
-- elles gardent exactement le même comportement, désormais explicite.
UPDATE autobattle_ability_rules
   SET stat_mod_direction = CASE WHEN stat_mod_target = 'opponent' THEN 'debuff' ELSE 'buff' END
 WHERE stat_mod_target IS NOT NULL AND stat_mod_direction IS NULL;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_stat_mod_stat_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_stat_mod_stat_check
  CHECK (stat_mod_stat IS NULL OR stat_mod_stat IN ('damage', 'precision'));
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_stat_mod_value_type_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_stat_mod_value_type_check
  CHECK (stat_mod_value_type IS NULL OR stat_mod_value_type IN ('flat', 'range', 'percent'));
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_stat_mod_duration_type_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_stat_mod_duration_type_check
  CHECK (stat_mod_duration_type IS NULL OR stat_mod_duration_type IN ('turns', 'battle_end'));
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_stat_mod_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_stat_mod_fields
  CHECK (
    stat_mod_target IS NULL
    OR (
      stat_mod_stat IS NOT NULL
      AND stat_mod_value_type IS NOT NULL
      AND (stat_mod_value_type <> 'percent' OR stat_mod_stat = 'damage')
      AND (stat_mod_value_type <> 'flat' OR stat_mod_flat IS NOT NULL)
      AND (stat_mod_value_type <> 'range' OR (stat_mod_min IS NOT NULL AND stat_mod_max IS NOT NULL AND stat_mod_max >= stat_mod_min))
      AND (stat_mod_value_type <> 'percent' OR (stat_mod_percent IS NOT NULL AND stat_mod_percent > 0))
      AND stat_mod_duration_type IS NOT NULL
      AND (stat_mod_duration_type <> 'turns' OR (stat_mod_duration_turns IS NOT NULL AND stat_mod_duration_turns >= 1))
      AND (stat_mod_max_uses IS NULL OR stat_mod_max_uses >= 1)
    )
  );

-- Soin passif ("heal over time") : accordé à son utilisateur sur un coup
-- réussi, inflige un certain montant de soin à chaque début de son propre
-- tour pendant heal_dot_duration_turns tours de combat (compteur global,
-- comme stat_mod_duration_turns) — une réapplication rejoue montant+durée
-- (pas de cumul). Indépendant du soin instantané (heal_type/heal_amount/
-- heal_percent) : les deux peuvent coexister sur la même capacité. Bloqué
-- par un Anti-Soin adverse actif (cancel_heal_duration_turns ci-dessous),
-- voir autobattle_resolve_battle. heal_dot_type détermine comment le montant
-- par tour est calculé, résolu en un entier fixe UNE SEULE FOIS au moment où
-- l'effet est accordé (pas recalculé à chaque tick) :
--   'flat' (ou NULL, valeur historique) : heal_dot_amount PV par tour, fixe.
--   'percent_max_hp' : heal_dot_percent % des PV MAX de son utilisateur.
--   'percent_damage' : heal_dot_percent % des dégâts infligés par LE COUP qui
--     a accordé l'effet (comme heal_type = 'percent_damage', mais pour le
--     soin passif).
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS heal_dot_amount integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS heal_dot_duration_turns integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS heal_dot_type text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS heal_dot_percent integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_heal_dot_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_heal_dot_fields
  CHECK (
    (heal_dot_type IS NULL AND heal_dot_amount IS NULL AND heal_dot_percent IS NULL AND heal_dot_duration_turns IS NULL)
    OR (
      heal_dot_duration_turns IS NOT NULL AND heal_dot_duration_turns >= 1
      AND (
        ((heal_dot_type IS NULL OR heal_dot_type = 'flat') AND heal_dot_amount IS NOT NULL AND heal_dot_amount > 0 AND heal_dot_percent IS NULL)
        OR (heal_dot_type IN ('percent_max_hp', 'percent_damage') AND heal_dot_percent IS NOT NULL AND heal_dot_percent >= 1 AND heal_dot_percent <= 100 AND heal_dot_amount IS NULL)
      )
    )
  );

-- Anti-Soin : sur un coup réussi, annule TOUS les effets de soin de
-- l'adversaire (soin instantané, soin passif, guérison du poison par un
-- soin) pendant cancel_heal_duration_turns tours de combat (compteur global).
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS cancel_heal_duration_turns integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_cancel_heal_duration_turns_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_cancel_heal_duration_turns_check
  CHECK (cancel_heal_duration_turns IS NULL OR cancel_heal_duration_turns >= 1);

-- Dégâts en % des PV de la cible : sur un coup réussi, remplace ENTIÈREMENT le
-- calcul de dégâts habituel (dégâts de base + dé + modificateur de stat) par
-- floor(PV de la cible × percent_hp_damage_percent / 100). Les dégâts
-- additionnels conditionnels (bonus_damage_*), le contre-coup, le soin, etc.
-- s'appliquent ensuite normalement, sur CE total. 50 par défaut côté admin
-- (AdminAutoBattleAbilityRulesPanel), pas de défaut SQL forcé.
--
-- percent_hp_damage_basis choisit QUELS PV servent de base :
--   'current' (ou NULL, valeur historique) : les PV ACTUELS de la cible AVANT
--     ce coup — comme "Ultimapoing"/Super Fang, des dégâts qui s'amenuisent à
--     mesure que la cible s'affaiblit et ne peuvent jamais l'achever seuls ;
--   'max' : ses PV MAX, donc un montant CONSTANT pendant tout le combat, qui
--     lui peut mettre K.O.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS percent_hp_damage_percent integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS percent_hp_damage_basis text;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_percent_hp_damage_percent_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_percent_hp_damage_percent_check
  CHECK (percent_hp_damage_percent IS NULL OR (percent_hp_damage_percent >= 1 AND percent_hp_damage_percent <= 100));
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_percent_hp_damage_basis_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_percent_hp_damage_basis_check
  CHECK (percent_hp_damage_basis IS NULL OR percent_hp_damage_basis IN ('current', 'max'));

-- Filtre de TYPE sur le modificateur de stat (stat_mod_*, uniquement pour
-- stat = 'damage') : NULL = le modificateur s'applique à toutes les capacités
-- (comportement historique), sinon il ne s'applique QUE lorsque la capacité
-- jouée est de ce type élémentaire (attacks.type, comparé sans casse ni
-- espaces superflus). C'est ce qui permet un buff du genre "+10 dégâts sur
-- les capacités Feu" : le montant reste flat/fourchette/% comme avant, seul
-- le champ d'application change. Le filtre voyage avec le modificateur ACTIF
-- (chaque entrée de la pile *_damage_mods porte le sien, voir
-- autobattle_mod_total), pas avec la capacité qui attaque — voir
-- autobattle_resolve_round_core.
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
-- (keep_going_bonus_type = 'flat'), soit un pourcentage des dégâts de base du
-- POKÉMON ('percent_damage') — sa composante espèce + bonus XP seule, sans les
-- dégâts propres de la capacité ni le x2 d'efficacité de type (damage_species_xp,
-- pas base_damage), pour qu'un même pourcentage rapporte la même chose quelle
-- que soit la capacité qui porte l'effet. La chaîne s'interrompt au premier RATÉ
-- (précision manquée, ou cible invulnérable) OU au premier tour entièrement
-- PASSÉ à cause d'un statut bloquant (paralysie, gel, sommeil) : la capacité
-- cesse alors d'être imposée et le tour suivant redevient un choix libre. Une
-- capacité qui ignore le statut en question (ignore_status_block) agit
-- normalement et poursuit donc sa chaîne.
-- Deux durées possibles, exclusives l'une de l'autre :
--   keep_going_turns = N        : N réutilisations forcées, puis la main est
--                                 rendue (soit N+1 utilisations en tout).
--   keep_going_until_fail = true: la capacité se rejoue INDÉFINIMENT, une fois
--                                 par tour, jusqu'au premier raté — le bonus
--                                 cumulatif n'a alors pas de plafond.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS keep_going_turns integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS keep_going_until_fail boolean NOT NULL DEFAULT false;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS keep_going_bonus_type text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS keep_going_bonus_flat integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS keep_going_bonus_percent integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_keep_going_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_keep_going_fields
  CHECK (
    (keep_going_turns IS NULL AND NOT keep_going_until_fail)
    OR (
      -- Les deux durées sont exclusives : soit un nombre de tours, soit
      -- "jusqu'à l'échec", jamais les deux.
      (
        (keep_going_turns IS NOT NULL AND keep_going_turns >= 1 AND NOT keep_going_until_fail)
        OR (keep_going_until_fail AND keep_going_turns IS NULL)
      )
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

-- ── Effets persistants OFFENSIFS : dégâts et vol de vie par tour ────────────
-- Miroirs exacts du soin passif ci-dessus, mais posés sur l'ADVERSAIRE par un
-- coup réussi (voir la branche d'octroi de autobattle_resolve_round_core) :
--   damage_dot_* = "damage over time", la victime perd des PV au début de
--                  CHACUN DE SES tours pendant damage_dot_duration_turns tours
--                  de combat (un tick peut mettre K.O.) ;
--   leech_dot_*  = "life steal over time", mêmes règles, mais les PV perdus
--                  sont rendus au LANCEUR (plafonnés à ce qu'il reste à la
--                  victime, et à ses propres PV max) ; la part soin est
--                  annulée si le voleur subit un Anti-Soin.
-- Montant résolu UNE FOIS à l'octroi, jamais recalculé au tick :
--   type 'flat' (ou NULL) : *_amount PV par tour ;
--   type 'percent_max_hp' : *_percent % des PV MAX de la VICTIME (« % des PV
--                           de l'adversaire »), *_amount restant NULL.
-- Réutiliser la capacité REMPOSE l'effet (montant et échéance réécrits), comme
-- le soin passif.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS damage_dot_type text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS damage_dot_amount integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS damage_dot_percent integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS damage_dot_duration_turns integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_damage_dot_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_damage_dot_fields
  CHECK (
    (damage_dot_type IS NULL AND damage_dot_amount IS NULL AND damage_dot_percent IS NULL AND damage_dot_duration_turns IS NULL)
    OR (
      damage_dot_duration_turns IS NOT NULL AND damage_dot_duration_turns >= 1
      AND (
        ((damage_dot_type IS NULL OR damage_dot_type = 'flat') AND damage_dot_amount IS NOT NULL AND damage_dot_amount > 0 AND damage_dot_percent IS NULL)
        OR (damage_dot_type = 'percent_max_hp' AND damage_dot_percent IS NOT NULL AND damage_dot_percent >= 1 AND damage_dot_percent <= 100 AND damage_dot_amount IS NULL)
      )
    )
  );

ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS leech_dot_type text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS leech_dot_amount integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS leech_dot_percent integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS leech_dot_duration_turns integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_leech_dot_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_leech_dot_fields
  CHECK (
    (leech_dot_type IS NULL AND leech_dot_amount IS NULL AND leech_dot_percent IS NULL AND leech_dot_duration_turns IS NULL)
    OR (
      leech_dot_duration_turns IS NOT NULL AND leech_dot_duration_turns >= 1
      AND (
        ((leech_dot_type IS NULL OR leech_dot_type = 'flat') AND leech_dot_amount IS NOT NULL AND leech_dot_amount > 0 AND leech_dot_percent IS NULL)
        OR (leech_dot_type = 'percent_max_hp' AND leech_dot_percent IS NOT NULL AND leech_dot_percent >= 1 AND leech_dot_percent <= 100 AND leech_dot_amount IS NULL)
      )
    )
  );

-- ── Tentative de statut persistante ─────────────────────────────────────────
-- Troisième effet persistant OFFENSIF, sur le même modèle que les deux
-- ci-dessus (posé sur l'adversaire par un coup réussi, actif pendant
-- status_dot_duration_turns tours de combat) : à chacun des tours de la
-- VICTIME, status_dot_chance % de chances de lui infliger status_dot_status.
-- Deux règles, alignées sur le statut de terrain de la météo :
--   * la tentative n'a lieu QUE si la victime n'a aucun statut (un seul statut
--     à la fois, et un effet qui écraserait le sien à chaque tour serait
--     ingérable) — l'effet continue donc de « guetter » tant qu'il dure ;
--   * la cible peut encore le neutraliser par un talent (autobattle_talent_
--     status_guard : 'status_immunity', 'auto_cure_first_status').
-- Le jet a lieu APRÈS le tick de statut de la victime, comme un statut infligé
-- par une attaque : il ne mord donc qu'à partir de son tour suivant. Un jet
-- raté ne produit aucun tour de journal (sinon une ligne inutile par tour).
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS status_dot_status text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS status_dot_chance integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS status_dot_duration_turns integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_status_dot_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_status_dot_fields
  CHECK (
    (status_dot_status IS NULL AND status_dot_chance IS NULL AND status_dot_duration_turns IS NULL)
    OR (
      status_dot_status IN ('paralysis', 'fear', 'confusion', 'sleep', 'burn', 'poison', 'frozen')
      AND status_dot_chance IS NOT NULL AND status_dot_chance >= 1 AND status_dot_chance <= 100
      AND status_dot_duration_turns IS NOT NULL AND status_dot_duration_turns >= 1
    )
  );

-- ── Purges (capacités de « nettoyage ») ─────────────────────────────────────
-- Trois effets indépendants, appliqués sur un coup réussi et cumulables entre
-- eux comme avec le reste :
--   clear_damage_dot = retire les EFFETS PERSISTANTS que subit son LANCEUR :
--                      les trois posés par une capacité (damage_dot, leech_dot
--                      et la tentative de statut status_dot). Ne touche NI aux
--                      statuts eux-mêmes (brûlure, poison — ils gardent leurs
--                      propres ticks et leurs propres guérisons, voir
--                      cure_status), NI à la météo, qui a sa purge dédiée ;
--   clear_weather    = dissipe la météo en cours, quelle qu'elle soit — état
--                      de TERRAIN partagé, donc pour les deux camps ;
--   cure_status      = guérit le statut de son LANCEUR, quel qu'il soit.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS clear_damage_dot boolean NOT NULL DEFAULT false;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS clear_weather boolean NOT NULL DEFAULT false;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS cure_status boolean NOT NULL DEFAULT false;

-- ── Capacité conditionnée au statut de la cible ─────────────────────────────
-- « Ne fonctionne que sur une cible atteinte de [statut] » (genre "Croque
-- Rêve", inutilisable sur une cible éveillée) : si la cible n'est PAS affectée
-- par exactement ce statut au moment du coup, la capacité échoue purement et
-- simplement — traité comme un raté (texte dédié côté client, chaîne "Continue
-- sur sa lancée" interrompue, rafale stoppée), sans aucun effet ni dégât.
-- NULL = aucune condition (comportement historique).
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS requires_target_status text;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_requires_target_status_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_requires_target_status_check
  CHECK (requires_target_status IS NULL OR requires_target_status IN ('paralysis', 'fear', 'confusion', 'sleep', 'burn', 'poison', 'frozen'));

-- ── Perce-immunité (lève une immunité de type pendant X tours) ──────────────
-- pierce_immunity_type = le type de POKÉMON dont l'immunité tombe (« Spectre »
-- pour qu'une capacité Normal puisse enfin le toucher, voir type_no_effect) —
-- pas le type de la capacité, qui est déjà connu. L'effet profite au LANCEUR
-- seul : dès ce coup-ci (sans quoi, immunisée elle-même, la capacité ne
-- pourrait jamais toucher pour poser l'effet) puis pendant
-- pierce_immunity_turns tours de combat, toutes ses capacités ignorent
-- l'immunité de ce type-là. Aucune contrainte sur le libellé du type : il est
-- comparé normalisé (voir type_norm), comme partout ailleurs.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS pierce_immunity_type text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS pierce_immunity_turns integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_pierce_immunity_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_pierce_immunity_fields
  CHECK (
    (pierce_immunity_type IS NULL AND pierce_immunity_turns IS NULL)
    OR (btrim(COALESCE(pierce_immunity_type, '')) <> '' AND pierce_immunity_turns IS NOT NULL AND pierce_immunity_turns >= 1)
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

-- OBSOLÈTE — plus lue par personne (ni les RPC, qui ne l'ont jamais lue, ni le
-- client depuis que l'animation vient uniquement des colonnes "Animation" /
-- "Animation 2" du CSV des attaques, voir attacks.animation plus haut et
-- src/lib/battleAnimations.ts). Le réglage correspondant a été retiré de
-- AdminAutoBattleAbilityRulesPanel. Conservée telle quelle (NOT NULL DEFAULT
-- 'normal', donc sans effet sur les insertions) pour ne rien casser sur les
-- bases existantes ; supprimable par un DROP COLUMN si besoin de faire le
-- ménage.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS animation_style text NOT NULL DEFAULT 'normal';
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_animation_style_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_animation_style_check
  CHECK (animation_style IN ('normal', 'soft'));

-- ============================================================
-- Météo (effets de TERRAIN, voir AdminAutoBattleWeathersPanel)
-- ============================================================
-- Troisième couche d'effets configurables, après les capacités (par capacité) et
-- les talents (par espèce) : la météo est partagée par LES DEUX camps et une
-- SEULE peut être active à la fois — en déclencher une remplace la précédente.
-- Elle est PERMANENTE (aucune durée en tours) : elle dure jusqu'à son
-- remplacement ou la fin du combat, et repart toujours à « aucune » au combat
-- suivant (rien n'est persisté entre deux combats).
--
-- Une météo n'est qu'un NOM + une liste d'effets : une météo sans aucun effet
-- est parfaitement valide et sert alors uniquement de condition pour les
-- buff/debuff des talents et des capacités (voir weather_condition plus bas).
--
-- animation : jouée au moment où la météo se lève (mêmes identifiants que
-- attacks.animation, voir src/lib/battleAnimations.ts) — NULL = 'idle'.
CREATE TABLE IF NOT EXISTS autobattle_weathers (
  id          bigserial PRIMARY KEY,
  nom         text NOT NULL UNIQUE,
  animation   text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Emoji affiché en combat, dans la pastille ronde posée entre les deux noms de
-- pokémon (voir AutoBattleScreen) — un clic dessus ouvre la description de la
-- météo. Texte libre plutôt qu'une liste fermée : l'admin colle l'emoji qu'il
-- veut. Vide/NULL = pastille repliée sur un emoji générique côté client.
ALTER TABLE autobattle_weathers ADD COLUMN IF NOT EXISTS icon text;

ALTER TABLE autobattle_weathers DROP CONSTRAINT IF EXISTS autobattle_weathers_animation_check;
ALTER TABLE autobattle_weathers ADD CONSTRAINT autobattle_weathers_animation_check
  CHECK (animation IS NULL OR animation IN (
    'idle', 'jump_attack', 'strike', 'stomp', 'beam', 'projectile',
    'multi_projectile', 'bomb', 'round_motion', 'jump', 'fade'));

-- Effets d'une météo — plusieurs par météo (ex. une tempête de sable qui baisse
-- la précision ET inflige des dégâts chaque tour).
--
-- kind :
--   'stat_mod'        modifie une stat (dégâts ou précision) de amount (signé,
--                     mêmes unités que autobattle_talents.amount : la précision
--                     est sur 10). target_scope dit à quoi type_filter se
--                     compare : au type d'ESPÈCE du pokémon ('pokemon_type',
--                     ex. « les pokémon Feu gagnent +1 précision ») ou au type
--                     de la CAPACITÉ jouée ('ability_type', ex. « les attaques
--                     Feu font +1 dégât »).
--   'inflict_status'  chaque tour, percent % de chances d'infliger `status` aux
--                     pokémon dont le type figure dans type_filter.
--   'damage'          chaque tour, percent % de chances d'infliger damage_amount
--                     dégâts aux pokémon dont le type figure dans type_filter.
--
-- type_filter est une liste d'INCLUSION : vide ou NULL = TOUS les types (même
-- convention que autobattle_talents.type_filter avec p_empty = true, voir
-- autobattle_talent_type_match). Pour « tous sauf Sol et Roche », l'UI admin
-- offre un bouton « tout cocher » puis on décoche les deux.
--
-- Les ticks 'inflict_status' / 'damage' se jouent UNE fois par tour de combat,
-- pour les DEUX pokémon (chacun son propre jet), AVANT tout le reste du tour —
-- avant les priorités, avant les ticks de statut, avant les capacités. Voir
-- autobattle_weather_tick.
CREATE TABLE IF NOT EXISTS autobattle_weather_effects (
  id            bigserial PRIMARY KEY,
  weather_id    bigint NOT NULL REFERENCES autobattle_weathers(id) ON DELETE CASCADE,
  kind          text NOT NULL DEFAULT 'stat_mod',
  stat          text,
  amount        integer,
  target_scope  text,
  status        text,
  percent       integer,
  damage_amount integer,
  type_filter   text[],
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_autobattle_weather_effects_weather_id ON autobattle_weather_effects(weather_id);

ALTER TABLE autobattle_weather_effects DROP CONSTRAINT IF EXISTS autobattle_weather_effects_kind_check;
ALTER TABLE autobattle_weather_effects ADD CONSTRAINT autobattle_weather_effects_kind_check
  CHECK (kind IN ('stat_mod', 'inflict_status', 'damage'));
ALTER TABLE autobattle_weather_effects DROP CONSTRAINT IF EXISTS autobattle_weather_effects_stat_check;
ALTER TABLE autobattle_weather_effects ADD CONSTRAINT autobattle_weather_effects_stat_check
  CHECK (stat IS NULL OR stat IN ('damage', 'precision'));
ALTER TABLE autobattle_weather_effects DROP CONSTRAINT IF EXISTS autobattle_weather_effects_scope_check;
ALTER TABLE autobattle_weather_effects ADD CONSTRAINT autobattle_weather_effects_scope_check
  CHECK (target_scope IS NULL OR target_scope IN ('pokemon_type', 'ability_type'));
-- Mêmes valeurs que attacks.status_effect (pas de 'any' ici : on inflige un
-- statut PRÉCIS).
ALTER TABLE autobattle_weather_effects DROP CONSTRAINT IF EXISTS autobattle_weather_effects_status_check;
ALTER TABLE autobattle_weather_effects ADD CONSTRAINT autobattle_weather_effects_status_check
  CHECK (status IS NULL OR status IN ('paralysis', 'fear', 'confusion', 'sleep', 'burn', 'poison', 'frozen'));
ALTER TABLE autobattle_weather_effects DROP CONSTRAINT IF EXISTS autobattle_weather_effects_percent_check;
ALTER TABLE autobattle_weather_effects ADD CONSTRAINT autobattle_weather_effects_percent_check
  CHECK (percent IS NULL OR percent BETWEEN 1 AND 100);

-- Champs obligatoires par kind — l'UI admin envoie toujours un groupe cohérent,
-- ces contraintes ne font qu'empêcher une configuration inexploitable.
ALTER TABLE autobattle_weather_effects DROP CONSTRAINT IF EXISTS autobattle_weather_effects_fields;
ALTER TABLE autobattle_weather_effects ADD CONSTRAINT autobattle_weather_effects_fields
  CHECK (
    (kind = 'stat_mod' AND stat IS NOT NULL AND amount IS NOT NULL AND target_scope IS NOT NULL)
    OR (kind = 'inflict_status' AND status IS NOT NULL AND percent IS NOT NULL)
    OR (kind = 'damage' AND damage_amount IS NOT NULL AND damage_amount > 0 AND percent IS NOT NULL)
  );

ALTER TABLE autobattle_weathers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read autobattle_weathers" ON autobattle_weathers;
DROP POLICY IF EXISTS "Public insert autobattle_weathers" ON autobattle_weathers;
DROP POLICY IF EXISTS "Public update autobattle_weathers" ON autobattle_weathers;
DROP POLICY IF EXISTS "Public delete autobattle_weathers" ON autobattle_weathers;
CREATE POLICY "Public read autobattle_weathers"   ON autobattle_weathers FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_weathers" ON autobattle_weathers FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_weathers" ON autobattle_weathers FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete autobattle_weathers" ON autobattle_weathers FOR DELETE TO anon USING (true);

ALTER TABLE autobattle_weather_effects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read autobattle_weather_effects" ON autobattle_weather_effects;
DROP POLICY IF EXISTS "Public insert autobattle_weather_effects" ON autobattle_weather_effects;
DROP POLICY IF EXISTS "Public update autobattle_weather_effects" ON autobattle_weather_effects;
DROP POLICY IF EXISTS "Public delete autobattle_weather_effects" ON autobattle_weather_effects;
CREATE POLICY "Public read autobattle_weather_effects"   ON autobattle_weather_effects FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert autobattle_weather_effects" ON autobattle_weather_effects FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update autobattle_weather_effects" ON autobattle_weather_effects FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Public delete autobattle_weather_effects" ON autobattle_weather_effects FOR DELETE TO anon USING (true);

-- Déclenchement d'une météo PAR UNE CAPACITÉ (façon Danse Pluie) : à chaque
-- utilisation réussie (coup non raté), weather_chance % de chances de lever
-- weather_id. ON DELETE SET NULL : supprimer une météo ne casse aucune règle —
-- le moteur ignore simplement une règle dont la météo a disparu.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS weather_id bigint REFERENCES autobattle_weathers(id) ON DELETE SET NULL;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS weather_chance integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_weather_chance_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_weather_chance_check
  CHECK (weather_chance IS NULL OR weather_chance BETWEEN 1 AND 100);

-- Condition « météo active » du modificateur de stat (le buff/debuff de la
-- capacité) : NULL = aucune condition, 'any' = n'importe quelle météo active,
-- 'none' = aucune météo active, 'this' = la météo stat_mod_weather_id.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_weather_condition text;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS stat_mod_weather_id bigint REFERENCES autobattle_weathers(id) ON DELETE SET NULL;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_stat_mod_weather_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_stat_mod_weather_check
  CHECK (stat_mod_weather_condition IS NULL OR stat_mod_weather_condition IN ('any', 'none', 'this'));

-- ============================================================
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
--                          dégâts de base et movepool —
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
--   'set_weather'          lève la météo weather_id avec percent % de chances, au
--                          moment donné par trigger (mêmes valeurs que
--                          'inflict_status' : 'battle_start', 'each_turn' ou
--                          'on_ability_type'). Une météo déjà en cours est
--                          REMPLACÉE ; si c'est déjà celle-là, rien ne se passe.
--                          Voir autobattle_weathers.
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

-- Météo (voir autobattle_weathers). weather_id = celle que lève un talent
-- 'set_weather' ; weather_condition/weather_condition_id = condition « météo en
-- cours » d'un 'stat_boost' (NULL = aucune condition, 'any' = n'importe quelle
-- météo, 'none' = aucune météo, 'this' = celle de weather_condition_id).
-- ON DELETE SET NULL des deux côtés : supprimer une météo ne supprime jamais un
-- talent, le moteur ignore simplement la règle devenue incomplète.
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS weather_id bigint REFERENCES autobattle_weathers(id) ON DELETE SET NULL;
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS weather_condition text;
ALTER TABLE autobattle_talents ADD COLUMN IF NOT EXISTS weather_condition_id bigint REFERENCES autobattle_weathers(id) ON DELETE SET NULL;
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_weather_condition_check;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_weather_condition_check
  CHECK (weather_condition IS NULL OR weather_condition IN ('any', 'none', 'this'));

ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_kind_check;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_kind_check
  CHECK (kind IN (
    'stat_boost', 'absorb_first_damage', 'endure_ko',
    'poison_damage_boost', 'burn_damage_boost', 'priority', 'inflict_status',
    'status_immunity', 'type_immunity', 'type_damage_to_heal', 'no_recoil',
    'dice_bonus_damage', 'auto_cure_first_status', 'invulnerable_until_hit',
    'heal_below_hp', 'transform', 'heavy_sleeper', 'set_weather',
    'cancel_talents'));
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
-- 'set_weather' : weather_id n'est VOLONTAIREMENT pas exigé (ON DELETE SET NULL
-- doit pouvoir le vider sans faire échouer la suppression d'une météo) — le
-- moteur ignore un talent sans météo et l'admin l'affiche comme incomplet.
ALTER TABLE autobattle_talents DROP CONSTRAINT IF EXISTS autobattle_talents_set_weather_fields;
ALTER TABLE autobattle_talents ADD CONSTRAINT autobattle_talents_set_weather_fields
  CHECK (
    kind <> 'set_weather'
    OR (percent IS NOT NULL AND percent BETWEEN 1 AND 100 AND trigger IS NOT NULL)
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

-- Ticket Combat : catalogue seedé une fois (RLS bloque l'écriture anon
-- sur items, donc à exécuter manuellement via l'éditeur SQL Supabase — même
-- caveat que "Ticket Fouille" plus haut dans ce fichier).
-- INSERT INTO items (nom, type, achat, vente, description, image_url)
-- VALUES ('Ticket Combat', 'Monnaie', 0, 0, 'Permet de lancer un combat automatique.', '/website_icons/icon_battle_ticket.png')
-- ON CONFLICT (nom) DO NOTHING;

ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_autobattle_enabled boolean NOT NULL DEFAULT true;

-- Somme des bonus XP (PV ou DMG) d'une espèce jusqu'à un XP donné — portage SQL
-- de getHpBonus/getDamageBonus (src/lib/xpBonuses.ts) : chaque case xp_10..xp_100
-- est un texte libre, seules celles au format "+N PV"/"+N DMG" comptent, sommées
-- pour tout palier <= p_xp. p_kind vaut 'PV' ou 'DMG'.
CREATE OR REPLACE FUNCTION autobattle_xp_bonus(p_pokemon_nom text, p_xp integer, p_kind text)
RETURNS integer
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(SUM((m.match)[1]::integer), 0)::integer
  FROM (
    SELECT t.threshold, regexp_match(trim(t.cell), '^\+\s*(\d+)\s*(PV|DMG)$', 'i') AS match
    FROM pokemon p,
    LATERAL (VALUES
      (10, p.xp_10), (20, p.xp_20), (30, p.xp_30), (40, p.xp_40), (50, p.xp_50),
      (60, p.xp_60), (70, p.xp_70), (80, p.xp_80), (90, p.xp_90), (100, p.xp_100)
    ) AS t(threshold, cell)
    WHERE p.nom = p_pokemon_nom
  ) m
  WHERE m.match IS NOT NULL AND m.threshold <= p_xp AND upper((m.match)[2]) = upper(p_kind)
$$;

-- Palier XP maximum configuré pour une espèce (case xp_* non vide la plus
-- haute, quel que soit son contenu) — portage SQL de getMaxXp, utilisé pour
-- plafonner l'XP gagnée en Combat Auto (même règle que clampXp côté client).
-- NULL si l'espèce n'a aucun palier configuré (= pas de plafond, comme côté client).
CREATE OR REPLACE FUNCTION autobattle_max_xp(p_pokemon_nom text)
RETURNS integer
LANGUAGE sql STABLE
AS $$
  SELECT MAX(t.threshold)::integer
  FROM pokemon p,
  LATERAL (VALUES
    (10, p.xp_10), (20, p.xp_20), (30, p.xp_30), (40, p.xp_40), (50, p.xp_50),
    (60, p.xp_60), (70, p.xp_70), (80, p.xp_80), (90, p.xp_90), (100, p.xp_100)
  ) AS t(threshold, cell)
  WHERE p.nom = p_pokemon_nom AND trim(COALESCE(t.cell, '')) <> ''
$$;

-- Nombre d'attaques consécutives qu'un côté joue avant que le tour ne passe à
-- l'autre, pour la capacité donnée : 1 par défaut (aucune règle configurée
-- ou 'skip' — 'skip' est géré séparément dans autobattle_resolve_battle via
-- v_player_skip_pending/v_opponent_skip_pending, PAS ici, car il s'agit d'une
-- alternance attaque/passe et non d'un nombre d'attaques consécutives), 2/3
-- pour 'play_twice'/'play_three', ou un tirage entre turn_random_min/max pour
-- 'play_random' — retiré au sort à CHAQUE nouvelle activation (pas une seule
-- fois pour tout le combat), voir autobattle_resolve_battle.
CREATE OR REPLACE FUNCTION autobattle_ability_burst(p_attack_nom text)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_rule record;
BEGIN
  SELECT * INTO v_rule FROM autobattle_ability_rules WHERE attack_nom = p_attack_nom;
  IF v_rule IS NULL OR v_rule.turn_effect IS NULL THEN
    RETURN 1;
  END IF;
  CASE v_rule.turn_effect
    WHEN 'play_twice' THEN RETURN 2;
    WHEN 'play_three' THEN RETURN 3;
    WHEN 'play_random' THEN RETURN v_rule.turn_random_min + floor(random() * (v_rule.turn_random_max - v_rule.turn_random_min + 1))::integer;
    ELSE RETURN 1;
  END CASE;
END;
$$;

GRANT EXECUTE ON FUNCTION autobattle_ability_burst(text) TO anon, authenticated;

-- ============================================================
-- Table des types (efficacité et immunités)
-- ============================================================
-- L'efficacité dépend du TYPE DE LA CAPACITÉ jouée face au TYPE DU POKÉMON
-- DÉFENSEUR — plus des colonnes pokemon.super_efficace_1..4 de l'espèce
-- attaquante (toujours importées depuis le CSV, mais devenues inutilisées),
-- et plus d'aucune condition « la capacité doit être du type de son lanceur ».
--   type_super_effective = dégâts de base x2 (voir *_type_bonus chez les
--                          appelants, le x2 lui-même n'a pas changé) ;
--   type_no_effect       = immunité TOTALE : la capacité ne fait rien du tout
--                          si elle vise l'adversaire (voir la branche
--                          « aucun effet » de autobattle_resolve_round_core /
--                          autobattle_resolve_battle) ; une capacité
--                          auto-ciblée (soin/buff sur soi, météo) reste jouée
--                          normalement.
-- Doublon assumé côté client dans src/lib/typeChart.ts (badges des écrans de
-- sélection + tableau récapitulatif admin) : toute modification de la table
-- doit être faite AUX DEUX ENDROITS.

-- Libellé de type normalisé : minuscules, sans accent, alias ramenés au
-- libellé canonique — les données mélangent « Électrik »/« Electrik »,
-- « Fée »/« Fee », « Ténèbres »/« Tenebr » (CSV des attaques),
-- « Fantôme »/« Spectre » (voir TYPE_COLORS côté client, mêmes alias).
CREATE OR REPLACE FUNCTION type_norm(p_type text)
RETURNS text
LANGUAGE sql IMMUTABLE
AS $$
  WITH n AS (
    SELECT lower(translate(trim(COALESCE(p_type, '')),
      'ÀÁÂÄÃÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÇàáâäãéèêëíìîïóòôöõúùûüç',
      'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc')) AS t
  )
  SELECT CASE t
    WHEN 'fantome' THEN 'spectre'
    WHEN 'tenebr'  THEN 'tenebres'
    WHEN 'metal'   THEN 'acier'
    ELSE t
  END
  FROM n
$$;

GRANT EXECUTE ON FUNCTION type_norm(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION type_super_effective(p_ability_type text, p_defender_type text)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM (VALUES
      ('acier', 'fee'), ('acier', 'glace'), ('acier', 'roche'),
      ('combat', 'acier'), ('combat', 'glace'), ('combat', 'normal'), ('combat', 'roche'), ('combat', 'tenebres'),
      ('dragon', 'dragon'),
      ('eau', 'feu'), ('eau', 'roche'), ('eau', 'sol'),
      ('electrik', 'eau'), ('electrik', 'vol'),
      ('fee', 'combat'), ('fee', 'dragon'), ('fee', 'tenebres'),
      ('feu', 'acier'), ('feu', 'glace'), ('feu', 'insecte'), ('feu', 'plante'),
      ('glace', 'dragon'), ('glace', 'plante'), ('glace', 'sol'), ('glace', 'vol'),
      ('insecte', 'plante'), ('insecte', 'psy'), ('insecte', 'tenebres'),
      -- Normal : super efficace contre aucun type.
      ('plante', 'eau'), ('plante', 'roche'), ('plante', 'sol'),
      ('poison', 'combat'), ('poison', 'plante'),
      ('psy', 'combat'), ('psy', 'poison'),
      ('roche', 'feu'), ('roche', 'glace'), ('roche', 'insecte'), ('roche', 'vol'),
      ('sol', 'acier'), ('sol', 'electrik'), ('sol', 'feu'), ('sol', 'poison'), ('sol', 'roche'),
      ('spectre', 'psy'), ('spectre', 'spectre'),
      ('tenebres', 'psy'), ('tenebres', 'spectre'),
      ('vol', 'combat'), ('vol', 'insecte'), ('vol', 'plante')
    ) AS t(atk, def)
    WHERE t.atk = type_norm(p_ability_type)
      AND t.def = type_norm(p_defender_type)
  )
$$;

GRANT EXECUTE ON FUNCTION type_super_effective(text, text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION type_no_effect(p_ability_type text, p_defender_type text)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM (VALUES
      ('combat', 'spectre'),
      ('dragon', 'fee'),
      ('electrik', 'sol'),
      ('normal', 'spectre'),
      ('poison', 'acier'),
      ('psy', 'tenebres'),
      ('sol', 'vol'),
      ('spectre', 'normal')
    ) AS t(atk, def)
    WHERE t.atk = type_norm(p_ability_type)
      AND t.def = type_norm(p_defender_type)
  )
$$;

GRANT EXECUTE ON FUNCTION type_no_effect(text, text) TO anon, authenticated;

-- Immunités de STATUT propres à un type d'espèce (requirement) : un pokémon de
-- ce type ne peut JAMAIS recevoir ce statut, quelle qu'en soit la source —
-- capacité, talent 'inflict_status', tentative persistante (status_dot) ou
-- statut de terrain d'une météo.
--   Acier → Poison        Feu → Brûlure        Glace → Gel
-- Contrairement au talent 'status_immunity', cette immunité ne dépend d'aucune
-- donnée d'admin et ne peut donc être ni désactivée par la bascule globale des
-- talents (autobattle_config.talents_enabled) ni annulée par 'cancel_talents' :
-- elle est vérifiée dans autobattle_talent_status_guard, avant les talents.
-- Silencieuse comme 'status_immunity' : le statut est simplement ignoré, aucun
-- tour de journal n'est émis (sinon le client allumerait un badge que plus
-- aucun tick ne viendrait éteindre).
CREATE OR REPLACE FUNCTION autobattle_status_type_immune(p_pokemon_type text, p_status text)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM (VALUES
      ('acier', 'poison'),
      ('feu',   'burn'),
      ('glace', 'frozen')
    ) AS t(pokemon_type, status)
    WHERE t.pokemon_type = type_norm(p_pokemon_type)
      AND t.status = p_status
  )
$$;

GRANT EXECUTE ON FUNCTION autobattle_status_type_immune(text, text) TO anon, authenticated;

-- ============================================================
-- Modificateurs de stat EMPILABLES (voir autobattle_ability_rules.stat_mod_*)
-- ============================================================
-- Chaque application ajoute une entrée à un tableau jsonb au lieu d'écraser la
-- précédente : deux buffs "+2 dégâts pendant 3 tours" joués coup sur coup
-- donnent bien +4, chacun s'éteignant à SA propre échéance (le plus ancien
-- retombe donc à +2 avant de disparaître). Une entrée vaut
--   {"a": montant signé, "e": numéro de round d'expiration, "t": type filtré}
-- où "t" est absent/NULL sauf pour un modificateur de dégâts restreint à un
-- type de capacité (stat_mod_type_filter), et où "e" vaut 999999 pour une
-- durée "jusqu'à la fin du combat".
--
-- autobattle_mod_total additionne les entrées encore actives au round donné —
-- en ne gardant que celles dont le filtre de type correspond à la capacité
-- jouée (p_ability_type NULL = pas de filtrage, cas de la précision).
CREATE OR REPLACE FUNCTION autobattle_mod_total(p_mods jsonb, p_round integer, p_ability_type text)
RETURNS integer
LANGUAGE sql IMMUTABLE
AS $$
  SELECT COALESCE(SUM((m ->> 'a')::integer), 0)::integer
  FROM jsonb_array_elements(COALESCE(p_mods, '[]'::jsonb)) m
  WHERE p_round <= (m ->> 'e')::integer
    AND (
      (m ->> 't') IS NULL
      OR lower(trim(m ->> 't')) = lower(trim(COALESCE(p_ability_type, '')))
    )
$$;

-- Retire les entrées expirées — purement cosmétique pour le moteur (total
-- ci-dessus les ignore déjà), mais évite que la pile persistée ne grossisse
-- indéfiniment sur un long combat.
CREATE OR REPLACE FUNCTION autobattle_mod_purge(p_mods jsonb, p_round integer)
RETURNS jsonb
LANGUAGE sql IMMUTABLE
AS $$
  SELECT COALESCE(jsonb_agg(m), '[]'::jsonb)
  FROM jsonb_array_elements(COALESCE(p_mods, '[]'::jsonb)) m
  WHERE p_round <= (m ->> 'e')::integer
$$;

GRANT EXECUTE ON FUNCTION autobattle_mod_total(jsonb, integer, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_mod_purge(jsonb, integer) TO anon, authenticated;

-- ============================================================
-- Météo : helpers de base (lecture, filtres, conditions)
-- ============================================================
-- La météo courante circule dans les moteurs sous forme d'un seul jsonb :
--   {"id": N, "nom": "...", "animation": "...", "effects": [ligne de table, ...]}
-- ou SQL NULL quand il n'y a pas de météo. Les helpers de PHASE (levée, tick de
-- début de tour) sont plus bas, après les talents — ils s'appuient dessus.
--
-- Les helpers ci-dessous sont volontairement tolérants au NULL : « pas de
-- météo » est l'état normal, pas un cas d'erreur.

-- p_enabled = bascule globale du mode (autobattle_config.weather_enabled ou
-- pvp_config.weather_enabled) : à faux, renvoie toujours NULL et TOUT le système
-- de météo devient inerte, exactement comme autobattle_talents_for pour les
-- talents. Renvoie NULL aussi si la météo a été supprimée entre-temps.
CREATE OR REPLACE FUNCTION autobattle_weather_for(p_weather_id bigint, p_enabled boolean DEFAULT true)
RETURNS jsonb
LANGUAGE sql STABLE
AS $$
  SELECT CASE WHEN COALESCE(p_enabled, true) AND p_weather_id IS NOT NULL THEN (
    SELECT jsonb_build_object(
      'id', w.id,
      'nom', w.nom,
      'icon', w.icon,
      'animation', w.animation,
      -- Univers des types, embarqué ici pour que la description d'un effet
      -- puisse dire « tous types sauf Sol, Roche » (voir
      -- autobattle_weather_type_list) sans qu'aucun helper aval n'ait à lire une
      -- table — ils restent tous IMMUTABLE. Même liste que les pastilles de
      -- l'UI admin : les types réellement présents dans le catalogue d'attaques.
      'all_types', COALESCE((
        SELECT jsonb_agg(DISTINCT a.type ORDER BY a.type)
        FROM attacks a WHERE a.type IS NOT NULL AND a.type <> ''), '[]'::jsonb),
      'effects', COALESCE((
        SELECT jsonb_agg(to_jsonb(e) ORDER BY e.id)
        FROM autobattle_weather_effects e WHERE e.weather_id = w.id), '[]'::jsonb))
    FROM autobattle_weathers w WHERE w.id = p_weather_id
  ) ELSE NULL END
$$;

-- Filtre de types d'un effet météo : liste d'INCLUSION, vide ou absente = TOUS
-- les types (l'admin coche ce qui est concerné, jamais ce qui est épargné).
-- Comparaison insensible à la casse et aux espaces, comme partout ailleurs :
-- les types viennent de deux CSV qui ne s'accordent pas toujours.
CREATE OR REPLACE FUNCTION autobattle_weather_type_match(p_list jsonb, p_type text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN jsonb_typeof(p_list) IS DISTINCT FROM 'array' OR jsonb_array_length(p_list) = 0 THEN true
    ELSE EXISTS (
      SELECT 1 FROM jsonb_array_elements_text(p_list) f
      WHERE lower(trim(f)) = lower(trim(COALESCE(p_type, '')))
    )
  END
$$;

-- Le même filtre, mis en toutes lettres pour la description d'un effet. Renvoie
-- la fin de phrase complète (« … pokémon de » + ce qui suit) :
--   • liste vide            → « tous types »
--   • tous les types cochés → « tous types »
--   • majorité cochée       → « tous types sauf Sol, Roche »
--   • sinon                 → « type Feu, Glace »
-- La forme négative dès que les types cochés sont PLUS NOMBREUX que les autres :
-- une tempête de sable se configure en cochant 16 types sur 18, et « tous types
-- sauf Sol, Roche » est la seule formulation lisible.
-- p_all = univers des types (voir autobattle_weather_for, clé 'all_types') ;
-- absent, la fonction se rabat sur la liste positive — d'où le DEFAULT, qui
-- garde la fonction utilisable sans lecture de table et donc IMMUTABLE.
-- Le pendant client est weatherTypeList (src/lib/autoBattle.ts), à garder aligné.
DROP FUNCTION IF EXISTS autobattle_weather_type_list(jsonb);
CREATE OR REPLACE FUNCTION autobattle_weather_type_list(p_list jsonb, p_all jsonb DEFAULT NULL)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  v_sel     text[];
  v_all     text[];
  v_missing text[];
BEGIN
  SELECT COALESCE(array_agg(f), '{}'::text[]) INTO v_sel
    FROM jsonb_array_elements_text(CASE WHEN jsonb_typeof(p_list) = 'array' THEN p_list ELSE '[]'::jsonb END) f;
  IF cardinality(v_sel) = 0 THEN
    RETURN 'tous types';
  END IF;

  SELECT COALESCE(array_agg(f), '{}'::text[]) INTO v_all
    FROM jsonb_array_elements_text(CASE WHEN jsonb_typeof(p_all) = 'array' THEN p_all ELSE '[]'::jsonb END) f;
  IF cardinality(v_all) = 0 THEN
    RETURN 'type ' || array_to_string(v_sel, ', ');
  END IF;

  -- Comparaison insensible à la casse/aux espaces, comme partout ailleurs.
  SELECT COALESCE(array_agg(a), '{}'::text[]) INTO v_missing
    FROM unnest(v_all) a
    WHERE NOT EXISTS (SELECT 1 FROM unnest(v_sel) s WHERE lower(trim(s)) = lower(trim(a)));

  IF cardinality(v_missing) = 0 THEN
    RETURN 'tous types';
  END IF;
  IF cardinality(v_sel) > cardinality(v_missing) THEN
    RETURN 'tous types sauf ' || array_to_string(v_missing, ', ');
  END IF;
  RETURN 'type ' || array_to_string(v_sel, ', ');
END;
$$;

CREATE OR REPLACE FUNCTION autobattle_weather_id(p_weather jsonb)
RETURNS bigint LANGUAGE sql IMMUTABLE AS $$
  SELECT (p_weather ->> 'id')::bigint
$$;

-- « Aucune météo » se représente par un SQL NULL dans les moteurs, mais tout
-- helper qui renvoie un objet jsonb transforme ce NULL en null JSON
-- (jsonb_build_object ne sait pas faire autrement), et `'null'::jsonb IS NOT
-- NULL` vaut VRAI — de quoi croire à une météo qui n'existe pas. À appeler sur
-- toute météo relue depuis un jsonb.
CREATE OR REPLACE FUNCTION autobattle_weather_norm(p_weather jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN jsonb_typeof(p_weather) = 'object' THEN p_weather ELSE NULL END
$$;

-- Condition « météo en cours » d'un buff/debuff (talents comme capacités) :
-- NULL = pas de condition, 'any' = n'importe quelle météo, 'none' = aucune
-- météo, 'this' = celle dont l'id est p_weather_condition_id.
CREATE OR REPLACE FUNCTION autobattle_weather_cond(p_cond text, p_weather_condition_id bigint, p_weather jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT p_cond IS NULL
      OR (p_cond = 'any'  AND p_weather IS NOT NULL)
      OR (p_cond = 'none' AND p_weather IS NULL)
      OR (p_cond = 'this' AND p_weather IS NOT NULL
          AND p_weather_condition_id IS NOT NULL
          AND (p_weather ->> 'id')::bigint = p_weather_condition_id)
$$;

-- Buff/debuff de terrain appliqué à un camp : somme des effets 'stat_mod' de la
-- stat demandée dont le filtre de types correspond. target_scope décide à QUOI
-- le filtre se compare — au type d'espèce du pokémon ('pokemon_type', ex. « les
-- pokémon Feu gagnent +1 précision ») ou au type de la capacité jouée
-- ('ability_type', ex. « les attaques Feu font +1 dégât »).
CREATE OR REPLACE FUNCTION autobattle_weather_stat_bonus(
  p_weather jsonb, p_pokemon_type text, p_ability_type text, p_stat text)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(SUM((e ->> 'amount')::integer), 0)::integer
  FROM jsonb_array_elements(COALESCE(p_weather -> 'effects', '[]'::jsonb)) e
  WHERE (e ->> 'kind') = 'stat_mod'
    AND (e ->> 'stat') = p_stat
    AND autobattle_weather_type_match(
          e -> 'type_filter',
          CASE WHEN (e ->> 'target_scope') = 'ability_type' THEN p_ability_type ELSE p_pokemon_type END)
$$;

-- Libellé français d'un statut — le pendant SQL de STATUS_EFFECT_LABEL
-- (src/lib/autoBattle.ts), nécessaire pour rédiger la description d'une météo
-- côté serveur. Les deux listes doivent rester identiques.
CREATE OR REPLACE FUNCTION autobattle_status_label(p_status text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_status
    WHEN 'paralysis' THEN 'paralysie'
    WHEN 'fear'      THEN 'peur'
    WHEN 'confusion' THEN 'confusion'
    WHEN 'sleep'     THEN 'sommeil'
    WHEN 'burn'      THEN 'brûlure'
    WHEN 'poison'    THEN 'poison'
    WHEN 'frozen'    THEN 'gel'
    ELSE 'un statut'
  END
$$;

-- Résumé lisible d'UN effet de météo. Volontairement aligné sur
-- describeWeatherEffect (src/lib/autoBattle.ts), qui produit la même phrase pour
-- l'UI admin — les deux doivent rester cohérents.
-- p_all_types : univers des types, pour la formulation négative « tous types
-- sauf … » (voir autobattle_weather_type_list).
CREATE OR REPLACE FUNCTION autobattle_weather_effect_detail(p_effect jsonb, p_all_types jsonb DEFAULT NULL)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE (p_effect ->> 'kind')
    WHEN 'stat_mod' THEN
      (CASE WHEN COALESCE((p_effect ->> 'amount')::integer, 0) >= 0 THEN '+' ELSE '' END)
      || COALESCE(p_effect ->> 'amount', '0')
      || (CASE WHEN (p_effect ->> 'stat') = 'precision' THEN ' précision' ELSE ' dégâts' END)
      || ' — ' || (CASE WHEN (p_effect ->> 'target_scope') = 'ability_type' THEN 'capacités' ELSE 'pokémon' END)
      || ' de ' || autobattle_weather_type_list(p_effect -> 'type_filter', p_all_types)
    WHEN 'inflict_status' THEN
      COALESCE(p_effect ->> 'percent', '0') || ' % par tour d''infliger '
      || autobattle_status_label(p_effect ->> 'status')
      || ' — pokémon de ' || autobattle_weather_type_list(p_effect -> 'type_filter', p_all_types)
    WHEN 'damage' THEN
      COALESCE(p_effect ->> 'percent', '0') || ' % par tour d''infliger '
      || COALESCE(p_effect ->> 'damage_amount', '0') || ' dégâts'
      || ' — pokémon de ' || autobattle_weather_type_list(p_effect -> 'type_filter', p_all_types)
    ELSE ''
  END
$$;

-- Description complète d'une météo, UNE LIGNE PAR EFFET (tableau jsonb de
-- chaînes) : c'est ce que le client affiche dans la bulle ouverte au clic sur la
-- pastille météo, sans avoir à relire la configuration en base.
-- Une météo sans effet renvoie un tableau vide — la bulle le dit explicitement.
CREATE OR REPLACE FUNCTION autobattle_weather_details(p_weather jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE((
    SELECT jsonb_agg(autobattle_weather_effect_detail(e, p_weather -> 'all_types'))
    FROM jsonb_array_elements(COALESCE(p_weather -> 'effects', '[]'::jsonb)) e
  ), '[]'::jsonb)
$$;

GRANT EXECUTE ON FUNCTION autobattle_weather_for(bigint, boolean) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_weather_type_match(jsonb, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_weather_type_list(jsonb, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_weather_id(jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_weather_norm(jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_weather_cond(text, bigint, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_weather_stat_bonus(jsonb, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_status_label(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_weather_effect_detail(jsonb, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_weather_details(jsonb) TO anon, authenticated;

-- ============================================================
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
-- `weather_nom` est ajouté au passage (jointure sur weather_id) : les helpers
-- n'ont ainsi jamais besoin de retoucher la base pour libeller la météo qu'un
-- talent 'set_weather' lève, ce qui les garde IMMUTABLE.
CREATE OR REPLACE FUNCTION autobattle_talents_for(p_pokemon_nom text, p_enabled boolean DEFAULT true)
RETURNS jsonb
LANGUAGE sql STABLE
AS $$
  SELECT CASE WHEN COALESCE(p_enabled, true) THEN
    COALESCE((
      SELECT jsonb_agg(to_jsonb(t) || jsonb_build_object('weather_nom', w.nom) ORDER BY t.id)
      FROM autobattle_talents t
      LEFT JOIN autobattle_weathers w ON w.id = t.weather_id
      WHERE t.pokemon_nom = p_pokemon_nom), '[]'::jsonb)
  ELSE '[]'::jsonb END
$$;

-- Talent 'cancel_talents' : ANNULE TOUS LES TALENTS DU COMBAT, dans les deux
-- camps — celui de son porteur compris. Il ne se contente pas de neutraliser
-- l'adversaire : dès qu'un des deux pokémon l'a, le combat entier se joue comme
-- si le système de talents était éteint (même résultat que la bascule globale
-- autobattle_config/pvp_config.talents_enabled, mais pour ce combat-là).
--
-- Il s'applique AVANT TOUT LE RESTE : la résolution des talents est la toute
-- première chose que font les fonctions de combat (avant la copie 'transform',
-- avant la priorité d'initiative, avant l'annonce d'ouverture), donc filtrer
-- ici suffit à ce qu'aucune autre phase ne voie jamais un talent annulé.
--
-- Le talent annulateur lui-même est CONSERVÉ dans la liste de son porteur, pour
-- deux raisons : il doit rester annonçable au tour 0 (sinon le joueur ne
-- comprend pas pourquoi plus rien ne se déclenche), et il doit continuer
-- d'annuler quand c'est le camp d'en face qui l'interroge. Aucun helper de
-- phase ne réagit à ce kind : il est inerte partout ailleurs.
CREATE OR REPLACE FUNCTION autobattle_talents_effective(p_self jsonb, p_opp jsonb)
RETURNS jsonb
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE
    WHEN EXISTS (
      SELECT 1
      FROM jsonb_array_elements(COALESCE(p_self, '[]'::jsonb) || COALESCE(p_opp, '[]'::jsonb)) t
      WHERE (t ->> 'kind') = 'cancel_talents')
    THEN COALESCE((
      SELECT jsonb_agg(t)
      FROM jsonb_array_elements(COALESCE(p_self, '[]'::jsonb)) t
      WHERE (t ->> 'kind') = 'cancel_talents'), '[]'::jsonb)
    ELSE COALESCE(p_self, '[]'::jsonb)
  END
$$;

-- Raccourci utilisé par TOUS les points d'entrée de combat à la place de
-- autobattle_talents_for : « les talents de p_self_nom face à p_opp_nom », donc
-- déjà passés au filtre d'annulation. Appeler _for directement dans un moteur
-- serait un contournement de 'cancel_talents'.
CREATE OR REPLACE FUNCTION autobattle_talents_vs(p_self_nom text, p_opp_nom text, p_enabled boolean DEFAULT true)
RETURNS jsonb
LANGUAGE sql STABLE
AS $$
  SELECT autobattle_talents_effective(
    autobattle_talents_for(p_self_nom, p_enabled),
    autobattle_talents_for(p_opp_nom, p_enabled))
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
    WHEN 'cancel_talents' THEN 'annule tous les talents du combat, des deux côtés'
    -- weather_nom est injecté par autobattle_talents_for (jointure), la colonne
    -- weather_id seule ne dirait rien au joueur.
    WHEN 'set_weather' THEN 'déclenche ' || COALESCE(NULLIF(trim(COALESCE(p_talent ->> 'weather_nom', '')), ''), 'une météo')
      || ' (' || COALESCE(p_talent ->> 'percent', '0') || ' %)'
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
      || (CASE (p_talent ->> 'weather_condition')
            WHEN 'any'  THEN ' par temps changé'
            WHEN 'none' THEN ' par temps calme'
            WHEN 'this' THEN ' selon la météo en cours'
            ELSE '' END)
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

-- p_weather : météo en cours (voir autobattle_weather_for), NULL s'il n'y en a
-- pas — sert à la condition weather_condition/weather_condition_id.
DROP FUNCTION IF EXISTS autobattle_talent_stat_active(jsonb, text, integer, integer, text, text, integer);
CREATE OR REPLACE FUNCTION autobattle_talent_stat_active(
  p_talent jsonb, p_ability_type text, p_hp integer, p_max_hp integer,
  p_opp_status text, p_self_status text, p_hits integer, p_weather jsonb DEFAULT NULL)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT (p_talent ->> 'kind') = 'stat_boost'
    AND autobattle_talent_type_match(p_talent -> 'type_filter', p_ability_type, true)
    AND autobattle_weather_cond(
          p_talent ->> 'weather_condition',
          (p_talent ->> 'weather_condition_id')::bigint,
          p_weather)
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

DROP FUNCTION IF EXISTS autobattle_talent_stat_bonus(jsonb, jsonb, text, text, integer, integer, text, text);
CREATE OR REPLACE FUNCTION autobattle_talent_stat_bonus(
  p_talents jsonb, p_state jsonb, p_stat text, p_ability_type text, p_hp integer, p_max_hp integer,
  p_opp_status text, p_self_status text, p_weather jsonb DEFAULT NULL)
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
    AND autobattle_talent_stat_active(t, p_ability_type, p_hp, p_max_hp, p_opp_status, p_self_status, autobattle_talent_hits(p_state), p_weather)
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
    -- 'cancel_talents' est le seul talent encore présent dans la liste quand
    -- l'annulation est active (voir autobattle_talents_effective) : il DOIT
    -- s'annoncer, c'est la seule explication donnée au joueur de l'absence de
    -- tout autre talent pendant le combat.
    IF (v_t ->> 'kind') IN ('poison_damage_boost', 'burn_damage_boost', 'status_immunity',
                            'type_immunity', 'type_damage_to_heal', 'no_recoil', 'invulnerable_until_hit',
                            'transform', 'heavy_sleeper', 'cancel_talents')
       OR ((v_t ->> 'kind') = 'priority' AND COALESCE((v_t ->> 'amount')::integer, 0) <> 0)
       OR ((v_t ->> 'kind') = 'stat_boost'
           AND (v_t ->> 'hp_condition') IS NULL
           AND (v_t ->> 'opponent_status') IS NULL
           AND (v_t ->> 'self_status') IS NULL
           -- Un bonus conditionné à la météo n'est pas permanent : il s'annonce
           -- quand la météo le rend actif (autobattle_talent_act).
           AND (v_t ->> 'weather_condition') IS NULL
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
-- p_opp_talents/p_opp_status/p_opp_type servent à respecter l'immunité (de
-- talent ET de type) et à ne pas écraser un statut déjà en place. p_weather =
-- météo en cours (voir autobattle_weather_for), qui conditionne les bonus de
-- stat et évite de relancer une météo déjà levée. Renvoie
-- {"state", "turns", "inflict_status", "set_weather"} — set_weather = l'id de la
-- météo à lever, que l'appelant applique via autobattle_weather_set.
DROP FUNCTION IF EXISTS autobattle_talent_act(jsonb, jsonb, text, text, text, integer, integer, text, text, jsonb, integer);
DROP FUNCTION IF EXISTS autobattle_talent_act(jsonb, jsonb, text, text, text, integer, integer, text, text, jsonb, integer, jsonb);
CREATE OR REPLACE FUNCTION autobattle_talent_act(
  p_talents jsonb, p_state jsonb, p_side text, p_trigger text, p_ability_type text,
  p_hp integer, p_max_hp integer, p_opp_status text, p_self_status text,
  p_opp_talents jsonb, p_turn_no integer, p_weather jsonb DEFAULT NULL,
  -- Type d'espèce de la CIBLE du statut (l'adversaire du porteur du talent) :
  -- une cible immunisée par son type ne doit pas voir le talent se déclencher
  -- « pour rien » (voir la garde ci-dessous). Par défaut NULL = pas d'immunité
  -- de type connue, la garde de autobattle_talent_status_guard reste seule
  -- juge — elle, ne laisse rien passer.
  p_opp_type text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_state   jsonb := COALESCE(p_state, autobattle_talent_state_init());
  v_turns   jsonb := '[]'::jsonb;
  v_status  text;
  v_weather bigint;
  v_t       jsonb;
BEGIN
  FOR v_t IN SELECT * FROM jsonb_array_elements(COALESCE(p_talents, '[]'::jsonb)) LOOP
    -- Les bonus CUMULATIFS s'annoncent eux-mêmes à chaque coup encaissé (voir
    -- autobattle_talent_defend) : les exclure ici évite une annonce en double.
    IF NOT COALESCE((v_t ->> 'require_damage_taken')::boolean, false)
       AND autobattle_talent_stat_active(v_t, p_ability_type, p_hp, p_max_hp, p_opp_status, p_self_status, autobattle_talent_hits(v_state), p_weather)
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
      -- Vaut pour l'immunité de TYPE comme pour celle de talent : sans ce
      -- filtre, le tour porterait 'talent_inflicted_status' et le client
      -- allumerait un badge de statut que la garde vient de refuser, badge que
      -- plus aucun tick ne viendrait éteindre.
      IF autobattle_status_type_immune(p_opp_type, v_status) OR EXISTS (
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

    -- Levée de météo. Le talent s'annonce ici ; la météo elle-même s'annoncera
    -- au retour, dans autobattle_weather_set (deux entrées de journal : « X
    -- déclenche son talent », puis « la météo se lève »).
    -- Un talent dont la météo a été supprimée (weather_id NULL, ON DELETE SET
    -- NULL) est simplement ignoré, et relancer la météo DÉJÀ en cours n'a aucun
    -- intérêt : on ne gaspille ni le jet ni une ligne d'historique.
    IF (v_t ->> 'kind') = 'set_weather'
       AND (v_t ->> 'trigger') = p_trigger
       AND (v_t ->> 'weather_id') IS NOT NULL
       AND v_weather IS NULL
       AND (p_weather ->> 'id')::bigint IS DISTINCT FROM (v_t ->> 'weather_id')::bigint
       AND ((v_t ->> 'trigger') <> 'on_ability_type'
            OR autobattle_talent_type_match(v_t -> 'type_filter', p_ability_type, true))
       AND random() * 100 < COALESCE((v_t ->> 'percent')::integer, 0)
    THEN
      v_weather := (v_t ->> 'weather_id')::bigint;
      v_turns := v_turns || jsonb_build_array(
        autobattle_talent_turn(p_turn_no, p_side, p_hp, v_t, jsonb_build_object('talent_set_weather', v_weather)));
    END IF;
  END LOOP;

  RETURN jsonb_build_object('state', v_state, 'turns', v_turns, 'inflict_status', v_status, 'set_weather', v_weather);
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
      -- PV annoncés = p_hp PLUS le soin, même raison que pour les bonus
      -- cumulatifs plus bas : p_hp est l'état AVANT le coup et le client
      -- resynchronise les PV sur attacker_hp_after à chaque talent_tick.
      -- Renvoyer p_hp tel quel afficherait « soigné » sans que la barre bouge
      -- (elle ne se corrigeait qu'au tour suivant). ATTENTION : cette fonction
      -- ne connaît pas les PV max, la valeur peut donc DÉPASSER le maximum en
      -- cas de surplus de soin — c'est le client qui borne (voir
      -- AutoBattleScreen, talent_tick), l'appelant appliquant de son côté
      -- LEAST(max_hp, hp - damage + heal) à l'état serveur.
      v_turns := v_turns || jsonb_build_array(
        autobattle_talent_turn(p_turn_no, p_side, p_hp + v_heal, v_t, jsonb_build_object('talent_absorbed', v_heal, 'heal', v_heal)));
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
        -- PV annoncés = p_hp MOINS les dégâts qui passent : p_hp est l'état
        -- AVANT le coup (l'appelant ne retire v_damage qu'au retour de cette
        -- fonction), or le client resynchronise les PV du porteur sur
        -- attacker_hp_after à chaque talent_tick (voir AutoBattleScreen).
        -- Renvoyer p_hp tel quel remonterait donc la barre de vie au niveau
        -- d'avant le coup : le talent aurait l'air de SOIGNER à chaque coup
        -- encaissé. Ici v_heal vaut forcément 0 (la conversion en soin met
        -- v_damage à 0 et exclut cette branche), donc p_hp - v_damage est
        -- exactement les PV que l'appelant va poser.
        v_turns := v_turns || jsonb_build_array(autobattle_talent_turn(
          p_turn_no, p_side, p_hp - v_damage, v_t,
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
-- Point de passage OBLIGATOIRE de tout statut posé sur un pokémon, quelle qu'en
-- soit la source (capacité, talent 'inflict_status', tentative persistante
-- status_dot, statut de terrain d'une météo) : immunité de TYPE
-- (autobattle_status_type_immune, indépendante de toute donnée d'admin),
-- immunité de talent ('status_immunity', permanente) et guérison automatique du
-- premier statut ('auto_cure_first_status', usage unique). Renvoie
-- {"blocked", "state", "turns"} — blocked = le statut ne s'applique pas.
-- p_pokemon_type = type d'espèce de la VICTIME (celle qui reçoit le statut,
-- donc le lanceur lui-même quand la capacité est retournée) — SANS valeur par
-- défaut, exprès : un appelant qui l'oublierait doit échouer bruyamment plutôt
-- que de laisser passer un statut interdit.
DROP FUNCTION IF EXISTS autobattle_talent_status_guard(jsonb, jsonb, text, text, integer, integer);
CREATE OR REPLACE FUNCTION autobattle_talent_status_guard(
  p_talents jsonb, p_state jsonb, p_side text, p_status text, p_hp integer, p_turn_no integer,
  p_pokemon_type text)
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

  -- Immunité de type (Acier/Poison, Feu/Brûlure, Glace/Gel) : vérifiée en tout
  -- premier, avant les talents — elle ne consomme ni 'auto_cure_first_status'
  -- ni quoi que ce soit d'autre, et reste silencieuse comme 'status_immunity'.
  IF autobattle_status_type_immune(p_pokemon_type, p_status) THEN
    RETURN jsonb_build_object('blocked', true, 'state', v_state, 'turns', v_turns);
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
GRANT EXECUTE ON FUNCTION autobattle_talents_effective(jsonb, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talents_vs(text, text, boolean) TO anon, authenticated;
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
GRANT EXECUTE ON FUNCTION autobattle_talent_stat_active(jsonb, text, integer, integer, text, text, integer, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_stat_bonus(jsonb, jsonb, text, text, integer, integer, text, text, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_open(jsonb, text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_priority(jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_act(jsonb, jsonb, text, text, text, integer, integer, text, text, jsonb, integer, jsonb, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_defend(jsonb, jsonb, text, integer, text, integer, integer, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_survive(jsonb, jsonb, text, integer, integer, integer, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_status_guard(jsonb, jsonb, text, text, integer, integer, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_tick_bonus(jsonb, jsonb, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_dice(jsonb, integer, text, integer, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_has_kind(jsonb, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_shield_active(jsonb, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_talent_spend_shield(jsonb, jsonb) TO anon, authenticated;

-- ============================================================
-- Météo : helpers de PHASE (levée, tick de début de tour)
-- ============================================================
-- Placés après les talents parce qu'ils s'appuient dessus : les dégâts de météo
-- passent par autobattle_talent_survive (endure_ko / heal_below_hp) et ses
-- statuts par autobattle_talent_status_guard (status_immunity /
-- auto_cure_first_status), exactement comme les ticks de brûlure et de poison.
-- Un effet de terrain ne doit pas être une porte dérobée qui contourne les
-- talents défensifs.

-- Entrée de journal d'un événement météo. Même forme qu'autobattle_talent_turn
-- (dont il reprend les invariants : `attacker` = le camp CONCERNÉ, pas un
-- attaquant ; le client resynchronise les PV sur attacker_hp_after).
CREATE OR REPLACE FUNCTION autobattle_weather_turn(p_turn_no integer, p_side text, p_hp integer, p_weather jsonb, p_extra jsonb)
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
    'weather_tick', true,
    'weather_id', (p_weather ->> 'id')::bigint,
    'weather_nom', COALESCE(NULLIF(trim(COALESCE(p_weather ->> 'nom', '')), ''), 'Météo'),
    'weather_animation', p_weather ->> 'animation',
    -- Emoji + description ligne par ligne : le client affiche la pastille ronde
    -- entre les deux noms de pokémon et sa bulle au clic, sans jamais relire la
    -- configuration en base (voir AutoBattleScreen).
    'weather_icon', p_weather ->> 'icon',
    'weather_details', autobattle_weather_details(p_weather),
    -- Effets bruts : le client s'en sert pour marquer d'une pastille météo les
    -- capacités CONCERNÉES dans la grille de sélection (voir
    -- weatherAffectsAbility, src/lib/autoBattle.ts) — une décision qui a besoin
    -- du type et du scope de chaque effet, pas seulement de la phrase.
    'weather_effects', COALESCE(p_weather -> 'effects', '[]'::jsonb)
  ) || COALESCE(p_extra, '{}'::jsonb)
$$;

-- Lève une météo, en remplaçant celle en cours. Renvoie {"weather", "turns"} —
-- `weather` étant la météo APRÈS coup (inchangée si rien ne s'est passé).
--
-- Ne fait rien, et n'émet aucune ligne d'historique, si : aucun id demandé, la
-- bascule globale du mode est à faux, la météo a été supprimée depuis, ou c'est
-- déjà elle qui est en cours. C'est le seul point de tout le moteur qui écrit la
-- météo — d'où l'unicité garantie (« une seule météo à la fois »).
CREATE OR REPLACE FUNCTION autobattle_weather_set(
  p_weather_id bigint, p_enabled boolean, p_current jsonb, p_side text, p_hp integer, p_turn_no integer)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_new jsonb;
BEGIN
  IF p_weather_id IS NULL OR (p_current ->> 'id')::bigint IS NOT DISTINCT FROM p_weather_id THEN
    RETURN jsonb_build_object('weather', p_current, 'turns', '[]'::jsonb);
  END IF;

  v_new := autobattle_weather_for(p_weather_id, p_enabled);
  IF v_new IS NULL THEN
    RETURN jsonb_build_object('weather', p_current, 'turns', '[]'::jsonb);
  END IF;

  -- weather_set : le client remplace le bandeau de météo active (et non un
  -- simple tick sur un pokémon), voir AutoBattleScreen.
  RETURN jsonb_build_object(
    'weather', v_new,
    'turns', jsonb_build_array(autobattle_weather_turn(
      p_turn_no, p_side, p_hp, v_new,
      jsonb_build_object('weather_set', true,
                         'weather_replaced', p_current IS NOT NULL))));
END;
$$;

-- Tick de début de tour, POUR UN camp. À appeler une fois par tour de combat et
-- par pokémon, AVANT tout le reste du tour (avant les priorités, avant les ticks
-- de statut, avant les capacités) — c'est la règle du mode : « la météo, c'est
-- la première chose qui se passe ».
--
-- Renvoie {"hp", "status", "state", "turns"}. Les dégâts et le statut sont
-- indépendants (une météo peut faire les deux) mais un seul statut peut être
-- infligé par tour, et jamais si le pokémon en a déjà un — même règle que les
-- talents 'inflict_status'.
CREATE OR REPLACE FUNCTION autobattle_weather_tick(
  p_weather jsonb, p_side text, p_pokemon_type text, p_hp integer, p_max_hp integer,
  p_status text, p_talents jsonb, p_state jsonb, p_turn_no integer)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_hp     integer := COALESCE(p_hp, 0);
  v_status text    := p_status;
  v_state  jsonb   := COALESCE(p_state, autobattle_talent_state_init());
  v_turns  jsonb   := '[]'::jsonb;
  v_damage integer;
  v_res    jsonb;
  v_e      jsonb;
BEGIN
  IF p_weather IS NULL OR v_hp <= 0 THEN
    RETURN jsonb_build_object('hp', v_hp, 'status', v_status, 'state', v_state, 'turns', v_turns);
  END IF;

  -- Dégâts de terrain (grêle, tempête de sable…). Cumulés si la météo porte
  -- plusieurs effets 'damage', chacun avec son propre jet.
  FOR v_e IN SELECT * FROM jsonb_array_elements(COALESCE(p_weather -> 'effects', '[]'::jsonb)) LOOP
    IF v_hp > 0
       AND (v_e ->> 'kind') = 'damage'
       AND autobattle_weather_type_match(v_e -> 'type_filter', p_pokemon_type)
       AND random() * 100 < COALESCE((v_e ->> 'percent')::integer, 0)
    THEN
      v_damage := GREATEST(0, COALESCE((v_e ->> 'damage_amount')::integer, 0));
      v_hp := v_hp - v_damage;
      -- Comme un tick de brûlure/poison : le K.O. peut être encaissé
      -- ('endure_ko') et le soin de seuil se déclencher ('heal_below_hp'), le
      -- tout AVANT de figer le drapeau 'ko' de l'entrée de journal. Les PV
      -- ANNONCÉS sont ceux d'avant le soin (hp_before_heal), pour que la chute
      -- reste visible — le tour de talent qui suit remonte la barre.
      v_res := autobattle_talent_survive(p_talents, v_state, p_side, v_hp, p_max_hp, p_turn_no, v_status);
      v_hp := (v_res ->> 'hp')::integer;
      v_state := v_res -> 'state';
      v_status := v_res ->> 'status';
      v_turns := v_turns || jsonb_build_array(autobattle_weather_turn(
        p_turn_no, p_side, (v_res ->> 'hp_before_heal')::integer, p_weather,
        jsonb_build_object('weather_damage', v_damage, 'damage', v_damage, 'ko', v_hp <= 0)))
        || (v_res -> 'turns');
    END IF;
  END LOOP;

  -- Statut de terrain (gel de la grêle…). Un seul par tour, et seulement si le
  -- pokémon est encore debout et sans statut.
  IF v_hp > 0 AND v_status IS NULL THEN
    FOR v_e IN SELECT * FROM jsonb_array_elements(COALESCE(p_weather -> 'effects', '[]'::jsonb)) LOOP
      IF v_status IS NULL
         AND (v_e ->> 'kind') = 'inflict_status'
         AND autobattle_weather_type_match(v_e -> 'type_filter', p_pokemon_type)
         AND random() * 100 < COALESCE((v_e ->> 'percent')::integer, 0)
      THEN
        -- La garde est consultée AVANT d'annoncer quoi que ce soit : une
        -- immunité ('status_immunity') bloque sans émettre le moindre tour, et
        -- rien ne doit alors s'afficher — sinon le client allume un badge de
        -- statut que plus aucun tick ne viendra éteindre (exactement le défaut
        -- corrigé pour les talents 'inflict_status' à l'entrée en combat).
        -- 'auto_cure_first_status', lui, bloque EN émettant son tour : on
        -- annonce alors le statut, puis sa guérison immédiate juste après.
        v_res := autobattle_talent_status_guard(p_talents, v_state, p_side, v_e ->> 'status', v_hp, p_turn_no, p_pokemon_type);
        v_state := v_res -> 'state';
        IF NOT ((v_res ->> 'blocked')::boolean AND jsonb_array_length(v_res -> 'turns') = 0) THEN
          v_turns := v_turns || jsonb_build_array(autobattle_weather_turn(
            p_turn_no, p_side, v_hp, p_weather,
            jsonb_build_object('weather_inflicted_status', v_e ->> 'status')))
            || (v_res -> 'turns');
          IF NOT (v_res ->> 'blocked')::boolean THEN
            v_status := v_e ->> 'status';
          END IF;
        END IF;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object('hp', v_hp, 'status', v_status, 'state', v_state, 'turns', v_turns);
END;
$$;

GRANT EXECUTE ON FUNCTION autobattle_weather_turn(integer, text, integer, jsonb, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_weather_set(bigint, boolean, jsonb, text, integer, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_weather_tick(jsonb, text, text, integer, integer, text, jsonb, jsonb, integer) TO anon, authenticated;

-- ============================================================
-- Effets persistants OFFENSIFS : dégâts par tour et vol de vie par tour
-- (voir autobattle_ability_rules.damage_dot_* / leech_dot_*)
-- ============================================================
-- UN tick, pour le camp qui SUBIT (p_side = celui dont c'est le tour, comme un
-- tick de brûlure/poison), joué au tout début de son tour — avant même son
-- tick de statut, et qu'il agisse ou non ensuite (un tour passé sur paralysie/
-- gel/sommeil le subit quand même, exactement comme le soin passif tique
-- malgré un tour sauté).
--
-- Les deux effets sont indépendants et peuvent coexister sur la même victime :
-- les dégâts persistants d'abord, le vol de vie ensuite. Comme un tick de
-- statut, chacun peut mettre K.O. — et donc déclencher les talents de survie
-- ('endure_ko', 'heal_below_hp') via autobattle_talent_survive, dont les tours
-- sont émis juste après celui du tick (les PV ANNONCÉS restent ceux d'avant le
-- soin de seuil, hp_before_heal, pour que la chute soit visible).
--
-- Vol de vie : on ne prend jamais plus de PV qu'il n'en reste à la victime, et
-- le voleur ne dépasse pas ses propres PV max ; si le VOLEUR subit un Anti-Soin
-- (p_other_heal_blocked), la victime perd quand même ses PV mais rien n'est
-- rendu ('heal' = 0 et 'heal_blocked' sur le tour). N'importe quel soin guérit
-- le poison, celui-ci compris — d'où p_other_status en entrée/sortie.
--
-- Retour : { hp, other_hp, status, other_status, state, turns }.
CREATE OR REPLACE FUNCTION autobattle_dot_tick(
  p_side text, p_turn_no integer,
  p_hp integer, p_max_hp integer, p_other_hp integer, p_other_max_hp integer,
  p_status text, p_other_status text,
  p_damage_dot integer, p_leech_dot integer,
  p_talents jsonb, p_state jsonb, p_other_heal_blocked boolean)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_hp          integer := COALESCE(p_hp, 0);
  v_other_hp    integer := COALESCE(p_other_hp, 0);
  v_status      text    := p_status;
  v_other_status text   := p_other_status;
  v_state       jsonb   := COALESCE(p_state, autobattle_talent_state_init());
  v_turns       jsonb   := '[]'::jsonb;
  v_damage      integer;
  v_gain        integer;
  v_res         jsonb;
BEGIN
  IF v_hp <= 0 THEN
    RETURN jsonb_build_object(
      'hp', v_hp, 'other_hp', v_other_hp, 'status', v_status,
      'other_status', v_other_status, 'state', v_state, 'turns', v_turns);
  END IF;

  -- Dégâts persistants.
  IF COALESCE(p_damage_dot, 0) > 0 THEN
    v_damage := p_damage_dot;
    v_hp := v_hp - v_damage;
    v_res := autobattle_talent_survive(p_talents, v_state, p_side, v_hp, p_max_hp, p_turn_no, v_status);
    v_hp := (v_res ->> 'hp')::integer;
    v_state := v_res -> 'state';
    v_status := v_res ->> 'status';
    v_turns := v_turns || jsonb_build_array(jsonb_build_object(
      'turn', p_turn_no, 'attacker', p_side, 'damage', v_damage, 'skipped', false,
      'damage_dot_tick', true,
      'attacker_hp_after', GREATEST(0, (v_res ->> 'hp_before_heal')::integer),
      'defender_hp_after', GREATEST(0, v_other_hp), 'ko', v_hp <= 0
    )) || (v_res -> 'turns');
  END IF;

  -- Vol de vie persistant : seulement si la victime est encore debout après
  -- les dégâts persistants ci-dessus (rien à voler à un pokémon déjà K.O.).
  IF v_hp > 0 AND COALESCE(p_leech_dot, 0) > 0 THEN
    v_damage := LEAST(p_leech_dot, v_hp);
    v_hp := v_hp - v_damage;
    v_gain := CASE WHEN COALESCE(p_other_heal_blocked, false) THEN 0
                   ELSE LEAST(v_damage, GREATEST(0, COALESCE(p_other_max_hp, v_other_hp) - v_other_hp)) END;
    v_other_hp := v_other_hp + v_gain;
    IF v_gain > 0 AND v_other_status = 'poison' THEN v_other_status := NULL; END IF;
    v_res := autobattle_talent_survive(p_talents, v_state, p_side, v_hp, p_max_hp, p_turn_no, v_status);
    v_hp := (v_res ->> 'hp')::integer;
    v_state := v_res -> 'state';
    v_status := v_res ->> 'status';
    v_turns := v_turns || jsonb_build_array(jsonb_build_object(
      'turn', p_turn_no, 'attacker', p_side, 'damage', v_damage, 'skipped', false,
      'leech_dot_tick', true, 'heal', v_gain,
      'heal_blocked', COALESCE(p_other_heal_blocked, false),
      'attacker_hp_after', GREATEST(0, (v_res ->> 'hp_before_heal')::integer),
      'defender_hp_after', GREATEST(0, v_other_hp), 'ko', v_hp <= 0
    )) || (v_res -> 'turns');
  END IF;

  RETURN jsonb_build_object(
    'hp', v_hp, 'other_hp', v_other_hp, 'status', v_status,
    'other_status', v_other_status, 'state', v_state, 'turns', v_turns);
END;
$$;

-- Tentative de statut persistante (voir autobattle_ability_rules.status_dot_*)
-- pour le camp qui la SUBIT, jouée à chacun de ses tours — mais APRÈS son tick
-- de statut, contrairement aux deux effets ci-dessus : un statut posé ici ne
-- mord donc qu'à son tour suivant, exactement comme un statut infligé par une
-- attaque adverse. L'appelant n'appelle cette fonction que si la victime n'a
-- aucun statut (un seul statut à la fois par camp).
--
-- Un jet raté ne produit AUCUN tour de journal. Un jet réussi passe encore par
-- autobattle_talent_status_guard : la cible peut y être immunisée
-- ('status_immunity', silencieux) ou guérir aussitôt ('auto_cure_first_status',
-- qui émet ses propres tours) — même garde et même précaution que le statut de
-- terrain de la météo (ne rien annoncer quand rien ne s'applique, sinon le
-- client allume un badge que plus aucun tick ne viendra éteindre).
--
-- Retour : { status, state, turns }.
DROP FUNCTION IF EXISTS autobattle_status_dot_tick(text, integer, integer, text, text, integer, jsonb, jsonb);
CREATE OR REPLACE FUNCTION autobattle_status_dot_tick(
  p_side text, p_turn_no integer, p_hp integer, p_status text,
  p_status_dot text, p_chance integer, p_talents jsonb, p_state jsonb,
  -- Type d'espèce de la VICTIME — passé tel quel à la garde (immunité de type).
  p_pokemon_type text)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_status text  := p_status;
  v_state  jsonb := COALESCE(p_state, autobattle_talent_state_init());
  v_turns  jsonb := '[]'::jsonb;
  v_res    jsonb;
BEGIN
  IF p_status_dot IS NULL OR v_status IS NOT NULL OR COALESCE(p_hp, 0) <= 0
     OR random() * 100 >= COALESCE(p_chance, 0) THEN
    RETURN jsonb_build_object('status', v_status, 'state', v_state, 'turns', v_turns);
  END IF;

  v_res := autobattle_talent_status_guard(p_talents, v_state, p_side, p_status_dot, p_hp, p_turn_no, p_pokemon_type);
  v_state := v_res -> 'state';
  IF (v_res ->> 'blocked')::boolean AND jsonb_array_length(v_res -> 'turns') = 0 THEN
    RETURN jsonb_build_object('status', v_status, 'state', v_state, 'turns', v_turns);
  END IF;

  v_turns := jsonb_build_array(jsonb_build_object(
    'turn', p_turn_no, 'attacker', p_side, 'damage', 0, 'skipped', false,
    'status_dot_tick', true, 'status_dot_applied', p_status_dot,
    'attacker_hp_after', GREATEST(0, COALESCE(p_hp, 0)),
    'defender_hp_after', GREATEST(0, COALESCE(p_hp, 0)), 'ko', false
  )) || (v_res -> 'turns');
  IF NOT (v_res ->> 'blocked')::boolean THEN
    v_status := p_status_dot;
  END IF;
  RETURN jsonb_build_object('status', v_status, 'state', v_state, 'turns', v_turns);
END;
$$;

-- Immunité de type EFFECTIVE d'un coup : l'immunité de la table des types
-- (type_no_effect), sauf si l'attaquant la perce — soit par la capacité qu'il
-- joue à cet instant (p_ability_pierce_type, qui vaut donc dès ce coup-ci),
-- soit par un perce-immunité encore actif accordé par une capacité précédente
-- (p_state_pierce_type/p_state_pierce_expires, comparés au round en cours).
-- Voir autobattle_ability_rules.pierce_immunity_type.
CREATE OR REPLACE FUNCTION autobattle_type_immune(
  p_ability_type text, p_defender_type text,
  p_ability_pierce_type text, p_state_pierce_type text,
  p_state_pierce_expires integer, p_round_no integer)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT type_no_effect(p_ability_type, p_defender_type)
     AND NOT (
       (p_ability_pierce_type IS NOT NULL AND type_norm(p_ability_pierce_type) = type_norm(p_defender_type))
       OR (p_state_pierce_type IS NOT NULL
           AND type_norm(p_state_pierce_type) = type_norm(p_defender_type)
           AND p_state_pierce_expires IS NOT NULL
           AND p_round_no <= p_state_pierce_expires)
     )
$$;

-- Condition de dégâts additionnels 'weight_ratio' (voir autobattle_ability_
-- rules.bonus_damage_weight_*) : « poids(target) <comparaison> percent % du
-- poids de l'autre », du point de vue du camp qui ATTAQUE (p_self_weight).
-- Un poids manquant ou nul d'un côté ne remplit jamais la condition.
CREATE OR REPLACE FUNCTION autobattle_weight_condition(
  p_target text, p_comparison text, p_percent integer,
  p_self_weight numeric, p_opponent_weight numeric)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE
    WHEN COALESCE(p_self_weight, 0) <= 0 OR COALESCE(p_opponent_weight, 0) <= 0 THEN false
    WHEN p_target = 'opponent' THEN
      CASE WHEN p_comparison = 'lower'
        THEN p_opponent_weight < p_self_weight * COALESCE(p_percent, 100) / 100.0
        ELSE p_opponent_weight > p_self_weight * COALESCE(p_percent, 100) / 100.0 END
    ELSE
      CASE WHEN p_comparison = 'lower'
        THEN p_self_weight < p_opponent_weight * COALESCE(p_percent, 100) / 100.0
        ELSE p_self_weight > p_opponent_weight * COALESCE(p_percent, 100) / 100.0 END
  END
$$;

-- Signe d'un modificateur de stat (voir autobattle_ability_rules.stat_mod_*) :
-- 'debuff' = baisse (montant négatif), 'buff' = hausse (montant positif), et ce
-- INDÉPENDAMMENT de la cible — un lanceur peut donc se baisser une stat à
-- lui-même. p_direction NULL = règles écrites avant l'ajout du sens explicite :
-- on retombe sur l'ancienne convention (cible adverse = baisse, soi = hausse).
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
GRANT EXECUTE ON FUNCTION autobattle_status_dot_tick(text, integer, integer, text, text, integer, jsonb, jsonb, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_type_immune(text, text, text, text, integer, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_weight_condition(text, text, integer, numeric, numeric) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_stat_mod_signed(integer, text, text) TO anon, authenticated;

-- ============================================================
-- Moteur de résolution de tour PARTAGÉ (utilisé par autobattle_resolve_
-- manual_round ET pvp_resolve_round plus bas dans ce fichier — mêmes
-- formules exactes, aucune duplication de la boucle de résolution
-- elle-même). Un "round" = un tour complet des DEUX camps (rafales/passes/
-- préparations internes comprises), borné à s'arrêter dès que 2 changements
-- de camp (flips) ont eu lieu.
--
-- Tout ce qui précède (validation niveau/défi, ticket, sélection de
-- capacité — y compris Métamorph côté Combat Auto — et lecture de la config
-- autobattle_ability_rules) reste propre à chaque appelant, qui construit un
-- autobattle_combatant_ability par camp avant d'appeler cette fonction ; tout
-- ce qui suit (récompenses/progression pour Combat Auto, ligne
-- pvp_challenge_attempts pour le PvP) reste également propre à chaque
-- appelant, à partir de l'état renvoyé (autobattle_round_result).
-- ============================================================

-- État mutable d'un camp, persisté entre deux appels RPC (colonnes
-- player_*/opponent_* de autobattle_manual_battles, attacker_*/defender_*
-- de pvp_battles — chaque appelant marshalle ses propres colonnes dans/hors
-- de ce type, voir autobattle_resolve_manual_round et pvp_resolve_round).
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
  -- Effets persistants OFFENSIFS subis par CE camp (posés par l'adversaire,
  -- voir autobattle_ability_rules.damage_dot_*/leech_dot_*) : montant par
  -- tick déjà résolu, et numéro de round d'échéance. Le vol de vie ne stocke
  -- pas son bénéficiaire — c'est forcément l'autre camp.
  damage_dot_amount      integer,
  damage_dot_expires     integer,
  leech_dot_amount       integer,
  leech_dot_expires      integer,
  -- Tentative de statut persistante subie par CE camp (voir
  -- autobattle_ability_rules.status_dot_*) : statut guetté, probabilité par
  -- tour, et round d'échéance.
  status_dot_status      text,
  status_dot_chance      integer,
  status_dot_expires     integer,
  -- Perce-immunité actif accordé à CE camp (voir pierce_immunity_type) : type
  -- de pokémon dont il ignore l'immunité, et round d'échéance.
  pierce_immunity_type   text,
  pierce_immunity_expires integer,
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
  -- Réglages de la condition 'weight_ratio' (voir autobattle_weight_condition).
  bonus_weight_target            text,
  bonus_weight_comparison        text,
  bonus_weight_percent           integer,
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
  -- Dégâts persistants / vol de vie persistant posés sur l'adversaire, et
  -- perce-immunité accordé au lanceur (voir autobattle_ability_rules).
  damage_dot_config_amount        integer,
  damage_dot_config_turns         integer,
  damage_dot_config_type          text,
  damage_dot_config_percent       integer,
  leech_dot_config_amount         integer,
  leech_dot_config_turns          integer,
  leech_dot_config_type           text,
  leech_dot_config_percent        integer,
  status_dot_config_status        text,
  status_dot_config_chance        integer,
  status_dot_config_turns         integer,
  pierce_immunity_type            text,
  pierce_immunity_turns           integer,
  -- Statut exigé sur la CIBLE pour que la capacité fonctionne (voir
  -- autobattle_ability_rules.requires_target_status) : hors condition, échec.
  requires_target_status          text,
  -- Purges jouées sur un coup réussi (voir autobattle_ability_rules) :
  -- dégâts sur la durée subis par le lanceur, météo en cours, statut du
  -- lanceur.
  clear_damage_dot                boolean,
  clear_weather                   boolean,
  cure_status                     boolean,
  cancel_heal_duration            integer,
  percent_hp_damage_percent       integer,
  percent_hp_damage_basis         text,
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
  ignore_status_block             text,
  -- Météo levée par la capacité (voir autobattle_ability_rules.weather_id) et
  -- sa probabilité, plus la condition « météo en cours » qui autorise ou non son
  -- modificateur de stat (stat_mod_weather_condition/_id).
  weather_id                      bigint,
  weather_chance                  integer,
  stat_mod_weather_condition      text,
  stat_mod_weather_id             bigint,
  -- Sens du modificateur de stat, INDÉPENDANT de sa cible ('buff' = hausse,
  -- 'debuff' = baisse, NULL = ancienne convention déduite de la cible) — voir
  -- autobattle_stat_mod_signed. Ajouté en fin de type pour rester aligné sur
  -- l'ALTER TYPE ... ADD ATTRIBUTE joué sur les bases déjà en place.
  stat_mod_direction              text
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
  next_first_attacker text,
  -- Météo en cours à la fin du round (voir autobattle_weathers) : NULL = aucune.
  -- État de TERRAIN partagé par les deux camps, d'où sa place ici et non dans
  -- autobattle_combatant_state. L'appelant doit le persister dans sa colonne
  -- weather_id et le repasser au round suivant.
  weather_id      bigint
);

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
          v_player.status_dot_status, v_player.status_dot_chance, p_player_talents, v_player.talent_state, p_player_pokemon_type);
        v_player.status := v_dot_res ->> 'status';
        v_player.talent_state := v_dot_res -> 'state';
        v_turns := v_turns || (v_dot_res -> 'turns');
      ELSIF v_attacker = 'opponent' AND v_opponent.status_dot_status IS NOT NULL AND v_opponent.status IS NULL THEN
        v_dot_res := autobattle_status_dot_tick('opponent', v_turn_no, v_opponent.hp, v_opponent.status,
          v_opponent.status_dot_status, v_opponent.status_dot_chance, p_opponent_talents, v_opponent.talent_state, p_opponent_pokemon_type);
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
        v_player.hp, v_player.max_hp, v_opponent.status, v_player.status, p_opponent_talents, v_turn_no, v_weather, p_opponent_pokemon_type);
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
        v_talent_res := autobattle_talent_status_guard(p_opponent_talents, v_opponent.talent_state, 'opponent', v_talent_inflict, v_opponent.hp, v_turn_no, p_opponent_pokemon_type);
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
              v_player.hp, v_player.max_hp, v_opponent.status, v_player.status, p_opponent_talents, v_turn_no, v_weather, p_opponent_pokemon_type);
            v_player.talent_state := v_talent_res -> 'state';
            v_turns := v_turns || (v_talent_res -> 'turns');
            v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, p_weather_enabled, v_weather, 'player', v_player.hp, v_turn_no);
            v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
            v_turns := v_turns || (v_weather_res -> 'turns');
            v_talent_inflict := v_talent_res ->> 'inflict_status';
            IF v_talent_inflict IS NOT NULL THEN
              v_talent_res := autobattle_talent_status_guard(p_opponent_talents, v_opponent.talent_state, 'opponent', v_talent_inflict, v_opponent.hp, v_turn_no, p_opponent_pokemon_type);
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
              CASE WHEN p_player_ability.status_reversed THEN v_player.hp ELSE v_opponent.hp END, v_turn_no,
              CASE WHEN p_player_ability.status_reversed THEN p_player_pokemon_type ELSE p_opponent_pokemon_type END);
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
        v_opponent.hp, v_opponent.max_hp, v_player.status, v_opponent.status, p_player_talents, v_turn_no, v_weather, p_player_pokemon_type);
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
        v_talent_res := autobattle_talent_status_guard(p_player_talents, v_player.talent_state, 'player', v_talent_inflict, v_player.hp, v_turn_no, p_player_pokemon_type);
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
              v_opponent.hp, v_opponent.max_hp, v_player.status, v_opponent.status, p_player_talents, v_turn_no, v_weather, p_player_pokemon_type);
            v_opponent.talent_state := v_talent_res -> 'state';
            v_turns := v_turns || (v_talent_res -> 'turns');
            v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, p_weather_enabled, v_weather, 'opponent', v_opponent.hp, v_turn_no);
            v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
            v_turns := v_turns || (v_weather_res -> 'turns');
            v_talent_inflict := v_talent_res ->> 'inflict_status';
            IF v_talent_inflict IS NOT NULL THEN
              v_talent_res := autobattle_talent_status_guard(p_player_talents, v_player.talent_state, 'player', v_talent_inflict, v_player.hp, v_turn_no, p_player_pokemon_type);
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
              CASE WHEN p_opponent_ability.status_reversed THEN v_opponent.hp ELSE v_player.hp END, v_turn_no,
              CASE WHEN p_opponent_ability.status_reversed THEN p_opponent_pokemon_type ELSE p_player_pokemon_type END);
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

-- Résout un combat Combat Auto de bout en bout, de façon atomique et
-- autoritaire côté serveur (rien n'est fait confiance côté client hormis les
-- 4 identifiants passés en argument — stats, dégâts, avantage de type, coup
-- de dé et issue sont tous recalculés ici à partir de pokemon/attacks).
--
-- Étapes : 1) garde anti-double-soumission (idempotency_key UNIQUE) ;
-- 2) verrouille la ligne de progression niveau (FOR UPDATE) pour sérialiser
-- les tentatives concurrentes du même joueur sur ce niveau ; 3) valide
-- variante/niveau actifs, niveau attendu (pas de saut/rejeu), pokémon/capacité
-- éligibles ; 4) débite 1 ticket (échoue proprement si aucun) ; 5) simule le
-- combat tour par tour (formule : dégâts pokémon ×2 si le TYPE DE LA CAPACITÉ
-- jouée est super efficace contre le type de l'adversaire — voir
-- type_super_effective —, + dégâts de la capacité, jamais doublés ; et coup
-- entièrement annulé si ce type ne peut rien contre l'adversaire, voir
-- type_no_effect) ; 6) à la victoire, crédite toutes les récompenses du
-- niveau et fait avancer la progression ; à la défaite, marque seulement le
-- niveau comme découvert. Tout ceci dans une seule transaction implicite
-- (fonction plpgsql) : soit tout est appliqué, soit rien ne l'est.
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
GRANT EXECUTE ON FUNCTION autobattle_xp_bonus(text, integer, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION autobattle_max_xp(text) TO anon, authenticated;

-- Démarre un combat en mode Manuel (variant.game_mode = 'manual') : crée la
-- ligne autobattle_manual_battles et tire au sort first_attacker AVANT que
-- le joueur choisisse sa 1ère capacité — permet au client d'afficher le
-- tirage au sort (AutoBattleCoinToss, comme en mode Auto) juste après le
-- choix du pokémon, avant même la grille de sélection de capacité (voir
-- requirement). Le ticket est débité ICI, au moment du tirage au sort —
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

-- history_events.category doit accepter la nouvelle catégorie 'autobattle'
ALTER TABLE history_events DROP CONSTRAINT IF EXISTS history_events_category_check;
ALTER TABLE history_events ADD CONSTRAINT history_events_category_check
  CHECK (category IN ('inventory', 'pokedex', 'team', 'combat', 'minigame', 'daycare', 'safari', 'autobattle'));

-- Diffusion Realtime — mêmes raisons que les blocs Fouille/Pension/Safari ci-dessus
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'autobattle_config', 'autobattle_variants', 'autobattle_levels', 'autobattle_level_rewards',
    'autobattle_player_state', 'autobattle_player_variant_progress', 'autobattle_player_level_state',
    'autobattle_battles', 'autobattle_banned_attacks', 'autobattle_ability_rules'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', t);
    END IF;
  END LOOP;
END $$;

-- ============================================================
-- Chat (canal de discussion global temps réel, un seul salon)
-- ============================================================

-- Un message par ligne, joueur (ou PNJ) émetteur. content est du texte brut :
-- les références objet/pokémon/lieu sont détectées à l'affichage côté client
-- (même mécanisme que le texte des chapitres de campagne), rien de spécial
-- n'est stocké ici. player_id référence players.id sans FK, comme le reste
-- du schéma.
CREATE TABLE IF NOT EXISTS chat_messages (
  id          bigserial PRIMARY KEY,
  player_id   bigint NOT NULL,
  content     text NOT NULL,
  is_npc      boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Lecture + écriture + suppression publiques (app sans vraie sécurité, comme
-- le reste du schéma) — la limite anti-spam (admin_parameters.chat_spam_limit_per_minute)
-- et la modération admin (suppression d'un message, "tout effacer") sont donc
-- appliquées côté client uniquement.
CREATE POLICY "Public read chat_messages" ON chat_messages FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert chat_messages" ON chat_messages FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public delete chat_messages" ON chat_messages FOR DELETE TO anon USING (true);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
  END IF;
END $$;

-- Paramètres du chat + activation/désactivation de la fonctionnalité (Admin → Paramètres)
ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_chat_enabled boolean NOT NULL DEFAULT true;
ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS chat_max_message_length integer NOT NULL DEFAULT 300;
ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS chat_spam_limit_per_minute integer NOT NULL DEFAULT 3;
-- Horodatage du dernier message joueur (non-PNJ) notifié par le job horaire
-- (netlify/functions/send-notifications.js) — distinct du push instantané des
-- messages PNJ envoyés depuis Admin → Chat (netlify/functions/send-chat-notification.js),
-- qui ne passe pas par ce job.
ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS chat_last_notified_at timestamptz;

-- history_events.category doit accepter la nouvelle catégorie 'chat'
ALTER TABLE history_events DROP CONSTRAINT IF EXISTS history_events_category_check;
ALTER TABLE history_events ADD CONSTRAINT history_events_category_check
  CHECK (category IN ('inventory', 'pokedex', 'team', 'combat', 'minigame', 'daycare', 'safari', 'autobattle', 'chat'));

-- ============================================================
-- Échanges entre joueurs (proposés/acceptés depuis une carte dans le Chat)
-- ============================================================

-- Une offre d'échange publique (n'importe quel joueur peut l'accepter, pas de
-- destinataire fixé). offer = ce que le proposeur donne, request = ce qu'il
-- demande en retour. Forme de offer/request selon kind (voir src/types.ts) :
--   kind = 'item'    : {"items": [{"item_nom": text, "quantity": int}, ...]} (max 3 côté client)
--   kind = 'pokemon' : offer = {"player_pokemon_id": int}
--                      request = {"pokemon_nom": text}  -- espèce précise demandée
--                             ou {"pokemon_nom": null}   -- "N'importe quel Pokémon non possédé"
-- La création est un simple INSERT client (pas de RPC : aucune contrainte
-- d'atomicité à ce stade, juste une proposition). L'acceptation/l'annulation
-- passent par les fonctions ci-dessous, qui revalident tout côté serveur.
CREATE TABLE IF NOT EXISTS trades (
  id           bigserial PRIMARY KEY,
  kind         text NOT NULL CHECK (kind IN ('item', 'pokemon')),
  proposer_id  bigint NOT NULL,
  status       text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
  offer        jsonb NOT NULL,
  request      jsonb NOT NULL,
  accepted_by  bigint,
  resolved_at  timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_trades_status ON trades(status);

ALTER TABLE trades ENABLE ROW LEVEL SECURITY;

-- Lecture + écriture publiques (app sans vraie sécurité, comme le reste du
-- schéma) — trade_accept/trade_cancel ci-dessous tournent en tant qu'invoker
-- (anon), d'où la policy UPDATE : ce sont les vérifications internes aux
-- fonctions (propriété, quantités, statut 'pending') qui protègent l'intégrité
-- des échanges, pas RLS.
CREATE POLICY "Public read trades" ON trades FOR SELECT TO anon USING (true);
CREATE POLICY "Public insert trades" ON trades FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Public update trades" ON trades FOR UPDATE TO anon USING (true) WITH CHECK (true);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'trades'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE trades;
  END IF;
END $$;

-- Carte d'échange dans le Chat : un message peut référencer un échange (au lieu
-- de porter du texte libre) — la carte se met à jour en suivant trades.status
-- en temps réel côté client, le message lui-même ne change jamais après envoi.
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS message_type text NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'trade'));
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS trade_id bigint;

-- Accepte un échange en attente : revalide que le proposeur possède toujours
-- l'offre et que l'acceptant possède bien ce qui est demandé, puis effectue le
-- transfert des deux côtés dans la même transaction. p_chosen_player_pokemon_id
-- n'est utilisé que pour kind = 'pokemon' : l'instance précise (avec son
-- surnom/XP/capacités) que l'acceptant cède en retour.
CREATE OR REPLACE FUNCTION trade_accept(p_trade_id bigint, p_player_id bigint, p_chosen_player_pokemon_id bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_trade trades%ROWTYPE;
  v_item jsonb;
  v_have integer;
  v_offer_owner bigint;
  v_chosen_owner bigint;
  v_chosen_nom text;
  v_requested_nom text;
  v_already_owned integer;
BEGIN
  SELECT * INTO v_trade FROM trades WHERE id = p_trade_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('status', 'not_found'); END IF;
  IF v_trade.status <> 'pending' THEN RETURN jsonb_build_object('status', 'already_resolved'); END IF;
  IF v_trade.proposer_id = p_player_id THEN RETURN jsonb_build_object('status', 'cannot_accept_own'); END IF;

  IF v_trade.kind = 'item' THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_trade.offer->'items') LOOP
      SELECT quantity INTO v_have FROM player_items
        WHERE player_id = v_trade.proposer_id AND item_nom = v_item->>'item_nom' FOR UPDATE;
      IF COALESCE(v_have, 0) < (v_item->>'quantity')::integer THEN
        RETURN jsonb_build_object('status', 'offer_no_longer_available');
      END IF;
    END LOOP;
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_trade.request->'items') LOOP
      SELECT quantity INTO v_have FROM player_items
        WHERE player_id = p_player_id AND item_nom = v_item->>'item_nom' FOR UPDATE;
      IF COALESCE(v_have, 0) < (v_item->>'quantity')::integer THEN
        RETURN jsonb_build_object('status', 'insufficient_items');
      END IF;
    END LOOP;

    FOR v_item IN SELECT * FROM jsonb_array_elements(v_trade.offer->'items') LOOP
      UPDATE player_items SET quantity = quantity - (v_item->>'quantity')::integer
        WHERE player_id = v_trade.proposer_id AND item_nom = v_item->>'item_nom';
      INSERT INTO player_items (player_id, item_nom, quantity)
        VALUES (p_player_id, v_item->>'item_nom', (v_item->>'quantity')::integer)
        ON CONFLICT (player_id, item_nom) DO UPDATE SET quantity = player_items.quantity + EXCLUDED.quantity;
    END LOOP;
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_trade.request->'items') LOOP
      UPDATE player_items SET quantity = quantity - (v_item->>'quantity')::integer
        WHERE player_id = p_player_id AND item_nom = v_item->>'item_nom';
      INSERT INTO player_items (player_id, item_nom, quantity)
        VALUES (v_trade.proposer_id, v_item->>'item_nom', (v_item->>'quantity')::integer)
        ON CONFLICT (player_id, item_nom) DO UPDATE SET quantity = player_items.quantity + EXCLUDED.quantity;
    END LOOP;

  ELSE -- kind = 'pokemon'
    SELECT player_id INTO v_offer_owner
      FROM player_pokemon WHERE id = (v_trade.offer->>'player_pokemon_id')::bigint FOR UPDATE;
    IF v_offer_owner IS NULL OR v_offer_owner <> v_trade.proposer_id THEN
      RETURN jsonb_build_object('status', 'offer_no_longer_available');
    END IF;

    IF p_chosen_player_pokemon_id IS NULL THEN
      RETURN jsonb_build_object('status', 'no_pokemon_chosen');
    END IF;
    SELECT player_id, pokemon_nom INTO v_chosen_owner, v_chosen_nom
      FROM player_pokemon WHERE id = p_chosen_player_pokemon_id FOR UPDATE;
    IF v_chosen_owner IS NULL OR v_chosen_owner <> p_player_id THEN
      RETURN jsonb_build_object('status', 'not_owner');
    END IF;

    v_requested_nom := v_trade.request->>'pokemon_nom';
    IF v_requested_nom IS NOT NULL THEN
      IF v_chosen_nom <> v_requested_nom THEN
        RETURN jsonb_build_object('status', 'wrong_species');
      END IF;
    ELSE
      SELECT count(*) INTO v_already_owned
        FROM player_pokemon WHERE player_id = v_trade.proposer_id AND pokemon_nom = v_chosen_nom;
      IF v_already_owned > 0 THEN
        RETURN jsonb_build_object('status', 'already_owned');
      END IF;
    END IF;

    UPDATE player_pokemon SET player_id = p_player_id, in_team = false
      WHERE id = (v_trade.offer->>'player_pokemon_id')::bigint;
    UPDATE player_pokemon SET player_id = v_trade.proposer_id, in_team = false
      WHERE id = p_chosen_player_pokemon_id;
  END IF;

  UPDATE trades SET status = 'completed', accepted_by = p_player_id, resolved_at = now() WHERE id = p_trade_id;
  RETURN jsonb_build_object('status', 'ok');
END;
$$;

-- Annule un échange encore en attente (uniquement par son proposeur).
CREATE OR REPLACE FUNCTION trade_cancel(p_trade_id bigint, p_player_id bigint)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_trade trades%ROWTYPE;
BEGIN
  SELECT * INTO v_trade FROM trades WHERE id = p_trade_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('status', 'not_found'); END IF;
  IF v_trade.status <> 'pending' THEN RETURN jsonb_build_object('status', 'already_resolved'); END IF;
  IF v_trade.proposer_id <> p_player_id THEN RETURN jsonb_build_object('status', 'not_proposer'); END IF;

  UPDATE trades SET status = 'cancelled', resolved_at = now() WHERE id = p_trade_id;
  RETURN jsonb_build_object('status', 'ok');
END;
$$;

GRANT EXECUTE ON FUNCTION trade_accept(bigint, bigint, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION trade_cancel(bigint, bigint) TO anon, authenticated;

-- ============================================================
-- Message de conclusion d'échange (carte "Voir l'échange" + notification)
-- ============================================================

-- Espèce/surnom effectivement cédés par l'acceptant côté Pokémon — dénormalisé
-- au moment de l'acceptation (comme trades.offer.pokemon_nom/nickname au moment
-- de la création) pour permettre l'affichage du message de conclusion et le
-- rejeu de l'animation d'échange sans avoir à retrouver l'instance d'origine
-- (qui a pu changer de main depuis). NULL pour les échanges d'objets.
ALTER TABLE trades ADD COLUMN IF NOT EXISTS resolved_pokemon_nom text;
ALTER TABLE trades ADD COLUMN IF NOT EXISTS resolved_pokemon_nickname text;

-- chat_messages.message_type doit accepter la nouvelle valeur 'trade_completed'
-- (message de conclusion envoyé par l'acceptant, distinct de la carte de
-- proposition 'trade' d'origine — voir src/components/chat/TradeCompletedCard.tsx)
ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS chat_messages_message_type_check;
ALTER TABLE chat_messages ADD CONSTRAINT chat_messages_message_type_check
  CHECK (message_type IN ('text', 'trade', 'trade_completed'));

-- Redéfinition de trade_accept : capture en plus l'espèce/surnom cédés par
-- l'acceptant (v_chosen_nickname) et les enregistre dans resolved_pokemon_nom/
-- resolved_pokemon_nickname à la conclusion — reste de la fonction inchangé.
CREATE OR REPLACE FUNCTION trade_accept(p_trade_id bigint, p_player_id bigint, p_chosen_player_pokemon_id bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_trade trades%ROWTYPE;
  v_item jsonb;
  v_have integer;
  v_offer_owner bigint;
  v_chosen_owner bigint;
  v_chosen_nom text;
  v_chosen_nickname text;
  v_requested_nom text;
  v_already_owned integer;
BEGIN
  SELECT * INTO v_trade FROM trades WHERE id = p_trade_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('status', 'not_found'); END IF;
  IF v_trade.status <> 'pending' THEN RETURN jsonb_build_object('status', 'already_resolved'); END IF;
  IF v_trade.proposer_id = p_player_id THEN RETURN jsonb_build_object('status', 'cannot_accept_own'); END IF;

  IF v_trade.kind = 'item' THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_trade.offer->'items') LOOP
      SELECT quantity INTO v_have FROM player_items
        WHERE player_id = v_trade.proposer_id AND item_nom = v_item->>'item_nom' FOR UPDATE;
      IF COALESCE(v_have, 0) < (v_item->>'quantity')::integer THEN
        RETURN jsonb_build_object('status', 'offer_no_longer_available');
      END IF;
    END LOOP;
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_trade.request->'items') LOOP
      SELECT quantity INTO v_have FROM player_items
        WHERE player_id = p_player_id AND item_nom = v_item->>'item_nom' FOR UPDATE;
      IF COALESCE(v_have, 0) < (v_item->>'quantity')::integer THEN
        RETURN jsonb_build_object('status', 'insufficient_items');
      END IF;
    END LOOP;

    FOR v_item IN SELECT * FROM jsonb_array_elements(v_trade.offer->'items') LOOP
      UPDATE player_items SET quantity = quantity - (v_item->>'quantity')::integer
        WHERE player_id = v_trade.proposer_id AND item_nom = v_item->>'item_nom';
      INSERT INTO player_items (player_id, item_nom, quantity)
        VALUES (p_player_id, v_item->>'item_nom', (v_item->>'quantity')::integer)
        ON CONFLICT (player_id, item_nom) DO UPDATE SET quantity = player_items.quantity + EXCLUDED.quantity;
    END LOOP;
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_trade.request->'items') LOOP
      UPDATE player_items SET quantity = quantity - (v_item->>'quantity')::integer
        WHERE player_id = p_player_id AND item_nom = v_item->>'item_nom';
      INSERT INTO player_items (player_id, item_nom, quantity)
        VALUES (v_trade.proposer_id, v_item->>'item_nom', (v_item->>'quantity')::integer)
        ON CONFLICT (player_id, item_nom) DO UPDATE SET quantity = player_items.quantity + EXCLUDED.quantity;
    END LOOP;

  ELSE -- kind = 'pokemon'
    SELECT player_id INTO v_offer_owner
      FROM player_pokemon WHERE id = (v_trade.offer->>'player_pokemon_id')::bigint FOR UPDATE;
    IF v_offer_owner IS NULL OR v_offer_owner <> v_trade.proposer_id THEN
      RETURN jsonb_build_object('status', 'offer_no_longer_available');
    END IF;

    IF p_chosen_player_pokemon_id IS NULL THEN
      RETURN jsonb_build_object('status', 'no_pokemon_chosen');
    END IF;
    SELECT player_id, pokemon_nom, nickname INTO v_chosen_owner, v_chosen_nom, v_chosen_nickname
      FROM player_pokemon WHERE id = p_chosen_player_pokemon_id FOR UPDATE;
    IF v_chosen_owner IS NULL OR v_chosen_owner <> p_player_id THEN
      RETURN jsonb_build_object('status', 'not_owner');
    END IF;

    v_requested_nom := v_trade.request->>'pokemon_nom';
    IF v_requested_nom IS NOT NULL THEN
      IF v_chosen_nom <> v_requested_nom THEN
        RETURN jsonb_build_object('status', 'wrong_species');
      END IF;
    ELSE
      SELECT count(*) INTO v_already_owned
        FROM player_pokemon WHERE player_id = v_trade.proposer_id AND pokemon_nom = v_chosen_nom;
      IF v_already_owned > 0 THEN
        RETURN jsonb_build_object('status', 'already_owned');
      END IF;
    END IF;

    UPDATE player_pokemon SET player_id = p_player_id, in_team = false
      WHERE id = (v_trade.offer->>'player_pokemon_id')::bigint;
    UPDATE player_pokemon SET player_id = v_trade.proposer_id, in_team = false
      WHERE id = p_chosen_player_pokemon_id;
  END IF;

  UPDATE trades SET
    status = 'completed',
    accepted_by = p_player_id,
    resolved_at = now(),
    resolved_pokemon_nom = v_chosen_nom,
    resolved_pokemon_nickname = v_chosen_nickname
  WHERE id = p_trade_id;
  RETURN jsonb_build_object('status', 'ok');
END;
$$;

GRANT EXECUTE ON FUNCTION trade_accept(bigint, bigint, bigint) TO anon, authenticated;

-- history_events n'avait pas de policy DELETE (journal pensé immuable côté
-- client) — mais Admin → Historique expose un bouton "Vider l'historique"
-- (useHistoryEvents.clearAll) qui appelle .delete().neq('id', 0). Sans policy,
-- RLS filtre silencieusement toutes les lignes de la suppression : la requête
-- réussit (aucune erreur renvoyée) mais supprime 0 ligne, donc les données
-- reviennent au prochain fetchAll/rechargement alors que l'UI les affichait
-- comme supprimées.
CREATE POLICY "Public delete history_events"
  ON history_events FOR DELETE TO anon USING (true);


-- ============================================================
-- Défi PvP (bannières de défi joueur contre joueur — gratuit, sans ticket, sans
-- récompense : le seul but est de prouver sa valeur face aux autres joueurs)
-- ============================================================
--
-- Un joueur pose un de ses pokémon (Équipe ou PC) en "défenseur" avec jusqu'à
-- 4 capacités choisies dans un ORDRE précis (boucle) : ceci crée une
-- bannière visible de tous, jouable gratuitement et sans limite de tentatives
-- par n'importe quel AUTRE joueur, qui affronte ce défenseur en Combat Manuel
-- (comme Combat Auto en mode 'manual', voir plus haut dans ce fichier) — le
-- défenseur n'est jamais actif pendant le combat, ses capacités tournent
-- simplement en boucle (même mécanique que opponent_ability_nom_1..10/
-- opponent_ability_cycle_index de Combat Auto, juste bornée à 4 positions).
--
-- Le défenseur posé est un INSTANTANÉ figé au moment du dépôt (espèce, PV/
-- dégâts dérivés de l'XP au moment du dépôt, capacités choisies) : le
-- pokémon réel n'est JAMAIS bloqué, son propriétaire continue de l'utiliser
-- normalement ailleurs (Équipe, Combat Auto...) pendant qu'il défend cette
-- bannière, et les changements ultérieurs (XP gagnée, capacités changées,
-- évolution) n'affectent jamais un défi déjà posé (voir pvp_post_challenge).
-- Retirer un défi puis en reposer un nouveau crée une toute NOUVELLE ligne
-- (nouvel id) : impossible de modifier un défi actif en place, il faut
-- repasser par ce cycle — le tableau des scores (pvp_challenge_attempts,
-- rattaché à l'INSTANCE via challenge_id, pas au joueur défenseur) repart
-- donc naturellement à zéro à chaque repose.
--
-- Moteur de combat : pvp_resolve_round délègue sa boucle de résolution à
-- autobattle_resolve_round_core (voir juste après autobattle_ability_burst
-- plus haut dans ce fichier) — le MÊME moteur partagé que Combat Auto en
-- mode Manuel (autobattle_resolve_manual_round a été restructuré pour
-- déléguer à ce même moteur), aucune duplication de la boucle de résolution
-- elle-même. Seul ce qui diffère structurellement reste propre à chaque
-- appelant : le défenseur Combat Auto est un NPC configuré à plat
-- (autobattle_levels.opponent_hp/opponent_base_damage, nombres admin fixes),
-- suivant une progression de niveaux séquentielle payante par ticket, alors
-- que le défenseur PvP est un instantané dérivé espèce+XP comme un vrai
-- joueur (pvp_challenges), gratuit et rejouable à l'infini, sans notion de
-- Métamorph (limitation volontaire, comme le mode Manuel de Combat Auto ne
-- la gère déjà que côté adversaire) : un Métamorph posé en défenseur se
-- comporte comme une espèce normale. Le JSON renvoyé par pvp_resolve_round
-- réutilise VOLONTAIREMENT le vocabulaire 'player'/'opponent' du moteur
-- partagé (AutoBattleTurn/AutoBattleManualRoundResult — l'attaquant =
-- 'player', le défenseur figé = 'opponent') pour que AutoBattleScreen/
-- ManualBattleScreen (src/components/autoBattle/) soient réutilisés tels
-- quels côté client, sans aucune modification.

ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_pvp_enabled boolean NOT NULL DEFAULT true;

CREATE TABLE IF NOT EXISTS pvp_config (
  id                 bigint PRIMARY KEY DEFAULT 1,
  nom                text NOT NULL DEFAULT 'Défi PvP',
  icon_url           text NOT NULL DEFAULT '',
  -- Voir autobattle_config.precision_enabled : même bascule globale, propre
  -- à ce mode de jeu (peut différer du réglage Combat Auto).
  precision_enabled  boolean NOT NULL DEFAULT true,
  -- Nombre maximum de capacités dans la boucle défensive d'un défi (voir
  -- pvp_challenges.ability_noms/pvp_post_challenge) — les doublons comptent
  -- (une même capacité peut occuper plusieurs positions de la boucle).
  loadout_max        integer NOT NULL DEFAULT 4 CHECK (loadout_max BETWEEN 1 AND 8),
  -- Adversaire d'entraînement du bouton "Tester" (voir pvp_trial_battles /
  -- pvp_trial_start plus bas) : un pokémon "PV élevés + capacité anodine"
  -- choisi par l'admin, purement pour laisser un joueur observer sa boucle
  -- en action avant de la poster réellement — trial_hp est un nombre FIXE
  -- (pas dérivé d'XP, ce pokémon n'existe dans aucun roster) ; trial_ability_
  -- nom est une SEULE capacité (pas de boucle, toujours la même à chaque
  -- tour). Vide par défaut : pvp_trial_start refuse tant que non configuré.
  trial_pokemon_nom  text NOT NULL DEFAULT '',
  trial_hp           integer NOT NULL DEFAULT 80 CHECK (trial_hp > 0),
  trial_ability_nom  text NOT NULL DEFAULT '',
  -- Bannières décoratives optionnelles (image via URL, voir GameBanner)
  -- affichées au-dessus des titres "Champion Actuel"/"Challengers" dans le
  -- popup (voir PvpPopup) — vide par défaut, purement cosmétique.
  champion_banner_url     text NOT NULL DEFAULT '',
  challengers_banner_url  text NOT NULL DEFAULT '',
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO pvp_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
-- Mise à jour si la table existe déjà :
ALTER TABLE pvp_config ADD COLUMN IF NOT EXISTS loadout_max integer NOT NULL DEFAULT 4;
ALTER TABLE pvp_config DROP CONSTRAINT IF EXISTS pvp_config_loadout_max_check;
ALTER TABLE pvp_config ADD CONSTRAINT pvp_config_loadout_max_check CHECK (loadout_max BETWEEN 1 AND 8);
ALTER TABLE pvp_config ADD COLUMN IF NOT EXISTS trial_pokemon_nom text NOT NULL DEFAULT '';
ALTER TABLE pvp_config ADD COLUMN IF NOT EXISTS trial_hp integer NOT NULL DEFAULT 80;
ALTER TABLE pvp_config DROP CONSTRAINT IF EXISTS pvp_config_trial_hp_check;
ALTER TABLE pvp_config ADD CONSTRAINT pvp_config_trial_hp_check CHECK (trial_hp > 0);
ALTER TABLE pvp_config ADD COLUMN IF NOT EXISTS trial_ability_nom text NOT NULL DEFAULT '';
ALTER TABLE pvp_config ADD COLUMN IF NOT EXISTS champion_banner_url text NOT NULL DEFAULT '';
ALTER TABLE pvp_config ADD COLUMN IF NOT EXISTS challengers_banner_url text NOT NULL DEFAULT '';
-- Voir autobattle_config.talents_enabled : même bascule globale, propre à ce
-- mode de jeu (elle couvre aussi le combat d'essai "Tester").
ALTER TABLE pvp_config ADD COLUMN IF NOT EXISTS talents_enabled boolean NOT NULL DEFAULT true;
-- Voir autobattle_config.weather_enabled : idem pour la météo.
ALTER TABLE pvp_config ADD COLUMN IF NOT EXISTS weather_enabled boolean NOT NULL DEFAULT true;

CREATE TABLE IF NOT EXISTS pvp_challenges (
  id                        bigserial PRIMARY KEY,
  defender_player_id        bigint NOT NULL,
  -- Référence de traçabilité uniquement (affichage admin) : jamais relue
  -- pour les stats de combat une fois le défi posé, voir max_hp/
  -- damage_species_xp ci-dessous (instantané figé).
  source_player_pokemon_id  bigint NOT NULL,
  pokemon_nom               text NOT NULL,
  pokemon_numero            text,
  nickname                  text,
  xp                        integer NOT NULL DEFAULT 0,
  -- PV/dégâts FIGÉS au moment du dépôt (espèce + bonus XP, formule identique
  -- à autobattle_xp_bonus déjà utilisée par Combat Auto) — jamais recalculés
  -- ensuite, même si le pokémon réel gagne de l'XP par la suite.
  max_hp                    integer NOT NULL CHECK (max_hp > 0),
  damage_species_xp         integer NOT NULL DEFAULT 0,
  -- Boucle défensive, DANS L'ORDRE — les doublons sont autorisés (une même
  -- capacité peut occuper plusieurs positions, voir pvp_post_challenge) et
  -- comptent chacun pour la limite pvp_config.loadout_max. Remplace
  -- l'ancien ability_nom_1..4 (colonnes fixes) par un tableau de longueur
  -- variable — voir bloc de migration juste en dessous pour les bases déjà
  -- créées avec l'ancien schéma.
  ability_noms              text[] NOT NULL CHECK (array_length(ability_noms, 1) >= 1),
  active                    boolean NOT NULL DEFAULT true,
  withdrawn_at              timestamptz,
  idempotency_key           uuid NOT NULL,
  created_at                timestamptz NOT NULL DEFAULT now(),
  -- Titre de Champion (voir pvp_promote_to_champion plus bas) : au plus une
  -- ligne active à la fois porte is_champion = true (sérialisé par un verrou
  -- advisory, pas de contrainte DB — même idiome que le reste du fichier).
  -- Une promotion crée TOUJOURS une NOUVELLE ligne (jamais un flip en place)
  -- pour repartir avec un tableau des scores vierge (pvp_challenge_attempts,
  -- rattaché à l'INSTANCE) : created_at sert alors de "Champion depuis" côté
  -- client (voir PvpChampionBanner), donc toujours frais à la promotion.
  is_champion               boolean NOT NULL DEFAULT false,
  UNIQUE (idempotency_key)
);
CREATE INDEX IF NOT EXISTS idx_pvp_challenges_defender ON pvp_challenges(defender_player_id, active);
ALTER TABLE pvp_challenges ADD COLUMN IF NOT EXISTS is_champion boolean NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_pvp_challenges_champion ON pvp_challenges(is_champion) WHERE is_champion AND active;
-- Migration si la table existe déjà avec l'ancien schéma (colonnes fixes
-- ability_nom_1..4, sans doublons possibles) :
ALTER TABLE pvp_challenges ADD COLUMN IF NOT EXISTS ability_noms text[];
-- EXECUTE dynamique : une simple UPDATE statique référençant ability_nom_1..4
-- échoue dès la planification (colonne inexistante, erreur 42703) si la table
-- a été créée directement avec ability_noms (jamais eu l'ancien schéma) —
-- contrairement à un WHERE EXISTS, qui ne protège que les LIGNES concernées,
-- pas la validité de la requête elle-même.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'pvp_challenges' AND column_name = 'ability_nom_1') THEN
    EXECUTE 'UPDATE pvp_challenges SET ability_noms = array_remove(ARRAY[ability_nom_1, ability_nom_2, ability_nom_3, ability_nom_4], NULL) WHERE ability_noms IS NULL';
  END IF;
END $$;
ALTER TABLE pvp_challenges ALTER COLUMN ability_noms SET NOT NULL;
ALTER TABLE pvp_challenges DROP CONSTRAINT IF EXISTS pvp_challenges_ability_noms_check;
ALTER TABLE pvp_challenges ADD CONSTRAINT pvp_challenges_ability_noms_check CHECK (array_length(ability_noms, 1) >= 1);
ALTER TABLE pvp_challenges DROP COLUMN IF EXISTS ability_nom_1;
ALTER TABLE pvp_challenges DROP COLUMN IF EXISTS ability_nom_2;
ALTER TABLE pvp_challenges DROP COLUMN IF EXISTS ability_nom_3;
ALTER TABLE pvp_challenges DROP COLUMN IF EXISTS ability_nom_4;

-- État vivant (éphémère) d'une tentative en cours contre un défi — même
-- rôle que autobattle_manual_battles, mais symétrique : attacker_* = le
-- joueur qui tente sa chance (pokémon réel, capacité choisie à CHAQUE tour),
-- defender_* = l'instantané figé du défi (pvp_challenges), dont les capacités
-- (jusqu'à 4) tournent en boucle via defender_ability_cycle_index — une
-- position par NOUVEAU tour défenseur, même mécanique que autobattle_
-- manual_battles.opponent_ability_cycle_index, juste bornée à 4 positions au
-- lieu de 10 (voir pvp_resolve_round). Une seule ligne active à la fois par
-- (attacker_player_id, challenge_id) : un attaquant peut retenter autant de
-- fois qu'il veut, chaque nouvelle tentative (pvp_start_battle) purge et
-- recrée cette ligne. started_at sert de base au calcul de la durée affichée
-- sur le tableau des scores ("Victoire en XXs", voir pvp_resolve_round).
CREATE TABLE IF NOT EXISTS pvp_battles (
  id                               bigserial PRIMARY KEY,
  challenge_id                     bigint NOT NULL REFERENCES pvp_challenges(id) ON DELETE CASCADE,
  attacker_player_id               bigint NOT NULL,
  attacker_player_pokemon_id       bigint NOT NULL,
  first_attacker                   text NOT NULL CHECK (first_attacker IN ('attacker', 'defender')),
  turn_no                          integer NOT NULL DEFAULT 0,
  round_no                         integer NOT NULL DEFAULT 0,
  attacker_hp                      integer NOT NULL,
  attacker_max_hp                  integer NOT NULL,
  defender_hp                      integer NOT NULL,
  defender_max_hp                  integer NOT NULL,
  attacker_status                  text,
  defender_status                  text,
  attacker_damage_mod_amount       integer NOT NULL DEFAULT 0,
  attacker_damage_mod_expires      integer,
  attacker_precision_mod_amount    integer NOT NULL DEFAULT 0,
  attacker_precision_mod_expires   integer,
  defender_damage_mod_amount       integer NOT NULL DEFAULT 0,
  defender_damage_mod_expires      integer,
  defender_precision_mod_amount    integer NOT NULL DEFAULT 0,
  defender_precision_mod_expires   integer,
  attacker_heal_dot_amount         integer,
  attacker_heal_dot_expires        integer,
  defender_heal_dot_amount         integer,
  defender_heal_dot_expires        integer,
  attacker_heal_disabled_expires   integer,
  defender_heal_disabled_expires   integer,
  attacker_invulnerable            boolean NOT NULL DEFAULT false,
  attacker_invuln_granted_round    integer,
  defender_invulnerable            boolean NOT NULL DEFAULT false,
  defender_invuln_granted_round    integer,
  attacker_stat_mod_uses           jsonb NOT NULL DEFAULT '{}'::jsonb,
  defender_stat_mod_uses           jsonb NOT NULL DEFAULT '{}'::jsonb,
  attacker_used_ability             boolean NOT NULL DEFAULT false,
  attacker_took_damage              boolean NOT NULL DEFAULT false,
  defender_used_ability             boolean NOT NULL DEFAULT false,
  defender_took_damage              boolean NOT NULL DEFAULT false,
  attacker_skip_pending             boolean NOT NULL DEFAULT false,
  defender_skip_pending             boolean NOT NULL DEFAULT false,
  attacker_preparing                boolean NOT NULL DEFAULT false,
  defender_preparing                boolean NOT NULL DEFAULT false,
  attacker_preparing_ability_nom    text,
  defender_preparing_ability_nom    text,
  defender_ability_cycle_index      integer NOT NULL DEFAULT 0,
  turn_log                          jsonb NOT NULL DEFAULT '[]'::jsonb,
  outcome                           text CHECK (outcome IS NULL OR outcome IN ('win', 'lose')),
  started_at                        timestamptz NOT NULL DEFAULT now(),
  last_idempotency_key              uuid,
  last_result                       jsonb,
  created_at                        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (attacker_player_id, challenge_id)
);

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

-- Effets persistants offensifs subis / perce-immunité accordé (voir les mêmes
-- colonnes sur autobattle_manual_battles).
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_damage_dot_amount integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_damage_dot_expires integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_damage_dot_amount integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_damage_dot_expires integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_leech_dot_amount integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_leech_dot_expires integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_leech_dot_amount integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_leech_dot_expires integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_pierce_immunity_type text;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_pierce_immunity_expires integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_pierce_immunity_type text;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_pierce_immunity_expires integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_status_dot_status text;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_status_dot_chance integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_status_dot_expires integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_status_dot_status text;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_status_dot_chance integer;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_status_dot_expires integer;

-- Piles de modificateurs de stat (voir autobattle_mod_total) : remplacent les
-- colonnes *_damage_mod_amount/_expires/_type_filter et *_precision_mod_amount/
-- _expires, qui ne portaient qu'UN modificateur écrasable par camp et par stat.
-- Les anciennes colonnes sont laissées en place (inutilisées) plutôt que
-- supprimées, pour ne pas casser un combat déjà en cours au moment de la
-- migration.
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_damage_mods jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_damage_mods jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_precision_mods jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_precision_mods jsonb NOT NULL DEFAULT '[]'::jsonb;

-- Talents d'espèce déjà déclenchés (voir autobattle_talents / talent_state).
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS attacker_talent_state jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS defender_talent_state jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Météo en cours — voir autobattle_manual_battles.weather_id (même rôle, une
-- seule colonne pour les deux camps).
ALTER TABLE pvp_battles ADD COLUMN IF NOT EXISTS weather_id bigint;

-- Journal figé des tentatives terminées — le tableau des scores affiché sous
-- chaque bannière (voir PvpChallengeBanner côté client) : une ligne par
-- tentative résolue (gagnée ou perdue), rattachée à l'INSTANCE de défi
-- (challenge_id, pas defender_player_id) pour que le tableau reparte à zéro
-- à chaque retrait/repose (voir pvp_challenges). duration_turns n'est
-- renseigné qu'en cas de victoire ("X tours" côté client) — jeu au tour par
-- tour, compter des SECONDES n'avait pas de sens (voir pvp_resolve_round,
-- calculé depuis round_no plutôt que started_at/now()) ; defender_hp_remaining
-- qu'en cas de défaite ("XX PV" côté client).
CREATE TABLE IF NOT EXISTS pvp_challenge_attempts (
  id                          bigserial PRIMARY KEY,
  challenge_id                bigint NOT NULL REFERENCES pvp_challenges(id) ON DELETE CASCADE,
  defender_player_id          bigint NOT NULL,
  attacker_player_id          bigint NOT NULL,
  attacker_player_pokemon_id  bigint NOT NULL,
  attacker_pokemon_nom        text NOT NULL,
  outcome                     text NOT NULL CHECK (outcome IN ('win', 'lose')),
  duration_turns              integer,
  defender_hp_remaining       integer,
  idempotency_key             uuid NOT NULL,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (idempotency_key)
);
CREATE INDEX IF NOT EXISTS idx_pvp_challenge_attempts_challenge ON pvp_challenge_attempts(challenge_id, created_at DESC);
-- Migration si la table existe déjà avec l'ancienne colonne (secondes réelles) :
ALTER TABLE pvp_challenge_attempts ADD COLUMN IF NOT EXISTS duration_turns integer;
ALTER TABLE pvp_challenge_attempts DROP COLUMN IF EXISTS duration_seconds;

ALTER TABLE pvp_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE pvp_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE pvp_battles ENABLE ROW LEVEL SECURITY;
ALTER TABLE pvp_challenge_attempts ENABLE ROW LEVEL SECURITY;

-- Lecture + écriture publiques partout (app sans vraie sécurité, comme le
-- reste du schéma) — pvp_resolve_round s'exécute avec le rôle appelant
-- (anon), pas en SECURITY DEFINER, elle a donc besoin de ces mêmes policies.
DROP POLICY IF EXISTS "Public read pvp_config" ON pvp_config;
CREATE POLICY "Public read pvp_config" ON pvp_config FOR SELECT TO anon USING (true);
DROP POLICY IF EXISTS "Public update pvp_config" ON pvp_config;
CREATE POLICY "Public update pvp_config" ON pvp_config FOR UPDATE TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public read pvp_challenges" ON pvp_challenges;
CREATE POLICY "Public read pvp_challenges" ON pvp_challenges FOR SELECT TO anon USING (true);
DROP POLICY IF EXISTS "Public insert pvp_challenges" ON pvp_challenges;
CREATE POLICY "Public insert pvp_challenges" ON pvp_challenges FOR INSERT TO anon WITH CHECK (true);
DROP POLICY IF EXISTS "Public update pvp_challenges" ON pvp_challenges;
CREATE POLICY "Public update pvp_challenges" ON pvp_challenges FOR UPDATE TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Public delete pvp_challenges" ON pvp_challenges;
CREATE POLICY "Public delete pvp_challenges" ON pvp_challenges FOR DELETE TO anon USING (true);

DROP POLICY IF EXISTS "Public read pvp_battles" ON pvp_battles;
CREATE POLICY "Public read pvp_battles" ON pvp_battles FOR SELECT TO anon USING (true);
DROP POLICY IF EXISTS "Public insert pvp_battles" ON pvp_battles;
CREATE POLICY "Public insert pvp_battles" ON pvp_battles FOR INSERT TO anon WITH CHECK (true);
DROP POLICY IF EXISTS "Public update pvp_battles" ON pvp_battles;
CREATE POLICY "Public update pvp_battles" ON pvp_battles FOR UPDATE TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Public delete pvp_battles" ON pvp_battles;
CREATE POLICY "Public delete pvp_battles" ON pvp_battles FOR DELETE TO anon USING (true);

DROP POLICY IF EXISTS "Public read pvp_challenge_attempts" ON pvp_challenge_attempts;
CREATE POLICY "Public read pvp_challenge_attempts" ON pvp_challenge_attempts FOR SELECT TO anon USING (true);
DROP POLICY IF EXISTS "Public insert pvp_challenge_attempts" ON pvp_challenge_attempts;
CREATE POLICY "Public insert pvp_challenge_attempts" ON pvp_challenge_attempts FOR INSERT TO anon WITH CHECK (true);
DROP POLICY IF EXISTS "Public delete pvp_challenge_attempts" ON pvp_challenge_attempts;
CREATE POLICY "Public delete pvp_challenge_attempts" ON pvp_challenge_attempts FOR DELETE TO anon USING (true);

-- Pose un nouveau défi (retire automatiquement l'ancien défi actif du même
-- joueur s'il y en a un, voir commentaire de pvp_challenges) : instantané des
-- PV/dégâts au moment de l'appel, jusqu'à pvp_config.loadout_max capacités
-- CONNUES par ce pokémon, non bannies (autobattle_banned_attacks, liste
-- réutilisée telle quelle, partagée avec Combat Auto), dans l'ordre transmis
-- — LES DOUBLONS SONT AUTORISÉS (une même capacité peut occuper plusieurs
-- positions de la boucle), voir PvpAbilityLoadoutPicker.
CREATE OR REPLACE FUNCTION pvp_post_challenge(
  p_player_id bigint,
  p_player_pokemon_id bigint,
  p_ability_noms text[],
  p_idempotency_key uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_existing_id bigint;
  v_config record;
  v_pp record;
  v_species record;
  v_nom text;
  v_max_hp integer;
  v_damage_species_xp integer;
  v_new_id bigint;
BEGIN
  -- Sérialise les dépôts concurrents du même joueur (deux onglets/appareils)
  -- — même idiome que pg_advisory_xact_lock('pension_slots') pour la Pension.
  PERFORM pg_advisory_xact_lock(hashtext('pvp_challenge_' || p_player_id));

  SELECT id INTO v_existing_id FROM pvp_challenges WHERE idempotency_key = p_idempotency_key;
  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object('status', 'ok', 'challenge_id', v_existing_id);
  END IF;

  -- Le Champion (voir pvp_promote_to_champion) ne peut pas poser un second
  -- pokémon en défi tant qu'il détient le titre — un seul défi actif par
  -- joueur (comme avant), mais celui du Champion n'est jamais remplaçable de
  -- cette façon, seulement en étant battu ou dépossédé par un admin.
  IF EXISTS (SELECT 1 FROM pvp_challenges WHERE defender_player_id = p_player_id AND active = true AND is_champion = true) THEN
    RETURN jsonb_build_object('status', 'already_champion');
  END IF;

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

  v_max_hp := GREATEST(1, COALESCE(v_species.pv_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'PV'));
  v_damage_species_xp := COALESCE(v_species.degats_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'DMG');

  UPDATE pvp_challenges SET active = false, withdrawn_at = now()
    WHERE defender_player_id = p_player_id AND active = true;

  INSERT INTO pvp_challenges (
    defender_player_id, source_player_pokemon_id, pokemon_nom, pokemon_numero, nickname, xp,
    max_hp, damage_species_xp, ability_noms,
    idempotency_key
  ) VALUES (
    p_player_id, p_player_pokemon_id, v_pp.pokemon_nom, v_pp.pokemon_numero, v_pp.nickname, v_pp.xp,
    v_max_hp, v_damage_species_xp, p_ability_noms,
    p_idempotency_key
  ) RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('status', 'ok', 'challenge_id', v_new_id);
END;
$$;

GRANT EXECUTE ON FUNCTION pvp_post_challenge(bigint, bigint, text[], uuid) TO anon, authenticated;

-- Retire le défi actif d'un joueur (le joueur lui-même, ou un admin via
-- l'admin PvP — voir AdminPvpPanel, qui appelle cette même fonction avec
-- p_player_id = defender_player_id de la ligne visée, pas forcément le
-- joueur courant). N'affecte JAMAIS pvp_battles/pvp_challenge_attempts :
-- une tentative déjà démarrée peut se terminer normalement (voir
-- pvp_resolve_round, qui ne revérifie plus 'active' une fois le combat lancé).
CREATE OR REPLACE FUNCTION pvp_withdraw_challenge(p_player_id bigint, p_challenge_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_challenge record;
BEGIN
  SELECT * INTO v_challenge FROM pvp_challenges WHERE id = p_challenge_id;
  IF v_challenge IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;
  IF v_challenge.defender_player_id <> p_player_id THEN
    RETURN jsonb_build_object('status', 'not_owner');
  END IF;
  IF NOT v_challenge.active THEN
    RETURN jsonb_build_object('status', 'already_withdrawn');
  END IF;

  UPDATE pvp_challenges SET active = false, withdrawn_at = now() WHERE id = p_challenge_id;
  RETURN jsonb_build_object('status', 'ok');
END;
$$;

GRANT EXECUTE ON FUNCTION pvp_withdraw_challenge(bigint, bigint) TO anon, authenticated;

-- Démarre une tentative (Combat Manuel) contre un défi : tire au sort qui
-- attaque en premier AVANT le choix de capacité (comme autobattle_start_
-- manual_battle), pas de ticket à débiter (mode gratuit). Purge toute
-- tentative précédente du même attaquant sur ce même défi (rejouer un défi
-- déjà tenté redémarre à zéro, jamais de reprise de PV/statuts résiduels).
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
  -- Type d'espèce du DÉFENSEUR (le défi ne stocke que son nom d'espèce) : sert
  -- aux immunités de statut de type des talents « à l'entrée en combat ».
  v_d_type            text;
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
  v_talent_inflict      text;
  v_side                text;
  v_talents_enabled     boolean;
  -- Météo — voir autobattle_start_manual_battle, même mécanique.
  v_weather_enabled     boolean;
  v_weather             jsonb;
  v_weather_res         jsonb;
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
  SELECT type INTO v_d_type FROM pokemon WHERE nom = v_challenge.pokemon_nom;

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
  -- Bascule globale des talents (voir pvp_config.talents_enabled), puis filtre
  -- 'cancel_talents' (voir autobattle_talents_effective).
  SELECT talents_enabled INTO v_talents_enabled FROM pvp_config WHERE id = 1;
  v_talents_enabled := COALESCE(v_talents_enabled, true);
  v_a_talents := autobattle_talents_vs(v_pp.pokemon_nom, v_challenge.pokemon_nom, v_talents_enabled);
  v_d_talents := autobattle_talents_vs(v_challenge.pokemon_nom, v_pp.pokemon_nom, v_talents_enabled);
  -- Bascule globale de la météo (voir pvp_config.weather_enabled).
  SELECT weather_enabled INTO v_weather_enabled FROM pvp_config WHERE id = 1;
  v_weather_enabled := COALESCE(v_weather_enabled, true);
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

  -- Garde 'auto_cure_first_status' sur la cible, comme en cours de combat
  -- (voir autobattle_resolve_battle) : autobattle_talent_act ne gère que
  -- l'immunité.
  FOREACH v_side IN ARRAY (CASE WHEN v_first_attacker = 'attacker' THEN ARRAY['player', 'opponent'] ELSE ARRAY['opponent', 'player'] END) LOOP
    IF v_side = 'player' THEN
      v_talent_res := autobattle_talent_act(v_a_talents, v_a_talent_state, 'player', 'battle_start', NULL,
        v_attacker_max_hp, v_attacker_max_hp, v_d_status, v_a_status, v_d_talents, 0, v_weather, v_d_type);
      v_a_talent_state := v_talent_res -> 'state';
      v_start_turns := v_start_turns || (v_talent_res -> 'turns');
      -- Météo « à l'entrée en combat » : persistée sur la ligne de combat.
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'player', v_attacker_max_hp, 0);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_start_turns := v_start_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(v_d_talents, v_d_talent_state, 'opponent', v_talent_inflict, v_challenge.max_hp, 0, v_d_type);
        v_d_talent_state := v_talent_res -> 'state';
        v_start_turns := v_start_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_d_status := v_talent_inflict;
        END IF;
      END IF;
    ELSE
      v_talent_res := autobattle_talent_act(v_d_talents, v_d_talent_state, 'opponent', 'battle_start', NULL,
        v_challenge.max_hp, v_challenge.max_hp, v_a_status, v_d_status, v_a_talents, 0, v_weather, v_species.type);
      v_d_talent_state := v_talent_res -> 'state';
      v_start_turns := v_start_turns || (v_talent_res -> 'turns');
      -- Voir le même commentaire côté attaquant.
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, v_weather_enabled, v_weather, 'opponent', v_challenge.max_hp, 0);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_start_turns := v_start_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(v_a_talents, v_a_talent_state, 'player', v_talent_inflict, v_attacker_max_hp, 0, v_species.type);
        v_a_talent_state := v_talent_res -> 'state';
        v_start_turns := v_start_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_a_status := v_talent_inflict;
        END IF;
      END IF;
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
    turn_log, attacker_talent_state, defender_talent_state, attacker_status, defender_status,
    weather_id
  ) VALUES (
    p_challenge_id, p_attacker_player_id, p_attacker_player_pokemon_id, v_first_attacker,
    v_attacker_max_hp, v_attacker_max_hp, v_challenge.max_hp, v_challenge.max_hp,
    now(), p_idempotency_key, v_result,
    v_start_turns, v_a_talent_state, v_d_talent_state, v_a_status, v_d_status,
    autobattle_weather_id(v_weather)
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION pvp_start_battle(bigint, bigint, bigint, uuid) TO anon, authenticated;

-- Résout UN SEUL "tour" (les deux camps, rafales/passes/préparations
-- comprises — comme autobattle_resolve_manual_round, voir son commentaire
-- pour le détail de chaque effet, repris ici à l'identique) contre un défi
-- PvP. v_attacker_*/v_defender_* ci-dessous (variables internes) désignent
-- respectivement le joueur qui attaque et l'instantané figé du défi — mais
-- le JSON renvoyé (turns[].attacker, player_hp/opponent_hp...) réutilise
-- volontairement le vocabulaire 'player'/'opponent' d'AutoBattleTurn/
-- AutoBattleManualRoundResult ('player' = l'attaquant, 'opponent' = le
-- défenseur figé) pour que AutoBattleScreen/ManualBattleScreen soient
-- réutilisés côté client SANS AUCUNE modification (voir PvpBattleScreen).
-- Aucun ticket, aucune récompense, aucune notion de Métamorph (limitation
-- volontaire) ; à la victoire/défaite, insère la ligne pvp_challenge_attempts
-- (tableau des scores de la bannière) au lieu de créditer XP/objets.
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

-- ============================================================
-- Titre de Champion PvP — une bannière spéciale mise en avant en haut du
-- popup (voir PvpPopup), premium visuellement (bordure dorée, chrono "Depuis
-- ...", voir PvpChampionBanner), au-dessus des défis "Challengers" normaux.
-- Au plus UN défi actif porte is_champion = true à la fois (voir colonne
-- pvp_challenges.is_champion). Une promotion CRÉE une nouvelle ligne pour le
-- nouveau Champion (repart avec un tableau des scores vierge, created_at =
-- "Champion depuis") mais ne fait que RE-BASCULER is_champion à false sur
-- l'ancien (reste active, redevient un Challenger normal — voir requirement
-- dédié : être détrôné renvoie dans "Challengers", ça ne retire pas le défi).
--
-- Devenir Champion : soit en battant le Champion actuel (voir la fin de
-- pvp_resolve_round juste au-dessus, qui appelle pvp_promote_to_champion),
-- soit nommé directement par un admin (voir AdminPvpPanel — utile pour
-- désigner le tout premier Champion, la fonction ne fait aucune distinction
-- entre les deux cas d'appel).
CREATE OR REPLACE FUNCTION pvp_promote_to_champion(p_source_challenge_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_source  record;
  v_new_id  bigint;
BEGIN
  -- Sérialise les promotions concurrentes (idem pg_advisory_xact_lock
  -- ('pension_slots') pour la Pension) : pas de contrainte DB dédiée, ce
  -- verrou est la seule garantie qu'au plus un Champion actif existe.
  PERFORM pg_advisory_xact_lock(hashtext('pvp_champion'));

  SELECT * INTO v_source FROM pvp_challenges WHERE id = p_source_challenge_id AND active = true FOR UPDATE;
  IF v_source IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;
  IF v_source.is_champion THEN
    RETURN jsonb_build_object('status', 'already_champion');
  END IF;

  -- Dépossède l'ancien Champion SANS le retirer (redevient un Challenger
  -- normal, voir requirement) puis retire le défi source (celui qui vient
  -- d'être promu) : son propriétaire ne peut pas être à la fois Champion et
  -- Challenger (voir pvp_post_challenge, qui lui bloque déjà tout nouveau
  -- dépôt tant qu'il est Champion).
  UPDATE pvp_challenges SET is_champion = false
    WHERE is_champion = true AND active = true;
  UPDATE pvp_challenges SET active = false, withdrawn_at = now()
    WHERE id = p_source_challenge_id;

  INSERT INTO pvp_challenges (
    defender_player_id, source_player_pokemon_id, pokemon_nom, pokemon_numero, nickname, xp,
    max_hp, damage_species_xp, ability_noms, is_champion, idempotency_key
  ) VALUES (
    v_source.defender_player_id, v_source.source_player_pokemon_id, v_source.pokemon_nom, v_source.pokemon_numero, v_source.nickname, v_source.xp,
    v_source.max_hp, v_source.damage_species_xp, v_source.ability_noms, true,
    -- UUID aléatoire sans dépendre de pgcrypto/gen_random_uuid (pas garanti
    -- disponible selon la version Postgres) — même trick que côté idempotency
    -- key ailleurs dans ce fichier n'étant pas nécessaire ici (jamais rejoué).
    (md5(random()::text || clock_timestamp()::text))::uuid
  ) RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('status', 'ok', 'challenge_id', v_new_id);
END;
$$;

GRANT EXECUTE ON FUNCTION pvp_promote_to_champion(bigint) TO anon, authenticated;

-- Dépossède le Champion actuel sans successeur (voir AdminPvpPanel) — comme
-- pvp_promote_to_champion, ne retire pas son défi : redevient un Challenger
-- normal (visible dans "Challengers"), la section "Champion Actuel" reste
-- vide côté client jusqu'à la prochaine promotion.
CREATE OR REPLACE FUNCTION pvp_admin_clear_champion()
RETURNS jsonb
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('pvp_champion'));
  UPDATE pvp_challenges SET is_champion = false WHERE is_champion = true AND active = true;
  RETURN jsonb_build_object('status', 'ok');
END;
$$;

GRANT EXECUTE ON FUNCTION pvp_admin_clear_champion() TO anon, authenticated;
-- ============================================================
-- Mode "Tester" (bouton à côté de "Confirmer le défi", voir
-- PvpAbilityLoadoutPicker/PvpTrialBattleScreen) : combat d'ESSAI gratuit,
-- 100% automatique des DEUX côtés, contre un adversaire factice configuré en
-- admin (pvp_config.trial_pokemon_nom/trial_hp/trial_ability_nom) — sert
-- uniquement à regarder sa boucle de capacités EN COURS DE CONSTRUCTION (pas
-- encore postée comme défi réel) s'exécuter contre un "punching-ball", pour
-- ajuster l'ordre avant de confirmer. Aucun ticket, aucune récompense, aucun
-- historique, aucun tableau de scores — purement éphémère, quittable à tout
-- moment (voir onBack côté client, aucun nettoyage serveur requis : la ligne
-- est simplement écrasée par la tentative suivante, voir pvp_trial_start).
-- Délègue au même moteur partagé autobattle_resolve_round_core que
-- pvp_resolve_round/autobattle_resolve_manual_round, mais ici les DEUX
-- camps tournent en boucle automatique (attacker_ability_noms ET
-- dummy_ability_nom, ce dernier boucle trivialement sur lui-même vu qu'il
-- n'y a qu'une seule capacité) — contrairement à pvp_resolve_round où seul
-- le défenseur boucle, l'attaquant étant normalement choisi interactivement.
-- ============================================================

CREATE TABLE IF NOT EXISTS pvp_trial_battles (
  id                               bigserial PRIMARY KEY,
  player_id                        bigint NOT NULL,
  player_pokemon_id                bigint NOT NULL,
  -- Boucle en cours de configuration au moment du clic "Tester" (pas encore
  -- postée comme défi réel, voir pvp_challenges.ability_noms pour l'équivalent
  -- posté) — snapshotée ici pour la durée du combat d'essai uniquement.
  attacker_ability_noms            text[] NOT NULL,
  attacker_ability_cycle_index     integer NOT NULL DEFAULT 0,
  -- Instantané de la config admin au moment du clic "Tester" (voir
  -- pvp_config.trial_*) — un admin qui change la config en cours d'essai ne
  -- doit pas modifier un combat déjà lancé.
  dummy_pokemon_nom                text NOT NULL,
  dummy_max_hp                     integer NOT NULL,
  dummy_ability_nom                text NOT NULL,
  first_attacker                   text NOT NULL CHECK (first_attacker IN ('attacker', 'defender')),
  turn_no                          integer NOT NULL DEFAULT 0,
  round_no                         integer NOT NULL DEFAULT 0,
  attacker_hp                      integer NOT NULL,
  attacker_max_hp                  integer NOT NULL,
  defender_hp                      integer NOT NULL,
  defender_max_hp                  integer NOT NULL,
  attacker_status                  text,
  defender_status                  text,
  attacker_damage_mod_amount       integer NOT NULL DEFAULT 0,
  attacker_damage_mod_expires      integer,
  attacker_precision_mod_amount    integer NOT NULL DEFAULT 0,
  attacker_precision_mod_expires   integer,
  defender_damage_mod_amount       integer NOT NULL DEFAULT 0,
  defender_damage_mod_expires      integer,
  defender_precision_mod_amount    integer NOT NULL DEFAULT 0,
  defender_precision_mod_expires   integer,
  attacker_heal_dot_amount         integer,
  attacker_heal_dot_expires        integer,
  defender_heal_dot_amount         integer,
  defender_heal_dot_expires        integer,
  attacker_heal_disabled_expires   integer,
  defender_heal_disabled_expires   integer,
  attacker_invulnerable            boolean NOT NULL DEFAULT false,
  attacker_invuln_granted_round    integer,
  defender_invulnerable            boolean NOT NULL DEFAULT false,
  defender_invuln_granted_round    integer,
  attacker_stat_mod_uses           jsonb NOT NULL DEFAULT '{}'::jsonb,
  defender_stat_mod_uses           jsonb NOT NULL DEFAULT '{}'::jsonb,
  attacker_used_ability             boolean NOT NULL DEFAULT false,
  attacker_took_damage              boolean NOT NULL DEFAULT false,
  defender_used_ability             boolean NOT NULL DEFAULT false,
  defender_took_damage              boolean NOT NULL DEFAULT false,
  attacker_skip_pending             boolean NOT NULL DEFAULT false,
  defender_skip_pending             boolean NOT NULL DEFAULT false,
  attacker_preparing                boolean NOT NULL DEFAULT false,
  defender_preparing                boolean NOT NULL DEFAULT false,
  attacker_preparing_ability_nom    text,
  defender_preparing_ability_nom    text,
  turn_log                          jsonb NOT NULL DEFAULT '[]'::jsonb,
  outcome                           text CHECK (outcome IS NULL OR outcome IN ('win', 'lose')),
  started_at                        timestamptz NOT NULL DEFAULT now(),
  last_idempotency_key              uuid,
  last_result                       jsonb,
  created_at                        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (player_id)
);

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

-- Effets persistants offensifs subis / perce-immunité accordé (voir les mêmes
-- colonnes sur autobattle_manual_battles).
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_damage_dot_amount integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_damage_dot_expires integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_damage_dot_amount integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_damage_dot_expires integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_leech_dot_amount integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_leech_dot_expires integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_leech_dot_amount integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_leech_dot_expires integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_pierce_immunity_type text;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_pierce_immunity_expires integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_pierce_immunity_type text;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_pierce_immunity_expires integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_status_dot_status text;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_status_dot_chance integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_status_dot_expires integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_status_dot_status text;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_status_dot_chance integer;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_status_dot_expires integer;

-- Piles de modificateurs de stat (voir autobattle_mod_total) : remplacent les
-- colonnes *_damage_mod_amount/_expires/_type_filter et *_precision_mod_amount/
-- _expires, qui ne portaient qu'UN modificateur écrasable par camp et par stat.
-- Les anciennes colonnes sont laissées en place (inutilisées) plutôt que
-- supprimées, pour ne pas casser un combat déjà en cours au moment de la
-- migration.
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_damage_mods jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_damage_mods jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_precision_mods jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_precision_mods jsonb NOT NULL DEFAULT '[]'::jsonb;

-- Talents d'espèce déjà déclenchés (voir autobattle_talents / talent_state).
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS attacker_talent_state jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS defender_talent_state jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Météo en cours — voir autobattle_manual_battles.weather_id.
ALTER TABLE pvp_trial_battles ADD COLUMN IF NOT EXISTS weather_id bigint;

-- Le DEFAULT est passé d'un tableau à un OBJET en cours de développement :
-- ADD COLUMN IF NOT EXISTS ne le corrige pas sur une base déjà migrée.
ALTER TABLE autobattle_manual_battles ALTER COLUMN player_talent_state SET DEFAULT '{}'::jsonb;
ALTER TABLE autobattle_manual_battles ALTER COLUMN opponent_talent_state SET DEFAULT '{}'::jsonb;
ALTER TABLE pvp_battles ALTER COLUMN attacker_talent_state SET DEFAULT '{}'::jsonb;
ALTER TABLE pvp_battles ALTER COLUMN defender_talent_state SET DEFAULT '{}'::jsonb;
ALTER TABLE pvp_trial_battles ALTER COLUMN attacker_talent_state SET DEFAULT '{}'::jsonb;
ALTER TABLE pvp_trial_battles ALTER COLUMN defender_talent_state SET DEFAULT '{}'::jsonb;
ALTER TABLE pvp_trial_battles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read pvp_trial_battles" ON pvp_trial_battles;
CREATE POLICY "Public read pvp_trial_battles" ON pvp_trial_battles FOR SELECT TO anon USING (true);
DROP POLICY IF EXISTS "Public insert pvp_trial_battles" ON pvp_trial_battles;
CREATE POLICY "Public insert pvp_trial_battles" ON pvp_trial_battles FOR INSERT TO anon WITH CHECK (true);
DROP POLICY IF EXISTS "Public update pvp_trial_battles" ON pvp_trial_battles;
CREATE POLICY "Public update pvp_trial_battles" ON pvp_trial_battles FOR UPDATE TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Public delete pvp_trial_battles" ON pvp_trial_battles;
CREATE POLICY "Public delete pvp_trial_battles" ON pvp_trial_battles FOR DELETE TO anon USING (true);

-- Démarre (ou redémarre — une tentative précédente est toujours écrasée,
-- voir DELETE ci-dessous) un combat d'essai pour la boucle p_ability_noms
-- (en cours de configuration côté client, pas encore postée) contre le
-- pantin configuré en admin. p_player_starts vient d'un choix EXPLICITE du
-- joueur (pas un tirage au sort aléatoire comme pvp_start_battle/
-- autobattle_start_manual_battle) — cet écran sert justement à observer
-- l'ordre des capacités dans les deux configurations.
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
  v_talent_inflict  text;
  v_side            text;
  -- Météo — voir autobattle_start_manual_battle, même mécanique. La bascule est
  -- lue sur v_config, déjà chargé (comme talents_enabled juste en dessous).
  v_weather         jsonb;
  v_weather_res     jsonb;
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
  -- déjà chargé ici, pas besoin d'un SELECT dédié. _vs : filtre 'cancel_talents'
  -- (voir autobattle_talents_effective).
  v_a_talents := autobattle_talents_vs(v_pp.pokemon_nom, v_config.trial_pokemon_nom, COALESCE(v_config.talents_enabled, true));
  v_d_talents := autobattle_talents_vs(v_config.trial_pokemon_nom, v_pp.pokemon_nom, COALESCE(v_config.talents_enabled, true));

  v_talent_start := autobattle_talent_open(v_a_talents, 'player', v_attacker_max_hp);
  v_start_turns := v_start_turns || (v_talent_start -> 'turns');
  v_a_talent_state := v_talent_start -> 'state';
  v_talent_start := autobattle_talent_open(v_d_talents, 'opponent', v_dummy_hp);
  v_start_turns := v_start_turns || (v_talent_start -> 'turns');
  v_d_talent_state := v_talent_start -> 'state';

  -- Garde 'auto_cure_first_status' sur la cible, comme en cours de combat
  -- (voir autobattle_resolve_battle) : autobattle_talent_act ne gère que
  -- l'immunité.
  FOREACH v_side IN ARRAY (CASE WHEN v_first_attacker = 'attacker' THEN ARRAY['player', 'opponent'] ELSE ARRAY['opponent', 'player'] END) LOOP
    IF v_side = 'player' THEN
      v_talent_res := autobattle_talent_act(v_a_talents, v_a_talent_state, 'player', 'battle_start', NULL,
        v_attacker_max_hp, v_attacker_max_hp, v_d_status, v_a_status, v_d_talents, 0, v_weather, v_dummy_species.type);
      v_a_talent_state := v_talent_res -> 'state';
      v_start_turns := v_start_turns || (v_talent_res -> 'turns');
      -- Météo « à l'entrée en combat » : persistée sur la ligne d'essai.
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, COALESCE(v_config.weather_enabled, true), v_weather, 'player', v_attacker_max_hp, 0);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_start_turns := v_start_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(v_d_talents, v_d_talent_state, 'opponent', v_talent_inflict, v_dummy_hp, 0, v_dummy_species.type);
        v_d_talent_state := v_talent_res -> 'state';
        v_start_turns := v_start_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_d_status := v_talent_inflict;
        END IF;
      END IF;
    ELSE
      v_talent_res := autobattle_talent_act(v_d_talents, v_d_talent_state, 'opponent', 'battle_start', NULL,
        v_dummy_hp, v_dummy_hp, v_a_status, v_d_status, v_a_talents, 0, v_weather, v_species.type);
      v_d_talent_state := v_talent_res -> 'state';
      v_start_turns := v_start_turns || (v_talent_res -> 'turns');
      -- Voir le même commentaire côté attaquant.
      v_weather_res := autobattle_weather_set((v_talent_res ->> 'set_weather')::bigint, COALESCE(v_config.weather_enabled, true), v_weather, 'opponent', v_dummy_hp, 0);
      v_weather := autobattle_weather_norm(v_weather_res -> 'weather');
      v_start_turns := v_start_turns || (v_weather_res -> 'turns');
      v_talent_inflict := v_talent_res ->> 'inflict_status';
      IF v_talent_inflict IS NOT NULL THEN
        v_talent_res := autobattle_talent_status_guard(v_a_talents, v_a_talent_state, 'player', v_talent_inflict, v_attacker_max_hp, 0, v_species.type);
        v_a_talent_state := v_talent_res -> 'state';
        v_start_turns := v_start_turns || (v_talent_res -> 'turns');
        IF NOT (v_talent_res ->> 'blocked')::boolean THEN
          v_a_status := v_talent_inflict;
        END IF;
      END IF;
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
    turn_log, attacker_talent_state, defender_talent_state, attacker_status, defender_status,
    weather_id
  ) VALUES (
    p_player_id, p_player_pokemon_id, p_ability_noms,
    v_config.trial_pokemon_nom, v_dummy_hp, v_config.trial_ability_nom,
    v_first_attacker, v_attacker_max_hp, v_attacker_max_hp, v_dummy_hp, v_dummy_hp,
    now(), p_idempotency_key, v_result,
    v_start_turns, v_a_talent_state, v_d_talent_state, v_a_status, v_d_status,
    autobattle_weather_id(v_weather)
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION pvp_trial_start(bigint, bigint, text[], boolean, uuid) TO anon, authenticated;

-- Résout UN SEUL round d'un combat d'essai (voir pvp_trial_start) : contrairement
-- à pvp_resolve_round, AUCUNE capacité n'est choisie interactivement — les
-- deux camps cyclent automatiquement (l'attaquant à travers sa boucle en
-- cours de test, le pantin à travers sa capacité unique) — voir
-- PvpTrialBattleScreen, qui rappelle cette fonction en boucle jusqu'à l'issue
-- sans jamais attendre d'action du joueur.
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

-- history_events.category doit accepter la nouvelle catégorie 'pvp'
ALTER TABLE history_events DROP CONSTRAINT IF EXISTS history_events_category_check;
ALTER TABLE history_events ADD CONSTRAINT history_events_category_check
  CHECK (category IN ('inventory', 'pokedex', 'team', 'combat', 'minigame', 'daycare', 'safari', 'autobattle', 'chat', 'pvp'));

-- Diffusion Realtime — mêmes raisons que les blocs Fouille/Pension/Safari/
-- Combat Auto ci-dessus. pvp_battles n'est PAS inclus (état vivant purement
-- consulté via les réponses RPC, jamais souscrit — même choix que
-- autobattle_manual_battles).
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['pvp_config', 'pvp_challenges', 'pvp_challenge_attempts']
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', t);
    END IF;
  END LOOP;
END $$;

-- ============================================================================
-- Chat — indicateur "Vu par" (accusés de lecture)
-- ============================================================================
-- Une ligne par joueur (PK player_id) : l'id du dernier message qu'il a vu.
-- Côté client, les avatars "Vu par" s'affichent sous ce message précis. Les
-- PNJ ne sont jamais enregistrés ici (ils n'ont pas de session qui lit le
-- chat) — le filtrage se fait à l'affichage. player_id et last_read_message_id
-- référencent players.id / chat_messages.id sans FK, comme le reste du schéma.

CREATE TABLE IF NOT EXISTS chat_read_receipts (
  player_id            bigint PRIMARY KEY,
  last_read_message_id bigint NOT NULL,
  updated_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chat_read_receipts ENABLE ROW LEVEL SECURITY;

-- Lecture/écriture publiques (app sans vraie sécurité, comme le reste du schéma).
DROP POLICY IF EXISTS "Public read chat_read_receipts" ON chat_read_receipts;
CREATE POLICY "Public read chat_read_receipts" ON chat_read_receipts FOR SELECT TO anon USING (true);
DROP POLICY IF EXISTS "Public insert chat_read_receipts" ON chat_read_receipts;
CREATE POLICY "Public insert chat_read_receipts" ON chat_read_receipts FOR INSERT TO anon WITH CHECK (true);
DROP POLICY IF EXISTS "Public update chat_read_receipts" ON chat_read_receipts;
CREATE POLICY "Public update chat_read_receipts" ON chat_read_receipts FOR UPDATE TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Public delete chat_read_receipts" ON chat_read_receipts;
CREATE POLICY "Public delete chat_read_receipts" ON chat_read_receipts FOR DELETE TO anon USING (true);

-- Diffusion Realtime : les avatars "Vu par" doivent apparaître chez les autres
-- joueurs sans rechargement, comme les messages eux-mêmes (chat_messages).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_read_receipts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE chat_read_receipts;
  END IF;
END $$;
