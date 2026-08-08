import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { SafariGroup, SafariGroupPokemon, SafariGaugeArea } from '../types'

// CRUD complet des groupes Safari (contrairement à la Pension dont les
// groupes viennent d'un import CSV) : groupes + leurs pokémon pondérés +
// leurs zones de jauge (propres à chaque groupe, voir schema.sql).
export function useSafariGroups() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [groups, setGroups] = useState<SafariGroup[]>([])
  const [groupPokemon, setGroupPokemon] = useState<SafariGroupPokemon[]>([])
  const [gaugeAreas, setGaugeAreas] = useState<SafariGaugeArea[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [groupsRes, pokemonRes, areasRes] = await Promise.all([
        supabase.from('safari_groups').select('*').order('id'),
        supabase.from('safari_group_pokemon').select('*'),
        supabase.from('safari_gauge_areas').select('*').order('sort_order'),
      ])
      if (groupsRes.error) throw groupsRes.error
      if (pokemonRes.error) throw pokemonRes.error
      if (areasRes.error) throw areasRes.error
      setGroups(groupsRes.data ?? [])
      setGroupPokemon(pokemonRes.data ?? [])
      setGaugeAreas(areasRes.data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  // Fusion ligne par ligne (pas de refetch complet sur chaque événement) :
  // un refetch global ici rechargeait toute la page admin — y compris pendant
  // que l'admin est en train de taper dans un champ — à chaque écriture,
  // même la sienne (l'écho de son propre INSERT/UPDATE arrivant par Realtime).
  useEffect(() => {
    const channel = supabase
      .channel(`safari-groups-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'safari_groups' }, (payload) => {
        const row = payload.new as SafariGroup
        setGroups((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'safari_groups' }, (payload) => {
        const row = payload.new as SafariGroup
        setGroups((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'safari_groups' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setGroups((prev) => prev.filter((r) => r.id !== id))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'safari_group_pokemon' }, (payload) => {
        const row = payload.new as SafariGroupPokemon
        setGroupPokemon((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'safari_group_pokemon' }, (payload) => {
        const row = payload.new as SafariGroupPokemon
        setGroupPokemon((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'safari_group_pokemon' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setGroupPokemon((prev) => prev.filter((r) => r.id !== id))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'safari_gauge_areas' }, (payload) => {
        const row = payload.new as SafariGaugeArea
        setGaugeAreas((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'safari_gauge_areas' }, (payload) => {
        const row = payload.new as SafariGaugeArea
        setGaugeAreas((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'safari_gauge_areas' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setGaugeAreas((prev) => prev.filter((r) => r.id !== id))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [fetchAll])

  const pokemonByGroup = useMemo(() => {
    const map = new Map<number, SafariGroupPokemon[]>()
    for (const row of groupPokemon) {
      const list = map.get(row.group_id)
      if (list) list.push(row)
      else map.set(row.group_id, [row])
    }
    return map
  }, [groupPokemon])

  const areasByGroup = useMemo(() => {
    const map = new Map<number, SafariGaugeArea[]>()
    for (const row of gaugeAreas) {
      const list = map.get(row.group_id)
      if (list) list.push(row)
      else map.set(row.group_id, [row])
    }
    return map
  }, [gaugeAreas])

  const addGroup = useCallback(async (nom: string) => {
    const { data, error } = await supabase.from('safari_groups').insert({ nom }).select().single()
    if (error) {
      console.error("Erreur lors de la création du groupe Safari :", error)
      return
    }
    setGroups((prev) => [...prev, data as SafariGroup])
  }, [])

  const updateGroup = useCallback(async (id: number, patch: Partial<Pick<SafariGroup, 'nom' | 'weight'>>) => {
    setGroups((prev) => prev.map((g) => (g.id === id ? { ...g, ...patch } : g)))
    const { error } = await supabase.from('safari_groups').update(patch).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour du groupe Safari :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const deleteGroup = useCallback(async (id: number) => {
    setGroups((prev) => prev.filter((g) => g.id !== id))
    const { error } = await supabase.from('safari_groups').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors de la suppression du groupe Safari :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const addGroupPokemon = useCallback(async (groupId: number, pokemonNom: string) => {
    const { data, error } = await supabase
      .from('safari_group_pokemon')
      .insert({ group_id: groupId, pokemon_nom: pokemonNom, weight: 1 })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'ajout du pokémon au groupe :", error)
      return
    }
    setGroupPokemon((prev) => [...prev, data as SafariGroupPokemon])
  }, [])

  const updateGroupPokemonWeight = useCallback(async (id: number, weight: number) => {
    setGroupPokemon((prev) => prev.map((r) => (r.id === id ? { ...r, weight } : r)))
    const { error } = await supabase.from('safari_group_pokemon').update({ weight }).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour du poids :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const removeGroupPokemon = useCallback(async (id: number) => {
    setGroupPokemon((prev) => prev.filter((r) => r.id !== id))
    const { error } = await supabase.from('safari_group_pokemon').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors du retrait du pokémon du groupe :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const addGaugeArea = useCallback(async (groupId: number, patch: Omit<SafariGaugeArea, 'id' | 'group_id' | 'created_at'>) => {
    const { data, error } = await supabase
      .from('safari_gauge_areas')
      .insert({ group_id: groupId, ...patch })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'ajout de la zone de jauge :", error)
      return
    }
    setGaugeAreas((prev) => [...prev, data as SafariGaugeArea])
  }, [])

  const updateGaugeArea = useCallback(async (id: number, patch: Partial<Omit<SafariGaugeArea, 'id' | 'group_id' | 'created_at'>>) => {
    setGaugeAreas((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)))
    const { error } = await supabase.from('safari_gauge_areas').update(patch).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour de la zone de jauge :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const removeGaugeArea = useCallback(async (id: number) => {
    setGaugeAreas((prev) => prev.filter((r) => r.id !== id))
    const { error } = await supabase.from('safari_gauge_areas').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors du retrait de la zone de jauge :', error)
      await fetchAll()
    }
  }, [fetchAll])

  return {
    groups, groupPokemon, gaugeAreas, pokemonByGroup, areasByGroup, loading, error,
    addGroup, updateGroup, deleteGroup,
    addGroupPokemon, updateGroupPokemonWeight, removeGroupPokemon,
    addGaugeArea, updateGaugeArea, removeGaugeArea,
    refetch: fetchAll,
  }
}
