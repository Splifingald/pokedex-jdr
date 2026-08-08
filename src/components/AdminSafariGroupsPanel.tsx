import { useState } from 'react'
import type { SafariGaugeArea, SafariGroupPokemon, Pokemon } from '../types'
import { useSafariGroups } from '../hooks/useSafariGroups'
import { useSafariConfig } from '../hooks/useSafariConfig'
import { usePokemon } from '../hooks/usePokemon'
import { validateGaugeAreas, computeBestAreaCaptureStats } from '../lib/safari'
import { NumberInput } from './NumberInput'
import { PokemonSearchInput } from './PokemonSearchInput'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { CloseIcon } from './icons/CloseIcon'

function GroupPokemonEditor({
  entries, pokemon, onAdd, onUpdateWeight, onRemove,
}: {
  entries: SafariGroupPokemon[]
  pokemon: Pokemon[]
  onAdd: (pokemonNom: string) => void
  onUpdateWeight: (id: number, weight: number) => void
  onRemove: (id: number) => void
}) {
  return (
    <>
      <div className="flex flex-col gap-1.5 mb-2">
        {entries.length === 0 ? (
          <p className="text-ink-muted-2 text-xs italic">Aucun pokémon dans ce groupe — il ne pourra jamais être tiré.</p>
        ) : (
          entries.map((row) => {
            const species = pokemon.find((p) => p.nom === row.pokemon_nom)
            return (
              <div key={row.id} className="flex items-center gap-2">
                <div className="w-6 h-6 shrink-0 flex items-center justify-center">
                  {species?.image_miniature ? (
                    <img src={species.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
                  ) : (
                    <span className="text-lg">🦁</span>
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
      <PokemonSearchInput options={pokemon} onSelect={(p) => onAdd(p.nom)} placeholder="Ajouter un pokémon…" />
    </>
  )
}

function GaugeAreaEditor({
  areas, onAdd, onUpdate, onRemove,
}: {
  areas: SafariGaugeArea[]
  onAdd: () => void
  onUpdate: (id: number, patch: Partial<Omit<SafariGaugeArea, 'id' | 'group_id' | 'created_at'>>) => void
  onRemove: (id: number) => void
}) {
  const sorted = [...areas].sort((a, b) => a.min_value - b.min_value)
  const errors = validateGaugeAreas(areas)

  return (
    <>
      <div className="flex flex-col gap-1.5 mb-2">
        {sorted.map((area) => (
          <div key={area.id} className="flex items-center gap-2">
            <input
              type="color"
              value={area.color}
              onChange={(e) => onUpdate(area.id, { color: e.target.value })}
              className="w-8 h-8 shrink-0 rounded border-2 border-ink"
            />
            <NumberInput
              min={0}
              fallback={area.min_value}
              value={area.min_value}
              onCommit={(v) => onUpdate(area.id, { min_value: Math.min(100, Math.max(0, v)) })}
              className="w-16 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
            />
            <span className="text-ink-muted-2 text-xs">→</span>
            <NumberInput
              min={0}
              fallback={area.max_value}
              value={area.max_value}
              onCommit={(v) => onUpdate(area.id, { max_value: Math.min(100, Math.max(0, v)) })}
              className="w-16 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
            />
            <span className="text-ink-muted-2 text-xs">Capture</span>
            <NumberInput
              min={0}
              fallback={area.catch_rate_pct}
              value={area.catch_rate_pct}
              onCommit={(v) => onUpdate(area.id, { catch_rate_pct: v })}
              className="w-16 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
            />
            <span className="text-ink-muted-2 text-xs">%</span>
            <button onClick={() => onRemove(area.id)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
              <CloseIcon className="w-3 h-3" />
            </button>
          </div>
        ))}
      </div>
      <button onClick={onAdd} className={`text-xs px-3 py-1.5 rounded font-bold ${BUTTON_STYLE.gray}`}>+ Ajouter une zone</button>
      {errors.length > 0 && (
        <div className="mt-2 bg-red-50 border-2 border-red-300 rounded p-2">
          {errors.map((e, i) => (
            <p key={i} className="text-red-700 text-xs">⚠ {e}</p>
          ))}
        </div>
      )}
    </>
  )
}

// Statistiques calculées (baies infinies) — voir
// src/lib/safari.ts::computeBestAreaCaptureStats pour le détail du calcul.
// Trois indicateurs : la chance d'atteindre un jour la meilleure zone, la
// capture qui en découle si le joueur "mise tout" sur cette zone (risque
// maximal, quitte à la dépasser et ne plus jamais pouvoir capturer), et la
// capture sous la politique OPTIMALE qui accepte de capturer dans une zone
// moins bonne mais plus sûre plutôt que de risquer de dépasser la meilleure
// (risque minimal — toujours ≥ au risque maximal).
function CaptureStatsInfo({
  areas, berryMinIncrease, berryMaxIncrease,
}: {
  areas: SafariGaugeArea[]
  berryMinIncrease: number
  berryMaxIncrease: number
}) {
  const errors = validateGaugeAreas(areas)
  if (errors.length > 0) return null
  const stats = computeBestAreaCaptureStats(areas, berryMinIncrease, berryMaxIncrease)
  if (!stats) return null

  return (
    <div className="border-t-2 border-[#cfc7a8] pt-3 mt-3">
      <p className="text-ink-muted-2 text-sm mb-2">
        Statistiques (baies infinies) — meilleure zone : <span className="font-bold" style={{ color: stats.bestArea.color }}>{stats.bestArea.catch_rate_pct}%</span> ({stats.bestArea.min_value}-{stats.bestArea.max_value})
      </p>
      <div className="flex gap-4">
        <div className="flex-1 bg-cream-secondary border-2 border-ink rounded p-2 text-center">
          <p className="text-ink-muted-2 text-xs">Chance d'atteindre la meilleure zone</p>
          <p className="text-ink text-lg font-black">{(stats.probReachBest * 100).toFixed(1)}%</p>
        </div>
        <div className="flex-1 bg-cream-secondary border-2 border-ink rounded p-2 text-center">
          <p className="text-ink-muted-2 text-xs">Capture en visant la meilleure zone (risque max)</p>
          <p className="text-ink text-lg font-black">{(stats.captureProbabilityMaxRisk * 100).toFixed(1)}%</p>
        </div>
        <div className="flex-1 bg-cream-secondary border-2 border-ink rounded p-2 text-center">
          <p className="text-ink-muted-2 text-xs">Capture en jouant la sécurité (risque min)</p>
          <p className="text-ink text-lg font-black">{(stats.captureProbabilityMinRisk * 100).toFixed(1)}%</p>
        </div>
      </div>
    </div>
  )
}

export function AdminSafariGroupsPanel() {
  const {
    groups, pokemonByGroup, areasByGroup, loading,
    addGroup, updateGroup, deleteGroup,
    addGroupPokemon, updateGroupPokemonWeight, removeGroupPokemon,
    addGaugeArea, updateGaugeArea, removeGaugeArea,
  } = useSafariGroups()
  const { config } = useSafariConfig()
  const { pokemon } = usePokemon()
  const [selected, setSelected] = useState<number | null>(null)
  const [newGroupName, setNewGroupName] = useState('')

  if (loading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  const selectedGroup = groups.find((g) => g.id === selected) ?? null
  const selectedPokemon = selected ? pokemonByGroup.get(selected) ?? [] : []
  const selectedAreas = selected ? areasByGroup.get(selected) ?? [] : []

  return (
    <div className="flex flex-col md:flex-row gap-4 w-full items-start">
      <div className={`bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6 ${selected ? 'md:w-80 shrink-0' : ''}`}>
        <div className="flex items-center gap-2 mb-5">
          <span className="text-2xl">🧭</span>
          <h3 className="text-[#a3841a] text-lg font-bold">Groupes de pokémon</h3>
        </div>

        <div className="flex gap-2 mb-4">
          <input
            type="text"
            value={newGroupName}
            onChange={(e) => setNewGroupName(e.target.value)}
            placeholder="Nouveau groupe…"
            className="flex-1 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
          <button
            onClick={() => { if (newGroupName.trim()) { addGroup(newGroupName.trim()); setNewGroupName('') } }}
            className={`px-3 py-2 rounded text-sm font-bold ${BUTTON_STYLE.yellow}`}
          >
            + Créer
          </button>
        </div>

        {groups.length === 0 ? (
          <p className="text-ink-muted-2 text-sm">Aucun groupe pour l'instant.</p>
        ) : (
          <div className="flex flex-col gap-2">
            {groups.map((g) => (
              <div key={g.id} className="flex items-center gap-2">
                <button
                  onClick={() => setSelected(selected === g.id ? null : g.id)}
                  className={`flex-1 text-left px-3 py-2 rounded text-sm font-bold ${PIXEL_BORDER_SM} ${selected === g.id ? 'bg-yellow-100 ring-2 ring-[#a3841a]' : 'bg-cream-secondary'}`}
                >
                  {g.nom}
                </button>
                <button onClick={() => deleteGroup(g.id)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
                  <CloseIcon className="w-3 h-3" />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {selectedGroup && (
        <div className="flex-1 min-w-0 bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
          <div className="flex items-center gap-3 mb-4">
            <h4 className="text-ink text-base font-bold flex-1">{selectedGroup.nom}</h4>
            <label className="text-ink-muted-2 text-sm">Poids de tirage</label>
            <NumberInput
              min={0}
              fallback={selectedGroup.weight}
              value={selectedGroup.weight}
              onCommit={(v) => updateGroup(selectedGroup.id, { weight: Math.max(0, v) })}
              className="w-16 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
            />
          </div>

          <div className="flex flex-col gap-4">
            <div>
              <p className="text-ink-muted-2 text-sm mb-2">Pokémon du groupe</p>
              <GroupPokemonEditor
                entries={selectedPokemon}
                pokemon={pokemon}
                onAdd={(nom) => addGroupPokemon(selectedGroup.id, nom)}
                onUpdateWeight={updateGroupPokemonWeight}
                onRemove={removeGroupPokemon}
              />
            </div>

            <div className="border-t-2 border-[#cfc7a8] pt-3">
              <p className="text-ink-muted-2 text-sm mb-2">Zones de la jauge de capture (0-100)</p>
              <GaugeAreaEditor
                areas={selectedAreas}
                onAdd={() => addGaugeArea(selectedGroup.id, { min_value: 0, max_value: 100, color: '#f5a623', catch_rate_pct: 20, sort_order: selectedAreas.length })}
                onUpdate={updateGaugeArea}
                onRemove={removeGaugeArea}
              />
            </div>

            <CaptureStatsInfo
              areas={selectedAreas}
              berryMinIncrease={config.berry_min_increase}
              berryMaxIncrease={config.berry_max_increase}
            />
          </div>
        </div>
      )}
    </div>
  )
}
