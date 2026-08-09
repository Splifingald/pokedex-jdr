import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { AutoBattleAbilityRule } from '../types'

// Effets spéciaux des capacités (rythme des tours et/ou soin) — gérés
// librement par l'admin, consultés à la fois par le RPC autobattle_resolve_battle
// (autobattle_ability_burst + heal_type) et par l'UI (AdminAutoBattleAbilityRulesPanel).
export function useAutoBattleAbilityRules() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [rules, setRules] = useState<AutoBattleAbilityRule[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    try {
      const { data, error } = await supabase.from('autobattle_ability_rules').select('*').order('attack_nom')
      if (error) throw error
      setRules(data ?? [])
    } catch (err) {
      console.error('Erreur lors du chargement des effets spéciaux Combat Auto :', err)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`autobattle-ability-rules-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'autobattle_ability_rules' }, (payload) => {
        const row = payload.new as AutoBattleAbilityRule
        setRules((prev) => (prev.some((r) => r.attack_nom === row.attack_nom) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'autobattle_ability_rules' }, (payload) => {
        const row = payload.new as AutoBattleAbilityRule
        setRules((prev) => prev.map((r) => (r.attack_nom === row.attack_nom ? row : r)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'autobattle_ability_rules' }, (payload) => {
        const nom = (payload.old as { attack_nom: string }).attack_nom
        setRules((prev) => prev.filter((r) => r.attack_nom !== nom))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const addRule = useCallback(async (attackNom: string) => {
    const { data, error } = await supabase
      .from('autobattle_ability_rules')
      .insert({ attack_nom: attackNom })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de l'ajout de l'effet spécial :", error)
      return
    }
    setRules((prev) => [...prev, data as AutoBattleAbilityRule])
  }, [])

  const updateRule = useCallback(async (attackNom: string, patch: Partial<Omit<AutoBattleAbilityRule, 'attack_nom' | 'created_at'>>) => {
    setRules((prev) => prev.map((r) => (r.attack_nom === attackNom ? { ...r, ...patch } : r)))
    const { error } = await supabase.from('autobattle_ability_rules').update(patch).eq('attack_nom', attackNom)
    if (error) {
      console.error("Erreur lors de la mise à jour de l'effet spécial :", error)
      await fetchAll()
    }
  }, [fetchAll])

  const removeRule = useCallback(async (attackNom: string) => {
    setRules((prev) => prev.filter((r) => r.attack_nom !== attackNom))
    const { error } = await supabase.from('autobattle_ability_rules').delete().eq('attack_nom', attackNom)
    if (error) {
      console.error("Erreur lors du retrait de l'effet spécial :", error)
      await fetchAll()
    }
  }, [fetchAll])

  return { rules, loading, addRule, updateRule, removeRule }
}
