import { useMemo, useState } from 'react'
import { usePlayers } from '../hooks/usePlayers'
import { useItems } from '../hooks/useItems'
import { usePokemon } from '../hooks/usePokemon'
import { useHistoryEvents } from '../hooks/useHistoryEvents'
import { useDisplayState } from '../hooks/useDisplayState'
import { useDisplayAssets } from '../hooks/useDisplayAssets'
import type { ReferenceEntry } from '../hooks/useReferenceIndex'
import { groupHistoryEvents, type DisplayHistoryEntry } from '../lib/historyGrouping'
import { buildSentenceParts, sentenceToPlainText, type SentenceContext, type SentencePart } from '../lib/historySentences'
import { ReferenceDispatcher } from './campaign/ReferenceDispatcher'
import type { HistoryCategory } from '../types'

const CATEGORY_LABELS: Record<HistoryCategory, string> = {
  inventory: 'Inventaire',
  pokedex: 'Pokédex',
  team: 'Équipe / PC',
  combat: 'Combat',
}

// Supprime les diacritiques (accents) après décomposition NFD, pour une
// recherche insensible aux accents ("pokedollar" trouve "Pokédollar").
const DIACRITICS_REGEX = /[̀-ͯ]/g

function normalize(s: string): string {
  return s.toLowerCase().normalize('NFD').replace(DIACRITICS_REGEX, '')
}

function Sentence({ parts, onRefClick }: { parts: SentencePart[]; onRefClick: (entry: ReferenceEntry) => void }) {
  return (
    <>
      {parts.map((part, i) =>
        'text' in part ? (
          <span key={i}>{part.text}</span>
        ) : (
          <span key={i} className="ref-highlight" onClick={() => onRefClick(part.ref)}>
            {part.ref.icon && (
              <img
                src={part.ref.icon}
                alt=""
                className={`ref-icon ${part.ref.type === 'pokemon' ? 'ref-icon-pokemon' : part.ref.type === 'player' ? 'ref-icon-player' : ''}`}
              />
            )}
            {part.label ?? part.ref.name}
          </span>
        )
      )}
    </>
  )
}

function formatTimestamp(iso: string): string {
  return new Date(iso).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' })
}

export function AdminHistoryPanel() {
  const { players, loading: playersLoading } = usePlayers()
  const { byName: itemsByName } = useItems()
  const { pokemon } = usePokemon()
  const { events, loading: eventsLoading } = useHistoryEvents()
  const { state: displayState, updateDisplayState } = useDisplayState()
  const { assets: displayAssets } = useDisplayAssets()

  const [playerFilter, setPlayerFilter] = useState<number | 'all'>('all')
  const [categoryFilter, setCategoryFilter] = useState<HistoryCategory | 'all'>('all')
  const [search, setSearch] = useState('')
  const [activeReference, setActiveReference] = useState<ReferenceEntry | null>(null)

  const playersById = useMemo(() => new Map(players.map((p) => [p.id, p])), [players])
  const playersByName = useMemo(() => new Map(players.map((p) => [p.name, p])), [players])
  const pokemonByName = useMemo(() => new Map(pokemon.map((p) => [p.nom, p])), [pokemon])

  const sentenceCtx: SentenceContext = useMemo(
    () => ({ playersById, pokemonByName, itemsByName }),
    [playersById, pokemonByName, itemsByName]
  )

  const grouped = useMemo(() => groupHistoryEvents(events), [events])

  const rows = useMemo(() => {
    const withSentences = grouped.map((entry) => {
      const parts = buildSentenceParts(entry, sentenceCtx)
      return { entry, parts, plainText: sentenceToPlainText(parts) }
    })
    const q = normalize(search.trim())
    return withSentences.filter(({ entry, plainText }) => {
      if (playerFilter !== 'all' && entry.player_id !== playerFilter) return false
      if (categoryFilter !== 'all' && entry.category !== categoryFilter) return false
      if (q && !normalize(plainText).includes(q)) return false
      return true
    })
  }, [grouped, sentenceCtx, playerFilter, categoryFilter, search])

  const loading = playersLoading || eventsLoading

  const avatar = (entry: DisplayHistoryEntry) => {
    const p = playersById.get(entry.player_id)
    return (
      <div className="w-8 h-8 rounded-full overflow-hidden shrink-0 border-2" style={{ borderColor: p?.color ?? '#a3841a' }}>
        {p?.image_url ? (
          <img src={p.image_url} alt={p.name} className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full" style={{ backgroundColor: p?.color ?? '#a3841a' }} />
        )}
      </div>
    )
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] max-w-2xl w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <h3 className="text-[#a3841a] text-lg font-bold">Historique</h3>
      </div>

      <div className="flex flex-wrap gap-2 mb-4">
        <select
          value={playerFilter}
          onChange={(e) => setPlayerFilter(e.target.value === 'all' ? 'all' : Number(e.target.value))}
          className="bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
        >
          <option value="all">Tous les joueurs</option>
          {players.map((p) => (
            <option key={p.id} value={p.id}>{p.name}</option>
          ))}
        </select>
        <select
          value={categoryFilter}
          onChange={(e) => setCategoryFilter(e.target.value as HistoryCategory | 'all')}
          className="bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
        >
          <option value="all">Toutes les catégories</option>
          {(Object.keys(CATEGORY_LABELS) as HistoryCategory[]).map((c) => (
            <option key={c} value={c}>{CATEGORY_LABELS[c]}</option>
          ))}
        </select>
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Rechercher…"
          className="flex-1 min-w-[140px] bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
        />
      </div>

      {loading ? (
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      ) : rows.length === 0 ? (
        <p className="text-ink-muted-2 text-sm">Aucun événement pour l'instant.</p>
      ) : (
        <div className="flex flex-col gap-1.5 max-h-[70vh] overflow-y-auto">
          {rows.map(({ entry, parts }) => (
            <div key={entry.key} className="flex items-start gap-2.5 bg-cream-secondary border-2 border-ink rounded px-2.5 py-2">
              {avatar(entry)}
              <p className="flex-1 text-ink text-sm leading-snug">
                <Sentence parts={parts} onRefClick={setActiveReference} />
              </p>
              <span className="text-ink-muted-2 text-[11px] shrink-0 whitespace-nowrap">{formatTimestamp(entry.created_at)}</span>
            </div>
          ))}
        </div>
      )}

      <ReferenceDispatcher
        activeReference={activeReference}
        pokemonByName={pokemonByName}
        attacksByName={new Map()}
        itemsByName={itemsByName}
        playersByName={playersByName}
        locationsByName={new Map()}
        encountersByLieu={new Map()}
        displayState={displayState}
        displayAssets={displayAssets}
        updateDisplayState={updateDisplayState}
        onClose={() => setActiveReference(null)}
      />
    </div>
  )
}
