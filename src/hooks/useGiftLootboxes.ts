import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { GiftLootbox, GiftLootboxItem, GiftLootboxSpecies } from '../types'
import { DEFAULT_LOOTBOX_TIMER_MIN_HOURS, DEFAULT_LOOTBOX_TIMER_MAX_HOURS } from '../types'

export function useGiftLootboxes() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [lootboxes, setLootboxes] = useState<GiftLootbox[]>([])
  const [lootboxItems, setLootboxItems] = useState<GiftLootboxItem[]>([])
  const [speciesAssignments, setSpeciesAssignments] = useState<GiftLootboxSpecies[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [lootboxesRes, itemsRes, speciesRes] = await Promise.all([
        supabase.from('gift_lootboxes').select('*').order('created_at'),
        supabase.from('gift_lootbox_items').select('*'),
        supabase.from('gift_lootbox_species').select('*'),
      ])
      if (lootboxesRes.error) throw lootboxesRes.error
      if (itemsRes.error) throw itemsRes.error
      if (speciesRes.error) throw speciesRes.error
      setLootboxes(lootboxesRes.data ?? [])
      setLootboxItems(itemsRes.data ?? [])
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

  // Abonnement temps réel — tables globales (pas de filtrage par joueur)
  useEffect(() => {
    const channel = supabase
      .channel(`gift-lootboxes-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'gift_lootboxes' }, (payload) => {
        const row = payload.new as GiftLootbox
        setLootboxes((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'gift_lootboxes' }, (payload) => {
        const row = payload.new as GiftLootbox
        setLootboxes((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'gift_lootboxes' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setLootboxes((prev) => prev.filter((r) => r.id !== id))
        setLootboxItems((prev) => prev.filter((r) => r.lootbox_id !== id))
        setSpeciesAssignments((prev) => prev.filter((r) => r.lootbox_id !== id))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'gift_lootbox_items' }, (payload) => {
        const row = payload.new as GiftLootboxItem
        setLootboxItems((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'gift_lootbox_items' }, (payload) => {
        const row = payload.new as GiftLootboxItem
        setLootboxItems((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'gift_lootbox_items' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setLootboxItems((prev) => prev.filter((r) => r.id !== id))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'gift_lootbox_species' }, (payload) => {
        const row = payload.new as GiftLootboxSpecies
        setSpeciesAssignments((prev) => (prev.some((r) => r.pokemon_nom === row.pokemon_nom) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'gift_lootbox_species' }, (payload) => {
        const row = payload.new as GiftLootboxSpecies
        setSpeciesAssignments((prev) => prev.map((r) => (r.pokemon_nom === row.pokemon_nom ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'gift_lootbox_species' }, (payload) => {
        const pokemonNom = (payload.old as { pokemon_nom: string }).pokemon_nom
        setSpeciesAssignments((prev) => prev.filter((r) => r.pokemon_nom !== pokemonNom))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const itemsByLootbox = useMemo(() => {
    const map = new Map<number, GiftLootboxItem[]>()
    for (const item of lootboxItems) {
      const list = map.get(item.lootbox_id)
      if (list) list.push(item)
      else map.set(item.lootbox_id, [item])
    }
    return map
  }, [lootboxItems])

  const speciesByLootbox = useMemo(() => {
    const map = new Map<number, GiftLootboxSpecies[]>()
    for (const assignment of speciesAssignments) {
      const list = map.get(assignment.lootbox_id)
      if (list) list.push(assignment)
      else map.set(assignment.lootbox_id, [assignment])
    }
    return map
  }, [speciesAssignments])

  const createLootbox = useCallback(async (nom: string) => {
    const { data, error } = await supabase
      .from('gift_lootboxes')
      .insert({
        nom,
        is_default: lootboxes.length === 0,
        timer_min_hours: DEFAULT_LOOTBOX_TIMER_MIN_HOURS,
        timer_max_hours: DEFAULT_LOOTBOX_TIMER_MAX_HOURS,
      })
      .select()
      .single()
    if (error) {
      console.error('Erreur lors de la création du lootbox :', error)
      return null
    }
    const row = data as GiftLootbox
    setLootboxes((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
    return row
  }, [lootboxes])

  const updateLootbox = useCallback(async (id: number, patch: Partial<Pick<GiftLootbox, 'nom' | 'timer_min_hours' | 'timer_max_hours'>>) => {
    setLootboxes((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)))
    const { error } = await supabase.from('gift_lootboxes').update(patch).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour du lootbox :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const deleteLootbox = useCallback(async (id: number) => {
    const target = lootboxes.find((l) => l.id === id)
    if (!target || target.is_default) {
      console.error('Impossible de supprimer le lootbox par défaut.')
      return
    }
    setLootboxes((prev) => prev.filter((r) => r.id !== id))
    setLootboxItems((prev) => prev.filter((r) => r.lootbox_id !== id))
    setSpeciesAssignments((prev) => prev.filter((r) => r.lootbox_id !== id))
    const { error } = await supabase.from('gift_lootboxes').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors de la suppression du lootbox :', error)
      await fetchAll()
    }
  }, [lootboxes, fetchAll])

  // Doit être séquentiel (pas Promise.all) : l'index unique partiel n'autorise
  // qu'un seul is_default=true à la fois, donc on désactive l'ancien avant
  // d'activer le nouveau.
  const setDefaultLootbox = useCallback(async (id: number) => {
    const previousDefault = lootboxes.find((l) => l.is_default)
    setLootboxes((prev) => prev.map((r) => ({ ...r, is_default: r.id === id })))
    if (previousDefault && previousDefault.id !== id) {
      const { error: unsetError } = await supabase.from('gift_lootboxes').update({ is_default: false }).eq('id', previousDefault.id)
      if (unsetError) {
        console.error('Erreur lors du changement de lootbox par défaut :', unsetError)
        await fetchAll()
        return
      }
    }
    const { error } = await supabase.from('gift_lootboxes').update({ is_default: true }).eq('id', id)
    if (error) {
      console.error('Erreur lors du changement de lootbox par défaut :', error)
      await fetchAll()
    }
  }, [lootboxes, fetchAll])

  const addLootboxItem = useCallback(async (lootboxId: number, itemNom: string, quantity: number, weight: number) => {
    const { data, error } = await supabase
      .from('gift_lootbox_items')
      .insert({ lootbox_id: lootboxId, item_nom: itemNom, quantity, weight })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'ajout de l'objet au lootbox :", error)
      return
    }
    const row = data as GiftLootboxItem
    setLootboxItems((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
  }, [])

  const updateLootboxItem = useCallback(async (itemRowId: number, patch: Partial<Pick<GiftLootboxItem, 'quantity' | 'weight'>>) => {
    setLootboxItems((prev) => prev.map((r) => (r.id === itemRowId ? { ...r, ...patch } : r)))
    const { error } = await supabase.from('gift_lootbox_items').update(patch).eq('id', itemRowId)
    if (error) {
      console.error("Erreur lors de la mise à jour de l'objet du lootbox :", error)
      await fetchAll()
    }
  }, [fetchAll])

  const removeLootboxItem = useCallback(async (itemRowId: number) => {
    setLootboxItems((prev) => prev.filter((r) => r.id !== itemRowId))
    const { error } = await supabase.from('gift_lootbox_items').delete().eq('id', itemRowId)
    if (error) {
      console.error("Erreur lors du retrait de l'objet du lootbox :", error)
      await fetchAll()
    }
  }, [fetchAll])

  const assignSpecies = useCallback(async (pokemonNom: string, lootboxId: number) => {
    setSpeciesAssignments((prev) => {
      const existing = prev.find((r) => r.pokemon_nom === pokemonNom)
      if (existing) return prev.map((r) => (r.pokemon_nom === pokemonNom ? { ...r, lootbox_id: lootboxId } : r))
      return [...prev, { pokemon_nom: pokemonNom, lootbox_id: lootboxId, created_at: new Date().toISOString() }]
    })
    const { error } = await supabase
      .from('gift_lootbox_species')
      .upsert({ pokemon_nom: pokemonNom, lootbox_id: lootboxId })
    if (error) {
      console.error("Erreur lors de l'assignation de l'espèce :", error)
      await fetchAll()
    }
  }, [fetchAll])

  const unassignSpecies = useCallback(async (pokemonNom: string) => {
    setSpeciesAssignments((prev) => prev.filter((r) => r.pokemon_nom !== pokemonNom))
    const { error } = await supabase.from('gift_lootbox_species').delete().eq('pokemon_nom', pokemonNom)
    if (error) {
      console.error("Erreur lors du retrait de l'assignation de l'espèce :", error)
      await fetchAll()
    }
  }, [fetchAll])

  return {
    lootboxes,
    lootboxItems,
    speciesAssignments,
    itemsByLootbox,
    speciesByLootbox,
    loading,
    error,
    createLootbox,
    updateLootbox,
    deleteLootbox,
    setDefaultLootbox,
    addLootboxItem,
    updateLootboxItem,
    removeLootboxItem,
    assignSpecies,
    unassignSpecies,
    refetch: fetchAll,
  }
}
