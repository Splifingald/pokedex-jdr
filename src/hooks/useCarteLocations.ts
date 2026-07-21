import { useState, useEffect, useCallback, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { CarteLocation } from '../types'

export function useCarteLocations() {
  const [locations, setLocations] = useState<CarteLocation[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('carte_locations').select('*')
      if (error) throw error
      setLocations(data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  const byColor = useMemo(() => {
    const map = new Map<string, CarteLocation>()
    for (const l of locations) map.set(l.couleur.toLowerCase(), l)
    return map
  }, [locations])

  return { locations, byColor, loading, error, refetch: fetchAll }
}
