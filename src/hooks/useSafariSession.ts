import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { SafariSession, SafariSessionPokemon, SafariMove } from '../types'

export type BerryResult =
  | { status: 'ok'; gaugeBefore: number; gaugeAfter: number }
  | { status: 'not_found' | 'already_resolved' }

export type BallResult =
  | { status: 'ok'; success: boolean }
  | { status: 'not_found' | 'already_resolved' | 'already_attempted' }

// Possède la session Safari partagée en cours : tous les joueurs qui ont le
// popup ouvert pointent sur la même session (safari_sessions.is_active = true)
// et voient les jauges/résolutions en direct via Realtime. Les écritures
// concurrentes-sûres (créer/renouveler la session, lancer une baie, tenter une
// capture) passent par les fonctions RPC safari_ensure_active_session /
// safari_throw_berry / safari_throw_ball — voir supabase/schema.sql.
export function useSafariSession(playerId: number) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [session, setSession] = useState<SafariSession | null>(null)
  const [sessionPokemon, setSessionPokemon] = useState<SafariSessionPokemon[]>([])
  const [moves, setMoves] = useState<SafariMove[]>([])
  const [loading, setLoading] = useState(true)

  const loadSession = useCallback(async (sessionId: number) => {
    const [sessionRes, pokemonRes, movesRes] = await Promise.all([
      supabase.from('safari_sessions').select('*').eq('id', sessionId).single(),
      supabase.from('safari_session_pokemon').select('*').eq('session_id', sessionId).order('slot'),
      supabase.from('safari_moves').select('*').eq('session_id', sessionId).order('created_at', { ascending: false }).limit(500),
    ])
    if (sessionRes.error) throw sessionRes.error
    setSession(sessionRes.data as SafariSession)
    setSessionPokemon(pokemonRes.data ?? [])
    setMoves(movesRes.data ?? [])
  }, [])

  // Retourne (en la créant si besoin) l'id de la session active. N'est appelée
  // qu'au montage du popup ou après une capture/fuite qui vient de résoudre le
  // 3e pokémon (voir throwBall) — jamais par un minuteur en arrière-plan, pour
  // qu'une session expirée reste inactive tant qu'aucun joueur n'ouvre Safari.
  const ensureActiveSession = useCallback(async () => {
    setLoading(true)
    try {
      const { data: sessionId, error } = await supabase.rpc('safari_ensure_active_session')
      if (error) throw error
      await loadSession(sessionId as number)
    } catch (err) {
      console.error('Erreur lors de la création/récupération de la session Safari :', err)
    } finally {
      setLoading(false)
    }
  }, [loadSession])

  useEffect(() => {
    ensureActiveSession()
    // eslint-disable-next-line react-hooks/exhaustive-deps -- une seule fois au montage
  }, [])

  // Vérifie localement l'expiration du minuteur pour rafraîchir l'affichage
  // (lecture seule, ne recrée jamais de session — voir ensureActiveSession).
  useEffect(() => {
    if (!session || !session.is_active) return
    const interval = setInterval(() => {
      if (new Date(session.expires_at).getTime() <= Date.now()) {
        loadSession(session.id)
      }
    }, 1000)
    return () => clearInterval(interval)
  }, [session, loadSession])

  useEffect(() => {
    const channel = supabase
      .channel(`safari-session-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'safari_sessions' }, (payload) => {
        const row = payload.new as SafariSession
        setSession((prev) => (prev && row.id === prev.id ? row : prev))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'safari_session_pokemon' }, (payload) => {
        const row = payload.new as SafariSessionPokemon
        setSessionPokemon((prev) => (prev.some((r) => r.id === row.id) ? prev.map((r) => (r.id === row.id ? row : r)) : prev))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'safari_moves' }, (payload) => {
        const row = payload.new as SafariMove
        setMoves((prev) => (prev.some((r) => r.id === row.id) ? prev : [row, ...prev]))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const throwBerry = useCallback(async (sessionPokemonId: number): Promise<BerryResult> => {
    const { data, error } = await supabase.rpc('safari_throw_berry', {
      p_session_pokemon_id: sessionPokemonId,
      p_player_id: playerId,
    })
    if (error) {
      console.error('Erreur lors du lancer de baie :', error)
      return { status: 'not_found' }
    }
    const result = data as { status: 'ok' | 'not_found' | 'already_resolved'; gauge_before?: number; gauge_after?: number }
    if (result.status === 'ok') {
      return { status: 'ok', gaugeBefore: result.gauge_before ?? 0, gaugeAfter: result.gauge_after ?? 0 }
    }
    return { status: result.status }
  }, [playerId])

  const throwBall = useCallback(async (sessionPokemonId: number): Promise<BallResult> => {
    const { data, error } = await supabase.rpc('safari_throw_ball', {
      p_session_pokemon_id: sessionPokemonId,
      p_player_id: playerId,
    })
    if (error) {
      console.error('Erreur lors de la tentative de capture :', error)
      return { status: 'not_found' }
    }
    const result = data as { status: 'ok' | 'not_found' | 'already_resolved' | 'already_attempted'; success?: boolean }
    if (result.status === 'ok') {
      // La session peut avoir été renouvelée côté serveur si ce lancer a
      // résolu le 3e pokémon — safari_ensure_active_session est idempotente
      // (retourne la session déjà créée sans rien recréer) et permet de
      // détecter/suivre la nouvelle session immédiatement.
      const { data: activeId } = await supabase.rpc('safari_ensure_active_session')
      if (activeId) await loadSession(activeId as number)
      return { status: 'ok', success: result.success ?? false }
    }
    return { status: result.status }
  }, [playerId, loadSession])

  return { session, sessionPokemon, moves, loading, ensureActiveSession, throwBerry, throwBall }
}
