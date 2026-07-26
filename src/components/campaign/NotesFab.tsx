import { useState } from 'react'
import type { JSONContent } from '@tiptap/core'
import type { ReferenceEntry, ReferenceIndex } from '../../hooks/useReferenceIndex'
import { NotesEditor } from './NotesEditor'
import { PANEL_LG } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  notes: JSONContent
  onSave: (notes: JSONContent) => void
  referenceIndex: ReferenceIndex
  onReferenceClick: (entry: ReferenceEntry) => void
}

// Bouton flottant bas-droite pour les notes de MJ : reste au-dessus des popups
// (chapitre/session) au lieu d'être imbriqué dans leur contenu défilant.
export function NotesFab({ notes, onSave, referenceIndex, onReferenceClick }: Props) {
  const [open, setOpen] = useState(false)

  const handleReferenceClick = (entry: ReferenceEntry) => {
    // Referme le panneau de notes pour laisser la place au popup d'info référencé
    setOpen(false)
    onReferenceClick(entry)
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        title="Notes"
        className={`fixed bottom-4 right-4 z-[55] w-12 h-12 rounded-full text-xl flex items-center justify-center ${open ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
      >
        📝
      </button>

      {open && (
        <div className={`fixed bottom-20 right-4 z-[55] w-80 max-w-[calc(100vw-2rem)] max-h-[60vh] flex flex-col overflow-hidden ${PANEL_LG}`}>
          <div className="shrink-0 flex items-center gap-2 p-3 border-b-2 border-[#cfc7a8]">
            <span className="text-lg">📝</span>
            <h4 className="text-ink font-bold flex-1">Notes</h4>
            <button
              onClick={() => setOpen(false)}
              className={`w-7 h-7 shrink-0 rounded-md text-sm font-bold ${BUTTON_STYLE.gray}`}
            >
              ✕
            </button>
          </div>
          <div className="flex-1 overflow-y-auto p-3 bg-cream">
            <NotesEditor
              notes={notes}
              onSave={onSave}
              referenceIndex={referenceIndex}
              onReferenceClick={handleReferenceClick}
            />
          </div>
        </div>
      )}
    </>
  )
}
