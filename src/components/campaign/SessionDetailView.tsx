import { useEffect, useState } from 'react'
import type { CampaignSession, Player, CarteLocation, Attack, Item, Pokemon, Encounter, DisplayAsset, DisplayState } from '../../types'
import { EMPTY_CHAPTER_CONTENT } from '../../types'
import type { ReferenceEntry, ReferenceIndex } from '../../hooks/useReferenceIndex'
import type { UpdateDisplayState } from '../../lib/displayActions'
import { useCampaignChapters } from '../../hooks/useCampaignChapters'
import { ChapterCard } from './ChapterCard'
import { ChapterEditor } from './ChapterEditor'
import { ChapterViewPopup } from './ChapterViewPopup'
import { SessionViewPopup } from './SessionViewPopup'
import { ReferenceDispatcher } from './ReferenceDispatcher'
import { SetBannerBackgroundButton } from './SetBannerBackgroundButton'
import { BannerPickerButton } from './BannerPickerButton'
import { EditableHeaderImage } from './EditableHeaderImage'
import { EmojiPickerButton } from './EmojiPickerButton'
import { CampaignIcon } from './CampaignIcon'
import { DoneToggle } from './DoneToggle'
import { NotesFab } from './NotesFab'
import { ImageLightbox } from '../ImageLightbox'
import { ConfirmPopup } from '../ConfirmPopup'
import { PixelIcon } from '../icons/PixelIcon'
import { EyeIcon } from '../icons/EyeIcon'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'
import { formatDateFr } from '../../lib/formatDate'
import { SAVE_ICON } from '../../lib/icons'

interface Props {
  session: CampaignSession
  onUpdateSession: (id: number, data: { title?: string; icon?: string; session_date?: string | null; image_url?: string | null; image_position?: number; done?: boolean; notes?: CampaignSession['notes'] }) => void
  onDeleteSession: (id: number) => void
  onBack: () => void
  referenceIndex: ReferenceIndex
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  playersByName: Map<string, Player>
  locationsByName: Map<string, CarteLocation>
  encountersByLieu: Map<string, Encounter[]>
  displayState: DisplayState
  displayAssets: DisplayAsset[]
  updateDisplayState: UpdateDisplayState
}

const emptyChapterForm = { title: '', icon: '📄' }

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
  encountersByLieu,
  displayState,
  displayAssets,
  updateDisplayState,
}: Props) {
  const { chapters, loading, createChapter, updateChapter, deleteChapter, reorderChapters } = useCampaignChapters(session.id)
  const [selectedChapterId, setSelectedChapterId] = useState<number | null>(null)
  const [viewingChapterId, setViewingChapterId] = useState<number | null>(null)
  const [viewingSession, setViewingSession] = useState(false)
  const [viewerOpen, setViewerOpen] = useState(false)
  const [confirmDeleteSession, setConfirmDeleteSession] = useState(false)
  const [draggedChapterId, setDraggedChapterId] = useState<number | null>(null)
  const [sessionNotesReference, setSessionNotesReference] = useState<ReferenceEntry | null>(null)

  const [editingSession, setEditingSession] = useState(false)
  const [sessionForm, setSessionForm] = useState({
    title: session.title,
    icon: session.icon,
    session_date: session.session_date ?? '',
    image_url: session.image_url ?? '',
    image_position: session.image_position ?? 50,
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
        encountersByLieu={encountersByLieu}
        displayState={displayState}
        displayAssets={displayAssets}
        updateDisplayState={updateDisplayState}
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
      image_position: sessionForm.image_position,
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
    })
    setCreatingChapter(false)
    setChapterForm(emptyChapterForm)
    setShowChapterForm(false)
    if (created) setSelectedChapterId(created.id)
  }

  const handleDrop = (targetId: number) => {
    if (draggedChapterId == null || draggedChapterId === targetId) {
      setDraggedChapterId(null)
      return
    }
    const ids = chapters.map((c) => c.id)
    const from = ids.indexOf(draggedChapterId)
    const to = ids.indexOf(targetId)
    ids.splice(to, 0, ids.splice(from, 1)[0])
    reorderChapters(ids)
    setDraggedChapterId(null)
  }

  return (
    <div className="flex-1 overflow-y-auto p-4">
      <button onClick={onBack} className={`mb-3 text-sm rounded px-3 py-1.5 ${BUTTON_STYLE.gray}`}>
        ← Retour aux sessions
      </button>

      {editingSession ? (
        sessionForm.image_url && (
          <EditableHeaderImage
            src={sessionForm.image_url}
            alt={sessionForm.title}
            position={sessionForm.image_position}
            onPositionChange={(p) => setSessionForm((f) => ({ ...f, image_position: p }))}
            className="w-full h-32 rounded-lg mb-3 border-2 border-ink"
          />
        )
      ) : (
        session.image_url && (
          <div className="relative w-full h-32 rounded-lg overflow-hidden mb-3 border-2 border-ink">
            <button
              onClick={() => setViewerOpen(true)}
              className="block w-full h-full"
            >
              <img
                src={session.image_url}
                alt={session.title}
                className="w-full h-full object-cover"
                style={{ objectPosition: `50% ${session.image_position ?? 50}%` }}
              />
            </button>
            <SetBannerBackgroundButton imageUrl={session.image_url} updateDisplayState={updateDisplayState} />
          </div>
        )
      )}

      {editingSession ? (
        <div className="mb-4 p-3 rounded-lg bg-cream-secondary border-2 border-ink">
          <div className="flex items-center gap-2 mb-2">
            <EmojiPickerButton
              trigger={<CampaignIcon icon={sessionForm.icon} size={24} emojiClassName="text-xl" />}
              triggerClassName={`w-10 h-10 rounded-lg text-xl flex items-center justify-center shrink-0 ${PIXEL_BORDER_SM} bg-cream`}
              onSelect={(icon) => setSessionForm((f) => ({ ...f, icon }))}
              itemsByName={itemsByName}
              pokemonByName={pokemonByName}
              playersByName={playersByName}
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
          <div className="flex items-center gap-2 mb-3">
            <BannerPickerButton
              displayAssets={displayAssets}
              onSelect={(url) => setSessionForm((f) => ({ ...f, image_url: url }))}
              variant="button"
              label={sessionForm.image_url ? "Changer l'image" : 'Choisir une image'}
            />
            {sessionForm.image_url && (
              <button
                type="button"
                onClick={() => setSessionForm((f) => ({ ...f, image_url: '' }))}
                className={`text-xs px-2 py-2 rounded ${BUTTON_STYLE.gray}`}
              >
                Retirer
              </button>
            )}
          </div>
          <div className="grid grid-cols-2 gap-2">
            <button onClick={() => setEditingSession(false)} className={`py-2 rounded text-sm ${BUTTON_STYLE.gray}`}>
              Annuler
            </button>
            <button
              onClick={handleSaveSession}
              disabled={!sessionForm.title.trim()}
              className={`py-2 rounded text-sm font-bold inline-flex items-center justify-center gap-1.5 disabled:opacity-50 ${BUTTON_STYLE.yellow}`}
            >
              <PixelIcon src={SAVE_ICON} size={16} />
              Enregistrer
            </button>
          </div>
        </div>
      ) : (
        <div className="flex items-center gap-2 mb-4">
          <CampaignIcon icon={session.icon} size={34} emojiClassName="text-3xl" />
          <div className="flex-1 min-w-0">
            <h2 className="text-cream text-lg font-bold truncate">{session.title}</h2>
            {session.session_date && (
              <p className="text-[#7a7c9a] text-xs">{formatDateFr(session.session_date)}</p>
            )}
          </div>
          <DoneToggle done={session.done} onToggle={() => onUpdateSession(session.id, { done: !session.done })} />
          <button
            onClick={() => setViewingSession(true)}
            title="Voir toute la session"
            className={`text-xs rounded px-2 py-1 inline-flex items-center gap-1 ${BUTTON_STYLE.gray}`}
          >
            <EyeIcon className="w-3.5 h-3.5" /> Voir tout
          </button>
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
              trigger={<CampaignIcon icon={chapterForm.icon} size={24} emojiClassName="text-xl" />}
              triggerClassName={`w-10 h-10 rounded-lg text-xl flex items-center justify-center shrink-0 ${PIXEL_BORDER_SM} bg-cream`}
              onSelect={(icon) => setChapterForm((f) => ({ ...f, icon }))}
              itemsByName={itemsByName}
              pokemonByName={pokemonByName}
              playersByName={playersByName}
            />
            <input
              type="text"
              value={chapterForm.title}
              onChange={(e) => setChapterForm((f) => ({ ...f, title: e.target.value }))}
              placeholder="Titre du chapitre"
              className="flex-1 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
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
            <div
              key={chapter.id}
              draggable
              onDragStart={() => setDraggedChapterId(chapter.id)}
              onDragOver={(e) => e.preventDefault()}
              onDrop={() => handleDrop(chapter.id)}
              onDragEnd={() => setDraggedChapterId(null)}
              className={draggedChapterId === chapter.id ? 'opacity-40' : ''}
            >
              <ChapterCard
                chapter={chapter}
                onClick={() => setSelectedChapterId(chapter.id)}
                onView={() => setViewingChapterId(chapter.id)}
              />
            </div>
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
          encountersByLieu={encountersByLieu}
          displayState={displayState}
          displayAssets={displayAssets}
          updateDisplayState={updateDisplayState}
          onToggleDone={() => updateChapter(viewingChapter.id, { done: !viewingChapter.done })}
          onSaveNotes={(notes) => updateChapter(viewingChapter.id, { notes })}
          onClose={() => setViewingChapterId(null)}
        />
      )}

      {viewingSession && (
        <SessionViewPopup
          session={session}
          chapters={chapters}
          referenceIndex={referenceIndex}
          pokemonByName={pokemonByName}
          attacksByName={attacksByName}
          itemsByName={itemsByName}
          playersByName={playersByName}
          locationsByName={locationsByName}
          encountersByLieu={encountersByLieu}
          displayState={displayState}
          displayAssets={displayAssets}
          updateDisplayState={updateDisplayState}
          onClose={() => setViewingSession(false)}
        />
      )}

      {!editingSession && !viewingChapter && !viewingSession && (
        <NotesFab
          notes={session.notes ?? EMPTY_CHAPTER_CONTENT}
          onSave={(notes) => onUpdateSession(session.id, { notes })}
          referenceIndex={referenceIndex}
          onReferenceClick={(entry) => setSessionNotesReference(entry)}
          displayState={displayState}
          displayAssets={displayAssets}
          updateDisplayState={updateDisplayState}
        />
      )}

      <ReferenceDispatcher
        activeReference={sessionNotesReference}
        pokemonByName={pokemonByName}
        attacksByName={attacksByName}
        itemsByName={itemsByName}
        playersByName={playersByName}
        locationsByName={locationsByName}
        encountersByLieu={encountersByLieu}
        displayState={displayState}
        displayAssets={displayAssets}
        updateDisplayState={updateDisplayState}
        onClose={() => setSessionNotesReference(null)}
      />

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
