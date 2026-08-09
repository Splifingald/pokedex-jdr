import { useCallback, useState } from 'react'
import type { ChatMessage } from '../types'

const STORAGE_KEY = 'chatLastSeenAt'

// Compteur de non-lus purement client (localStorage), sans état serveur —
// même logique que currentPlayerId (PlayerContext) : simple, pas de sync
// multi-appareil nécessaire pour ce indicateur.
export function useChatUnread(messages: ChatMessage[]) {
  const [lastSeenAt, setLastSeenAt] = useState<string>(() => localStorage.getItem(STORAGE_KEY) ?? '')

  const unreadCount = lastSeenAt
    ? messages.filter((m) => m.created_at > lastSeenAt).length
    : messages.length

  const markSeen = useCallback(() => {
    const now = new Date().toISOString()
    localStorage.setItem(STORAGE_KEY, now)
    setLastSeenAt(now)
  }, [])

  return { unreadCount, markSeen }
}
