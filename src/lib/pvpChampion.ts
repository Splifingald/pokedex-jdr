function pluralize(n: number, singular: string, plural: string): string {
  return n === 1 ? singular : plural
}

// Deux métriques de temps toujours ("Depuis 3 jours et 12 heures" / "Depuis
// 2 min et 10 secondes"...) — jamais plus, jamais moins, quelle que soit
// l'ancienneté du règne. "min" abrégé uniquement pour la paire minutes+
// secondes (le seul cas où le texte doit rester très court), les autres
// unités toujours en toutes lettres.
export function formatChampionSince(sinceIso: string, now: Date): string {
  const totalSeconds = Math.max(0, Math.floor((now.getTime() - new Date(sinceIso).getTime()) / 1000))
  const days = Math.floor(totalSeconds / 86400)
  const hours = Math.floor((totalSeconds % 86400) / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60

  if (days > 0) {
    return `Depuis ${days} ${pluralize(days, 'jour', 'jours')} et ${hours} ${pluralize(hours, 'heure', 'heures')}`
  }
  if (hours > 0) {
    return `Depuis ${hours} ${pluralize(hours, 'heure', 'heures')} et ${minutes} ${pluralize(minutes, 'minute', 'minutes')}`
  }
  if (minutes > 0) {
    return `Depuis ${minutes} min et ${seconds} ${pluralize(seconds, 'seconde', 'secondes')}`
  }
  return `Depuis ${seconds} ${pluralize(seconds, 'seconde', 'secondes')}`
}
