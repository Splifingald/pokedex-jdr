// Logique partagée des calques du mode Affichage (PNJ / Pokémon / Objets) :
// réutilisée par AdminDisplayPanel et par les boutons "Ajouter à l'affichage"
// des popups de référence, pour ne pas dupliquer add/remove/reorder.

export const MAX_FIGURES = 4

export function moveInArray(ids: number[], index: number, direction: -1 | 1): number[] {
  const target = index + direction
  if (target < 0 || target >= ids.length) return ids
  const next = [...ids]
  ;[next[index], next[target]] = [next[target], next[index]]
  return next
}

export function addToLayer(current: number[], id: number, max = MAX_FIGURES): number[] {
  if (current.includes(id) || current.length >= max) return current
  return [...current, id]
}

export function removeFromLayer(current: number[], id: number): number[] {
  return current.filter((x) => x !== id)
}
