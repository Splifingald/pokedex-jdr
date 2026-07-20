// Minuscules + sans accents, pour une recherche insensible à la casse et aux accents
// (ex: "def" doit trouver "Déflagration")
export function normalizeSearch(s: string): string {
  return s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
}
