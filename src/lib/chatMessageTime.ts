// Horodatage affiché à côté du nom dans une bulle de chat, par tranches
// calendaires (comme formatMoveTimestamp pour la Fouille) : aujourd'hui ->
// heure seule ; hier (jour calendaire précédent) -> "Hier à HH:MM" ; même
// année -> "JJ/MM à HH:MM" ; année différente -> "JJ/MM/AAAA à HH:MM".
export function formatChatMessageTime(iso: string, now: Date = new Date()): string {
  const date = new Date(iso)
  const sameDay = (a: Date, b: Date) =>
    a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()

  const hh = String(date.getHours()).padStart(2, '0')
  const mm = String(date.getMinutes()).padStart(2, '0')
  const time = `${hh}:${mm}`

  if (sameDay(date, now)) return time

  const yesterday = new Date(now)
  yesterday.setDate(now.getDate() - 1)
  if (sameDay(date, yesterday)) return `Hier à ${time}`

  const dd = String(date.getDate()).padStart(2, '0')
  const mo = String(date.getMonth() + 1).padStart(2, '0')
  if (date.getFullYear() === now.getFullYear()) return `${dd}/${mo} à ${time}`

  return `${dd}/${mo}/${date.getFullYear()} à ${time}`
}
