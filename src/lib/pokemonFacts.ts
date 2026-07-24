import type { Pokemon } from '../types'

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
