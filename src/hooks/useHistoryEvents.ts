import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { HistoryEvent } from '../types'

// Journal complet, non filtré par joueur — l'onglet Admin → Historique filtre
// côté client (joueur, catégorie, recherche texte).
export function useHistoryEvents() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [events, setEvents] = useState<HistoryEvent[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('history_events').select('*').order('created_at')
      if (error) throw error
      setEvents((data as HistoryEvent[]) ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  // Table immuable côté client (pas d'UPDATE/DELETE) : seul INSERT est écouté.
  useEffect(() => {
    const channel = supabase
      .channel(`history-events-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'history_events' },
        (payload) => {
          const row = payload.new as HistoryEvent
          setEvents((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  return { events, loading, error, refetch: fetchAll }
}
