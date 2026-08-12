import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { PvpChallengeAttempt } from '../types'

// Tableau des scores de toutes les bannières PvP actives — une ligne par
// tentative résolue (voir pvp_challenge_attempts), groupée côté client par
// challenge_id pour l'affichage sous chaque bannière (voir PvpChallengeBanner).
export function usePvpChallengeAttempts() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [attempts, setAttempts] = useState<PvpChallengeAttempt[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    try {
      const { data, error } = await supabase.from('pvp_challenge_attempts').select('*').order('created_at', { ascending: false })
      if (error) throw error
      setAttempts(data ?? [])
    } catch (err) {
      console.error('Erreur lors du chargement du tableau des scores PvP :', err)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`pvp-challenge-attempts-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'pvp_challenge_attempts' }, (payload) => {
        const row = payload.new as PvpChallengeAttempt
        setAttempts((prev) => (prev.some((a) => a.id === row.id) ? prev : [row, ...prev]))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const attemptsByChallenge = useMemo(() => {
    const map = new Map<number, PvpChallengeAttempt[]>()
    for (const a of attempts) {
      const list = map.get(a.challenge_id)
      if (list) list.push(a)
      else map.set(a.challenge_id, [a])
    }
    return map
  }, [attempts])

  // Suppression d'une seule ligne du tableau des scores (admin, voir
  // AdminPvpPanel/PvpChallengeBanner) — n'affecte ni le défi ni les autres
  // tentatives.
  const deleteAttempt = useCallback(async (attemptId: number) => {
    const { error } = await supabase.from('pvp_challenge_attempts').delete().eq('id', attemptId)
    if (error) {
      console.error('Erreur lors de la suppression de la tentative PvP :', error)
      return false
    }
    setAttempts((prev) => prev.filter((a) => a.id !== attemptId))
    return true
  }, [])

  return { attempts, attemptsByChallenge, loading, deleteAttempt }
}
