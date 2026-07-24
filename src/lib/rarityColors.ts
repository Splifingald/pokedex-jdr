import { normalizeSearch } from './normalizeSearch'

// Badges de rareté lisibles sur fond crème
const RARITY_STYLES: Record<string, string> = {
  commun: 'bg-green-200 border-green-700 text-green-900',
  'peu commun': 'bg-blue-200 border-blue-700 text-blue-900',
  rare: 'bg-purple-200 border-purple-700 text-purple-900',
  legendaire: 'bg-orange-200 border-orange-700 text-orange-900',
}

const DEFAULT_STYLE = 'bg-cream-secondary border-ink/50 text-ink-muted'

export function rarityBadgeStyle(rarete: string | null | undefined): string {
  if (!rarete) return DEFAULT_STYLE
  return RARITY_STYLES[normalizeSearch(rarete.trim())] ?? DEFAULT_STYLE
}
