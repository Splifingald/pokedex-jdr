import { useMemo, useState } from 'react'
import type { Pokemon, Encounter } from '../types'
import { useEncounters } from '../hooks/useEncounters'
import { PANEL, PIXEL_BORDER_SM } from '../lib/panelStyles'
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

  return (
    <div className="flex-1 flex flex-col overflow-hidden relative">
      <div className="flex-1 overflow-y-auto p-4" onClick={() => setOpenComment(null)}>
        {loading ? (
          <p className="text-[#7a7c9a] text-sm">Chargement…</p>
        ) : groups.length === 0 ? (
          <p className="text-[#7a7c9a] text-sm">Aucune rencontre importée.</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {groups.map((group) => (
              <div key={group.lieu} className={`${PANEL} p-3`}>
                <h3 className="text-ink font-bold mb-2">{group.lieu}</h3>
                <div className="flex flex-col gap-1.5">
                  {group.rows.map((row) => {
                    const poke = pokemonByName.get(row.pokemon_nom)
                    return (
                      <div key={row.id} className="flex items-center gap-2 py-1 border-b border-[#cfc7a8] last:border-b-0">
                        {poke?.image_miniature ? (
                          <img
                            src={poke.image_miniature}
                            alt={row.pokemon_nom}
                            className="pixelated w-6 h-6 object-contain shrink-0"
                          />
                        ) : (
                          <span className="w-6 h-6 shrink-0 rounded border border-ink/30 flex items-center justify-center text-ink-muted-2 text-[10px]">
                            ?
                          </span>
                        )}
                        <span className="flex-1 text-ink text-sm truncate">{row.pokemon_nom}</span>
                        {row.de != null && (
                          <span className={`shrink-0 text-xs px-1.5 py-0.5 rounded ${PIXEL_BORDER_SM} bg-cream-secondary text-ink-muted`}>
                            🎲 {row.de}+
                          </span>
                        )}
                        {row.commentaire && (
                          <button
                            onClick={(e) => { e.stopPropagation(); setOpenComment(row) }}
                            title="Voir le commentaire"
                            className="shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-xs bg-cream-secondary border border-ink/40"
                          >
                            ℹ️
                          </button>
                        )}
                      </div>
                    )
                  })}
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
