import type { Player } from '../types'

export interface MentionMatcher {
  /** null si aucun joueur (hors PNJ) n'est éligible aux mentions */
  regex: RegExp | null
  lookup: Map<string, Player>
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

// Les PNJ sont volontairement exclus : "@NomDePNJ" reste du texte brut, seules
// les mentions de vrais joueurs sont surlignées et déclenchent une notification.
// Tri par longueur décroissante pour qu'un nom plus long l'emporte sur un nom
// plus court qui en serait le préfixe (ex. "@Jean" vs "@Jean-Paul").
export function buildMentionMatcher(players: Player[]): MentionMatcher {
  const eligible = players.filter((p) => !p.is_npc && p.name.trim())
  if (eligible.length === 0) return { regex: null, lookup: new Map() }

  const sorted = [...eligible].sort((a, b) => b.name.length - a.name.length)
  const lookup = new Map(sorted.map((p) => [p.name.toLowerCase(), p]))
  const pattern = sorted.map((p) => escapeRegExp(p.name)).join('|')
  const regex = new RegExp(`@(${pattern})(?![\\p{L}\\p{N}_])`, 'giu')
  return { regex, lookup }
}

// Renvoie les joueurs (dédupliqués) mentionnés via "@Nom" dans le contenu d'un message.
export function findMentionedPlayers(content: string, players: Player[]): Player[] {
  const { regex, lookup } = buildMentionMatcher(players)
  if (!regex) return []
  const found = new Map<number, Player>()
  let m: RegExpExecArray | null
  regex.lastIndex = 0
  while ((m = regex.exec(content))) {
    const player = lookup.get(m[1].toLowerCase())
    if (player) found.set(player.id, player)
    if (m.index === regex.lastIndex) regex.lastIndex++
  }
  return [...found.values()]
}
