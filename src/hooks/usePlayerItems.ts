import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { PlayerItem } from '../types'
import { POKEDOLLAR_ITEM_NAME } from '../types'

export function usePlayerItems(playerId: number | null) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [inventory, setInventory] = useState<PlayerItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    if (!playerId) {
      setInventory([])
      setLoading(false)
      return
    }
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase
        .from('player_items')
        .select('*')
        .eq('player_id', playerId)
        .order('created_at')
      if (error) throw error
      setInventory(data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [playerId])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  // Abonnement temps réel : filtré côté client comme player_pokemon
  useEffect(() => {
    if (!playerId) return
    const channel = supabase
      .channel(`player-items-changes-${playerId}-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'player_items' },
        (payload) => {
          const row = payload.new as PlayerItem
          if (row.player_id !== playerId) return
          setInventory((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'player_items' },
        (payload) => {
          const row = payload.new as PlayerItem
          if (row.player_id !== playerId) return
          setInventory((prev) => prev.map((r) => (r.id === row.id ? row : r)))
        }
      )
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table: 'player_items' },
        (payload) => {
          const id = (payload.old as { id: number }).id
          setInventory((prev) => prev.filter((r) => r.id !== id))
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [playerId])

  const pokedollars = useMemo(
    () => inventory.find((r) => r.item_nom === POKEDOLLAR_ITEM_NAME)?.quantity ?? 0,
    [inventory]
  )

  // La ligne Pokedollar n'est jamais supprimée, même à 0 (c'est l'argent du joueur)
  const setQuantity = useCallback(async (row: PlayerItem, quantity: number) => {
    const clamped = Math.max(0, quantity)

    if (clamped === 0 && row.item_nom !== POKEDOLLAR_ITEM_NAME) {
      setInventory((prev) => prev.filter((r) => r.id !== row.id))
      const { error } = await supabase.from('player_items').delete().eq('id', row.id)
      if (error) {
        console.error("Erreur lors de la suppression de l'objet :", error)
        await fetchAll()
      }
      return
    }

    setInventory((prev) => prev.map((r) => (r.id === row.id ? { ...r, quantity: clamped } : r)))
    const { error } = await supabase.from('player_items').update({ quantity: clamped }).eq('id', row.id)
    if (error) {
      console.error('Erreur lors de la mise à jour de la quantité :', error)
      setInventory((prev) => prev.map((r) => (r.id === row.id ? { ...r, quantity: row.quantity } : r)))
    }
  }, [fetchAll])

  const addItem = useCallback(async (itemNom: string) => {
    if (!playerId) return
    const existing = inventory.find((r) => r.item_nom === itemNom)
    if (existing) {
      await setQuantity(existing, existing.quantity + 1)
      return
    }
    const { data, error } = await supabase
      .from('player_items')
      .insert({ player_id: playerId, item_nom: itemNom, quantity: 1 })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'ajout de l'objet :", error)
      await fetchAll()
      return
    }
    setInventory((prev) => (prev.some((r) => r.id === (data as PlayerItem).id) ? prev : [...prev, data as PlayerItem]))
  }, [playerId, inventory, setQuantity, fetchAll])

  const setPokedollars = useCallback(async (quantity: number) => {
    if (!playerId) return
    const clamped = Math.max(0, quantity)
    const existing = inventory.find((r) => r.item_nom === POKEDOLLAR_ITEM_NAME)
    if (existing) {
      await setQuantity(existing, clamped)
      return
    }
    const { data, error } = await supabase
      .from('player_items')
      .insert({ player_id: playerId, item_nom: POKEDOLLAR_ITEM_NAME, quantity: clamped })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de la mise à jour des pokédollars :", error)
      await fetchAll()
      return
    }
    setInventory((prev) => (prev.some((r) => r.id === (data as PlayerItem).id) ? prev : [...prev, data as PlayerItem]))
  }, [playerId, inventory, setQuantity, fetchAll])

  const sellOne = useCallback(async (row: PlayerItem, value: number) => {
    await setQuantity(row, row.quantity - 1)
    await setPokedollars(pokedollars + value)
  }, [setQuantity, setPokedollars, pokedollars])

  return {
    inventory,
    pokedollars,
    loading,
    error,
    addItem,
    setQuantity,
    sellOne,
    setPokedollars,
    refetch: fetchAll,
  }
}
