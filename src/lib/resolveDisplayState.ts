import type { Background, DisplayAsset, DisplayState, Item, Pokemon } from '../types'

interface DisplayFigure {
  id: number
  nom: string
  image_url: string
}

export function resolveDisplayState(
  state: DisplayState,
  backgrounds: Background[],
  assets: DisplayAsset[],
  pokemonList: Pokemon[],
  items: Item[]
) {
  const backgroundUrl = backgrounds.find((b) => b.id === state.background_id)?.image_url ?? null

  const npcs: DisplayFigure[] = state.npc_ids
    .map((id) => assets.find((a) => a.id === id))
    .filter((a): a is DisplayAsset => !!a)
    .map((a) => ({ id: a.id, nom: a.nom, image_url: a.image_url }))

  const pokemons: DisplayFigure[] = state.pokemon_ids
    .map((id) => pokemonList.find((p) => p.id === id))
    .filter((p): p is Pokemon => !!p)
    .map((p) => ({ id: p.id, nom: p.nom, image_url: p.image_miniature }))

  const found = items.find((i) => i.id === state.item_id)
  const item: DisplayFigure | null = found ? { id: found.id, nom: found.nom, image_url: found.image_url ?? '' } : null

  return { backgroundUrl, npcs, pokemons, item }
}
