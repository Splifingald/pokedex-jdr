import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { OnlineBattleLogRow } from '../types'

// Journal simplifié du combat : une ligne par Pokémon ayant participé, y
// compris ceux qui ont quitté le plateau (retirés, remplacés, mis K.O.).
// Alimenté côté serveur par online_place_token / online_remove_token, pour
// qu'un remplacement de Pokémon — qui ne passe par aucun retrait explicite —
// soit malgré tout consigné.
//
// Monté uniquement quand on en a besoin (bilan de fin de partie).
export function useBattleLog(enabled: boolean) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [rows, setRows] = useState<OnlineBattleLogRow[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    if (!enabled) {
      setRows([])
      setLoading(false)
      return
    }
    setLoading(true)
    try {
      const { data, error } = await supabase.from('online_battle_log').select('*').order('created_at')
      if (error) throw error
      setRows((data ?? []) as OnlineBattleLogRow[])
    } catch (err) {
      console.error('Erreur de chargement du journal de bataille :', err)
    } finally {
      setLoading(false)
    }
  }, [enabled])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    if (!enabled) return
    const channel = supabase
      .channel(`online-battle-log-changes-${channelId.current}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'online_battle_log' }, () => {
        void fetchAll()
      })
      .subscribe()
    return () => {
      supabase.removeChannel(channel)
    }
  }, [enabled, fetchAll])

  return { rows, loading, refetch: fetchAll }
}
