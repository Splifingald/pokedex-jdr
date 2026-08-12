import type { Player } from '../types'

// Plage Unicode des diacritiques combinants (accents) une fois le texte
// décomposé en forme NFD — U+0300 à U+036F.
const COMBINING_DIACRITICS_REGEX = new RegExp('[̀-ͯ]', 'g')

// Insensible à la casse ET aux accents : "@elea" ou "@ELEA" doivent tous deux
// resoudre vers un joueur nomme "Éléa". On decompose les caracteres accentues
// (NFD) puis on retire les diacritiques avant de comparer en minuscules.
function normalizeMentionKey(s: string): string {
  return s.normalize('NFD').replace(COMBINING_DIACRITICS_REGEX, '').toLowerCase()
}

// Un token de mention est "@" suivi de caractères de mot, non précédé d'un
// caractère de mot ou d'un autre "@" (évite de matcher "email@Nom").
const MENTION_TOKEN_REGEX = /(?<![\p{L}\p{N}_@])@([\p{L}\p{N}_-]{1,40})/gu

export interface MentionMatcher {
  /** null si aucun joueur (hors PNJ) n'est éligible aux mentions */
  lookup: Map<string, Player> | null
}

// Les PNJ sont volontairement exclus : "@NomDePNJ" reste du texte brut, seules
// les mentions de vrais joueurs sont surlignées et déclenchent une notification.
export function buildMentionMatcher(players: Player[]): MentionMatcher {
  const eligible = players.filter((p) => !p.is_npc && p.name.trim())
  if (eligible.length === 0) return { lookup: null }
  const lookup = new Map(eligible.map((p) => [normalizeMentionKey(p.name), p]))
  return { lookup }
}

// Découpe `content` sur les tokens "@xxx" et invoque `onMatch` pour chacun qui
// résout vers un joueur connu (accents/casse ignorés), avec sa position exacte
// dans le texte d'origine (donc la casse/accentuation telle que tapée par l'auteur).
export function scanMentions(
  content: string,
  matcher: MentionMatcher,
  onMatch: (player: Player, matchedText: string, index: number) => void
) {
  if (!matcher.lookup) return
  MENTION_TOKEN_REGEX.lastIndex = 0
  let m: RegExpExecArray | null
  while ((m = MENTION_TOKEN_REGEX.exec(content))) {
    const player = matcher.lookup.get(normalizeMentionKey(m[1]))
    if (player) onMatch(player, m[0], m.index)
  }
}

// Renvoie les joueurs (dédupliqués) mentionnés via "@Nom" dans le contenu d'un message.
export function findMentionedPlayers(content: string, players: Player[]): Player[] {
  const matcher = buildMentionMatcher(players)
  const found = new Map<number, Player>()
  scanMentions(content, matcher, (player) => found.set(player.id, player))
  return [...found.values()]
}

export interface MentionSuggestion {
  player: Player
  /** Caractères à insérer après le préfixe déjà tapé pour obtenir le nom complet */
  suffix: string
}

// Auto-complétion de la mention en cours de frappe : cherche un token "@préfixe" en fin
// de texte (juste avant le curseur) et, s'il ne correspond exactement qu'à un seul joueur
// (PNJ exclus, accents/casse ignorés) dont le nom commence par ce préfixe, renvoie le
// complément à insérer. Tant que plusieurs joueurs partagent le même préfixe, aucune
// suggestion n'est renvoyée.
export function computeMentionSuggestion(textBeforeCursor: string, players: Player[]): MentionSuggestion | null {
  const match = /(?<![\p{L}\p{N}_@])@([\p{L}\p{N}_-]{1,40})$/u.exec(textBeforeCursor)
  if (!match) return null
  const partial = match[1]
  const partialKey = normalizeMentionKey(partial)
  const candidates = players.filter(
    (p) => !p.is_npc && p.name.trim() && normalizeMentionKey(p.name).startsWith(partialKey)
  )
  if (candidates.length !== 1) return null
  const player = candidates[0]
  if (player.name.length <= partial.length) return null
  return { player, suffix: player.name.slice(partial.length) }
}
