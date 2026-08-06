import { useState, useMemo } from 'react'
import type { Pokemon, Item, Player } from '../types'
import { useHistoryEvents } from '../hooks/useHistoryEvents'
import { usePlayers } from '../hooks/usePlayers'
import { groupHistoryEvents } from '../lib/historyGrouping'
import { buildSentenceParts, sentenceToPlainText, type SentenceContext } from '../lib/historySentences'
import { formatMoveTimestamp } from '../lib/mining'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  pokemonByName: Map<string, Pokemon>
  itemsByName: Map<string, Item>
}

function FeedAvatar({ player }: { player?: Player }) {
  return (
    <div className="w-6 h-6 rounded-full overflow-hidden shrink-0 border-2" style={{ borderColor: player?.color ?? '#a3841a' }}>
      {player?.image_url ? (
        <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
      ) : (
        <div className="w-full h-full" style={{ backgroundColor: player?.color ?? '#a3841a' }} />
      )}
    </div>
  )
}

const VISIBLE_COUNT = 5

// Flux des actions liées à la Pension (dépôts, retraits, appariements
// compatibles, œufs reçus) — même principe que MiningMoveFeed pour Fouille,
// mais réutilise le journal global (history_events, catégorie 'daycare')
// plutôt qu'une table de coups dédiée.
export function PensionHistoryFeed({ pokemonByName, itemsByName }: Props) {
  const { events, loading } = useHistoryEvents()
  const { players } = usePlayers()
  const [showAll, setShowAll] = useState(false)
  const [now] = useState(() => Date.now())

  const playersById = useMemo(() => new Map(players.map((p) => [p.id, p])), [players])
  const sentenceCtx: SentenceContext = useMemo(() => ({ playersById, pokemonByName, itemsByName }), [playersById, pokemonByName, itemsByName])

  const daycareEntries = useMemo(
    () => groupHistoryEvents(events).filter((e) => e.category === 'daycare'),
    [events]
  )

  if (loading) return null
  if (daycareEntries.length === 0) {
    return <p className="text-ink-muted-2 text-sm italic text-center py-3">Aucune activité récente à la pension.</p>
  }

  const visible = showAll ? daycareEntries : daycareEntries.slice(0, VISIBLE_COUNT)

  return (
    <div className="flex flex-col gap-1.5 max-h-48 overflow-y-auto">
      {visible.map((entry) => {
        const player = playersById.get(entry.player_id)
        const parts = buildSentenceParts(entry, sentenceCtx)
        return (
          <div key={entry.key} className="flex items-center gap-2 text-sm">
            <FeedAvatar player={player} />
            <span className="text-ink flex-1 min-w-0 truncate">{sentenceToPlainText(parts)}</span>
            <span className="text-ink-muted-2 text-xs shrink-0">{formatMoveTimestamp(entry.created_at, new Date(now))}</span>
          </div>
        )
      })}
      {!showAll && daycareEntries.length > VISIBLE_COUNT && (
        <button
          onClick={() => setShowAll(true)}
          className={`self-center mt-1 px-3 py-1 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}
        >
          Charger plus
        </button>
      )}
    </div>
  )
}
