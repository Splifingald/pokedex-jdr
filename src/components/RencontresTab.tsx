import { useMemo, useState } from 'react'
import type { Attack, Pokemon, Encounter } from '../types'
import { useEncounters } from '../hooks/useEncounters'
import { EncounterRow } from './EncounterRow'
import { EncounterQuickPickBar } from './EncounterQuickPickBar'
import { EncounterSearchBar, type EncounterFilter } from './EncounterSearchBar'
import { PokemonDetailSheet } from './PokemonDetailSheet'
import { PixelIcon } from './icons/PixelIcon'
import { NAV_ICON } from '../lib/icons'
import { PANEL } from '../lib/panelStyles'
import { rollQuickPick, getQuickPickTopDe, getQuickPickHighlight } from '../lib/encounterQuickPick'

interface Props {
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  isAdmin: boolean
}

interface LieuGroup {
  lieu: string
  rows: Encounter[]
}

export function RencontresTab({ pokemonByName, attacksByName, isAdmin }: Props) {
  const { encounters, loading } = useEncounters()
  const [filter, setFilter] = useState<EncounterFilter | null>(null)
  const [quickPick, setQuickPick] = useState<number | null>(null)
  const [selectedPokemon, setSelectedPokemon] = useState<Pokemon | null>(null)

  const groups = useMemo<LieuGroup[]>(() => {
    const byLieu = new Map<string, Encounter[]>()
    for (const enc of encounters) {
      const list = byLieu.get(enc.lieu) ?? []
      list.push(enc)
      byLieu.set(enc.lieu, list)
    }
    return [...byLieu.entries()]
      .map(([lieu, rows]) => ({
        lieu,
        rows: [...rows].sort((a, b) => (a.de ?? Infinity) - (b.de ?? Infinity)),
      }))
      .sort((a, b) => a.lieu.localeCompare(b.lieu, 'fr'))
  }, [encounters])

  const lieux = useMemo(() => groups.map((g) => g.lieu), [groups])

  const pokemonNames = useMemo(
    () => [...new Set(encounters.map((e) => e.pokemon_nom))].sort((a, b) => a.localeCompare(b, 'fr')),
    [encounters]
  )

  const filteredGroups = useMemo<LieuGroup[]>(() => {
    if (!filter) return groups
    if (filter.type === 'lieu') return groups.filter((g) => g.lieu === filter.value)
    return groups
      .map((g) => ({ lieu: g.lieu, rows: g.rows.filter((r) => r.pokemon_nom === filter.value) }))
      .filter((g) => g.rows.length > 0)
  }, [groups, filter])

  const allRows = useMemo(() => filteredGroups.flatMap((g) => g.rows), [filteredGroups])

  const topDe = useMemo(
    () => (quickPick != null ? getQuickPickTopDe(allRows, quickPick) : null),
    [allRows, quickPick]
  )

  return (
    <div className="flex-1 flex flex-col overflow-hidden relative">
      <div className="flex-1 overflow-y-auto p-4">
        <EncounterSearchBar
          lieux={lieux}
          pokemonNames={pokemonNames}
          pokemonByName={pokemonByName}
          onFilterChange={setFilter}
        />

        <EncounterQuickPickBar
          pick={quickPick}
          onToggle={() => setQuickPick((p) => (p == null ? rollQuickPick() : null))}
        />

        {loading ? (
          <p className="text-[#7a7c9a] text-sm">Chargement…</p>
        ) : filteredGroups.length === 0 ? (
          <p className="text-[#7a7c9a] text-sm">{filter ? 'Aucun résultat.' : 'Aucune rencontre importée.'}</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {filteredGroups.map((group) => (
              <div key={group.lieu} className={`${PANEL} p-3`}>
                <div className="flex items-center gap-1.5 mb-2">
                  <PixelIcon src={NAV_ICON.rencontres!} size={16} colored className="text-ink" alt="" />
                  <h3 className="text-ink font-bold truncate">{group.lieu}</h3>
                </div>
                <table className="w-full border-collapse">
                  <tbody>
                    {group.rows.map((row) => (
                      <EncounterRow
                        key={row.id}
                        row={row}
                        pokemon={pokemonByName.get(row.pokemon_nom)}
                        highlight={getQuickPickHighlight(row, quickPick, topDe)}
                        onSelect={setSelectedPokemon}
                      />
                    ))}
                  </tbody>
                </table>
              </div>
            ))}
          </div>
        )}
      </div>

      {selectedPokemon && (
        <PokemonDetailSheet
          context="pokedex"
          pokemon={selectedPokemon}
          attacksByName={attacksByName}
          isAdmin={isAdmin}
          isDiscovered={true}
          onClose={() => setSelectedPokemon(null)}
        />
      )}
    </div>
  )
}
