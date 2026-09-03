import type { Cell } from './onlineBoard'
import { cellKey } from './onlineBoard'

// Portée des capacités, utilisée par le plateau de bataille pour surligner la
// zone d'effet quand un joueur sélectionne une capacité de son Pokémon.
// Le surlignage est purement local : sélectionner une capacité ne l'utilise
// pas et n'est pas diffusé aux autres.
//
// Codage dans la colonne « Distance » du CSV des attaques (Attack.distance) :
//   - vide (null)                 → portée infinie, tout le plateau s'allume
//   - « infini », « ∞ », -1       → idem, écriture explicite
//   - un entier N ≥ 0             → losange de rayon N
//
// La case vide vaut bien l'infini et non « aucune portée » : ce sont les
// capacités sans distance (Danse Pluie, Tempête de Sable, Zénith, Vol…), donc
// des effets de terrain qui portent sur tout le plateau. Il n'existe pas de
// cas « rien ne s'allume » — une capacité a soit un rayon, soit l'infini.
// La colonne Postgres étant un integer, l'infini est stocké NULL.

export type AbilityRange =
  | { kind: 'infinite' }
  | { kind: 'radius'; radius: number }

const INFINITE_WORDS = ['infini', 'infinie', '∞', 'illimite', 'illimitee', 'illimité', 'illimitée', 'infinite']

/** Normalise une cellule « Distance » du CSV vers la colonne integer.
 *  Tout ce qui n'est pas un entier positif vaut l'infini, stocké NULL. */
export function parseAttackDistance(raw: string | undefined | null): number | null {
  const trimmed = (raw ?? '').trim()
  if (!trimmed) return null
  if (INFINITE_WORDS.includes(trimmed.toLowerCase())) return null
  const parsed = parseInt(trimmed, 10)
  if (!Number.isFinite(parsed) || parsed < 0) return null
  return parsed
}

export function abilityRange(distance: number | null): AbilityRange {
  // Un négatif résiduel (ancienne saisie « -1 ») vaut aussi l'infini.
  if (distance == null || distance < 0) return { kind: 'infinite' }
  return { kind: 'radius', radius: distance }
}

/** Libellé affiché à côté de l'icône de portée (fiche capacité). */
export function formatDistance(distance: number | null): string {
  return distance == null || distance < 0 ? '∞' : String(distance)
}

/** Cases couvertes par la capacité depuis `origin`.
 *  Distance de Manhattan (losange) : portée 1 = les 4 cases adjacentes.
 *  La case du Pokémon lui-même n'est PAS incluse, sauf à la portée 0 qui ne
 *  désigne que lui. */
export function rangeCells(origin: Cell, range: AbilityRange, cols: number, rows: number): Set<string> {
  const cells = new Set<string>()

  if (range.kind === 'infinite') {
    for (let col = 0; col < cols; col++) {
      for (let row = 0; row < rows; row++) cells.add(cellKey(col, row))
    }
    return cells
  }

  if (range.radius === 0) {
    if (origin.col >= 0 && origin.col < cols && origin.row >= 0 && origin.row < rows) {
      cells.add(cellKey(origin.col, origin.row))
    }
    return cells
  }

  for (let dc = -range.radius; dc <= range.radius; dc++) {
    const remaining = range.radius - Math.abs(dc)
    for (let dr = -remaining; dr <= remaining; dr++) {
      if (dc === 0 && dr === 0) continue
      const col = origin.col + dc
      const row = origin.row + dr
      if (col < 0 || col >= cols || row < 0 || row >= rows) continue
      cells.add(cellKey(col, row))
    }
  }
  return cells
}
