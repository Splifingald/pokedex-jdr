import { useState, useMemo } from 'react'
import type { DisplayAsset } from '../types'
import { normalizeSearch } from '../lib/normalizeSearch'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'

interface Props {
  options: DisplayAsset[]
  onSelect: (asset: DisplayAsset) => void
  placeholder?: string
}

export function DisplayAssetSearchInput({ options, onSelect, placeholder = 'Rechercher…' }: Props) {
  const [query, setQuery] = useState('')

  const matches = useMemo(() => {
    const q = normalizeSearch(query.trim())
    if (!q) return []
    return options.filter((a) => normalizeSearch(a.nom).includes(q)).slice(0, 8)
  }, [query, options])

  const handleSelect = (asset: DisplayAsset) => {
    onSelect(asset)
    setQuery('')
  }

  return (
    <div className="relative">
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder={placeholder}
        className={`w-full px-3 py-2 rounded-lg ${PIXEL_BORDER_SM} bg-cream text-ink text-sm placeholder-ink-muted-2 outline-none`}
      />
      {query && (
        <div className={`absolute z-10 top-full left-0 right-0 mt-1 rounded-lg ${PIXEL_BORDER_SM} bg-cream shadow-[var(--shadow-pixel)] max-h-56 overflow-y-auto`}>
          {matches.length === 0 ? (
            <p className="text-ink-muted-2 text-sm px-3 py-2">Aucun résultat</p>
          ) : (
            matches.map((a) => (
              <button
                key={a.id}
                onClick={() => handleSelect(a)}
                className="w-full flex items-center gap-2 px-3 py-2 border-b border-[#cfc7a8] last:border-b-0 hover:bg-cream-secondary transition-colors text-left"
              >
                <div className="w-6 h-6 shrink-0 flex items-center justify-center">
                  {a.image_url && <img src={a.image_url} alt="" className="w-full h-full object-contain" />}
                </div>
                <span className="flex-1 text-ink text-sm truncate">{a.nom}</span>
              </button>
            ))
          )}
        </div>
      )}
    </div>
  )
}
