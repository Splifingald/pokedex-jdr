export type CampaignIconType = 'item' | 'pokemon' | 'player'

const PREFIX = 'icon:'

// Encode une image (objet/Pokémon/joueur) choisie comme icône de chapitre/session dans la
// même colonne texte que les emoji : "icon:<type>:<url>". Un emoji ne commence jamais par
// "icon:", donc aucune ambiguïté possible, pas de migration de schéma nécessaire.
export function encodeIcon(type: CampaignIconType, url: string): string {
  return `${PREFIX}${type}:${url}`
}

export function parseIcon(icon: string): { type: CampaignIconType; url: string } | null {
  if (!icon.startsWith(PREFIX)) return null
  const rest = icon.slice(PREFIX.length)
  const sep = rest.indexOf(':')
  if (sep === -1) return null
  const type = rest.slice(0, sep)
  if (type !== 'item' && type !== 'pokemon' && type !== 'player') return null
  return { type, url: rest.slice(sep + 1) }
}

export function isImageIcon(icon: string): boolean {
  return icon.startsWith(PREFIX)
}
