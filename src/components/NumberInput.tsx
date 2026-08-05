import { useState, useEffect } from 'react'

interface Props {
  value: number
  onCommit: (value: number) => void
  fallback?: number
  className?: string
  min?: number
  disabled?: boolean
}

// Champ nombre contrôlé par un état texte local : l'utilisateur peut effacer
// entièrement le champ pendant la saisie, la valeur numérique n'est recalculée
// (et remise à `fallback` si vide/invalide) qu'à la validation (blur ou Entrée).
export function NumberInput({ value, onCommit, fallback = 0, className, min, disabled = false }: Props) {
  const [text, setText] = useState(String(value))

  useEffect(() => {
    setText(String(value))
  }, [value])

  const commit = () => {
    const parsed = parseInt(text, 10)
    onCommit(Number.isNaN(parsed) ? fallback : parsed)
  }

  return (
    <input
      type="number"
      min={min}
      value={text}
      disabled={disabled}
      onChange={(e) => setText(e.target.value)}
      onBlur={commit}
      onKeyDown={(e) => {
        if (e.key === 'Enter') { commit(); (e.target as HTMLInputElement).blur() }
      }}
      className={`[appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none disabled:opacity-50 disabled:cursor-not-allowed ${className ?? ''}`}
    />
  )
}
