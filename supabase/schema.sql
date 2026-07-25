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
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS carte_image_url text NOT NULL DEFAULT '';
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS carte_couleurs_image_url text NOT NULL DEFAULT '';
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS accueil_image_url text NOT NULL DEFAULT '';
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_pokedex_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_photo_capture_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_pokemon_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_inventory_enabled boolean NOT NULL DEFAULT true;
-- ALTER TABLE admin_parameters ADD COLUMN IF NOT EXISTS feature_map_enabled boolean NOT NULL DEFAULT true;
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
  id          bigserial PRIMARY KEY,
  name        text NOT NULL,
  color       text NOT NULL DEFAULT '#3B82F6',
  image_url   text NOT NULL DEFAULT '',
  is_npc      boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Pokémon possédés (une ligne par instance capturée, pas par espèce :
-- un joueur peut posséder plusieurs fois le même pokémon)
CREATE TABLE IF NOT EXISTS player_pokemon (
  id              bigserial PRIMARY KEY,
  player_id       bigint NOT NULL,
  pokemon_nom     text NOT NULL,     -- référence par nom vers pokemon.nom (pas de FK, survit aux réimports CSV)
  pokemon_numero  text,              -- copie du numéro pour résilience d'affichage
  xp              integer NOT NULL DEFAULT 0,
  moves           text[] NOT NULL DEFAULT '{}',
  in_team         boolean NOT NULL DEFAULT false,
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
  accueil_image_url         text NOT NULL DEFAULT '',
  feature_pokedex_enabled        boolean NOT NULL DEFAULT true,
  feature_photo_capture_enabled  boolean NOT NULL DEFAULT true,
  feature_pokemon_enabled        boolean NOT NULL DEFAULT true,
  feature_inventory_enabled      boolean NOT NULL DEFAULT true,
  feature_map_enabled            boolean NOT NULL DEFAULT true,
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
  cout        integer NOT NULL DEFAULT 0,
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
-- Journal de campagne (Sessions / Chapitres)
-- ============================================================

CREATE TABLE IF NOT EXISTS campaign_sessions (
  id           bigserial PRIMARY KEY,
  title        text NOT NULL,
  icon         text NOT NULL DEFAULT '📓',
  session_date date,
  image_url    text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS campaign_chapters (
  id           bigserial PRIMARY KEY,
  session_id   bigint NOT NULL REFERENCES campaign_sessions(id) ON DELETE CASCADE,
  title        text NOT NULL,
  icon         text NOT NULL DEFAULT '📄',
  image_url    text,
  content      jsonb NOT NULL DEFAULT '{"type":"doc","content":[{"type":"paragraph"}]}'::jsonb,
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
