import { useState, useCallback } from 'react'

const key = (playerPokemonId: number) => `hp_${playerPokemonId}`

function clamp(value: number, max: number) {
  return Math.max(0, Math.min(max, value))
}

export function useLocalHp(playerPokemonId: number, maxHp: number) {
  const [hp, setHpState] = useState<number>(() => {
    const stored = localStorage.getItem(key(playerPokemonId))
    if (stored === null) {
      localStorage.setItem(key(playerPokemonId), String(maxHp))
      return maxHp
    }
    return clamp(parseInt(stored, 10) || 0, maxHp)
  })

  const setHp = useCallback((value: number) => {
    const clamped = clamp(value, maxHp)
    setHpState(clamped)
    localStorage.setItem(key(playerPokemonId), String(clamped))
  }, [playerPokemonId, maxHp])

  return [hp, setHp] as const
}
