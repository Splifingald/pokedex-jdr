import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { CampaignChapter } from '../types'

// Charge tous les chapitres, toutes sessions confondues — sert uniquement à construire l'index
// de référence global (permet de référencer un chapitre depuis n'importe quelle session) et à
// mettre à jour un chapitre référencé sans connaître sa session. La vue de session ouverte a sa
// propre copie scopée via useCampaignChapters ; les deux restent synchronisées par le realtime
// Supabase (l'UPDATE émis ici est reçu par les deux abonnements).
export function useAllCampaignChapters() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [chapters, setChapters] = useState<CampaignChapter[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    try {
      const { data, error } = await supabase.from('campaign_chapters').select('*')
      if (error) throw error
      setChapters(data ?? [])
    } catch (err) {
      console.error('Erreur lors du chargement des chapitres :', err)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`campaign-chapters-all-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'campaign_chapters' },
        (payload) => {
          const chapter = payload.new as CampaignChapter
          setChapters((prev) => (prev.some((c) => c.id === chapter.id) ? prev : [...prev, chapter]))
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'campaign_chapters' },
        (payload) => {
          const chapter = payload.new as CampaignChapter
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
  }, [])

  const updateChapter = useCallback(async (id: number, data: Partial<Pick<CampaignChapter, 'title' | 'icon' | 'content' | 'notes' | 'done'>>) => {
    setChapters((prev) => prev.map((c) => (c.id === id ? { ...c, ...data } : c)))
    const { error } = await supabase.from('campaign_chapters').update(data).eq('id', id)
    if (error) {
      console.error('Erreur lors de la mise à jour du chapitre :', error)
      await fetchAll()
    }
  }, [fetchAll])

  return { chapters, loading, updateChapter }
}
