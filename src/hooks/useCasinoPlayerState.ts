import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { CasinoPlayerState } from '../types'

export function useCasinoPlayerState(playerId: number | null) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [state, setState] = useState<CasinoPlayerState | null>(null)
  const [loading, setLoading] = useState(true)

  const fetchState = useCallback(async () => {
    if (!playerId) {
      setState(null)
      setLoading(false)
      return
    }
    setLoading(true)
    try {
      const { data, error } = await supabase
        .from('casino_player_state')
        .select('*')
        .eq('player_id', playerId)
        .maybeSingle()
      if (error) throw error
      if (data) {
        setState(data as CasinoPlayerState)
      } else {
        // Première visite : crée la ligne à la volée.
        const { data: created, error: insertError } = await supabase
          .from('casino_player_state')
          .insert({ player_id: playerId })
          .select()
          .single()
        if (insertError) throw insertError
        setState(created as CasinoPlayerState)
      }
    } catch (err) {
      // Ne pas écraser un état local (potentiellement optimiste) par un état
      // vide sur une erreur transitoire — ça créerait une boucle avec le
      // minuteur de tickets (computeTicketRegen réarme dès que next_ticket_at
      // repasse à null, ce qui redéclenche un nouvel appel en échec, etc.).
      console.error("Erreur lors du chargement de l'état casino :", err)
    } finally {
      setLoading(false)
    }
  }, [playerId])

  useEffect(() => {
    fetchState()
  }, [fetchState])

  useEffect(() => {
    if (!playerId) return
    const channel = supabase
      .channel(`casino-player-state-changes-${playerId}-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'casino_player_state' }, (payload) => {
        const row = payload.new as CasinoPlayerState
        if (row.player_id !== playerId) return
        setState(row)
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'casino_player_state' }, (payload) => {
        const row = payload.new as CasinoPlayerState
        if (row.player_id !== playerId) return
        setState(row)
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [playerId])

  const updateState = useCallback(async (patch: Partial<Omit<CasinoPlayerState, 'player_id'>>) => {
    if (!playerId) return
    setState((prev) => (prev ? { ...prev, ...patch } : prev))
    const { error } = await supabase
      .from('casino_player_state')
      .upsert({ player_id: playerId, ...patch })
    if (error) {
      console.error("Erreur lors de la mise à jour de l'état casino :", error)
      await fetchState()
    }
  }, [playerId, fetchState])

  return { state, loading, updateState }
}
