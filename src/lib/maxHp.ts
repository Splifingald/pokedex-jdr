import type { Pokemon, PlayerPokemon } from '../types'

export function getMaxHp(playerPokemon: PlayerPokemon, pokemon: Pokemon | undefined): number {
  return playerPokemon.max_hp_override ?? pokemon?.pv_base ?? 0
}
