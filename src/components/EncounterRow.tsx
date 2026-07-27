import type { Encounter, Pokemon } from '../types'
import type { QuickPickHighlight } from '../lib/encounterQuickPick'

interface Props {
  row: Encounter
  pokemon: Pokemon | undefined
  highlight?: QuickPickHighlight
  onSelect: (pokemon: Pokemon) => void
}

export function EncounterRow({ row, pokemon, highlight = null, onSelect }: Props) {
  const bg = highlight === 'top' ? 'bg-[#f0c48f]' : highlight === 'match' ? 'bg-[#f6eec2]' : ''
  const clickable = !!pokemon

  return (
    <tr
      id={`encounter-row-${row.id}`}
      onClick={() => pokemon && onSelect(pokemon)}
      className={`${bg} border-b border-[#cfc7a8] last:border-b-0 ${clickable ? 'cursor-pointer hover:brightness-95' : ''}`}
    >
      <td className="py-1 pr-2 w-12">
        {pokemon?.image_miniature ? (
          <img
            src={pokemon.image_miniature}
            alt={row.pokemon_nom}
            className="pixelated w-[47px] h-[47px] object-contain"
          />
        ) : (
          <span className="w-[47px] h-[47px] rounded border border-ink/30 flex items-center justify-center text-ink-muted-2 text-xs">
            ?
          </span>
        )}
      </td>
      <td className="py-1 pr-2">
        <div className={`text-ink text-sm truncate ${highlight === 'top' ? 'font-bold' : ''}`}>{row.pokemon_nom}</div>
        {row.commentaire && (
          <div className="text-ink-muted-2 text-[10px] truncate">{row.commentaire}</div>
        )}
      </td>
      <td className="py-1 pl-1 pr-2 text-right text-ink-muted text-sm font-bold w-8">{row.de ?? '—'}</td>
    </tr>
  )
}
