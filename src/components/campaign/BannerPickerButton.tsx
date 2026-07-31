import { useMemo, useState } from 'react'
import type { DisplayAsset } from '../../types'
import { normalizeSearch } from '../../lib/normalizeSearch'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'

interface Props {
  displayAssets: DisplayAsset[]
  onSelect: (url: string) => void
  /** 'icon' : petit bouton carré (barre d'outils) — 'button' : bouton rectangulaire libellé (formulaires) */
  variant?: 'icon' | 'button'
  label?: string
  confirmLabel?: string
}

// Sélecteur d'image partagé entre "insérer une bannière" (fil du chapitre) et les en-têtes
// de session/chapitre : choix parmi les Fonds existants (display_assets de type Background)
// ou saisie libre d'une URL.
export function BannerPickerButton({ displayAssets, onSelect, variant = 'icon', label = 'Choisir une image', confirmLabel = 'Choisir' }: Props) {
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState('')
  const [url, setUrl] = useState('')

  const backgrounds = useMemo(() => displayAssets.filter((a) => a.type === 'Background'), [displayAssets])

  const filtered = useMemo(() => {
    const q = normalizeSearch(query.trim())
    const list = q ? backgrounds.filter((a) => normalizeSearch(a.nom).includes(q)) : backgrounds
    return list.slice(0, 50)
  }, [query, backgrounds])

  const handleSelect = (src: string) => {
    onSelect(src)
    setOpen(false)
    setQuery('')
    setUrl('')
  }

  return (
    <>
      {variant === 'icon' ? (
        <button
          type="button"
          title={label}
          onClick={() => setOpen(true)}
          className={`w-8 h-8 rounded text-sm flex items-center justify-center shrink-0 ${BUTTON_STYLE.gray}`}
        >
          🖼️
        </button>
      ) : (
        <button
          type="button"
          onClick={() => setOpen(true)}
          className={`py-2 px-3 rounded text-sm font-bold inline-flex items-center justify-center gap-1.5 ${BUTTON_STYLE.gray}`}
        >
          🖼️ {label}
        </button>
      )}
      {open && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
          onClick={(e) => { if (e.target === e.currentTarget) setOpen(false) }}
        >
          <div className={`w-80 max-w-[85vw] flex flex-col gap-2 bg-cream rounded-lg p-3 ${PIXEL_BORDER_SM}`}>
            <p className="text-ink text-xs font-bold">Choisir un fond existant</p>
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Rechercher…"
              className={`w-full px-3 py-2 rounded-lg ${PIXEL_BORDER_SM} bg-cream text-ink text-sm placeholder-ink-muted-2 outline-none`}
            />
            <div className={`max-h-56 overflow-y-auto rounded-lg bg-cream ${PIXEL_BORDER_SM}`}>
              {filtered.length === 0 ? (
                <p className="text-ink-muted-2 text-sm px-3 py-2">Aucun résultat</p>
              ) : (
                filtered.map((asset) => (
                  <button
                    key={asset.id}
                    type="button"
                    onClick={() => handleSelect(asset.image_url)}
                    className="w-full flex items-center gap-2 px-3 py-2 border-b border-[#cfc7a8] last:border-b-0 hover:bg-cream-secondary transition-colors text-left"
                  >
                    <img src={asset.image_url} alt="" className="w-8 h-8 shrink-0 object-cover rounded" />
                    <span className="flex-1 text-ink text-sm truncate">{asset.nom}</span>
                  </button>
                ))
              )}
            </div>

            <p className="text-ink text-xs font-bold mt-1">…ou coller une image</p>
            <div className="flex items-center gap-2">
              <input
                type="text"
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                placeholder="Lien de l'image"
                className={`flex-1 px-3 py-2 rounded-lg ${PIXEL_BORDER_SM} bg-cream text-ink text-sm placeholder-ink-muted-2 outline-none`}
              />
              <button
                type="button"
                disabled={!url.trim()}
                onClick={() => handleSelect(url.trim())}
                className={`text-sm px-3 py-2 rounded-lg font-bold disabled:opacity-40 ${BUTTON_STYLE.green}`}
              >
                {confirmLabel}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
