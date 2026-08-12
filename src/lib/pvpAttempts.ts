import type { PvpChallengeAttempt } from '../types'

// "Aujourd'hui à XXhXXm" / "Hier à XXhXXm" / "Le DD/MM" — jamais d'année (le
// tableau des scores repart de toute façon à zéro à chaque retrait/repose
// d'un défi, voir pvp_challenges, donc une tentative vieille de plus d'un an
// n'a jamais lieu d'être affichée ici).
export function formatAttemptTimestamp(iso: string): string {
  const date = new Date(iso)
  const now = new Date()
  const hh = String(date.getHours()).padStart(2, '0')
  const mm = String(date.getMinutes()).padStart(2, '0')
  const sameDay = (a: Date, b: Date) =>
    a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  if (sameDay(date, now)) return `Aujourd'hui à ${hh}h${mm}`
  const yesterday = new Date(now)
  yesterday.setDate(now.getDate() - 1)
  if (sameDay(date, yesterday)) return `Hier à ${hh}h${mm}`
  const dd = String(date.getDate()).padStart(2, '0')
  const mo = String(date.getMonth() + 1).padStart(2, '0')
  return `Le ${dd}/${mo}`
}

// Une victoire bat toujours une défaite ; entre deux victoires, celle en
// MOINS de tours gagne (jeu au tour par tour, voir duration_turns) ; entre
// deux défaites, celle qui a laissé le moins de PV au défenseur (donc la
// plus proche de la victoire) gagne — sert à la fois à choisir la MEILLEURE
// tentative de chaque joueur (vue par défaut) et à trier ces meilleures
// tentatives entre elles (classement implicite).
function compareAttemptQuality(a: PvpChallengeAttempt, b: PvpChallengeAttempt): number {
  if (a.outcome !== b.outcome) return a.outcome === 'win' ? -1 : 1
  if (a.outcome === 'win') return (a.duration_turns ?? Infinity) - (b.duration_turns ?? Infinity)
  return (a.defender_hp_remaining ?? Infinity) - (b.defender_hp_remaining ?? Infinity)
}

// Vue par défaut (voir "Voir tout" plus bas pour l'historique complet) : une
// seule ligne par joueur, sa MEILLEURE tentative contre ce défi précis.
export function bestAttemptPerPlayer(attempts: PvpChallengeAttempt[]): PvpChallengeAttempt[] {
  const bestByPlayer = new Map<number, PvpChallengeAttempt>()
  for (const a of attempts) {
    const current = bestByPlayer.get(a.attacker_player_id)
    if (!current || compareAttemptQuality(a, current) < 0) bestByPlayer.set(a.attacker_player_id, a)
  }
  return [...bestByPlayer.values()].sort(compareAttemptQuality)
}
