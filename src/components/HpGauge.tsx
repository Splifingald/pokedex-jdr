interface Props {
  current: number
  max: number
  /** Si fourni, la barre devient cliquable : cliquer à x% règle les PV à x% du max */
  onChange?: (value: number) => void
}

export function HpGauge({ current, max, onChange }: Props) {
  const pct = max > 0 ? Math.max(0, Math.min(100, (current / max) * 100)) : 0
  const isKo = current <= 0

  const handleClick = onChange
    ? (e: React.MouseEvent<HTMLDivElement>) => {
        const rect = e.currentTarget.getBoundingClientRect()
        const frac = (e.clientX - rect.left) / rect.width
        onChange(Math.max(0, Math.min(max, Math.round(frac * max))))
      }
    : undefined

  const color = pct < 20 ? 'bg-hp-red' : pct < 50 ? 'bg-hp-orange' : 'bg-hp-green'
  const textColor = pct < 20 ? 'text-hp-red' : pct < 50 ? 'text-hp-orange' : 'text-hp-green'

  const bar = (
    <div
      className={`h-2.5 rounded-full bg-[#cfc7a8] border border-ink overflow-hidden ${onChange ? 'cursor-pointer' : ''}`}
      onClick={handleClick}
      title={onChange ? 'Cliquer pour régler les PV' : undefined}
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
      <div className={`text-xs font-bold text-right mb-0.5 ${textColor}`}>{current} / {max}</div>
      {bar}
    </div>
  )
}
