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
}

export const CSV_REQUIRED_HEADERS: (keyof CsvRow)[] = [
  'Numéro', 'Nom', 'Type', 'Dégâts de base', 'PV de base',
  'Distance de déplacement en combat', 'Image miniature', 'Image illustrée',
]
