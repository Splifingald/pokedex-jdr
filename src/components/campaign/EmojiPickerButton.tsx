import { useEffect, useState, type ReactNode } from 'react'
import EmojiPicker, { type EmojiClickData, Theme } from 'emoji-picker-react'

interface Props {
  onSelect: (emoji: string) => void
  trigger: ReactNode
  triggerClassName?: string
  title?: string
}

export function EmojiPickerButton({ onSelect, trigger, triggerClassName, title }: Props) {
  const [open, setOpen] = useState(false)

  useEffect(() => {
    if (!open) return
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false) }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [open])

  const handlePick = (data: EmojiClickData) => {
    onSelect(data.emoji)
    setOpen(false)
  }

  return (
    <>
      <button type="button" title={title} onClick={() => setOpen(true)} className={triggerClassName}>
        {trigger}
      </button>
      {open && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
          onClick={(e) => { if (e.target === e.currentTarget) setOpen(false) }}
        >
          <EmojiPicker onEmojiClick={handlePick} theme={Theme.AUTO} />
        </div>
      )}
    </>
  )
}
