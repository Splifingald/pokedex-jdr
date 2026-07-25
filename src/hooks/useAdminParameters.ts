import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { AdminParameters } from '../types'

const DEFAULTS: AdminParameters = {
  id: 1,
  max_moves: 4,
  max_team_size: 3,
  carte_image_url: '',
  carte_couleurs_image_url: '',
  accueil_image_url: '',
  feature_pokedex_enabled: true,
  feature_photo_capture_enabled: true,
  feature_pokemon_enabled: true,
  feature_inventory_enabled: true,
  feature_map_enabled: true,
  feature_gifting_enabled: true,
}

export function useAdminParameters() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [parameters, setParameters] = useState<AdminParameters>(DEFAULTS)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchParameters = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('admin_parameters').select('*').eq('id', 1).single()
      if (error) throw error
      setParameters({ ...DEFAULTS, ...(data as AdminParameters) })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchParameters()
  }, [fetchParameters])

  useEffect(() => {
    const channel = supabase
      .channel(`admin-parameters-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'admin_parameters' },
        (payload) => {
          setParameters({ ...DEFAULTS, ...(payload.new as AdminParameters) })
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const updateParameters = useCallback(async (data: Partial<Omit<AdminParameters, 'id'>>) => {
    setParameters((prev) => ({ ...prev, ...data }))
    const { error } = await supabase.from('admin_parameters').update(data).eq('id', 1)
    if (error) {
      console.error('Erreur lors de la mise à jour des paramètres :', error)
      await fetchParameters()
    }
  }, [fetchParameters])

  return { parameters, loading, error, updateParameters }
}
