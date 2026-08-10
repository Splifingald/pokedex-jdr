import { useState, useCallback, useEffect } from 'react'
import type { StatusId } from '../lib/status'
import { DEFAULT_STATUS } from '../lib/status'

const key = (playerPokemonId: number) => `status_${playerPokemonId}`
const EVENT = 'local-status-changed'

function dispatchChange(playerPokemonId: number, status: StatusId) {
  window.dispatchEvent(new CustomEvent(EVENT, { detail: { id: playerPokemonId, status } }))
}

// Écrit directement dans le localStorage et prévient les instances montées du hook
// (utilisé pour les actions groupées comme "tout soigner", en dehors du cycle de vie d'un composant)
export function restoreLocalStatus(playerPokemonId: number) {
  localStorage.setItem(key(playerPokemonId), DEFAULT_STATUS)
  dispatchChange(playerPokemonId, DEFAULT_STATUS)
}

export function useLocalStatus(playerPokemonId: number) {
  const [status, setStatusState] = useState<StatusId>(() => {
    return (localStorage.getItem(key(playerPokemonId)) as StatusId | null) ?? DEFAULT_STATUS
  })

  // Synchro entre plusieurs instances montées du même pokémon (ex: carte + fiche)
  useEffect(() => {
    const handler = (e: Event) => {
      const { id, status } = (e as CustomEvent<{ id: number; status: StatusId }>).detail
      if (id === playerPokemonId) setStatusState(status)
    }
    window.addEventListener(EVENT, handler)
    return () => window.removeEventListener(EVENT, handler)
  }, [playerPokemonId])

  const setStatus = useCallback((value: StatusId) => {
    setStatusState(value)
    localStorage.setItem(key(playerPokemonId), value)
    dispatchChange(playerPokemonId, value)
  }, [playerPokemonId])

  return [status, setStatus] as const
}
