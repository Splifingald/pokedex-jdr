import { useState, useEffect, useLayoutEffect, useMemo, useRef } from 'react'
import type { MiningGrid, MiningGridItem, MiningGridCell, Player, Item } from '../types'
import { rowLetter, jigsawSliceStyle } from '../lib/mining'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Snapshot {
  grid: MiningGrid
  items: MiningGridItem[]
  cells: MiningGridCell[]
}

interface Props {
  snapshot: Snapshot
  itemsByName: Map<string, Item>
  playersById: Map<number, Player>
  hiddenCellImageUrl: string
  emptyCellImageUrl: string
  onDone: () => void
}

const REVEAL_INTERVAL_MS = 300
const SETTLE_DELAY_MS = 500

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr]
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

// Mesure l'espace réellement disponible (texte + éventuel bouton en prennent
// une part variable) et renvoie le côté du plus grand carré qui y tient —
// garantit que la grille ET le bouton "Continuer" restent visibles sans
// défilement, quelle que soit la taille de l'écran ou la taille de la grille.
function useSquareSide(): [React.RefObject<HTMLDivElement | null>, number] {
  const ref = useRef<HTMLDivElement>(null)
  const [side, setSide] = useState(0)

  // Mesure synchrone (avant peinture) au montage pour éviter un flash à 0px
  // le temps que ResizeObserver livre sa première notification, qui reste
  // ensuite en place pour suivre les changements ultérieurs (redimensionnement
  // de la fenêtre, apparition du bouton "Continuer").
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const measure = () => {
      const rect = el.getBoundingClientRect()
      setSide(Math.max(0, Math.min(rect.width, rect.height)))
    }
    measure()
    const observer = new ResizeObserver(measure)
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  return [ref, side]
}

// Grille statique de fin de partie : révèle une à une (ordre mélangé, un
// intervalle fixe) toutes les cases qui n'avaient pas été creusées avant que
// la grille ne s'épuise, en partant de son état réel (les cases déjà
// creusées restent telles quelles, sans animation). Une fois la révélation
// terminée, un bouton "Continuer" apparaît — aucune fermeture automatique ni
// par clic sur le fond.
export function MiningGridExhaustedPopup({ snapshot, itemsByName, playersById, hiddenCellImageUrl, emptyCellImageUrl, onDone }: Props) {
  const { grid, items, cells } = snapshot
  const size = grid.size
  const [squareRef, squareSide] = useSquareSide()

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

  // Ordre de révélation : mélangé une seule fois, tant que `cells` (figé par
  // le snapshot du parent) ne change pas — en pratique une seule fois pour
  // toute la durée de vie de ce popup.
  const revealOrder = useMemo(() => shuffle(cells.filter((c) => !c.dug).map((c) => c.cell_index)), [cells])

  const [revealedCount, setRevealedCount] = useState(0)
  const allRevealed = revealedCount >= revealOrder.length
  const [showButton, setShowButton] = useState(false)

  useEffect(() => {
    if (allRevealed) return
    const timer = window.setTimeout(() => setRevealedCount((n) => n + 1), REVEAL_INTERVAL_MS)
    return () => clearTimeout(timer)
  }, [allRevealed, revealedCount])

  useEffect(() => {
    if (!allRevealed) return
    const settleTimer = window.setTimeout(() => setShowButton(true), SETTLE_DELAY_MS)
    return () => clearTimeout(settleTimer)
  }, [allRevealed])

  const revealedIndices = useMemo(() => new Set(revealOrder.slice(0, revealedCount)), [revealOrder, revealedCount])

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="relative bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-2xl w-full h-[min(90vh,640px)] p-6 flex flex-col gap-4">
        {/* Hauteur fixe (pas "h-auto") : un enfant flex-1 (flex-basis 0%) n'a
            aucun espace où grandir dans un conteneur dont la hauteur dépend
            de son propre contenu — la grille se retrouverait à 0px. */}
        <p className="text-ink text-base text-center shrink-0">
          Le mur est trop endommagé, vous ne pouvez plus creuser ici, cherchons un autre mur.
        </p>
        <div ref={squareRef} className="flex-1 min-h-0 min-w-0 flex items-center justify-center">
          <div style={{ width: squareSide, height: squareSide }}>
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
                  const wasAlreadyDug = cell?.dug ?? false
                  const justRevealed = !wasAlreadyDug && revealedIndices.has(cellIndex)
                  const isRevealed = wasAlreadyDug || justRevealed

                  if (!isRevealed) {
                    return (
                      <div
                        key={cellIndex}
                        className={`w-full h-full min-w-0 min-h-0 rounded ${PIXEL_BORDER_SM} bg-[#e0c185] flex items-center justify-center text-ink text-xs font-bold`}
                      >
                        {hiddenCellImageUrl ? (
                          <img src={hiddenCellImageUrl} className="w-full h-full object-contain pixelated" alt="" />
                        ) : (
                          '?'
                        )}
                      </div>
                    )
                  }

                  const gridItem = cell?.item_id ? itemsById.get(cell.item_id) : undefined
                  const catalogItem = gridItem ? itemsByName.get(gridItem.item_nom) : undefined
                  const discoverer = cell?.dug_by_player_id ? playersById.get(cell.dug_by_player_id) : undefined
                  const popClass = justRevealed ? ' animate-[celebrate-pop_0.3s_ease-out]' : ''

                  if (gridItem && catalogItem?.image_url) {
                    const style = jigsawSliceStyle(gridItem, row, col, catalogItem.image_url)
                    return (
                      <div
                        key={cellIndex}
                        title={catalogItem.nom}
                        className={`w-full h-full min-w-0 min-h-0 rounded border-[3px] border-ink${popClass}`}
                        style={{ ...style, backgroundRepeat: 'no-repeat', ...(discoverer ? { borderColor: discoverer.color } : {}) }}
                      />
                    )
                  }

                  return (
                    <div
                      key={cellIndex}
                      className={`w-full h-full min-w-0 min-h-0 rounded border-[3px] border-ink bg-[#cbb894] flex items-center justify-center overflow-hidden${popClass}`}
                      style={discoverer ? { borderColor: discoverer.color } : undefined}
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
        </div>

        {showButton && (
          <button
            onClick={onDone}
            className={`shrink-0 self-center px-6 py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.yellow}`}
          >
            Continuer
          </button>
        )}
      </div>
    </div>
  )
}
