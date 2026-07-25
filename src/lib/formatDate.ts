// Formate une date ISO (YYYY-MM-DD, telle que renvoyée par Postgres) en DD/MM/YYYY
// sans passer par `Date` pour éviter tout décalage de fuseau horaire sur une date pure.
export function formatDateFr(iso: string): string {
  const [y, m, d] = iso.split('-')
  return `${d}/${m}/${y}`
}
