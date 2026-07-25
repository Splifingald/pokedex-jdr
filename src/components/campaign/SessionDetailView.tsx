import { useEffect, useState } from 'react'
import type { CampaignSession, Player, CarteLocation, Attack, Item, Pokemon } from '../../types'
import type { ReferenceIndex } from '../../hooks/useReferenceIndex'
import { useCampaignChapters } from '../../hooks/useCampaignChapters'
import { ChapterCard } from './ChapterCard'
import { ChapterEditor } from './ChapterEditor'
import { ChapterViewPopup } from './ChapterViewPopup'
import { EmojiPickerButton } from './EmojiPickerButton'
import { DoneToggle } from './DoneToggle'
import { ImageLightbox } from '../ImageLightbox'
import { ConfirmPopup } from '../ConfirmPopup'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'
import { formatDateFr } from '../../lib/formatDate'

interface Props {
  session: CampaignSession
  onUpdateSession: (id: number, data: { title?: string; icon?: string; session_date?: string | null; image_url?: string | null; done?: boolean }) => void
  onDeleteSession: (id: number) => void
  onBack: () => void
  referenceIndex: ReferenceIndex
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  playersByName: Map<string, Player>
  locationsByName: Map<string, CarteLocation>
}

const emptyChapterForm = { title: '', icon: '📄', image_url: '' }

export function SessionDetailView({
  session,
  onUpdateSession,
  onDeleteSession,
  onBack,
  referenceIndex,
  pokemonByName,
  attacksByName,
  itemsByName,
  playersByName,
  locationsByName,
}: Props) {
  const { chapters, loading, createChapter, updateChapter, deleteChapter } = useCampaignChapters(session.id)
  const [selectedChapterId, setSelectedChapterId] = useState<number | null>(null)
  const [viewingChapterId, setViewingChapterId] = useState<number | null>(null)
  const [viewerOpen, setViewerOpen] = useState(false)
  const [confirmDeleteSession, setConfirmDeleteSession] = useState(false)

  const [editingSession, setEditingSession] = useState(false)
  const [sessionForm, setSessionForm] = useState({
    title: session.title,
    icon: session.icon,
    session_date: session.session_date ?? '',
    image_url: session.image_url ?? '',
  })

  const [showChapterForm, setShowChapterForm] = useState(false)
  const [chapterForm, setChapterForm] = useState(emptyChapterForm)
  const [creatingChapter, setCreatingChapter] = useState(false)

  useEffect(() => {
    if (selectedChapterId != null && !chapters.some((c) => c.id === selectedChapterId)) {
      setSelectedChapterId(null)
    }
    if (viewingChapterId != null && !chapters.some((c) => c.id === viewingChapterId)) {
      setViewingChapterId(null)
    }
  }, [chapters, selectedChapterId, viewingChapterId])

  const selectedChapter = chapters.find((c) => c.id === selectedChapterId) ?? null
  const viewingChapter = chapters.find((c) => c.id === viewingChapterId) ?? null

  if (selectedChapter) {
    return (
      <ChapterEditor
        key={selectedChapter.id}
        chapter={selectedChapter}
        referenceIndex={referenceIndex}
        pokemonByName={pokemonByName}
        attacksByName={attacksByName}
        itemsByName={itemsByName}
        playersByName={playersByName}
        locationsByName={locationsByName}
        onUpdate={(id, data) => updateChapter(id, data)}
        onDelete={(id) => { deleteChapter(id); setSelectedChapterId(null) }}
        onBack={() => setSelectedChapterId(null)}
      />
    )
  }

  const handleSaveSession = () => {
    onUpdateSession(session.id, {
      title: sessionForm.title,
      icon: sessionForm.icon,
      session_date: sessionForm.session_date || null,
      image_url: sessionForm.image_url.trim() || null,
    })
    setEditingSession(false)
  }

  const handleCreateChapter = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!chapterForm.title.trim()) return
    setCreatingChapter(true)
    const created = await createChapter({
      title: chapterForm.title,
      icon: chapterForm.icon,
      image_url: chapterForm.image_url.trim() || null,
    })
    setCreatingChapter(false)
    setChapterForm(emptyChapterForm)
    setShowChapterForm(false)
    if (created) setSelectedChapterId(created.id)
  }

  return (
    <div className="flex-1 overflow-y-auto p-4">
      <button onClick={onBack} className={`mb-3 text-sm rounded px-3 py-1.5 ${BUTTON_STYLE.gray}`}>
        ← Retour aux sessions
      </button>

      {session.image_url && (
        <button
          onClick={() => setViewerOpen(true)}
          className="block w-full h-32 rounded-lg overflow-hidden mb-3 border-2 border-ink"
        >
          <img src={session.image_url} alt={session.title} className="w-full h-full object-cover" />
        </button>
      )}

      {editingSession ? (
        <div className="mb-4 p-3 rounded-lg bg-cream-secondary border-2 border-ink">
          <div className="flex items-center gap-2 mb-2">
            <EmojiPickerButton
              trigger={sessionForm.icon}
              triggerClassName={`w-10 h-10 rounded-lg text-xl flex items-center justify-center shrink-0 ${PIXEL_BORDER_SM} bg-cream`}
              onSelect={(icon) => setSessionForm((f) => ({ ...f, icon }))}
            />
            <input
              type="text"
              value={sessionForm.title}
              onChange={(e) => setSessionForm((f) => ({ ...f, title: e.target.value }))}
              placeholder="Titre de la session"
              className="flex-1 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
          <input
            type="date"
            value={sessionForm.session_date}
            onChange={(e) => setSessionForm((f) => ({ ...f, session_date: e.target.value }))}
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none mb-2"
          />
          <input
            type="text"
            value={sessionForm.image_url}
            onChange={(e) => setSessionForm((f) => ({ ...f, image_url: e.target.value }))}
            placeholder="Lien de l'image de référence (optionnel)"
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none mb-3"
          />
          <div className="grid grid-cols-2 gap-2">
            <button onClick={() => setEditingSession(false)} className={`py-2 rounded text-sm ${BUTTON_STYLE.gray}`}>
              Annuler
            </button>
            <button
              onClick={handleSaveSession}
              disabled={!sessionForm.title.trim()}
              className={`py-2 rounded text-sm font-bold disabled:opacity-50 ${BUTTON_STYLE.yellow}`}
            >
              Enregistrer
            </button>
          </div>
        </div>
      ) : (
        <div className="flex items-center gap-2 mb-4">
          <span className="text-3xl shrink-0">{session.icon}</span>
          <div className="flex-1 min-w-0">
            <h2 className="text-cream text-lg font-bold truncate">{session.title}</h2>
            {session.session_date && (
              <p className="text-[#7a7c9a] text-xs">{formatDateFr(session.session_date)}</p>
            )}
          </div>
          <DoneToggle done={session.done} onToggle={() => onUpdateSession(session.id, { done: !session.done })} />
          <button onClick={() => setEditingSession(true)} className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}>
            Éditer
          </button>
          <button onClick={() => setConfirmDeleteSession(true)} className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}>
            Suppr.
          </button>
        </div>
      )}

      <div className="flex items-center justify-between mb-2">
        <p className="text-[#7a7c9a] text-xs font-bold">CHAPITRES</p>
        <button onClick={() => setShowChapterForm((s) => !s)} className={`text-xs rounded px-2 py-1 font-bold ${BUTTON_STYLE.yellow}`}>
          + Nouveau chapitre
        </button>
      </div>

      {showChapterForm && (
        <form onSubmit={handleCreateChapter} className="mb-4 p-3 rounded-lg bg-cream-secondary border-2 border-ink">
          <div className="flex items-center gap-2 mb-2">
            <EmojiPickerButton
              trigger={chapterForm.icon}
              triggerClassName={`w-10 h-10 rounded-lg text-xl flex items-center justify-center shrink-0 ${PIXEL_BORDER_SM} bg-cream`}
              onSelect={(icon) => setChapterForm((f) => ({ ...f, icon }))}
            />
            <input
              type="text"
              value={chapterForm.title}
              onChange={(e) => setChapterForm((f) => ({ ...f, title: e.target.value }))}
              placeholder="Titre du chapitre"
              className="flex-1 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
          <input
            type="text"
            value={chapterForm.image_url}
            onChange={(e) => setChapterForm((f) => ({ ...f, image_url: e.target.value }))}
            placeholder="Lien de l'image de référence (optionnel)"
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none mb-3"
          />
          <button
            type="submit"
            disabled={creatingChapter || !chapterForm.title.trim()}
            className={`w-full py-2 rounded text-sm font-bold disabled:opacity-50 ${BUTTON_STYLE.yellow}`}
          >
            Créer
          </button>
        </form>
      )}

      {loading ? (
        <p className="text-[#7a7c9a] text-sm">Chargement…</p>
      ) : chapters.length === 0 ? (
        <p className="text-[#7a7c9a] text-sm">Aucun chapitre pour l'instant.</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {chapters.map((chapter) => (
            <ChapterCard
              key={chapter.id}
              chapter={chapter}
              onClick={() => setSelectedChapterId(chapter.id)}
              onView={() => setViewingChapterId(chapter.id)}
            />
          ))}
        </div>
      )}

      {viewerOpen && session.image_url && (
        <ImageLightbox src={session.image_url} alt={session.title} onClose={() => setViewerOpen(false)} />
      )}

      {viewingChapter && (
        <ChapterViewPopup
          chapter={viewingChapter}
          referenceIndex={referenceIndex}
          pokemonByName={pokemonByName}
          attacksByName={attacksByName}
          itemsByName={itemsByName}
          playersByName={playersByName}
          locationsByName={locationsByName}
          onToggleDone={() => updateChapter(viewingChapter.id, { done: !viewingChapter.done })}
          onClose={() => setViewingChapterId(null)}
        />
      )}

      {confirmDeleteSession && (
        <ConfirmPopup
          title="Supprimer cette session ?"
          message={`${session.title} et tous ses chapitres seront définitivement supprimés.`}
          confirmLabel="Supprimer"
          danger
          onConfirm={() => { setConfirmDeleteSession(false); onDeleteSession(session.id); onBack() }}
          onCancel={() => setConfirmDeleteSession(false)}
        />
      )}
    </div>
  )
}
