import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { MiningConfig } from '../types'

const DEFAULTS: MiningConfig = {
  id: 1,
  ticket_max: 3,
  ticket_regen_amount: 24,
  ticket_regen_unit: 'hours',
  ticket_buy_cost: 0,
  ticket_daily_buy_cap: 3,
  ticket_full_notify_enabled: false,
  nom: 'Fouille',
  icon_url: '/website_icons/icon_digging_game.png',
  banner_url: '',
  hidden_cell_image_url: '',
  empty_cell_image_url: '',
  grid_size_min: 4,
  grid_size_max: 6,
  fill_ratio_pct: 20,
  move_budget_pct: 50,
  next_custom_grid_id: null,
}

export function useMiningConfig() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [config, setConfig] = useState<MiningConfig>(DEFAULTS)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchConfig = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('mining_config').select('*').eq('id', 1).single()
      if (error) throw error
      setConfig({ ...DEFAULTS, ...(data as MiningConfig) })
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
      .channel(`mining-config-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'mining_config' },
        (payload) => {
          setConfig({ ...DEFAULTS, ...(payload.new as MiningConfig) })
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const updateConfig = useCallback(async (data: Partial<Omit<MiningConfig, 'id'>>) => {
    setConfig((prev) => ({ ...prev, ...data }))
    const { error } = await supabase.from('mining_config').update(data).eq('id', 1)
    if (error) {
      console.error('Erreur lors de la mise à jour de la config Fouille :', error)
      await fetchConfig()
    }
  }, [fetchConfig])

  return { config, loading, error, updateConfig }
}
