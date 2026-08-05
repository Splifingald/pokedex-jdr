import { useState, useEffect, useMemo } from 'react'
import { useMiningConfig } from '../hooks/useMiningConfig'
import { useMiningItemDefs } from '../hooks/useMiningItemDefs'
import { useItems } from '../hooks/useItems'
import { NumberInput } from './NumberInput'
import { ItemSearchInput } from './ItemSearchInput'
import { CloseIcon } from './icons/CloseIcon'
import { PokedollarIcon } from './PokedollarIcon'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { computeGridExpectedValue } from '../lib/mining'
import { POKEDOLLAR_ITEM_NAME } from '../types'

const CARD = 'bg-cream-secondary border-2 border-ink rounded-[var(--radius-pixel)] p-4 mb-4 break-inside-avoid-column'
const CARD_TITLE = 'text-[#a3841a] text-base font-bold mb-3'

export function AdminMiningProceduralPanel() {
  const { config, loading, updateConfig } = useMiningConfig()
  const { itemDefs, addItemDef, updateItemDef, removeItemDef } = useMiningItemDefs()
  const { items, byName: itemsByName } = useItems()

  const [nom, setNom] = useState(config.nom)
  const [iconUrl, setIconUrl] = useState(config.icon_url)
  const [bannerUrl, setBannerUrl] = useState(config.banner_url)
  const [hiddenCellImageUrl, setHiddenCellImageUrl] = useState(config.hidden_cell_image_url)
  const [emptyCellImageUrl, setEmptyCellImageUrl] = useState(config.empty_cell_image_url)

  useEffect(() => {
    setNom(config.nom)
    setIconUrl(config.icon_url)
    setBannerUrl(config.banner_url)
    setHiddenCellImageUrl(config.hidden_cell_image_url)
    setEmptyCellImageUrl(config.empty_cell_image_url)
  }, [config])

  // Espérance de valeur — pour savoir ce que "vaut" un ticket en moyenne.
  const evStats = useMemo(() => computeGridExpectedValue(config, itemDefs, itemsByName), [config, itemDefs, itemsByName])
  const pokedollarImageUrl = itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url

  if (loading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  const totalWeight = itemDefs.reduce((sum, d) => sum + (d.enabled ? d.weight : 0), 0)

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">⛏️</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Fouille — Génération procédurale</h3>
      </div>

      <div className="flex flex-col gap-4">
        <div className="columns-1 lg:columns-2 gap-4">
          <div className={CARD}>
            <p className={CARD_TITLE}>Affichage</p>
            <div className="flex flex-col gap-3">
              <div>
                <label className="text-ink-muted-2 text-sm block mb-1">Nom affiché</label>
                <input
                  type="text"
                  value={nom}
                  onChange={(e) => setNom(e.target.value)}
                  onBlur={() => updateConfig({ nom })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div className="flex gap-3">
                <div className="flex-1">
                  <label className="text-ink-muted-2 text-sm block mb-1">Icône (URL)</label>
                  <input
                    type="text"
                    value={iconUrl}
                    onChange={(e) => setIconUrl(e.target.value)}
                    onBlur={() => updateConfig({ icon_url: iconUrl })}
                    placeholder="https://…"
                    className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                  />
                </div>
                <div className="flex-1">
                  <label className="text-ink-muted-2 text-sm block mb-1">Bannière (URL)</label>
                  <input
                    type="text"
                    value={bannerUrl}
                    onChange={(e) => setBannerUrl(e.target.value)}
                    onBlur={() => updateConfig({ banner_url: bannerUrl })}
                    placeholder="https://…"
                    className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                  />
                </div>
              </div>
              <div>
                <label className="text-ink-muted-2 text-sm block mb-1">Sprite de case cachée (URL)</label>
                <input
                  type="text"
                  value={hiddenCellImageUrl}
                  onChange={(e) => setHiddenCellImageUrl(e.target.value)}
                  onBlur={() => updateConfig({ hidden_cell_image_url: hiddenCellImageUrl })}
                  placeholder="https://… (vide = « ? »)"
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div>
                <label className="text-ink-muted-2 text-sm block mb-1">Sprite de case vide creusée (URL)</label>
                <input
                  type="text"
                  value={emptyCellImageUrl}
                  onChange={(e) => setEmptyCellImageUrl(e.target.value)}
                  onBlur={() => updateConfig({ empty_cell_image_url: emptyCellImageUrl })}
                  placeholder="https://… (vide = case unie)"
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
            </div>
          </div>

          <div className={CARD}>
            <p className={CARD_TITLE}>Taille de grille (carrée, N×N cases)</p>
            <div className="flex gap-3">
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Minimum</label>
                <NumberInput
                  min={2}
                  fallback={config.grid_size_min}
                  value={config.grid_size_min}
                  onCommit={(v) => updateConfig({ grid_size_min: Math.max(2, Math.min(v, config.grid_size_max)) })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Maximum</label>
                <NumberInput
                  min={2}
                  fallback={config.grid_size_max}
                  value={config.grid_size_max}
                  onCommit={(v) => updateConfig({ grid_size_max: Math.max(v, config.grid_size_min) })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
            </div>
          </div>

          <div className={CARD}>
            <p className={CARD_TITLE}>Remplissage de la grille (% de cases occupées par des objets)</p>
            <NumberInput
              min={1}
              fallback={config.fill_ratio_pct}
              value={config.fill_ratio_pct}
              onCommit={(v) => updateConfig({ fill_ratio_pct: Math.max(1, Math.min(100, v)) })}
              className="w-40 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
            <p className="text-ink-muted-2 text-xs mt-1">
              Les objets sont tirés un par un (au poids) et placés jusqu'à atteindre ce seuil — le dernier tirage peut le dépasser légèrement.
            </p>
          </div>

          <div className={CARD}>
            <p className={CARD_TITLE}>Coups disponibles (% des cases de la grille)</p>
            <NumberInput
              min={1}
              fallback={config.move_budget_pct}
              value={config.move_budget_pct}
              onCommit={(v) => updateConfig({ move_budget_pct: Math.max(1, Math.min(100, v)) })}
              className="w-40 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
            <p className="text-ink-muted-2 text-xs mt-1">
              Ex : 50% sur une grille 4×4 (16 cases) → 8 coups avant épuisement de la grille.
            </p>
          </div>
        </div>

        <div>
          <p className="text-ink-muted-2 text-sm mb-2 font-bold">Objets pouvant apparaître (taille + poids de tirage)</p>
          <div className="flex flex-col gap-1.5 mb-2">
            {itemDefs.length === 0 ? (
              <p className="text-ink-muted-2 text-xs italic">Aucun objet — les grilles générées seront vides.</p>
            ) : (
              itemDefs.map((def) => {
                const item = itemsByName.get(def.item_nom)
                const pct = totalWeight > 0 && def.enabled ? Math.round((def.weight / totalWeight) * 100) : 0
                return (
                  <div key={def.id} className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={def.enabled}
                      onChange={(e) => updateItemDef(def.id, { enabled: e.target.checked })}
                      className="w-4 h-4 shrink-0"
                      title="Actif dans le tirage"
                    />
                    <div className="w-6 h-6 shrink-0 flex items-center justify-center">
                      {item?.image_url ? (
                        <img src={item.image_url} alt="" className="w-full h-full object-contain" />
                      ) : (
                        <span className="text-lg">🎒</span>
                      )}
                    </div>
                    <span className="flex-1 text-ink text-sm truncate">{def.item_nom}</span>
                    <span className="text-ink-muted-2 text-xs">Taille</span>
                    <select
                      value={def.size}
                      onChange={(e) => updateItemDef(def.id, { size: Number(e.target.value) as 1 | 2 | 3 | 4 })}
                      className="w-16 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm outline-none"
                    >
                      {[1, 2, 3, 4].map((s) => (
                        <option key={s} value={s}>{s}×{s}</option>
                      ))}
                    </select>
                    <span className="text-ink-muted-2 text-xs">Poids</span>
                    <NumberInput
                      min={0}
                      fallback={def.weight}
                      value={def.weight}
                      onCommit={(v) => updateItemDef(def.id, { weight: Math.max(0, v) })}
                      className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
                    />
                    <span className="text-ink-muted-2 text-xs w-9 text-right">{pct}%</span>
                    <button onClick={() => removeItemDef(def.id)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
                      <CloseIcon className="w-3 h-3" />
                    </button>
                  </div>
                )
              })
            )}
          </div>
          <ItemSearchInput
            options={items}
            onSelect={(item) => addItemDef(item.nom, 1, 1)}
          />

          <div className={`mt-3 p-3 rounded ${PIXEL_BORDER_SM} bg-white/60 text-xs text-ink-muted-2 flex justify-between`}>
            <span>
              Valeur moyenne d'une grille : <strong className="text-ink">{evStats.expectedGridValue.toFixed(1)}</strong>{' '}
              <PokedollarIcon imageUrl={pokedollarImageUrl} size={14} className="align-[-2px]" />
            </span>
            <span>
              Valeur moyenne d'une case (≈ valeur d'un ticket) : <strong className="text-ink">{evStats.expectedCellValue.toFixed(1)}</strong>{' '}
              <PokedollarIcon imageUrl={pokedollarImageUrl} size={14} className="align-[-2px]" />
            </span>
          </div>
        </div>
      </div>
    </div>
  )
}
