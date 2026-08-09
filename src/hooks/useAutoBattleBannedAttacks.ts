import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import type { AutoBattleBannedAttack } from '../types'

// Liste des capacités bannies du Combat Auto — gérée librement par l'admin
// (AdminAutoBattleBannedAttacksPanel), consultée à la fois par le picker de
// capacité du joueur et par le sélecteur de capacité adverse en admin.
export function useAutoBattleBannedAttacks() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [bannedAttacks, setBannedAttacks] = useState<AutoBattleBannedAttack[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    try {
      const { data, error } = await supabase.from('autobattle_banned_attacks').select('*').order('attack_nom')
      if (error) throw error
      setBannedAttacks(data ?? [])
    } catch (err) {
      console.error('Erreur lors du chargement des capacités bannies Combat Auto :', err)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`autobattle-banned-attacks-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'autobattle_banned_attacks' }, (payload) => {
        const row = payload.new as AutoBattleBannedAttack
        setBannedAttacks((prev) => (prev.some((r) => r.attack_nom === row.attack_nom) ? prev : [...prev, row]))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'autobattle_banned_attacks' }, (payload) => {
        const nom = (payload.old as { attack_nom: string }).attack_nom
        setBannedAttacks((prev) => prev.filter((r) => r.attack_nom !== nom))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const bannedNames = useMemo(() => new Set(bannedAttacks.map((r) => r.attack_nom)), [bannedAttacks])

  const banAttack = useCallback(async (attackNom: string) => {
    const { data, error } = await supabase.from('autobattle_banned_attacks').insert({ attack_nom: attackNom }).select().single()
    if (error) {
      console.error("Erreur lors de l'ajout à la liste des capacités bannies :", error)
      return
    }
    setBannedAttacks((prev) => [...prev, data as AutoBattleBannedAttack])
  }, [])

  const unbanAttack = useCallback(async (attackNom: string) => {
    setBannedAttacks((prev) => prev.filter((r) => r.attack_nom !== attackNom))
    const { error } = await supabase.from('autobattle_banned_attacks').delete().eq('attack_nom', attackNom)
    if (error) {
      console.error('Erreur lors du retrait de la liste des capacités bannies :', error)
      await fetchAll()
    }
  }, [fetchAll])

  return { bannedAttacks, bannedNames, loading, banAttack, unbanAttack }
}
