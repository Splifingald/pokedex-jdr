import type { BattleAnimationId } from './lib/battleAnimations'

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
  attaque_11: string | null
  attaque_12: string | null
  attaque_13: string | null
  attaque_14: string | null
  attaque_15: string | null
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
  'Attaque 11': string
  'Attaque 12': string
  'Attaque 13': string
  'Attaque 14': string
  'Attaque 15': string
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
  // Statut "mini-jeu" (Combat Auto uniquement) importé depuis le CSV au même
  // titre que le reste de l'attaque — voir AutoBattleStatusEffect plus bas.
  status_effect: AutoBattleStatusEffect | null
  status_chance: number | null
  // Capacités non-offensives (soin pur, buff pur, statut sur soi...) :
  // n'infligent AUCUN dégât (même passif espèce+XP) quand utilisées en
  // Combat Auto/Manuel — importé depuis le CSV (colonne "Inflige dégâts").
  deals_damage: boolean
  // Animation jouée par le pokémon quand il utilise cette capacité en Combat
  // Auto/Manuel (colonne "Animation" du CSV) — purement visuel, aucun effet
  // sur la résolution du combat, voir src/lib/battleAnimations.ts. NULL
  // (colonne vide ou libellé non reconnu) = 'jump_attack', le bond historique.
  animation: BattleAnimationId | null
  // Animation du SECOND tour des capacités en deux temps
  // (autobattle_ability_rules.turn_effect = 'prepare_release', colonne
  // "Animation 2" du CSV) : le tour de préparation joue `animation`, celui de
  // la libération joue celle-ci. NULL = `animation` est rejouée telle quelle.
  animation_2: BattleAnimationId | null
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
  'Mini-game status': string
  'Status probability': string
  'Inflige dégâts': string
  'Animation': string
  'Animation 2': string
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
export type ChatMessageType = 'text' | 'trade' | 'trade_completed'

export interface ChatMessage {
  id: number
  player_id: number
  content: string
  is_npc: boolean
  message_type: ChatMessageType
  trade_id: number | null
  created_at: string
}

// Accusé de lecture "Vu par" : dernier message vu par un joueur (une ligne par
// joueur). Les PNJ n'en ont jamais — seules les vraies sessions lisent le chat.
export interface ChatReadReceipt {
  player_id: number
  last_read_message_id: number
  updated_at: string
}

// ── Échanges entre joueurs (proposés/acceptés depuis le Chat) ─
export type TradeKind = 'item' | 'pokemon'
export type TradeStatus = 'pending' | 'completed' | 'cancelled'

export interface TradeItemEntry {
  item_nom: string
  quantity: number
}

export interface TradeItemsPayload {
  items: TradeItemEntry[]
}

export interface TradePokemonOfferPayload {
  player_pokemon_id: number
  // Dénormalisé au moment de la création (l'auteur a alors son propre roster
  // sous la main) pour permettre l'affichage de la carte d'échange (sprite,
  // surnom) sans avoir à charger le roster de l'autre joueur. Purement
  // cosmétique : trade_accept revalide tout depuis player_pokemon via l'id.
  pokemon_nom: string
  nickname: string | null
}

export interface TradePokemonRequestPayload {
  // null = "N'importe quel Pokémon non possédé" par le proposeur
  pokemon_nom: string | null
}

export interface Trade {
  id: number
  kind: TradeKind
  proposer_id: number
  status: TradeStatus
  offer: TradeItemsPayload | TradePokemonOfferPayload
  request: TradeItemsPayload | TradePokemonRequestPayload
  accepted_by: number | null
  resolved_at: string | null
  // Espèce/surnom effectivement cédés par l'acceptant côté Pokémon (voir
  // trade_accept en base) — null pour les échanges d'objets ou tant que
  // 'pending'. Sert à l'affichage du message de conclusion et au rejeu de
  // l'animation d'échange sans dépendre d'une instance qui a pu re-changer de main.
  resolved_pokemon_nom: string | null
  resolved_pokemon_nickname: string | null
  created_at: string
}

export type TradeAcceptStatus =
  | 'ok' | 'not_found' | 'already_resolved' | 'cannot_accept_own'
  | 'offer_no_longer_available' | 'insufficient_items'
  | 'no_pokemon_chosen' | 'not_owner' | 'wrong_species' | 'already_owned' | 'error'

export type TradeCancelStatus = 'ok' | 'not_found' | 'already_resolved' | 'not_proposer' | 'error'

export const TRADE_MAX_ITEMS = 3

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
  /** Combats gagnés par cette instance précise (pas l'espèce) — conservé à travers les évolutions, voir supabase/schema.sql. */
  battles_won: number
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
  feature_pvp_enabled: boolean
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
  // Système de précision (attacks.precision, 1-10, NULL = 10) désactivable
  // globalement — désactivé, toute capacité touche systématiquement.
  precision_enabled: boolean
  // Talents d'espèce (autobattle_talents) désactivables globalement, comme la
  // précision — désactivés, aucun talent n'est lu ni déclenché, y compris les
  // annonces d'ouverture de combat. Les configurations restent en base.
  talents_enabled: boolean
  // Icônes du mode de jeu affichées sur la bannière de chaque parcours
  // (AutoBattleVariantBanner) selon son game_mode — partagées par toutes les
  // variantes, réglées dans l'admin "Combat Auto — Général".
  mode_icon_auto_url: string
  mode_icon_manual_url: string
}

export interface AutoBattlePlayerState {
  player_id: number
  next_ticket_at: string | null
  purchase_count: number
  purchase_date: string | null
  ticket_full_notified: boolean
  created_at: string
}

// 'auto' = le joueur choisit UNE capacité avant le combat, tout se résout
// d'un coup (voir autobattle_resolve_battle). 'manual' = le joueur choisit
// une capacité à chaque tour (voir autobattle_resolve_manual_round).
export type AutoBattleGameMode = 'auto' | 'manual'

export interface AutoBattleVariant {
  id: number
  nom: string
  enabled: boolean
  icon_url: string
  banner_url: string
  sort_order: number
  game_mode: AutoBattleGameMode
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
  // Positions 2 à 10 de la séquence adverse (mode Manuel uniquement, voir
  // autobattle_resolve_manual_round) — l'adversaire les joue dans cet ordre,
  // en boucle. Ignorées en mode Auto (toujours opponent_ability_nom seule).
  opponent_ability_nom_2: string | null
  opponent_ability_nom_3: string | null
  opponent_ability_nom_4: string | null
  opponent_ability_nom_5: string | null
  opponent_ability_nom_6: string | null
  opponent_ability_nom_7: string | null
  opponent_ability_nom_8: string | null
  opponent_ability_nom_9: string | null
  opponent_ability_nom_10: string | null
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

// Effet spécial d'une capacité (voir autobattle_ability_rules) : effet sur le
// rythme des tours et/ou effet de soin, indépendants et tous deux optionnels.
// Le statut (voir AutoBattleStatusEffect ci-dessous) N'EST PAS ici : il vient
// directement du CSV des attaques (Attack.status_effect/status_chance), au
// même titre que degats_base/precision — pas une règle admin séparée (seul
// status_reversed, un réglage propre au mode de jeu, vit ici).
// prepare_release : la capacité se prépare au 1er tour (aucune action,
// texte "Préparation") puis s'utilise normalement au 2e.
// charge_double_next : la capacité ne fait rien au tour où elle est choisie
// (tour de "charge") ; au tour SUIVANT, son utilisateur agit deux fois de
// suite sans que l'adversaire n'intervienne entre les deux — en Combat
// Manuel/PvP il choisit une capacité différente pour chacune des deux
// actions, en Combat Auto (capacité fixe) c'est deux fois la même.
// first_and_replay : la capacité s'utilise normalement mais ne "consomme"
// pas le tour — son utilisateur rejoue immédiatement (nouveau choix) et
// prend la main en premier pour la suite du combat. Ce dernier volet n'a de
// sens qu'en Combat Manuel/PvP, où l'ordre des tours est persisté (en Combat
// Auto l'ordre est une stricte alternance, l'effet se réduit à "joue deux
// fois"). Voir supabase/schema.sql.
export type AutoBattleTurnEffect = 'skip' | 'play_twice' | 'play_three' | 'play_random' | 'repeat_until_fail' | 'prepare_release' | 'charge_double_next' | 'first_and_replay'
// Bonus cumulatif de la chaîne "Continue sur sa lancée" (voir
// AutoBattleAbilityRule.keep_going_turns) : montant fixe, ou pourcentage des
// dégâts de base du POKÉMON (espèce + bonus XP seuls, sans les dégâts propres
// de la capacité ni le x2 d'efficacité de type). Appliqué une fois par réutilisation
// (rien à la 1ère, ×1 à la 2e, ×2 à la 3e...).
export type AutoBattleKeepGoingBonusType = 'flat' | 'percent_damage'
// Statut bloquant qu'une capacité peut ignorer (voir
// AutoBattleAbilityRule.ignore_status_block) : un seul à la fois, et
// uniquement parmi les trois qui font passer le tour — la brûlure et le
// poison n'ont jamais bloqué quoi que ce soit, la peur et la confusion se
// contentent de réduire la précision.
export type AutoBattleIgnoreStatusBlock = Extract<AutoBattleStatusEffect, 'paralysis' | 'sleep' | 'frozen'>
export type AutoBattleHealType = 'static' | 'percent_damage' | 'use_stats'
// Type de montant du soin passif (heal_dot, voir heal_dot_amount/heal_dot_percent
// ci-dessous) : 'flat' (ou NULL, valeur historique) = montant fixe par tour ;
// 'percent_max_hp' = % des PV MAX de son utilisateur ; 'percent_damage' = % des
// dégâts infligés par le coup qui a accordé l'effet. Résolu en un entier fixe
// une seule fois à l'octroi, jamais recalculé à chaque tick.
export type AutoBattleHealDotType = 'flat' | 'percent_max_hp' | 'percent_damage'
// paralysis/frozen : passe le prochain tour, une seule fois. fear/confusion :
// précision réduite de 3/5 au prochain tour, une seule fois. sleep : passe
// son tour tant qu'un dé à 6 faces ne tombe pas sur 4/5/6 (relancé à chaque
// tour). burn : 5 dégâts passifs par tour jusqu'à un dé à 4/5/6. poison : 3
// dégâts passifs par tour jusqu'à ce que ce camp soit soigné, quel que soit
// le moyen. Voir autobattle_resolve_battle pour l'implémentation complète.
export type AutoBattleStatusEffect = 'paralysis' | 'fear' | 'confusion' | 'sleep' | 'burn' | 'poison' | 'frozen'
// 'range' tire un montant entre min/max à chaque coup réussi (un montant
// "fixe" est juste un range avec min=max) ; 'percent_damage' prend un % des
// dégâts (bonus inclus) infligés ce coup-là — dans les deux cas, dégâts sur
// l'utilisateur lui-même, après tout le reste.
export type AutoBattleRecoilType = 'range' | 'percent_damage'
// Dégâts additionnels appliqués après le dé si la condition associée est
// vérifiée : 'multiply' multiplie le total, 'flat' ajoute un montant fixe,
// 'range' ajoute un montant tiré entre min/max.
export type AutoBattleBonusDamageType = 'multiply' | 'flat' | 'range'
// took_damage_last_turn : ce camp a été touché par l'adversaire depuis son
// propre dernier tour. first_use : 1ère fois que ce camp attaque dans le
// combat. dice_equals : le dé de dégâts de CETTE capacité est tombé sur
// bonus_damage_condition_dice_value. has_status : l'ADVERSAIRE est
// actuellement affecté par un statut. self_has_status : c'est L'UTILISATEUR
// de la capacité qui l'est (frapper plus fort en étant soi-même empoisonné,
// brûlé…). Ces deux dernières partagent bonus_damage_status_filter, qui
// restreint la condition à un statut précis (NULL = n'importe lequel).
export type AutoBattleBonusDamageCondition = 'took_damage_last_turn' | 'first_use' | 'dice_equals' | 'has_status' | 'self_has_status'
// Modificateur de stat (dégâts de base ou précision) — 'opponent' = débuff
// (appliqué à l'adversaire du lanceur), 'self' = buff (appliqué au lanceur
// lui-même) : le sens (hausse/baisse) découle directement de la cible, pas
// un champ séparé. 'percent' n'est valable que pour stat = 'damage' (la
// précision n'a pas d'équivalent "stat de base" en %, voir requirement).
// Les modificateurs se CUMULENT : chaque application s'empile avec sa propre
// échéance, donc deux "+2 dégâts pendant 3 tours" joués coup sur coup donnent
// +4, puis retombent à +2 quand le plus ancien expire. Chaque application dure
// soit stat_mod_duration_turns tours de COMBAT (compteur global, pas propre à
// un camp), soit jusqu'à la fin du combat.
// stat_mod_max_uses plafonne le nombre d'applications RÉUSSIES (un raté ne
// compte pas) sur tout le combat — au-delà, la capacité continue de
// s'utiliser normalement mais n'applique plus le modificateur (voir
// AutoBattleTurn.stat_mod_limit_reached).
export type AutoBattleStatModTarget = 'self' | 'opponent'
export type AutoBattleStatModStat = 'damage' | 'precision'
export type AutoBattleStatModValueType = 'flat' | 'range' | 'percent'
export type AutoBattleStatModDurationType = 'turns' | 'battle_end'
export interface AutoBattleAbilityRule {
  attack_nom: string
  turn_effect: AutoBattleTurnEffect | null
  turn_random_min: number | null
  turn_random_max: number | null
  repeat_max_iterations: number | null
  heal_type: AutoBattleHealType | null
  heal_amount: number | null
  heal_percent: number | null
  status_reversed: boolean
  recoil_type: AutoBattleRecoilType | null
  recoil_min: number | null
  recoil_max: number | null
  recoil_percent: number | null
  invulnerable_next_turn: boolean
  bonus_damage_type: AutoBattleBonusDamageType | null
  bonus_damage_multiplier: number | null
  bonus_damage_flat: number | null
  bonus_damage_min: number | null
  bonus_damage_max: number | null
  bonus_damage_condition: AutoBattleBonusDamageCondition | null
  bonus_damage_condition_dice_value: number | null
  // Ne s'applique qu'aux conditions 'has_status' / 'self_has_status' : NULL =
  // "n'importe quel statut" (comportement historique), sinon la condition
  // n'est vérifiée que pour ce statut précis.
  bonus_damage_status_filter: AutoBattleStatusEffect | null
  stat_mod_target: AutoBattleStatModTarget | null
  stat_mod_stat: AutoBattleStatModStat | null
  stat_mod_value_type: AutoBattleStatModValueType | null
  stat_mod_flat: number | null
  stat_mod_min: number | null
  stat_mod_max: number | null
  stat_mod_percent: number | null
  stat_mod_duration_type: AutoBattleStatModDurationType | null
  stat_mod_duration_turns: number | null
  stat_mod_max_uses: number | null
  // Soin passif ("heal over time") : accordé à son utilisateur sur un coup
  // réussi, tick à chaque début de son propre tour pendant
  // heal_dot_duration_turns tours de combat (compteur global, comme
  // stat_mod_duration_turns) — indépendant du soin instantané (heal_type
  // ci-dessus), les deux peuvent coexister sur la même capacité. Bloqué par
  // un Anti-Soin adverse actif (cancel_heal_duration_turns), voir plus bas.
  // heal_dot_type = 'flat' (ou NULL) : heal_dot_amount PV par tour, fixe.
  // heal_dot_type = 'percent_max_hp'/'percent_damage' : heal_dot_percent %
  // (des PV max, ou des dégâts infligés par le coup qui a accordé l'effet) —
  // dans ce cas heal_dot_amount reste NULL, voir AutoBattleHealDotType.
  heal_dot_type: AutoBattleHealDotType | null
  heal_dot_amount: number | null
  heal_dot_percent: number | null
  heal_dot_duration_turns: number | null
  // Anti-Soin : sur un coup réussi, annule TOUS les effets de soin de
  // l'adversaire (heal_type instantané, heal_dot, guérison du poison par un
  // soin) pendant cancel_heal_duration_turns tours de combat.
  cancel_heal_duration_turns: number | null
  // Dégâts en % des PV restants (comme Super Fang) : remplace ENTIÈREMENT le
  // calcul de dégâts habituel par floor(PV actuels de la cible AVANT ce coup
  // × percent_hp_damage_percent / 100) — les dégâts additionnels
  // conditionnels/contre-coup/soin s'appliquent ensuite normalement sur ce
  // total. NULL = désactivé.
  percent_hp_damage_percent: number | null
  // Filtre de TYPE du modificateur de stat ci-dessus (uniquement pour
  // stat_mod_stat = 'damage') : NULL = s'applique à toutes les capacités,
  // sinon uniquement à celles de ce type élémentaire (attacks.type). Permet
  // un buff du genre "+10 dégâts sur les capacités Feu".
  stat_mod_type_filter: string | null
  // Bouclier "Prévention" : sur un coup réussi, protège son utilisateur des
  // dégâts ADDITIONNELS dus à l'efficacité de type (super efficace) pendant
  // ce nombre de tours de combat — les coups adverses touchent toujours,
  // mais sans leur bonus de type. NULL = désactivé.
  prevention_duration_turns: number | null
  // "Continue sur sa lancée" : la capacité est automatiquement rejouée
  // pendant keep_going_turns tours supplémentaires de son utilisateur (choix
  // verrouillé côté client, voir AutoBattleManualRoundResult.
  // player_forced_ability_nom), avec un bonus de dégâts cumulatif à chaque
  // réutilisation (la 1ère utilisation n'en a aucun). La chaîne s'interrompt au
  // premier raté, ou au premier tour passé à cause d'un statut bloquant
  // (paralysie/gel/sommeil) : la capacité cesse alors d'être imposée.
  // Deux durées possibles, exclusives : keep_going_turns = N réutilisations
  // forcées, ou keep_going_until_fail = rejeu illimité (une fois par tour)
  // jusqu'au premier raté, sans plafond sur le bonus cumulatif.
  keep_going_turns: number | null
  keep_going_until_fail: boolean
  keep_going_bonus_type: AutoBattleKeepGoingBonusType | null
  keep_going_bonus_flat: number | null
  keep_going_bonus_percent: number | null
  // Soin passif "jusqu'au réveil" : au lieu de heal_dot_duration_turns
  // (NULL dans ce cas), l'effet dure tant que son utilisateur est ENDORMI et
  // s'arrête au tour de son réveil.
  heal_dot_until_awake: boolean
  // Capacité utilisable malgré UN statut bloquant précis (genre "Ronflement",
  // utilisable en dormant mais pas en étant paralysé) : null = désactivé, sinon
  // le statut concerné — les deux autres continuent de faire passer le tour.
  // Le tick de statut a lieu normalement dans tous les cas.
  ignore_status_block: AutoBattleIgnoreStatusBlock | null
  created_at: string
}

// ── Talents (effets passifs PAR ESPÈCE, table autobattle_talents) ────────────
// Pendant par ESPÈCE d'AutoBattleAbilityRule (qui est par CAPACITÉ) : un talent
// s'applique quelle que soit la capacité jouée, dans TOUS les modes de combat
// et pour LES DEUX camps. Édités depuis AdminAutoBattleTalentsPanel, appliqués
// exclusivement côté serveur (voir les helpers autobattle_talent_* dans
// supabase/schema.sql) — le client ne fait que rejouer les tours talent_tick.
export type AutoBattleTalentKind =
  | 'stat_boost'
  | 'absorb_first_damage'
  | 'endure_ko'
  | 'poison_damage_boost'
  | 'burn_damage_boost'
  | 'priority'
  | 'inflict_status'
  | 'status_immunity'
  | 'type_immunity'
  | 'type_damage_to_heal'
  | 'no_recoil'
  | 'dice_bonus_damage'
  | 'auto_cure_first_status'
  | 'invulnerable_until_hit'
  | 'heal_below_hp'
  /** Copie l'adversaire (sprite, type, super efficace, dégâts de base, movepool) — anciennement le cas spécial « Métamorph », codé en dur sur le nom d'espèce. Sans effet en PvP. */
  | 'transform'
  /** « Somnolent » : endormi, il lui faut un 6 exact au dé pour se réveiller (au lieu de 4, 5 ou 6). */
  | 'heavy_sleeper'

export type AutoBattleTalentStat = 'damage' | 'precision'
export type AutoBattleTalentValueType = 'flat' | 'percent_max_hp' | 'range'
export type AutoBattleTalentHpCondition = 'below' | 'above'
/**
 * Quand un 'inflict_status' tente de s'appliquer. 'on_ability_type' exige un
 * COUP DIRECT qui a porté (capacité offensive, non ratée, dégâts non nuls) ;
 * 'each_turn' se tente avant la capacité, qu'elle touche ou non.
 */
export type AutoBattleTalentTrigger = 'battle_start' | 'each_turn' | 'on_ability_type'
/** Condition « statut » d'un bonus de stat : 'any' = n'importe lequel. */
export type AutoBattleTalentStatusCondition = 'any' | AutoBattleStatusEffect

// Une ligne d'autobattle_talents. Colonnes volontairement mutualisées entre les
// kinds (voir le commentaire de la table) : `amount`/`amount_max`/`percent`/
// `value_type` portent la valeur, `type_filter`/`status_filter` les listes, le
// reste les conditions. Seul un sous-ensemble est pertinent par kind.
export interface AutoBattleTalent {
  id: number
  pokemon_nom: string
  /** Libellé affiché en combat, prérempli depuis pokemon.nom_talent à la création. */
  nom: string
  kind: AutoBattleTalentKind
  /** Animation jouée sur le pokémon au déclenchement — null = 'idle'. */
  animation: BattleAnimationId | null
  stat: AutoBattleTalentStat | null
  /** Montant signé (bonus de stat, priorité, dégâts de tick, soin plat, min d'une fourchette). */
  amount: number | null
  amount_max: number | null
  /** % (soin en % des PV max, chance d'infliger un statut). */
  percent: number | null
  value_type: AutoBattleTalentValueType | null
  /** Types de capacité (bonus de stat) ou de dégâts (immunité, conversion en soin). */
  type_filter: string[] | null
  status_filter: AutoBattleStatusEffect[] | null
  hp_condition: AutoBattleTalentHpCondition | null
  /** Seuil en % des PV max — condition d'un bonus de stat, ou déclencheur de 'heal_below_hp'. */
  hp_percent: number | null
  opponent_status: AutoBattleTalentStatusCondition | null
  self_status: AutoBattleTalentStatusCondition | null
  /** Bonus CUMULATIF : multiplié par le nombre de coups DIRECTS encaissés — la brûlure et le poison ne comptent pas. */
  require_damage_taken: boolean
  trigger: AutoBattleTalentTrigger | null
  dice_value: number | null
  created_at: string
}

// Un tour du journal de combat renvoyé par le RPC autobattle_resolve_battle —
// le client se contente de rejouer cette séquence (jamais recalculée côté
// client). skipped = le camp a passé son tour sans attaquer (effet spécial
// 'skip'/'prepare_release' OU statut paralysie/gel/sommeil raté) ; preparing
// = 1er tour de 'prepare_release' (texte "Préparation", jamais de dégâts) ;
// missed = l'attaque a raté (système de précision) ; invulnerable_miss =
// l'attaque a raté car la cible était invulnérable ce tour-là (pas un raté
// de précision normal, texte distinct côté client) ; heal/attacker_hp_after
// ne sont présents que si l'attaquant s'est soigné ce tour-là ; recoil =
// dégâts de contre-coup sur l'attaquant lui-même (attacker_hp_after reflète
// alors l'état final, après soin ET contre-coup le cas échéant) ;
// invulnerable_granted = ce coup a rendu son auteur invulnérable au prochain
// tour adverse. status_applied = un coup réussi a infligé ce statut —
// normalement à l'adversaire, à l'attaquant lui-même si
// status_applied_reversed. status_cured_by_heal = le poison de l'attaquant a
// été guéri par son propre soin ce tour-là. status_tick = ce tour est un
// "tick" de statut (dé lancé pour sleep/burn — status_roll —, dégâts passifs
// pour burn/poison dans `damage`/`attacker_hp_after`, statut levé ou non
// dans status_cured) — toujours sur turn.attacker, le camp affecté par son
// propre statut.
export interface AutoBattleTurn {
  turn: number
  attacker: 'player' | 'opponent'
  damage: number
  /** damage AVANT le dé (espèce + bonus XP + multiplicateur type + dégâts de base de la capacité) — fourni PAR TOUR, fiable en Combat Manuel où l'ability change à chaque round (contrairement à AutoBattleScreenProps.playerDamagePerHit/opponentDamagePerHit, figés pour tout le combat). Absent sur les coups ratés/statuts (non pertinent). */
  damage_before_dice?: number
  /** Composante espèce+XP seule, AVANT le multiplicateur de type — permet de reconstruire le détail complet du calcul en admin (ex. "10 (dégâts de base) x2 (super efficace) + 4 (dégâts de la capacité) + 4 (dé) = 28"), voir AutoBattleScreen. */
  damage_species_xp?: number
  /** Résultat du dé de dégâts (0 si la capacité n'en a pas) — distinct de damage_before_dice/damage pour isoler ce terme dans le détail du calcul. */
  damage_dice?: number
  defender_hp_after: number
  ko: boolean
  skipped?: boolean
  preparing?: boolean
  missed?: boolean
  invulnerable_miss?: boolean
  invulnerable_granted?: boolean
  /** Modificateur de précision (buff/debuff, voir AutoBattleAbilityRule.stat_mod_stat = 'precision') actif sur l'ATTAQUANT au moment de ce tour — déjà signé (négatif = malus), 0 si aucun actif. Absent sur les coups où la précision n'entre pas en jeu (statuts, invulnérabilité...). Permet de reconstruire le détail complet en debug admin (voir AutoBattleScreen), au même titre que damage_species_xp pour les dégâts. */
  precision_mod_amount?: number
  heal?: number
  recoil?: number
  attacker_hp_after?: number
  status_applied?: AutoBattleStatusEffect
  status_applied_reversed?: boolean
  status_cured_by_heal?: boolean
  status_tick?: boolean
  status?: AutoBattleStatusEffect
  status_roll?: number | null
  status_cured?: boolean
  // stat_mod_applied = un coup réussi a (ré)appliqué le modificateur de stat
  // de cette capacité — sur turn.attacker (target='self') ou sur l'autre
  // camp (target='opponent'), voir amount (déjà signé : négatif = baisse,
  // positif = hausse). stat_mod_limit_reached = ce coup aurait dû appliquer
  // le modificateur mais stat_mod_max_uses est déjà épuisé (aucun effet ce
  // tour-là). heal_dot_tick = ce tour est un tick de soin passif (comme
  // status_tick, mais soigne au lieu de blesser — montant dans `heal`,
  // toujours sur turn.attacker). heal_dot_granted = ce coup réussi a
  // (ré)accordé le soin passif de cette capacité à son utilisateur.
  // cancel_heal_applied = ce coup réussi a activé l'Anti-Soin sur
  // l'adversaire. heal_blocked = un soin (instantané ou passif) aurait dû
  // s'appliquer ce tour-là mais a été annulé par l'Anti-Soin adverse actif.
  stat_mod_applied?: { target: AutoBattleStatModTarget; stat: AutoBattleStatModStat; amount: number; duration_type: AutoBattleStatModDurationType }
  stat_mod_limit_reached?: boolean
  heal_dot_tick?: boolean
  heal_dot_granted?: boolean
  cancel_heal_applied?: boolean
  heal_blocked?: boolean
  // percent_hp_damage = les dégâts de ce coup viennent du calcul "% des PV
  // restants" (voir AutoBattleAbilityRule.percent_hp_damage_percent) plutôt
  // que du calcul habituel dégâts de base + dé.
  percent_hp_damage?: boolean
  // charging = tour de "charge" de turn_effect 'charge_double_next' (aucun
  // effet, comme `preparing`, mais annonce un DOUBLE tour à venir).
  // prevention_granted = ce coup réussi a accordé le bouclier Prévention à
  // son auteur. prevention_blocked = ce coup a perdu son bonus super efficace
  // à cause du bouclier Prévention de la cible. keep_going_bonus = part des
  // dégâts venant du bonus cumulatif de la chaîne "Continue sur sa lancée".
  charging?: boolean
  prevention_granted?: boolean
  prevention_blocked?: boolean
  keep_going_bonus?: number
  // talent_tick = ce tour est un déclenchement de TALENT d'espèce (voir
  // autobattle_talents) : `attacker` désigne le camp PROPRIÉTAIRE du talent,
  // pas un attaquant, et defender_hp_after n'a pas de sens (il reprend les PV
  // du propriétaire). Le client resynchronise les PV sur attacker_hp_after —
  // indispensable pour 'endure_ko' (remonte à 1 PV) et 'heal_below_hp'.
  // talent_animation = animation à jouer sur le pokémon lui-même (NULL =
  // 'idle') ; talent_detail = phrase prête à afficher dans l'historique ;
  // talent_absorbed = dégâts annulés ou convertis en soin le cas échéant.
  talent_tick?: boolean
  talent_nom?: string
  talent_kind?: AutoBattleTalentKind
  talent_animation?: BattleAnimationId | null
  talent_detail?: string
  talent_absorbed?: number
  /** Statut infligé à l'ADVERSAIRE du porteur par un talent 'inflict_status' — un tour de talent n'étant pas un tour d'attaque, il ne passe pas par status_applied, mais le badge doit quand même apparaître. */
  talent_inflicted_status?: AutoBattleStatusEffect
  // Décoration CLIENT UNIQUEMENT (jamais renvoyée par le serveur) — voir
  // ManualBattleScreen : en Combat Manuel la capacité change à chaque tour,
  // contrairement au Combat Auto où elle est fixe (playerAbilityNom/
  // opponentAbilityNom, props de AutoBattleScreen) ; ManualBattleScreen tague
  // chaque tour avec la capacité effectivement jouée ce tour-là avant de
  // l'ajouter au tableau `turns` cumulatif passé à AutoBattleScreen, qui la
  // préfère à ses props fixes quand présente (voir sideInfo).
  ability_nom?: string
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
  /** Cas Métamorph (pokémon du joueur) : sprite de l'adversaire copié pour ce combat (voir autobattle_resolve_battle) — jamais présent sinon. */
  player_image_override?: string | null
  /** Cas Métamorph (pokémon du joueur) : capacité réellement jouée (celle de l'adversaire, copiée), différente de celle choisie dans le picker. */
  player_ability_nom_override?: string | null
  /** Cas Métamorph configuré comme ADVERSAIRE d'un niveau : sprite du joueur copié pour ce combat — jamais présent sinon. */
  opponent_image_override?: string | null
  /** Cas Métamorph adversaire : capacité réellement jouée (celle du joueur, copiée), différente de celle configurée sur le niveau. */
  opponent_ability_nom_override?: string | null
}

export type AutoBattleManualRoundStatus = AutoBattleResolveStatus | 'wrong_mode' | 'not_started'

// Réponse du RPC autobattle_start_manual_battle (voir supabase/schema.sql) —
// crée la ligne autobattle_manual_battles et tire au sort first_attacker
// AVANT que le joueur choisisse sa 1ère capacité, pour permettre d'afficher
// le tirage au sort (AutoBattleCoinToss) juste après le choix du pokémon —
// ne débite PAS de ticket (voir autobattle_resolve_manual_round, qui s'en
// charge au 1er tour réellement joué).
export interface AutoBattleStartManualBattleResult {
  status: AutoBattleManualRoundStatus
  first_attacker?: 'player' | 'opponent'
  /**
   * Tours de talent joués à l'OUVERTURE du combat (talent_tick, turn = 0) :
   * passifs permanents annoncés et statuts infligés « à l'entrée en combat ».
   * Résolus ici plutôt qu'au 1er round pour que leur animation passe AVANT la
   * première sélection de capacité (voir ManualBattleScreen.startTurns).
   */
  turns?: AutoBattleTurn[]
}

// Réponse du RPC autobattle_resolve_manual_round (voir supabase/schema.sql) —
// résout UN SEUL tour (voir AutoBattleTurn) — mais un "tour" y couvre un
// tour complet des DEUX camps, rafales/passes/préparations comprises (voir
// autobattle_ability_rules.turn_effect, pleinement actif en mode Manuel) —
// pas le combat entier. turns ne contient que les entrées NOUVELLES de ce
// tour, à concaténer côté client à la suite du journal déjà affiché plutôt
// qu'à le remplacer. Métamorph (joueur OU adversaire) copie sprite/type/
// liste super efficace/dégâts de base du côté adverse — seuls les PV max et
// le nom restent les siens propres (voir requirement dédié) ; ADVERSAIRE
// copie tout le movepool du joueur et pioche au hasard dedans à chaque
// nouveau tour, JOUEUR copie l'ensemble des capacités CONFIGURÉES sur le
// niveau adverse (le joueur choisit toujours laquelle jouer, contrairement à
// l'adversaire).
export interface AutoBattleManualRoundResult {
  status: AutoBattleManualRoundStatus
  turn_no?: number
  first_attacker?: 'player' | 'opponent'
  player_hp?: number
  player_max_hp?: number
  opponent_hp?: number
  opponent_max_hp?: number
  player_damage_per_hit?: number
  opponent_damage_per_hit?: number
  player_type_bonus?: boolean
  opponent_type_bonus?: boolean
  turns?: AutoBattleTurn[]
  outcome?: 'win' | 'lose'
  rewards?: AutoBattleReward[]
  variant_completed?: boolean
  next_level_index?: number
  opponent_pokemon_nom?: string
  /** Capacité effectivement jouée par l'adversaire CE tour (séquence à jusqu'à 10 positions, voir autobattle_levels.opponent_ability_nom_2..10, ou piochée dans le movepool du joueur si Métamorph) — pas forcément la même d'un tour à l'autre. */
  opponent_ability_nom?: string
  /** Capacité jouée par le joueur ce tour (= p_ability_nom envoyé, sauf capacité forcée — voir player_forced_ability_nom) — renvoyée pour simplifier l'affichage/historique côté client. */
  player_ability_nom?: string
  /** Capacité IMPOSÉE au joueur pour le prochain tour (préparation en cours, tour passé imposé par l'effet 'skip', ou chaîne "Continue sur sa lancée" encore active) — le client verrouille alors sa grille de sélection dessus au lieu de la deviner. null/absent = choix libre. */
  player_forced_ability_nom?: string | null
  /** Cas Métamorph ADVERSAIRE : sprite du joueur copié pour ce combat — jamais présent sinon. */
  opponent_image_override?: string | null
  /** Cas Métamorph JOUEUR : sprite de l'adversaire copié pour ce combat — jamais présent sinon. */
  player_image_override?: string | null
}

// ── Défi PvP (bannières de défi joueur contre joueur) ─────────
// Gratuit, sans milestone, tentatives illimitées — voir supabase/schema.sql
// pour le détail du moteur (pvp_resolve_round délègue au même moteur partagé
// que Combat Auto en mode Manuel, autobattle_resolve_round_core).
export interface PvpConfig {
  id: number
  nom: string
  icon_url: string
  precision_enabled: boolean
  // Voir AutoBattleConfig.talents_enabled — même bascule, propre au mode JcJ
  // (elle couvre aussi le combat d'essai "Tester").
  talents_enabled: boolean
  // Nombre maximum de capacités dans la boucle défensive d'un défi — les
  // doublons comptent (voir PvpAbilityLoadoutPicker, pvp_post_challenge).
  loadout_max: number
  // Adversaire d'entraînement du bouton "Tester" (voir PvpTrialBattleScreen,
  // pvp_trial_start) — vide tant que non configuré par l'admin, auquel cas
  // "Tester" est désactivé côté client (statut 'trial_not_configured').
  trial_pokemon_nom: string
  trial_hp: number
  trial_ability_nom: string
  // Bannières décoratives optionnelles (image via URL, voir GameBanner) au-
  // dessus des titres "Champion Actuel"/"Challengers" dans le popup — vide
  // par défaut, purement cosmétique.
  champion_banner_url: string
  challengers_banner_url: string
}

// Un défi = un instantané FIGÉ (espèce + PV/dégâts dérivés de l'XP au moment
// du dépôt + jusqu'à pvp_config.loadout_max capacités DANS L'ORDRE, doublons
// autorisés) posé par un joueur en tant que défenseur — voir
// pvp_post_challenge. Le pokémon réel (source_player_pokemon_id) n'est
// jamais bloqué et continue d'être utilisable normalement ailleurs.
export interface PvpChallenge {
  id: number
  defender_player_id: number
  source_player_pokemon_id: number
  pokemon_nom: string
  pokemon_numero: string | null
  nickname: string | null
  xp: number
  max_hp: number
  damage_species_xp: number
  ability_noms: string[]
  active: boolean
  withdrawn_at: string | null
  created_at: string
  // Titre de Champion (voir pvp_promote_to_champion) : au plus un défi actif
  // à la fois porte is_champion = true — une promotion crée TOUJOURS une
  // NOUVELLE ligne (jamais un flip en place, voir schema.sql), donc
  // created_at sert directement de "Champion depuis" côté client (voir
  // PvpChampionBanner).
  is_champion: boolean
}

// Une ligne par tentative résolue (gagnée ou perdue) — le tableau des scores
// affiché sous chaque bannière (voir PvpChallengeBanner), rattachée à
// l'INSTANCE de défi (challenge_id) : repart à zéro à chaque retrait/repose.
export interface PvpChallengeAttempt {
  id: number
  challenge_id: number
  defender_player_id: number
  attacker_player_id: number
  attacker_player_pokemon_id: number
  attacker_pokemon_nom: string
  outcome: 'win' | 'lose'
  // Nombre de tours (pas des secondes — jeu au tour par tour, voir
  // pvp_resolve_round) qu'il a fallu à l'attaquant pour gagner.
  duration_turns: number | null
  defender_hp_remaining: number | null
  created_at: string
}

export type PvpPostChallengeStatus = 'ok' | 'invalid_abilities' | 'ineligible_pokemon' | 'already_champion'
export interface PvpPostChallengeResult {
  status: PvpPostChallengeStatus
  challenge_id?: number
}

export type PvpWithdrawChallengeStatus = 'ok' | 'not_found' | 'not_owner' | 'already_withdrawn'

export type PvpStartBattleStatus = 'ok' | 'not_found' | 'challenge_inactive' | 'own_challenge' | 'ineligible_pokemon' | 'champion_requires_own_challenge'
export interface PvpStartBattleResult {
  status: PvpStartBattleStatus
  first_attacker?: 'player' | 'opponent'
  /** Voir AutoBattleStartManualBattleResult.turns — tours de talent d'ouverture. */
  turns?: AutoBattleTurn[]
}

export type PvpRoundStatus = PvpStartBattleStatus | 'ineligible_ability' | 'not_started'

// Réponse du RPC pvp_resolve_round — mêmes champs qu'AutoBattleManualRoundResult
// à dessein ('player' = l'attaquant, 'opponent' = le défenseur figé) pour que
// ManualBattleScreen/AutoBattleScreen soient réutilisés côté client tels
// quels, sans aucune modification (voir PvpPopup). Pas de rewards/
// variant_completed/next_level_index (mode gratuit, sans progression).
export interface PvpResolveRoundResult {
  status: PvpRoundStatus
  turn_no?: number
  first_attacker?: 'player' | 'opponent'
  player_hp?: number
  player_max_hp?: number
  opponent_hp?: number
  opponent_max_hp?: number
  player_damage_per_hit?: number
  opponent_damage_per_hit?: number
  player_type_bonus?: boolean
  opponent_type_bonus?: boolean
  turns?: AutoBattleTurn[]
  outcome?: 'win' | 'lose'
  opponent_pokemon_nom?: string
  opponent_ability_nom?: string
  player_ability_nom?: string
  /** Voir AutoBattleManualRoundResult.player_forced_ability_nom — même champ, même usage côté client. */
  player_forced_ability_nom?: string | null
}

// ── Mode "Tester" (combat d'essai gratuit contre un pantin configuré en
// admin, voir PvpTrialBattleScreen/pvp_trial_start/pvp_trial_resolve_round)
export type PvpTrialStartStatus = 'ok' | 'invalid_abilities' | 'ineligible_pokemon' | 'trial_not_configured'
export interface PvpTrialStartResult {
  status: PvpTrialStartStatus
  first_attacker?: 'player' | 'opponent'
  /** Voir AutoBattleStartManualBattleResult.turns — tours de talent d'ouverture. */
  turns?: AutoBattleTurn[]
}

export type PvpTrialRoundStatus = PvpTrialStartStatus | 'not_started' | 'not_found' | 'ineligible_ability'

// Même forme qu'AutoBattleManualRoundResult/PvpResolveRoundResult à dessein
// (voir leurs commentaires) — les deux camps cyclent automatiquement côté
// serveur, aucune capacité choisie interactivement ici.
export interface PvpTrialRoundResult {
  status: PvpTrialRoundStatus
  turn_no?: number
  first_attacker?: 'player' | 'opponent'
  player_hp?: number
  player_max_hp?: number
  opponent_hp?: number
  opponent_max_hp?: number
  player_damage_per_hit?: number
  opponent_damage_per_hit?: number
  player_type_bonus?: boolean
  opponent_type_bonus?: boolean
  turns?: AutoBattleTurn[]
  outcome?: 'win' | 'lose'
  opponent_pokemon_nom?: string
  opponent_ability_nom?: string
  player_ability_nom?: string
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
export type HistoryCategory = 'inventory' | 'pokedex' | 'team' | 'combat' | 'minigame' | 'daycare' | 'safari' | 'autobattle' | 'chat' | 'pvp'

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
  | 'pvp_challenge_posted'    // défi PvP posté
  | 'pvp_challenge_withdrawn' // défi PvP retiré
  | 'pvp_attempt_win'   // tentative PvP remportée
  | 'pvp_attempt_lose'  // tentative PvP perdue
  | 'pvp_champion_crowned' // devient le nouveau Champion PvP (dépossède l'ancien)

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

// entry.player_id est TOUJOURS l'auteur de l'action (celui qui poste/retire/
// attaque) — defender_player_id désigne l'AUTRE joueur (le propriétaire du
// défi), absent uniquement sur pvp_challenge_posted/withdrawn où l'auteur EST
// le défenseur.
export interface HistoryPvpPayload {
  defender_player_id: number
  defender_pokemon_nom: string
  attacker_pokemon_nom?: string // présent seulement sur pvp_attempt_win/lose
  challenge_id: number
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
  | HistoryPvpPayload

export interface HistoryEvent {
  id: number
  player_id: number
  category: HistoryCategory
  action_type: HistoryActionType
  payload: HistoryPayload
  created_at: string
}
