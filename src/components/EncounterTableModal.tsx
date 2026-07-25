import { useEffect, useMemo, useState } from 'react'
import type { Encounter, Pokemon } from '../types'
import { EncounterRow } from './EncounterRow'
import { PANEL_LG } from '../lib/panelStyles'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  lieu: string
  rows: Encounter[]
  pokemonByName: Map<string, Pokemon>
  onClose: () => void
}

export function EncounterTableModal({ lieu, rows, pokemonByName, onClose }: Props) {
  const [openComment, setOpenComment] = useState<Encounter | null>(null)

  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onClose])

  const sorted = useMemo(
    () => [...rows].sort((a, b) => (a.de ?? Infinity) - (b.de ?? Infinity)),
    [rows]
  )

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className={`${PANEL_LG} max-w-sm w-full max-h-[80vh] flex flex-col overflow-hidden`}>
        <div className="flex items-center gap-2 p-4 border-b-2 border-[#cfc7a8] shrink-0">
          <span className="text-xl">🎲</span>
          <h3 className="text-ink font-bold flex-1 truncate">{lieu}</h3>
          <button
            onClick={onClose}
            className={`w-7 h-7 shrink-0 rounded-md text-sm font-bold ${BUTTON_STYLE.gray}`}
          >
            ✕
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-4" onClick={() => setOpenComment(null)}>
          <div className="flex flex-col gap-1.5">
            {sorted.map((row) => (
              <EncounterRow
                key={row.id}
                row={row}
                pokemon={pokemonByName.get(row.pokemon_nom)}
                onOpenComment={setOpenComment}
              />
            ))}
          </div>
        </div>

        {openComment && (
          <div className="shrink-0 bg-cream-secondary border-t-2 border-[#cfc7a8] p-3 max-h-[35%] overflow-y-auto">
            <div className="flex items-center gap-2 mb-1">
              <span className="text-ink text-sm font-bold flex-1 truncate">{openComment.pokemon_nom}</span>
              <button
                onClick={() => setOpenComment(null)}
                className={`w-6 h-6 shrink-0 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}
              >
                ✕
              </button>
            </div>
            <p className="text-ink-muted text-sm whitespace-pre-wrap">{openComment.commentaire}</p>
          </div>
        )}
      </div>
    </div>
  )
}
