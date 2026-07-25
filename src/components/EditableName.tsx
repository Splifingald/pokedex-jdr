import { useState, useRef, useEffect } from 'react'

interface Props {
  value: string
  onCommit: (value: string) => void
  className?: string
}

// Nom cliquable qui se transforme en champ texte pour édition (surnom d'un pokémon possédé).
// Commit au blur/Entrée ; Échap annule. Une valeur vide restaure le nom d'espèce (géré par l'appelant).
export function EditableName({ value, onCommit, className }: Props) {
  const [editing, setEditing] = useState(false)
  const [text, setText] = useState(value)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    setText(value)
  }, [value])

  useEffect(() => {
    if (editing) {
      inputRef.current?.focus()
      inputRef.current?.select()
    }
  }, [editing])

  const commit = () => {
    setEditing(false)
    const trimmed = text.trim()
    if (trimmed !== value) onCommit(trimmed)
  }

  if (editing) {
    return (
      <input
        ref={inputRef}
        type="text"
        value={text}
        onChange={(e) => setText(e.target.value)}
        onBlur={commit}
        onKeyDown={(e) => {
          if (e.key === 'Enter') (e.target as HTMLInputElement).blur()
          if (e.key === 'Escape') { setText(value); setEditing(false) }
        }}
        className={`bg-white border-2 border-ink rounded px-1.5 outline-none ${className ?? ''}`}
      />
    )
  }

  return (
    <button
      onClick={() => setEditing(true)}
      title="Renommer"
      className={`group flex items-center gap-1.5 min-w-0 text-left ${className ?? ''}`}
    >
      <span className="truncate">{value}</span>
      <span className="text-[0.7em] opacity-40 group-hover:opacity-90 shrink-0">✏️</span>
    </button>
  )
}
