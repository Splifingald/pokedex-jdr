import { useEffect, useMemo, useState } from 'react'
import type { Attack, Encounter, Pokemon } from '../types'
import { EncounterRow } from './EncounterRow'
import { EncounterQuickPickBar } from './EncounterQuickPickBar'
import { PokemonDetailSheet } from './PokemonDetailSheet'
import { PixelIcon } from './icons/PixelIcon'
import { NAV_ICON } from '../lib/icons'
import { PANEL_LG } from '../lib/panelStyles'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { rollQuickPick, getQuickPickTopDe, getQuickPickHighlight, scrollToEncounterRow } from '../lib/encounterQuickPick'

interface Props {
  lieu: string
  rows: Encounter[]
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  isAdmin: boolean
  onClose: () => void
}

export function EncounterTableModal({ lieu, rows, pokemonByName, attacksByName, isAdmin, onClose }: Props) {
  const [quickPick, setQuickPick] = useState<number | null>(null)
  const [selectedPokemon, setSelectedPokemon] = useState<Pokemon | null>(null)

  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onClose])

  const sorted = useMemo(
    () => [...rows].sort((a, b) => (a.de ?? Infinity) - (b.de ?? Infinity)),
    [rows]
  )

  const topDe = useMemo(
    () => (quickPick != null ? getQuickPickTopDe(sorted, quickPick) : null),
    [sorted, quickPick]
  )

  useEffect(() => {
    if (topDe == null) return
    const topRow = sorted.find((r) => r.de === topDe)
    if (topRow) scrollToEncounterRow(topRow.id)
  }, [sorted, topDe])

  return (
    <>
      <div
        className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
        onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
      >
        <div className={`${PANEL_LG} max-w-sm w-full max-h-[80vh] flex flex-col overflow-hidden`}>
          <div className="flex items-center gap-2 p-4 border-b-2 border-[#cfc7a8] shrink-0">
            <PixelIcon src={NAV_ICON.rencontres!} size={22} colored className="text-ink" alt="" />
            <h3 className="text-ink font-bold flex-1 truncate">{lieu}</h3>
            <button
              onClick={onClose}
              className={`w-7 h-7 shrink-0 rounded-md text-sm font-bold ${BUTTON_STYLE.gray}`}
            >
              ✕
            </button>
          </div>

          <div className="flex-1 overflow-y-auto p-4">
            <EncounterQuickPickBar
              pick={quickPick}
              onToggle={() => setQuickPick((p) => (p == null ? rollQuickPick() : null))}
            />
            <table className="w-full border-collapse">
              <tbody>
                {sorted.map((row) => (
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
        </div>
      </div>

      {selectedPokemon && (
        <PokemonDetailSheet
          context="pokedex"
          pokemon={selectedPokemon}
          attacksByName={attacksByName}
          isAdmin={isAdmin}
          isDiscovered={true}
          elevated
          onClose={() => setSelectedPokemon(null)}
        />
      )}
    </>
  )
}
