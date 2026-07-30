import type { DisplayAsset, DisplayState, Item, Pokemon } from '../types'

interface DisplayFigure {
  id: number
  nom: string
  image_url: string
}

export function resolveDisplayState(
  state: DisplayState,
  assets: DisplayAsset[],
  pokemonList: Pokemon[],
  itemsList: Item[]
) {
  const backgroundUrl = state.background_url?.trim() || assets.find((a) => a.id === state.background_id)?.image_url || null

  const npcs: DisplayFigure[] = state.npc_ids
    .map((id) => assets.find((a) => a.id === id))
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
