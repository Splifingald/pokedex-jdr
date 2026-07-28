import { useEffect, useRef, useState } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Underline from '@tiptap/extension-underline'
import { TextStyle } from '@tiptap/extension-text-style'
import Color from '@tiptap/extension-color'
import type { CampaignChapter, Player, CarteLocation, Attack, Item, Pokemon, Encounter } from '../../types'
import { EMPTY_CHAPTER_CONTENT } from '../../types'
import type { ReferenceEntry, ReferenceIndex } from '../../hooks/useReferenceIndex'
import { ReferenceHighlight, forceReferenceRecompute } from '../../lib/referenceExtension'
import { EditorToolbar } from './EditorToolbar'
import { EmojiPickerButton } from './EmojiPickerButton'
import { ReferenceDispatcher } from './ReferenceDispatcher'
import { EditableHeaderImage } from './EditableHeaderImage'
import { ImageLightbox } from '../ImageLightbox'
import { ConfirmPopup } from '../ConfirmPopup'
import { DoneToggle } from './DoneToggle'
import { PixelIcon } from '../icons/PixelIcon'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { PANEL_LG, PIXEL_BORDER_SM } from '../../lib/panelStyles'
import { SAVE_ICON } from '../../lib/icons'

interface Props {
  chapter: CampaignChapter
  referenceIndex: ReferenceIndex
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  playersByName: Map<string, Player>
  locationsByName: Map<string, CarteLocation>
  encountersByLieu: Map<string, Encounter[]>
  onUpdate: (id: number, data: { title?: string; icon?: string; image_url?: string | null; image_position?: number; content?: CampaignChapter['content']; done?: boolean }) => void
  onDelete: (id: number) => void
  onBack: () => void
}

export function ChapterEditor({
  chapter,
  referenceIndex,
  pokemonByName,
  attacksByName,
  itemsByName,
  playersByName,
  locationsByName,
  encountersByLieu,
  onUpdate,
  onDelete,
  onBack,
}: Props) {
  const [title, setTitle] = useState(chapter.title)
  const [icon, setIcon] = useState(chapter.icon)
  const [imageUrl, setImageUrl] = useState(chapter.image_url ?? '')
  const [imagePosition, setImagePosition] = useState(chapter.image_position ?? 50)
  const [dirty, setDirty] = useState(false)
  const [viewerOpen, setViewerOpen] = useState(false)
  const [confirmBack, setConfirmBack] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [activeReference, setActiveReference] = useState<ReferenceEntry | null>(null)

  const indexRef = useRef(referenceIndex)
  useEffect(() => { indexRef.current = referenceIndex }, [referenceIndex])

  const editor = useEditor({
    content: chapter.content ?? EMPTY_CHAPTER_CONTENT,
    extensions: [
      StarterKit,
      Underline,
      TextStyle,
      Color,
      ReferenceHighlight.configure({
        getIndex: () => indexRef.current,
        onReferenceClick: (entry) => setActiveReference(entry),
      }),
    ],
    onUpdate: () => setDirty(true),
  })

  // Recompose les décorations si l'index de référence change sans que le document ait changé
  // (ex : un PNJ ajouté ailleurs dans l'app pendant que ce chapitre est ouvert)
  useEffect(() => {
    if (editor) forceReferenceRecompute(editor)
  }, [editor, referenceIndex])

  useEffect(() => {
    if (!dirty) return
    const handler = (e: BeforeUnloadEvent) => { e.preventDefault() }
    window.addEventListener('beforeunload', handler)
    return () => window.removeEventListener('beforeunload', handler)
  }, [dirty])

  const handleSave = () => {
    onUpdate(chapter.id, { title, icon, image_url: imageUrl.trim() || null, image_position: imagePosition, content: editor?.getJSON() })
    setDirty(false)
  }

  // Raccourci Ctrl+S / Cmd+S pour enregistrer
  const handleSaveRef = useRef(handleSave)
  useEffect(() => { handleSaveRef.current = handleSave })
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
        e.preventDefault()
        handleSaveRef.current()
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [])

  const handleBack = () => {
    if (dirty) {
      setConfirmBack(true)
      return
    }
    onBack()
  }

  const handleSaveAndQuit = () => {
    handleSave()
    setConfirmBack(false)
    onBack()
  }

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <div className="shrink-0 p-4 border-b-2 border-[#cfc7a8]">
        <div className="flex items-center gap-2 mb-3">
          <button onClick={handleBack} className={`text-sm rounded px-3 py-1.5 ${BUTTON_STYLE.gray}`}>
            ← Retour
          </button>
          <DoneToggle done={chapter.done} onToggle={() => onUpdate(chapter.id, { done: !chapter.done })} />
          <span className="flex-1" />
          {dirty && <span className="text-xs text-[#ffd75e] font-bold">● Non enregistré</span>}
          <button onClick={handleSave} className={`text-sm rounded px-3 py-1.5 font-bold inline-flex items-center gap-1.5 ${BUTTON_STYLE.green}`}>
            <PixelIcon src={SAVE_ICON} size={16} />
            Enregistrer
          </button>
          <button onClick={() => setConfirmDelete(true)} className={`text-sm rounded px-3 py-1.5 ${BUTTON_STYLE.red}`}>
            🗑
          </button>
        </div>

        {imageUrl && (
          <div className="relative w-full h-24 rounded-lg mb-3 border-2 border-ink overflow-hidden">
            <EditableHeaderImage
              src={imageUrl}
              alt={title}
              position={imagePosition}
              onPositionChange={(p) => { setImagePosition(p); setDirty(true) }}
              className="w-full h-full"
            />
            <button
              type="button"
              onClick={() => setViewerOpen(true)}
              title="Agrandir"
              className="absolute top-1 left-1 w-7 h-7 rounded-md flex items-center justify-center text-sm bg-black/50 text-white"
            >
              🔍
            </button>
          </div>
        )}

        <div className="flex items-center gap-2">
          <EmojiPickerButton
            trigger={icon}
            title="Changer l'icône"
            triggerClassName={`w-10 h-10 rounded-lg text-xl flex items-center justify-center shrink-0 ${PIXEL_BORDER_SM} bg-cream`}
            onSelect={(e) => { setIcon(e); setDirty(true) }}
          />
          <input
            type="text"
            value={title}
            onChange={(e) => { setTitle(e.target.value); setDirty(true) }}
            placeholder="Titre du chapitre"
            className={`flex-1 px-3 py-2 rounded-lg ${PIXEL_BORDER_SM} bg-cream text-ink text-sm outline-none`}
          />
        </div>
        <input
          type="text"
          value={imageUrl}
          onChange={(e) => { setImageUrl(e.target.value); setDirty(true) }}
          placeholder="Lien de l'image de référence (optionnel)"
          className={`w-full mt-2 px-3 py-2 rounded-lg ${PIXEL_BORDER_SM} bg-cream text-ink text-sm outline-none`}
        />
      </div>

      <EditorToolbar editor={editor} />
      <div className="flex-1 overflow-y-auto p-4 bg-cream text-ink">
        <EditorContent editor={editor} />
      </div>

      {viewerOpen && imageUrl && (
        <ImageLightbox src={imageUrl} alt={title} onClose={() => setViewerOpen(false)} />
      )}

      {confirmBack && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
          <div className={`${PANEL_LG} max-w-xs w-full p-6`}>
            <div className="text-center mb-5">
              <h3 className="text-ink text-lg">Modifications non enregistrées</h3>
              <p className="text-ink-muted text-sm mt-2">Que voulez-vous faire avant de quitter ?</p>
            </div>
            <div className="flex flex-col gap-2">
              <button
                onClick={handleSaveAndQuit}
                className={`py-2.5 rounded text-sm font-bold inline-flex items-center justify-center gap-1.5 ${BUTTON_STYLE.green}`}
              >
                <PixelIcon src={SAVE_ICON} size={16} />
                Enregistrer et quitter
              </button>
              <button
                onClick={() => { setConfirmBack(false); onBack() }}
                className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.red}`}
              >
                Quitter sans enregistrer
              </button>
              <button
                onClick={() => setConfirmBack(false)}
                className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.gray}`}
              >
                Annuler
              </button>
            </div>
          </div>
        </div>
      )}

      {confirmDelete && (
        <ConfirmPopup
          title="Supprimer ce chapitre ?"
          message={`${chapter.title} sera définitivement supprimé.`}
          confirmLabel="Supprimer"
          danger
          onConfirm={() => { setConfirmDelete(false); onDelete(chapter.id) }}
          onCancel={() => setConfirmDelete(false)}
        />
      )}

      <ReferenceDispatcher
        activeReference={activeReference}
        pokemonByName={pokemonByName}
        attacksByName={attacksByName}
        itemsByName={itemsByName}
        playersByName={playersByName}
        locationsByName={locationsByName}
        encountersByLieu={encountersByLieu}
        onClose={() => setActiveReference(null)}
      />
    </div>
  )
}
