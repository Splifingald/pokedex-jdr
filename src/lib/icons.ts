// Icônes pixel-art custom (public/website_icons/) — remplacent les emojis
// pour les zones où un asset dédié existe.
const BASE = '/website_icons'

export const NAV_ICON: Partial<Record<string, string>> = {
  accueil: `${BASE}/icon_navbar_home.png`,
  pokedex: `${BASE}/icon_navbar_pokedex.png`,
  equipe: `${BASE}/icon_navbar_team.png`,
  sac: `${BASE}/icon_navbar_bag.png`,
  carte: `${BASE}/icon_navbar_map.png`,
  attaques: `${BASE}/icon_navbar_abilities.png`,
  campagne: `${BASE}/icon_navbar_journal.png`,
  admin: `${BASE}/icon_navbar_admin.png`,
  rencontres: `${BASE}/icon_navbar_encounters.png`,
}

export const STAT_ICON = {
  hp: `${BASE}/icon_stat_hp.png`,
  damage: `${BASE}/icon_stat_damage.png`,
  distance: `${BASE}/icon_stat_distance.png`,
  location: `${BASE}/icon_stat_location.png`,
  talent: `${BASE}/icon_stat_talent.png`,
  transport: `${BASE}/icon_stat_transport.png`,
  abilities: `${BASE}/icon_stat_abilities.png`,
  catchrate: `${BASE}/icon_stat_catchrate.png`,
  supereffective: `${BASE}/icon_stat_supereffective.png`,
}

export const STATUS_ICON = {
  paralysie: `${BASE}/icon_status_paralysed.png`,
  apeure: `${BASE}/icon_status_afraid.png`,
  confusion: `${BASE}/icon_status_confused.png`,
  endormi: `${BASE}/icon_status_asleep.png`,
  brule: `${BASE}/icon_status_burned.png`,
  empoisonne: `${BASE}/icon_status_poisoned.png`,
  gele: `${BASE}/icon_status_frozen.png`,
  ko: `${BASE}/icon_status_KO.png`,
}

export const SETTINGS_ICON = `${BASE}/icon_settings.png`
export const SAVE_ICON = `${BASE}/icon_save.png`
export const PC_ICON = `${BASE}/icon_pokemon_box.png`
export const GIFT_ICON = `${BASE}/image_pokemon_gift.png`
