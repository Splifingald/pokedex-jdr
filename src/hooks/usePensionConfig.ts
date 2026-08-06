import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { PensionConfig } from '../types'

const DEFAULTS: PensionConfig = {
  id: 1,
  nom: 'Pension Pokémon',
  icon_url: '/website_icons/icon_daycare_game.png',
  banner_url: '',
  capacity_total: 3,
  tick_xp_amount: 1,
  tick_interval_amount: 2,
  tick_interval_unit: 'hours',
  default_lifetime_xp_cap: 50,
  default_hatch_timer_min: 24,
  default_hatch_timer_max: 48,
  default_hatch_timer_unit: 'hours',
  info_text:
    "Chaque dresseur ne peut avoir qu'un pokémon en pension.\n" +
    "Il y a des limites d'expérience cumulable en pension.\n" +
    "Les pokémon de dresseurs différents peuvent produire des œufs s'ils sont compatibles — dans ce cas, l'œuf est donné à l'un des deux dresseurs, au hasard.\n" +
    "Les œufs reçus peuvent contenir tout type de pokémon, la dame de la pension s'amuse à les mélanger pour faire des surprises aux dresseurs !",
}

export function usePensionConfig() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [config, setConfig] = useState<PensionConfig>(DEFAULTS)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchConfig = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('pension_config').select('*').eq('id', 1).single()
      if (error) throw error
      setConfig({ ...DEFAULTS, ...(data as PensionConfig) })
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
      .channel(`pension-config-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'pension_config' },
        (payload) => {
          setConfig({ ...DEFAULTS, ...(payload.new as PensionConfig) })
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const updateConfig = useCallback(async (data: Partial<Omit<PensionConfig, 'id'>>) => {
    setConfig((prev) => ({ ...prev, ...data }))
    const { error } = await supabase.from('pension_config').update(data).eq('id', 1)
    if (error) {
      console.error('Erreur lors de la mise à jour de la config Pension :', error)
      await fetchConfig()
    }
  }, [fetchConfig])

  return { config, loading, error, updateConfig }
}
