import { useState, useMemo } from 'react'
import type { Pokemon } from '../types'

interface Props {
  options: Pokemon[]
  onSelect: (pokemon: Pokemon) => void
  placeholder?: string
}

export function PokemonSearchInput({ options, onSelect, placeholder = 'Rechercher un pokémon…' }: Props) {
  const [query, setQuery] = useState('')

  const matches = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return []
    return options.filter((p) => p.nom.toLowerCase().includes(q) || p.numero.includes(q)).slice(0, 8)
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
        className="w-full bg-gray-900 border border-gray-700 rounded px-3 py-2 text-white text-sm placeholder-gray-500 outline-none focus:border-red-500 transition-colors"
      />
      {query && (
        <div className="absolute z-10 top-full left-0 right-0 mt-1 bg-gray-800 border border-gray-700 rounded shadow-lg max-h-64 overflow-y-auto">
          {matches.length === 0 ? (
            <p className="text-gray-500 text-sm px-3 py-2">Aucun résultat</p>
          ) : (
            matches.map((p) => (
              <button
                key={p.id}
                onClick={() => handleSelect(p)}
                className="w-full flex items-center gap-2 px-3 py-2 hover:bg-gray-700 transition-colors text-left"
              >
                {p.image_miniature && (
                  <img src={p.image_miniature} alt={p.nom} className="pixelated w-6 h-6 object-contain shrink-0" />
                )}
                <span className="text-gray-400 text-xs shrink-0">#{p.numero}</span>
                <span className="text-white text-sm truncate">{p.nom}</span>
              </button>
            ))
          )}
        </div>
      )}
    </div>
  )
}
