import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { CampaignChapter } from '../types'
import { EMPTY_CHAPTER_CONTENT } from '../types'

type ChapterInput = { title: string; icon: string; image_url: string | null; image_position?: number; content?: CampaignChapter['content']; notes?: CampaignChapter['notes']; done?: boolean; position?: number }

export function useCampaignChapters(sessionId: number | null) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [chapters, setChapters] = useState<CampaignChapter[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async () => {
    if (!sessionId) {
      setChapters([])
      setLoading(false)
      return
    }
    setLoading(true)
    setError(null)
    try {
      const { data, error } = await supabase
        .from('campaign_chapters')
        .select('*')
        .eq('session_id', sessionId)
        .order('position')
      if (error) throw error
      setChapters(data ?? [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [sessionId])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  // Abonnement temps réel : filtré côté client comme player_items
  useEffect(() => {
    if (!sessionId) return
    const channel = supabase
      .channel(`campaign-chapters-changes-${sessionId}-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'campaign_chapters' },
        (payload) => {
          const chapter = payload.new as CampaignChapter
          if (chapter.session_id !== sessionId) return
          setChapters((prev) => (prev.some((c) => c.id === chapter.id) ? prev : [...prev, chapter]))
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'campaign_chapters' },
        (payload) => {
          const chapter = payload.new as CampaignChapter
          if (chapter.session_id !== sessionId) return
          setChapters((prev) => prev.map((c) => (c.id === chapter.id ? chapter : c)))
        }
      )
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table: 'campaign_chapters' },
        (payload) => {
          const id = (payload.old as { id: number }).id
          setChapters((prev) => prev.filter((c) => c.id !== id))
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [sessionId])

  const createChapter = useCallback(async (data: ChapterInput) => {
    if (!sessionId) return null
    const { data: created, error } = await supabase
      .from('campaign_chapters')
      .insert({ session_id: sessionId, content: EMPTY_CHAPTER_CONTENT, position: chapters.length, ...data })
      .select()
      .single()
    if (error) {
      console.error('Erreur lors de la création du chapitre :', error)
      return null
    }
    setChapters((prev) => [...prev, created as CampaignChapter])
    return created as CampaignChapter
  }, [sessionId, chapters.length])

  const updateChapter = useCallback(async (id: number, data: Partial<ChapterInput>) => {
    setChapters((prev) => prev.map((c) => (c.id === id ? { ...c, ...data } : c)))
    const { error } = await supabase.from('campaign_chapters').update(data).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour du chapitre :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const reorderChapters = useCallback(async (orderedIds: number[]) => {
    setChapters((prev) => {
      const byId = new Map(prev.map((c) => [c.id, c]))
      return orderedIds.map((id, i) => ({ ...byId.get(id)!, position: i }))
    })
    const results = await Promise.all(
      orderedIds.map((id, i) => supabase.from('campaign_chapters').update({ position: i }).eq('id', id))
    )
    if (results.some((r) => r.error)) {
      console.error('Erreur lors de la réorganisation des chapitres :', results.find((r) => r.error)?.error)
      await fetchAll()
    }
  }, [fetchAll])

  const deleteChapter = useCallback(async (id: number) => {
    setChapters((prev) => prev.filter((c) => c.id !== id))
    const { error } = await supabase.from('campaign_chapters').delete().eq('id', id)
    if (error) {
      console.error('Erreur lors de la suppression du chapitre :', error)
      await fetchAll()
    }
  }, [fetchAll])

  return { chapters, loading, error, createChapter, updateChapter, deleteChapter, reorderChapters, refetch: fetchAll }
}
