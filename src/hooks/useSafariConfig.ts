import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { SafariConfig } from '../types'

const DEFAULTS: SafariConfig = {
  id: 1,
  nom: 'Safari',
  icon_url: '/website_icons/icon_safari_game.png',
  banner_url: '',
  session_duration_amount: 72,
  session_duration_unit: 'hours',
  berry_min_increase: 5,
  berry_max_increase: 15,
  berry_reward_amount: 1,
  berry_reward_interval_amount: 0,
  berry_reward_interval_unit: 'hours',
  berry_reward_max: 5,
  ball_reward_amount: 1,
  ball_reward_interval_amount: 0,
  ball_reward_interval_unit: 'hours',
  ball_reward_max: 3,
}

export function useSafariConfig() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [config, setConfig] = useState<SafariConfig>(DEFAULTS)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchConfig = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('safari_config').select('*').eq('id', 1).single()
      if (error) throw error
      setConfig({ ...DEFAULTS, ...(data as SafariConfig) })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchConfig()
  }, [fetchConfig])

  useEffect(() => {
    const channel = supabase
      .channel(`safari-config-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'safari_config' }, (payload) => {
        setConfig({ ...DEFAULTS, ...(payload.new as SafariConfig) })
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const updateConfig = useCallback(async (data: Partial<Omit<SafariConfig, 'id'>>) => {
    setConfig((prev) => ({ ...prev, ...data }))
    const { error } = await supabase.from('safari_config').update(data).eq('id', 1)
    if (error) {
      console.error('Erreur lors de la mise à jour de la config Safari :', error)
      await fetchConfig()
    }
  }, [fetchConfig])

  return { config, loading, error, updateConfig }
}
