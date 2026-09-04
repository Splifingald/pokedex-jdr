import { useMemo } from 'react'
import type { BoardGrid } from '../../lib/onlineBoard'
import { outlinePath, regionOutline } from '../../lib/onlineBoard'

/** Un ensemble de cases à cerner d'un trait, dans une couleur donnée. */
export interface OutlinedZone {
  key: string
  cells: Set<string>
  stroke: string
}

interface Props {
  grid: BoardGrid
  /** Dessinées dans l'ordre : les dernières passent devant. */
  zones: OutlinedZone[]
}

/** Épaisseur en pixels d'écran, pas en cases : un plateau à 40 colonnes garde
 *  un trait lisible, et le zoom du plateau le grossit comme le reste. */
const STROKE_WIDTH = 3

// Contours des zones du plateau : cases bloquées, cases peintes, portée de la
// capacité choisie, cases atteignables pendant un déplacement.
//
// Le remplissage doit rester discret — c'est une illustration en dessous, pas
// un fond — donc c'est le CONTOUR qui porte la lisibilité. Il ne suit que le
// pourtour de la zone : une flaque de dix cases est cernée d'un seul trait, ce
// qui la donne à lire d'un coup d'œil là où dix carrés séparés se confondaient
// avec le quadrillage.
//
// Un seul trait, dans la couleur de la zone : pas de liseré de contraste, la
// zone doit se lire comme une zone et pas comme une décoration.
export function BattleZoneOutlines({ grid, zones }: Props) {
  const paths = useMemo(
    () => zones
      .filter((z) => z.cells.size > 0)
      .map((z) => ({ key: z.key, stroke: z.stroke, d: outlinePath(regionOutline(z.cells)) }))
      .filter((z) => z.d),
    [zones]
  )

  if (paths.length === 0) return null

  return (
    <svg
      className="absolute left-0 right-0 w-full pointer-events-none"
      style={{ top: `${grid.offsetY * 100}%`, height: `${grid.rows * grid.cellH * 100}%` }}
      viewBox={`0 0 ${grid.cols} ${grid.rows}`}
      // La bande de cases entières fait exactement cols × rows cases carrées :
      // le repère n'est donc pas déformé malgré le « none ».
      preserveAspectRatio="none"
      aria-hidden="true"
    >
      {paths.map((p) => (
        // Bouts carrés : les segments fusionnés se rejoignent à angle droit, et
        // le débord d'un demi-trait remplit exactement les coins.
        <path
          key={p.key}
          d={p.d}
          fill="none"
          stroke={p.stroke}
          strokeWidth={STROKE_WIDTH}
          strokeLinecap="square"
          vectorEffect="non-scaling-stroke"
        />
      ))}
    </svg>
  )
}
