import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { ChatMessage, ChatMessageType } from '../types'
import { logHistoryEvent } from '../lib/historyLog'

// Salon global unique — pas de filtre par joueur, tout le monde lit le même flux.
export function useChatMessages() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('chat_messages').select('*').order('created_at', { ascending: true }).limit(5000)
      if (error) throw error
      setMessages((data as ChatMessage[]) ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`chat-messages-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'chat_messages' },
        (payload) => {
          const row = payload.new as ChatMessage
          setMessages((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
        }
      )
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table: 'chat_messages' },
        (payload) => {
          const row = payload.old as ChatMessage
          setMessages((prev) => prev.filter((r) => r.id !== row.id))
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const sendMessage = useCallback(async (playerId: number, content: string, isNpc: boolean): Promise<ChatMessage | null> => {
    const { data, error } = await supabase
      .from('chat_messages')
      .insert({ player_id: playerId, content, is_npc: isNpc })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'envoi du message :", error)
      return null
    }
    void logHistoryEvent('chat', 'chat_message', playerId, { content, is_npc: isNpc })
    return data as ChatMessage
  }, [])

  // content = résumé texte de repli (historique/notifications) ; le rendu riche
  // (carte de proposition ou message de conclusion) se fait via message_type + trade_id.
  const sendTradeMessage = useCallback(async (
    playerId: number,
    content: string,
    tradeId: number,
    messageType: Extract<ChatMessageType, 'trade' | 'trade_completed'> = 'trade'
  ): Promise<ChatMessage | null> => {
    const { data, error } = await supabase
      .from('chat_messages')
      .insert({ player_id: playerId, content, is_npc: false, message_type: messageType, trade_id: tradeId })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'envoi du message d'échange :", error)
      return null
    }
    void logHistoryEvent('chat', 'chat_message', playerId, { content, is_npc: false })
    return data as ChatMessage
  }, [])

  const deleteMessage = useCallback(async (id: number) => {
    setMessages((prev) => prev.filter((m) => m.id !== id))
    const { error } = await supabase.from('chat_messages').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors de la suppression du message :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const clearAll = useCallback(async () => {
    setMessages([])
    const { error } = await supabase.from('chat_messages').delete().neq('id', 0)
    if (error) {
      console.error('Erreur lors de la suppression du chat :', error)
      await fetchAll()
      return
    }
    // Les accusés de lecture pointent sur des messages qui n'existent plus :
    // on les purge pour ne pas laisser de "Vu par" orphelin au prochain message.
    const { error: receiptsError } = await supabase.from('chat_read_receipts').delete().neq('player_id', 0)
    if (receiptsError) console.error('Erreur lors de la suppression des accusés de lecture :', receiptsError)
  }, [fetchAll])

  return { messages, loading, error, refetch: fetchAll, sendMessage, sendTradeMessage, deleteMessage, clearAll }
}
