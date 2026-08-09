import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { AdminParameters } from '../types'

const DEFAULTS: AdminParameters = {
  id: 1,
  max_moves: 4,
  max_team_size: 3,
  carte_image_url: '',
  carte_couleurs_image_url: '',
  map_addon_image_urls: [],
  accueil_image_url: '',
  feature_pokedex_enabled: true,
  feature_photo_capture_enabled: true,
  feature_pokemon_enabled: true,
  feature_inventory_enabled: true,
  feature_map_enabled: true,
  feature_gifting_enabled: true,
  feature_minijeux_enabled: true,
  feature_mining_enabled: true,
  feature_pension_enabled: true,
  feature_safari_enabled: true,
  feature_autobattle_enabled: true,
  feature_chat_enabled: true,
  chat_max_message_length: 300,
  chat_spam_limit_per_minute: 3,
  chat_last_notified_at: null,
  stat_points_base: 40,
  stat_min: 5,
  stat_max: 15,
  stat_points_per_level: 1,
  stat_charisme_icon_url: '',
  stat_charisme_description: '',
  stat_intelligence_icon_url: '',
  stat_intelligence_description: '',
  stat_sagesse_icon_url: '',
  stat_sagesse_description: '',
  stat_dexterite_icon_url: '',
  stat_dexterite_description: '',
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
