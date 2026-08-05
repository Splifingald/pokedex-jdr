import { useEffect, useMemo, useRef, useState } from 'react'
import Papa from 'papaparse'
import { usePlayers } from '../hooks/usePlayers'
import { useItems } from '../hooks/useItems'
import { usePokemon } from '../hooks/usePokemon'
import { useAttacks } from '../hooks/useAttacks'
import { useHistoryEvents } from '../hooks/useHistoryEvents'
import { usePlayerPokemon } from '../hooks/usePlayerPokemon'
import { useAdminParameters } from '../hooks/useAdminParameters'
import type { ReferenceEntry } from '../hooks/useReferenceIndex'
import { groupHistoryEvents, type DisplayHistoryEntry } from '../lib/historyGrouping'
import { buildSentenceParts, sentenceToPlainText, type SentenceContext, type SentencePart } from '../lib/historySentences'
import { normalizeSearch } from '../lib/normalizeSearch'
import { ReferenceDispatcher } from './campaign/ReferenceDispatcher'
import { PokemonDetailSheet } from './PokemonDetailSheet'
import { ConfirmPopup } from './ConfirmPopup'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import type { Player, Pokemon, Attack, HistoryCategory, HistoryInventoryPayload, HistoryTeamPayload, HistoryCombatPayload } from '../types'

const CATEGORY_LABELS: Record<HistoryCategory, string> = {
  inventory: 'Inventaire',
  pokedex: 'Pokédex',
  team: 'Équipe / PC',
  combat: 'Combat',
  minigame: 'Mini-Jeux',
  daycare: 'Pension',
}

function Avatar({ player, size = 8 }: { player?: Player; size?: 5 | 8 }) {
  const px = size === 5 ? 'w-5 h-5' : 'w-8 h-8'
  return (
    <div className={`${px} rounded-full overflow-hidden shrink-0 border-2`} style={{ borderColor: player?.color ?? '#a3841a' }}>
      {player?.image_url ? (
        <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
      ) : (
        <div className="w-full h-full" style={{ backgroundColor: player?.color ?? '#a3841a' }} />
      )}
    </div>
  )
}

// Sélecteur de joueur cherchable — remplace un <select> simple : bouton affichant
// le joueur choisi (avatar + nom) qui ouvre un panneau avec recherche + liste d'avatars.
function PlayerFilterDropdown({
  players,
  playersById,
  value,
  onChange,
}: {
  players: Player[]
  playersById: Map<number, Player>
  value: number | 'all'
  onChange: (v: number | 'all') => void
}) {
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState('')
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const handler = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) setOpen(false)
    }
    window.addEventListener('mousedown', handler)
    return () => window.removeEventListener('mousedown', handler)
  }, [open])

  const filtered = useMemo(() => {
    const q = normalizeSearch(query.trim())
    if (!q) return players
    return players.filter((p) => normalizeSearch(p.name).includes(q))
  }, [players, query])

  const selectedPlayer = value !== 'all' ? playersById.get(value) : undefined

  const select = (v: number | 'all') => {
    onChange(v)
    setOpen(false)
    setQuery('')
  }

  return (
    <div className="relative" ref={containerRef}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-1.5 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none min-w-[170px]"
      >
        {selectedPlayer && <Avatar player={selectedPlayer} size={5} />}
        <span className="flex-1 text-left truncate">{selectedPlayer ? selectedPlayer.name : 'Tous les joueurs'}</span>
        <span className="text-ink-muted-2 text-xs">▾</span>
      </button>
      {open && (
        <div className="absolute z-10 top-full left-0 mt-1 w-64 bg-cream border-2 border-ink rounded-lg shadow-[var(--shadow-pixel)] max-h-72 overflow-hidden flex flex-col">
          <input
            autoFocus
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Rechercher un joueur…"
            className="w-full bg-white border-b-2 border-ink px-3 py-2 text-ink text-sm outline-none shrink-0"
          />
          <div className="overflow-y-auto">
            <button
              onClick={() => select('all')}
              className="w-full flex items-center gap-2 px-3 py-2 border-b border-[#cfc7a8] hover:bg-cream-secondary transition-colors text-left"
            >
              <span className="text-ink text-sm">Tous les joueurs</span>
            </button>
            {filtered.length === 0 ? (
              <p className="text-ink-muted-2 text-sm px-3 py-2">Aucun résultat</p>
            ) : (
              filtered.map((p) => (
                <button
                  key={p.id}
                  onClick={() => select(p.id)}
                  className="w-full flex items-center gap-2 px-3 py-2 border-b border-[#cfc7a8] last:border-b-0 hover:bg-cream-secondary transition-colors text-left"
                >
                  <Avatar player={p} size={5} />
                  <span className="text-ink text-sm truncate">{p.name}</span>
                </button>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  )
}

// Fiche complète (PV/statut/XP éditables) d'une instance possédée, ouverte quand une
// ligne "Équipe / PC" ou "Combat" référence un Pokémon précis — même vue que depuis
// l'onglet Équipe du joueur, sans barre "Ajouter à l'affichage" (pas pertinent ici).
function HistoryOwnedPokemonPopup({
  playerId,
  playerPokemonId,
  isNpc,
  pokemonByName,
  attacksByName,
  onClose,
}: {
  playerId: number
  playerPokemonId: number
  isNpc: boolean
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  onClose: () => void
}) {
  const { roster, updateXp, updateNickname, toggleInTeam, deleteOwnedPokemon } = usePlayerPokemon(playerId)
  const { parameters } = useAdminParameters()
  const found = roster.find((r) => r.id === playerPokemonId)
  if (!found) return null

  const team = roster.filter((r) => r.in_team)
  const teamFull = isNpc ? false : team.length >= parameters.max_team_size

  return (
    <PokemonDetailSheet
      context="pokemon"
      pokemon={pokemonByName.get(found.pokemon_nom)}
      playerPokemon={found}
      attacksByName={attacksByName}
      isAdmin={true}
      teamFull={teamFull}
      isNpc={isNpc}
      maxMoves={parameters.max_moves}
      onUpdateXp={updateXp}
      onRename={updateNickname}
      onToggleInTeam={toggleInTeam}
      onDelete={deleteOwnedPokemon}
      onClose={onClose}
    />
  )
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
  const { byName: attacksByName } = useAttacks()
  const { events, loading: eventsLoading, clearAll } = useHistoryEvents()

  const [playerFilter, setPlayerFilter] = useState<number | 'all'>('all')
  const [categoryFilter, setCategoryFilter] = useState<HistoryCategory | 'all'>('all')
  const [search, setSearch] = useState('')
  const [activeReference, setActiveReference] = useState<ReferenceEntry | null>(null)
  const [ownedPokemonTarget, setOwnedPokemonTarget] = useState<{ playerId: number; playerPokemonId: number } | null>(null)
  const [confirmingClear, setConfirmingClear] = useState(false)

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
    const q = normalizeSearch(search.trim())
    return withSentences.filter(({ entry, plainText }) => {
      if (playerFilter !== 'all' && entry.player_id !== playerFilter) return false
      if (categoryFilter !== 'all' && entry.category !== categoryFilter) return false
      if (q && !normalizeSearch(plainText).includes(q)) return false
      return true
    })
  }, [grouped, sentenceCtx, playerFilter, categoryFilter, search])

  const loading = playersLoading || eventsLoading

  const handleRefClick = (ref: ReferenceEntry, entry: DisplayHistoryEntry) => {
    // Un Pokémon référencé par une ligne Équipe/PC ou Combat désigne une instance
    // possédée précise : on ouvre sa fiche complète plutôt que la fiche espèce.
    if (ref.type === 'pokemon' && (entry.category === 'team' || entry.category === 'combat')) {
      const payload = entry.payload as HistoryTeamPayload | HistoryCombatPayload
      setOwnedPokemonTarget({ playerId: entry.player_id, playerPokemonId: payload.player_pokemon_id })
      return
    }
    setActiveReference(ref)
  }

  const handleExportCsv = () => {
    const csvRows = rows.map(({ entry, plainText }) => {
      const isInventory = entry.category === 'inventory'
      const payload = isInventory ? (entry.payload as HistoryInventoryPayload) : null
      return {
        Player: playersById.get(entry.player_id)?.name ?? 'Joueur inconnu',
        Type: CATEGORY_LABELS[entry.category],
        Date: formatTimestamp(entry.created_at),
        Description: plainText,
        Item: payload?.item_nom ?? '',
        Quantity: payload?.delta ?? '',
      }
    })
    const csv = Papa.unparse(csvRows)
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `historique_${new Date().toISOString().slice(0, 10)}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  const handleClearAll = async () => {
    await clearAll()
    setConfirmingClear(false)
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <h3 className="text-[#a3841a] text-lg font-bold">Historique</h3>
      </div>

      <div className="flex flex-wrap items-center gap-2 mb-4">
        <PlayerFilterDropdown players={players} playersById={playersById} value={playerFilter} onChange={setPlayerFilter} />
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
        <div className="flex gap-2 ml-auto">
          <button onClick={handleExportCsv} className={`text-sm px-3 py-2 rounded font-bold whitespace-nowrap ${BUTTON_STYLE.blue}`}>
            Exporter CSV
          </button>
          <button onClick={() => setConfirmingClear(true)} className={`text-sm px-3 py-2 rounded font-bold whitespace-nowrap ${BUTTON_STYLE.red}`}>
            Vider l'historique
          </button>
        </div>
      </div>

      {loading ? (
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      ) : rows.length === 0 ? (
        <p className="text-ink-muted-2 text-sm">Aucun événement pour l'instant.</p>
      ) : (
        <div className="flex flex-col gap-1.5 max-h-[70vh] overflow-y-auto">
          {rows.map(({ entry, parts }) => (
            <div key={entry.key} className="flex items-start gap-2.5 bg-cream-secondary border-2 border-ink rounded px-2.5 py-2">
              <Avatar player={playersById.get(entry.player_id)} />
              <p className="flex-1 text-ink text-sm leading-snug">
                <Sentence parts={parts} onRefClick={(ref) => handleRefClick(ref, entry)} />
              </p>
              <span className="text-ink-muted-2 text-sm shrink-0 whitespace-nowrap">{formatTimestamp(entry.created_at)}</span>
            </div>
          ))}
        </div>
      )}

      <ReferenceDispatcher
        activeReference={activeReference}
        pokemonByName={pokemonByName}
        attacksByName={attacksByName}
        itemsByName={itemsByName}
        playersByName={playersByName}
        locationsByName={new Map()}
        encountersByLieu={new Map()}
        showDisplayBar={false}
        onClose={() => setActiveReference(null)}
      />

      {ownedPokemonTarget && (
        <HistoryOwnedPokemonPopup
          playerId={ownedPokemonTarget.playerId}
          playerPokemonId={ownedPokemonTarget.playerPokemonId}
          isNpc={playersById.get(ownedPokemonTarget.playerId)?.is_npc ?? false}
          pokemonByName={pokemonByName}
          attacksByName={attacksByName}
          onClose={() => setOwnedPokemonTarget(null)}
        />
      )}

      {confirmingClear && (
        <ConfirmPopup
          title="Vider tout l'historique ?"
          message="Cette action supprime définitivement toutes les lignes de l'historique. Impossible à annuler."
          confirmLabel="Vider"
          danger
          onConfirm={handleClearAll}
          onCancel={() => setConfirmingClear(false)}
        />
      )}
    </div>
  )
}
