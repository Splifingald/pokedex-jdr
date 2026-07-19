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
        <span className="text-red-500 font-bold text-lg tracking-wide">K.O.</span>
      </div>
    )
  }

  const color = pct < 20 ? 'bg-red-500' : pct < 50 ? 'bg-orange-400' : 'bg-green-500'
  const textColor = pct < 20 ? 'text-red-500' : pct < 50 ? 'text-orange-400' : 'text-green-500'

  return (
    <div>
      <div className={`text-xs font-bold text-right mb-0.5 ${textColor}`}>{current} / {max}</div>
      <div className="h-2 rounded-full bg-gray-700 overflow-hidden">
        <div className={`h-full rounded-full transition-all ${color}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  )
}
