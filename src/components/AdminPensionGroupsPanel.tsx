import { useState } from 'react'
import type { GiftTimerUnit, PensionEggPoolMode, PensionEggPoolEntry, Pokemon } from '../types'
import { usePensionGroups } from '../hooks/usePensionGroups'
import { usePensionConfig } from '../hooks/usePensionConfig'
import { usePokemon } from '../hooks/usePokemon'
import { DEFAULT_EGG_POOL_GROUP } from '../lib/pension'
import { NumberInput } from './NumberInput'
import { PokemonSearchInput } from './PokemonSearchInput'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { CloseIcon } from './icons/CloseIcon'

// Ligne "valeur personnalisée pour ce groupe, sinon hérite du réglage global" —
// même esprit que les colonnes nullable de pension_group_config (tick_interval_*,
// lifetime_xp_cap, hatch_timer_*).
function OverrideNumberField({
  label, value, fallback, onCommit, onClear,
}: {
  label: string
  value: number | null
  fallback: number
  onCommit: (v: number) => void
  onClear: () => void
}) {
  const active = value != null
  return (
    <div className="flex-1">
      <label className="flex items-center gap-1.5 text-ink-muted-2 text-sm mb-1">
        <input
          type="checkbox"
          checked={active}
          onChange={(e) => (e.target.checked ? onCommit(fallback) : onClear())}
          className="w-3.5 h-3.5"
        />
        {label}
      </label>
      <NumberInput
        min={0}
        fallback={fallback}
        value={value ?? fallback}
        onCommit={onCommit}
        className={`w-full bg-white border-2 border-ink rounded px-3 py-2 text-sm outline-none ${active ? 'text-ink' : 'text-ink-muted-2'}`}
      />
    </div>
  )
}

// Liste éditable d'espèces œuf + poids, réutilisée pour la réserve par défaut
// et pour la réserve personnalisée d'un groupe.
function EggPoolEditor({
  pool, pokemon, onAdd, onUpdateWeight, onRemove,
}: {
  pool: PensionEggPoolEntry[]
  pokemon: Pokemon[]
  onAdd: (pokemonNom: string) => void
  onUpdateWeight: (id: number, weight: number) => void
  onRemove: (id: number) => void
}) {
  return (
    <>
      <div className="flex flex-col gap-1.5 mb-2">
        {pool.length === 0 ? (
          <p className="text-ink-muted-2 text-xs italic">Aucune espèce œuf — les paires concernées se recycleront sans jamais produire d'œuf.</p>
        ) : (
          pool.map((row) => {
            const species = pokemon.find((p) => p.nom === row.pokemon_nom)
            return (
              <div key={row.id} className="flex items-center gap-2">
                <div className="w-6 h-6 shrink-0 flex items-center justify-center">
                  {species?.image_miniature ? (
                    <img src={species.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
                  ) : (
                    <span className="text-lg">🥚</span>
                  )}
                </div>
                <span className="flex-1 text-ink text-sm truncate">{row.pokemon_nom}</span>
                <span className="text-ink-muted-2 text-xs">Poids</span>
                <NumberInput
                  min={1}
                  fallback={1}
                  value={row.weight}
                  onCommit={(v) => onUpdateWeight(row.id, Math.max(1, v))}
                  className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
                />
                <button onClick={() => onRemove(row.id)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
                  <CloseIcon className="w-3 h-3" />
                </button>
              </div>
            )
          })
        )}
      </div>
      <PokemonSearchInput options={pokemon} onSelect={(p) => onAdd(p.nom)} placeholder="Ajouter une espèce œuf…" />
    </>
  )
}

const EGG_POOL_MODE_LABELS: Record<PensionEggPoolMode, string> = {
  default: 'Réserve par défaut',
  custom: 'Réserve personnalisée',
  none: 'Aucun œuf',
}

export function AdminPensionGroupsPanel() {
  const { groups, groupConfigByGroup, eggPoolByGroup, loading, updateGroupConfig, addEggPoolEntry, updateEggPoolWeight, removeEggPoolEntry } = usePensionGroups()
  const { config: pensionConfig } = usePensionConfig()
  const { pokemon } = usePokemon()
  const [selected, setSelected] = useState<string | null>(null)

  if (loading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  const selectedConfig = selected ? groupConfigByGroup.get(selected) : undefined
  const selectedPool = selected ? eggPoolByGroup.get(selected) ?? [] : []
  const defaultPool = eggPoolByGroup.get(DEFAULT_EGG_POOL_GROUP) ?? []
  const selectedMode: PensionEggPoolMode = selectedConfig?.egg_pool_mode ?? 'default'

  return (
    <div className="flex flex-col gap-4 w-full">
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <div className="flex items-center gap-2 mb-2">
          <span className="text-2xl">🥚</span>
          <h3 className="text-[#a3841a] text-lg font-bold">Réserve d'œufs par défaut</h3>
        </div>
        <p className="text-ink-muted-2 text-xs mb-3">Utilisée par tout groupe laissé en mode « Réserve par défaut » ci-dessous.</p>
        <EggPoolEditor
          pool={defaultPool}
          pokemon={pokemon}
          onAdd={(nom) => addEggPoolEntry(DEFAULT_EGG_POOL_GROUP, nom, 1)}
          onUpdateWeight={updateEggPoolWeight}
          onRemove={removeEggPoolEntry}
        />
      </div>

      <div className="flex flex-col md:flex-row gap-4 w-full items-start">
        <div className={`bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6 ${selected ? 'md:w-80 shrink-0' : ''}`}>
          <div className="flex items-center gap-2 mb-5">
            <span className="text-2xl">🧬</span>
            <h3 className="text-[#a3841a] text-lg font-bold">Groupes d'œufs</h3>
          </div>
          {groups.length === 0 ? (
            <p className="text-ink-muted-2 text-sm">Aucun groupe importé pour l'instant (CSV Pokémon / Groupe 1 / Groupe 2 / Groupe 3).</p>
          ) : (
            <div className="flex flex-col gap-2">
              {groups.map((g) => (
                <button
                  key={g}
                  onClick={() => setSelected(selected === g ? null : g)}
                  className={`text-left px-3 py-2 rounded text-sm font-bold ${PIXEL_BORDER_SM} ${selected === g ? 'bg-yellow-100 ring-2 ring-[#a3841a]' : 'bg-cream-secondary'}`}
                >
                  {g}
                </button>
              ))}
            </div>
          )}
        </div>

        {selected && (
          <div className="flex-1 min-w-0 bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
            <h4 className="text-ink text-base font-bold mb-4">{selected}</h4>

            <div className="flex flex-col gap-4">
              <div>
                <p className="text-ink-muted-2 text-xs mb-2">Éclosion — fourchette personnalisée</p>
                <div className="flex gap-3">
                  <OverrideNumberField
                    label="Minimum"
                    value={selectedConfig?.hatch_timer_min ?? null}
                    fallback={pensionConfig.default_hatch_timer_min}
                    onCommit={(v) => updateGroupConfig(selected, { hatch_timer_min: v, hatch_timer_unit: selectedConfig?.hatch_timer_unit ?? pensionConfig.default_hatch_timer_unit })}
                    onClear={() => updateGroupConfig(selected, { hatch_timer_min: null, hatch_timer_max: null, hatch_timer_unit: null })}
                  />
                  <OverrideNumberField
                    label="Maximum"
                    value={selectedConfig?.hatch_timer_max ?? null}
                    fallback={pensionConfig.default_hatch_timer_max}
                    onCommit={(v) => updateGroupConfig(selected, { hatch_timer_max: v, hatch_timer_unit: selectedConfig?.hatch_timer_unit ?? pensionConfig.default_hatch_timer_unit })}
                    onClear={() => updateGroupConfig(selected, { hatch_timer_min: null, hatch_timer_max: null, hatch_timer_unit: null })}
                  />
                  <div className="w-32 shrink-0">
                    <label className="text-ink-muted-2 text-sm block mb-1">Unité</label>
                    <select
                      value={selectedConfig?.hatch_timer_unit ?? pensionConfig.default_hatch_timer_unit}
                      disabled={selectedConfig?.hatch_timer_min == null}
                      onChange={(e) => updateGroupConfig(selected, { hatch_timer_unit: e.target.value as GiftTimerUnit })}
                      className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none disabled:opacity-50"
                    >
                      <option value="hours">Heures</option>
                      <option value="minutes">Minutes</option>
                    </select>
                  </div>
                </div>
              </div>

              <div className="border-t-2 border-[#cfc7a8] pt-3">
                <p className="text-ink-muted-2 text-sm mb-2">Œufs possibles</p>
                <div className="flex gap-2 mb-3">
                  {(Object.keys(EGG_POOL_MODE_LABELS) as PensionEggPoolMode[]).map((mode) => (
                    <button
                      key={mode}
                      onClick={() => updateGroupConfig(selected, { egg_pool_mode: mode })}
                      className={`flex-1 px-2 py-1.5 rounded text-xs font-bold ${selectedMode === mode ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
                    >
                      {EGG_POOL_MODE_LABELS[mode]}
                    </button>
                  ))}
                </div>

                {selectedMode === 'none' && (
                  <p className="text-ink-muted-2 text-xs italic">Ce groupe ne produit jamais d'œuf, quelle que soit la réserve par défaut.</p>
                )}

                {selectedMode === 'default' && (
                  defaultPool.length === 0 ? (
                    <p className="text-ink-muted-2 text-xs italic">La réserve par défaut est vide pour l'instant (à éditer en haut de cette page) — ce groupe ne produira donc pas d'œuf tant qu'elle l'est.</p>
                  ) : (
                    <div className="flex flex-col gap-1">
                      {defaultPool.map((row) => (
                        <span key={row.id} className="text-ink-muted-2 text-xs">🥚 {row.pokemon_nom} (poids {row.weight})</span>
                      ))}
                    </div>
                  )
                )}

                {selectedMode === 'custom' && (
                  <EggPoolEditor
                    pool={selectedPool}
                    pokemon={pokemon}
                    onAdd={(nom) => addEggPoolEntry(selected, nom, 1)}
                    onUpdateWeight={updateEggPoolWeight}
                    onRemove={removeEggPoolEntry}
                  />
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
