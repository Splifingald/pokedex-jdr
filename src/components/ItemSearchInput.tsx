import { useState, useMemo } from 'react'
import type { Item } from '../types'
import { POKEDOLLAR_ITEM_NAME } from '../types'
import { normalizeSearch } from '../lib/normalizeSearch'

interface Props {
  options: Item[]
  onSelect: (item: Item) => void
}

export function ItemSearchInput({ options, onSelect }: Props) {
  const [query, setQuery] = useState('')

  const matches = useMemo(() => {
    const q = normalizeSearch(query.trim())
    if (!q) return []
    return options
      .filter((i) => i.nom !== POKEDOLLAR_ITEM_NAME && normalizeSearch(i.nom).includes(q))
      .slice(0, 8)
  }, [query, options])

  const handleSelect = (item: Item) => {
    onSelect(item)
    setQuery('')
  }

  return (
    <div className="relative">
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Ajouter un objet…"
        className="w-full bg-gray-900 border border-gray-700 rounded px-3 py-2 text-white text-sm placeholder-gray-500 outline-none focus:border-red-500 transition-colors"
      />
      {query && (
        <div className="absolute z-10 top-full left-0 right-0 mt-1 bg-gray-800 border border-gray-700 rounded shadow-lg max-h-64 overflow-y-auto">
          {matches.length === 0 ? (
            <p className="text-gray-500 text-sm px-3 py-2">Aucun résultat</p>
          ) : (
            matches.map((i) => (
              <button
                key={i.nom}
                onClick={() => handleSelect(i)}
                className="w-full flex items-center gap-2 px-3 py-2 hover:bg-gray-700 transition-colors text-left"
              >
                <div className="w-6 h-6 shrink-0 flex items-center justify-center">
                  {i.image_url ? (
                    <img src={i.image_url} alt="" className="w-full h-full object-contain" />
                  ) : (
                    <span className="text-lg">🎒</span>
                  )}
                </div>
                <span className="text-white text-sm truncate">{i.nom}</span>
              </button>
            ))
          )}
        </div>
      )}
    </div>
  )
}
