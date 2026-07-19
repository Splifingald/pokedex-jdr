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
  attaque_10            text
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
  max_hp_override integer,          -- si renseigné, remplace pokemon.pv_base pour cette instance uniquement
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Mise à jour si la table existe déjà :
-- ALTER TABLE player_pokemon ADD COLUMN IF NOT EXISTS max_hp_override integer;

-- Paramètres admin (une seule ligne, id fixe = 1)
CREATE TABLE IF NOT EXISTS admin_parameters (
  id             bigint PRIMARY KEY DEFAULT 1,
  max_moves      integer NOT NULL DEFAULT 4,
  max_team_size  integer NOT NULL DEFAULT 3,
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
