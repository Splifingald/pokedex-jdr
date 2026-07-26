import { useRef } from 'react'

interface Props {
  current: number
  max: number
  /** Si fourni, la barre devient cliquable/glissable : cliquer ou glisser à x% règle les PV à x% du max */
  onChange?: (value: number) => void
  /** Affiche le texte "current / max" au-dessus de la barre (défaut: true) */
  showValue?: boolean
  /** Classes de bordure de la barre (défaut: fin liseré ink) — pour un contour plus marqué sur fond chargé */
  barBorderClassName?: string
}

export function HpGauge({ current, max, onChange, showValue = true, barBorderClassName = 'border border-ink' }: Props) {
  // Ref plutôt que state : évite un re-render (donc un ré-attachement de listener)
  // entre le pointerdown et le premier pointermove du drag.
  const dragging = useRef(false)
  const pct = max > 0 ? Math.max(0, Math.min(100, (current / max) * 100)) : 0
  const isKo = current <= 0

  const valueFromPointer = (clientX: number, rect: DOMRect) => {
    const frac = (clientX - rect.left) / rect.width
    return Math.max(0, Math.min(max, Math.round(frac * max)))
  }

  const handlePointerDown = onChange
    ? (e: React.PointerEvent<HTMLDivElement>) => {
        e.currentTarget.setPointerCapture(e.pointerId)
        dragging.current = true
        onChange(valueFromPointer(e.clientX, e.currentTarget.getBoundingClientRect()))
      }
    : undefined

  const handlePointerMove = onChange
    ? (e: React.PointerEvent<HTMLDivElement>) => {
        if (!dragging.current) return
        onChange(valueFromPointer(e.clientX, e.currentTarget.getBoundingClientRect()))
      }
    : undefined

  const stopDragging = onChange ? () => { dragging.current = false } : undefined

  const color = pct < 20 ? 'bg-hp-red' : pct < 50 ? 'bg-hp-orange' : 'bg-hp-green'
  const textColor = pct < 20 ? 'text-hp-red' : pct < 50 ? 'text-hp-orange' : 'text-hp-green'

  const bar = (
    <div
      className={`h-2.5 rounded-full bg-[#cfc7a8] ${barBorderClassName} overflow-hidden ${onChange ? 'cursor-pointer touch-none select-none' : ''}`}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={stopDragging}
      onPointerCancel={stopDragging}
      title={onChange ? 'Cliquer ou glisser pour régler les PV' : undefined}
    >
      <div className={`h-full rounded-full transition-all ${color}`} style={{ width: `${pct}%` }} />
    </div>
  )

  if (isKo) {
    return (
      <div>
        <div className="text-center">
          <span className="text-hp-red font-bold text-lg tracking-wide">K.O.</span>
        </div>
        {/* Barre vide conservée quand elle est éditable, pour pouvoir re-soigner au clic */}
        {onChange && bar}
      </div>
    )
  }

  return (
    <div>
      {showValue && (
        <div className={`text-xs font-bold text-right mb-0.5 ${textColor}`}>{current} / {max}</div>
      )}
      {bar}
    </div>
  )
}
