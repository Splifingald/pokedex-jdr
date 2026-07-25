import { useMemo, useState } from 'react'
import type { Pokemon, Encounter } from '../types'
import { useEncounters } from '../hooks/useEncounters'
import { EncounterRow } from './EncounterRow'
import { EncounterSearchBar, type EncounterFilter } from './EncounterSearchBar'
import { PANEL } from '../lib/panelStyles'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  pokemonByName: Map<string, Pokemon>
}

interface LieuGroup {
  lieu: string
  rows: Encounter[]
}

export function RencontresTab({ pokemonByName }: Props) {
  const { encounters, loading } = useEncounters()
  const [openComment, setOpenComment] = useState<Encounter | null>(null)
  const [filter, setFilter] = useState<EncounterFilter | null>(null)

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

  return (
    <div className="flex-1 flex flex-col overflow-hidden relative">
      <div className="flex-1 overflow-y-auto p-4" onClick={() => setOpenComment(null)}>
        <EncounterSearchBar
          lieux={lieux}
          pokemonNames={pokemonNames}
          pokemonByName={pokemonByName}
          onFilterChange={setFilter}
        />

        {loading ? (
          <p className="text-[#7a7c9a] text-sm">Chargement…</p>
        ) : filteredGroups.length === 0 ? (
          <p className="text-[#7a7c9a] text-sm">{filter ? 'Aucun résultat.' : 'Aucune rencontre importée.'}</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {filteredGroups.map((group) => (
              <div key={group.lieu} className={`${PANEL} p-3`}>
                <h3 className="text-ink font-bold mb-2">{group.lieu}</h3>
                <div className="flex flex-col gap-1.5">
                  {group.rows.map((row) => (
                    <EncounterRow
                      key={row.id}
                      row={row}
                      pokemon={pokemonByName.get(row.pokemon_nom)}
                      onOpenComment={setOpenComment}
                    />
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {openComment && (
        <div className="shrink-0 bg-cream border-t-4 border-ink rounded-t-2xl p-4 max-h-[45%] overflow-y-auto animate-[sheet-pop_0.25s_ease-out]">
          <div className="flex items-center gap-2 mb-2">
            <h3 className="text-ink font-bold flex-1 truncate">{openComment.pokemon_nom} — {openComment.lieu}</h3>
            <button
              onClick={() => setOpenComment(null)}
              className={`w-7 h-7 shrink-0 rounded-md text-sm font-bold ${BUTTON_STYLE.gray}`}
            >
              ✕
            </button>
          </div>
          <p className="text-ink-muted text-sm whitespace-pre-wrap">{openComment.commentaire}</p>
        </div>
      )}
    </div>
  )
}
