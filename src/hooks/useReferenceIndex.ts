import { useMemo } from 'react'
import type { Pokemon, Player, CarteLocation, Attack, Item, CampaignChapter } from '../types'
import { TYPE_COLORS } from '../lib/typeColors'

export type ReferenceType = 'pokemon' | 'player' | 'location' | 'ability' | 'item' | 'chapter'

export interface ReferenceEntry {
  type: ReferenceType
  id: number
  name: string
  /** URL de sprite (pokemon), d'icône (item) ou d'avatar (joueur/PNJ) à afficher devant le texte référencé */
  icon?: string
  /** Couleur du type (capacités), remplace la couleur bleue par défaut du surlignage */
  color?: string
}

export interface ReferenceIndex {
  entries: ReferenceEntry[]
  /** Regex combinant tous les noms connus, triés du plus long au plus court (le plus long l'emporte à position égale) */
  matcher: RegExp
  /** Résout un texte matché (en minuscules) vers son entité */
  lookup: Map<string, ReferenceEntry>
}

// En cas de collision exacte de nom entre deux types différents, le premier de cette liste l'emporte :
// les personnages nommés (joueurs/PNJ) priment, puis les espèces de Pokémon, puis la mécanique de jeu
// (capacités/objets), les lieux en dernier car ce sont des titres libres les plus susceptibles de
// coïncider accidentellement avec un mot courant.
const TYPE_PRIORITY: ReferenceType[] = ['player', 'pokemon', 'ability', 'item', 'location', 'chapter']

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

const EMPTY_INDEX: ReferenceIndex = { entries: [], matcher: /(?!)/g, lookup: new Map() }

export function useReferenceIndex(
  pokemon: Pokemon[],
  players: Player[],
  locations: CarteLocation[],
  attacks: Attack[],
  items: Item[],
  chapters: CampaignChapter[] = []
): ReferenceIndex {
  return useMemo(() => {
    const raw: ReferenceEntry[] = [
      ...pokemon.map((p): ReferenceEntry => ({ type: 'pokemon', id: p.id, name: p.nom, icon: p.image_miniature || undefined })),
      ...players.map((p): ReferenceEntry => ({ type: 'player', id: p.id, name: p.name, icon: p.image_url || undefined })),
      ...locations.map((l): ReferenceEntry => ({ type: 'location', id: l.id, name: l.titre })),
      ...attacks.map((a): ReferenceEntry => ({ type: 'ability', id: a.id, name: a.nom, color: TYPE_COLORS[a.type] })),
      ...items.map((i): ReferenceEntry => ({ type: 'item', id: i.id, name: i.nom, icon: i.image_url ?? undefined })),
      ...chapters.map((c): ReferenceEntry => ({ type: 'chapter', id: c.id, name: c.title })),
    ].filter((e) => e.name && e.name.trim())

    // Déduplique les collisions exactes de nom (insensible à la casse) selon la priorité de type
    const byKey = new Map<string, ReferenceEntry>()
    for (const entry of raw) {
      const key = entry.name.toLowerCase()
      const existing = byKey.get(key)
      if (!existing || TYPE_PRIORITY.indexOf(entry.type) < TYPE_PRIORITY.indexOf(existing.type)) {
        byKey.set(key, entry)
      }
    }

    const entries = [...byKey.values()]
    if (entries.length === 0) return EMPTY_INDEX

    // Plus long en premier : à position de départ égale dans l'alternance regex, le premier
    // motif qui matche l'emporte — trier par longueur décroissante fait donc gagner le plus long.
    const sorted = [...entries].sort((a, b) => b.name.length - a.name.length)
    const pattern = sorted.map((e) => escapeRegExp(e.name)).join('|')
    const matcher = new RegExp(`(?<![\\p{L}\\p{N}_])(${pattern})(?![\\p{L}\\p{N}_])`, 'giu')

    return { entries, matcher, lookup: byKey }
  }, [pokemon, players, locations, attacks, items, chapters])
}
