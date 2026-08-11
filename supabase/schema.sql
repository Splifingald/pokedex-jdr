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

-- Table des attaques (référencées par nom depuis pokemon.attaque_1..10, pas de FK)
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
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO autobattle_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
-- Si autobattle_config existe déjà (migration précédente déjà appliquée) :
ALTER TABLE autobattle_config ADD COLUMN IF NOT EXISTS precision_enabled boolean NOT NULL DEFAULT true;

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
  player_invuln_granted_turn     integer,
  opponent_invulnerable          boolean NOT NULL DEFAULT false,
  opponent_invuln_granted_turn   integer,
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
  turn_effect       text CHECK (turn_effect IS NULL OR turn_effect IN ('skip', 'play_twice', 'play_three', 'play_random', 'repeat_until_fail')),
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
-- Si autobattle_ability_rules existe déjà (migration précédente déjà appliquée) :
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS repeat_max_iterations integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_turn_effect_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_turn_effect_check
  CHECK (turn_effect IS NULL OR turn_effect IN ('skip', 'play_twice', 'play_three', 'play_random', 'repeat_until_fail', 'prepare_release'));
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
  CHECK (bonus_damage_condition IS NULL OR bonus_damage_condition IN ('took_damage_last_turn', 'first_use', 'dice_equals', 'has_status'));
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

-- Filtre de statut pour la condition 'has_status' ci-dessus : NULL = "n'
-- importe quel statut" (comportement historique, inchangé), sinon un statut
-- PRÉCIS parmi les 7 existants — la condition n'est alors vérifiée que si le
-- camp est affecté par CE statut-là spécifiquement, pas un autre. Sans effet
-- (et ignoré côté RPC) si bonus_damage_condition <> 'has_status'.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS bonus_damage_status_filter text;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_bonus_damage_status_filter_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_bonus_damage_status_filter_check
  CHECK (bonus_damage_status_filter IS NULL OR bonus_damage_status_filter IN ('paralysis', 'fear', 'confusion', 'sleep', 'burn', 'poison', 'frozen'));

-- Modificateur de stat (dégâts de base ou précision), appliqué sur un coup
-- réussi soit à l'adversaire du lanceur (stat_mod_target = 'opponent', un
-- débuff), soit au lanceur lui-même (stat_mod_target = 'self', un buff) — le
-- sens hausse/baisse découle directement de la cible, voir
-- autobattle_resolve_battle. 'percent' (stat_mod_percent) n'est valable que
-- pour stat = 'damage', calculé sur les dégâts de base DE COMBAT de la cible
-- tels que calculés en tout début de combat (avant tout modificateur), fixes
-- pour tout le combat. Dure stat_mod_duration_turns tours de combat (compteur
-- global de tours, pas propre à un camp) ou jusqu'à la fin du combat
-- (stat_mod_duration_type = 'battle_end'). stat_mod_max_uses plafonne le
-- nombre d'applications RÉUSSIES sur tout le combat (un raté ne compte pas) ;
-- NULL = illimité. Un seul modificateur actif à la fois par (camp, stat) :
-- une réapplication écrase la précédente (même montant + durée rejoués),
-- pas de cumul — même philosophie que le statut (autobattle_ability_rules
-- ne stocke pas d'état de combat, juste la config, l'état vit dans le RPC).
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
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_stat_mod_target_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_stat_mod_target_check
  CHECK (stat_mod_target IS NULL OR stat_mod_target IN ('self', 'opponent'));
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
-- réussi, inflige heal_dot_amount PV de soin à chaque début de son propre
-- tour pendant heal_dot_duration_turns tours de combat (compteur global,
-- comme stat_mod_duration_turns) — une réapplication rejoue montant+durée
-- (pas de cumul). Indépendant du soin instantané (heal_type/heal_amount/
-- heal_percent) : les deux peuvent coexister sur la même capacité. Bloqué
-- par un Anti-Soin adverse actif (cancel_heal_duration_turns ci-dessous),
-- voir autobattle_resolve_battle.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS heal_dot_amount integer;
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS heal_dot_duration_turns integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_heal_dot_fields;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_heal_dot_fields
  CHECK (
    (heal_dot_amount IS NULL AND heal_dot_duration_turns IS NULL)
    OR (heal_dot_amount IS NOT NULL AND heal_dot_amount > 0 AND heal_dot_duration_turns IS NOT NULL AND heal_dot_duration_turns >= 1)
  );

-- Anti-Soin : sur un coup réussi, annule TOUS les effets de soin de
-- l'adversaire (soin instantané, soin passif, guérison du poison par un
-- soin) pendant cancel_heal_duration_turns tours de combat (compteur global).
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS cancel_heal_duration_turns integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_cancel_heal_duration_turns_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_cancel_heal_duration_turns_check
  CHECK (cancel_heal_duration_turns IS NULL OR cancel_heal_duration_turns >= 1);

-- Dégâts en % des PV restants : sur un coup réussi, remplace ENTIÈREMENT le
-- calcul de dégâts habituel (dégâts de base + dé + modificateur de stat) par
-- floor(PV ACTUELS de la cible AVANT ce coup × percent_hp_damage_percent /
-- 100) — comme "Ultimapoing"/Super Fang côté jeux officiels. Les dégâts
-- additionnels conditionnels (bonus_damage_*), le contre-coup, le soin, etc.
-- s'appliquent ensuite normalement, sur CE total. 50 par défaut côté admin
-- (AdminAutoBattleAbilityRulesPanel), pas de défaut SQL forcé.
ALTER TABLE autobattle_ability_rules ADD COLUMN IF NOT EXISTS percent_hp_damage_percent integer;
ALTER TABLE autobattle_ability_rules DROP CONSTRAINT IF EXISTS autobattle_ability_rules_percent_hp_damage_percent_check;
ALTER TABLE autobattle_ability_rules ADD CONSTRAINT autobattle_ability_rules_percent_hp_damage_percent_check
  CHECK (percent_hp_damage_percent IS NULL OR (percent_hp_damage_percent >= 1 AND percent_hp_damage_percent <= 100));

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
-- combat tour par tour (formule : dégâts pokémon ×2 si son espèce est
-- "super efficace" contre le type de l'adversaire, + dégâts de la capacité,
-- jamais doublés) ; 6) à la victoire, crédite toutes les récompenses du
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
  v_player_invuln_pending_miss   boolean := false;
  v_opponent_invuln_pending_miss boolean := false;
  v_player_invuln_granted_turn   integer;
  v_opponent_invuln_granted_turn integer;
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
  -- Soin passif (heal_dot) et Anti-Soin (cancel_heal) — voir
  -- autobattle_ability_rules. Config chargée une fois (côté source), état
  -- actif suivi séparément (côté affecté), même logique d'expiration par
  -- numéro de tour que les modificateurs de stat ci-dessus.
  v_player_heal_dot_config_amount    integer;
  v_player_heal_dot_config_turns     integer;
  v_opponent_heal_dot_config_amount  integer;
  v_opponent_heal_dot_config_turns   integer;
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
  v_player_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (CASE WHEN v_is_metamorph THEN v_opponent_species.super_efficace_1 ELSE v_player_species.super_efficace_1 END),
      (CASE WHEN v_is_metamorph THEN v_opponent_species.super_efficace_2 ELSE v_player_species.super_efficace_2 END),
      (CASE WHEN v_is_metamorph THEN v_opponent_species.super_efficace_3 ELSE v_player_species.super_efficace_3 END),
      (CASE WHEN v_is_metamorph THEN v_opponent_species.super_efficace_4 ELSE v_player_species.super_efficace_4 END)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(CASE WHEN v_is_opponent_metamorph THEN v_player_species.type ELSE v_opponent_species.type END))
  );
  -- Dégâts de base (avant dé) : bonus de type inclus, jamais redoublé par le
  -- dé. Le dé (attacks.degats_de) est retiré au sort à CHAQUE coup dans la
  -- boucle ci-dessous (1..degats_de inclus), pas une seule fois pour tout le
  -- combat — c'est ce qui lui donne son côté aléatoire "à chaque attaque".
  -- Métamorph part du dégât de BASE de l'adversaire (celui configuré pour ce
  -- niveau) plutôt que du sien, mais garde son propre bonus XP (l'XP reste
  -- une progression personnelle, pas quelque chose "copié").
  v_player_damage := (COALESCE(v_player_base_damage_component, 0)
    + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'DMG'))
    * (CASE WHEN v_player_type_bonus THEN 2 ELSE 1 END) + COALESCE(v_ability.degats_base, 0);

  v_opponent_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (CASE WHEN v_is_opponent_metamorph THEN v_player_species.super_efficace_1 ELSE v_opponent_species.super_efficace_1 END),
      (CASE WHEN v_is_opponent_metamorph THEN v_player_species.super_efficace_2 ELSE v_opponent_species.super_efficace_2 END),
      (CASE WHEN v_is_opponent_metamorph THEN v_player_species.super_efficace_3 ELSE v_opponent_species.super_efficace_3 END),
      (CASE WHEN v_is_opponent_metamorph THEN v_player_species.super_efficace_4 ELSE v_opponent_species.super_efficace_4 END)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(CASE WHEN v_is_metamorph THEN v_opponent_species.type ELSE v_player_species.type END))
  );
  v_opponent_damage := COALESCE(v_opponent_base_damage_component, 0) * (CASE WHEN v_opponent_type_bonus THEN 2 ELSE 1 END)
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
         heal_dot_amount, heal_dot_duration_turns, cancel_heal_duration_turns, percent_hp_damage_percent
    INTO v_player_heal_type, v_player_heal_amount, v_player_heal_percent, v_player_turn_effect, v_player_repeat_max, v_player_status_reversed,
         v_player_recoil_type, v_player_recoil_min, v_player_recoil_max, v_player_recoil_percent, v_player_invuln_grant,
         v_player_bonus_type, v_player_bonus_multiplier, v_player_bonus_flat, v_player_bonus_min, v_player_bonus_max,
         v_player_bonus_condition, v_player_bonus_dice_value, v_player_bonus_status_filter,
         v_player_stat_mod_target, v_player_stat_mod_stat, v_player_stat_mod_value_type, v_player_stat_mod_flat, v_player_stat_mod_min, v_player_stat_mod_max, v_player_stat_mod_percent,
         v_player_stat_mod_duration_type, v_player_stat_mod_duration_turns, v_player_stat_mod_max_uses,
         v_player_heal_dot_config_amount, v_player_heal_dot_config_turns, v_player_cancel_heal_duration, v_player_percent_hp_damage_percent
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_ability_nom;
  v_player_status_reversed := COALESCE(v_player_status_reversed, false);
  v_player_invuln_grant := COALESCE(v_player_invuln_grant, false);

  SELECT heal_type, heal_amount, heal_percent, turn_effect, repeat_max_iterations, status_reversed,
         recoil_type, recoil_min, recoil_max, recoil_percent, invulnerable_next_turn,
         bonus_damage_type, bonus_damage_multiplier, bonus_damage_flat, bonus_damage_min, bonus_damage_max,
         bonus_damage_condition, bonus_damage_condition_dice_value, bonus_damage_status_filter,
         stat_mod_target, stat_mod_stat, stat_mod_value_type, stat_mod_flat, stat_mod_min, stat_mod_max, stat_mod_percent,
         stat_mod_duration_type, stat_mod_duration_turns, stat_mod_max_uses,
         heal_dot_amount, heal_dot_duration_turns, cancel_heal_duration_turns, percent_hp_damage_percent
    INTO v_opponent_heal_type, v_opponent_heal_amount, v_opponent_heal_percent, v_opponent_turn_effect, v_opponent_repeat_max, v_opponent_status_reversed,
         v_opponent_recoil_type, v_opponent_recoil_min, v_opponent_recoil_max, v_opponent_recoil_percent, v_opponent_invuln_grant,
         v_opponent_bonus_type, v_opponent_bonus_multiplier, v_opponent_bonus_flat, v_opponent_bonus_min, v_opponent_bonus_max,
         v_opponent_bonus_condition, v_opponent_bonus_dice_value, v_opponent_bonus_status_filter,
         v_opponent_stat_mod_target, v_opponent_stat_mod_stat, v_opponent_stat_mod_value_type, v_opponent_stat_mod_flat, v_opponent_stat_mod_min, v_opponent_stat_mod_max, v_opponent_stat_mod_percent,
         v_opponent_stat_mod_duration_type, v_opponent_stat_mod_duration_turns, v_opponent_stat_mod_max_uses,
         v_opponent_heal_dot_config_amount, v_opponent_heal_dot_config_turns, v_opponent_cancel_heal_duration, v_opponent_percent_hp_damage_percent
    FROM autobattle_ability_rules WHERE attack_nom = v_effective_opponent_ability_nom;
  v_opponent_status_reversed := COALESCE(v_opponent_status_reversed, false);
  v_opponent_invuln_grant := COALESCE(v_opponent_invuln_grant, false);

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

    -- Le bouclier d'invulnérabilité dure EXACTEMENT 1 tour, point : il est
    -- retiré dès que v_turn_no dépasse le tour où il a été accordé, que ce
    -- tour suivant soit une vraie attaque adverse ou non (préparation, tour
    -- passé, tick de statut, ou même la suite d'une rafale du même côté) —
    -- placé ici, HORS du bloc "IF v_block_remaining IS NULL", pour qu'il
    -- s'exécute à CHAQUE itération de boucle sans exception (une rafale
    -- play_twice/play_three/repeat_until_fail laisse v_block_remaining non
    -- NULL sur les tours suivants, ce qui sautait cette expiration avant).
    -- v_*_invuln_pending_miss retient jusqu'à la résolution d'attaque plus
    -- bas si CE tour précis doit rater automatiquement (uniquement si son
    -- attaquant est bien le camp adverse à celui protégé).
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

    -- Expiration des modificateurs de stat / soin passif / Anti-Soin, tous
    -- suivis par numéro de tour absolu (voir DECLARE ci-dessus) — comme le
    -- bouclier d'invulnérabilité juste au-dessus, vérifié à CHAQUE itération
    -- sans exception, y compris pendant une rafale (v_block_remaining non
    -- NULL) d'un autre côté.
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

    IF v_block_remaining IS NULL THEN
      v_status_precision_penalty := 0;

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
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', true,
          'status_tick', true, 'status', v_player_status, 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        v_player_status := NULL;
        v_attacker := 'opponent';
        IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
        CONTINUE;
      ELSIF v_attacker = 'opponent' AND v_opponent_status IN ('paralysis', 'frozen') THEN
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', true,
          'status_tick', true, 'status', v_opponent_status, 'status_cured', true,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        v_opponent_status := NULL;
        v_attacker := 'player';
        IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
        CONTINUE;

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
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', NOT v_status_cured,
          'status_tick', true, 'status', 'sleep', 'status_roll', v_status_roll, 'status_cured', v_status_cured,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_status_cured THEN
          v_player_status := NULL;
          v_turn_no := v_turn_no + 1;
        ELSE
          v_attacker := 'opponent';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
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
          v_turn_no := v_turn_no + 1;
        ELSE
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
         AND (v_player_heal_disabled_expires IS NULL OR v_turn_no > v_player_heal_disabled_expires) THEN
        v_player_hp := LEAST(v_player_max_hp, v_player_hp + v_player_heal_dot_amount);
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'skipped', false,
          'heal_dot_tick', true, 'heal', v_player_heal_dot_amount,
          'attacker_hp_after', v_player_hp, 'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_player_status = 'poison' THEN v_player_status := NULL; END IF;
        v_turn_no := v_turn_no + 1;
      ELSIF v_attacker = 'opponent' AND v_opponent_heal_dot_amount IS NOT NULL
         AND (v_opponent_heal_disabled_expires IS NULL OR v_turn_no > v_opponent_heal_disabled_expires) THEN
        v_opponent_hp := LEAST(v_level.opponent_hp, v_opponent_hp + v_opponent_heal_dot_amount);
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'skipped', false,
          'heal_dot_tick', true, 'heal', v_opponent_heal_dot_amount,
          'attacker_hp_after', v_opponent_hp, 'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_opponent_status = 'poison' THEN v_opponent_status := NULL; END IF;
        v_turn_no := v_turn_no + 1;
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
            v_player_invuln_granted_turn := v_turn_no;
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
            v_opponent_invuln_granted_turn := v_turn_no;
            v_turn_entry := v_turn_entry || jsonb_build_object('invulnerable_granted', true);
          END IF;
          v_turns := v_turns || jsonb_build_array(v_turn_entry);
          v_opponent_preparing := true;
          v_attacker := 'player';
          IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
          CONTINUE;
        END IF;
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
      -- Invulnérabilité de l'adversaire (bouclier déjà retiré au début de
      -- CE tour ci-dessus, voir v_opponent_invuln_pending_miss) : rate
      -- automatiquement, ignore précision/statuts entièrement.
      IF v_opponent_invuln_pending_miss THEN
        v_opponent_invuln_pending_miss := false;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true, 'invulnerable_miss', true,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_player_turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
      ELSE
        v_missed := (NOT v_player_never_miss) AND
          random() >= ((CASE WHEN v_precision_enabled THEN GREATEST(0, COALESCE(v_ability.precision, 10) - v_status_precision_penalty + v_player_precision_mod_amount) ELSE 10 END * 10) / 100.0);

        IF v_missed THEN
          v_turns := v_turns || jsonb_build_array(jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true,
            'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
          ));
          -- 'repeat_until_fail' : le premier raté met fin à la série en
          -- cours, même s'il reste des activations dans v_block_remaining —
          -- on force le passage de tour via la décrémentation générique.
          IF v_player_turn_effect = 'repeat_until_fail' THEN
            v_block_remaining := 1;
          END IF;
        ELSE
          v_hit_dice := CASE WHEN v_ability.degats_de IS NOT NULL AND v_ability.degats_de > 0
            THEN 1 + floor(random() * v_ability.degats_de)::integer ELSE 0 END;
          v_hit_damage := GREATEST(0, v_player_damage + v_hit_dice + v_player_damage_mod_amount);

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
            OR v_player_bonus_condition = 'has_status' AND v_player_status IS NOT NULL AND (v_player_bonus_status_filter IS NULL OR v_player_status = v_player_bonus_status_filter);
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
          v_player_used_ability := true;
          v_player_took_damage := false;

          v_opponent_hp := v_opponent_hp - v_hit_damage;
          v_opponent_took_damage := true;

          v_heal_amt := NULL;
          IF v_player_heal_type = 'static' THEN
            v_heal_amt := COALESCE(v_player_heal_amount, 0);
          ELSIF v_player_heal_type = 'percent_damage' THEN
            v_heal_amt := floor(v_hit_damage * COALESCE(v_player_heal_percent, 0) / 100.0)::integer;
          ELSIF v_player_heal_type = 'use_stats' THEN
            v_heal_dice := CASE WHEN v_ability.degats_de IS NOT NULL AND v_ability.degats_de > 0
              THEN 1 + floor(random() * v_ability.degats_de)::integer ELSE 0 END;
            v_heal_amt := COALESCE(v_ability.degats_base, 0) + v_heal_dice;
          END IF;

          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', v_hit_damage,
            'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', v_opponent_hp <= 0
          );
          IF v_percent_hp_damage_applied THEN
            v_turn_entry := v_turn_entry || jsonb_build_object('percent_hp_damage', true);
          END IF;
          IF v_heal_amt IS NOT NULL AND v_heal_amt > 0 AND (v_player_heal_disabled_expires IS NULL OR v_turn_no > v_player_heal_disabled_expires) THEN
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
              v_stat_mod_expiry := CASE WHEN v_player_stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_turn_no + COALESCE(v_player_stat_mod_duration_turns, 1) END;
              IF v_player_stat_mod_target = 'self' AND v_player_stat_mod_stat = 'damage' THEN
                v_player_damage_mod_amount := v_stat_mod_amount; v_player_damage_mod_expires := v_stat_mod_expiry;
              ELSIF v_player_stat_mod_target = 'self' AND v_player_stat_mod_stat = 'precision' THEN
                v_player_precision_mod_amount := v_stat_mod_amount; v_player_precision_mod_expires := v_stat_mod_expiry;
              ELSIF v_player_stat_mod_target = 'opponent' AND v_player_stat_mod_stat = 'damage' THEN
                v_opponent_damage_mod_amount := v_stat_mod_amount; v_opponent_damage_mod_expires := v_stat_mod_expiry;
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
          -- ce coup réussi, indépendant du soin instantané ci-dessus.
          IF v_player_heal_dot_config_amount IS NOT NULL THEN
            v_player_heal_dot_amount := v_player_heal_dot_config_amount;
            v_player_heal_dot_expires := v_turn_no + v_player_heal_dot_config_turns;
            v_turn_entry := v_turn_entry || jsonb_build_object('heal_dot_granted', true);
          END IF;
          -- Anti-Soin : désactive tous les effets de soin adverses (soin
          -- instantané, soin passif, guérison du poison par un soin) pendant
          -- cancel_heal_duration_turns tours de combat.
          IF v_player_cancel_heal_duration IS NOT NULL THEN
            v_opponent_heal_disabled_expires := v_turn_no + v_player_cancel_heal_duration;
            v_turn_entry := v_turn_entry || jsonb_build_object('cancel_heal_applied', true);
          END IF;
          -- Invulnérabilité accordée par cette capacité : consommée au
          -- prochain tour adverse (voir plus haut), indépendamment du reste.
          -- Pour 'prepare_release', déjà accordée à la préparation (protège
          -- le tour adverse qui suit immédiatement, pas celui après la
          -- libération) — ne pas la ré-accorder ici dans ce cas.
          IF v_player_invuln_grant AND v_player_turn_effect <> 'prepare_release' THEN
            v_player_invulnerable := true;
            v_player_invuln_granted_turn := v_turn_no;
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
      IF v_player_invuln_pending_miss THEN
        v_player_invuln_pending_miss := false;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'missed', true, 'invulnerable_miss', true,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_opponent_turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
      ELSE
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
            OR v_opponent_bonus_condition = 'has_status' AND v_opponent_status IS NOT NULL AND (v_opponent_bonus_status_filter IS NULL OR v_opponent_status = v_opponent_bonus_status_filter);
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
          v_opponent_used_ability := true;
          v_opponent_took_damage := false;

          v_player_hp := v_player_hp - v_hit_damage;
          v_player_took_damage := true;

          v_heal_amt := NULL;
          IF v_opponent_heal_type = 'static' THEN
            v_heal_amt := COALESCE(v_opponent_heal_amount, 0);
          ELSIF v_opponent_heal_type = 'percent_damage' THEN
            v_heal_amt := floor(v_hit_damage * COALESCE(v_opponent_heal_percent, 0) / 100.0)::integer;
          ELSIF v_opponent_heal_type = 'use_stats' THEN
            v_heal_dice := CASE WHEN v_opponent_ability.degats_de IS NOT NULL AND v_opponent_ability.degats_de > 0
              THEN 1 + floor(random() * v_opponent_ability.degats_de)::integer ELSE 0 END;
            v_heal_amt := COALESCE(v_opponent_ability.degats_base, 0) + v_heal_dice;
          END IF;

          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', v_hit_damage,
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
              v_stat_mod_expiry := CASE WHEN v_opponent_stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_turn_no + COALESCE(v_opponent_stat_mod_duration_turns, 1) END;
              IF v_opponent_stat_mod_target = 'self' AND v_opponent_stat_mod_stat = 'damage' THEN
                v_opponent_damage_mod_amount := v_stat_mod_amount; v_opponent_damage_mod_expires := v_stat_mod_expiry;
              ELSIF v_opponent_stat_mod_target = 'self' AND v_opponent_stat_mod_stat = 'precision' THEN
                v_opponent_precision_mod_amount := v_stat_mod_amount; v_opponent_precision_mod_expires := v_stat_mod_expiry;
              ELSIF v_opponent_stat_mod_target = 'opponent' AND v_opponent_stat_mod_stat = 'damage' THEN
                v_player_damage_mod_amount := v_stat_mod_amount; v_player_damage_mod_expires := v_stat_mod_expiry;
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
    END IF;

    -- Filet de sécurité : si les deux côtés infligent 0 dégât, ou s'ils sont
    -- tous deux configurés en 'skip' (aucun ne peut jamais gagner), on force
    -- une défaite plutôt qu'une boucle infinie.
    IF v_turn_no > 200 THEN v_outcome := 'lose'; EXIT; END IF;
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
CREATE OR REPLACE FUNCTION autobattle_resolve_manual_round(
  p_player_id bigint,
  p_level_id bigint,
  p_player_pokemon_id bigint,
  p_ability_nom text,
  p_idempotency_key uuid,
  p_is_new_battle boolean DEFAULT false
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
  v_is_new              boolean;
  v_ticket_item_nom     text := 'Ticket Combat';
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

  -- Une ligne existante pour un NOUVEAU tour (clé d'idempotence différente de
  -- la dernière connue) est un vestige d'un combat précédent sur ce niveau
  -- si soit (a) elle est terminée (outcome renseigné : gagné/perdu, puis
  -- réessayé), soit (b) le client signale explicitement le lancement d'un
  -- TOUT NOUVEAU combat (p_is_new_battle, envoyé uniquement au 1er tour) —
  -- ce 2e cas couvre un combat quitté EN COURS (outcome encore NULL) : sans
  -- lui, la ligne abandonnée restait vivante et un nouveau combat sur ce
  -- niveau reprenait à tort ses PV/statuts au lieu de redémarrer à zéro,
  -- alors que le client, lui, ré-affichait des PV pleins (d'où un gros saut
  -- de PV incohérent au coup suivant). Dans les deux cas on purge et on
  -- redémarre à zéro, comme s'il n'y avait pas de ligne du tout.
  IF v_row.id IS NOT NULL AND (v_row.outcome IS NOT NULL OR p_is_new_battle) THEN
    DELETE FROM autobattle_manual_battles WHERE id = v_row.id;
    v_row := NULL;
  END IF;

  v_is_new := v_row.id IS NULL;

  IF v_is_new THEN
    UPDATE player_items SET quantity = quantity - 1
      WHERE player_id = p_player_id AND item_nom = v_ticket_item_nom AND quantity >= 1;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('status', 'no_ticket');
    END IF;

    v_player_max_hp := COALESCE(v_player_species.pv_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'PV');
    v_first_attacker := CASE WHEN random() < 0.5 THEN 'player' ELSE 'opponent' END;

    INSERT INTO autobattle_manual_battles (
      player_id, level_id, variant_id, player_pokemon_id, first_attacker, turn_no,
      player_hp, player_max_hp, opponent_hp
    ) VALUES (
      p_player_id, p_level_id, v_variant.id, p_player_pokemon_id, v_first_attacker, 0,
      GREATEST(1, v_player_max_hp), GREATEST(1, v_player_max_hp), v_level.opponent_hp
    ) RETURNING * INTO v_row;
  END IF;

  -- État persisté (créé à l'instant, ou chargé depuis un tour précédent) :
  -- copié dans les variables de travail.
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

  v_player_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (v_player_species.super_efficace_1), (v_player_species.super_efficace_2),
      (v_player_species.super_efficace_3), (v_player_species.super_efficace_4)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(v_opponent_species.type))
  );
  v_player_damage := (COALESCE(v_player_species.degats_base, 0) + autobattle_xp_bonus(v_pp.pokemon_nom, v_pp.xp, 'DMG'))
    * (CASE WHEN v_player_type_bonus THEN 2 ELSE 1 END) + COALESCE(v_ability.degats_base, 0);
  v_player_damage_original := v_player_damage;

  v_opponent_type_bonus := EXISTS (
    SELECT 1 FROM (VALUES
      (v_opponent_species.super_efficace_1), (v_opponent_species.super_efficace_2),
      (v_opponent_species.super_efficace_3), (v_opponent_species.super_efficace_4)
    ) AS s(val) WHERE lower(trim(val)) = lower(trim(v_player_species.type))
  );
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
      IF v_opponent_invuln_pending_miss THEN
        v_opponent_invuln_pending_miss := false;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'player', 'damage', 0, 'missed', true, 'invulnerable_miss', true,
          'defender_hp_after', GREATEST(0, v_opponent_hp), 'ko', false
        ));
        IF v_player_turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
      ELSE
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
            OR v_player_bonus_condition = 'has_status' AND v_player_status IS NOT NULL AND (v_player_bonus_status_filter IS NULL OR v_player_status = v_player_bonus_status_filter);
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
          v_player_used_ability := true;
          v_player_took_damage := false;

          v_opponent_hp := v_opponent_hp - v_hit_damage;
          v_opponent_took_damage := true;

          v_heal_amt := NULL;
          IF v_player_heal_type = 'static' THEN
            v_heal_amt := COALESCE(v_player_heal_amount, 0);
          ELSIF v_player_heal_type = 'percent_damage' THEN
            v_heal_amt := floor(v_hit_damage * COALESCE(v_player_heal_percent, 0) / 100.0)::integer;
          ELSIF v_player_heal_type = 'use_stats' THEN
            v_heal_dice := CASE WHEN v_ability.degats_de IS NOT NULL AND v_ability.degats_de > 0
              THEN 1 + floor(random() * v_ability.degats_de)::integer ELSE 0 END;
            v_heal_amt := COALESCE(v_ability.degats_base, 0) + v_heal_dice;
          END IF;

          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'player', 'damage', v_hit_damage,
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
              v_stat_mod_expiry := CASE WHEN v_player_stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_turn_no + COALESCE(v_player_stat_mod_duration_turns, 1) END;
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
      IF v_player_invuln_pending_miss THEN
        v_player_invuln_pending_miss := false;
        v_turns := v_turns || jsonb_build_array(jsonb_build_object(
          'turn', v_turn_no, 'attacker', 'opponent', 'damage', 0, 'missed', true, 'invulnerable_miss', true,
          'defender_hp_after', GREATEST(0, v_player_hp), 'ko', false
        ));
        IF v_opponent_turn_effect = 'repeat_until_fail' THEN
          v_block_remaining := 1;
        END IF;
      ELSE
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
            OR v_opponent_bonus_condition = 'has_status' AND v_opponent_status IS NOT NULL AND (v_opponent_bonus_status_filter IS NULL OR v_opponent_status = v_opponent_bonus_status_filter);
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
          v_opponent_used_ability := true;
          v_opponent_took_damage := false;

          v_player_hp := v_player_hp - v_hit_damage;
          v_player_took_damage := true;

          v_heal_amt := NULL;
          IF v_opponent_heal_type = 'static' THEN
            v_heal_amt := COALESCE(v_opponent_heal_amount, 0);
          ELSIF v_opponent_heal_type = 'percent_damage' THEN
            v_heal_amt := floor(v_hit_damage * COALESCE(v_opponent_heal_percent, 0) / 100.0)::integer;
          ELSIF v_opponent_heal_type = 'use_stats' THEN
            v_heal_dice := CASE WHEN v_opponent_ability.degats_de IS NOT NULL AND v_opponent_ability.degats_de > 0
              THEN 1 + floor(random() * v_opponent_ability.degats_de)::integer ELSE 0 END;
            v_heal_amt := COALESCE(v_opponent_ability.degats_base, 0) + v_heal_dice;
          END IF;

          v_turn_entry := jsonb_build_object(
            'turn', v_turn_no, 'attacker', 'opponent', 'damage', v_hit_damage,
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
              v_stat_mod_expiry := CASE WHEN v_opponent_stat_mod_duration_type = 'battle_end' THEN 999999 ELSE v_turn_no + COALESCE(v_opponent_stat_mod_duration_turns, 1) END;
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

GRANT EXECUTE ON FUNCTION autobattle_resolve_manual_round(bigint, bigint, bigint, text, uuid, boolean) TO anon, authenticated;

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
