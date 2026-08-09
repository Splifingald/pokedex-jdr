import { useEffect, useRef, useState } from 'react'
import EmojiPicker, { type EmojiClickData, Theme } from 'emoji-picker-react'

interface Props {
  onSelect: (emoji: string) => void
}

// Bouton emoji du composeur de chat : reste ouvert après une sélection (contrairement
// à EmojiPickerButton du journal de campagne, qui choisit UNE icône puis se ferme) —
// un message peut contenir plusieurs emoji d'affilée.
export function ChatEmojiButton({ onSelect }: Props) {
  const [open, setOpen] = useState(false)
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const handler = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) setOpen(false)
    }
    const escHandler = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false) }
    window.addEventListener('mousedown', handler)
    window.addEventListener('keydown', escHandler)
    return () => {
      window.removeEventListener('mousedown', handler)
      window.removeEventListener('keydown', escHandler)
    }
  }, [open])

  return (
    <div ref={containerRef} className="relative shrink-0">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        title="Emoji"
        className="w-9 h-9 rounded-lg border-2 border-ink bg-white text-lg flex items-center justify-center"
      >
        😀
      </button>
      {open && (
        <div className="absolute z-20 bottom-full right-0 mb-1">
          <EmojiPicker onEmojiClick={(data: EmojiClickData) => onSelect(data.emoji)} theme={Theme.AUTO} />
        </div>
      )}
    </div>
  )
}
