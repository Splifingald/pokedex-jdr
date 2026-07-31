import { createContext, useContext, useState, useEffect, useMemo, type ReactNode } from 'react'
import { usePlayers } from '../hooks/usePlayers'
import type { Player } from '../types'

const STORAGE_KEY = 'currentPlayerId'

interface PlayerContextValue {
  player: Player | null
  players: Player[]
  playersLoading: boolean
  login: (player: Player) => void
  logout: () => void
  updatePlayer: (id: number, data: Partial<Omit<Player, 'id' | 'created_at'>>) => void
}

const PlayerContext = createContext<PlayerContextValue | null>(null)

export function PlayerProvider({ children }: { children: ReactNode }) {
  const { players, loading: playersLoading, updatePlayer } = usePlayers()
  const [currentPlayerId, setCurrentPlayerId] = useState<number | null>(() => {
    const stored = localStorage.getItem(STORAGE_KEY)
    return stored ? parseInt(stored, 10) : null
  })

  const player = useMemo(
    () => players.find((p) => p.id === currentPlayerId) ?? null,
    [players, currentPlayerId]
  )

  // Si le joueur connecté a été supprimé côté admin, on déconnecte proprement
  useEffect(() => {
    if (currentPlayerId !== null && !playersLoading && !players.some((p) => p.id === currentPlayerId)) {
      setCurrentPlayerId(null)
      localStorage.removeItem(STORAGE_KEY)
    }
  }, [players, playersLoading, currentPlayerId])

  const login = (p: Player) => {
    setCurrentPlayerId(p.id)
    localStorage.setItem(STORAGE_KEY, String(p.id))
  }

  const logout = () => {
    setCurrentPlayerId(null)
    localStorage.removeItem(STORAGE_KEY)
  }

  return (
    <PlayerContext.Provider value={{ player, players, playersLoading, login, logout, updatePlayer }}>
      {children}
    </PlayerContext.Provider>
  )
}

export function usePlayerContext() {
  const ctx = useContext(PlayerContext)
  if (!ctx) throw new Error('usePlayerContext doit être utilisé dans un PlayerProvider')
  return ctx
}
