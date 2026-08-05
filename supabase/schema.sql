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
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO pension_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

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
  v_capacity integer;
  v_current_count integer;
  v_player_has_slot integer;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('pension_slots'));

  SELECT player_id, in_team, in_daycare, daycare_capped
    INTO v_owner, v_in_team, v_in_daycare, v_capped
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
  SET in_daycare = true, daycare_placed_at = now(), daycare_last_tick_at = now()
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
