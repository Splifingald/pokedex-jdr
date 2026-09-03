import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { OnlineState } from '../types'

// Ligne unique (id = 1) du mode En ligne : annonce de la prochaine session,
// mode de l'écran partagé et configuration du plateau de bataille.
// Même patron que useDisplayState — dont le mode « display » reste piloté par
// la table display_state, inchangée.

export const ONLINE_STATE_DEFAULTS: OnlineState = {
  id: 1,
  session_at: null,
  session_message: '',
  session_announce_enabled: false,
  session_visible_days_before: 5,
  session_notified_at: null,
  mode: 'display',
  battle_background_nom: '',
  grid_cols: 16,
  grid_rows: 10,
  blocked_cells: [],
  colored_cells: {},
  players_sidebar_enabled: true,
  players_move_enabled: true,
  hide_layout: false,
  turn_order: [],
  turn_active_token_id: null,
  turn_order_position: 'top',
  endgame_phase: 'none',
  endgame_outcome: null,
  endgame_rewards: {},
  endgame_acked: [],
  battle_generation: 0,
  updated_at: '',
}

export type UpdateOnlineState = (data: Partial<Omit<OnlineState, 'id' | 'updated_at'>>) => Promise<void>

export function useOnlineState() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [state, setState] = useState<OnlineState>(ONLINE_STATE_DEFAULTS)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchState = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('online_state').select('*').eq('id', 1).single()
      if (error) throw error
      setState({ ...ONLINE_STATE_DEFAULTS, ...(data as OnlineState) })
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
      .channel(`online-state-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'online_state' },
        (payload) => {
          setState({ ...ONLINE_STATE_DEFAULTS, ...(payload.new as OnlineState) })
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  /** Mise à jour locale seule, sans écriture. Sert au coloriage : un glissé
   *  traverse des dizaines de cases et doit repeindre instantanément, mais une
   *  seule écriture groupée suffit (voir OnlineBattlePopup). */
  const patchLocal = useCallback((data: Partial<Omit<OnlineState, 'id' | 'updated_at'>>) => {
    setState((prev) => ({ ...prev, ...data }))
  }, [])

  const updateOnlineState = useCallback<UpdateOnlineState>(async (data) => {
    setState((prev) => ({ ...prev, ...data }))
    const { error } = await supabase.from('online_state').update({ ...data, updated_at: new Date().toISOString() }).eq('id', 1)
    if (error) {
      console.error('Erreur lors de la mise à jour du mode En ligne :', error)
      await fetchState()
    }
  }, [fetchState])

  return { state, loading, error, updateOnlineState, patchLocal, refetch: fetchState }
}
