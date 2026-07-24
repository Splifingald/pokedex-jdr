import { useState, useMemo } from 'react'
import type { Pokemon } from '../types'
import { normalizeSearch } from '../lib/normalizeSearch'

interface Props {
  options: Pokemon[]
  onSelect: (pokemon: Pokemon) => void
  placeholder?: string
}

export function PokemonSearchInput({ options, onSelect, placeholder = 'Rechercher un pokémon…' }: Props) {
  const [query, setQuery] = useState('')

  const matches = useMemo(() => {
    const q = normalizeSearch(query.trim())
    if (!q) return []
    return options.filter((p) => normalizeSearch(p.nom).includes(q) || p.numero.includes(q)).slice(0, 8)
  }, [query, options])

  const handleSelect = (p: Pokemon) => {
    onSelect(p)
    setQuery('')
  }

  return (
    <div className="relative">
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder={placeholder}
        className="w-full bg-cream border-2 border-ink rounded-lg px-3 py-2 text-ink text-sm placeholder-ink-muted-2 outline-none"
      />
      {query && (
        <div className="absolute z-10 top-full left-0 right-0 mt-1 bg-cream border-2 border-ink rounded-lg shadow-[var(--shadow-pixel)] max-h-64 overflow-y-auto">
          {matches.length === 0 ? (
            <p className="text-ink-muted-2 text-sm px-3 py-2">Aucun résultat</p>
          ) : (
            matches.map((p) => (
              <button
                key={p.id}
                onClick={() => handleSelect(p)}
                className="w-full flex items-center gap-2 px-3 py-2 border-b border-[#cfc7a8] last:border-b-0 hover:bg-cream-secondary transition-colors text-left"
              >
                {p.image_miniature && (
                  <img src={p.image_miniature} alt={p.nom} className="pixelated w-6 h-6 object-contain shrink-0" />
                )}
                <span className="text-ink-muted-2 text-xs shrink-0">#{p.numero}</span>
                <span className="text-ink text-sm truncate">{p.nom}</span>
              </button>
            ))
          )}
        </div>
      )}
    </div>
  )
}
