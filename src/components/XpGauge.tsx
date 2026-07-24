import type { CSSProperties } from 'react'
import type { Milestone } from '../lib/xpBonuses'
import { clampXp } from '../lib/xpBonuses'
import { NumberInput } from './NumberInput'

interface Props {
  xp: number
  max: number
  milestones: Milestone[]
  onXpChange: (value: number) => void
}

function markerStyle(value: number, max: number): CSSProperties {
  const pct = max > 0 ? (value / max) * 100 : 0
  if (pct <= 12) return { left: 0 }
  if (pct >= 88) return { right: 0 }
  return { left: `${pct}%`, transform: 'translateX(-50%)' }
}

const ALIGN_CLASS = { start: 'items-start', center: 'items-center', end: 'items-end' } as const

function markerAlign(value: number, max: number): keyof typeof ALIGN_CLASS {
  const pct = max > 0 ? (value / max) * 100 : 0
  if (pct <= 12) return 'start'
  if (pct >= 88) return 'end'
  return 'center'
}

export function XpGauge({ xp, max, milestones, onXpChange }: Props) {
  const pct = max > 0 ? Math.max(0, Math.min(100, (xp / max) * 100)) : 0

  return (
    <div>
      <div className="relative h-10 mb-1">
        {milestones.map((m) => (
          <div
            key={m.xp}
            className={`absolute bottom-0 z-10 flex flex-col ${ALIGN_CLASS[markerAlign(m.xp, max)]}`}
            style={markerStyle(m.xp, max)}
          >
            <div
              title={m.label}
              className="bg-gray-800 border border-blue-400 rounded px-1.5 py-0.5 text-white text-sm font-bold whitespace-nowrap max-w-[5.5rem] truncate"
            >
              {m.label}
            </div>
            <div className="w-0 h-0 border-l-[5px] border-l-transparent border-r-[5px] border-r-transparent border-t-[5px] border-t-blue-400" />
          </div>
        ))}
      </div>

      <div className="h-2 rounded-full bg-gray-700 overflow-hidden">
        <div className="h-full rounded-full bg-blue-500 transition-all" style={{ width: `${pct}%` }} />
      </div>

      <div className="relative h-11 mt-0.5">
        <span className="absolute top-0 left-0 text-gray-400 text-xs">XP</span>

        {milestones.map((m) => (
          <span
            key={m.xp}
            className={`absolute text-sm ${xp >= m.xp ? 'text-white font-bold' : 'text-white/60'}`}
            style={markerStyle(m.xp, max)}
          >
            {m.xp}
          </span>
        ))}

        <div className="absolute top-0 z-10 flex flex-col items-center" style={markerStyle(xp, max)}>
          <div className="w-0 h-0 border-l-[5px] border-l-transparent border-r-[5px] border-r-transparent border-b-[5px] border-b-blue-400" />
          <div className="flex items-center gap-1 bg-gray-800 border border-blue-400 rounded px-1 py-0.5">
            <button
              onClick={() => onXpChange(clampXp(xp - 1, max))}
              className="text-blue-400 font-bold w-5 h-5 shrink-0 flex items-center justify-center hover:bg-gray-700 rounded"
            >
              −
            </button>
            <NumberInput
              value={xp}
              onCommit={(v) => onXpChange(clampXp(v, max))}
              className="w-10 bg-transparent text-blue-400 font-bold text-sm text-center outline-none"
            />
            <button
              onClick={() => onXpChange(clampXp(xp + 1, max))}
              className="text-blue-400 font-bold w-5 h-5 shrink-0 flex items-center justify-center hover:bg-gray-700 rounded"
            >
              +
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
