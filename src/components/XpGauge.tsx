import { useRef, type ReactNode } from 'react'
import type { CSSProperties } from 'react'
import type { Milestone } from '../lib/xpBonuses'
import { clampXp, ITEM_TOKEN } from '../lib/xpBonuses'
import { NumberInput } from './NumberInput'

interface Props {
  xp: number
  max: number
  milestones: Milestone[]
  onXpChange: (value: number) => void
  /** Icône de l'objet requis pour l'évolution — remplace le token "[objet]" dans les libellés */
  evolutionItemIconUrl?: string | null
  evolutionItemName?: string | null
}

// Version texte brut du libellé pour le title="" (tooltip) : remplace le token par le
// nom de l'objet quand connu, sinon le retire simplement.
function labelTitle(label: string, itemName?: string | null): string {
  const idx = label.toLowerCase().indexOf(ITEM_TOKEN)
  if (idx === -1) return label
  return `${label.slice(0, idx)}${itemName ?? ''}${label.slice(idx + ITEM_TOKEN.length)}`.replace(/\s{2,}/g, ' ').trim()
}

// Rendu du libellé : remplace le token "[objet]" par une icône (ou un emoji de repli
// si l'objet n'est pas trouvé) plutôt que d'afficher le texte brut du token.
function renderLabel(label: string, iconUrl?: string | null): ReactNode {
  const idx = label.toLowerCase().indexOf(ITEM_TOKEN)
  if (idx === -1) return label
  const before = label.slice(0, idx)
  const after = label.slice(idx + ITEM_TOKEN.length)
  return (
    <>
      {before}
      {iconUrl ? (
        <img src={iconUrl} alt="" className="inline-block w-4 h-4 object-contain align-text-bottom mx-0.5" />
      ) : (
        <span className="mx-0.5">🎒</span>
      )}
      {after}
    </>
  )
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

export function XpGauge({ xp, max, milestones, onXpChange, evolutionItemIconUrl, evolutionItemName }: Props) {
  const dragging = useRef(false)
  const pct = max > 0 ? Math.max(0, Math.min(100, (xp / max) * 100)) : 0

  const valueFromPointer = (clientX: number, rect: DOMRect) => {
    const frac = (clientX - rect.left) / rect.width
    return clampXp(Math.round(frac * max), max)
  }

  return (
    <div>
      <div className="relative h-14 mb-1">
        {milestones.map((m) => (
          <div
            key={m.xp}
            className={`absolute bottom-0 z-10 flex flex-col ${ALIGN_CLASS[markerAlign(m.xp, max)]}`}
            style={markerStyle(m.xp, max)}
          >
            <div
              title={labelTitle(m.label, evolutionItemName)}
              className="bg-cream-secondary border border-xp-blue rounded px-1.5 py-0.5 text-ink text-sm font-bold max-w-[7.5rem] text-center line-clamp-2"
            >
              {renderLabel(m.label, evolutionItemIconUrl)}
            </div>
            <div className="w-0 h-0 border-l-[5px] border-l-transparent border-r-[5px] border-r-transparent border-t-[5px] border-t-xp-blue" />
          </div>
        ))}
      </div>

      <div
        className="h-2.5 rounded-full bg-[#cfc7a8] border border-ink overflow-hidden cursor-pointer touch-none select-none"
        title="Cliquer ou glisser pour régler l'XP"
        onPointerDown={(e) => {
          e.currentTarget.setPointerCapture(e.pointerId)
          dragging.current = true
          onXpChange(valueFromPointer(e.clientX, e.currentTarget.getBoundingClientRect()))
        }}
        onPointerMove={(e) => {
          if (!dragging.current) return
          onXpChange(valueFromPointer(e.clientX, e.currentTarget.getBoundingClientRect()))
        }}
        onPointerUp={() => { dragging.current = false }}
        onPointerCancel={() => { dragging.current = false }}
      >
        <div className="h-full rounded-full bg-xp-blue transition-all" style={{ width: `${pct}%` }} />
      </div>

      <div className="relative h-14 mt-0.5">
        <span className="absolute top-0 left-0 text-ink-muted-2 text-xs">XP</span>

        {milestones.map((m) => (
          <span
            key={m.xp}
            className={`absolute top-0 text-sm ${xp >= m.xp ? 'text-ink font-bold' : 'text-ink-muted-2'}`}
            style={markerStyle(m.xp, max)}
          >
            {m.xp}
          </span>
        ))}

        <div className="absolute top-5 z-10 flex flex-col items-center" style={markerStyle(xp, max)}>
          <div className="w-0 h-0 border-l-[5px] border-l-transparent border-r-[5px] border-r-transparent border-b-[5px] border-b-xp-blue" />
          <div className="flex items-center gap-1 bg-cream-secondary border border-xp-blue rounded px-1 py-0.5">
            <button
              onClick={() => onXpChange(clampXp(xp - 1, max))}
              className="text-xp-blue font-bold w-5 h-5 shrink-0 flex items-center justify-center hover:bg-cream-button rounded"
            >
              −
            </button>
            <NumberInput
              value={xp}
              onCommit={(v) => onXpChange(clampXp(v, max))}
              className="w-10 bg-transparent text-xp-blue font-bold text-sm text-center outline-none"
            />
            <button
              onClick={() => onXpChange(clampXp(xp + 1, max))}
              className="text-xp-blue font-bold w-5 h-5 shrink-0 flex items-center justify-center hover:bg-cream-button rounded"
            >
              +
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
