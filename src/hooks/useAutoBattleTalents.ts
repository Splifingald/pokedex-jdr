import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { AutoBattleTalent } from '../types'

// Talents d'espèce (effets passifs de combat) — même forme que
// useAutoBattleAbilityRules, mais plusieurs lignes par espèce (clé = id serial),
// donc l'ajout renvoie la ligne créée pour pouvoir la mettre en surbrillance.
// Lus côté serveur par les helpers autobattle_talent_* (voir supabase/schema.sql)
// et côté UI par AdminAutoBattleTalentsPanel.
export function useAutoBattleTalents() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [talents, setTalents] = useState<AutoBattleTalent[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    try {
      const { data, error } = await supabase.from('autobattle_talents').select('*').order('id')
      if (error) throw error
      setTalents(data ?? [])
    } catch (err) {
      console.error('Erreur lors du chargement des talents :', err)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`autobattle-talents-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'autobattle_talents' }, (payload) => {
        const row = payload.new as AutoBattleTalent
        setTalents((prev) => (prev.some((t) => t.id === row.id) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'autobattle_talents' }, (payload) => {
        const row = payload.new as AutoBattleTalent
        setTalents((prev) => prev.map((t) => (t.id === row.id ? row : t)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'autobattle_talents' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setTalents((prev) => prev.filter((t) => t.id !== id))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  // Groupés par espèce, dans l'ordre de création — l'UI affiche une carte par
  // espèce contenant tous ses talents.
  const talentsByPokemon = useMemo(() => {
    const map = new Map<string, AutoBattleTalent[]>()
    for (const t of talents) {
      const list = map.get(t.pokemon_nom)
      if (list) list.push(t)
      else map.set(t.pokemon_nom, [t])
    }
    return map
  }, [talents])

  /** Renvoie l'id créé (pour scroller/surligner la nouvelle ligne), ou null. */
  const addTalent = useCallback(async (pokemonNom: string, nom: string) => {
    const { data, error } = await supabase
      .from('autobattle_talents')
      // kind/stat/amount : valeurs par défaut d'un bonus de dégâts, seul groupe
      // de champs qui satisfait autobattle_talents_stat_boost_fields.
      .insert({ pokemon_nom: pokemonNom, nom, kind: 'stat_boost', stat: 'damage', amount: 1 })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'ajout du talent :", error)
      return null
    }
    const row = data as AutoBattleTalent
    setTalents((prev) => (prev.some((t) => t.id === row.id) ? prev : [...prev, row]))
    return row.id
  }, [])

  const updateTalent = useCallback(async (id: number, patch: Partial<Omit<AutoBattleTalent, 'id' | 'created_at'>>) => {
    setTalents((prev) => prev.map((t) => (t.id === id ? { ...t, ...patch } : t)))
    const { error } = await supabase.from('autobattle_talents').update(patch).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour du talent :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const removeTalent = useCallback(async (id: number) => {
    setTalents((prev) => prev.filter((t) => t.id !== id))
    const { error } = await supabase.from('autobattle_talents').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors du retrait du talent :', error)
      await fetchAll()
    }
  }, [fetchAll])

  return { talents, talentsByPokemon, loading, addTalent, updateTalent, removeTalent }
}
