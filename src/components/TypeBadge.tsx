import { TYPE_COLORS } from '../lib/typeColors'

interface TypeBadgeProps {
  type: string
  small?: boolean
  label?: string
}

export function TypeBadge({ type, small = false, label }: TypeBadgeProps) {
  const bg = TYPE_COLORS[type] ?? '#888888'
  return (
    <span
      className={`inline-block rounded font-bold uppercase tracking-wide text-white ${small ? 'px-1.5 py-0.5 text-xs' : 'px-3 py-1 text-sm'}`}
      style={{ backgroundColor: bg, textShadow: '0 1px 2px rgba(0,0,0,0.4)' }}
    >
      {label ?? type}
    </span>
  )
}
