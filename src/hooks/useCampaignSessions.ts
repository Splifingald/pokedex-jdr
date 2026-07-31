import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { CampaignSession } from '../types'

type SessionInput = { title: string; icon: string; session_date: string | null; image_url: string | null; image_position?: number; done?: boolean; notes?: CampaignSession['notes']; position?: number }

export function useCampaignSessions() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [sessions, setSessions] = useState<CampaignSession[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const sortSessions = (list: CampaignSession[]) => [...list].sort((a, b) => a.position - b.position)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('campaign_sessions').select('*').order('position')
      if (error) throw error
      setSessions(data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  // Abonnement temps réel : synchro entre appareils
  useEffect(() => {
    const channel = supabase
      .channel(`campaign-sessions-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'campaign_sessions' },
        (payload) => {
          const session = payload.new as CampaignSession
          setSessions((prev) => (prev.some((s) => s.id === session.id) ? prev : sortSessions([...prev, session])))
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'campaign_sessions' },
        (payload) => {
          const session = payload.new as CampaignSession
          setSessions((prev) => sortSessions(prev.map((s) => (s.id === session.id ? session : s))))
        }
      )
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table: 'campaign_sessions' },
        (payload) => {
          const id = (payload.old as { id: number }).id
          setSessions((prev) => prev.filter((s) => s.id !== id))
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const createSession = useCallback(async (data: SessionInput) => {
    const { data: created, error } = await supabase
      .from('campaign_sessions')
      .insert({ position: sessions.length, ...data })
      .select()
      .single()
    if (error) {
      console.error('Erreur lors de la création de la session :', error)
      return null
    }
    setSessions((prev) => sortSessions([...prev, created as CampaignSession]))
    return created as CampaignSession
  }, [sessions.length])

  const updateSession = useCallback(async (id: number, data: Partial<SessionInput>) => {
    setSessions((prev) => sortSessions(prev.map((s) => (s.id === id ? { ...s, ...data } : s))))
    const { error } = await supabase.from('campaign_sessions').update(data).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour de la session :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const reorderSessions = useCallback(async (orderedIds: number[]) => {
    setSessions((prev) => {
      const byId = new Map(prev.map((s) => [s.id, s]))
      return orderedIds.map((id, i) => ({ ...byId.get(id)!, position: i }))
    })
    const results = await Promise.all(
      orderedIds.map((id, i) => supabase.from('campaign_sessions').update({ position: i }).eq('id', id))
    )
    if (results.some((r) => r.error)) {
      console.error('Erreur lors de la réorganisation des sessions :', results.find((r) => r.error)?.error)
      await fetchAll()
    }
  }, [fetchAll])

  const deleteSession = useCallback(async (id: number) => {
    setSessions((prev) => prev.filter((s) => s.id !== id))
    // ON DELETE CASCADE sur campaign_chapters.session_id : pas de nettoyage manuel nécessaire
    const { error } = await supabase.from('campaign_sessions').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors de la suppression de la session :', error)
      await fetchAll()
    }
  }, [fetchAll])

  return { sessions, loading, error, createSession, updateSession, deleteSession, reorderSessions, refetch: fetchAll }
}
