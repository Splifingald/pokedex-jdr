import { useState, useEffect, useCallback, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { PokemonEvolution } from '../types'

export function usePokemonEvolutions() {
  const [evolutions, setEvolutions] = useState<PokemonEvolution[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('pokemon_evolutions').select('*')
      if (error) throw error
      setEvolutions(data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  const byPokemonNom = useMemo(() => {
    const map = new Map<string, PokemonEvolution[]>()
    for (const e of evolutions) {
      const list = map.get(e.pokemon_nom) ?? []
      list.push(e)
      map.set(e.pokemon_nom, list)
    }
    return map
  }, [evolutions])

  return { evolutions, byPokemonNom, loading, error, refetch: fetchAll }
}
