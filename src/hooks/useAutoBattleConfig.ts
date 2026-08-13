import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { AutoBattleConfig } from '../types'

const DEFAULTS: AutoBattleConfig = {
  id: 1,
  ticket_max: 3,
  ticket_regen_amount: 24,
  ticket_regen_unit: 'hours',
  ticket_buy_cost: 0,
  ticket_daily_buy_cap: 3,
  ticket_full_notify_enabled: false,
  nom: 'Combat Auto',
  icon_url: '',
  precision_enabled: true,
  mode_icon_auto_url: '',
  mode_icon_manual_url: '',
}

export function useAutoBattleConfig() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [config, setConfig] = useState<AutoBattleConfig>(DEFAULTS)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchConfig = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('autobattle_config').select('*').eq('id', 1).single()
      if (error) throw error
      setConfig({ ...DEFAULTS, ...(data as AutoBattleConfig) })
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
      .channel(`autobattle-config-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'autobattle_config' },
        (payload) => {
          setConfig({ ...DEFAULTS, ...(payload.new as AutoBattleConfig) })
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const updateConfig = useCallback(async (data: Partial<Omit<AutoBattleConfig, 'id'>>) => {
    setConfig((prev) => ({ ...prev, ...data }))
    const { error } = await supabase.from('autobattle_config').update(data).eq('id', 1)
    if (error) {
      console.error('Erreur lors de la mise à jour de la config Combat Auto :', error)
      await fetchConfig()
    }
  }, [fetchConfig])

  return { config, loading, error, updateConfig }
}
