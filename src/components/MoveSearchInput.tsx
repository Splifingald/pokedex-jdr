import { useState, useMemo } from 'react'
import type { Attack } from '../types'
import { TypeBadge } from './TypeBadge'
import { PixelIcon } from './icons/PixelIcon'
import { STAT_ICON, DICE_GENERIC_ICON } from '../lib/icons'
import { normalizeSearch } from '../lib/normalizeSearch'
import { getPrecisionColor } from '../lib/precisionColor'
import { getStatusEffectDisplay } from '../lib/autoBattle'

interface Props {
  options: Attack[]
  disabled: boolean
  onSelect: (attack: Attack) => void
  /** Affiche les dégâts de base à côté de chaque résultat (défaut: masqué) */
  showDamage?: boolean
}

export function MoveSearchInput({ options, disabled, onSelect, showDamage = false }: Props) {
  const [query, setQuery] = useState('')

  const matches = useMemo(() => {
    const q = normalizeSearch(query.trim())
    if (!q) return []
    return options.filter((a) => normalizeSearch(a.nom).includes(q)).slice(0, 8)
  }, [query, options])

  const handleSelect = (a: Attack) => {
    onSelect(a)
    setQuery('')
  }

  if (disabled) {
    return (
      <p className="text-ink-muted-2 text-sm bg-cream-secondary border-2 border-ink rounded-lg px-3 py-2">
        Nombre maximum de capacités atteint.
      </p>
    )
  }

  return (
    <div className="relative">
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Rechercher une capacité…"
        className="w-full bg-cream border-2 border-ink rounded-lg px-3 py-2 text-ink text-sm placeholder-ink-muted-2 outline-none"
      />
      {query && (
        <div className="absolute z-10 top-full left-0 right-0 mt-1 bg-cream border-2 border-ink rounded-lg shadow-[var(--shadow-pixel)] max-h-64 overflow-y-auto">
          {matches.length === 0 ? (
            <p className="text-ink-muted-2 text-sm px-3 py-2">Aucun résultat</p>
          ) : (
            matches.map((a) => (
              <button
                key={a.nom}
                onClick={() => handleSelect(a)}
                className="w-full flex items-center gap-2 px-3 py-2 border-b border-[#cfc7a8] last:border-b-0 hover:bg-cream-secondary transition-colors text-left"
              >
                <TypeBadge type={a.type} small />
                <span className="flex-1 text-ink text-sm truncate">{a.nom}</span>
                {showDamage && (
                  <span className="flex items-center gap-2 shrink-0">
                    <span className="flex items-center gap-1">
                      <PixelIcon src={STAT_ICON.damage} size={14} colored className="text-ink" />
                      <span className="text-ink text-xs font-bold">{a.degats_base ?? 0}</span>
                    </span>
                    {a.degats_de != null && (
                      <span className="flex items-center gap-1">
                        <PixelIcon src={DICE_GENERIC_ICON} size={14} colored className="text-ink" />
                        <span className="text-ink text-xs font-bold">{a.degats_de}</span>
                      </span>
                    )}
                    <span className="flex items-center gap-1">
                      <span className="text-xs">🎯</span>
                      <span className="text-xs font-bold" style={{ color: getPrecisionColor(a.precision ?? 10) }}>{a.precision ?? 10}</span>
                    </span>
                    {a.status_effect && (() => {
                      const statusDisplay = getStatusEffectDisplay(a.status_effect)
                      return (
                        <span
                          className="flex items-center gap-1 text-xs font-bold px-2 py-1 rounded-full text-white whitespace-nowrap"
                          style={{ backgroundColor: statusDisplay.color }}
                        >
                          <PixelIcon src={statusDisplay.iconSrc} size={14} />
                          {statusDisplay.label} {a.status_chance ?? 0}%
                        </span>
                      )
                    })()}
                  </span>
                )}
              </button>
            ))
          )}
        </div>
      )}
    </div>
  )
}
