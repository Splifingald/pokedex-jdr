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

export const ABILITY_DISTANCE_ICON = `${BASE}/icon_ability_distance.png`

export const PHOTO_ICON = `${BASE}/icon_photo_pokemon.png`

export const SETTINGS_ICON = `${BASE}/icon_settings.png`
export const SAVE_ICON = `${BASE}/icon_save.png`
export const PC_ICON = `${BASE}/icon_pokemon_box.png`
export const GIFT_ICON = `${BASE}/image_pokemon_gift.png`

export const CASINO_ICON = {
  pokeball: `${BASE}/icon_casino_pokeball.png`,
  superball: `${BASE}/icon_casino_superball.png`,
  hyperball: `${BASE}/icon_casino_hyperball.png`,
  masterball: `${BASE}/icon_casino_masterball.png`,
  ticket: `${BASE}/icon_casino_ticket.png`,
}

export const CASINO_MASCOT_ICON = `${BASE}/icon_casino.png`

export const DISPLAY_ICON = `${BASE}/icon_navbar_display.png`

export const DICE_ICON: Record<number, string> = {
  1: `${BASE}/Dice_1.png`,
  2: `${BASE}/Dice_2.png`,
  3: `${BASE}/Dice_3.png`,
  4: `${BASE}/Dice_4.png`,
  5: `${BASE}/Dice_5.png`,
  6: `${BASE}/Dice_6.png`,
}

export const DICE_GENERIC_ICON = `${BASE}/icon_casino_dice.png`

export const MINIGAMES_ICON = `${BASE}/icon_magikarp_game.png`
export const MAGIKARP_JUMP_ICON = `${BASE}/icon_magikarp_jump.png`
export const MINIGAMES_TICKET_ICON = `${BASE}/icon_magikarp_ticket.png`

export const MINING_ICON = `${BASE}/icon_digging_game.png`
export const MINING_TICKET_ICON = `${BASE}/icon_digging_ticket.png`

export const PENSION_ICON = `${BASE}/icon_daycare_game.png`

export const SAFARI_ICON = `${BASE}/icon_safari_game.png`

export const AUTOBATTLE_ICON = `${BASE}/icon_battle_game.png`
export const AUTOBATTLE_TICKET_ICON = `${BASE}/icon_battle_ticket.png`
