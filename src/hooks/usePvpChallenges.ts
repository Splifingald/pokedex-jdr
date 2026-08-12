import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { PvpChallenge, PvpPostChallengeResult, PvpWithdrawChallengeStatus } from '../types'
import { generateIdempotencyKey } from '../lib/autoBattle'

// Défis PvP actuellement affichables (un par défenseur au plus, voir
// pvp_post_challenge qui désactive automatiquement tout défi précédent du
// même joueur) — un retrait passe active à false, filtré ici plutôt que
// supprimé (garde l'historique/pvp_challenge_attempts intact, voir schema.sql).
export function usePvpChallenges() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [challenges, setChallenges] = useState<PvpChallenge[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    try {
      const { data, error } = await supabase.from('pvp_challenges').select('*').eq('active', true).order('created_at')
      if (error) throw error
      setChallenges(data ?? [])
    } catch (err) {
      console.error('Erreur lors du chargement des défis PvP :', err)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`pvp-challenges-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'pvp_challenges' }, (payload) => {
        const row = payload.new as PvpChallenge
        if (!row.active) return
        setChallenges((prev) => (prev.some((c) => c.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'pvp_challenges' }, (payload) => {
        const row = payload.new as PvpChallenge
        setChallenges((prev) => (row.active ? prev.map((c) => (c.id === row.id ? row : c)) : prev.filter((c) => c.id !== row.id)))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const postChallenge = useCallback(async (playerId: number, playerPokemonId: number, abilityNoms: string[]) => {
    const { data, error } = await supabase.rpc('pvp_post_challenge', {
      p_player_id: playerId,
      p_player_pokemon_id: playerPokemonId,
      p_ability_noms: abilityNoms,
      p_idempotency_key: generateIdempotencyKey(),
    })
    if (error) {
      console.error('Erreur lors du dépôt du défi PvP :', error)
      return { status: 'invalid_abilities' } as PvpPostChallengeResult
    }
    await fetchAll()
    return data as PvpPostChallengeResult
  }, [fetchAll])

  const withdrawChallenge = useCallback(async (playerId: number, challengeId: number) => {
    const { data, error } = await supabase.rpc('pvp_withdraw_challenge', {
      p_player_id: playerId,
      p_challenge_id: challengeId,
    })
    if (error) {
      console.error('Erreur lors du retrait du défi PvP :', error)
      return 'not_found' as PvpWithdrawChallengeStatus
    }
    setChallenges((prev) => prev.filter((c) => c.id !== challengeId))
    return (data as { status: PvpWithdrawChallengeStatus }).status
  }, [])

  // Suppression DÉFINITIVE (admin, voir AdminPvpPanel) — contrairement à
  // withdrawChallenge, retire la ligne au lieu de la désactiver, ce qui
  // cascade sur pvp_battles/pvp_challenge_attempts (ON DELETE CASCADE, voir
  // schema.sql) et efface donc aussi le tableau des scores du défi.
  const deleteChallenge = useCallback(async (challengeId: number) => {
    const { error } = await supabase.from('pvp_challenges').delete().eq('id', challengeId)
    if (error) {
      console.error('Erreur lors de la suppression du défi PvP :', error)
      return false
    }
    setChallenges((prev) => prev.filter((c) => c.id !== challengeId))
    return true
  }, [])

  return { challenges, loading, postChallenge, withdrawChallenge, deleteChallenge, refetch: fetchAll }
}
