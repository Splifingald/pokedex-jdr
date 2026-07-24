import { useState, useMemo } from 'react'
import type { Item } from '../types'
import { POKEDOLLAR_ITEM_NAME } from '../types'
import { normalizeSearch } from '../lib/normalizeSearch'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'

interface Props {
  options: Item[]
  /** Quantités possédées par nom d'objet, pour afficher "n en sac" dans les résultats */
  ownedQty?: Map<string, number>
  onSelect: (item: Item) => void
}

export function ItemSearchInput({ options, ownedQty, onSelect }: Props) {
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
        placeholder="Rechercher un objet…"
        className={`w-full px-3 py-2 rounded-lg ${PIXEL_BORDER_SM} bg-cream text-ink text-sm placeholder-ink-muted-2 outline-none`}
      />
      {query && (
        <div className={`absolute z-10 top-full left-0 right-0 mt-1 rounded-lg ${PIXEL_BORDER_SM} bg-cream shadow-[var(--shadow-pixel)] max-h-56 overflow-y-auto`}>
          {matches.length === 0 ? (
            <p className="text-ink-muted-2 text-sm px-3 py-2">Aucun résultat</p>
          ) : (
            matches.map((i) => {
              const qty = ownedQty?.get(i.nom) ?? 0
              return (
                <button
                  key={i.nom}
                  onClick={() => handleSelect(i)}
                  className="w-full flex items-center gap-2 px-3 py-2 border-b border-[#cfc7a8] last:border-b-0 hover:bg-cream-secondary transition-colors text-left"
                >
                  <div className="w-6 h-6 shrink-0 flex items-center justify-center">
                    {i.image_url ? (
                      <img src={i.image_url} alt="" className="w-full h-full object-contain" />
                    ) : (
                      <span className="text-lg">🎒</span>
                    )}
                  </div>
                  <span className="flex-1 text-ink text-sm truncate">{i.nom}</span>
                  <span className="text-xs text-ink-muted-2 shrink-0">
                    {qty > 0 ? `${qty} en sac` : 'Ajouter'}
                  </span>
                </button>
              )
            })
          )}
        </div>
      )}
    </div>
  )
}
