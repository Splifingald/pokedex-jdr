import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { SafariForcedPokemon } from '../types'

// Tirage forcé pour la PROCHAINE session Safari (au plus 3 lignes, une par
// slot) — consommé une seule fois côté serveur par safari_ensure_active_session()
// dès qu'il en contient exactement 3, puis vidé automatiquement.
export function useSafariForcedDraw() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [entries, setEntries] = useState<SafariForcedPokemon[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    const { data, error } = await supabase.from('safari_forced_pokemon').select('*').order('slot')
    if (error) {
      console.error('Erreur lors du chargement du tirage forcé Safari :', error)
    } else {
      setEntries(data ?? [])
    }
    setLoading(false)
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`safari-forced-pokemon-changes-${channelId.current}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'safari_forced_pokemon' }, () => fetchAll())
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [fetchAll])

  const setSlot = useCallback(async (slot: number, groupId: number, pokemonNom: string) => {
    const { error } = await supabase
      .from('safari_forced_pokemon')
      .upsert({ slot, group_id: groupId, pokemon_nom: pokemonNom })
    if (error) {
      console.error('Erreur lors de la définition du tirage forcé Safari :', error)
      return
    }
    setEntries((prev) => {
      const next = prev.filter((e) => e.slot !== slot)
      next.push({ slot, group_id: groupId, pokemon_nom: pokemonNom, created_at: new Date().toISOString() })
      return next.sort((a, b) => a.slot - b.slot)
    })
  }, [])

  const clearSlot = useCallback(async (slot: number) => {
    setEntries((prev) => prev.filter((e) => e.slot !== slot))
    const { error } = await supabase.from('safari_forced_pokemon').delete().eq('slot', slot)
    if (error) {
      console.error('Erreur lors du retrait du tirage forcé Safari :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const clearAll = useCallback(async () => {
    setEntries([])
    const { error } = await supabase.from('safari_forced_pokemon').delete().gte('slot', 0)
    if (error) {
      console.error("Erreur lors de l'annulation du tirage forcé Safari :", error)
      await fetchAll()
    }
  }, [fetchAll])

  return { entries, loading, setSlot, clearSlot, clearAll, refetch: fetchAll }
}
