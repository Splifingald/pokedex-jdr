import { useState, useMemo } from 'react'
import { useMiningCustomGrids } from '../hooks/useMiningCustomGrids'
import { useMiningConfig } from '../hooks/useMiningConfig'
import { useItems } from '../hooks/useItems'
import type { MiningCustomGridItem } from '../types'
import { NumberInput } from './NumberInput'
import { ItemSearchInput } from './ItemSearchInput'
import { ConfirmPopup } from './ConfirmPopup'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { CloseIcon } from './icons/CloseIcon'
import { TrashIcon } from './icons/TrashIcon'

function computeOccupancy(size: number, placements: MiningCustomGridItem[]): Map<number, MiningCustomGridItem> {
  const map = new Map<number, MiningCustomGridItem>()
  for (const p of placements) {
    for (let r = 0; r < p.size; r++) {
      for (let c = 0; c < p.size; c++) {
        map.set((p.origin_row + r) * size + (p.origin_col + c), p)
      }
    }
  }
  return map
}

export function AdminMiningCustomGridsPanel() {
  const { grids, placementsByGridId, loading, createGrid, updateGrid, deleteGrid, addPlacement, removePlacement } = useMiningCustomGrids()
  const { config, updateConfig } = useMiningConfig()
  const { items, byName: itemsByName } = useItems()

  const [newName, setNewName] = useState('')
  const [newSize, setNewSize] = useState(4)
  const [newMoveBudget, setNewMoveBudget] = useState(8)
  const [selectedId, setSelectedId] = useState<number | null>(null)
  const [confirmingDeleteId, setConfirmingDeleteId] = useState<number | null>(null)
  const [pendingPlacement, setPendingPlacement] = useState<{ item_nom: string; size: 1 | 2 | 3 | 4 } | null>(null)
  const [placementError, setPlacementError] = useState<string | null>(null)

  const selectedGrid = grids.find((g) => g.id === selectedId) ?? null
  const selectedPlacements = useMemo(
    () => (selectedId != null ? placementsByGridId.get(selectedId) ?? [] : []),
    [selectedId, placementsByGridId]
  )
  const occupancy = useMemo(
    () => (selectedGrid ? computeOccupancy(selectedGrid.size, selectedPlacements) : new Map<number, MiningCustomGridItem>()),
    [selectedGrid, selectedPlacements]
  )
  const confirmingGrid = grids.find((g) => g.id === confirmingDeleteId) ?? null
  const queuedGrid = grids.find((g) => g.id === config.next_custom_grid_id) ?? null

  const handleCreate = async () => {
    const nom = newName.trim()
    if (!nom) return
    const created = await createGrid(nom, Math.max(2, newSize), Math.max(1, newMoveBudget))
    setNewName('')
    if (created) setSelectedId(created.id)
  }

  const handleDelete = async (id: number) => {
    await deleteGrid(id)
    setConfirmingDeleteId(null)
    if (selectedId === id) setSelectedId(null)
  }

  const handleCellClick = (row: number, col: number) => {
    if (!selectedGrid) return
    setPlacementError(null)

    const occupant = occupancy.get(row * selectedGrid.size + col)
    if (!pendingPlacement) {
      // Pas d'objet en attente de placement : un clic sur une case occupée la retire.
      if (occupant) removePlacement(occupant.id)
      return
    }

    if (row + pendingPlacement.size > selectedGrid.size || col + pendingPlacement.size > selectedGrid.size) {
      setPlacementError('Cet objet dépasserait la grille à cet endroit.')
      return
    }
    for (let r = 0; r < pendingPlacement.size; r++) {
      for (let c = 0; c < pendingPlacement.size; c++) {
        if (occupancy.has((row + r) * selectedGrid.size + (col + c))) {
          setPlacementError('Cet emplacement chevauche un autre objet.')
          return
        }
      }
    }
    addPlacement(selectedGrid.id, pendingPlacement.item_nom, pendingPlacement.size, row, col)
    setPendingPlacement(null)
  }

  return (
    <div className="flex flex-col md:flex-row gap-4 w-full items-start">
      <div className={`bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6 ${selectedGrid ? 'md:w-96 shrink-0' : ''}`}>
        <div className="flex items-center gap-2 mb-5">
          <span className="text-2xl">🗺️</span>
          <h3 className="text-[#a3841a] text-lg font-bold">Grilles personnalisées</h3>
        </div>

        {queuedGrid && (
          <div className={`flex items-center gap-2 p-2 rounded mb-4 ${PIXEL_BORDER_SM} bg-yellow-100`}>
            <span className="flex-1 text-ink text-xs">
              Grille en file pour la prochaine partie : <strong>{queuedGrid.nom}</strong>
            </span>
            <button onClick={() => updateConfig({ next_custom_grid_id: null })} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
              Retirer
            </button>
          </div>
        )}

        {loading ? (
          <p className="text-ink-muted-2 text-sm">Chargement…</p>
        ) : (
          <div className="flex flex-col gap-4">
            <div className="flex flex-col gap-2">
              <input
                type="text"
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                placeholder="Nom de la nouvelle grille…"
                className="bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
              <div className="flex gap-2">
                <div className="flex-1">
                  <label className="text-ink-muted-2 text-xs block mb-1">Taille</label>
                  <NumberInput
                    min={2}
                    fallback={newSize}
                    value={newSize}
                    onCommit={(v) => setNewSize(Math.max(2, v))}
                    className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                  />
                </div>
                <div className="flex-1">
                  <label className="text-ink-muted-2 text-xs block mb-1">Coups dispo.</label>
                  <NumberInput
                    min={1}
                    fallback={newMoveBudget}
                    value={newMoveBudget}
                    onCommit={(v) => setNewMoveBudget(Math.max(1, v))}
                    className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                  />
                </div>
              </div>
              <button onClick={handleCreate} className={`px-4 py-2 rounded text-sm font-bold ${BUTTON_STYLE.green}`}>
                Créer
              </button>
            </div>

            <div className="flex flex-col gap-2">
              {grids.length === 0 ? (
                <p className="text-ink-muted-2 text-sm">Aucune grille personnalisée pour l'instant.</p>
              ) : (
                grids.map((g) => (
                  <div key={g.id} className={`flex items-center gap-2 px-3 py-2 rounded ${PIXEL_BORDER_SM} ${selectedId === g.id ? 'bg-yellow-100 ring-2 ring-[#a3841a]' : 'bg-cream-secondary'}`}>
                    <span className="flex-1 text-ink text-sm font-bold truncate">{g.nom}</span>
                    <span className="text-ink-muted-2 text-xs shrink-0">{g.size}×{g.size} · {g.move_budget} coups</span>
                    {config.next_custom_grid_id === g.id ? (
                      <span className="text-[10px] bg-yellow-200 text-yellow-900 border border-yellow-700 rounded px-1.5 py-0.5 shrink-0">
                        ⏳ En file
                      </span>
                    ) : (
                      <button
                        onClick={() => updateConfig({ next_custom_grid_id: g.id })}
                        className={`text-xs px-2 py-1 rounded shrink-0 ${BUTTON_STYLE.gray}`}
                      >
                        Mettre en file
                      </button>
                    )}
                    <button
                      onClick={() => setSelectedId(selectedId === g.id ? null : g.id)}
                      className={`text-xs px-2 py-1 rounded shrink-0 ${selectedId === g.id ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
                    >
                      Éditer
                    </button>
                    <button
                      onClick={() => setConfirmingDeleteId(g.id)}
                      className={`text-xs px-2 py-1 rounded shrink-0 ${BUTTON_STYLE.gray}`}
                    >
                      <TrashIcon className="w-3 h-3" />
                    </button>
                  </div>
                ))
              )}
            </div>
          </div>
        )}
      </div>

      {selectedGrid && (
        <div className="flex-1 min-w-0 bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
          <div className="flex flex-col gap-4">
            <div>
              <label className="text-ink-muted-2 text-sm block mb-1">Nom</label>
              <input
                key={selectedGrid.id}
                type="text"
                defaultValue={selectedGrid.nom}
                onBlur={(e) => {
                  const v = e.target.value.trim()
                  if (v && v !== selectedGrid.nom) updateGrid(selectedGrid.id, { nom: v })
                }}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>

            <div className="flex gap-3">
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Coups disponibles</label>
                <NumberInput
                  min={1}
                  fallback={selectedGrid.move_budget}
                  value={selectedGrid.move_budget}
                  onCommit={(v) => updateGrid(selectedGrid.id, { move_budget: Math.max(1, v) })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div className="flex-1">
                <p className="text-ink-muted-2 text-sm mb-1">Taille</p>
                <p className="text-ink text-sm py-2">{selectedGrid.size}×{selectedGrid.size} ({selectedGrid.size * selectedGrid.size} cases)</p>
              </div>
            </div>

            <div>
              <p className="text-ink-muted-2 text-sm mb-2">
                Objet à placer — choisissez-le puis cliquez sur la grille (coin haut-gauche de l'objet)
              </p>
              <div className="flex items-center gap-2 mb-2">
                <ItemSearchInput
                  options={items}
                  onSelect={(item) => setPendingPlacement({ item_nom: item.nom, size: 1 })}
                />
              </div>
              {pendingPlacement && (
                <div className={`flex items-center gap-2 p-2 rounded mb-2 ${PIXEL_BORDER_SM} bg-cream-secondary`}>
                  <span className="text-ink text-sm flex-1 truncate">
                    En attente de placement : <strong>{pendingPlacement.item_nom}</strong>
                  </span>
                  <span className="text-ink-muted-2 text-xs">Taille</span>
                  <select
                    value={pendingPlacement.size}
                    onChange={(e) => setPendingPlacement((p) => (p ? { ...p, size: Number(e.target.value) as 1 | 2 | 3 | 4 } : p))}
                    className="w-16 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm outline-none"
                  >
                    {[1, 2, 3, 4].map((s) => (
                      <option key={s} value={s}>{s}×{s}</option>
                    ))}
                  </select>
                  <button onClick={() => setPendingPlacement(null)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
                    <CloseIcon className="w-3 h-3" />
                  </button>
                </div>
              )}
              {placementError && <p className="text-red-700 text-xs mb-2">{placementError}</p>}

              <div className="overflow-x-auto">
                <div
                  className="inline-grid gap-0.5"
                  style={{ gridTemplateColumns: `repeat(${selectedGrid.size}, minmax(28px, 1fr))` }}
                >
                  {Array.from({ length: selectedGrid.size * selectedGrid.size }, (_, idx) => {
                    const row = Math.floor(idx / selectedGrid.size)
                    const col = idx % selectedGrid.size
                    const occupant = occupancy.get(idx)
                    const catalogItem = occupant ? itemsByName.get(occupant.item_nom) : undefined
                    return (
                      <button
                        key={idx}
                        onClick={() => handleCellClick(row, col)}
                        title={occupant ? occupant.item_nom : 'Case vide'}
                        className={`aspect-square rounded ${PIXEL_BORDER_SM} flex items-center justify-center overflow-hidden ${occupant ? 'bg-cream-secondary' : 'bg-white hover:bg-yellow-50'}`}
                      >
                        {occupant && catalogItem?.image_url ? (
                          <img src={catalogItem.image_url} alt="" className="w-full h-full object-contain p-0.5" />
                        ) : null}
                      </button>
                    )
                  })}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {confirmingGrid && (
        <ConfirmPopup
          title={`Supprimer "${confirmingGrid.nom}" ?`}
          confirmLabel="Supprimer"
          danger
          onConfirm={() => handleDelete(confirmingGrid.id)}
          onCancel={() => setConfirmingDeleteId(null)}
        />
      )}
    </div>
  )
}
