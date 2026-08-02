export interface Pokemon {
  id: number
  numero: string
  nom: string
  type: string
  degats_base: number
  pv_base: number
  super_efficace_1: string | null
  super_efficace_2: string | null
  super_efficace_3: string | null
  super_efficace_4: string | null
  distance_deplacement: number
  image_miniature: string
  image_illustree: string
  nom_talent: string | null
  description_talent: string | null
  chances_capture: string | null
  localisation_1: string | null
  localisation_2: string | null
  localisation_3: string | null
  cache: boolean
  code: string | null
  audio_url: string | null
  transport: string | null
  transport_value: number | null
  attaque_1: string | null
  attaque_2: string | null
  attaque_3: string | null
  attaque_4: string | null
  attaque_5: string | null
  attaque_6: string | null
  attaque_7: string | null
  attaque_8: string | null
  attaque_9: string | null
  attaque_10: string | null
  xp_10: string | null
  xp_20: string | null
  xp_30: string | null
  xp_40: string | null
  xp_50: string | null
  xp_60: string | null
  xp_70: string | null
  xp_80: string | null
  xp_90: string | null
  xp_100: string | null
}

export interface CsvRow {
  'Numéro': string
  'Nom': string
  'Type': string
  'Dégâts de base': string
  'PV de base': string
  'Super Efficace 1': string
  'Super Efficace 2': string
  'Super Efficace 3': string
  'Super Efficace 4': string
  'Distance de déplacement en combat': string
  'Image miniature': string
  'Image illustrée': string
  'Nom du talent': string
  'Description du talent': string
  'Chances de capture': string
  'Localisation 1': string
  'Localisation 2': string
  'Localisation 3': string
  'Caché': string
  'Code': string
  'Audio': string
  'Transport': string
  'Transport value': string
  'Attaque 1': string
  'Attaque 2': string
  'Attaque 3': string
  'Attaque 4': string
  'Attaque 5': string
  'Attaque 6': string
  'Attaque 7': string
  'Attaque 8': string
  'Attaque 9': string
  'Attaque 10': string
  '10 XP': string
  '20 XP': string
  '30 XP': string
  '40 XP': string
  '50 XP': string
  '60 XP': string
  '70 XP': string
  '80 XP': string
  '90 XP': string
  '100 XP': string
}

export const CSV_REQUIRED_HEADERS: (keyof CsvRow)[] = [
  'Numéro', 'Nom', 'Type', 'Dégâts de base', 'PV de base',
  'Distance de déplacement en combat', 'Image miniature', 'Image illustrée',
]

// ── Attaques ──────────────────────────────────────────────────
export interface Attack {
  id: number
  nom: string
  type: string
  degats_base: number | null
  degats_de: number | null
  cible: string | null
  distance: number | null
  precision: number | null
  degats_moyens: number | null
  effet: string | null
}

export interface AttackCsvRow {
  'Attaque': string
  'Type': string
  'Dégâts de base': string
  'Dégâts dé': string
  'Cible': string
  'Distance': string
  'Précision': string
  'Dégâts moyens': string
  'Effet': string
}

export const ATTACK_CSV_REQUIRED_HEADERS: (keyof AttackCsvRow)[] = ['Attaque', 'Type']

// ── Carte ─────────────────────────────────────────────────────
export interface CarteLocation {
  id: number
  couleur: string
  titre: string
  description: string | null
  admin_description: string | null
  type: string | null
  image_url: string | null
}

export interface CarteCsvRow {
  'Couleur': string
  'Titre': string
  'Description': string
  'Admin Description': string
  'Type': string
  'Image': string
}

export const CARTE_CSV_REQUIRED_HEADERS: (keyof CarteCsvRow)[] = ['Couleur', 'Titre']

// ── Joueurs ───────────────────────────────────────────────────
export interface Player {
  id: number
  name: string
  color: string
  image_url: string
  is_npc: boolean
  full_body_image_url: string
  age: number | null
  background_story: string
  level: number
  stat_charisme: number
  stat_intelligence: number
  stat_sagesse: number
  stat_dexterite: number
  created_at: string
}

export const PLAYER_COLORS: string[] = [
  '#3B82F6', // bleu
  '#10B981', // émeraude
  '#F59E0B', // ambre
  '#8B5CF6', // violet
  '#EC4899', // rose
  '#06B6D4', // cyan
  '#F97316', // orange
  '#84CC16', // citron vert
]

export interface PlayerPokemon {
  id: number
  player_id: number
  pokemon_nom: string
  pokemon_numero: string | null
  nickname: string | null
  xp: number
  moves: string[]
  in_team: boolean
  next_gift_at: string | null
  gift_notified: boolean
  gift_notified_at: string | null
  created_at: string
}

// Nom affiché d'une instance possédée : surnom personnalisé si défini, sinon nom d'espèce
export function ownedPokemonName(pp: Pick<PlayerPokemon, 'nickname' | 'pokemon_nom'>): string {
  return pp.nickname?.trim() || pp.pokemon_nom
}

export interface AdminParameters {
  id: number
  max_moves: number
  max_team_size: number
  carte_image_url: string
  carte_couleurs_image_url: string
  map_addon_image_urls: string[]
  accueil_image_url: string
  feature_pokedex_enabled: boolean
  feature_photo_capture_enabled: boolean
  feature_pokemon_enabled: boolean
  feature_inventory_enabled: boolean
  feature_map_enabled: boolean
  feature_gifting_enabled: boolean
  feature_casino_enabled: boolean
  stat_points_base: number
  stat_min: number
  stat_max: number
  stat_points_per_level: number
}

// Fond par défaut de l'écran d'accueil (modifiable dans Admin → Paramètres)
export const DEFAULT_ACCUEIL_IMAGE_URL =
  'https://media-s3-us-east-1.ceros.com/hype-beast/images/2018/07/13/a9a51bc0b8d626db493ab5f9a971b043/background-hero.png?imageOpt=1&fit=bounds&width=2163'

// ── Objets (Sac) ──────────────────────────────────────────────
export interface Item {
  id: number
  nom: string
  type: string
  rarete: string | null
  cout: number
  description: string | null
  image_url: string | null
}

export interface ItemCsvRow {
  'Nom': string
  'Type': string
  'Rareté': string
  'Coût': string
  'Description': string
  'Image': string
}

export const ITEM_CSV_REQUIRED_HEADERS: (keyof ItemCsvRow)[] = ['Nom', 'Type', 'Coût']

export interface PlayerItem {
  id: number
  player_id: number
  item_nom: string
  quantity: number
  created_at: string
}

export const POKEDOLLAR_ITEM_NAME = 'Pokédollar'
export const sellValue = (cout: number) => Math.floor(cout / 2)

// ── Évolutions ────────────────────────────────────────────────
export interface PokemonEvolution {
  id: number
  pokemon_nom: string
  evolution_nom: string
  condition_item_nom: string | null
  created_at: string
}

export interface PokemonEvolutionCsvRow {
  'Nom': string
  'Évolution': string
  'Condition': string
}

export const POKEMON_EVOLUTION_CSV_REQUIRED_HEADERS: (keyof PokemonEvolutionCsvRow)[] = ['Nom', 'Évolution']

// ── Cadeaux Pokémon (lootboxes) ───────────────────────────────
export type GiftTimerUnit = 'hours' | 'minutes'

export interface GiftLootbox {
  id: number
  nom: string
  is_default: boolean
  timer_min: number
  timer_max: number
  timer_unit: GiftTimerUnit
  created_at: string
}

export interface GiftLootboxItem {
  id: number
  lootbox_id: number
  item_nom: string // peut valoir POKEDOLLAR_ITEM_NAME
  quantity: number
  weight: number
  created_at: string
}

export interface GiftLootboxSpecies {
  pokemon_nom: string // clé primaire : une espèce = un seul lootbox
  lootbox_id: number
  created_at: string
}

export const DEFAULT_LOOTBOX_TIMER_MIN_HOURS = 60
export const DEFAULT_LOOTBOX_TIMER_MAX_HOURS = 80

// ── Casino ─────────────────────────────────────────────────────
export const TICKET_CASINO_ITEM_NAME = 'Ticket Casino'

export type SlotSymbol = 'pokeball' | 'superball' | 'hyperball' | 'masterball'

export interface CasinoConfig {
  id: number
  // Économie des tickets
  ticket_max: number
  ticket_regen_amount: number
  ticket_regen_unit: GiftTimerUnit
  ticket_buy_cost: number
  ticket_daily_buy_cap: number
  ticket_full_notify_enabled: boolean
  // Chance de Miaouss (machine à sous)
  slots_enabled: boolean
  slots_nom: string
  slots_icon_url: string
  slots_banner_url: string
  slots_pokeball_value: number
  slots_superball_value: number
  slots_hyperball_value: number
  slots_masterball_value: number
  // Poids relatifs de tirage (probabilité = poids / somme des poids)
  slots_pokeball_weight: number
  slots_superball_weight: number
  slots_hyperball_weight: number
  slots_masterball_weight: number
  slots_match2_multiplier: number
  slots_match3_multiplier: number
  // Dé Chance (dés contre l'IA)
  dice_enabled: boolean
  dice_nom: string
  dice_icon_url: string
  dice_banner_url: string
  dice_max_rounds: number
  dice_initial_gain: number
  dice_ai_target_min: number
  dice_ai_target_max: number
  dice_opponent_name: string
  dice_opponent_image_url: string
}

export interface CasinoPlayerState {
  player_id: number
  next_ticket_at: string | null
  purchase_count: number
  purchase_date: string | null
  ticket_full_notified: boolean
  created_at: string
}

// ── Notifications Push ───────────────────────────────────────
export interface PushSubscriptionRow {
  id: number
  player_id: number
  endpoint: string
  p256dh: string
  auth: string
  created_at: string
}

// ── Mode Affichage ───────────────────────────────────────────
// Types en usage dans display_assets.type : 'NPC' (figures PNJ), 'Background'
// (fonds d'écran, table `backgrounds` fusionnée ici — voir schema.sql) et
// 'Map Add-On' (calque superposé à la Carte, voir CarteTab.tsx).
export interface DisplayAsset {
  id: number
  nom: string
  type: string
  image_url: string
  reference: string
}

export interface DisplayAssetCsvRow {
  'Nom': string
  'Type': string
  'Image': string
  'Reference': string
}

export const DISPLAY_ASSET_CSV_REQUIRED_HEADERS: (keyof DisplayAssetCsvRow)[] = ['Nom', 'Type', 'Image', 'Reference']

export interface DisplayState {
  id: number
  background_id: number | null
  /** Fond personnalisé (ex : bannière de chapitre/session) — prioritaire sur background_id quand renseigné. */
  background_url: string | null
  npc_ids: number[]
  pokemon_ids: number[]
  item_ids: number[]
  updated_at: string
}

// ── Rencontres ────────────────────────────────────────────────
export interface Encounter {
  id: number
  lieu: string
  pokemon_nom: string
  de: number | null
  commentaire: string | null
}

export interface EncounterCsvRow {
  'Lieu': string
  'Pokémon': string
  'Dé': string
  'Commentaire': string
}

export const ENCOUNTER_CSV_REQUIRED_HEADERS: (keyof EncounterCsvRow)[] = ['Lieu', 'Pokémon', 'Dé']

// ── Journal de campagne ──────────────────────────────────────────
export interface CampaignSession {
  id: number
  title: string
  icon: string
  session_date: string | null
  image_url: string | null
  image_position: number
  done: boolean
  notes: import('@tiptap/core').JSONContent
  position: number
  created_at: string
}

export interface CampaignChapter {
  id: number
  session_id: number
  title: string
  icon: string
  content: import('@tiptap/core').JSONContent
  notes: import('@tiptap/core').JSONContent
  done: boolean
  position: number
  created_at: string
}

export const EMPTY_CHAPTER_CONTENT: import('@tiptap/core').JSONContent = {
  type: 'doc',
  content: [{ type: 'paragraph' }],
}

// ── Historique (journal des actions joueurs) ──────────────────
export type HistoryCategory = 'inventory' | 'pokedex' | 'team' | 'combat'

export type HistoryActionType =
  | 'item_add'          // ajout générique (Sac, achat de ticket, recharge de tickets)
  | 'item_remove'       // retrait générique (Sac, achat de ticket)
  | 'item_sale'         // vente d'un objet (crédit Pokédollar uniquement, une seule ligne)
  | 'item_gift'         // cadeau reçu d'un Pokémon
  | 'item_casino_win'   // gains au Casino
  | 'item_casino_spend' // ticket dépensé au Casino
  | 'pokedex_add'       // espèce découverte
  | 'pokemon_new'       // nouveau Pokémon obtenu (équipe ou PC)
  | 'pokemon_move'      // Pokémon existant déplacé équipe <-> PC
  | 'pokemon_evolve'    // Pokémon existant a évolué vers une nouvelle espèce
  | 'ko'                // K.O. / sortie de K.O.
  | 'status_change'     // statut appliqué / retiré

// Sur une ligne brute en base, `delta` est signé (négatif pour un retrait).
// Le regroupement à la lecture (src/lib/historyGrouping.ts) le normalise en
// valeur positive une fois le action_type net résolu (add vs remove).
export interface HistoryInventoryPayload {
  item_nom: string // nom de l'objet, ou 'Pokédollar' / 'Ticket Casino'
  delta: number
  total: number
  // ex: 'le Sac', 'la recharge de tickets', 'la vente de : Filet Ball',
  // "l'achat de tickets", nom d'affichage du Pokémon (cadeau), ou nom du
  // jeu de Casino (config.dice_nom / slots_nom)
  source: string
}

export interface HistoryPokedexPayload {
  pokemon_nom: string
  total: number // total de découvertes campagne-wide après l'événement
}

export interface HistoryTeamPayload {
  pokemon_nom: string
  player_pokemon_id: number
  nickname: string | null
  destination?: 'team' | 'pc'   // absent pour pokemon_evolve
  to_pokemon_nom?: string       // action_type === 'pokemon_evolve' : nouvelle espèce
}

export interface HistoryCombatPayload {
  pokemon_nom: string
  player_pokemon_id: number
  nickname: string | null
  ko?: boolean             // action_type === 'ko' : true = entre en K.O., false = sort du K.O.
  status_id?: import('./lib/status').StatusId // action_type === 'status_change'
  status_gained?: boolean  // true = statut appliqué, false = statut retiré
}

export type HistoryPayload =
  | HistoryInventoryPayload
  | HistoryPokedexPayload
  | HistoryTeamPayload
  | HistoryCombatPayload

export interface HistoryEvent {
  id: number
  player_id: number
  category: HistoryCategory
  action_type: HistoryActionType
  payload: HistoryPayload
  created_at: string
}
