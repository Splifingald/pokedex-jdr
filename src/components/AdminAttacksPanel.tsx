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

  const filtered = useMemo(() => {
    const q = normalizeSearch(search.trim())
    const list = q ? attacks.filter((a) => normalizeSearch(a.nom).includes(q)) : attacks
    return sortAttacks(list, sortKey)
  }, [attacks, search, sortKey])

  return (
    <div className="bg-gray-900 border-2 border-yellow-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-2xl w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">💥</span>
        <h3 className="text-yellow-400 text-lg">Capacités</h3>
      </div>

      <div className="flex flex-col sm:flex-row gap-2 mb-5">
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Rechercher une attaque…"
          className="flex-1 bg-gray-800 border border-gray-600 rounded px-3 py-2 text-white text-sm outline-none focus:border-red-400"
        />
        <select
          value={sortKey}
          onChange={(e) => setSortKey(e.target.value as SortKey)}
          className="bg-gray-800 border border-gray-600 rounded px-3 py-2 text-white text-sm outline-none focus:border-red-400"
        >
          {SORT_OPTIONS.map((o) => (
            <option key={o.id} value={o.id}>Trier par : {o.label}</option>
          ))}
        </select>
      </div>

      {loading ? (
        <p className="text-gray-500 text-sm">Chargement…</p>
      ) : filtered.length === 0 ? (
        <p className="text-gray-500 text-sm">Aucune capacité.</p>
      ) : (
        <div className="flex flex-col gap-3">
          {filtered.map((a) => (
            <div key={a.nom} className="bg-gray-800 border border-gray-700 rounded-lg p-3">
              <div className="flex items-center gap-2 mb-2 min-w-0">
                <TypeBadge type={a.type} small />
                <span className="text-white text-sm font-bold truncate">{a.nom}</span>
              </div>
              <AttackDetailCard attack={a} />
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
