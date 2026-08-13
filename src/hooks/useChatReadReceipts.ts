import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { ChatReadReceipt } from '../types'

// Accusés de lecture du chat ("Vu par") — une ligne par joueur, pointant sur le
// dernier message qu'il a vu. Table minuscule (un enregistrement par joueur),
// donc chargée intégralement puis maintenue à jour en Realtime, sans pagination.
export function useChatReadReceipts() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [receipts, setReceipts] = useState<ChatReadReceipt[]>([])
  // Plus grand id déjà marqué comme lu dans cette session : évite de renvoyer un
  // upsert à chaque rendu et de régresser vers un message plus ancien.
  const lastMarkedRef = useRef(0)

  const fetchAll = useCallback(async () => {
    const { data, error } = await supabase.from('chat_read_receipts').select('*')
    if (error) {
      console.error('Erreur lors du chargement des accusés de lecture :', error)
      return
    }
    setReceipts((data as ChatReadReceipt[]) ?? [])
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`chat-read-receipts-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'chat_read_receipts' },
        (payload) => {
          if (payload.eventType === 'DELETE') {
            // player_id est la clé primaire, donc toujours présent dans payload.old
            const removed = payload.old as Partial<ChatReadReceipt>
            setReceipts((prev) => prev.filter((r) => r.player_id !== removed.player_id))
            return
          }
          const row = payload.new as ChatReadReceipt
          setReceipts((prev) => [...prev.filter((r) => r.player_id !== row.player_id), row])
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const markRead = useCallback(async (playerId: number, messageId: number) => {
    if (messageId <= lastMarkedRef.current) return
    lastMarkedRef.current = messageId

    const row: ChatReadReceipt = {
      player_id: playerId,
      last_read_message_id: messageId,
      updated_at: new Date().toISOString(),
    }
    // Écho local immédiat : le Realtime ne renvoie pas toujours à l'émetteur.
    setReceipts((prev) => [...prev.filter((r) => r.player_id !== playerId), row])

    const { error } = await supabase.from('chat_read_receipts').upsert(row)
    if (error) console.error("Erreur lors de l'enregistrement de l'accusé de lecture :", error)
  }, [])

  return { receipts, refetch: fetchAll, markRead }
}
