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

// ── Chat (canal de discussion global) ────────────────────────
export interface ChatMessage {
  id: number
  player_id: number
  content: string
  is_npc: boolean
  created_at: string
}

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
  in_daycare: boolean
  daycare_placed_at: string | null
  daycare_last_tick_at: string | null
  daycare_lifetime_xp: number
  daycare_capped: boolean
  daycare_capped_notified: boolean
  daycare_xp_at_placement: number | null
  egg_reveal_seen: boolean
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
  feature_minijeux_enabled: boolean
  feature_mining_enabled: boolean
  feature_pension_enabled: boolean
  feature_safari_enabled: boolean
  feature_autobattle_enabled: boolean
  feature_chat_enabled: boolean
  chat_max_message_length: number
  chat_spam_limit_per_minute: number
  chat_last_notified_at: string | null
  stat_points_base: number
  stat_min: number
  stat_max: number
  stat_points_per_level: number
  stat_charisme_icon_url: string
  stat_charisme_description: string
  stat_intelligence_icon_url: string
  stat_intelligence_description: string
  stat_sagesse_icon_url: string
  stat_sagesse_description: string
  stat_dexterite_icon_url: string
  stat_dexterite_description: string
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
  achat: number
  vente: number
  description: string | null
  image_url: string | null
}

export interface ItemCsvRow {
  'Nom': string
  'Type': string
  'Rareté': string
  'Achat': string
  'Vente': string
  'Description': string
  'Image': string
}

export const ITEM_CSV_REQUIRED_HEADERS: (keyof ItemCsvRow)[] = ['Nom', 'Type', 'Achat']

export interface PlayerItem {
  id: number
  player_id: number
  item_nom: string
  quantity: number
  created_at: string
}

export const POKEDOLLAR_ITEM_NAME = 'Pokédollar'

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

// ── Mini-Jeux ──────────────────────────────────────────────────
export const TICKET_TREMPETTE_ITEM_NAME = 'Ticket Trempette'

export interface MinigamesConfig {
  id: number
  // Économie des tickets
  ticket_max: number
  ticket_regen_amount: number
  ticket_regen_unit: GiftTimerUnit
  ticket_buy_cost: number
  ticket_daily_buy_cap: number
  ticket_full_notify_enabled: boolean
  // Jeu 1 : Magikarp (tap game)
  magikarp_enabled: boolean
  magikarp_nom: string
  magikarp_icon_url: string
  magikarp_banner_url: string
  magikarp_numero: string
  magikarp_duration_seconds: number
  magikarp_star1_taps: number
  magikarp_star2_taps: number
  magikarp_star3_taps: number
  magikarp_star1_xp: number
  magikarp_star2_xp: number
  magikarp_star3_xp: number
}

export interface MinigamesPlayerState {
  player_id: number
  next_ticket_at: string | null
  purchase_count: number
  purchase_date: string | null
  ticket_full_notified: boolean
  magikarp_high_score: number
  created_at: string
}

// ── Fouille (mini-jeu collaboratif de fouille sur grille partagée) ─────
export const TICKET_MINING_ITEM_NAME = 'Ticket Fouille'

export interface MiningConfig {
  id: number
  // Économie des tickets
  ticket_max: number
  ticket_regen_amount: number
  ticket_regen_unit: GiftTimerUnit
  ticket_buy_cost: number
  ticket_daily_buy_cap: number
  ticket_full_notify_enabled: boolean
  // Affichage
  nom: string
  icon_url: string
  banner_url: string
  hidden_cell_image_url: string
  empty_cell_image_url: string
  // Génération procédurale
  grid_size_min: number
  grid_size_max: number
  fill_ratio_pct: number
  move_budget_pct: number
  // Grille personnalisée mise en file pour la prochaine génération (consommée une fois puis NULL)
  next_custom_grid_id: number | null
}

export interface MiningPlayerState {
  player_id: number
  next_ticket_at: string | null
  purchase_count: number
  purchase_date: string | null
  ticket_full_notified: boolean
  created_at: string
}

// Bibliothèque d'objets pouvant apparaître sur une grille procédurale.
export interface MiningItemDef {
  id: number
  item_nom: string
  size: 1 | 2 | 3 | 4
  weight: number
  enabled: boolean
  created_at: string
}

export interface MiningCustomGrid {
  id: number
  nom: string
  size: number
  move_budget: number
  created_at: string
}

export interface MiningCustomGridItem {
  id: number
  custom_grid_id: number
  item_nom: string
  size: 1 | 2 | 3 | 4
  origin_row: number
  origin_col: number
  created_at: string
}

export type MiningGridSource = 'procedural' | 'custom'

// La grille en cours (une seule active à la fois, partagée par tous les joueurs).
export interface MiningGrid {
  id: number
  size: number
  move_budget: number
  moves_used: number
  source: MiningGridSource
  custom_grid_id: number | null
  is_active: boolean
  created_at: string
  ended_at: string | null
}

// Instance d'objet placé sur une grille (procédurale ou personnalisée) — suit
// combien de cases il reste à découvrir avant d'être attribué au joueur qui
// creuse la dernière.
export interface MiningGridItem {
  id: number
  grid_id: number
  item_nom: string
  size: 1 | 2 | 3 | 4
  origin_row: number
  origin_col: number
  cells_total: number
  cells_remaining: number
  completed: boolean
  completed_by_player_id: number | null
  completed_at: string | null
}

// Une ligne par case de la grille — voir supabase/schema.sql pour pourquoi
// (fouilles simultanées sûres via UPDATE ... WHERE dug=false atomique).
export interface MiningGridCell {
  id: number
  grid_id: number
  cell_index: number // 0-indexé, row-major : index = row*size + col
  item_id: number | null // null = case vide
  dug: boolean
  dug_by_player_id: number | null
  dug_at: string | null
}

// Journal des coups joués sur la grille active, affiché en direct dans le
// popup Fouille (distinct de history_events : seuls les objets complétés sont
// aussi loggés globalement, pas chaque case creusée).
export interface MiningMove {
  id: number
  grid_id: number
  player_id: number
  cell_index: number
  item_id: number | null
  item_completed: boolean
  created_at: string
}

// ── Pension Pokémon (garderie collaborative) ────────────────────
export interface PensionConfig {
  id: number
  nom: string
  icon_url: string
  banner_url: string
  capacity_total: number
  tick_xp_amount: number
  tick_interval_amount: number
  tick_interval_unit: GiftTimerUnit
  default_lifetime_xp_cap: number
  default_hatch_timer_min: number
  default_hatch_timer_max: number
  default_hatch_timer_unit: GiftTimerUnit
  info_text: string
}

// 'default' = hérite de la réserve d'œufs par défaut (groupe sentinelle
// DEFAULT_EGG_POOL_GROUP dans pension_egg_pool) ; 'custom' = utilise la propre
// réserve du groupe (pension_egg_pool.groupe = ce groupe) ; 'none' = ce groupe
// ne produit jamais d'œuf, même si la réserve par défaut n'est pas vide.
export type PensionEggPoolMode = 'default' | 'custom' | 'none'

// groupe = clé primaire (texte libre venu du CSV pokemon_egg_groups). Purement
// dédié à l'éclosion (fourchette + réserve d'œufs) — les réglages XP (intervalle
// de tick, plafond à vie) sont un concept entièrement séparé, voir PensionXpGroup.
// Les champs nullable héritent de PensionConfig quand non renseignés.
export interface PensionGroupConfig {
  groupe: string
  hatch_timer_min: number | null
  hatch_timer_max: number | null
  hatch_timer_unit: GiftTimerUnit | null
  egg_pool_mode: PensionEggPoolMode
  created_at: string
}

// Groupe XP — créé manuellement par l'admin (pas de CSV), entièrement
// indépendant des groupes d'œufs. Une espèce appartient à au plus un groupe XP
// (voir PensionXpGroupSpecies) ; toute espèce non assignée utilise les valeurs
// par défaut de PensionConfig (tick_interval_amount/unit, default_lifetime_xp_cap).
export interface PensionXpGroup {
  id: number
  nom: string
  tick_interval_amount: number
  tick_interval_unit: GiftTimerUnit
  lifetime_xp_cap: number
  created_at: string
}

// pokemon_nom = clé primaire : une espèce n'appartient qu'à un seul groupe XP à la fois.
export interface PensionXpGroupSpecies {
  pokemon_nom: string
  xp_group_id: number
  created_at: string
}

export interface PokemonEggGroup {
  id: number
  pokemon_nom: string
  groupe: string
  created_at: string
}

export interface PensionEggPoolEntry {
  id: number
  groupe: string
  pokemon_nom: string
  weight: number
  created_at: string
}

// fixed_recipient_pokemon_id non-null uniquement pour un appariement ALL/TOUS
// (l'œuf va toujours au propriétaire de CE pokémon, jamais un tirage 50/50)
export interface PensionPair {
  id: number
  pokemon_a_id: number
  pokemon_b_id: number
  groupe: string
  fixed_recipient_pokemon_id: number | null
  paired_since: string
  target_duration_seconds: number
  created_at: string
}

export interface PokemonEggGroupCsvRow {
  'Pokémon': string
  'Groupe 1': string
  'Groupe 2': string
  'Groupe 3': string
}

export const POKEMON_EGG_GROUP_CSV_REQUIRED_HEADERS: (keyof PokemonEggGroupCsvRow)[] = ['Pokémon']

// ── Safari (mini-jeu collaboratif : session partagée de 3 pokémon sauvages) ──
export const BERRY_SAFARI_ITEM_NAME = 'Baie Framby'
export const BALL_SAFARI_ITEM_NAME = 'Safari Ball'

export interface SafariConfig {
  id: number
  nom: string
  icon_url: string
  banner_url: string
  session_duration_amount: number
  session_duration_unit: GiftTimerUnit
  berry_min_increase: number
  berry_max_increase: number
  berry_reward_amount: number
  berry_reward_interval_amount: number
  berry_reward_interval_unit: GiftTimerUnit
  berry_reward_max: number
  ball_reward_amount: number
  ball_reward_interval_amount: number
  ball_reward_interval_unit: GiftTimerUnit
  ball_reward_max: number
}

export interface SafariGroup {
  id: number
  nom: string
  weight: number
  created_at: string
}

export interface SafariGroupPokemon {
  id: number
  group_id: number
  pokemon_nom: string
  weight: number
  created_at: string
}

export interface SafariGaugeArea {
  id: number
  group_id: number
  min_value: number
  max_value: number
  color: string
  catch_rate_pct: number
  sort_order: number
  created_at: string
}

export type SafariPokemonStatus = 'active' | 'captured' | 'fled'

export interface SafariSession {
  id: number
  is_active: boolean
  started_at: string
  expires_at: string
  ended_at: string | null
  notified: boolean
}

export interface SafariSessionPokemon {
  id: number
  session_id: number
  slot: number
  pokemon_nom: string
  group_id: number
  position_gauge: number
  status: SafariPokemonStatus
  captured_by_player_id: number | null
  resolved_at: string | null
  created_at: string
}

export interface SafariBallAttempt {
  id: number
  session_pokemon_id: number
  player_id: number
  success: boolean
  created_at: string
}

// Tirage forcé par l'admin pour la PROCHAINE session (au plus 3 lignes, une
// par slot) — consommé une seule fois puis vidé, voir
// safari_ensure_active_session() côté SQL.
export interface SafariForcedPokemon {
  slot: number
  group_id: number
  pokemon_nom: string
  created_at: string
}

export interface SafariPlayerState {
  player_id: number
  next_berry_at: string | null
  next_ball_at: string | null
  created_at: string
}

export type SafariMoveAction = 'berry' | 'ball_success' | 'ball_fail'

export interface SafariMove {
  id: number
  session_id: number
  session_pokemon_id: number | null
  player_id: number
  action: SafariMoveAction
  gauge_before: number | null
  gauge_after: number | null
  created_at: string
}

// ── Combat Auto (mini-jeu de combat automatique par niveaux) ───
export const TICKET_AUTOBATTLE_ITEM_NAME = 'Ticket Combat'

export interface AutoBattleConfig {
  id: number
  ticket_max: number
  ticket_regen_amount: number
  ticket_regen_unit: GiftTimerUnit
  ticket_buy_cost: number
  ticket_daily_buy_cap: number
  ticket_full_notify_enabled: boolean
  nom: string
  icon_url: string
}

export interface AutoBattlePlayerState {
  player_id: number
  next_ticket_at: string | null
  purchase_count: number
  purchase_date: string | null
  ticket_full_notified: boolean
  created_at: string
}

export interface AutoBattleVariant {
  id: number
  nom: string
  enabled: boolean
  icon_url: string
  banner_url: string
  sort_order: number
  created_at: string
}

export interface AutoBattleLevel {
  id: number
  variant_id: number
  level_index: number
  opponent_pokemon_nom: string
  opponent_hp: number
  opponent_base_damage: number
  opponent_ability_nom: string
  created_at: string
}

export type AutoBattleRewardType = 'xp' | 'item' | 'badge'

export interface AutoBattleLevelReward {
  id: number
  level_id: number
  reward_type: AutoBattleRewardType
  xp_amount: number | null
  item_nom: string | null
  item_quantity: number | null
  sort_order: number
  created_at: string
}

export interface AutoBattlePlayerVariantProgress {
  player_id: number
  variant_id: number
  current_level_index: number
  variant_completed: boolean
  completed_at: string | null
  created_at: string
}

export interface AutoBattlePlayerLevelState {
  player_id: number
  level_id: number
  discovered: boolean
  discovered_at: string | null
  completed: boolean
  completed_at: string | null
  created_at: string
}

// Capacité bannie du Combat Auto (trop puissante pour ce mode), gérée
// librement par l'admin — exclut la capacité du choix du joueur ET de celui
// de l'adversaire.
export interface AutoBattleBannedAttack {
  attack_nom: string
  created_at: string
}

// Un tour du journal de combat renvoyé par le RPC autobattle_resolve_battle —
// le client se contente de rejouer cette séquence (jamais recalculée côté client).
export interface AutoBattleTurn {
  turn: number
  attacker: 'player' | 'opponent'
  damage: number
  defender_hp_after: number
  ko: boolean
}

export interface AutoBattleReward {
  reward_type: AutoBattleRewardType
  xp_amount?: number
  player_pokemon_id?: number
  xp_before?: number
  xp_after?: number
  item_nom?: string
  quantity?: number
}

export type AutoBattleResolveStatus =
  | 'ok'
  | 'duplicate_request'
  | 'not_found'
  | 'variant_disabled'
  | 'variant_completed'
  | 'wrong_level'
  | 'ineligible_pokemon'
  | 'ineligible_ability'
  | 'invalid_level'
  | 'no_ticket'

// Réponse du RPC autobattle_resolve_battle (voir supabase/schema.sql) — seuls
// les champs pertinents pour status='ok' sont garantis présents.
export interface AutoBattleResolveResult {
  status: AutoBattleResolveStatus
  coin_toss_first?: 'player' | 'opponent'
  player_max_hp?: number
  opponent_hp?: number
  player_damage_per_hit?: number // dégâts de base, dé exclu (le dé est retiré au sort à chaque coup, voir turns[].damage)
  opponent_damage_per_hit?: number // idem
  player_type_bonus?: boolean
  opponent_type_bonus?: boolean
  turns?: AutoBattleTurn[]
  outcome?: 'win' | 'lose'
  rewards?: AutoBattleReward[]
  variant_completed?: boolean
  next_level_index?: number
  opponent_pokemon_nom?: string
  opponent_ability_nom?: string
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
export type HistoryCategory = 'inventory' | 'pokedex' | 'team' | 'combat' | 'minigame' | 'daycare' | 'safari' | 'autobattle' | 'chat'

export type HistoryActionType =
  | 'item_add'          // ajout générique (Sac, achat de ticket, recharge de tickets)
  | 'item_remove'       // retrait générique (Sac, achat de ticket)
  | 'item_sale'         // vente d'un objet (crédit Pokédollar uniquement, une seule ligne)
  | 'item_gift'         // cadeau reçu d'un Pokémon
  | 'item_casino_win'   // gains au Casino
  | 'item_casino_spend' // ticket dépensé au Casino
  | 'item_minigame_spend' // ticket Mini-Jeux dépensé
  | 'item_mining_spend' // ticket Fouille dépensé
  | 'item_autobattle_spend' // ticket Combat Auto dépensé
  | 'minigame_xp_gain'  // XP crédité à un Pokémon via un Mini-Jeu
  | 'mining_item_found' // objet entièrement déterré sur la grille de Fouille
  | 'daycare_drop_off'  // pokémon déposé à la Pension
  | 'daycare_pickup'    // pokémon récupéré à la Pension
  | 'daycare_egg_received' // œuf reçu à la Pension
  | 'daycare_pair_formed' // pokémon nouvellement placé compatible avec un pokémon déjà en pension
  | 'safari_berry_throw' // baie lancée sur un pokémon Safari
  | 'safari_capture'     // pokémon Safari capturé
  | 'safari_flee'        // pokémon Safari a fui
  | 'autobattle_win'     // niveau de Combat Auto remporté
  | 'autobattle_lose'    // niveau de Combat Auto perdu
  | 'autobattle_variant_completed' // dernière niveau d'une variante remporté
  | 'pokedex_add'       // espèce découverte
  | 'pokemon_new'       // nouveau Pokémon obtenu (équipe ou PC)
  | 'pokemon_move'      // Pokémon existant déplacé équipe <-> PC
  | 'pokemon_evolve'    // Pokémon existant a évolué vers une nouvelle espèce
  | 'ko'                // K.O. / sortie de K.O.
  | 'status_change'     // statut appliqué / retiré
  | 'chat_message'      // message envoyé dans le chat global

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

export interface HistoryMinigamePayload {
  game_nom: string        // ex: config.magikarp_nom
  pokemon_nom: string     // espèce créditée (ex: 'Magicarpe')
  player_pokemon_id: number
  nickname: string | null
  xp_delta: number
  xp_total: number
  score: number            // score brut de la partie (nb de taps)
  stars: number             // étoiles obtenues sur cette partie
}

export interface HistoryMiningPayload {
  item_nom: string
  grid_id: number
  grid_size: number
}

export interface HistoryDaycarePayload {
  pokemon_nom: string
  player_pokemon_id: number
  nickname: string | null
  parent_a_nom?: string   // action_type === 'daycare_egg_received' uniquement
  parent_b_nom?: string   // action_type === 'daycare_egg_received' uniquement
  partner_pokemon_nom?: string   // action_type === 'daycare_pair_formed' uniquement
}

export interface HistorySafariPayload {
  pokemon_nom: string
  session_pokemon_id: number
  gauge_before?: number   // action_type === 'safari_berry_throw'
  gauge_after?: number    // action_type === 'safari_berry_throw'
}

export interface HistoryAutoBattlePayload {
  variant_nom: string
  pokemon_nom: string
  player_pokemon_id: number
  nickname: string | null
  level_index: number
  opponent_pokemon_nom: string
  variant_completed?: boolean // action_type === 'autobattle_variant_completed' uniquement
}

export interface HistoryChatPayload {
  content: string
  is_npc: boolean
}

export type HistoryPayload =
  | HistoryInventoryPayload
  | HistoryPokedexPayload
  | HistoryTeamPayload
  | HistoryCombatPayload
  | HistoryMinigamePayload
  | HistoryMiningPayload
  | HistoryDaycarePayload
  | HistorySafariPayload
  | HistoryAutoBattlePayload
  | HistoryChatPayload

export interface HistoryEvent {
  id: number
  player_id: number
  category: HistoryCategory
  action_type: HistoryActionType
  payload: HistoryPayload
  created_at: string
}
