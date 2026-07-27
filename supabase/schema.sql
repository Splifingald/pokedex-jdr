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
-- ALTER TABLE casino_config ADD COLUMN IF NOT EXISTS slots_superball_weight integer NOT NULL DEFAULT 1;
-- ALTER TABLE casino_config ADD COLUMN IF NOT EXISTS slots_hyperball_weight integer NOT NULL DEFAULT 1;
-- ALTER TABLE casino_config ADD COLUMN IF NOT EXISTS slots_masterball_weight integer NOT NULL DEFAULT 1;
-- ALTER TABLE casino_config ADD COLUMN IF NOT EXISTS dice_opponent_name text NOT NULL DEFAULT 'Le Croupier';
-- ALTER TABLE casino_config ADD COLUMN IF NOT EXISTS dice_opponent_image_url text NOT NULL DEFAULT '';
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
  nickname        text,              -- surnom personnalisé donné par le joueur (affiché à la place de pokemon_nom si défini)
  xp              integer NOT NULL DEFAULT 0,
  moves           text[] NOT NULL DEFAULT '{}',
  in_team         boolean NOT NULL DEFAULT false,
  next_gift_at    timestamptz,       -- prochain cadeau du pokémon (cadeaux Pokémon), NULL = aucun cadeau prévu
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
  feature_gifting_enabled        boolean NOT NULL DEFAULT true,
  feature_casino_enabled         boolean NOT NULL DEFAULT true,
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
-- Fonds d'écran de l'accueil (importés par CSV via Netlify Function)
-- ============================================================

CREATE TABLE IF NOT EXISTS backgrounds (
  id          bigserial PRIMARY KEY,
  nom         text NOT NULL UNIQUE,
  image_url   text NOT NULL DEFAULT ''
);

ALTER TABLE backgrounds ENABLE ROW LEVEL SECURITY;

-- backgrounds : lecture publique, écriture bloquée pour anon (via Netlify Function seulement)
CREATE POLICY "Public read backgrounds"
  ON backgrounds FOR SELECT
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
  done         boolean NOT NULL DEFAULT false,
  notes        jsonb NOT NULL DEFAULT '{"type":"doc","content":[{"type":"paragraph"}]}'::jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS campaign_chapters (
  id           bigserial PRIMARY KEY,
  session_id   bigint NOT NULL REFERENCES campaign_sessions(id) ON DELETE CASCADE,
  title        text NOT NULL,
  icon         text NOT NULL DEFAULT '📄',
  image_url    text,
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
INSERT INTO items (nom, type, cout, description, image_url)
VALUES ('Ticket Casino', 'Monnaie', 0, 'Permet de jouer au Casino.', '/website_icons/icon_casino_ticket.png')
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
  player_id      bigint PRIMARY KEY,
  next_ticket_at timestamptz,
  purchase_count integer NOT NULL DEFAULT 0,
  purchase_date  date,
  created_at     timestamptz NOT NULL DEFAULT now()
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
