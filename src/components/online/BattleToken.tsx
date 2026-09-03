import type { PointerEvent as ReactPointerEvent } from 'react'
import type { ResolvedToken } from '../../lib/onlineTokens'
import type { BoardGrid } from '../../lib/onlineBoard'
import { cellCenter } from '../../lib/onlineBoard'
import { getStatusInfo } from '../../lib/status'
import { STATUS_ICON } from '../../lib/icons'

interface Props {
  resolved: ResolvedToken
  grid: BoardGrid
  selected: boolean
  interactive: boolean
  /** Position pendant un glissé, en fractions 0..1 du plateau ; null = sur sa case. */
  dragPoint: { x: number; y: number } | null
  onPointerDown?: (e: ReactPointerEvent<HTMLDivElement>) => void
  /** Le survol est remonté au plateau : les PV et le dresseur sont dessinés
   *  dans un calque au-dessus de TOUS les jetons (voir BattleTokenInfo), donc
   *  hors de ce composant. */
  onHoverChange: (hovered: boolean) => void
}

// Jeton du plateau : le sprite du Pokémon posé sur un simple disque noir
// translucide, qui le détache du décor sans le masquer. Le sprite déborde
// volontairement du disque — il reste lisible même sur une petite case.
//
// Tailles et positions en unités de conteneur (cqw) et en pourcentages : le
// jeton suit donc le zoom et tombe au même endroit de l'illustration sur tous
// les écrans.
export function BattleToken({
  resolved, grid, selected, interactive, dragPoint, onPointerDown, onHoverChange,
}: Props) {
  const { token, species, displayName, status, isKo } = resolved

  const statusInfo = getStatusInfo(status)
  const hasStatus = status !== 'aucun'
  // K.O. prime sur le statut dans la pastille (information la plus critique),
  // même convention que PokemonOwnedCard.
  const badgeSrc = isKo ? STATUS_ICON.ko : statusInfo.iconSrc
  const showBadge = isKo || hasStatus

  // La case est carrée : une seule mesure suffit.
  const cellSize = `${(100 / grid.cols).toFixed(4)}cqw`
  const center = cellCenter(grid, token.cell_col, token.cell_row)
  const position = dragPoint
    ? { left: `${dragPoint.x * 100}%`, top: `${dragPoint.y * 100}%` }
    : { left: `${center.left * 100}%`, top: `${center.top * 100}%` }

  return (
    <div
      className={`absolute -translate-x-1/2 -translate-y-1/2 flex items-center justify-center ${dragPoint ? 'z-20 pointer-events-none' : 'z-10'} ${interactive ? 'pointer-events-auto' : 'pointer-events-none'}`}
      style={{ ...position, width: cellSize, height: cellSize }}
      onPointerDown={onPointerDown}
      onPointerEnter={() => onHoverChange(true)}
      onPointerLeave={() => onHoverChange(false)}
      title={displayName}
    >
      {/* Disque de fond : uniquement là pour détacher le sprite du décor */}
      <div
        className={`absolute w-[82%] h-[82%] rounded-full bg-black/50 ${selected ? 'shadow-[0_0_0_3px_var(--color-cream),0_0_0_6px_var(--color-shell)]' : ''} ${interactive ? 'cursor-grab active:cursor-grabbing touch-none' : ''}`}
      />

      {species?.image_miniature ? (
        <img
          src={species.image_miniature}
          // Le nom est porté par le title du jeton : un alt non vide
          // déverserait son texte par-dessus la pastille si le sprite 404.
          alt=""
          draggable={false}
          className={`pixelated token-outline relative w-[110%] h-[110%] object-contain select-none pointer-events-none ${isKo ? 'grayscale opacity-60' : ''}`}
        />
      ) : (
        <span className="relative text-cream font-bold pointer-events-none">?</span>
      )}

      {showBadge && badgeSrc && (
        <span
          className="absolute top-0 right-0 w-[38%] h-[38%] rounded-full bg-white border-2 border-ink flex items-center justify-center pointer-events-none shadow-[var(--shadow-pixel-sm)]"
          title={isKo ? 'K.O.' : statusInfo.label}
        >
          <img
            src={badgeSrc}
            alt={isKo ? 'K.O.' : statusInfo.label}
            draggable={false}
            className="pixelated w-[78%] h-[78%] object-contain"
          />
        </span>
      )}

    </div>
  )
}
