import type { Pokemon, PokemonEvolution } from '../types'

// Regroupe la construction des listes dérivées d'un Pokémon,
// auparavant dupliquée entre PokemonCard et PokemonDetailView.
export function getSuperEfficace(pokemon: Pokemon | undefined): string[] {
  if (!pokemon) return []
  return [
    pokemon.super_efficace_1,
    pokemon.super_efficace_2,
    pokemon.super_efficace_3,
    pokemon.super_efficace_4,
  ].filter(Boolean) as string[]
}

export function getLocalisations(pokemon: Pokemon | undefined): string[] {
  if (!pokemon) return []
  return [pokemon.localisation_1, pokemon.localisation_2, pokemon.localisation_3].filter(Boolean) as string[]
}

export function getAttaques(pokemon: Pokemon | undefined): string[] {
  if (!pokemon) return []
  return [
    pokemon.attaque_1, pokemon.attaque_2, pokemon.attaque_3, pokemon.attaque_4, pokemon.attaque_5,
    pokemon.attaque_6, pokemon.attaque_7, pokemon.attaque_8, pokemon.attaque_9, pokemon.attaque_10,
  ].filter(Boolean) as string[]
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
