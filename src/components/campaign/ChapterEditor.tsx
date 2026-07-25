import { useEffect, useRef, useState } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Underline from '@tiptap/extension-underline'
import { TextStyle } from '@tiptap/extension-text-style'
import Color from '@tiptap/extension-color'
import type { CampaignChapter, Player, CarteLocation, Attack, Item, Pokemon } from '../../types'
import { EMPTY_CHAPTER_CONTENT } from '../../types'
import type { ReferenceEntry, ReferenceIndex } from '../../hooks/useReferenceIndex'
import { ReferenceHighlight, forceReferenceRecompute } from '../../lib/referenceExtension'
import { EditorToolbar } from './EditorToolbar'
import { EmojiPickerButton } from './EmojiPickerButton'
import { PlayerReferencePopup } from './PlayerReferencePopup'
import { LocationReferencePopup } from './LocationReferencePopup'
import { AbilityReferencePopup } from './AbilityReferencePopup'
import { ItemReferencePopup } from './ItemReferencePopup'
import { PokemonDetailSheet } from '../PokemonDetailSheet'
import { ImageLightbox } from '../ImageLightbox'
import { ConfirmPopup } from '../ConfirmPopup'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'

interface Props {
  chapter: CampaignChapter
  referenceIndex: ReferenceIndex
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  playersByName: Map<string, Player>
  locationsByName: Map<string, CarteLocation>
  onUpdate: (id: number, data: { title?: string; icon?: string; image_url?: string | null; content?: CampaignChapter['content'] }) => void
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
  onUpdate,
  onDelete,
  onBack,
}: Props) {
  const [title, setTitle] = useState(chapter.title)
  const [icon, setIcon] = useState(chapter.icon)
  const [imageUrl, setImageUrl] = useState(chapter.image_url ?? '')
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
    onUpdate(chapter.id, { title, icon, image_url: imageUrl.trim() || null, content: editor?.getJSON() })
    setDirty(false)
  }

  const handleBack = () => {
    if (dirty) {
      setConfirmBack(true)
      return
    }
    onBack()
  }

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <div className="shrink-0 p-4 border-b-2 border-[#cfc7a8]">
        <div className="flex items-center gap-2 mb-3">
          <button onClick={handleBack} className={`text-sm rounded px-3 py-1.5 ${BUTTON_STYLE.gray}`}>
            ← Retour
          </button>
          <span className="flex-1" />
          {dirty && <span className="text-xs text-[#a3841a] font-bold">● Non enregistré</span>}
          <button onClick={handleSave} className={`text-sm rounded px-3 py-1.5 font-bold ${BUTTON_STYLE.green}`}>
            💾 Enregistrer
          </button>
          <button onClick={() => setConfirmDelete(true)} className={`text-sm rounded px-3 py-1.5 ${BUTTON_STYLE.red}`}>
            🗑
          </button>
        </div>

        {imageUrl && (
          <button
            onClick={() => setViewerOpen(true)}
            className="block w-full h-24 rounded-lg overflow-hidden mb-3 border-2 border-ink"
          >
            <img src={imageUrl} alt={title} className="w-full h-full object-cover" />
          </button>
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
        <ConfirmPopup
          title="Quitter sans enregistrer ?"
          message="Les modifications non enregistrées seront perdues."
          confirmLabel="Quitter"
          danger
          onConfirm={() => { setConfirmBack(false); onBack() }}
          onCancel={() => setConfirmBack(false)}
        />
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

      {activeReference?.type === 'pokemon' && (
        <PokemonDetailSheet
          context="pokedex"
          pokemon={pokemonByName.get(activeReference.name)}
          attacksByName={attacksByName}
          isAdmin={true}
          isDiscovered={true}
          onClose={() => setActiveReference(null)}
        />
      )}
      {activeReference?.type === 'player' && playersByName.get(activeReference.name) && (
        <PlayerReferencePopup
          player={playersByName.get(activeReference.name)!}
          pokemonByName={pokemonByName}
          attacksByName={attacksByName}
          itemsByName={itemsByName}
          onClose={() => setActiveReference(null)}
        />
      )}
      {activeReference?.type === 'location' && locationsByName.get(activeReference.name) && (
        <LocationReferencePopup
          location={locationsByName.get(activeReference.name)!}
          onClose={() => setActiveReference(null)}
        />
      )}
      {activeReference?.type === 'ability' && attacksByName.get(activeReference.name) && (
        <AbilityReferencePopup
          attack={attacksByName.get(activeReference.name)!}
          onClose={() => setActiveReference(null)}
        />
      )}
      {activeReference?.type === 'item' && itemsByName.get(activeReference.name) && (
        <ItemReferencePopup
          item={itemsByName.get(activeReference.name)!}
          onClose={() => setActiveReference(null)}
        />
      )}
    </div>
  )
}
