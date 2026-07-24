import { useState, useMemo } from 'react'
import type { Attack } from '../types'
import { useAttacks } from '../hooks/useAttacks'
import { normalizeSearch } from '../lib/normalizeSearch'
import { TypeBadge } from './TypeBadge'
import { AttackDetailCard } from './AttackDetailCard'

type SortKey = 'nom' | 'type' | 'degats_base' | 'degats_de' | 'effet' | 'precision'

const SORT_OPTIONS: { id: SortKey; label: string }[] = [
  { id: 'nom', label: 'Nom' },
  { id: 'type', label: 'Type' },
  { id: 'degats_base', label: 'Dégâts de base' },
  { id: 'degats_de', label: 'Dégâts dé' },
  { id: 'effet', label: 'Effet' },
  { id: 'precision', label: 'Précision' },
]

function compareNumeric(a: number | null, b: number | null): number {
  if (a == null && b == null) return 0
  if (a == null) return 1
  if (b == null) return -1
  return a - b
}

function sortAttacks(list: Attack[], key: SortKey): Attack[] {
  const sorted = [...list]
  switch (key) {
    case 'type':
      sorted.sort((a, b) => a.type.localeCompare(b.type) || a.nom.localeCompare(b.nom))
      break
    case 'degats_base':
      sorted.sort((a, b) => compareNumeric(a.degats_base, b.degats_base) || a.nom.localeCompare(b.nom))
      break
    case 'degats_de':
      sorted.sort((a, b) => compareNumeric(a.degats_de, b.degats_de) || a.nom.localeCompare(b.nom))
      break
    case 'precision':
      sorted.sort((a, b) => compareNumeric(a.precision, b.precision) || a.nom.localeCompare(b.nom))
      break
    case 'effet':
      sorted.sort((a, b) => Number(!!b.effet) - Number(!!a.effet) || a.nom.localeCompare(b.nom))
      break
    default:
      sorted.sort((a, b) => a.nom.localeCompare(b.nom))
  }
  return sorted
}

export function AdminAttacksPanel() {
  const { attacks, loading } = useAttacks()
  const [search, setSearch] = useState('')
  const [sortKey, setSortKey] = useState<SortKey>('nom')
  const [typeFilter, setTypeFilter] = useState('')

  const availableTypes = useMemo(
    () => [...new Set(attacks.map((a) => a.type))].sort(),
    [attacks]
  )

  const filtered = useMemo(() => {
    const q = normalizeSearch(search.trim())
    let list = q ? attacks.filter((a) => normalizeSearch(a.nom).includes(q)) : attacks
    if (typeFilter) list = list.filter((a) => a.type === typeFilter)
    return sortAttacks(list, sortKey)
  }, [attacks, search, typeFilter, sortKey])

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">💥</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Capacités</h3>
      </div>

      <div className="flex flex-col sm:flex-row gap-2 mb-5">
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Rechercher une attaque…"
          className="flex-1 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
        />
        <select
          value={typeFilter}
          onChange={(e) => setTypeFilter(e.target.value)}
          className="bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
        >
          <option value="">Tous les types</option>
          {availableTypes.map((t) => (
            <option key={t} value={t}>{t}</option>
          ))}
        </select>
        <select
          value={sortKey}
          onChange={(e) => setSortKey(e.target.value as SortKey)}
          className="bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
        >
          {SORT_OPTIONS.map((o) => (
            <option key={o.id} value={o.id}>Trier par : {o.label}</option>
          ))}
        </select>
      </div>

      {loading ? (
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      ) : filtered.length === 0 ? (
        <p className="text-ink-muted-2 text-sm">Aucune capacité.</p>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
          {filtered.map((a) => (
            <div key={a.nom} className="bg-cream-secondary border-2 border-ink rounded-lg p-3">
              <div className="flex items-center gap-2 mb-2 min-w-0">
                <TypeBadge type={a.type} small />
                <span className="text-ink text-sm font-bold truncate">{a.nom}</span>
              </div>
              <AttackDetailCard attack={a} />
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
