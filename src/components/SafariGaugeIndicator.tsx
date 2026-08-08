import type { SafariGaugeArea } from '../types'

interface Props {
  areas: SafariGaugeArea[]
  position: number
  /** Pokémon sélectionné : affiche les % dans les zones et les seuils en dessous. Sinon, juste la barre colorée + la flèche. */
  showLabels: boolean
}

// Jauge de capture 0-100 : forme "pilule" (extrémités totalement arrondies),
// zones colorées, et une flèche indiquant la position courante (qui chevauche
// légèrement le haut de la barre) — tout est piloté par la config admin
// (safari_gauge_areas), jamais codé en dur. Les % par zone et les seuils
// numériques ne sont affichés que pour le pokémon sélectionné (§ non-sélectionné
// : juste la barre + la flèche, en plus petit).
export function SafariGaugeIndicator({ areas, position, showLabels }: Props) {
  const sorted = [...areas].sort((a, b) => a.min_value - b.min_value)
  if (sorted.length === 0) return null

  const clamped = Math.min(100, Math.max(0, position))

  return (
    <div className="w-full">
      <div className="relative">
        <div className="relative h-4">
          <div
            className={`absolute -translate-x-1/2 leading-none transition-[left] duration-700 ease-out ${showLabels ? 'text-xl' : 'text-sm'}`}
            style={{ left: `${clamped}%`, bottom: showLabels ? -8 : -4, filter: 'drop-shadow(0 1px 0 white) drop-shadow(0 -1px 0 white) drop-shadow(1px 0 0 white) drop-shadow(-1px 0 0 white)' }}
          >
            ▼
          </div>
        </div>
        <div className={`relative w-full ${showLabels ? 'h-8' : 'h-4'} rounded-full overflow-hidden border-ink flex bg-white ${showLabels ? 'border-[3px]' : 'border-2'}`}>
          {sorted.map((area) => (
            <div
              key={area.id}
              style={{ width: `${area.max_value - area.min_value}%`, backgroundColor: area.color }}
              className="flex items-center justify-center text-sm font-black text-white"
            >
              {showLabels && (
                <span style={{ textShadow: '0 0 3px rgba(0,0,0,0.8), 0 1px 1px rgba(0,0,0,0.8)' }}>{area.catch_rate_pct}%</span>
              )}
            </div>
          ))}
        </div>
      </div>
      {showLabels && (
        <div className="relative w-full h-5 mt-1">
          {sorted.map((area) => (
            <span
              key={area.id}
              className="absolute -translate-x-1/2 text-sm font-bold text-ink-muted-2"
              style={{ left: `${area.min_value}%` }}
            >
              {area.min_value}
            </span>
          ))}
          <span className="absolute -translate-x-1/2 text-sm font-bold text-ink-muted-2" style={{ left: '100%' }}>100</span>
        </div>
      )}
    </div>
  )
}
