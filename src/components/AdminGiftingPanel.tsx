import { useState } from 'react'
import type { GiftTimerUnit } from '../types'
import { useGiftLootboxes } from '../hooks/useGiftLootboxes'
import { useItems } from '../hooks/useItems'
import { usePokemon } from '../hooks/usePokemon'
import { NumberInput } from './NumberInput'
import { ItemSearchInput } from './ItemSearchInput'
import { PokemonSearchInput } from './PokemonSearchInput'
import { ConfirmPopup } from './ConfirmPopup'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { TrashIcon } from './icons/TrashIcon'
import { GIFT_ICON } from '../lib/icons'

export function AdminGiftingPanel() {
  const {
    lootboxes, itemsByLootbox, speciesByLootbox, loading,
    createLootbox, updateLootbox, deleteLootbox, setDefaultLootbox,
    addLootboxItem, updateLootboxItem, removeLootboxItem,
    assignSpecies, unassignSpecies,
  } = useGiftLootboxes()
  const { items, byName: itemsByName } = useItems()
  const { pokemon } = usePokemon()

  const [newName, setNewName] = useState('')
  const [selectedId, setSelectedId] = useState<number | null>(null)
  const [confirmingDeleteId, setConfirmingDeleteId] = useState<number | null>(null)

  const selectedLootbox = lootboxes.find((l) => l.id === selectedId) ?? null
  const selectedItems = selectedId != null ? itemsByLootbox.get(selectedId) ?? [] : []
  const selectedSpecies = selectedId != null ? speciesByLootbox.get(selectedId) ?? [] : []
  const confirmingLootbox = lootboxes.find((l) => l.id === confirmingDeleteId) ?? null
  const affectedSpeciesCount = confirmingDeleteId != null ? (speciesByLootbox.get(confirmingDeleteId)?.length ?? 0) : 0

  const handleCreate = async () => {
    const nom = newName.trim()
    if (!nom) return
    const created = await createLootbox(nom)
    setNewName('')
    if (created) setSelectedId(created.id)
  }

  const handleDelete = async (id: number) => {
    await deleteLootbox(id)
    setConfirmingDeleteId(null)
    if (selectedId === id) setSelectedId(null)
  }

  return (
    <div className="flex flex-col md:flex-row gap-4 w-full items-start">
      <div className={`bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6 ${selectedLootbox ? 'md:w-96 shrink-0' : ''}`}>
        <div className="flex items-center gap-2 mb-5">
          <PixelIcon src={GIFT_ICON} size={24} />
          <h3 className="text-[#a3841a] text-lg font-bold">Cadeaux Pokémon</h3>
        </div>

        {loading ? (
          <p className="text-ink-muted-2 text-sm">Chargement…</p>
        ) : (
          <div className="flex flex-col gap-4">
            <div className="flex gap-2">
              <input
                type="text"
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') handleCreate() }}
                placeholder="Nom du nouveau lootbox…"
                className="flex-1 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
              <button onClick={handleCreate} className={`px-4 py-2 rounded text-sm font-bold ${BUTTON_STYLE.green}`}>
                Créer
              </button>
            </div>

            <div className="flex flex-col gap-2">
              {lootboxes.length === 0 ? (
                <p className="text-ink-muted-2 text-sm">Aucun lootbox pour l'instant.</p>
              ) : (
                lootboxes.map((lb) => (
                  <div key={lb.id} className={`flex items-center gap-2 px-3 py-2 rounded ${PIXEL_BORDER_SM} ${selectedId === lb.id ? 'bg-yellow-100 ring-2 ring-[#a3841a]' : 'bg-cream-secondary'}`}>
                    <span className="flex-1 text-ink text-sm font-bold truncate">{lb.nom}</span>
                    {lb.is_default ? (
                      <span className="text-[10px] bg-yellow-200 text-yellow-900 border border-yellow-700 rounded px-1.5 py-0.5 shrink-0">
                        ⭐ Par défaut
                      </span>
                    ) : (
                      <button
                        onClick={() => setDefaultLootbox(lb.id)}
                        className={`text-xs px-2 py-1 rounded shrink-0 ${BUTTON_STYLE.gray}`}
                      >
                        Définir par défaut
                      </button>
                    )}
                    <button
                      onClick={() => setSelectedId(selectedId === lb.id ? null : lb.id)}
                      className={`text-xs px-2 py-1 rounded shrink-0 ${selectedId === lb.id ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
                    >
                      Éditer
                    </button>
                    <button
                      onClick={() => setConfirmingDeleteId(lb.id)}
                      disabled={lb.is_default}
                      title={lb.is_default ? 'Désignez un autre lootbox par défaut avant de supprimer celui-ci' : undefined}
                      className={`text-xs px-2 py-1 rounded shrink-0 disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.gray}`}
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

      {selectedLootbox && (
        <div className="flex-1 min-w-0 bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
          <div className={`flex flex-col gap-4`}>
              <div>
                <label className="text-ink-muted-2 text-sm block mb-1">Nom</label>
                <input
                  key={selectedLootbox.id}
                  type="text"
                  defaultValue={selectedLootbox.nom}
                  onBlur={(e) => {
                    const v = e.target.value.trim()
                    if (v && v !== selectedLootbox.nom) updateLootbox(selectedLootbox.id, { nom: v })
                  }}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>

              <div className="flex gap-3">
                <div className="flex-1">
                  <label className="text-ink-muted-2 text-sm block mb-1">Minuteur min</label>
                  <NumberInput
                    min={0}
                    fallback={selectedLootbox.timer_min}
                    value={selectedLootbox.timer_min}
                    onCommit={(v) => updateLootbox(selectedLootbox.id, { timer_min: Math.max(0, v) })}
                    className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                  />
                </div>
                <div className="flex-1">
                  <label className="text-ink-muted-2 text-sm block mb-1">Minuteur max</label>
                  <NumberInput
                    min={0}
                    fallback={selectedLootbox.timer_max}
                    value={selectedLootbox.timer_max}
                    onCommit={(v) => updateLootbox(selectedLootbox.id, { timer_max: Math.max(0, v) })}
                    className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                  />
                </div>
                <div className="flex-1">
                  <label className="text-ink-muted-2 text-sm block mb-1">Unité</label>
                  <select
                    value={selectedLootbox.timer_unit}
                    onChange={(e) => updateLootbox(selectedLootbox.id, { timer_unit: e.target.value as GiftTimerUnit })}
                    className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                  >
                    <option value="hours">Heures</option>
                    <option value="minutes">Minutes</option>
                  </select>
                </div>
              </div>

              <div>
                <p className="text-ink-muted-2 text-sm mb-2">Objets (quantité fixe + poids du tirage)</p>
                <div className="flex flex-col gap-1.5 mb-2">
                  {selectedItems.length === 0 ? (
                    <p className="text-ink-muted-2 text-xs italic">Aucun objet — le tirage échouera.</p>
                  ) : (
                    selectedItems.map((row) => {
                      const item = itemsByName.get(row.item_nom)
                      return (
                        <div key={row.id} className="flex items-center gap-2">
                          <div className="w-6 h-6 shrink-0 flex items-center justify-center">
                            {item?.image_url ? (
                              <img src={item.image_url} alt="" className="w-full h-full object-contain" />
                            ) : (
                              <span className="text-lg">🎒</span>
                            )}
                          </div>
                          <span className="flex-1 text-ink text-sm truncate">{row.item_nom}</span>
                          <span className="text-ink-muted-2 text-xs">Qté</span>
                          <NumberInput
                            min={1}
                            fallback={1}
                            value={row.quantity}
                            onCommit={(v) => updateLootboxItem(row.id, { quantity: Math.max(1, v) })}
                            className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
                          />
                          <span className="text-ink-muted-2 text-xs">Poids</span>
                          <NumberInput
                            min={1}
                            fallback={1}
                            value={row.weight}
                            onCommit={(v) => updateLootboxItem(row.id, { weight: Math.max(1, v) })}
                            className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
                          />
                          <button onClick={() => removeLootboxItem(row.id)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
                            <CloseIcon className="w-3 h-3" />
                          </button>
                        </div>
                      )
                    })
                  )}
                </div>
                <ItemSearchInput
                  options={items}
                  includePokedollar
                  onSelect={(item) => addLootboxItem(selectedLootbox.id, item.nom, 1, 1)}
                />
              </div>

              <div>
                <p className="text-ink-muted-2 text-sm mb-2">Espèces assignées (sinon, lootbox par défaut)</p>
                <div className="flex flex-wrap gap-1.5 mb-2">
                  {selectedSpecies.length === 0 ? (
                    <p className="text-ink-muted-2 text-xs italic">Aucune espèce assignée.</p>
                  ) : (
                    selectedSpecies.map((s) => (
                      <span
                        key={s.pokemon_nom}
                        className={`flex items-center gap-1.5 pl-2 pr-1 py-1 rounded-full text-xs ${PIXEL_BORDER_SM} bg-cream`}
                      >
                        {s.pokemon_nom}
                        <button
                          onClick={() => unassignSpecies(s.pokemon_nom)}
                          className="w-4 h-4 flex items-center justify-center rounded-full hover:bg-black/10"
                        >
                          <CloseIcon className="w-2.5 h-2.5" />
                        </button>
                      </span>
                    ))
                  )}
                </div>
                <PokemonSearchInput
                  options={pokemon}
                  onSelect={(p) => assignSpecies(p.nom, selectedLootbox.id)}
                  placeholder="Assigner une espèce…"
                />
              </div>
          </div>
        </div>
      )}

      {confirmingLootbox && (
        <ConfirmPopup
          title={`Supprimer "${confirmingLootbox.nom}" ?`}
          message={affectedSpeciesCount > 0 ? `${affectedSpeciesCount} espèce(s) assignée(s) reviendront au lootbox par défaut.` : undefined}
          confirmLabel="Supprimer"
          danger
          onConfirm={() => handleDelete(confirmingLootbox.id)}
          onCancel={() => setConfirmingDeleteId(null)}
        />
      )}
    </div>
  )
}
