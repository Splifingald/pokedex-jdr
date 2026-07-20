import type { Milestone } from '../lib/xpBonuses'

interface Props {
  xp: number
  milestones: Milestone[]
}

export function XpMiniGauge({ xp, milestones }: Props) {
  const passed = milestones.filter((m) => xp >= m.xp)
  const next = milestones.find((m) => xp < m.xp)
  const segStart = passed.length > 0 ? passed[passed.length - 1].xp : 0
  const segEnd = next ? next.xp : segStart
  const pct = next ? Math.max(0, Math.min(100, ((xp - segStart) / (segEnd - segStart)) * 100)) : 100

  return (
    <div>
      <div className="flex items-center justify-between mb-0.5">
        <span className="text-[10px] text-gray-500">{segStart} XP</span>
        <span className="text-[10px] text-blue-400 font-bold">{next ? next.label : 'MAX'}</span>
      </div>
      <div className="h-1.5 rounded-full bg-gray-700 overflow-hidden">
        <div className="h-full rounded-full bg-blue-500 transition-all" style={{ width: `${pct}%` }} />
      </div>
    </div>
  )
}
