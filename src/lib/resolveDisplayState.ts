import type { DisplayAsset, DisplayState, Item, Player, Pokemon } from '../types'
import { playerToDisplayAsset } from './displayActions'

interface DisplayFigure {
  id: number
  nom: string
  image_url: string
}

// npc_ids ≤ -1 encodent -players.id (voir displayActions.ts) ; ≥ 1 sont des display_assets.id
export function resolveNpcAsset(id: number, assets: DisplayAsset[], players: Player[]): DisplayAsset | undefined {
  if (id < 0) {
    const player = players.find((p) => p.id === -id)
    return player ? playerToDisplayAsset(player) : undefined
  }
  return assets.find((a) => a.id === id)
}

export function resolveDisplayState(
  state: DisplayState,
  assets: DisplayAsset[],
  pokemonList: Pokemon[],
  itemsList: Item[],
  players: Player[] = []
) {
  // Un fond doit toujours être affiché : si l'id enregistré ne correspond à aucun
  // fond connu (pas encore choisi, fond supprimé...), on retombe sur le premier
  // de la liste plutôt que de laisser l'affichage sans fond.
  const backgroundUrl =
    state.background_url?.trim() ||
    assets.find((a) => a.id === state.background_id)?.image_url ||
    assets.find((a) => a.type === 'Background')?.image_url ||
    null

  const npcs: DisplayFigure[] = state.npc_ids
    .map((id) => resolveNpcAsset(id, assets, players))
    .filter((a): a is DisplayAsset => !!a)
    .map((a) => ({ id: a.id, nom: a.nom, image_url: a.image_url }))

  const pokemons: DisplayFigure[] = state.pokemon_ids
    .map((id) => pokemonList.find((p) => p.id === id))
    .filter((p): p is Pokemon => !!p)
    .map((p) => ({ id: p.id, nom: p.nom, image_url: p.image_miniature }))

  const items: DisplayFigure[] = state.item_ids
    .map((id) => itemsList.find((i) => i.id === id))
    .filter((i): i is Item => !!i)
    .map((i) => ({ id: i.id, nom: i.nom, image_url: i.image_url ?? '' }))

  return { backgroundUrl, npcs, pokemons, items }
}
