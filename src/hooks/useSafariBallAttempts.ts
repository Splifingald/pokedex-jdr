import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { SafariBallAttempt } from '../types'

// Tentatives de Safari Ball du joueur courant — sert uniquement à désactiver
// le bouton "Tenter la capture" une fois déjà tenté sur un pokémon donné (la
// garde faisant foi reste côté serveur, via la contrainte UNIQUE de
// safari_ball_attempts). Non filtré par session : hasAttempted() est appelé
// avec des session_pokemon_id de la session courante, donc les anciennes
// tentatives d'une session passée ne peuvent jamais matcher un id actif.
export function useSafariBallAttempts(playerId: number) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [attempts, setAttempts] = useState<SafariBallAttempt[]>([])

  const fetchAttempts = useCallback(async () => {
    const { data, error } = await supabase
      .from('safari_ball_attempts')
      .select('*')
      .eq('player_id', playerId)
    if (error) {
      console.error('Erreur lors du chargement des tentatives Safari Ball :', error)
      return
    }
    setAttempts((data as SafariBallAttempt[]) ?? [])
  }, [playerId])

  useEffect(() => {
    fetchAttempts()
  }, [fetchAttempts])

  useEffect(() => {
    const channel = supabase
      .channel(`safari-ball-attempts-changes-${playerId}-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'safari_ball_attempts' }, (payload) => {
        const row = payload.new as SafariBallAttempt
        if (row.player_id !== playerId) return
        setAttempts((prev) => (prev.some((r) => r.id === row.id) ? prev : [...prev, row]))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [playerId])

  const hasAttempted = useCallback(
    (sessionPokemonId: number) => attempts.some((a) => a.session_pokemon_id === sessionPokemonId),
    [attempts]
  )

  return { attempts, hasAttempted, refetch: fetchAttempts }
}
