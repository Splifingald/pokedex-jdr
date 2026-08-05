import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { MinigamesConfig } from '../types'

const DEFAULTS: MinigamesConfig = {
  id: 1,
  ticket_max: 3,
  ticket_regen_amount: 24,
  ticket_regen_unit: 'hours',
  ticket_buy_cost: 0,
  ticket_daily_buy_cap: 3,
  ticket_full_notify_enabled: false,
  magikarp_enabled: true,
  magikarp_nom: 'Magikarp',
  magikarp_icon_url: '/website_icons/icon_magikarp_game.png',
  magikarp_banner_url: '',
  magikarp_numero: '129',
  magikarp_duration_seconds: 10,
  magikarp_star1_taps: 20,
  magikarp_star2_taps: 30,
  magikarp_star3_taps: 50,
  magikarp_star1_xp: 5,
  magikarp_star2_xp: 10,
  magikarp_star3_xp: 20,
}

export function useMinigamesConfig() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [config, setConfig] = useState<MinigamesConfig>(DEFAULTS)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchConfig = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('minigames_config').select('*').eq('id', 1).single()
      if (error) throw error
      setConfig({ ...DEFAULTS, ...(data as MinigamesConfig) })
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
      .channel(`minigames-config-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'minigames_config' },
        (payload) => {
          setConfig({ ...DEFAULTS, ...(payload.new as MinigamesConfig) })
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const updateConfig = useCallback(async (data: Partial<Omit<MinigamesConfig, 'id'>>) => {
    setConfig((prev) => ({ ...prev, ...data }))
    const { error } = await supabase.from('minigames_config').update(data).eq('id', 1)
    if (error) {
      console.error('Erreur lors de la mise à jour de la config mini-jeux :', error)
      await fetchConfig()
    }
  }, [fetchConfig])

  return { config, loading, error, updateConfig }
}
