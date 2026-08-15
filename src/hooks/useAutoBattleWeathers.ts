import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { AutoBattleWeather, AutoBattleWeatherEffect } from '../types'

// Météos et leurs effets (voir autobattle_weathers / autobattle_weather_effects)
// — même forme que useAutoBattleTalents, mais DEUX tables : la météo n'est qu'un
// nom, ses effets vivent dans une table fille (plusieurs par météo, ou aucune —
// une météo sans effet sert de simple condition aux buff/debuff).
// Lues côté serveur par les helpers autobattle_weather_* (supabase/schema.sql),
// côté UI par AdminAutoBattleWeathersPanel et les sélecteurs de météo des
// panneaux Talents et Capacités.
export function useAutoBattleWeathers() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [weathers, setWeathers] = useState<AutoBattleWeather[]>([])
  const [effects, setEffects] = useState<AutoBattleWeatherEffect[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    try {
      const [weathersRes, effectsRes] = await Promise.all([
        supabase.from('autobattle_weathers').select('*').order('id'),
        supabase.from('autobattle_weather_effects').select('*').order('id'),
      ])
      if (weathersRes.error) throw weathersRes.error
      if (effectsRes.error) throw effectsRes.error
      setWeathers(weathersRes.data ?? [])
      setEffects(effectsRes.data ?? [])
    } catch (err) {
      console.error('Erreur lors du chargement des météos :', err)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`autobattle-weathers-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'autobattle_weathers' }, (payload) => {
        const row = payload.new as AutoBattleWeather
        setWeathers((prev) => (prev.some((w) => w.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'autobattle_weathers' }, (payload) => {
        const row = payload.new as AutoBattleWeather
        setWeathers((prev) => prev.map((w) => (w.id === row.id ? row : w)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'autobattle_weathers' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setWeathers((prev) => prev.filter((w) => w.id !== id))
        // ON DELETE CASCADE côté base : les effets partent avec leur météo, mais
        // aucun événement DELETE n'est émis pour eux (la cascade ne déclenche pas
        // la réplication ligne à ligne) — on les retire donc nous-mêmes.
        setEffects((prev) => prev.filter((e) => e.weather_id !== id))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'autobattle_weather_effects' }, (payload) => {
        const row = payload.new as AutoBattleWeatherEffect
        setEffects((prev) => (prev.some((e) => e.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'autobattle_weather_effects' }, (payload) => {
        const row = payload.new as AutoBattleWeatherEffect
        setEffects((prev) => prev.map((e) => (e.id === row.id ? row : e)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'autobattle_weather_effects' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setEffects((prev) => prev.filter((e) => e.id !== id))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  /** Effets groupés par météo, dans l'ordre de création. */
  const effectsByWeather = useMemo(() => {
    const map = new Map<number, AutoBattleWeatherEffect[]>()
    for (const e of effects) {
      const list = map.get(e.weather_id)
      if (list) list.push(e)
      else map.set(e.weather_id, [e])
    }
    return map
  }, [effects])

  /** Noms par id — ce que consomment describeTalent/describeAbilityRule, qui ne voient que des ids. */
  const weatherNames = useMemo(
    () => new Map(weathers.map((w) => [w.id, w.nom] as const)),
    [weathers],
  )

  /** Renvoie l'id créé (pour scroller/surligner la nouvelle carte), ou null. */
  const addWeather = useCallback(async (nom: string) => {
    const { data, error } = await supabase
      .from('autobattle_weathers')
      .insert({ nom })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'ajout de la météo :", error)
      return null
    }
    const row = data as AutoBattleWeather
    setWeathers((prev) => (prev.some((w) => w.id === row.id) ? prev : [...prev, row]))
    return row.id
  }, [])

  const updateWeather = useCallback(async (id: number, patch: Partial<Omit<AutoBattleWeather, 'id' | 'created_at'>>) => {
    setWeathers((prev) => prev.map((w) => (w.id === id ? { ...w, ...patch } : w)))
    const { error } = await supabase.from('autobattle_weathers').update(patch).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour de la météo :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const removeWeather = useCallback(async (id: number) => {
    setWeathers((prev) => prev.filter((w) => w.id !== id))
    setEffects((prev) => prev.filter((e) => e.weather_id !== id))
    const { error } = await supabase.from('autobattle_weathers').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors du retrait de la météo :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const addEffect = useCallback(async (weatherId: number) => {
    const { data, error } = await supabase
      .from('autobattle_weather_effects')
      // Groupe par défaut d'un 'stat_mod' : seul jeu de champs qui satisfait
      // autobattle_weather_effects_fields à la création.
      .insert({ weather_id: weatherId, kind: 'stat_mod', stat: 'precision', amount: 1, target_scope: 'pokemon_type' })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'ajout de l'effet météo :", error)
      return null
    }
    const row = data as AutoBattleWeatherEffect
    setEffects((prev) => (prev.some((e) => e.id === row.id) ? prev : [...prev, row]))
    return row.id
  }, [])

  const updateEffect = useCallback(async (id: number, patch: Partial<Omit<AutoBattleWeatherEffect, 'id' | 'weather_id' | 'created_at'>>) => {
    setEffects((prev) => prev.map((e) => (e.id === id ? { ...e, ...patch } : e)))
    const { error } = await supabase.from('autobattle_weather_effects').update(patch).eq('id', id)
    if (error) {
      console.error("Erreur lors de la mise à jour de l'effet météo :", error)
      await fetchAll()
    }
  }, [fetchAll])

  const removeEffect = useCallback(async (id: number) => {
    setEffects((prev) => prev.filter((e) => e.id !== id))
    const { error } = await supabase.from('autobattle_weather_effects').delete().eq('id', id)
    if (error) {
      console.error("Erreur lors du retrait de l'effet météo :", error)
      await fetchAll()
    }
  }, [fetchAll])

  return {
    weathers, effects, effectsByWeather, weatherNames, loading,
    addWeather, updateWeather, removeWeather,
    addEffect, updateEffect, removeEffect,
  }
}
