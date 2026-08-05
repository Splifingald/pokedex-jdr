import type { PlayerPokemon, MinigamesConfig } from '../types'

// Sélectionne l'instance de Magicarpe (par numero, pas par nom — résilient aux
// surnoms/réimports CSV) avec le plus d'XP. Retourne null si le joueur n'en possède aucune.
export function selectBestMagikarp(
  roster: PlayerPokemon[],
  targetNumero: string
): PlayerPokemon | null {
  const candidates = roster.filter((pp) => pp.pokemon_numero === targetNumero)
  if (candidates.length === 0) return null
  return candidates.reduce((best, pp) => (pp.xp > best.xp ? pp : best))
}

export function ownsTargetSpecies(roster: PlayerPokemon[], targetNumero: string): boolean {
  return roster.some((pp) => pp.pokemon_numero === targetNumero)
}

// Le jeu Magikarp est jouable si activé côté admin ET le joueur possède l'espèce ciblée.
export function isMagikarpAvailable(
  config: Pick<MinigamesConfig, 'magikarp_enabled' | 'magikarp_numero'>,
  roster: PlayerPokemon[]
): boolean {
  return config.magikarp_enabled && ownsTargetSpecies(roster, config.magikarp_numero)
}

// Vrai si au moins un mini-jeu est actuellement jouable par le joueur — sert à
// masquer entièrement le bouton d'accueil quand la popup serait vide. Un futur
// 2e jeu ajoutera simplement sa propre condition ici (même logique que
// casino_config : chaque jeu a ses propres colonnes préfixées).
export function hasAnyMinigameAvailable(
  config: Pick<MinigamesConfig, 'magikarp_enabled' | 'magikarp_numero'>,
  roster: PlayerPokemon[]
): boolean {
  return isMagikarpAvailable(config, roster)
}

export type StarCount = 0 | 1 | 2 | 3

// Étoiles obtenues pour un score donné, à partir des 3 seuils admin (ordre croissant).
export function computeStars(
  score: number,
  config: Pick<MinigamesConfig, 'magikarp_star1_taps' | 'magikarp_star2_taps' | 'magikarp_star3_taps'>
): StarCount {
  if (score >= config.magikarp_star3_taps) return 3
  if (score >= config.magikarp_star2_taps) return 2
  if (score >= config.magikarp_star1_taps) return 1
  return 0
}

// XP à créditer pour un nombre d'étoiles donné.
export function xpForStars(
  stars: StarCount,
  config: Pick<MinigamesConfig, 'magikarp_star1_xp' | 'magikarp_star2_xp' | 'magikarp_star3_xp'>
): number {
  if (stars === 3) return config.magikarp_star3_xp
  if (stars === 2) return config.magikarp_star2_xp
  if (stars === 1) return config.magikarp_star1_xp
  return 0
}
