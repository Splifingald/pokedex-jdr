import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { AutoBattlePlayerVariantProgress, AutoBattlePlayerLevelState } from '../types'

// Progression d'un joueur sur toutes les variantes de Combat Auto (niveau
// courant par variante + niveaux découverts/complétés) — lecture temps réel,
// écrite uniquement par le RPC autobattle_resolve_battle (jamais par ce hook).
export function useAutoBattleProgress(playerId: number | null) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [variantProgress, setVariantProgress] = useState<AutoBattlePlayerVariantProgress[]>([])
  const [levelState, setLevelState] = useState<AutoBattlePlayerLevelState[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    if (!playerId) {
      setVariantProgress([])
      setLevelState([])
      setLoading(false)
      return
    }
    setLoading(true)
    try {
      const [progressRes, levelRes] = await Promise.all([
        supabase.from('autobattle_player_variant_progress').select('*').eq('player_id', playerId),
        supabase.from('autobattle_player_level_state').select('*').eq('player_id', playerId),
      ])
      if (progressRes.error) throw progressRes.error
      if (levelRes.error) throw levelRes.error
      setVariantProgress(progressRes.data ?? [])
      setLevelState(levelRes.data ?? [])
    } catch (err) {
      console.error('Erreur lors du chargement de la progression Combat Auto :', err)
    } finally {
      setLoading(false)
    }
  }, [playerId])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    if (!playerId) return
    const channel = supabase
      .channel(`autobattle-progress-changes-${playerId}-${channelId.current}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'autobattle_player_variant_progress' }, (payload) => {
        const row = (payload.new ?? payload.old) as AutoBattlePlayerVariantProgress
        if (row.player_id !== playerId) return
        if (payload.eventType === 'DELETE') {
          setVariantProgress((prev) => prev.filter((r) => r.variant_id !== row.variant_id))
          return
        }
        setVariantProgress((prev) => {
          const exists = prev.some((r) => r.variant_id === row.variant_id)
          return exists ? prev.map((r) => (r.variant_id === row.variant_id ? row : r)) : [...prev, row]
        })
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'autobattle_player_level_state' }, (payload) => {
        const row = (payload.new ?? payload.old) as AutoBattlePlayerLevelState
        if (row.player_id !== playerId) return
        if (payload.eventType === 'DELETE') {
          setLevelState((prev) => prev.filter((r) => r.level_id !== row.level_id))
          return
        }
        setLevelState((prev) => {
          const exists = prev.some((r) => r.level_id === row.level_id)
          return exists ? prev.map((r) => (r.level_id === row.level_id ? row : r)) : [...prev, row]
        })
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [playerId])

  const progressByVariant = useMemo(() => {
    const map = new Map<number, AutoBattlePlayerVariantProgress>()
    for (const row of variantProgress) map.set(row.variant_id, row)
    return map
  }, [variantProgress])

  const stateByLevel = useMemo(() => {
    const map = new Map<number, AutoBattlePlayerLevelState>()
    for (const row of levelState) map.set(row.level_id, row)
    return map
  }, [levelState])

  return { variantProgress, levelState, progressByVariant, stateByLevel, loading, refetch: fetchAll }
}
