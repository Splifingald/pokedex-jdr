
// Géométrie du plateau de bataille.
//
// Rien n'est stocké en pixels : la base ne contient que des indices de cases
// (online_tokens.cell_col / cell_row) et les curseurs voyagent en fractions
// 0..1 du rectangle du plateau. Comme ce rectangle est exactement celui de
// l'image de fond sur tous les écrans (cadrage « contain », voir
// useFittedBox), une même valeur désigne le même point de l'illustration sur
// un téléphone, un portable et le vidéoprojecteur.

export interface Cell {
  col: number
  row: number
}

/** Grille dérivée : l'admin ne règle QUE le nombre de colonnes, les cases sont
 *  carrées, et le nombre de lignes tombe de la forme de l'image.
 *
 *  Toutes les mesures sont en fractions du plateau (0..1), jamais en pixels :
 *  la bande de cases tombe donc au même endroit de l'illustration sur tous les
 *  écrans, quel que soit le zoom. */
export interface BoardGrid {
  cols: number
  rows: number
  /** Largeur d'une case, en fraction de la largeur du plateau. */
  cellW: number
  /** Hauteur d'une case, en fraction de la HAUTEUR du plateau. En pixels réels
   *  elle vaut la largeur — les cases sont carrées — mais le plateau n'étant
   *  pas carré, la fraction diffère. */
  cellH: number
  /** Hauteur de la bande masquée en haut (et en bas), en fraction de la hauteur.
   *  C'est le reste qui ne fait pas une ligne complète, réparti des deux côtés. */
  offsetY: number
}

/** `ratio` = largeur/hauteur du plateau, c'est-à-dire de l'image de fond. */
export function computeGrid(cols: number, ratio: number): BoardGrid {
  const safeCols = Math.max(1, Math.floor(cols))
  const safeRatio = Number.isFinite(ratio) && ratio > 0 ? ratio : 16 / 9
  const cellW = 1 / safeCols
  // Case carrée : sa hauteur en pixels vaut sa largeur, soit largeurPlateau/cols.
  // Rapportée à la hauteur du plateau, cela fait (largeur/cols)/hauteur = ratio/cols.
  const cellH = safeRatio / safeCols
  // Seules les lignes entières sont affichées ; le reste est masqué en haut et en bas.
  const rows = Math.max(1, Math.floor(1 / cellH))
  const offsetY = Math.max(0, (1 - rows * cellH) / 2)
  return { cols: safeCols, rows, cellW, cellH, offsetY }
}

/** Centre d'une case, en fractions du plateau. */
export function cellCenter(grid: BoardGrid, col: number, row: number): { left: number; top: number } {
  return {
    left: (col + 0.5) * grid.cellW,
    top: grid.offsetY + (row + 0.5) * grid.cellH,
  }
}

export interface NormPoint {
  x: number
  y: number
}

export const cellKey = (col: number, row: number): string => `${col},${row}`

export function parseCellKey(key: string): Cell | null {
  const [c, r] = key.split(',')
  const col = Number(c)
  const row = Number(r)
  return Number.isInteger(col) && Number.isInteger(row) ? { col, row } : null
}

export function isInBounds(cell: Cell, grid: BoardGrid): boolean {
  return cell.col >= 0 && cell.col < grid.cols && cell.row >= 0 && cell.row < grid.rows
}

/** Fraction 0..1 du rectangle du plateau. Peut sortir de [0,1] si le pointeur
 *  est sur les bandes noires — à l'appelant de filtrer avec isOnBoard. */
export function pointToNorm(clientX: number, clientY: number, rect: DOMRect): NormPoint {
  return { x: (clientX - rect.left) / rect.width, y: (clientY - rect.top) / rect.height }
}

export const isOnBoard = (p: NormPoint): boolean => p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1

/** Case sous le pointeur, ou null hors du plateau — y compris sur les bandes
 *  masquées du haut et du bas, qui ne portent aucune case. */
export function pointToCell(clientX: number, clientY: number, rect: DOMRect, grid: BoardGrid): Cell | null {
  const p = pointToNorm(clientX, clientY, rect)
  if (p.x < 0 || p.x >= 1 || p.y < 0 || p.y >= 1) return null
  const rowFloat = (p.y - grid.offsetY) / grid.cellH
  if (rowFloat < 0 || rowFloat >= grid.rows) return null
  return {
    col: Math.min(grid.cols - 1, Math.max(0, Math.floor(p.x * grid.cols))),
    row: Math.min(grid.rows - 1, Math.max(0, Math.floor(rowFloat))),
  }
}

/** Boîte « contain » : la plus grande boîte de ratio donné tenant dans boxW × boxH. */
export function fitBox(boxW: number, boxH: number, ratio: number): { width: number; height: number } {
  if (boxW <= 0 || boxH <= 0 || !Number.isFinite(ratio) || ratio <= 0) return { width: 0, height: 0 }
  const width = Math.min(boxW, boxH * ratio)
  return { width, height: width / ratio }
}

/** Un jeton à 0 PV reste visible mais ne bloque plus sa case (règle produit,
 *  dupliquée côté SQL dans online_place_token : les deux doivent rester alignées). */
export function isTokenKo(currentHp: number): boolean {
  return currentHp <= 0
}

/** Case libre pour un dépôt ? `movingTokenId` exclut le jeton en cours de déplacement. */
export function isCellAvailable(
  cell: Cell,
  blocked: Set<string>,
  occupants: { tokenId: number; hp: number }[],
  movingTokenId: number | null
): boolean {
  if (blocked.has(cellKey(cell.col, cell.row))) return false
  return !occupants.some((o) => o.tokenId !== movingTokenId && !isTokenKo(o.hp))
}

/** Teintes de l'outil de coloriage du MJ. Volontairement translucides : ce sont
 *  des repères posés PAR-DESSUS l'illustration, pas des cases opaques. */
export const TILE_COLOR_CSS: Record<string, string> = {
  red: 'rgba(214, 69, 69, 0.42)',
  blue: 'rgba(74, 127, 214, 0.42)',
  green: 'rgba(76, 175, 107, 0.42)',
  orange: 'rgba(232, 147, 61, 0.42)',
  purple: 'rgba(138, 92, 214, 0.42)',
  pink: 'rgba(236, 72, 153, 0.42)',
}

export const TILE_COLOR_LABEL: Record<string, string> = {
  red: 'Rouge',
  blue: 'Bleu',
  green: 'Vert',
  orange: 'Orange',
  purple: 'Violet',
  pink: 'Rose',
}

/** Cases réellement atteignables en `steps` déplacements, en contournant les
 *  obstacles — contrairement à la portée d'une capacité, qui ignore le décor.
 *
 *  Un parcours en largeur, pas un losange : un Pokémon cerné n'a nulle part où
 *  aller, et le losange lui promettrait des cases inaccessibles. La case de
 *  départ n'est pas renvoyée (y rester n'est pas un déplacement). */
export function reachableCells(
  origin: Cell,
  steps: number,
  grid: BoardGrid,
  isObstacle: (cell: Cell) => boolean
): Set<string> {
  const reached = new Set<string>()
  if (steps <= 0) return reached

  const visited = new Set<string>([cellKey(origin.col, origin.row)])
  let frontier: Cell[] = [origin]

  for (let step = 0; step < steps && frontier.length > 0; step++) {
    const next: Cell[] = []
    for (const cell of frontier) {
      for (const [dc, dr] of [[1, 0], [-1, 0], [0, 1], [0, -1]] as const) {
        const candidate = { col: cell.col + dc, row: cell.row + dr }
        if (!isInBounds(candidate, grid)) continue
        const key = cellKey(candidate.col, candidate.row)
        if (visited.has(key)) continue
        visited.add(key)
        // Un obstacle ne se traverse pas et ne s'occupe pas : on l'écarte
        // sans l'ajouter au front.
        if (isObstacle(candidate)) continue
        reached.add(key)
        next.push(candidate)
      }
    }
    frontier = next
  }
  return reached
}
