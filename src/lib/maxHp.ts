import type { Pokemon, PlayerPokemon } from '../types'
import { getHpBonus } from './xpBonuses'

export function getMaxHp(playerPokemon: PlayerPokemon, pokemon: Pokemon | undefined): number {
  return (pokemon?.pv_base ?? 0) + getHpBonus(pokemon, playerPokemon.xp)
}
