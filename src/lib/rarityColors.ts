import { normalizeSearch } from './normalizeSearch'

const RARITY_STYLES: Record<string, string> = {
  commun: 'bg-green-900/60 border-green-600 text-green-200',
  'peu commun': 'bg-blue-900/60 border-blue-600 text-blue-200',
  rare: 'bg-purple-900/60 border-purple-600 text-purple-200',
  legendaire: 'bg-orange-900/60 border-orange-600 text-orange-200',
}

const DEFAULT_STYLE = 'bg-gray-800/60 border-gray-600 text-gray-200'

export function rarityBadgeStyle(rarete: string | null | undefined): string {
  if (!rarete) return DEFAULT_STYLE
  return RARITY_STYLES[normalizeSearch(rarete.trim())] ?? DEFAULT_STYLE
}
