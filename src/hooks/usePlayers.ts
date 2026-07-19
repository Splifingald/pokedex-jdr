import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { Player } from '../types'

export function usePlayers() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [players, setPlayers] = useState<Player[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('players').select('*').order('name')
      if (error) throw error
      setPlayers(data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  // Abonnement temps réel : synchro entre appareils
  useEffect(() => {
    const channel = supabase
      .channel(`players-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'players' },
        (payload) => {
          const player = payload.new as Player
          setPlayers((prev) => (prev.some((p) => p.id === player.id) ? prev : [...prev, player].sort((a, b) => a.name.localeCompare(b.name))))
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'players' },
        (payload) => {
          const player = payload.new as Player
          setPlayers((prev) => prev.map((p) => (p.id === player.id ? player : p)))
        }
      )
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table: 'players' },
        (payload) => {
          const id = (payload.old as { id: number }).id
          setPlayers((prev) => prev.filter((p) => p.id !== id))
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const createPlayer = useCallback(async (data: { name: string; color: string; image_url: string }) => {
    const { data: created, error } = await supabase.from('players').insert(data).select().single()
    if (error) {
      console.error('Erreur lors de la création du joueur :', error)
      return null
    }
    setPlayers((prev) => [...prev, created as Player].sort((a, b) => a.name.localeCompare(b.name)))
    return created as Player
  }, [])

  const updatePlayer = useCallback(async (id: number, data: { name: string; color: string; image_url: string }) => {
    setPlayers((prev) => prev.map((p) => (p.id === id ? { ...p, ...data } : p)))
    const { error } = await supabase.from('players').update(data).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour du joueur :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const deletePlayer = useCallback(async (id: number) => {
    setPlayers((prev) => prev.filter((p) => p.id !== id))
    // Pas de FK : on supprime explicitement le roster du joueur avant le joueur lui-même
    const { error: rosterError } = await supabase.from('player_pokemon').delete().eq('player_id', id)
    if (rosterError) {
      console.error('Erreur lors de la suppression du roster :', rosterError)
    }
    const { error } = await supabase.from('players').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors de la suppression du joueur :', error)
      await fetchAll()
    }
  }, [fetchAll])

  return { players, loading, error, createPlayer, updatePlayer, deletePlayer, refetch: fetchAll }
}
