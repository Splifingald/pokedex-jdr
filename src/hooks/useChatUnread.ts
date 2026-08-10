import { useCallback, useState } from 'react'
import type { ChatMessage } from '../types'

const STORAGE_KEY = 'chatLastSeenAt'

// Compteur de non-lus purement client (localStorage), sans état serveur —
// même logique que currentPlayerId (PlayerContext) : simple, pas de sync
// multi-appareil nécessaire pour ce indicateur. Les messages envoyés par le
// joueur courant ne comptent jamais comme non-lus (il vient de les écrire).
export function useChatUnread(messages: ChatMessage[], playerId: number | null) {
  const [lastSeenAt, setLastSeenAt] = useState<string>(() => localStorage.getItem(STORAGE_KEY) ?? '')

  const unreadMessages = messages.filter((m) => m.player_id !== playerId)
  const unreadCount = lastSeenAt
    ? unreadMessages.filter((m) => m.created_at > lastSeenAt).length
    : unreadMessages.length

  const markSeen = useCallback(() => {
    const now = new Date().toISOString()
    localStorage.setItem(STORAGE_KEY, now)
    setLastSeenAt(now)
  }, [])

  return { unreadCount, markSeen }
}
