import type { Pokemon, PlayerPokemon, PokemonEvolution, Item, PlayerItem } from '../types'
import { getMaxXp } from './xpBonuses'

export interface EvolutionOption {
  evolution: PokemonEvolution
  targetSpecies: Pokemon | undefined
  conditionItem: Item | null
  playerHasItem: boolean
  clickable: boolean
}

// Options d'évolution disponibles pour une instance possédée : nécessite d'avoir
// atteint le dernier palier d'XP de l'espèce ET au moins une ligne dans le
// catalogue d'évolutions importé par CSV pour cette espèce.
export function getEvolutionOptions(
  playerPokemon: PlayerPokemon,
  pokemon: Pokemon | undefined,
  evolutionsByPokemonNom: Map<string, PokemonEvolution[]>,
  pokemonByName: Map<string, Pokemon>,
  itemsByName: Map<string, Item>,
  inventory: PlayerItem[]
): EvolutionOption[] {
  const maxXp = getMaxXp(pokemon)
  if (maxXp == null || playerPokemon.xp < maxXp) return []

  const rows = evolutionsByPokemonNom.get(playerPokemon.pokemon_nom) ?? []
  return rows
    .filter((e) => pokemonByName.has(e.evolution_nom))
    .map((evolution) => {
      const conditionItem = evolution.condition_item_nom ? itemsByName.get(evolution.condition_item_nom) ?? null : null
      const playerHasItem = evolution.condition_item_nom
        ? (inventory.find((r) => r.item_nom === evolution.condition_item_nom)?.quantity ?? 0) >= 1
        : true
      return {
        evolution,
        targetSpecies: pokemonByName.get(evolution.evolution_nom),
        conditionItem,
        playerHasItem,
        clickable: playerHasItem,
      }
    })
}
