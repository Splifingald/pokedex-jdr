import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { MiningCustomGrid, MiningCustomGridItem } from '../types'

export function useMiningCustomGrids() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [grids, setGrids] = useState<MiningCustomGrid[]>([])
  const [gridItems, setGridItems] = useState<MiningCustomGridItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [gridsRes, itemsRes] = await Promise.all([
        supabase.from('mining_custom_grids').select('*').order('created_at'),
        supabase.from('mining_custom_grid_items').select('*'),
      ])
      if (gridsRes.error) throw gridsRes.error
      if (itemsRes.error) throw itemsRes.error
      setGrids(gridsRes.data ?? [])
      setGridItems(itemsRes.data ?? [])
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
      .channel(`mining-custom-grids-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'mining_custom_grids' }, (payload) => {
        const row = payload.new as MiningCustomGrid
        setGrids((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'mining_custom_grids' }, (payload) => {
        const row = payload.new as MiningCustomGrid
        setGrids((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'mining_custom_grids' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setGrids((prev) => prev.filter((r) => r.id !== id))
        setGridItems((prev) => prev.filter((r) => r.custom_grid_id !== id))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'mining_custom_grid_items' }, (payload) => {
        const row = payload.new as MiningCustomGridItem
        setGridItems((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'mining_custom_grid_items' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setGridItems((prev) => prev.filter((r) => r.id !== id))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const placementsByGridId = useMemo(() => {
    const map = new Map<number, MiningCustomGridItem[]>()
    for (const item of gridItems) {
      const list = map.get(item.custom_grid_id)
      if (list) list.push(item)
      else map.set(item.custom_grid_id, [item])
    }
    return map
  }, [gridItems])

  const createGrid = useCallback(async (nom: string, size: number, moveBudget: number) => {
    const { data, error } = await supabase
      .from('mining_custom_grids')
      .insert({ nom, size, move_budget: moveBudget })
      .select()
      .single()
    if (error) {
      console.error('Erreur lors de la création de la grille personnalisée :', error)
      return null
    }
    const row = data as MiningCustomGrid
    setGrids((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
    return row
  }, [])

  const updateGrid = useCallback(async (id: number, patch: Partial<Pick<MiningCustomGrid, 'nom' | 'size' | 'move_budget'>>) => {
    setGrids((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)))
    const { error } = await supabase.from('mining_custom_grids').update(patch).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour de la grille personnalisée :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const deleteGrid = useCallback(async (id: number) => {
    setGrids((prev) => prev.filter((r) => r.id !== id))
    setGridItems((prev) => prev.filter((r) => r.custom_grid_id !== id))
    const { error } = await supabase.from('mining_custom_grids').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors de la suppression de la grille personnalisée :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const addPlacement = useCallback(async (customGridId: number, itemNom: string, size: number, originRow: number, originCol: number) => {
    const { data, error } = await supabase
      .from('mining_custom_grid_items')
      .insert({ custom_grid_id: customGridId, item_nom: itemNom, size, origin_row: originRow, origin_col: originCol })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors du placement de l'objet :", error)
      return
    }
    const row = data as MiningCustomGridItem
    setGridItems((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
  }, [])

  const removePlacement = useCallback(async (id: number) => {
    setGridItems((prev) => prev.filter((r) => r.id !== id))
    const { error } = await supabase.from('mining_custom_grid_items').delete().eq('id', id)
    if (error) {
      console.error("Erreur lors du retrait de l'objet :", error)
      await fetchAll()
    }
  }, [fetchAll])

  return {
    grids,
    gridItems,
    placementsByGridId,
    loading,
    error,
    createGrid,
    updateGrid,
    deleteGrid,
    addPlacement,
    removePlacement,
    refetch: fetchAll,
  }
}
