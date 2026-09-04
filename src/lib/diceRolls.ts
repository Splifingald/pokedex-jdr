// Lancers de dés de l'écran partagé.
//
// Volontairement LOCAL : le résultat ne s'affiche que chez celui qui lance.
// Rien ne transite par le réseau, rien n'est écrit en base.
//
// Et volontairement ÉPHÉMÈRE : l'historique vit en mémoire, jamais dans le
// localStorage. Un rechargement de page ou une nouvelle bataille repart d'une
// ardoise vide — ces trois nombres sont un pense-bête de séance, pas une
// donnée à conserver d'une soirée à l'autre.

export const DICE_SIDES = [4, 6, 8, 10, 12, 20] as const
export type DiceSides = (typeof DICE_SIDES)[number]

/** Nombre de résultats récents conservés par type de dé. */
export const DICE_HISTORY_SIZE = 3

const history = new Map<number, number[]>()
/** Référence stable : la renvoyer évite de re-rendre pour un tableau vide neuf. */
const EMPTY: number[] = []

let version = 0
const listeners = new Set<() => void>()

function emit() {
  version++
  for (const listener of listeners) listener()
}

export function subscribeDiceHistory(listener: () => void): () => void {
  listeners.add(listener)
  return () => { listeners.delete(listener) }
}

export function getDiceHistoryVersion(): number {
  return version
}

export function rollDie(sides: number): number {
  return 1 + Math.floor(Math.random() * sides)
}

export function readHistory(sides: number): number[] {
  return history.get(sides) ?? EMPTY
}

/** Empile un résultat en tête et ne garde que les plus récents. */
export function pushHistory(sides: number, value: number): number[] {
  const next = [value, ...readHistory(sides)].slice(0, DICE_HISTORY_SIZE)
  history.set(sides, next)
  emit()
  return next
}

/** Table rase — appelé à la réinitialisation du plateau et à l'ouverture d'une
 *  nouvelle bataille. */
export function clearDiceHistory(): void {
  if (history.size === 0) return
  history.clear()
  emit()
}
