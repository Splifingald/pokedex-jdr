import { useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import type { Background } from '../types'

export function useBackgrounds() {
  const [backgrounds, setBackgrounds] = useState<Background[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('backgrounds').select('*').order('id', { ascending: true })
      if (error) throw error
      setBackgrounds(data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  return { backgrounds, loading, error, refetch: fetchAll }
}
