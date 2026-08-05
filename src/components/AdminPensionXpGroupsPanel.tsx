import { useState } from 'react'
import type { GiftTimerUnit } from '../types'
import { usePensionXpGroups } from '../hooks/usePensionXpGroups'
import { usePokemon } from '../hooks/usePokemon'
import { NumberInput } from './NumberInput'
import { PokemonSearchInput } from './PokemonSearchInput'
import { ConfirmPopup } from './ConfirmPopup'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { CloseIcon } from './icons/CloseIcon'
import { TrashIcon } from './icons/TrashIcon'

// Entièrement séparé des groupes d'œufs (AdminPensionGroupsPanel) — créés et
// peuplés à la main ici, pas de CSV. Même structure que AdminGiftingPanel
// (liste + panneau d'édition + assignation d'espèces par recherche).
export function AdminPensionXpGroupsPanel() {
  const {
    xpGroups, speciesByXpGroup, loading,
    createXpGroup, updateXpGroup, deleteXpGroup, assignSpecies, unassignSpecies,
  } = usePensionXpGroups()
  const { pokemon } = usePokemon()

  const [newName, setNewName] = useState('')
  const [selectedId, setSelectedId] = useState<number | null>(null)
  const [confirmingDeleteId, setConfirmingDeleteId] = useState<number | null>(null)

  const selectedGroup = xpGroups.find((g) => g.id === selectedId) ?? null
  const selectedSpecies = selectedId != null ? speciesByXpGroup.get(selectedId) ?? [] : []
  const confirmingGroup = xpGroups.find((g) => g.id === confirmingDeleteId) ?? null
  const affectedSpeciesCount = confirmingDeleteId != null ? (speciesByXpGroup.get(confirmingDeleteId)?.length ?? 0) : 0

  const handleCreate = async () => {
    const nom = newName.trim()
    if (!nom) return
    const created = await createXpGroup(nom)
    setNewName('')
    if (created) setSelectedId(created.id)
  }

  const handleDelete = async (id: number) => {
    await deleteXpGroup(id)
    setConfirmingDeleteId(null)
    if (selectedId === id) setSelectedId(null)
  }

  return (
    <div className="flex flex-col md:flex-row gap-4 w-full items-start">
      <div className={`bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6 ${selectedGroup ? 'md:w-96 shrink-0' : ''}`}>
        <div className="flex items-center gap-2 mb-5">
          <span className="text-2xl">⚡</span>
          <h3 className="text-[#a3841a] text-lg font-bold">Groupes XP</h3>
        </div>
        <p className="text-ink-muted-2 text-xs mb-4">
          Indépendants des groupes d'œufs — créés ici à la main pour donner à certaines espèces un intervalle de tick et/ou un plafond XP à vie différents des valeurs par défaut de la Pension.
        </p>

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
                placeholder="Nom du nouveau groupe XP…"
                className="flex-1 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
              <button onClick={handleCreate} className={`px-4 py-2 rounded text-sm font-bold ${BUTTON_STYLE.green}`}>
                Créer
              </button>
            </div>

            <div className="flex flex-col gap-2">
              {xpGroups.length === 0 ? (
                <p className="text-ink-muted-2 text-sm">Aucun groupe XP pour l'instant.</p>
              ) : (
                xpGroups.map((g) => (
                  <div key={g.id} className={`flex items-center gap-2 px-3 py-2 rounded ${PIXEL_BORDER_SM} ${selectedId === g.id ? 'bg-yellow-100 ring-2 ring-[#a3841a]' : 'bg-cream-secondary'}`}>
                    <span className="flex-1 text-ink text-sm font-bold truncate">{g.nom}</span>
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

      {selectedGroup && (
        <div className="flex-1 min-w-0 bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
          <div className="flex flex-col gap-4">
            <div>
              <label className="text-ink-muted-2 text-sm block mb-1">Nom</label>
              <input
                key={selectedGroup.id}
                type="text"
                defaultValue={selectedGroup.nom}
                onBlur={(e) => {
                  const v = e.target.value.trim()
                  if (v && v !== selectedGroup.nom) updateXpGroup(selectedGroup.id, { nom: v })
                }}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>

            <div className="flex gap-3">
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Intervalle de tick</label>
                <NumberInput
                  min={0}
                  fallback={selectedGroup.tick_interval_amount}
                  value={selectedGroup.tick_interval_amount}
                  onCommit={(v) => updateXpGroup(selectedGroup.id, { tick_interval_amount: Math.max(0, v) })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Unité</label>
                <select
                  value={selectedGroup.tick_interval_unit}
                  onChange={(e) => updateXpGroup(selectedGroup.id, { tick_interval_unit: e.target.value as GiftTimerUnit })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                >
                  <option value="hours">Heures</option>
                  <option value="minutes">Minutes</option>
                </select>
              </div>
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Plafond XP à vie</label>
                <NumberInput
                  min={0}
                  fallback={selectedGroup.lifetime_xp_cap}
                  value={selectedGroup.lifetime_xp_cap}
                  onCommit={(v) => updateXpGroup(selectedGroup.id, { lifetime_xp_cap: Math.max(0, v) })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
            </div>

            <div>
              <p className="text-ink-muted-2 text-sm mb-2">Espèces assignées (sinon, valeurs par défaut de la Pension)</p>
              <div className="flex flex-wrap gap-1.5 mb-2">
                {selectedSpecies.length === 0 ? (
                  <p className="text-ink-muted-2 text-xs italic">Aucune espèce assignée.</p>
                ) : (
                  selectedSpecies.map((nom) => (
                    <span
                      key={nom}
                      className={`flex items-center gap-1.5 pl-2 pr-1 py-1 rounded-full text-xs ${PIXEL_BORDER_SM} bg-cream`}
                    >
                      {nom}
                      <button
                        onClick={() => unassignSpecies(nom)}
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
                onSelect={(p) => assignSpecies(p.nom, selectedGroup.id)}
                placeholder="Assigner une espèce…"
              />
            </div>
          </div>
        </div>
      )}

      {confirmingGroup && (
        <ConfirmPopup
          title={`Supprimer "${confirmingGroup.nom}" ?`}
          message={affectedSpeciesCount > 0 ? `${affectedSpeciesCount} espèce(s) assignée(s) reviendront aux valeurs par défaut de la Pension.` : undefined}
          confirmLabel="Supprimer"
          danger
          onConfirm={() => handleDelete(confirmingGroup.id)}
          onCancel={() => setConfirmingDeleteId(null)}
        />
      )}
    </div>
  )
}
