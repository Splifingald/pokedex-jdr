import type { Encounter, Pokemon } from '../types'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'

interface Props {
  row: Encounter
  pokemon: Pokemon | undefined
  onOpenComment: (row: Encounter) => void
}

export function EncounterRow({ row, pokemon, onOpenComment }: Props) {
  return (
    <div className="flex items-center gap-2 py-1 border-b border-[#cfc7a8] last:border-b-0">
      {pokemon?.image_miniature ? (
        <img
          src={pokemon.image_miniature}
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
          onClick={(e) => { e.stopPropagation(); onOpenComment(row) }}
          title="Voir le commentaire"
          className="shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-xs bg-cream-secondary border border-ink/40"
        >
          ℹ️
        </button>
      )}
    </div>
  )
}
