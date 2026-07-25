import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  done: boolean
  onToggle: () => void
}

export function DoneToggle({ done, onToggle }: Props) {
  return (
    <button
      type="button"
      onClick={onToggle}
      className={`shrink-0 text-xs rounded px-2 py-1.5 font-bold flex items-center gap-1 ${done ? BUTTON_STYLE.green : BUTTON_STYLE.gray}`}
    >
      {done ? '✅ Terminé' : '☐ À faire'}
    </button>
  )
}
