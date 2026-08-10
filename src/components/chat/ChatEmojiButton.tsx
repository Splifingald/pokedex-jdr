import { useEffect, useState } from 'react'
import EmojiPicker, { type EmojiClickData, Theme } from 'emoji-picker-react'

interface Props {
  onSelect: (emoji: string) => void
}

// Bouton emoji du composeur de chat : reste ouvert après une sélection (contrairement
// à EmojiPickerButton du journal de campagne, qui choisit UNE icône puis se ferme) —
// un message peut contenir plusieurs emoji d'affilée. Rendu en overlay plein écran
// centré (comme EmojiPickerButton) plutôt qu'ancré au bouton : un dropdown ancré
// débordait de l'écran sur mobile, où le bouton est proche du bord droit du popup.
export function ChatEmojiButton({ onSelect }: Props) {
  const [open, setOpen] = useState(false)

  useEffect(() => {
    if (!open) return
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false) }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [open])

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        title="Emoji"
        className="w-9 h-9 rounded-lg border-2 border-ink bg-white text-lg flex items-center justify-center shrink-0"
      >
        😀
      </button>
      {open && (
        <div
          className="fixed inset-0 z-[60] flex items-center justify-center bg-black/70 p-4"
          onClick={(e) => { if (e.target === e.currentTarget) setOpen(false) }}
        >
          <EmojiPicker onEmojiClick={(data: EmojiClickData) => onSelect(data.emoji)} theme={Theme.AUTO} />
        </div>
      )}
    </>
  )
}
