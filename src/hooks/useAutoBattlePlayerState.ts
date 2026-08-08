import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { AutoBattlePlayerState } from '../types'

export function useAutoBattlePlayerState(playerId: number | null) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [state, setState] = useState<AutoBattlePlayerState | null>(null)
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
        .from('autobattle_player_state')
        .select('*')
        .eq('player_id', playerId)
        .maybeSingle()
      if (error) throw error
      if (data) {
        setState(data as AutoBattlePlayerState)
      } else {
        const { data: created, error: insertError } = await supabase
          .from('autobattle_player_state')
          .insert({ player_id: playerId })
          .select()
          .single()
        if (insertError) throw insertError
        setState(created as AutoBattlePlayerState)
      }
    } catch (err) {
      console.error("Erreur lors du chargement de l'état Combat Auto :", err)
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
      .channel(`autobattle-player-state-changes-${playerId}-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'autobattle_player_state' }, (payload) => {
        const row = payload.new as AutoBattlePlayerState
        if (row.player_id !== playerId) return
        setState(row)
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'autobattle_player_state' }, (payload) => {
        const row = payload.new as AutoBattlePlayerState
        if (row.player_id !== playerId) return
        setState(row)
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [playerId])

  const updateState = useCallback(async (patch: Partial<Omit<AutoBattlePlayerState, 'player_id'>>) => {
    if (!playerId) return
    setState((prev) => (prev ? { ...prev, ...patch } : prev))
    const { error } = await supabase
      .from('autobattle_player_state')
      .upsert({ player_id: playerId, ...patch })
    if (error) {
      console.error("Erreur lors de la mise à jour de l'état Combat Auto :", error)
      await fetchState()
    }
  }, [playerId, fetchState])

  return { state, loading, updateState }
}
