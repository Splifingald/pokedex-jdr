import { useState, useCallback, useEffect, useRef } from 'react'

const key = (playerPokemonId: number) => `hp_${playerPokemonId}`
const EVENT = 'local-hp-changed'

function clamp(value: number, max: number) {
  return Math.max(0, Math.min(max, value))
}

// Lecture directe hors cycle de vie d'un composant (ex : détecter un K.O.
// avant un "tout soigner" groupé) — voir restoreLocalHp ci-dessous.
export function getLocalHp(playerPokemonId: number): number | null {
  const stored = localStorage.getItem(key(playerPokemonId))
  return stored === null ? null : parseInt(stored, 10) || 0
}

function dispatchChange(playerPokemonId: number, hp: number) {
  window.dispatchEvent(new CustomEvent(EVENT, { detail: { id: playerPokemonId, hp } }))
}

// Écrit directement dans le localStorage et prévient les instances montées du hook
// (utilisé pour les actions groupées comme "tout soigner", en dehors du cycle de vie d'un composant)
export function restoreLocalHp(playerPokemonId: number, maxHp: number) {
  localStorage.setItem(key(playerPokemonId), String(maxHp))
  dispatchChange(playerPokemonId, maxHp)
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

  const prevMaxHpRef = useRef(maxHp)

  // Synchro entre plusieurs instances montées du même pokémon (ex: carte + fiche, ou "tout soigner")
  useEffect(() => {
    const handler = (e: Event) => {
      const { id, hp } = (e as CustomEvent<{ id: number; hp: number }>).detail
      if (id === playerPokemonId) setHpState(hp)
    }
    window.addEventListener(EVENT, handler)
    return () => window.removeEventListener(EVENT, handler)
  }, [playerPokemonId])

  // Si le PV max augmente (palier d'XP franchi), on ajoute le même delta aux PV actuels.
  // S'il diminue (ex: PV max personnalisés réduits), on reclamp les PV actuels au nouveau maximum.
  useEffect(() => {
    const prevMaxHp = prevMaxHpRef.current
    prevMaxHpRef.current = maxHp
    if (maxHp === prevMaxHp) return

    setHpState((prev) => {
      const next = maxHp > prevMaxHp ? prev + (maxHp - prevMaxHp) : prev
      const clamped = clamp(next, maxHp)
      localStorage.setItem(key(playerPokemonId), String(clamped))
      return clamped
    })
  }, [maxHp, playerPokemonId])

  const setHp = useCallback((value: number) => {
    const clamped = clamp(value, maxHp)
    setHpState(clamped)
    localStorage.setItem(key(playerPokemonId), String(clamped))
    dispatchChange(playerPokemonId, clamped)
  }, [playerPokemonId, maxHp])

  return [hp, setHp] as const
}
