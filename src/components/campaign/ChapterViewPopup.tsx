import { useEffect, useRef, useState } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Underline from '@tiptap/extension-underline'
import { TextStyle } from '@tiptap/extension-text-style'
import Color from '@tiptap/extension-color'
import type { CampaignChapter, Player, CarteLocation, Attack, Item, Pokemon, Encounter, DisplayAsset, DisplayState } from '../../types'
import { EMPTY_CHAPTER_CONTENT } from '../../types'
import type { ReferenceEntry, ReferenceIndex } from '../../hooks/useReferenceIndex'
import { ReferenceHighlight, forceReferenceRecompute } from '../../lib/referenceExtension'
import { DisplayCommandHighlight, forceDisplayCommandRecompute } from '../../lib/displayCommandExtension'
import { executeDisplayCommand, type DisplayCommand } from '../../lib/displayCommand'
import type { UpdateDisplayState } from '../../lib/displayActions'
import { useToast } from '../../context/ToastContext'
import { ReferenceDispatcher } from './ReferenceDispatcher'
import { SetBannerBackgroundButton } from './SetBannerBackgroundButton'
import { DoneToggle } from './DoneToggle'
import { NotesFab } from './NotesFab'
import { PANEL_LG } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { CampaignIcon } from './CampaignIcon'

interface Props {
  chapter: CampaignChapter
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
  displayState,
  displayAssets,
  updateDisplayState,
  onToggleDone,
  onSaveNotes,
  onClose,
}: Props) {
  const [activeReference, setActiveReference] = useState<ReferenceEntry | null>(null)
  const { showToast } = useToast()

  const indexRef = useRef(referenceIndex)
  useEffect(() => { indexRef.current = referenceIndex }, [referenceIndex])

  const displayStateRef = useRef(displayState)
  useEffect(() => { displayStateRef.current = displayState }, [displayState])
  const displayAssetsRef = useRef(displayAssets)
  useEffect(() => { displayAssetsRef.current = displayAssets }, [displayAssets])

  const handleDisplayCommand = (cmd: DisplayCommand) => {
    executeDisplayCommand(cmd, {
      referenceIndex: indexRef.current,
      displayState: displayStateRef.current,
      displayAssets: displayAssetsRef.current,
      updateDisplayState,
      showToast,
    })
  }

  const editor = useEditor({
    content: chapter.content ?? EMPTY_CHAPTER_CONTENT,
    editable: false,
    extensions: [
      StarterKit,
      Underline,
      TextStyle,
      Color,
      // getIndex/getDisplayAssets are only invoked lazily by the plugin (on doc change/click),
      // never read synchronously during this render
      // eslint-disable-next-line react-hooks/refs
      ReferenceHighlight.configure({
        getIndex: () => indexRef.current,
        getDisplayAssets: () => displayAssetsRef.current,
        onReferenceClick: (entry) => setActiveReference(entry),
      }),
      // eslint-disable-next-line react-hooks/refs -- same lazy-getter pattern as above
      DisplayCommandHighlight.configure({
        getIndex: () => indexRef.current,
        getDisplayAssets: () => displayAssetsRef.current,
        onCommand: handleDisplayCommand,
      }),
    ],
  })

  useEffect(() => {
    if (editor) forceReferenceRecompute(editor)
    if (editor) forceDisplayCommandRecompute(editor)
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
          <CampaignIcon icon={chapter.icon} size={28} emojiClassName="text-2xl" />
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
            <div className="relative w-full h-32 rounded-lg mb-4 border-2 border-ink overflow-hidden">
              <img
                src={chapter.image_url}
                alt={chapter.title}
                className="w-full h-full object-cover"
                style={{ objectPosition: `50% ${chapter.image_position ?? 50}%` }}
              />
              <SetBannerBackgroundButton imageUrl={chapter.image_url} updateDisplayState={updateDisplayState} />
            </div>
          )}
          <EditorContent editor={editor} />
        </div>
      </div>

      <NotesFab
        notes={chapter.notes ?? EMPTY_CHAPTER_CONTENT}
        onSave={onSaveNotes}
        referenceIndex={referenceIndex}
        onReferenceClick={(entry) => setActiveReference(entry)}
        displayState={displayState}
        displayAssets={displayAssets}
        updateDisplayState={updateDisplayState}
      />

      <ReferenceDispatcher
        activeReference={activeReference}
        pokemonByName={pokemonByName}
        attacksByName={attacksByName}
        itemsByName={itemsByName}
        playersByName={playersByName}
        locationsByName={locationsByName}
        encountersByLieu={encountersByLieu}
        displayState={displayState}
        displayAssets={displayAssets}
        updateDisplayState={updateDisplayState}
        onClose={() => setActiveReference(null)}
      />
    </div>
  )
}
