interface Props {
  current: number
  max: number
}

export function HpGauge({ current, max }: Props) {
  const pct = max > 0 ? Math.max(0, Math.min(100, (current / max) * 100)) : 0
  const isKo = current <= 0

  if (isKo) {
    return (
      <div className="text-center">
        <span className="text-hp-red font-bold text-lg tracking-wide">K.O.</span>
      </div>
    )
  }

  const color = pct < 20 ? 'bg-hp-red' : pct < 50 ? 'bg-hp-orange' : 'bg-hp-green'
  const textColor = pct < 20 ? 'text-hp-red' : pct < 50 ? 'text-hp-orange' : 'text-hp-green'

  return (
    <div>
      <div className={`text-xs font-bold text-right mb-0.5 ${textColor}`}>{current} / {max}</div>
      <div className="h-2.5 rounded-full bg-[#cfc7a8] border border-ink overflow-hidden">
        <div className={`h-full rounded-full transition-all ${color}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  )
}
