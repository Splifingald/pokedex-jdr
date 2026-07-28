import { useState, useEffect, useCallback, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { DisplayAsset } from '../types'

export function useDisplayAssets() {
  const [assets, setAssets] = useState<DisplayAsset[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('display_assets').select('*').order('nom', { ascending: true })
      if (error) throw error
      setAssets(data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  const npcs = useMemo(() => assets.filter((a) => a.type === 'NPC'), [assets])

  return { assets, npcs, loading, error, refetch: fetchAll }
}
