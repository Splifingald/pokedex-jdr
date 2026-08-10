import type { Attack, Item, PlayerPokemon, AutoBattleLevelReward, AutoBattleStatusEffect } from '../types'
import { getStatusInfo, type StatusId } from './status'

// Libellés propres à Combat Auto (alignés sur les libellés du CSV des
// attaques), mais couleur et icône RÉUTILISÉES du système de statut déjà
// affiché sur la fiche Pokémon (src/lib/status.ts, StatusSelect,
// PokemonOwnedCard) plutôt que redéfinies ici, pour rester visuellement
// cohérent entre les deux écrans.
export const STATUS_EFFECT_LABEL: Record<AutoBattleStatusEffect, string> = {
  paralysis: 'Paralysie',
  fear: 'Peur',
  confusion: 'Confusion',
  sleep: 'Sommeil',
  burn: 'Brûlure',
  poison: 'Poison',
  frozen: 'Gel',
}

const STATUS_ID_BY_EFFECT: Record<AutoBattleStatusEffect, StatusId> = {
  paralysis: 'paralysie',
  fear: 'apeure',
  confusion: 'confusion',
  sleep: 'endormi',
  burn: 'brule',
  poison: 'empoisonne',
  frozen: 'gele',
}

// Couleur + icône pixel-art (iconSrc) du statut équivalent sur la fiche
// Pokémon — voir getStatusInfo. `label` reste celui du CSV Combat Auto
// (STATUS_EFFECT_LABEL ci-dessus), pas celui de la fiche Pokémon. iconSrc
// est optionnel dans StatusInfo (le statut 'aucun' n'en a pas) mais toujours
// défini pour les 7 statuts mappés ici, d'où le non-null assertion.
export function getStatusEffectDisplay(status: AutoBattleStatusEffect) {
  const info = getStatusInfo(STATUS_ID_BY_EFFECT[status])
  return { label: STATUS_EFFECT_LABEL[status], color: info.color, iconSrc: info.iconSrc! }
}

// CSV des attaques (colonne "Mini-game status") → valeur interne. Casse et
// accents doivent correspondre exactement aux libellés du CSV.
const STATUS_EFFECT_BY_CSV_LABEL: Record<string, AutoBattleStatusEffect> = {
  'Paralysie': 'paralysis',
  'Peur': 'fear',
  'Confusion': 'confusion',
  'Sommeil': 'sleep',
  'Brûlure': 'burn',
  'Poison': 'poison',
  'Gel': 'frozen',
}
export function parseStatusEffectCsvLabel(label: string | undefined | null): AutoBattleStatusEffect | null {
  const trimmed = label?.trim()
  if (!trimmed) return null
  return STATUS_EFFECT_BY_CSV_LABEL[trimmed] ?? null
}

// Une capacité "offensive" est une capacité qui inflige quelque chose : soit
// des dégâts de base, soit un dé (voire les deux) — une capacité à 0 dégâts
// de base mais avec un dé reste utilisable, seule une capacité totalement
// sans dégâts (case vide/0 partout en CSV, capacité de statut/effet pur) est
// exclue.
export function isDamagingAbility(attack: Attack): boolean {
  const hasBase = attack.degats_base != null && attack.degats_base > 0
  const hasDice = attack.degats_de != null && attack.degats_de > 0
  return hasBase || hasDice
}

// Capacités offensives effectivement apprises par cette instance
// (playerPokemon.moves), hors capacités bannies (trop puissantes pour ce
// mode, voir autobattle_banned_attacks / AdminAutoBattleBannedAttacksPanel)
// — seules celles-ci sont sélectionnables en Combat Auto (voir
// AutoBattleAbilityPicker). Note : moves n'est PAS restreint au pool
// attaque_1..10 de l'espèce (voir PokemonDetailSheet.tsx où addableMoves
// propose tout le catalogue d'attaques, pas seulement celles de l'espèce) —
// il ne faut donc jamais recroiser avec ce pool ici.
export function getEligibleAbilities(
  playerMoves: string[],
  attacksByName: Map<string, Attack>,
  bannedAttacks: Set<string> = new Set()
): Attack[] {
  return playerMoves
    .map((nom) => attacksByName.get(nom))
    .filter((a): a is Attack => a != null && isDamagingAbility(a) && !bannedAttacks.has(a.nom))
}

// Pokémon du joueur pouvant participer à un combat : ni en pension, ni sans
// capacité offensive apprise (voir requirement #6/#9 du cahier des charges).
export function getEligiblePlayerPokemon(
  roster: PlayerPokemon[],
  attacksByName: Map<string, Attack>,
  bannedAttacks: Set<string> = new Set()
): PlayerPokemon[] {
  return roster.filter((pp) => !pp.in_daycare && getEligibleAbilities(pp.moves, attacksByName, bannedAttacks).length > 0)
}

// Récompense à prévisualiser sous un niveau donné de la bannière de
// progression (voir requirement #31) : s'il y a un ou plusieurs objets
// (item/badge — mécaniquement identiques, voir types.ts), on affiche celui
// de plus haute valeur (prix d'achat) ; sinon on retombe sur la récompense XP.
export function pickLevelBannerReward(
  rewards: AutoBattleLevelReward[],
  itemsByName: Map<string, Item>
): AutoBattleLevelReward | null {
  const itemRewards = rewards.filter((r) => r.reward_type === 'item' || r.reward_type === 'badge')
  if (itemRewards.length > 0) {
    return [...itemRewards].sort((a, b) => {
      const va = itemsByName.get(a.item_nom ?? '')?.achat ?? 0
      const vb = itemsByName.get(b.item_nom ?? '')?.achat ?? 0
      return vb - va
    })[0]
  }
  return rewards.find((r) => r.reward_type === 'xp') ?? null
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
