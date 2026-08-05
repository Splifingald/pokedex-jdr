import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { PensionXpGroup, PensionXpGroupSpecies } from '../types'

// Groupes XP — entièrement séparés des groupes d'œufs (usePensionGroups) :
// créés/peuplés à la main par l'admin, jamais via CSV. Même idiome que
// useGiftLootboxes (lootbox + assignation d'espèce), une espèce n'appartenant
// qu'à un seul groupe XP à la fois.
export function usePensionXpGroups() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [xpGroups, setXpGroups] = useState<PensionXpGroup[]>([])
  const [speciesAssignments, setSpeciesAssignments] = useState<PensionXpGroupSpecies[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [groupsRes, speciesRes] = await Promise.all([
        supabase.from('pension_xp_groups').select('*').order('created_at'),
        supabase.from('pension_xp_group_species').select('*'),
      ])
      if (groupsRes.error) throw groupsRes.error
      if (speciesRes.error) throw speciesRes.error
      setXpGroups(groupsRes.data ?? [])
      setSpeciesAssignments(speciesRes.data ?? [])
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
      .channel(`pension-xp-groups-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'pension_xp_groups' }, (payload) => {
        const row = payload.new as PensionXpGroup
        setXpGroups((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'pension_xp_groups' }, (payload) => {
        const row = payload.new as PensionXpGroup
        setXpGroups((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'pension_xp_groups' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setXpGroups((prev) => prev.filter((r) => r.id !== id))
        setSpeciesAssignments((prev) => prev.filter((r) => r.xp_group_id !== id))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'pension_xp_group_species' }, (payload) => {
        const row = payload.new as PensionXpGroupSpecies
        setSpeciesAssignments((prev) => (prev.some((r) => r.pokemon_nom === row.pokemon_nom) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'pension_xp_group_species' }, (payload) => {
        const row = payload.new as PensionXpGroupSpecies
        setSpeciesAssignments((prev) => prev.map((r) => (r.pokemon_nom === row.pokemon_nom ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'pension_xp_group_species' }, (payload) => {
        const pokemonNom = (payload.old as { pokemon_nom: string }).pokemon_nom
        setSpeciesAssignments((prev) => prev.filter((r) => r.pokemon_nom !== pokemonNom))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const speciesByXpGroup = useMemo(() => {
    const map = new Map<number, string[]>()
    for (const a of speciesAssignments) {
      const list = map.get(a.xp_group_id)
      if (list) list.push(a.pokemon_nom)
      else map.set(a.xp_group_id, [a.pokemon_nom])
    }
    return map
  }, [speciesAssignments])

  const xpGroupByPokemonNom = useMemo(() => {
    const groupsById = new Map(xpGroups.map((g) => [g.id, g]))
    const map = new Map<string, PensionXpGroup>()
    for (const a of speciesAssignments) {
      const group = groupsById.get(a.xp_group_id)
      if (group) map.set(a.pokemon_nom, group)
    }
    return map
  }, [xpGroups, speciesAssignments])

  const createXpGroup = useCallback(async (nom: string) => {
    const { data, error } = await supabase
      .from('pension_xp_groups')
      .insert({ nom })
      .select()
      .single()
    if (error) {
      console.error('Erreur lors de la création du groupe XP :', error)
      return null
    }
    const row = data as PensionXpGroup
    setXpGroups((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
    return row
  }, [])

  const updateXpGroup = useCallback(async (id: number, patch: Partial<Pick<PensionXpGroup, 'nom' | 'tick_interval_amount' | 'tick_interval_unit' | 'lifetime_xp_cap'>>) => {
    setXpGroups((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)))
    const { error } = await supabase.from('pension_xp_groups').update(patch).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour du groupe XP :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const deleteXpGroup = useCallback(async (id: number) => {
    setXpGroups((prev) => prev.filter((r) => r.id !== id))
    setSpeciesAssignments((prev) => prev.filter((r) => r.xp_group_id !== id))
    const { error } = await supabase.from('pension_xp_groups').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors de la suppression du groupe XP :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const assignSpecies = useCallback(async (pokemonNom: string, xpGroupId: number) => {
    setSpeciesAssignments((prev) => {
      const existing = prev.find((r) => r.pokemon_nom === pokemonNom)
      if (existing) return prev.map((r) => (r.pokemon_nom === pokemonNom ? { ...r, xp_group_id: xpGroupId } : r))
      return [...prev, { pokemon_nom: pokemonNom, xp_group_id: xpGroupId, created_at: new Date().toISOString() }]
    })
    const { error } = await supabase
      .from('pension_xp_group_species')
      .upsert({ pokemon_nom: pokemonNom, xp_group_id: xpGroupId })
    if (error) {
      console.error("Erreur lors de l'assignation de l'espèce :", error)
      await fetchAll()
    }
  }, [fetchAll])

  const unassignSpecies = useCallback(async (pokemonNom: string) => {
    setSpeciesAssignments((prev) => prev.filter((r) => r.pokemon_nom !== pokemonNom))
    const { error } = await supabase.from('pension_xp_group_species').delete().eq('pokemon_nom', pokemonNom)
    if (error) {
      console.error("Erreur lors du retrait de l'assignation de l'espèce :", error)
      await fetchAll()
    }
  }, [fetchAll])

  return {
    xpGroups,
    speciesAssignments,
    speciesByXpGroup,
    xpGroupByPokemonNom,
    loading,
    error,
    createXpGroup,
    updateXpGroup,
    deleteXpGroup,
    assignSpecies,
    unassignSpecies,
    refetch: fetchAll,
  }
}
