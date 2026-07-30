import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { DisplayState } from '../types'

const DEFAULTS: DisplayState = {
  id: 1,
  background_id: null,
  background_url: null,
  npc_ids: [],
  pokemon_ids: [],
  item_ids: [],
  updated_at: '',
}

export function useDisplayState() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [state, setState] = useState<DisplayState>(DEFAULTS)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchState = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('display_state').select('*').eq('id', 1).single()
      if (error) throw error
      setState({ ...DEFAULTS, ...(data as DisplayState) })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchState()
  }, [fetchState])

  useEffect(() => {
    const channel = supabase
      .channel(`display-state-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'display_state' },
        (payload) => {
          setState({ ...DEFAULTS, ...(payload.new as DisplayState) })
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const updateDisplayState = useCallback(async (data: Partial<Omit<DisplayState, 'id' | 'updated_at'>>) => {
    setState((prev) => ({ ...prev, ...data }))
    const { error } = await supabase.from('display_state').update(data).eq('id', 1)
    if (error) {
      console.error("Erreur lors de la mise à jour de l'affichage :", error)
      await fetchState()
    }
  }, [fetchState])

  return { state, loading, error, updateDisplayState }
}
