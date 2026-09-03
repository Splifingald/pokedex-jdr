import type { BoardPing } from '../../hooks/useOnlinePings'
import type { BoardGrid } from '../../lib/onlineBoard'

interface Props {
  pings: BoardPing[]
  grid: BoardGrid
}

// Pings de case : une onde circulaire part de la case et s'étend un peu
// au-delà, à la couleur de qui a pointé, avec son nom au centre. Remplace le
// curseur diffusé en continu — même intention (« regardez ça »), pour une
// poignée de messages au lieu d'un flux.
// Le calque ne capte aucun clic : il se superpose au plateau sans le bloquer.
export function BattlePingLayer({ pings, grid }: Props) {
  return (
    <div className="absolute inset-0 pointer-events-none overflow-hidden z-30">
      {pings.map((p) => (
        <div
          // La clé inclut l'instant de départ : re-pinger doit produire un
          // élément neuf, sinon React réutiliserait le nœud et l'animation ne
          // repartirait pas de zéro.
          key={`${p.cid}:${p.startedAt}`}
          className="absolute flex items-center justify-center animate-[ping-fade-out_1s_ease-out_2s_forwards]"
          style={{
            left: `${p.col * grid.cellW * 100}%`,
            top: `${(grid.offsetY + p.row * grid.cellH) * 100}%`,
            width: `${grid.cellW * 100}%`,
            height: `${grid.cellH * 100}%`,
          }}
        >
          {/* Teinte de la case, pour qu'elle reste repérable entre deux ondes */}
          <div
            className="absolute inset-0 rounded-[3px] animate-[ping-tile_1s_ease-out_infinite_alternate]"
            style={{ backgroundColor: p.color }}
          />

          {/* Deux ondes décalées : le décalage donne le mouvement continu */}
          <div
            className="absolute inset-0 rounded-full border-[3px] animate-[ping-ripple_1.4s_ease-out_infinite]"
            style={{ borderColor: p.color }}
          />
          <div
            className="absolute inset-0 rounded-full border-[3px] animate-[ping-ripple_1.4s_ease-out_infinite]"
            style={{ borderColor: p.color, animationDelay: '0.45s' }}
          />

          <span
            className="relative px-1.5 py-0.5 rounded border-2 border-ink text-ink text-xs font-bold whitespace-nowrap shadow-[var(--shadow-pixel-sm)]"
            style={{ backgroundColor: p.color }}
          >
            {p.name}
          </span>
        </div>
      ))}
    </div>
  )
}
