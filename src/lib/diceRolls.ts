// Lancers de dés de l'écran partagé.
//
// Volontairement LOCAL : le résultat ne s'affiche que chez celui qui lance, et
// son historique reste sur son appareil. Rien ne transite par le réseau.

export const DICE_SIDES = [4, 6, 8, 10, 12, 20] as const
export type DiceSides = (typeof DICE_SIDES)[number]

/** Nombre de résultats récents conservés par type de dé. */
export const DICE_HISTORY_SIZE = 3

const key = (sides: number) => `dice_history_d${sides}`

export function rollDie(sides: number): number {
  return 1 + Math.floor(Math.random() * sides)
}

export function readHistory(sides: number): number[] {
  try {
    const raw = localStorage.getItem(key(sides))
    if (!raw) return []
    const parsed: unknown = JSON.parse(raw)
    return Array.isArray(parsed)
      ? parsed.filter((n): n is number => typeof n === 'number').slice(0, DICE_HISTORY_SIZE)
      : []
  } catch {
    return []
  }
}

/** Empile un résultat en tête et ne garde que les plus récents. */
export function pushHistory(sides: number, value: number): number[] {
  const next = [value, ...readHistory(sides)].slice(0, DICE_HISTORY_SIZE)
  try {
    localStorage.setItem(key(sides), JSON.stringify(next))
  } catch {
    // Navigation privée, quota plein… : l'historique est un confort, pas un dû.
  }
  return next
}
