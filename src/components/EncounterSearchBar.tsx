import { useMemo, useState } from 'react'
import type { Pokemon } from '../types'
import { normalizeSearch } from '../lib/normalizeSearch'
import { CloseIcon } from './icons/CloseIcon'
import { PixelIcon } from './icons/PixelIcon'
import { STAT_ICON } from '../lib/icons'

export interface EncounterFilter {
  type: 'lieu' | 'pokemon'
  value: string
}

interface Suggestion {
  type: 'lieu' | 'pokemon'
  value: string
}

interface Props {
  lieux: string[]
  pokemonNames: string[]
  pokemonByName: Map<string, Pokemon>
  onFilterChange: (filter: EncounterFilter | null) => void
}

export function EncounterSearchBar({ lieux, pokemonNames, pokemonByName, onFilterChange }: Props) {
  const [query, setQuery] = useState('')
  const [active, setActive] = useState(false)

  const suggestions = useMemo<Suggestion[]>(() => {
    const q = normalizeSearch(query.trim())
    if (!q || active) return []
    const lieuMatches = lieux
      .filter((l) => normalizeSearch(l).includes(q))
      .slice(0, 5)
      .map((value): Suggestion => ({ type: 'lieu', value }))
    const pokemonMatches = pokemonNames
      .filter((n) => normalizeSearch(n).includes(q))
      .slice(0, 5)
      .map((value): Suggestion => ({ type: 'pokemon', value }))
    return [...lieuMatches, ...pokemonMatches]
  }, [query, lieux, pokemonNames, active])

  const handleSelect = (s: Suggestion) => {
    setQuery(s.value)
    setActive(true)
    onFilterChange(s)
  }

  const handleChange = (value: string) => {
    setQuery(value)
    setActive(false)
    if (value.trim() === '') onFilterChange(null)
  }

  const handleClear = () => {
    setQuery('')
    setActive(false)
    onFilterChange(null)
  }

  return (
    <div className="relative mb-4">
      <div className="relative">
        <input
          type="text"
          value={query}
          onChange={(e) => handleChange(e.target.value)}
          placeholder="Rechercher un lieu ou un pokémon…"
          className="w-full bg-cream border-2 border-ink rounded-lg px-3 py-2 pr-9 text-ink text-sm placeholder-ink-muted-2 outline-none"
        />
        {query && (
          <button
            onClick={handleClear}
            className="absolute right-2 top-1/2 -translate-y-1/2 text-ink-muted-2 text-sm w-6 h-6 flex items-center justify-center"
          >
            <CloseIcon className="w-3.5 h-3.5" />
          </button>
        )}
      </div>

      {suggestions.length > 0 && (
        <div className="absolute z-10 top-full left-0 right-0 mt-1 bg-cream border-2 border-ink rounded-lg shadow-[var(--shadow-pixel)] max-h-64 overflow-y-auto">
          {suggestions.map((s) => {
            const pokemon = s.type === 'pokemon' ? pokemonByName.get(s.value) : undefined
            return (
              <button
                key={`${s.type}-${s.value}`}
                onClick={() => handleSelect(s)}
                className="w-full flex items-center gap-2 px-3 py-2 border-b border-[#cfc7a8] last:border-b-0 hover:bg-cream-secondary transition-colors text-left"
              >
                {pokemon?.image_miniature ? (
                  <img src={pokemon.image_miniature} alt={s.value} className="pixelated w-6 h-6 object-contain shrink-0" />
                ) : s.type === 'lieu' ? (
                  <span className="text-ink shrink-0"><PixelIcon src={STAT_ICON.location} size={14} colored /></span>
                ) : (
                  <span className="text-xs shrink-0">🐾</span>
                )}
                <span className="text-ink text-sm truncate">{s.value}</span>
              </button>
            )
          })}
        </div>
      )}
    </div>
  )
}
