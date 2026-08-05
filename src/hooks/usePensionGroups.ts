import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { PokemonEggGroup, PensionGroupConfig, PensionEggPoolEntry } from '../types'

// Charge et synchronise en temps réel les 3 tables qui définissent les groupes
// d'œufs : l'assignation espèce → groupe (importée par CSV, lecture seule côté
// client), les réglages admin par groupe (créés à la volée ici au premier
// groupe découvert) et la réserve pondérée d'espèces "œuf" par groupe.
export function usePensionGroups() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [eggGroups, setEggGroups] = useState<PokemonEggGroup[]>([])
  const [groupConfigs, setGroupConfigs] = useState<PensionGroupConfig[]>([])
  const [eggPool, setEggPool] = useState<PensionEggPoolEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [eggGroupsRes, groupConfigsRes, eggPoolRes] = await Promise.all([
        supabase.from('pokemon_egg_groups').select('*'),
        supabase.from('pension_group_config').select('*'),
        supabase.from('pension_egg_pool').select('*'),
      ])
      if (eggGroupsRes.error) throw eggGroupsRes.error
      if (groupConfigsRes.error) throw groupConfigsRes.error
      if (eggPoolRes.error) throw eggPoolRes.error
      setEggGroups(eggGroupsRes.data ?? [])
      setGroupConfigs(groupConfigsRes.data ?? [])
      setEggPool(eggPoolRes.data ?? [])

      // Première visite d'un groupe : crée sa ligne de réglages à la volée
      // (même idiome que mining_player_state), pour que l'admin puisse la
      // surcharger sans avoir à "créer" le groupe explicitement.
      const knownGroups = new Set((groupConfigsRes.data ?? []).map((g) => g.groupe))
      const discoveredGroups = [...new Set((eggGroupsRes.data ?? []).map((g) => g.groupe))]
      const missing = discoveredGroups.filter((g) => !knownGroups.has(g))
      if (missing.length > 0) {
        const { data: created, error: insertError } = await supabase
          .from('pension_group_config')
          .insert(missing.map((groupe) => ({ groupe })))
          .select()
        if (!insertError && created) {
          setGroupConfigs((prev) => [...prev, ...(created as PensionGroupConfig[])])
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`pension-groups-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'pokemon_egg_groups' }, (payload) => {
        const row = payload.new as PokemonEggGroup
        setEggGroups((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'pokemon_egg_groups' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setEggGroups((prev) => prev.filter((r) => r.id !== id))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'pension_group_config' }, (payload) => {
        const row = payload.new as PensionGroupConfig
        setGroupConfigs((prev) => (prev.some((r) => r.groupe === row.groupe) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'pension_group_config' }, (payload) => {
        const row = payload.new as PensionGroupConfig
        setGroupConfigs((prev) => prev.map((r) => (r.groupe === row.groupe ? row : r)))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'pension_egg_pool' }, (payload) => {
        const row = payload.new as PensionEggPoolEntry
        setEggPool((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'pension_egg_pool' }, (payload) => {
        const row = payload.new as PensionEggPoolEntry
        setEggPool((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'pension_egg_pool' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setEggPool((prev) => prev.filter((r) => r.id !== id))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const groups = useMemo(() => [...new Set(eggGroups.map((g) => g.groupe))].sort(), [eggGroups])

  const eggGroupsByPokemonNom = useMemo(() => {
    const map = new Map<string, string[]>()
    for (const row of eggGroups) {
      const list = map.get(row.pokemon_nom)
      if (list) list.push(row.groupe)
      else map.set(row.pokemon_nom, [row.groupe])
    }
    return map
  }, [eggGroups])

  const groupConfigByGroup = useMemo(() => {
    const map = new Map<string, PensionGroupConfig>()
    for (const cfg of groupConfigs) map.set(cfg.groupe, cfg)
    return map
  }, [groupConfigs])

  const eggPoolByGroup = useMemo(() => {
    const map = new Map<string, PensionEggPoolEntry[]>()
    for (const entry of eggPool) {
      const list = map.get(entry.groupe)
      if (list) list.push(entry)
      else map.set(entry.groupe, [entry])
    }
    return map
  }, [eggPool])

  const updateGroupConfig = useCallback(async (groupe: string, patch: Partial<Omit<PensionGroupConfig, 'groupe' | 'created_at'>>) => {
    setGroupConfigs((prev) => prev.map((r) => (r.groupe === groupe ? { ...r, ...patch } : r)))
    const { error } = await supabase.from('pension_group_config').update(patch).eq('groupe', groupe)
    if (error) {
      console.error('Erreur lors de la mise à jour des réglages du groupe :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const addEggPoolEntry = useCallback(async (groupe: string, pokemonNom: string, weight: number) => {
    const { data, error } = await supabase
      .from('pension_egg_pool')
      .insert({ groupe, pokemon_nom: pokemonNom, weight })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'ajout de l'espèce œuf :", error)
      return
    }
    const row = data as PensionEggPoolEntry
    setEggPool((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
  }, [])

  const updateEggPoolWeight = useCallback(async (id: number, weight: number) => {
    setEggPool((prev) => prev.map((r) => (r.id === id ? { ...r, weight } : r)))
    const { error } = await supabase.from('pension_egg_pool').update({ weight }).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour du poids :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const removeEggPoolEntry = useCallback(async (id: number) => {
    setEggPool((prev) => prev.filter((r) => r.id !== id))
    const { error } = await supabase.from('pension_egg_pool').delete().eq('id', id)
    if (error) {
      console.error("Erreur lors du retrait de l'espèce œuf :", error)
      await fetchAll()
    }
  }, [fetchAll])

  return {
    eggGroups,
    groupConfigs,
    eggPool,
    groups,
    eggGroupsByPokemonNom,
    groupConfigByGroup,
    eggPoolByGroup,
    loading,
    error,
    updateGroupConfig,
    addEggPoolEntry,
    updateEggPoolWeight,
    removeEggPoolEntry,
    refetch: fetchAll,
  }
}
