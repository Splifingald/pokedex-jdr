import type { Attack, Pokemon, PokemonEvolution } from '../types'
import { normalizeType } from './typeChart'

// Regroupe la construction des listes dérivées d'un Pokémon,
// auparavant dupliquée entre PokemonCard et PokemonDetailView.
// NB : plus de getSuperEfficace ici — l'efficacité ne dépend plus des colonnes
// super_efficace_1..4 de l'espèce mais du TYPE DE LA CAPACITÉ jouée face au
// type du défenseur (voir src/lib/typeChart.ts). Les colonnes restent
// importées depuis le CSV (voir AdminPanel) mais ne sont plus lues nulle part.
export function getLocalisations(pokemon: Pokemon | undefined): string[] {
  if (!pokemon) return []
  return [pokemon.localisation_1, pokemon.localisation_2, pokemon.localisation_3].filter(Boolean) as string[]
}

export function getAttaques(pokemon: Pokemon | undefined): string[] {
  if (!pokemon) return []
  return [
    pokemon.attaque_1, pokemon.attaque_2, pokemon.attaque_3, pokemon.attaque_4, pokemon.attaque_5,
    pokemon.attaque_6, pokemon.attaque_7, pokemon.attaque_8, pokemon.attaque_9, pokemon.attaque_10,
    pokemon.attaque_11, pokemon.attaque_12, pokemon.attaque_13, pokemon.attaque_14, pokemon.attaque_15,
  ].filter(Boolean) as string[]
}

// Tri d'affichage des capacités d'une fiche (voir requirement) : on regroupe
// par type de capacité, puis on ordonne les groupes
//   1. type de l'espèce en tête (capacités « STAB »),
//   2. puis du type le plus représenté au moins représenté,
//   3. à égalité de nombre, ordre alphabétique du TYPE.
// Les capacités inconnues (absentes de attacksByName, donc sans type) ferment
// la marche. À l'intérieur d'un groupe, ordre alphabétique du nom.
// Comparaison des types toujours normalisée (« Électrik » / « Electrik »…),
// voir normalizeType.
export function sortMovesByType(
  moveNames: string[],
  attacksByName: Map<string, Attack>,
  pokemonType: string | null | undefined
): string[] {
  const speciesType = normalizeType(pokemonType)
  const groups = new Map<string, string[]>()
  for (const name of moveNames) {
    const key = normalizeType(attacksByName.get(name)?.type)
    const group = groups.get(key)
    if (group) group.push(name)
    else groups.set(key, [name])
  }

  const rank = (type: string) => (type === '' ? 2 : speciesType !== '' && type === speciesType ? 0 : 1)

  return [...groups.entries()]
    .sort(([typeA, movesA], [typeB, movesB]) => {
      const byRank = rank(typeA) - rank(typeB)
      if (byRank !== 0) return byRank
      if (movesA.length !== movesB.length) return movesB.length - movesA.length
      return typeA.localeCompare(typeB, 'fr')
    })
    .flatMap(([, moves]) => moves.sort((a, b) => a.localeCompare(b, 'fr')))
}

// Espèces dont ce Pokémon descend directement — remonte la chaîne d'évolution
// à l'envers (evolution_nom -> pokemon_nom) sur 2 générations max (parent,
// grand-parent), pas plus loin.
export function getPrecedentEvolutions(
  pokemon: Pokemon | undefined,
  pokemonByName: Map<string, Pokemon>,
  evolutionsByPokemonNom: Map<string, PokemonEvolution[]>
): Pokemon[] {
  if (!pokemon) return []
  const result: Pokemon[] = []
  const visited = new Set<string>([pokemon.nom])
  let currentGen = [pokemon.nom]

  for (let depth = 0; depth < 2 && currentGen.length > 0; depth++) {
    const nextGen: string[] = []
    for (const [fromNom, rows] of evolutionsByPokemonNom) {
      if (visited.has(fromNom)) continue
      if (rows.some((r) => currentGen.includes(r.evolution_nom))) nextGen.push(fromNom)
    }
    for (const nom of nextGen) {
      visited.add(nom)
      const species = pokemonByName.get(nom)
      if (species) result.push(species)
    }
    currentGen = nextGen
  }

  return result
}

// Capacités apprenables par ce Pokémon, en incluant celles de ses évolutions
// précédentes (un Pokémon peut apprendre tout ce que ses formes antérieures
// pouvaient apprendre).
export function getAttaquesWithPreEvolutions(
  pokemon: Pokemon | undefined,
  pokemonByName: Map<string, Pokemon>,
  evolutionsByPokemonNom: Map<string, PokemonEvolution[]>
): string[] {
  const species = [pokemon, ...getPrecedentEvolutions(pokemon, pokemonByName, evolutionsByPokemonNom)]
  const seen = new Set<string>()
  const result: string[] = []
  for (const s of species) {
    for (const move of getAttaques(s)) {
      if (!seen.has(move)) {
        seen.add(move)
        result.push(move)
      }
    }
  }
  return result
}
