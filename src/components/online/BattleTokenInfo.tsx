import type { ResolvedToken } from '../../lib/onlineTokens'
import type { BoardGrid } from '../../lib/onlineBoard'
import { cellCenter } from '../../lib/onlineBoard'
import { HpGauge } from '../HpGauge'

interface Props {
  resolved: ResolvedToken
  grid: BoardGrid
  showHp: boolean
  showOwner: boolean
}

// PV au-dessus du jeton, dresseur en dessous.
//
// Dessiné dans un calque séparé, PAR-DESSUS tous les jetons, et non à
// l'intérieur du jeton : celui-ci porte un z-index, donc il forme un contexte
// d'empilement dont ses enfants ne peuvent pas sortir — le sprite d'un jeton
// voisin passait devant les PV et le nom du dresseur d'un autre.
export function BattleTokenInfo({ resolved, grid, showHp, showOwner }: Props) {
  const { token, owner, ownerName, hp, maxHp } = resolved
  if (!showHp && !showOwner) return null

  const cellSize = `${(100 / grid.cols).toFixed(4)}cqw`
  const center = cellCenter(grid, token.cell_col, token.cell_row)

  return (
    <div
      className="absolute -translate-x-1/2 -translate-y-1/2 flex items-center justify-center pointer-events-none"
      style={{
        left: `${center.left * 100}%`,
        top: `${center.top * 100}%`,
        width: cellSize,
        height: cellSize,
      }}
    >
      {showHp && (
        <div className="absolute left-1/2 -translate-x-1/2 bottom-full mb-0.5 w-[150%]">
          <div className="bg-cream/90 border-2 border-ink rounded-[var(--radius-pixel-sm)] px-1 py-0.5">
            <HpGauge current={hp} max={maxHp} showValue compact barBorderClassName="border border-ink" />
          </div>
        </div>
      )}

      {showOwner && (
        <div className="absolute left-1/2 -translate-x-1/2 top-full mt-0.5">
          <div className="flex items-center gap-1 bg-cream/90 border-2 border-ink rounded-[var(--radius-pixel-sm)] pl-0.5 pr-1.5 py-0.5">
            <span
              className="w-4 h-4 shrink-0 rounded-full overflow-hidden border border-ink"
              style={{ backgroundColor: owner?.color }}
            >
              {owner?.image_url && (
                <img src={owner.image_url} alt="" draggable={false} className="w-full h-full object-cover" />
              )}
            </span>
            <span className="text-ink text-[0.6rem] leading-none font-bold whitespace-nowrap">{ownerName}</span>
          </div>
        </div>
      )}
    </div>
  )
}
