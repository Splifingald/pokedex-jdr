import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { CampaignSession } from '../types'

type SessionInput = { title: string; icon: string; session_date: string | null; image_url: string | null; done?: boolean }

export function useCampaignSessions() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [sessions, setSessions] = useState<CampaignSession[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const sortSessions = (list: CampaignSession[]) =>
    [...list].sort((a, b) => {
      if (a.session_date !== b.session_date) {
        if (!a.session_date) return 1
        if (!b.session_date) return -1
        return b.session_date.localeCompare(a.session_date)
      }
      return b.created_at.localeCompare(a.created_at)
    })

  const fetchAll = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase.from('campaign_sessions').select('*')
      if (error) throw error
      setSessions(sortSessions(data ?? []))
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
    const { data: created, error } = await supabase.from('campaign_sessions').insert(data).select().single()
    if (error) {
      console.error('Erreur lors de la création de la session :', error)
      return null
    }
    setSessions((prev) => sortSessions([...prev, created as CampaignSession]))
    return created as CampaignSession
  }, [])

  const updateSession = useCallback(async (id: number, data: Partial<SessionInput>) => {
    setSessions((prev) => sortSessions(prev.map((s) => (s.id === id ? { ...s, ...data } : s))))
    const { error } = await supabase.from('campaign_sessions').update(data).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour de la session :', error)
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

  return { sessions, loading, error, createSession, updateSession, deleteSession, refetch: fetchAll }
}
