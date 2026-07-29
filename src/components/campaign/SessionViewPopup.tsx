import { useEffect, useRef, useState } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Underline from '@tiptap/extension-underline'
import { TextStyle } from '@tiptap/extension-text-style'
import Color from '@tiptap/extension-color'
import type { CampaignSession, CampaignChapter, Player, CarteLocation, Attack, Item, Pokemon, Encounter } from '../../types'
import { EMPTY_CHAPTER_CONTENT } from '../../types'
import type { ReferenceEntry, ReferenceIndex } from '../../hooks/useReferenceIndex'
import { ReferenceHighlight, forceReferenceRecompute } from '../../lib/referenceExtension'
import { ReferenceDispatcher } from './ReferenceDispatcher'
import { PANEL_LG } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { CampaignIcon } from './CampaignIcon'

interface BlockProps {
  chapter: CampaignChapter
  referenceIndex: ReferenceIndex
  onReferenceClick: (entry: ReferenceEntry) => void
}

function SessionViewChapterBlock({ chapter, referenceIndex, onReferenceClick }: BlockProps) {
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
        onReferenceClick,
      }),
    ],
  })

  useEffect(() => {
    if (editor) forceReferenceRecompute(editor)
  }, [editor, referenceIndex])

  return (
    <div className="mb-6 last:mb-0">
      <div className="flex items-center gap-2 mb-3 pb-2 border-b-2 border-[#cfc7a8]">
        <CampaignIcon icon={chapter.icon} size={24} emojiClassName="text-xl" />
        <h4 className="font-bold text-ink flex-1 truncate">{chapter.title}</h4>
        {chapter.done && <span title="Terminé">✅</span>}
      </div>
      {chapter.image_url && (
        <img
          src={chapter.image_url}
          alt={chapter.title}
          className="w-full h-28 object-cover rounded-lg mb-3 border-2 border-ink"
          style={{ objectPosition: `50% ${chapter.image_position ?? 50}%` }}
        />
      )}
      <EditorContent editor={editor} />
    </div>
  )
}

interface Props {
  session: CampaignSession
  chapters: CampaignChapter[]
  referenceIndex: ReferenceIndex
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  playersByName: Map<string, Player>
  locationsByName: Map<string, CarteLocation>
  encountersByLieu: Map<string, Encounter[]>
  onClose: () => void
}

// Vue "lecture" de la session complète : tous les chapitres empilés dans l'ordre, en lecture seule.
export function SessionViewPopup({
  session,
  chapters,
  referenceIndex,
  pokemonByName,
  attacksByName,
  itemsByName,
  playersByName,
  locationsByName,
  encountersByLieu,
  onClose,
}: Props) {
  const [activeReference, setActiveReference] = useState<ReferenceEntry | null>(null)

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
          <CampaignIcon icon={session.icon} size={28} emojiClassName="text-2xl" />
          <h3 className="text-ink font-bold flex-1 truncate">{session.title}</h3>
          {session.done && <span title="Terminé">✅</span>}
          <button
            onClick={onClose}
            className={`w-8 h-8 shrink-0 rounded-md text-sm font-bold ${BUTTON_STYLE.gray}`}
          >
            ✕
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-4 bg-cream text-ink">
          {chapters.length === 0 ? (
            <p className="text-ink-muted text-sm">Aucun chapitre pour l'instant.</p>
          ) : (
            chapters.map((chapter) => (
              <SessionViewChapterBlock
                key={chapter.id}
                chapter={chapter}
                referenceIndex={referenceIndex}
                onReferenceClick={setActiveReference}
              />
            ))
          )}
        </div>
      </div>

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
