import { useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import type { Encounter } from '../types'

export function useEncounters() {
  const [encounters, setEncounters] = useState<Encounter[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('encounters').select('*')
      if (error) throw error
      setEncounters(data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  return { encounters, loading, error, refetch: fetchAll }
}
