import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { MiningItemDef } from '../types'

export function useMiningItemDefs() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [itemDefs, setItemDefs] = useState<MiningItemDef[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('mining_item_defs').select('*').order('created_at')
      if (error) throw error
      setItemDefs(data ?? [])
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
      .channel(`mining-item-defs-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'mining_item_defs' }, (payload) => {
        const row = payload.new as MiningItemDef
        setItemDefs((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'mining_item_defs' }, (payload) => {
        const row = payload.new as MiningItemDef
        setItemDefs((prev) => prev.map((r) => (r.id === row.id ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'mining_item_defs' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setItemDefs((prev) => prev.filter((r) => r.id !== id))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const addItemDef = useCallback(async (itemNom: string, size: number, weight: number) => {
    const { data, error } = await supabase
      .from('mining_item_defs')
      .insert({ item_nom: itemNom, size, weight })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'ajout de l'objet de Fouille :", error)
      return
    }
    const row = data as MiningItemDef
    setItemDefs((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
  }, [])

  const updateItemDef = useCallback(async (id: number, patch: Partial<Pick<MiningItemDef, 'size' | 'weight' | 'enabled'>>) => {
    setItemDefs((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)))
    const { error } = await supabase.from('mining_item_defs').update(patch).eq('id', id)
    if (error) {
      console.error("Erreur lors de la mise à jour de l'objet de Fouille :", error)
      await fetchAll()
    }
  }, [fetchAll])

  const removeItemDef = useCallback(async (id: number) => {
    setItemDefs((prev) => prev.filter((r) => r.id !== id))
    const { error } = await supabase.from('mining_item_defs').delete().eq('id', id)
    if (error) {
      console.error("Erreur lors du retrait de l'objet de Fouille :", error)
      await fetchAll()
    }
  }, [fetchAll])

  return { itemDefs, loading, error, addItemDef, updateItemDef, removeItemDef, refetch: fetchAll }
}
