import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { MiningPlayerState } from '../types'

export function useMiningPlayerState(playerId: number | null) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [state, setState] = useState<MiningPlayerState | null>(null)
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
        .from('mining_player_state')
        .select('*')
        .eq('player_id', playerId)
        .maybeSingle()
      if (error) throw error
      if (data) {
        setState(data as MiningPlayerState)
      } else {
        // Première visite : crée la ligne à la volée.
        const { data: created, error: insertError } = await supabase
          .from('mining_player_state')
          .insert({ player_id: playerId })
          .select()
          .single()
        if (insertError) throw insertError
        setState(created as MiningPlayerState)
      }
    } catch (err) {
      console.error("Erreur lors du chargement de l'état Fouille :", err)
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
      .channel(`mining-player-state-changes-${playerId}-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'mining_player_state' }, (payload) => {
        const row = payload.new as MiningPlayerState
        if (row.player_id !== playerId) return
        setState(row)
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'mining_player_state' }, (payload) => {
        const row = payload.new as MiningPlayerState
        if (row.player_id !== playerId) return
        setState(row)
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [playerId])

  const updateState = useCallback(async (patch: Partial<Omit<MiningPlayerState, 'player_id'>>) => {
    if (!playerId) return
    setState((prev) => (prev ? { ...prev, ...patch } : prev))
    const { error } = await supabase
      .from('mining_player_state')
      .upsert({ player_id: playerId, ...patch })
    if (error) {
      console.error("Erreur lors de la mise à jour de l'état Fouille :", error)
      await fetchState()
    }
  }, [playerId, fetchState])

  return { state, loading, updateState }
}
