import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { CasinoConfig } from '../types'

const DEFAULTS: CasinoConfig = {
  id: 1,
  ticket_max: 3,
  ticket_regen_amount: 24,
  ticket_regen_unit: 'hours',
  ticket_buy_cost: 100,
  ticket_daily_buy_cap: 3,
  ticket_full_notify_enabled: false,
  slots_enabled: true,
  slots_nom: 'Chance de Miaouss',
  slots_icon_url: '',
  slots_banner_url: '',
  slots_pokeball_value: 10,
  slots_superball_value: 20,
  slots_hyperball_value: 50,
  slots_masterball_value: 200,
  slots_pokeball_weight: 1,
  slots_superball_weight: 1,
  slots_hyperball_weight: 1,
  slots_masterball_weight: 1,
  slots_match2_multiplier: 3,
  slots_match3_multiplier: 10,
  dice_enabled: true,
  dice_nom: 'Dé Chance',
  dice_icon_url: '',
  dice_banner_url: '',
  dice_max_rounds: 3,
  dice_initial_gain: 100,
  dice_ai_target_min: 13,
  dice_ai_target_max: 17,
  dice_opponent_name: 'Le Croupier',
  dice_opponent_image_url: '',
}

export function useCasinoConfig() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [config, setConfig] = useState<CasinoConfig>(DEFAULTS)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchConfig = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('casino_config').select('*').eq('id', 1).single()
      if (error) throw error
      setConfig({ ...DEFAULTS, ...(data as CasinoConfig) })
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
      .channel(`casino-config-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'casino_config' },
        (payload) => {
          setConfig({ ...DEFAULTS, ...(payload.new as CasinoConfig) })
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const updateConfig = useCallback(async (data: Partial<Omit<CasinoConfig, 'id'>>) => {
    setConfig((prev) => ({ ...prev, ...data }))
    const { error } = await supabase.from('casino_config').update(data).eq('id', 1)
    if (error) {
      console.error('Erreur lors de la mise à jour de la config casino :', error)
      await fetchConfig()
    }
  }, [fetchConfig])

  return { config, loading, error, updateConfig }
}
