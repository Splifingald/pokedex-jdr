import { useState, useMemo } from 'react'
import type { Player } from '../types'
import { normalizeSearch } from '../lib/normalizeSearch'

interface Props {
  options: Player[]
  onSelect: (player: Player) => void
  placeholder?: string
}

export function PlayerSearchInput({ options, onSelect, placeholder = 'Rechercher un joueur…' }: Props) {
  const [query, setQuery] = useState('')

  const matches = useMemo(() => {
    const q = normalizeSearch(query.trim())
    if (!q) return []
    return options.filter((p) => normalizeSearch(p.name).includes(q)).slice(0, 8)
  }, [query, options])

  const handleSelect = (p: Player) => {
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
        className="w-full bg-white border-2 border-ink rounded-lg px-3 py-2 text-ink text-sm placeholder-ink-muted-2 outline-none"
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
                <div className="w-6 h-6 rounded-full overflow-hidden shrink-0 border-2" style={{ borderColor: p.color }}>
                  {p.image_url ? (
                    <img src={p.image_url} alt={p.name} className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full" style={{ backgroundColor: p.color }} />
                  )}
                </div>
                <span className="text-ink text-sm truncate">{p.name}</span>
                {p.is_npc && <span className="text-purple-800 text-[10px] font-bold shrink-0">PNJ</span>}
              </button>
            ))
          )}
        </div>
      )}
    </div>
  )
}
