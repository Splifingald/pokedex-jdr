import type { ChatMessage } from '../types'

const WINDOW_MS = 60_000

// Vérification anti-spam côté client uniquement (même posture que le reste de
// l'app, sans vraie sécurité serveur). Retourne le nombre de secondes à
// attendre avant de pouvoir renvoyer un message, ou 0 si l'envoi est autorisé.
export function chatCooldownSeconds(
  messages: ChatMessage[],
  playerId: number,
  limitPerMinute: number,
  now: number = Date.now()
): number {
  const recent = messages
    .filter((m) => m.player_id === playerId && !m.is_npc && now - new Date(m.created_at).getTime() < WINDOW_MS)
    .sort((a, b) => a.created_at.localeCompare(b.created_at))

  if (recent.length < limitPerMinute) return 0

  const oldestInWindow = recent[recent.length - limitPerMinute]
  const freesAt = new Date(oldestInWindow.created_at).getTime() + WINDOW_MS
  return Math.max(0, Math.ceil((freesAt - now) / 1000))
}
