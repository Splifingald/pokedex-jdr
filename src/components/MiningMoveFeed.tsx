import { useState } from 'react'
import type { MiningMove, MiningGridItem, Player, Item } from '../types'
import { cellLabel, formatMoveTimestamp } from '../lib/mining'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  moves: MiningMove[]
  gridSize: number
  playersById: Map<number, Player>
  itemsById: Map<number, MiningGridItem>
  itemsByName: Map<string, Item>
  now: number
}

function MoveAvatar({ player }: { player?: Player }) {
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

const VISIBLE_COUNT = 3

// Flux des coups joués sur la grille active, distinct de l'historique global
// (Admin → Historique) : chaque case creusée y apparaît, pas seulement les
// objets trouvés — voir supabase/schema.sql (table mining_moves) pour le détail.
export function MiningMoveFeed({ moves, gridSize, playersById, itemsById, itemsByName, now }: Props) {
  const [showAll, setShowAll] = useState(false)

  if (moves.length === 0) {
    return <p className="text-ink-muted-2 text-xs italic text-center py-3">Aucun coup joué pour l'instant.</p>
  }

  const visible = showAll ? moves : moves.slice(0, VISIBLE_COUNT)

  return (
    <div className="flex flex-col gap-1.5 max-h-48 overflow-y-auto">
      {visible.map((move) => {
        const player = playersById.get(move.player_id)
        const label = cellLabel(move.cell_index, gridSize)
        const gridItem = move.item_id ? itemsById.get(move.item_id) : undefined
        const catalogItem = gridItem ? itemsByName.get(gridItem.item_nom) : undefined

        return (
          <div key={move.id} className="flex items-center gap-2 text-xs">
            <MoveAvatar player={player} />
            <span className="text-ink flex-1 min-w-0 truncate">
              <strong>{player?.name ?? 'Joueur inconnu'}</strong>
              {move.item_completed && gridItem ? (
                <>
                  {' '}a trouvé <strong>{catalogItem?.nom ?? gridItem.item_nom}</strong> en zone {label} !
                </>
              ) : (
                <> a découvert la zone {label}</>
              )}
            </span>
            <span className="text-ink-muted-2 text-[10px] shrink-0">{formatMoveTimestamp(move.created_at, new Date(now))}</span>
          </div>
        )
      })}
      {!showAll && moves.length > VISIBLE_COUNT && (
        <button
          onClick={() => setShowAll(true)}
          className={`self-center mt-1 px-3 py-1 rounded text-[11px] font-bold ${BUTTON_STYLE.gray}`}
        >
          Charger plus
        </button>
      )}
    </div>
  )
}
