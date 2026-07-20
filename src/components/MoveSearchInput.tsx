import { useState, useMemo } from 'react'
import type { Attack } from '../types'
import { TypeBadge } from './TypeBadge'
import { normalizeSearch } from '../lib/normalizeSearch'

interface Props {
  options: Attack[]
  disabled: boolean
  onSelect: (attack: Attack) => void
}

export function MoveSearchInput({ options, disabled, onSelect }: Props) {
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
      <p className="text-gray-500 text-sm bg-gray-800 border border-gray-700 rounded px-3 py-2">
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
        className="w-full bg-gray-900 border border-gray-700 rounded px-3 py-2 text-white text-sm placeholder-gray-500 outline-none focus:border-red-500 transition-colors"
      />
      {query && (
        <div className="absolute z-10 top-full left-0 right-0 mt-1 bg-gray-800 border border-gray-700 rounded shadow-lg max-h-64 overflow-y-auto">
          {matches.length === 0 ? (
            <p className="text-gray-500 text-sm px-3 py-2">Aucun résultat</p>
          ) : (
            matches.map((a) => (
              <button
                key={a.nom}
                onClick={() => handleSelect(a)}
                className="w-full flex items-center gap-2 px-3 py-2 hover:bg-gray-700 transition-colors text-left"
              >
                <TypeBadge type={a.type} small />
                <span className="text-white text-sm truncate">{a.nom}</span>
              </button>
            ))
          )}
        </div>
      )}
    </div>
  )
}
