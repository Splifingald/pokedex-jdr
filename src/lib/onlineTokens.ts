import type { OnlineToken, Player, PlayerPokemon, Pokemon } from '../types'
import { ownedPokemonName } from '../types'
import { getVitals, mergeVitals, resolveHp, resolveStatus, vitalsFromRow } from './pokemonVitals'
import { getMaxHp } from './maxHp'
import { getDamageBreakdown } from './xpBonuses'
import { TYPE_COLORS } from './typeColors'
import { DEFAULT_STATUS, type StatusId } from './status'
import { isTokenKo } from './onlineBoard'

// Résolution d'un jeton du plateau vers tout ce qu'il faut pour l'afficher.
// Pendant du resolveDisplayState.ts du mode Affichage : une fonction pure, pour
// que le rendu du plateau soit identique dans l'aperçu admin, la pop-up joueur
// et l'écran /display (qui, lui, n'a aucun contexte React — voir main.tsx).

export interface TokenContext {
  ownedById: Map<number, PlayerPokemon>
  pokemonByName: Map<string, Pokemon>
  playersById: Map<number, Player>
}

export interface ResolvedToken {
  token: OnlineToken
  /** Nom affiché : surnom du Pokémon possédé, sinon libellé libre, sinon espèce. */
  displayName: string
  species: Pokemon | undefined
  owned: PlayerPokemon | undefined
  owner: Player | undefined
  /** Nom du dresseur, ou « ? » pour un personnage inconnu posé par le MJ. */
  ownerName: string
  ownerColor: string
  spriteUrl: string
  typeColor: string
  hp: number
  maxHp: number
  status: StatusId
  damage: number
  isKo: boolean
  /** Espèce libre posée par le MJ : PV et dégâts viennent du jeton, pas d'un player_pokemon. */
  isFree: boolean
}

const UNKNOWN_COLOR = '#8a8362'

export function resolveToken(token: OnlineToken, ctx: TokenContext): ResolvedToken {
  const species = ctx.pokemonByName.get(token.pokemon_nom)
  const owned = token.player_pokemon_id != null ? ctx.ownedById.get(token.player_pokemon_id) : undefined
  const owner = token.owner_player_id != null ? ctx.playersById.get(token.owner_player_id) : undefined
  const isFree = token.player_pokemon_id == null

  let hp: number
  let maxHp: number
  let status: StatusId
  let damage: number

  if (!isFree && owned) {
    maxHp = getMaxHp(owned, species)
    const vitals = mergeVitals(getVitals(owned.id), vitalsFromRow(owned))
    hp = resolveHp(vitals, maxHp)
    status = resolveStatus(vitals)
    damage = getDamageBreakdown(species, owned.xp).total
  } else {
    maxHp = token.free_max_hp ?? species?.pv_base ?? 0
    hp = token.free_current_hp ?? maxHp
    status = token.free_status ?? DEFAULT_STATUS
    damage = token.free_damage ?? species?.degats_base ?? 0
  }

  const displayName = owned
    ? ownedPokemonName(owned)
    : token.free_label.trim() || token.pokemon_nom

  return {
    token,
    displayName,
    species,
    owned,
    owner,
    ownerName: owner?.name ?? '?',
    ownerColor: owner?.color ?? UNKNOWN_COLOR,
    spriteUrl: species?.image_miniature ?? '',
    typeColor: TYPE_COLORS[species?.type ?? ''] ?? '#888888',
    hp,
    maxHp,
    status,
    damage,
    isKo: isTokenKo(hp),
    isFree,
  }
}

/** Le joueur peut-il déplacer ce jeton ? Le MJ peut tout bouger ; un joueur ne
 *  bouge que le sien, et seulement si le MJ a autorisé le déplacement. */
export function canMoveToken(
  t: ResolvedToken,
  viewerPlayerId: number | null,
  isAdmin: boolean,
  movementAllowed: boolean
): boolean {
  if (isAdmin) return true
  if (!movementAllowed) return false
  return !t.token.placed_by_admin && t.token.owner_player_id != null && t.token.owner_player_id === viewerPlayerId
}

/** Le joueur peut-il ouvrir la fiche de ce jeton ? Le MJ voit tout ; un joueur
 *  ne consulte que ses propres Pokémon. */
export function canInspectToken(t: ResolvedToken, viewerPlayerId: number | null, isAdmin: boolean): boolean {
  return isAdmin || (t.token.owner_player_id != null && t.token.owner_player_id === viewerPlayerId)
}

/** Ordre du tour : la liste enregistrée d'abord, puis tout jeton qu'elle ignore
 *  encore, dans son ordre d'arrivée sur le plateau (les id sont croissants).
 *  Les jetons disparus sont écartés — inutile de nettoyer la liste en base à
 *  chaque retrait. */
export function resolveTurnOrder(tokens: ResolvedToken[], order: number[]): ResolvedToken[] {
  const byId = new Map(tokens.map((t) => [t.token.id, t]))
  const ordered: ResolvedToken[] = []
  const seen = new Set<number>()
  for (const id of order) {
    const t = byId.get(id)
    if (t && !seen.has(id)) {
      ordered.push(t)
      seen.add(id)
    }
  }
  const rest = tokens.filter((t) => !seen.has(t.token.id)).sort((a, b) => a.token.id - b.token.id)
  return [...ordered, ...rest]
}

/** Étiquettes du suivi des tours compact : l'initiale du Pokémon suffit, sauf
 *  quand deux d'entre eux partagent la même initiale ET la même couleur de type
 *  — indistinguables autrement. Ces deux-là passent alors à deux lettres. */
export function turnOrderLabels(ordered: ResolvedToken[]): Map<number, string> {
  const initials = (name: string, n: number) =>
    name.replace(/[^\p{L}\p{N}]/gu, '').slice(0, n).toUpperCase() || '?'

  const groups = new Map<string, ResolvedToken[]>()
  for (const t of ordered) {
    const key = `${initials(t.displayName, 1)}|${t.typeColor}`
    const list = groups.get(key)
    if (list) list.push(t)
    else groups.set(key, [t])
  }

  const labels = new Map<number, string>()
  for (const list of groups.values()) {
    const length = list.length > 1 ? 2 : 1
    for (const t of list) labels.set(t.token.id, initials(t.displayName, length))
  }
  return labels
}
