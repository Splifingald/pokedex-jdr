import type { Pokemon, PlayerPokemon, PokemonEvolution, Item, PlayerItem } from '../types'
import { getMilestones, ITEM_TOKEN } from './xpBonuses'

export interface EvolutionOption {
  evolution: PokemonEvolution
  targetSpecies: Pokemon | undefined
  conditionItem: Item | null
  playerHasItem: boolean
  clickable: boolean
}

// XP du palier le plus bas dont le libellé (texte libre de la case xp_*) satisfait
// le prédicat donné — sert à repérer les paliers "Évolution" / "Évolution possible".
function findTriggerXp(pokemon: Pokemon | undefined, matches: (label: string) => boolean): number | null {
  const xps = getMilestones(pokemon)
    .filter((m) => m.kind === 'text' && matches(m.label.trim().toLowerCase()))
    .map((m) => m.xp)
  return xps.length ? Math.min(...xps) : null
}

// "Évo" / "Évo." sont acceptés comme abréviation de "Évolution" (label déjà trim/lowercase ici)
// pour permettre des libellés plus courts dans la jauge XP.
const isEvolutionWord = (label: string) => label === 'évolution' || label === 'évo' || label === 'évo.'
const startsWithEvolutionWord = (label: string) =>
  label.startsWith('évolution') || label.startsWith('évo.') || label.startsWith('évo ')

// Palier distinct de isEvolutionWord/startsWithEvolutionWord (aucune collision :
// ces libellés ne commencent ni par "évolution" ni par "évo") — déclenche une
// évolution vers une cible tirée au hasard parmi pokemon_evolutions plutôt
// qu'un choix précis. Toujours sans objet requis (pas de variante "possible"),
// utilisé pour les œufs de la Pension Pokémon mais applicable à n'importe
// quelle espèce.
const isRandomEvolutionWord = (label: string) => label === 'éclosion' || label === 'évo. aléatoire' || label === 'évolution aléatoire'

// Options d'évolution disponibles pour une instance possédée. Le palier XP qui
// déclenche l'affichage n'est pas forcément le dernier de la jauge : c'est celui
// dont le libellé vaut exactement "Évolution"/"Évo"/"Évo." (évolutions sans objet
// requis) ou commence par l'un de ces mots et contient "possible" et/ou le token
// "[objet]" (évolutions avec objet requis — "Évolution possible (Pierre Feu)",
// "Évo. possible [objet]", "Évolution [objet]" et "Évo [objet]" sont tous équivalents)
// — tout autre texte (ex : "Évolution aléatoire") est ignoré, le MJ gère ce cas
// manuellement.
export function getEvolutionOptions(
  playerPokemon: PlayerPokemon,
  pokemon: Pokemon | undefined,
  evolutionsByPokemonNom: Map<string, PokemonEvolution[]>,
  pokemonByName: Map<string, Pokemon>,
  itemsByName: Map<string, Item>,
  inventory: PlayerItem[]
): EvolutionOption[] {
  const rows = evolutionsByPokemonNom.get(playerPokemon.pokemon_nom) ?? []
  if (rows.length === 0) return []

  const noConditionXp = findTriggerXp(pokemon, isEvolutionWord)
  const conditionXp = findTriggerXp(pokemon, (l) => startsWithEvolutionWord(l) && (l.includes('possible') || l.includes(ITEM_TOKEN)))
  const noConditionReady = noConditionXp != null && playerPokemon.xp >= noConditionXp
  const conditionReady = conditionXp != null && playerPokemon.xp >= conditionXp

  return rows
    .filter((e) => pokemonByName.has(e.evolution_nom))
    .filter((e) => (e.condition_item_nom ? conditionReady : noConditionReady))
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

// XP du palier "Éclosion"/"Évo. aléatoire" le plus bas, ou null si l'espèce n'en a pas.
export function getRandomEvolutionTrigger(pokemon: Pokemon | undefined): number | null {
  return findTriggerXp(pokemon, isRandomEvolutionWord)
}

export function isRandomEvolutionReady(playerPokemon: PlayerPokemon, pokemon: Pokemon | undefined): boolean {
  const xp = getRandomEvolutionTrigger(pokemon)
  return xp != null && playerPokemon.xp >= xp
}

// Cible tirée uniformément au hasard parmi les options d'évolution configurées
// pour cette espèce (pokemon_evolutions) — toujours sans condition d'objet,
// contrairement aux évolutions normales qui peuvent en avoir une.
export function pickRandomEvolution(pokemonNom: string, evolutionsByPokemonNom: Map<string, PokemonEvolution[]>): PokemonEvolution | null {
  const rows = evolutionsByPokemonNom.get(pokemonNom) ?? []
  if (rows.length === 0) return null
  return rows[Math.floor(Math.random() * rows.length)]
}
