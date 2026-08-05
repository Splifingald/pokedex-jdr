import { useMemo } from 'react'
import type { MiningGrid, MiningGridItem, MiningGridCell, MiningMove, Player, Item } from '../types'
import { rowLetter, jigsawSliceStyle } from '../lib/mining'
import { MiningMoveFeed } from './MiningMoveFeed'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'

interface Props {
  grid: MiningGrid | null
  items: MiningGridItem[]
  cells: MiningGridCell[]
  moves: MiningMove[]
  loading: boolean
  players: Player[]
  itemsByName: Map<string, Item>
  ticketCount: number
  hiddenCellImageUrl: string
  emptyCellImageUrl: string
  now: number
  onDigCell: (cellIndex: number) => void
}

export function MiningGridGame({ grid, items, cells, moves, loading, players, itemsByName, ticketCount, hiddenCellImageUrl, emptyCellImageUrl, now, onDigCell }: Props) {
  const cellsByIndex = useMemo(() => {
    const map = new Map<number, MiningGridCell>()
    for (const c of cells) map.set(c.cell_index, c)
    return map
  }, [cells])

  const itemsById = useMemo(() => {
    const map = new Map<number, MiningGridItem>()
    for (const it of items) map.set(it.id, it)
    return map
  }, [items])

  const playersById = useMemo(() => {
    const map = new Map<number, Player>()
    for (const p of players) map.set(p.id, p)
    return map
  }, [players])

  if (loading || !grid) {
    return <p className="text-ink-muted-2 text-sm text-center py-6">Chargement de la grille…</p>
  }

  const exhausted = grid.moves_used >= grid.move_budget
  const size = grid.size

  return (
    <div className="flex flex-col gap-4">
      <div className={`p-2 rounded ${PIXEL_BORDER_SM} bg-cream-secondary`}>
        <div className="flex justify-between text-xs text-ink-muted-2 mb-1">
          <span>Coups avant effondrement du mur</span>
          <span>{grid.moves_used} / {grid.move_budget}</span>
        </div>
        <div className="h-2 rounded bg-white/60 overflow-hidden">
          <div
            className="h-full bg-[#c98a3e]"
            style={{ width: `${Math.min(100, (grid.moves_used / grid.move_budget) * 100)}%` }}
          />
        </div>
        {exhausted && (
          <p className="text-ink-muted-2 text-xs mt-1 italic">Grille épuisée — une nouvelle grille sera générée au prochain coup.</p>
        )}
      </div>

      {/* Boîte carrée dont le côté = min(largeur disponible, 45% de la hauteur
          de l'écran) — garantit que la grille entière reste visible sans
          défilement, quelle que soit sa taille (contrairement à une largeur de
          case minimale fixe, qui forçait un défilement horizontal sur les
          grandes grilles / petits écrans). */}
      <div className="mx-auto w-full" style={{ maxWidth: 'min(100%, 45vh)', aspectRatio: '1 / 1' }}>
        <div
          className="grid gap-0.5 w-full h-full"
          style={{ gridTemplateColumns: `28px repeat(${size}, 1fr)`, gridTemplateRows: `28px repeat(${size}, 1fr)` }}
        >
          <div key="corner" />
          {Array.from({ length: size }, (_, col) => (
            <div key={`col-${col}`} className="text-ink-muted-2 text-[10px] font-bold text-center">
              {col + 1}
            </div>
          ))}

          {Array.from({ length: size }, (_, row) => [
            <div key={`row-${row}`} className="text-ink-muted-2 text-[10px] font-bold flex items-center justify-center">
              {rowLetter(row)}
            </div>,
            ...Array.from({ length: size }, (_, col) => {
              const cellIndex = row * size + col
              const cell = cellsByIndex.get(cellIndex)
              const dug = cell?.dug ?? false
              const gridItem = cell?.item_id ? itemsById.get(cell.item_id) : undefined
              const catalogItem = gridItem ? itemsByName.get(gridItem.item_nom) : undefined
              const discoverer = cell?.dug_by_player_id ? playersById.get(cell.dug_by_player_id) : undefined

              if (!dug) {
                return (
                  <button
                    key={cellIndex}
                    onClick={() => onDigCell(cellIndex)}
                    disabled={ticketCount < 1 || exhausted}
                    className={`w-full h-full min-w-0 min-h-0 rounded ${PIXEL_BORDER_SM} bg-[#e0c185] hover:bg-[#e8ce9c] active:scale-95 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center text-ink text-xs font-bold overflow-hidden`}
                  >
                    {hiddenCellImageUrl ? (
                      <img src={hiddenCellImageUrl} alt="" className="w-full h-full object-contain pixelated" />
                    ) : (
                      '?'
                    )}
                  </button>
                )
              }

              const discovererStyle = discoverer ? { borderColor: discoverer.color } : undefined

              if (gridItem && catalogItem?.image_url) {
                const style = jigsawSliceStyle(gridItem, row, col, catalogItem.image_url)
                return (
                  <div
                    key={cellIndex}
                    title={catalogItem.nom}
                    className={`w-full h-full min-w-0 min-h-0 rounded border-[3px] border-ink ${gridItem.completed ? 'ring-2 ring-yellow-400' : ''}`}
                    style={{ ...style, backgroundRepeat: 'no-repeat', ...discovererStyle }}
                  />
                )
              }

              return (
                <div
                  key={cellIndex}
                  className="w-full h-full min-w-0 min-h-0 rounded border-[3px] border-ink bg-[#cbb894] flex items-center justify-center overflow-hidden"
                  style={discovererStyle}
                >
                  {emptyCellImageUrl && (
                    <img src={emptyCellImageUrl} alt="" className="w-full h-full object-contain pixelated" />
                  )}
                </div>
              )
            }),
          ])}
        </div>
      </div>

      <div>
        <p className="text-ink-muted-2 text-sm mb-2 font-bold">Historique</p>
        <MiningMoveFeed moves={moves} gridSize={size} playersById={playersById} itemsById={itemsById} itemsByName={itemsByName} now={now} />
      </div>
    </div>
  )
}
