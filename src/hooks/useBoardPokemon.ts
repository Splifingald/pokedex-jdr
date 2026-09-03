import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { PlayerPokemon } from '../types'
import { primeVitals } from '../lib/pokemonVitals'

// Toutes les lignes player_pokemon, pas seulement celles du joueur courant :
// le plateau affiche les Pokémon de tout le monde et le MJ peut incarner
// n'importe quel personnage. Monté uniquement quand un plateau est visible,
// pour ne pas charger le roster de tous les joueurs sur l'écran d'accueil.

export function useBoardPokemon(enabled: boolean) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [rows, setRows] = useState<PlayerPokemon[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    if (!enabled) {
      setRows([])
      setLoading(false)
      return
    }
    setLoading(true)
    try {
      const { data, error } = await supabase.from('player_pokemon').select('*').order('id')
      if (error) throw error
      setRows((data ?? []) as PlayerPokemon[])
    } catch (err) {
      console.error('Erreur de chargement des Pokémon du plateau :', err)
    } finally {
      setLoading(false)
    }
  }, [enabled])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    if (rows.length > 0) primeVitals(rows)
  }, [rows])

  useEffect(() => {
    if (!enabled) return
    const channel = supabase
      .channel(`board-pokemon-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'player_pokemon' }, (payload) => {
        const row = payload.new as PlayerPokemon
        setRows((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'player_pokemon' }, (payload) => {
        const row = payload.new as PlayerPokemon
        setRows((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'player_pokemon' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setRows((prev) => prev.filter((r) => r.id !== id))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [enabled])

  const byId = useMemo(() => new Map(rows.map((r) => [r.id, r])), [rows])
  const byPlayerId = useMemo(() => {
    const map = new Map<number, PlayerPokemon[]>()
    for (const r of rows) {
      const list = map.get(r.player_id)
      if (list) list.push(r)
      else map.set(r.player_id, [r])
    }
    return map
  }, [rows])

  return { rows, byId, byPlayerId, loading, refetch: fetchAll }
}
