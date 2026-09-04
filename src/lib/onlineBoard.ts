
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

/** Cases réellement atteignables en `steps` déplacements, en contournant le
 *  décor — contrairement à la portée d'une capacité, qui l'ignore.
 *
 *  Un parcours en largeur, pas un losange : un Pokémon cerné n'a nulle part où
 *  aller, et le losange lui promettrait des cases inaccessibles. La case de
 *  départ n'est pas renvoyée (y rester n'est pas un déplacement).
 *
 *  DEUX sortes d'obstacles, à ne pas confondre :
 *  - `isWall` (case bloquée) : ni traversée, ni occupée ;
 *  - `isOccupied` (un autre Pokémon debout) : on la TRAVERSE, on ne s'y arrête
 *    pas. Elle coûte donc un point de déplacement comme n'importe quelle case,
 *    mais ne sort pas dans le résultat. Un Pokémon peut ainsi passer derrière
 *    une ligne alliée, ce qu'un mur lui interdirait. */
export function reachableCells(
  origin: Cell,
  steps: number,
  grid: BoardGrid,
  isWall: (cell: Cell) => boolean,
  isOccupied: (cell: Cell) => boolean
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
        // Un mur ne se traverse pas : on l'écarte sans l'ajouter au front.
        if (isWall(candidate)) continue
        // Une case occupée reste un passage : elle avance le front, mais on ne
        // peut pas s'y arrêter.
        if (!isOccupied(candidate)) reached.add(key)
        next.push(candidate)
      }
    }
    frontier = next
  }
  return reached
}

/** Teintes opaques, pour le TRAIT de contour d'une zone peinte : le remplissage
 *  reste translucide (on doit voir le décor), mais sa bordure doit se lire. */
export const TILE_OUTLINE_CSS: Record<string, string> = {
  red: 'rgb(214, 69, 69)',
  blue: 'rgb(74, 127, 214)',
  green: 'rgb(76, 175, 107)',
  orange: 'rgb(232, 147, 61)',
  purple: 'rgb(138, 92, 214)',
  pink: 'rgb(236, 72, 153)',
}

/** Un segment de contour, en unités de case : (0,0) est le coin haut-gauche de
 *  la case (0,0), (cols,rows) le coin bas-droit de la dernière. */
export interface OutlineSegment {
  x1: number
  y1: number
  x2: number
  y2: number
}

/** Fusionne les arêtes alignées et contiguës en un seul trait.
 *  `line` = l'axe fixe (la ligne pour une arête horizontale, la colonne pour
 *  une verticale), `at` = l'index de départ le long du trait. */
function mergeRuns(edges: { line: number; at: number }[], horizontal: boolean): OutlineSegment[] {
  const byLine = new Map<number, Set<number>>()
  for (const e of edges) {
    const set = byLine.get(e.line)
    if (set) set.add(e.at)
    else byLine.set(e.line, new Set([e.at]))
  }
  const runs: OutlineSegment[] = []
  const push = (line: number, start: number, end: number) => {
    runs.push(horizontal
      ? { x1: start, y1: line, x2: end, y2: line }
      : { x1: line, y1: start, x2: line, y2: end })
  }
  for (const [line, set] of byLine) {
    const ats = [...set].sort((a, b) => a - b)
    let start = ats[0]
    let end = ats[0] + 1
    for (let i = 1; i < ats.length; i++) {
      if (ats[i] === end) { end++; continue }
      push(line, start, end)
      start = ats[i]
      end = ats[i] + 1
    }
    push(line, start, end)
  }
  return runs
}

/** Contour « intelligent » d'une zone : seulement les arêtes qui la séparent de
 *  l'extérieur, jamais les traits intérieurs entre deux cases voisines.
 *
 *  C'est ce qui distingue une ZONE d'un tas de cases : cinq cases bloquées
 *  côte à côte donnent un seul rectangle cerné, pas cinq carrés. Les arêtes
 *  alignées sont fusionnées en un trait continu, pour que le rendu ne trahisse
 *  pas le découpage (les jointures de segments se voient aux angles). */
export function regionOutline(cells: Iterable<string>): OutlineSegment[] {
  const zone = cells instanceof Set ? cells : new Set(cells)
  const inZone = (col: number, row: number) => zone.has(cellKey(col, row))
  const horizontal: { line: number; at: number }[] = []
  const vertical: { line: number; at: number }[] = []
  for (const key of zone) {
    const cell = parseCellKey(key)
    if (!cell) continue
    const { col, row } = cell
    if (!inZone(col, row - 1)) horizontal.push({ line: row, at: col })
    if (!inZone(col, row + 1)) horizontal.push({ line: row + 1, at: col })
    if (!inZone(col - 1, row)) vertical.push({ line: col, at: row })
    if (!inZone(col + 1, row)) vertical.push({ line: col + 1, at: row })
  }
  return [...mergeRuns(horizontal, true), ...mergeRuns(vertical, false)]
}

/** Chemin SVG d'un contour, dans un repère où 1 unité = 1 case. */
export function outlinePath(segments: OutlineSegment[]): string {
  return segments.map((s) => `M${s.x1} ${s.y1}L${s.x2} ${s.y2}`).join('')
}
