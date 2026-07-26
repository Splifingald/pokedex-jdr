import { useEffect, useRef, useState } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import type { JSONContent } from '@tiptap/core'
import type { ReferenceEntry, ReferenceIndex } from '../../hooks/useReferenceIndex'
import { ReferenceHighlight, forceReferenceRecompute } from '../../lib/referenceExtension'

interface Props {
  notes: JSONContent
  onSave: (notes: JSONContent) => void
  referenceIndex: ReferenceIndex
  onReferenceClick: (entry: ReferenceEntry) => void
}

const AUTOSAVE_DELAY_MS = 10000

// Éditeur de notes de MJ : texte brut uniquement (pas de titres/couleurs/emoji),
// mais garde le référencement (@Pokémon/attaque/objet/lieu/joueur). Sauvegarde
// automatique 10s après la dernière frappe, ou immédiatement via Ctrl+S.
export function NotesEditor({ notes, onSave, referenceIndex, onReferenceClick }: Props) {
  const [status, setStatus] = useState<'idle' | 'pending' | 'saved'>('idle')
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const savedBadgeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const indexRef = useRef(referenceIndex)
  useEffect(() => { indexRef.current = referenceIndex }, [referenceIndex])

  const editor = useEditor({
    content: notes,
    extensions: [
      StarterKit.configure({
        heading: false,
        bold: false,
        italic: false,
        strike: false,
        code: false,
        codeBlock: false,
        blockquote: false,
        bulletList: false,
        orderedList: false,
        horizontalRule: false,
      }),
      ReferenceHighlight.configure({
        getIndex: () => indexRef.current,
        onReferenceClick,
      }),
    ],
    onUpdate: () => {
      setStatus('pending')
      if (timerRef.current) clearTimeout(timerRef.current)
      timerRef.current = setTimeout(() => saveRef.current(), AUTOSAVE_DELAY_MS)
    },
  })

  useEffect(() => {
    if (editor) forceReferenceRecompute(editor)
  }, [editor, referenceIndex])

  const save = () => {
    if (!editor) return
    if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null }
    onSave(editor.getJSON())
    setStatus('saved')
    if (savedBadgeTimerRef.current) clearTimeout(savedBadgeTimerRef.current)
    savedBadgeTimerRef.current = setTimeout(() => setStatus('idle'), 2000)
  }

  const saveRef = useRef(save)
  useEffect(() => { saveRef.current = save })

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
        e.preventDefault()
        saveRef.current()
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [])

  useEffect(() => {
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current)
      if (savedBadgeTimerRef.current) clearTimeout(savedBadgeTimerRef.current)
    }
  }, [])

  return (
    <div>
      {(status === 'pending' || status === 'saved') && (
        <div className="flex justify-end mb-1">
          {status === 'pending' && <span className="text-xs text-[#ffd75e] font-bold">Enregistrement…</span>}
          {status === 'saved' && <span className="text-xs text-[#4caf6b] font-bold">Enregistré ✓</span>}
        </div>
      )}
      <div className="rounded-lg border-2 border-ink bg-cream p-2 text-ink text-sm min-h-[4rem]">
        <EditorContent editor={editor} />
      </div>
    </div>
  )
}
