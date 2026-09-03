import type { OnlineState } from '../types'

// Annonce de la prochaine session : découpage de session_at et règle
// d'affichage de la pop-up d'accueil.
//
// session_at est un timestamptz : contrairement aux dates pures du projet
// (campaign_sessions, formatDate.ts), il porte une heure et doit donc bien
// passer par Date pour être rendu dans le fuseau du joueur.

export interface SessionParts {
  dateInput: string // YYYY-MM-DD, pour <input type="date">
  timeInput: string // HH:MM,     pour <input type="time">
  label: string     // « 14/03/2026 à 20:30 »
}

function pad(n: number): string {
  return String(n).padStart(2, '0')
}

export function splitSessionAt(iso: string | null): SessionParts {
  if (!iso) return { dateInput: '', timeInput: '', label: '' }
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return { dateInput: '', timeInput: '', label: '' }
  const dateInput = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
  const timeInput = `${pad(d.getHours())}:${pad(d.getMinutes())}`
  return {
    dateInput,
    timeInput,
    label: `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} à ${timeInput}`,
  }
}

/** Recompose un timestamptz depuis les deux champs du formulaire admin.
 *  Heure vide = 20:00, l'heure de rendez-vous la plus probable. */
export function joinSessionAt(dateInput: string, timeInput: string): string | null {
  if (!dateInput) return null
  const [h, m] = (timeInput || '20:00').split(':')
  const [y, mo, d] = dateInput.split('-').map(Number)
  const date = new Date(y, (mo ?? 1) - 1, d ?? 1, Number(h) || 0, Number(m) || 0, 0, 0)
  return Number.isNaN(date.getTime()) ? null : date.toISOString()
}

/** La pop-up d'accueil s'affiche à chaque ouverture de l'app tant que
 *  l'annonce est active, mais seulement à partir de N jours avant la session —
 *  et jamais une fois l'heure passée. */
export function shouldShowSessionAnnouncement(state: OnlineState, now: Date = new Date()): boolean {
  if (!state.session_announce_enabled || !state.session_at) return false
  const at = new Date(state.session_at)
  if (Number.isNaN(at.getTime())) return false
  if (at.getTime() < now.getTime()) return false
  const daysUntil = (at.getTime() - now.getTime()) / 86_400_000
  return daysUntil <= state.session_visible_days_before
}
