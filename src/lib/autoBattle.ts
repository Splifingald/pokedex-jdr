import type { Attack, PlayerPokemon, AutoBattleLevelReward } from '../types'

// Une capacité "offensive" est une capacité avec des dégâts de base strictement
// positifs (case vide en CSV = capacité de statut/effet, voir types.ts
// Attack.degats_base ; une capacité à 0 dégâts n'apporte rien en Combat Auto).
export function isDamagingAbility(attack: Attack): boolean {
  return attack.degats_base != null && attack.degats_base > 0
}

// Capacités offensives effectivement apprises par cette instance
// (playerPokemon.moves) — seules celles-ci sont sélectionnables en Combat
// Auto (voir AutoBattleAbilityPicker). Note : moves n'est PAS restreint au
// pool attaque_1..10 de l'espèce (voir PokemonDetailSheet.tsx où
// addableMoves propose tout le catalogue d'attaques, pas seulement celles de
// l'espèce) — il ne faut donc jamais recroiser avec ce pool ici.
export function getEligibleAbilities(
  playerMoves: string[],
  attacksByName: Map<string, Attack>
): Attack[] {
  return playerMoves
    .map((nom) => attacksByName.get(nom))
    .filter((a): a is Attack => a != null && isDamagingAbility(a))
}

// Pokémon du joueur pouvant participer à un combat : ni en pension, ni sans
// capacité offensive apprise (voir requirement #6/#9 du cahier des charges).
export function getEligiblePlayerPokemon(
  roster: PlayerPokemon[],
  attacksByName: Map<string, Attack>
): PlayerPokemon[] {
  return roster.filter((pp) => !pp.in_daycare && getEligibleAbilities(pp.moves, attacksByName).length > 0)
}

const REWARD_RANK: Record<AutoBattleLevelReward['reward_type'], number> = {
  badge: 0,
  item: 1,
  xp: 2,
}

// Ordonne les récompenses d'un niveau par importance décroissante (badge >
// objet > XP — les badges sont les plus rares/marquants, l'XP la plus
// "courante") : sert à choisir laquelle prévisualiser sur la bannière de
// progression quand un niveau a plusieurs récompenses (voir requirement #31).
export function rankRewardsBySignificance(rewards: AutoBattleLevelReward[]): AutoBattleLevelReward[] {
  return [...rewards].sort((a, b) => {
    const rankDiff = REWARD_RANK[a.reward_type] - REWARD_RANK[b.reward_type]
    if (rankDiff !== 0) return rankDiff
    return a.sort_order - b.sort_order
  })
}

export function pickBannerPreviewReward(rewards: AutoBattleLevelReward[]): AutoBattleLevelReward | null {
  const ranked = rankRewardsBySignificance(rewards)
  return ranked[0] ?? null
}

// Fenêtre de niveaux affichée sur la jauge de progression (niveau courant +
// les 3 suivants), recentrée automatiquement s'il reste moins de 4 niveaux à
// venir — voir requirement #16/#29.
export function buildMilestoneWindow(currentIndex: number, totalLevels: number, windowSize = 4): number[] {
  if (totalLevels <= 0) return []
  const clampedSize = Math.min(windowSize, totalLevels)
  const start = Math.max(0, Math.min(currentIndex, totalLevels - clampedSize))
  return Array.from({ length: clampedSize }, (_, i) => start + i)
}

// crypto.randomUUID() n'existe que dans un contexte sécurisé (HTTPS ou
// localhost) — indisponible si l'app est ouverte via l'IP locale du réseau
// en HTTP simple (cas courant pour cette PWA auto-hébergée). Repli sur un
// générateur RFC4122 v4 manuel (via crypto.getRandomValues si dispo, sinon
// Math.random) pour que la clé d'idempotence du combat reste disponible
// dans tous les contextes.
export function generateIdempotencyKey(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID()
  }
  const bytes = new Uint8Array(16)
  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    crypto.getRandomValues(bytes)
  } else {
    for (let i = 0; i < bytes.length; i++) bytes[i] = Math.floor(Math.random() * 256)
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
}
