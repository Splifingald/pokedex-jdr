import type { Milestone } from '../lib/xpBonuses'

interface Props {
  current: number
  max: number
  milestones: Milestone[]
}

export function XpGauge({ current, max, milestones }: Props) {
  const pct = max > 0 ? Math.max(0, Math.min(100, (current / max) * 100)) : 0

  return (
    <div className="px-2">
      <div className="text-xs font-bold text-right mb-1 text-blue-400">{current} / {max} XP</div>

      <div className="relative h-3.5">
        {milestones.map((m, i) => (
          <span
            key={m.xp}
            title={m.label}
            className={`absolute -translate-x-1/2 whitespace-nowrap text-[9px] font-bold leading-none max-w-[4rem] truncate ${
              current >= m.xp ? 'text-blue-300' : 'text-gray-500'
            } ${i % 2 === 1 ? '-top-1' : 'top-0'}`}
            style={{ left: `${(m.xp / max) * 100}%` }}
          >
            {m.label}
          </span>
        ))}
      </div>

      <div className="h-2 rounded-full bg-gray-700 overflow-hidden">
        <div className="h-full rounded-full bg-blue-500 transition-all" style={{ width: `${pct}%` }} />
      </div>

      <div className="relative h-3 mt-0.5">
        {milestones.map((m) => (
          <span
            key={m.xp}
            className={`absolute -translate-x-1/2 text-[9px] leading-none ${
              current >= m.xp ? 'text-blue-300 font-bold' : 'text-gray-500'
            }`}
            style={{ left: `${(m.xp / max) * 100}%` }}
          >
            {m.xp}
          </span>
        ))}
      </div>
    </div>
  )
}
