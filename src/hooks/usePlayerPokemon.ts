import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { PlayerPokemon } from '../types'

export function usePlayerPokemon(playerId: number | null) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [roster, setRoster] = useState<PlayerPokemon[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    if (!playerId) {
      setRoster([])
      setLoading(false)
      return
    }
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase
        .from('player_pokemon')
        .select('*')
        .eq('player_id', playerId)
        .order('created_at')
      if (error) throw error
      setRoster(data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [playerId])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  // Abonnement temps réel : filtré côté client comme discovered_pokemon
  useEffect(() => {
    if (!playerId) return
    const channel = supabase
      .channel(`player-pokemon-changes-${playerId}-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'player_pokemon' },
        (payload) => {
          const row = payload.new as PlayerPokemon
          if (row.player_id !== playerId) return
          setRoster((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'player_pokemon' },
        (payload) => {
          const row = payload.new as PlayerPokemon
          if (row.player_id !== playerId) return
          setRoster((prev) => prev.map((r) => (r.id === row.id ? row : r)))
        }
      )
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table: 'player_pokemon' },
        (payload) => {
          const id = (payload.old as { id: number }).id
          setRoster((prev) => prev.filter((r) => r.id !== id))
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [playerId])

  const addOwnedPokemon = useCallback(async (nom: string, numero: string) => {
    if (!playerId) return null
    const { data, error } = await supabase
      .from('player_pokemon')
      .insert({ player_id: playerId, pokemon_nom: nom, pokemon_numero: numero })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'ajout au roster :", error)
      return null
    }
    setRoster((prev) => [...prev, data as PlayerPokemon])
    return data as PlayerPokemon
  }, [playerId])

  const updateXp = useCallback(async (id: number, xp: number) => {
    setRoster((prev) => prev.map((r) => (r.id === id ? { ...r, xp } : r)))
    const { error } = await supabase.from('player_pokemon').update({ xp }).eq('id', id)
    if (error) {
      console.error("Erreur lors de la mise à jour de l'XP :", error)
    }
  }, [])

  const toggleInTeam = useCallback(async (id: number, inTeam: boolean) => {
    setRoster((prev) => prev.map((r) => (r.id === id ? { ...r, in_team: inTeam } : r)))
    const { error } = await supabase.from('player_pokemon').update({ in_team: inTeam }).eq('id', id)
    if (error) {
      console.error("Erreur lors du changement d'équipe :", error)
      setRoster((prev) => prev.map((r) => (r.id === id ? { ...r, in_team: !inTeam } : r)))
    }
  }, [])

  const setMoves = useCallback(async (id: number, moves: string[]) => {
    setRoster((prev) => prev.map((r) => (r.id === id ? { ...r, moves } : r)))
    const { error } = await supabase.from('player_pokemon').update({ moves }).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour des capacités :', error)
    }
  }, [])

  const addMove = useCallback((id: number, moveName: string) => {
    const current = roster.find((r) => r.id === id)
    if (!current) return
    if (current.moves.includes(moveName)) return
    return setMoves(id, [...current.moves, moveName])
  }, [roster, setMoves])

  const removeMove = useCallback((id: number, moveName: string) => {
    const current = roster.find((r) => r.id === id)
    if (!current) return
    return setMoves(id, current.moves.filter((m) => m !== moveName))
  }, [roster, setMoves])

  const deleteOwnedPokemon = useCallback(async (id: number) => {
    setRoster((prev) => prev.filter((r) => r.id !== id))
    const { error } = await supabase.from('player_pokemon').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors de la suppression du pokémon :', error)
      await fetchAll()
    }
  }, [fetchAll])

  return {
    roster,
    loading,
    error,
    addOwnedPokemon,
    updateXp,
    toggleInTeam,
    addMove,
    removeMove,
    deleteOwnedPokemon,
    refetch: fetchAll,
  }
}
