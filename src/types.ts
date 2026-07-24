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
  xp: number
  moves: string[]
  in_team: boolean
  created_at: string
}

export interface AdminParameters {
  id: number
  max_moves: number
  max_team_size: number
  carte_image_url: string
  carte_couleurs_image_url: string
}

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
