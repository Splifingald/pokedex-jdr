import type { MiningConfig, MiningItemDef, Item } from '../types'

// ── Génération procédurale ──────────────────────────────────────
// Toute la logique de tirage/placement vit ici en TS (testable), pas côté SQL —
// la fonction RPC mining_ensure_active_grid se contente de persister le layout
// calculé ici (ou de l'ignorer si une grille personnalisée est en file).

export interface MiningItemPlacement {
  item_nom: string
  size: number
  origin_row: number
  origin_col: number
}

export interface ProceduralGridLayout {
  size: number
  move_budget: number
  items: MiningItemPlacement[]
}

// Tirage pondéré à une seule entrée : probabilité de chaque objet = son poids
// / somme des poids — même principe que rollWeightedSymbol dans casino.ts.
function pickOneWeighted(pool: MiningItemDef[], totalWeight: number): MiningItemDef {
  let roll = Math.random() * totalWeight
  for (const def of pool) {
    roll -= def.weight
    if (roll < 0) return def
  }
  return pool[pool.length - 1]
}

// Tente de placer un objet à une origine aléatoire non chevauchante, par
// essais bornés. Retourne null si aucune place valide n'est trouvée après 200
// essais (objet trop grand pour l'espace restant) — cas dégénéré accepté
// plutôt qu'une erreur bloquante.
function tryPlaceOne(size: number, def: MiningItemDef, occupied: Set<number>): MiningItemPlacement | null {
  if (def.size > size) return null

  for (let attempt = 0; attempt < 200; attempt++) {
    const originRow = Math.floor(Math.random() * (size - def.size + 1))
    const originCol = Math.floor(Math.random() * (size - def.size + 1))

    let fits = true
    for (let r = 0; r < def.size && fits; r++) {
      for (let c = 0; c < def.size && fits; c++) {
        if (occupied.has((originRow + r) * size + (originCol + c))) fits = false
      }
    }
    if (!fits) continue

    for (let r = 0; r < def.size; r++) {
      for (let c = 0; c < def.size; c++) {
        occupied.add((originRow + r) * size + (originCol + c))
      }
    }
    return { item_nom: def.item_nom, size: def.size, origin_row: originRow, origin_col: originCol }
  }
  return null
}

const MAX_CONSECUTIVE_PLACEMENT_FAILURES = 50

export function generateProceduralGridLayout(
  config: Pick<MiningConfig, 'grid_size_min' | 'grid_size_max' | 'fill_ratio_pct' | 'move_budget_pct'>,
  itemDefs: MiningItemDef[]
): ProceduralGridLayout {
  const sizeMin = Math.max(2, Math.min(config.grid_size_min, config.grid_size_max))
  const sizeMax = Math.max(sizeMin, config.grid_size_max)
  const size = sizeMin + Math.floor(Math.random() * (sizeMax - sizeMin + 1))

  const moveBudget = Math.max(1, Math.ceil((size * size * config.move_budget_pct) / 100))

  // Tire les objets un par un (avec remise) et les place tant que le
  // remplissage cible n'est pas atteint — le dernier objet peut faire dépasser
  // la cible, jamais l'inverse (voulu : on ne retire jamais un objet déjà placé).
  const pool = itemDefs.filter((d) => d.enabled && d.weight > 0)
  const totalWeight = pool.reduce((sum, d) => sum + d.weight, 0)
  const targetOccupied = Math.ceil((size * size * config.fill_ratio_pct) / 100)

  const occupied = new Set<number>()
  const items: MiningItemPlacement[] = []
  let consecutiveFailures = 0

  while (pool.length > 0 && occupied.size < targetOccupied && consecutiveFailures < MAX_CONSECUTIVE_PLACEMENT_FAILURES) {
    const def = pickOneWeighted(pool, totalWeight)
    const placement = tryPlaceOne(size, def, occupied)
    if (placement) {
      items.push(placement)
      consecutiveFailures = 0
    } else {
      consecutiveFailures++
    }
  }

  return { size, move_budget: moveBudget, items }
}

// ── Affichage ────────────────────────────────────────────────────

// Étiquette "B3" : lettre de ligne (A, B, C…) + numéro de colonne (1-indexé).
// Gère au-delà de 26 lignes (AA, AB…) même si une grille aussi grande est peu
// probable en pratique (taille max raisonnable côté admin). Exportée seule
// (sans le numéro de colonne) pour les en-têtes de ligne de la grille.
export function rowLetter(row: number): string {
  let n = row
  let label = ''
  do {
    label = String.fromCharCode(65 + (n % 26)) + label
    n = Math.floor(n / 26) - 1
  } while (n >= 0)
  return label
}

export function cellLabel(cellIndex: number, size: number): string {
  const row = Math.floor(cellIndex / size)
  const col = cellIndex % size
  return `${rowLetter(row)}${col + 1}`
}

// Horodatage relatif d'un coup, par tranches calendaires (pas une fenêtre
// glissante de 24h) : aujourd'hui -> minutes/heures écoulées ; hier (jour
// calendaire précédent) -> "Hier" ; avant -> date absolue DD/MM/YYYY.
export function formatMoveTimestamp(iso: string, now: Date = new Date()): string {
  const date = new Date(iso)
  const sameDay = (a: Date, b: Date) =>
    a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()

  if (sameDay(date, now)) {
    const diffMin = Math.floor((now.getTime() - date.getTime()) / 60000)
    if (diffMin < 1) return "À l'instant"
    if (diffMin < 60) return `Il y a ${diffMin} minute${diffMin === 1 ? '' : 's'}`
    const diffH = Math.floor(diffMin / 60)
    return `Il y a ${diffH} heure${diffH === 1 ? '' : 's'}`
  }

  const yesterday = new Date(now)
  yesterday.setDate(now.getDate() - 1)
  if (sameDay(date, yesterday)) return 'Hier'

  const dd = String(date.getDate()).padStart(2, '0')
  const mm = String(date.getMonth() + 1).padStart(2, '0')
  return `Le ${dd}/${mm}/${date.getFullYear()}`
}

// ── Économie (admin) ────────────────────────────────────────────

export interface MiningExpectedValue {
  expectedItemCount: number
  expectedValuePerDraw: number
  expectedGridValue: number
  expectedCells: number
  expectedCellValue: number
}

// Espérance de valeur d'une grille et d'une case (≈ valeur d'un ticket), à
// partir du poids/valeur d'achat des objets de la bibliothèque et des plages
// admin — même principe d'espérance pondérée que les calculateurs de
// casino.ts, appliqué au tirage d'objets de Fouille plutôt qu'aux symboles.
// Utilise `achat` (valeur brute du catalogue) plutôt que `vente` (délibérément
// plus basse, pour ne pas inciter à l'achat-revente) — c'est `achat` qui reflète
// la vraie valeur de l'objet trouvé.
export function computeGridExpectedValue(
  config: Pick<MiningConfig, 'fill_ratio_pct' | 'grid_size_min' | 'grid_size_max'>,
  itemDefs: MiningItemDef[],
  itemsByName: Map<string, Item>
): MiningExpectedValue {
  const pool = itemDefs.filter((d) => d.enabled && d.weight > 0)
  const totalWeight = pool.reduce((sum, d) => sum + d.weight, 0)
  const expectedValuePerDraw = totalWeight > 0
    ? pool.reduce((sum, d) => sum + d.weight * (itemsByName.get(d.item_nom)?.achat ?? 0), 0) / totalWeight
    : 0
  // Cellules occupées par tirage en moyenne (chaque objet a une empreinte size²) —
  // sert à convertir la cible de remplissage (%) en nombre d'objets tirés en moyenne.
  const expectedCellsPerDraw = totalWeight > 0
    ? pool.reduce((sum, d) => sum + d.weight * d.size * d.size, 0) / totalWeight
    : 0

  const sizeMin = Math.max(2, Math.min(config.grid_size_min, config.grid_size_max))
  const sizeMax = Math.max(sizeMin, config.grid_size_max)
  const sizes = Array.from({ length: sizeMax - sizeMin + 1 }, (_, i) => sizeMin + i)
  // Espérance exacte de size² pour size uniforme sur [sizeMin, sizeMax] — pas
  // simplement le carré de la taille moyenne (légèrement différent, aussi simple à calculer).
  const expectedCells = sizes.reduce((sum, s) => sum + s * s, 0) / sizes.length

  const targetOccupiedCells = expectedCells * (config.fill_ratio_pct / 100)
  // Approximation : ignore le dépassement du dernier objet tiré et les échecs
  // de placement (grille pleine) — suffisant pour un indicateur admin.
  const expectedItemCount = expectedCellsPerDraw > 0 ? targetOccupiedCells / expectedCellsPerDraw : 0
  const expectedGridValue = expectedItemCount * expectedValuePerDraw

  return {
    expectedItemCount,
    expectedValuePerDraw,
    expectedGridValue,
    expectedCells,
    expectedCellValue: expectedCells > 0 ? expectedGridValue / expectedCells : 0,
  }
}

export interface JigsawStyle {
  backgroundImage: string
  backgroundSize: string
  backgroundPosition: string
}

// Découpe l'image d'un objet en tranches N×N (N = sa taille) via background-size/
// position CSS, sans traitement d'image côté serveur : la tranche affichée pour
// une case dépend de sa position locale dans l'empreinte de l'objet.
export function jigsawSliceStyle(
  item: { size: number; origin_row: number; origin_col: number },
  cellRow: number,
  cellCol: number,
  imageUrl: string
): JigsawStyle {
  const localRow = cellRow - item.origin_row
  const localCol = cellCol - item.origin_col
  const denom = item.size - 1
  const posX = denom > 0 ? (localCol / denom) * 100 : 0
  const posY = denom > 0 ? (localRow / denom) * 100 : 0
  return {
    backgroundImage: `url(${imageUrl})`,
    backgroundSize: `${item.size * 100}% ${item.size * 100}%`,
    backgroundPosition: `${posX}% ${posY}%`,
  }
}
