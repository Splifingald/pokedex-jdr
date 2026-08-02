import { useState } from 'react'
import type { DisplayAsset } from '../../types'
import { normalizeSearch } from '../../lib/normalizeSearch'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'

interface Props {
  candidates: DisplayAsset[]
  selectedId: number | null
  onSelect: (id: number) => void
}

// Combobox cherchable pour choisir, parmi les images partageant la Reference d'un PNJ/lieu,
// laquelle pousser vers le Mode Affichage — contrairement à DisplayAssetSearchInput (liste
// vide tant qu'on ne tape pas), affiche la sélection courante au repos et ne filtre que
// dans la liste de candidats fournie, pas tout le catalogue display_assets.
export function DisplayAssetCandidatePicker({ candidates, selectedId, onSelect }: Props) {
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(false)

  const selected = candidates.find((c) => c.id === selectedId) ?? null

  const q = normalizeSearch(query.trim())
  const matches = q ? candidates.filter((c) => normalizeSearch(c.nom).includes(q)) : candidates

  const handleSelect = (asset: DisplayAsset) => {
    onSelect(asset.id)
    setQuery('')
    setOpen(false)
  }

  return (
    <div className="relative flex-1 min-w-[140px]">
      <input
        type="text"
        value={open ? query : (selected?.nom ?? '')}
        onChange={(e) => setQuery(e.target.value)}
        onFocus={() => {
          setOpen(true)
          setQuery('')
        }}
        onBlur={() => setTimeout(() => setOpen(false), 150)}
        placeholder="Rechercher une image…"
        className={`w-full px-2 py-1 rounded-lg ${PIXEL_BORDER_SM} bg-cream text-ink text-xs placeholder-ink-muted-2 outline-none`}
      />
      {open && (
        <div className={`absolute z-10 top-full left-0 right-0 mt-1 rounded-lg ${PIXEL_BORDER_SM} bg-cream shadow-[var(--shadow-pixel)] max-h-56 overflow-y-auto`}>
          {matches.length === 0 ? (
            <p className="text-ink-muted-2 text-sm px-3 py-2">Aucun résultat</p>
          ) : (
            matches.map((a) => (
              <button
                key={a.id}
                onMouseDown={(e) => {
                  e.preventDefault()
                  handleSelect(a)
                }}
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
