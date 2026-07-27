import type { Encounter } from '../types'

export const QUICK_PICK_MIN = 1
export const QUICK_PICK_MAX = 20

export function rollQuickPick(): number {
  return QUICK_PICK_MIN + Math.floor(Math.random() * (QUICK_PICK_MAX - QUICK_PICK_MIN + 1))
}

// Valeur de dé la plus haute parmi les rencontres couvertes par le tirage (mise en avant renforcée)
export function getQuickPickTopDe(rows: Encounter[], pick: number): number | null {
  let top: number | null = null
  for (const row of rows) {
    if (row.de == null || row.de > pick) continue
    if (top == null || row.de > top) top = row.de
  }
  return top
}

export type QuickPickHighlight = 'top' | 'match' | null

export function getQuickPickHighlight(row: Encounter, pick: number | null, top: number | null): QuickPickHighlight {
  if (pick == null || row.de == null || row.de > pick) return null
  return row.de === top ? 'top' : 'match'
}

// Amène la rencontre la mieux notée du tirage dans la zone visible (sans scroll si déjà à l'écran)
export function scrollToEncounterRow(rowId: number) {
  document.getElementById(`encounter-row-${rowId}`)?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
}
