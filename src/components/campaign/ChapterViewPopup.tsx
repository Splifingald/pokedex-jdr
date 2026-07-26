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
import { ReferenceDispatcher } from './ReferenceDispatcher'
import { DoneToggle } from './DoneToggle'
import { NotesFab } from './NotesFab'
import { PANEL_LG } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  chapter: CampaignChapter
  referenceIndex: ReferenceIndex
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  playersByName: Map<string, Player>
  locationsByName: Map<string, CarteLocation>
  encountersByLieu: Map<string, Encounter[]>
  onToggleDone: () => void
  onSaveNotes: (notes: CampaignChapter['notes']) => void
  onClose: () => void
}

export function ChapterViewPopup({
  chapter,
  referenceIndex,
  pokemonByName,
  attacksByName,
  itemsByName,
  playersByName,
  locationsByName,
  encountersByLieu,
  onToggleDone,
  onSaveNotes,
  onClose,
}: Props) {
  const [activeReference, setActiveReference] = useState<ReferenceEntry | null>(null)

  const indexRef = useRef(referenceIndex)
  useEffect(() => { indexRef.current = referenceIndex }, [referenceIndex])

  const editor = useEditor({
    content: chapter.content ?? EMPTY_CHAPTER_CONTENT,
    editable: false,
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
  })

  useEffect(() => {
    if (editor) forceReferenceRecompute(editor)
  }, [editor, referenceIndex])

  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onClose])

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className={`${PANEL_LG} max-w-2xl w-full max-h-[90vh] flex flex-col overflow-hidden`}>
        <div className="shrink-0 flex items-center gap-2 p-4 border-b-2 border-[#cfc7a8]">
          <span className="text-2xl shrink-0">{chapter.icon}</span>
          <h3 className="text-ink font-bold flex-1 truncate">{chapter.title}</h3>
          <DoneToggle done={chapter.done} onToggle={onToggleDone} />
          <button
            onClick={onClose}
            className={`w-8 h-8 shrink-0 rounded-md text-sm font-bold ${BUTTON_STYLE.gray}`}
          >
            ✕
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-4 bg-cream text-ink">
          {chapter.image_url && (
            <img
              src={chapter.image_url}
              alt={chapter.title}
              className="w-full h-32 object-cover rounded-lg mb-4 border-2 border-ink"
            />
          )}
          <EditorContent editor={editor} />
        </div>
      </div>

      <NotesFab
        notes={chapter.notes ?? EMPTY_CHAPTER_CONTENT}
        onSave={onSaveNotes}
        referenceIndex={referenceIndex}
        onReferenceClick={(entry) => setActiveReference(entry)}
      />

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
