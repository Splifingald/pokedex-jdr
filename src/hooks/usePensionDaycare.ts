import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { PlayerPokemon, PensionPair } from '../types'

export type PensionActionStatus =
  | 'ok'
  | 'not_owner'
  | 'must_be_in_pc'
  | 'already_placed'
  | 'permanently_capped'
  | 'player_slot_taken'
  | 'daycare_full'
  | 'not_placed'
  | 'error'

// État global de la Pension (tous joueurs confondus) : qui y est actuellement
// placé + les appariements en cours pour la production d'œufs. Distinct
// d'usePlayerPokemon (qui ne charge que le roster d'UN joueur) — cette table
// doit être lue sans filtre par joueur.
export function usePensionDaycare(playerId: number | null) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [daycareRoster, setDaycareRoster] = useState<PlayerPokemon[]>([])
  const [pairs, setPairs] = useState<PensionPair[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [rosterRes, pairsRes] = await Promise.all([
        supabase.from('player_pokemon').select('*').eq('in_daycare', true),
        supabase.from('pension_pairs').select('*'),
      ])
      if (rosterRes.error) throw rosterRes.error
      if (pairsRes.error) throw pairsRes.error
      setDaycareRoster(rosterRes.data ?? [])
      setPairs(pairsRes.data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`pension-daycare-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'player_pokemon' }, (payload) => {
        const row = payload.new as PlayerPokemon
        setDaycareRoster((prev) => {
          if (!row.in_daycare) return prev.filter((r) => r.id !== row.id)
          return prev.some((r) => r.id === row.id) ? prev.map((r) => (r.id === row.id ? row : r)) : [...prev, row]
        })
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'player_pokemon' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setDaycareRoster((prev) => prev.filter((r) => r.id !== id))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'pension_pairs' }, (payload) => {
        const row = payload.new as PensionPair
        setPairs((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'pension_pairs' }, (payload) => {
        const row = payload.new as PensionPair
        setPairs((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'pension_pairs' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setPairs((prev) => prev.filter((r) => r.id !== id))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const myDaycarePokemon = useMemo(
    () => (playerId ? daycareRoster.find((r) => r.player_id === playerId) ?? null : null),
    [daycareRoster, playerId]
  )

  const pairsByPokemonId = useMemo(() => {
    const map = new Map<number, PensionPair[]>()
    for (const pair of pairs) {
      for (const id of [pair.pokemon_a_id, pair.pokemon_b_id]) {
        const list = map.get(id)
        if (list) list.push(pair)
        else map.set(id, [pair])
      }
    }
    return map
  }, [pairs])

  const placeInDaycare = useCallback(async (playerPokemonId: number): Promise<PensionActionStatus> => {
    if (!playerId) return 'error'
    const { data, error } = await supabase.rpc('pension_place', { p_player_pokemon_id: playerPokemonId, p_player_id: playerId })
    if (error) {
      console.error('Erreur lors du placement en pension :', error)
      return 'error'
    }
    const status = (data as { status: PensionActionStatus })?.status ?? 'error'
    // Recharge explicitement plutôt que de compter uniquement sur le Realtime
    // (pas de ligne player_pokemon complète en main ici pour une mise à jour
    // optimiste) : évite de devoir fermer/rouvrir le popup pour voir le
    // placement pris en compte.
    if (status === 'ok') await fetchAll()
    return status
  }, [playerId, fetchAll])

  const retrieveFromDaycare = useCallback(async (playerPokemonId: number): Promise<PensionActionStatus> => {
    if (!playerId) return 'error'
    const { data, error } = await supabase.rpc('pension_retrieve', { p_player_pokemon_id: playerPokemonId, p_player_id: playerId })
    if (error) {
      console.error('Erreur lors du retrait de la pension :', error)
      return 'error'
    }
    const status = (data as { status: PensionActionStatus })?.status ?? 'error'
    if (status === 'ok') {
      setDaycareRoster((prev) => prev.filter((r) => r.id !== playerPokemonId))
      await fetchAll()
    }
    return status
  }, [playerId, fetchAll])

  return {
    daycareRoster,
    pairs,
    pairsByPokemonId,
    myDaycarePokemon,
    loading,
    error,
    placeInDaycare,
    retrieveFromDaycare,
    refetch: fetchAll,
  }
}
