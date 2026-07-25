import type { GiftLootbox, GiftLootboxItem, GiftLootboxSpecies, PlayerPokemon } from '../types'

// Résout le lootbox applicable à une espèce : celui assigné explicitement,
// sinon celui marqué par défaut.
export function resolveLootboxForSpecies(
  pokemonNom: string,
  lootboxes: GiftLootbox[],
  assignments: GiftLootboxSpecies[]
): GiftLootbox | undefined {
  const assigned = assignments.find((a) => a.pokemon_nom === pokemonNom)
  if (assigned) {
    const lootbox = lootboxes.find((l) => l.id === assigned.lootbox_id)
    if (lootbox) return lootbox
  }
  return lootboxes.find((l) => l.is_default)
}

// Prochain horodatage de cadeau : maintenant + une durée aléatoire dans la
// plage du lootbox (en heures).
export function randomNextGiftAt(
  lootbox: Pick<GiftLootbox, 'timer_min_hours' | 'timer_max_hours'>,
  from: Date = new Date()
): string {
  const { timer_min_hours: min, timer_max_hours: max } = lootbox
  const hours = min + Math.random() * Math.max(0, max - min)
  return new Date(from.getTime() + hours * 3_600_000).toISOString()
}

// Un pokémon a un cadeau prêt si : il est dans l'équipe, son dresseur n'est
// pas un PNJ (le gifting ne s'applique jamais aux PNJ), et son minuteur est
// écoulé. Aucune notion de compte à rebours visible n'existe côté joueur —
// c'est une simple comparaison d'horodatage recalculée périodiquement.
export function isGiftReady(
  pp: Pick<PlayerPokemon, 'in_team' | 'next_gift_at'>,
  isNpc: boolean,
  now: Date = new Date()
): boolean {
  if (isNpc || !pp.in_team || !pp.next_gift_at) return false
  return new Date(pp.next_gift_at).getTime() <= now.getTime()
}

// Tirage pondéré à une seule entrée (un cadeau = un tirage de lootbox).
export function drawLootboxReward(lootboxId: number, allItems: GiftLootboxItem[]): GiftLootboxItem | null {
  const items = allItems.filter((i) => i.lootbox_id === lootboxId && i.weight > 0)
  const total = items.reduce((sum, i) => sum + i.weight, 0)
  if (total <= 0) return null
  let r = Math.random() * total
  for (const item of items) {
    r -= item.weight
    if (r <= 0) return item
  }
  return items[items.length - 1] ?? null
}

interface MaybeResetGiftTimerParams {
  giftingEnabled: boolean
  isNpc: boolean
  wasInTeam: boolean
  willBeInTeam: boolean
  pokemonNom: string
  playerPokemonId: number
  lootboxes: GiftLootbox[]
  speciesAssignments: GiftLootboxSpecies[]
  setNextGiftAt: (id: number, nextGiftAt: string | null) => Promise<void>
}

// À appeler après toute mutation qui peut faire entrer un pokémon dans
// l'équipe (toggleInTeam, addOwnedPokemon). Ne relance le minuteur que sur
// la transition hors-équipe → équipe, jamais si déjà dans l'équipe.
export async function maybeResetGiftTimerOnEntry(params: MaybeResetGiftTimerParams): Promise<void> {
  const {
    giftingEnabled, isNpc, wasInTeam, willBeInTeam, pokemonNom,
    playerPokemonId, lootboxes, speciesAssignments, setNextGiftAt,
  } = params
  if (!giftingEnabled || isNpc || wasInTeam || !willBeInTeam) return
  const lootbox = resolveLootboxForSpecies(pokemonNom, lootboxes, speciesAssignments)
  if (!lootbox) return
  await setNextGiftAt(playerPokemonId, randomNextGiftAt(lootbox))
}
