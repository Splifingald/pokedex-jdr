import { useRef, useState, useCallback, useEffect, useMemo } from 'react'
import type { PointerEvent as ReactPointerEvent } from 'react'
import type { OnlineState } from '../../types'
import type { ResolvedToken } from '../../lib/onlineTokens'
import type { BoardPing } from '../../hooks/useOnlinePings'
import type { Cell } from '../../lib/onlineBoard'
import { cellKey, computeGrid, pointToCell, pointToNorm, reachableCells, TILE_COLOR_CSS } from '../../lib/onlineBoard'
import { useFittedBox } from '../../hooks/useFittedBox'
import { useBoardZoom } from '../../hooks/useBoardZoom'
import { BattleToken } from './BattleToken'
import { BattleTokenInfo } from './BattleTokenInfo'
import { BattlePingLayer } from './BattlePingLayer'

/** Ce que le spectateur a le droit de voir. Passé en props et jamais lu dans un
 *  contexte React : ce composant est aussi rendu par /display, monté HORS
 *  PlayerProvider (voir src/main.tsx). */
export interface BoardViewer {
  playerId: number | null
  isAdmin: boolean
  /** PV de tous les jetons visibles en permanence (vue MJ). */
  alwaysShowHp: boolean
}

interface Props {
  state: OnlineState
  backgroundUrl: string
  tokens: ResolvedToken[]
  viewer: BoardViewer
  selectedTokenId: number | null
  /** Cases allumées par la capacité sélectionnée — purement local, jamais diffusé. */
  highlightedCells: Set<string>
  /** true quand l'outil « colorier » du MJ est actif : le clic peint au lieu d'agir. */
  paintMode: boolean
  /** Lecture seule : l'écran /display regarde sans rien pouvoir faire. */
  readOnly: boolean
  pings: BoardPing[]
  canMoveToken: (t: ResolvedToken) => boolean
  onSelectToken: (t: ResolvedToken) => void
  onMoveToken: (t: ResolvedToken, cell: Cell) => void
  /** Clic simple sur une case, hors coloriage : ping côté joueur, blocage côté MJ. */
  onCellActivate: (cell: Cell) => void
  /** Case peinte pendant un glissé (outil coloriage). */
  onCellPaint: (cell: Cell) => void
  /** Le nombre de lignes découle de la forme de l'image, pas d'un réglage : on
   *  le remonte pour le mémoriser, afin que le serveur et le surlignage de
   *  portée travaillent sur la même grille. Absent en lecture seule. */
  onRowsChange?: (rows: number) => void
}

const DRAG_THRESHOLD_PX = 5
const DEFAULT_RATIO = 16 / 9

// Plateau de bataille partagé.
//
// Cadrage « image entière » : la boîte du plateau prend exactement le ratio de
// l'image de fond, centrée sur fond noir. Le rectangle du plateau EST donc
// celui de l'illustration — c'est ce qui garantit que la grille tombe au même
// endroit du décor sur tous les écrans, et que rien n'a besoin d'être stocké en
// pixels (la base ne connaît que des indices de cases).
//
// Toutes les interactions passent par les Pointer Events : un seul chemin de
// code pour la souris, le stylet et le doigt (le drag & drop HTML5 natif,
// utilisé ailleurs dans le projet, ne fonctionne pas au tactile).
export function BattleBoard({
  state, backgroundUrl, tokens, viewer, selectedTokenId, highlightedCells,
  paintMode, readOnly, pings, canMoveToken, onSelectToken, onMoveToken, onCellActivate, onCellPaint, onRowsChange,
}: Props) {
  const wrapperRef = useRef<HTMLDivElement>(null)
  const boardRef = useRef<HTMLDivElement>(null)
  const [ratio, setRatio] = useState(DEFAULT_RATIO)
  const box = useFittedBox(wrapperRef, ratio)
  // Zoom molette/pincement, de « l'image entière » (×1) à ×2. Désactivé sur
  // l'écran /display, que personne ne pilote.
  const zoom = useBoardZoom(wrapperRef, box, !readOnly)

  // Une seule dimension réglable : les cases sont carrées et le nombre de
  // lignes tombe de la forme de l'image (voir computeGrid).
  const grid = useMemo(() => computeGrid(state.grid_cols, ratio), [state.grid_cols, ratio])
  // Vue épurée : on ne garde que le décor et les Pokémon. Partagée par tout le
  // monde, et activée d'office par la fin de partie.
  const bare = state.hide_layout
  const { cols, rows } = grid
  const blocked = useMemo(() => new Set(state.blocked_cells), [state.blocked_cells])

  // Mémorise le nombre de lignes calculé : le garde-fou serveur
  // (online_place_token) et le surlignage de portée s'appuient dessus.
  useEffect(() => {
    if (!onRowsChange || rows === state.grid_rows) return
    onRowsChange(rows)
  }, [rows, state.grid_rows, onRowsChange])

  // État de glissé en refs, pas en state : un re-rendu entre le pointerdown et
  // le premier pointermove détacherait les écouteurs (même raison que
  // RoamingPokemonSprite).
  const dragTokenRef = useRef<ResolvedToken | null>(null)
  const dragStartRef = useRef<{ x: number; y: number } | null>(null)
  const movedRef = useRef(false)
  const paintingRef = useRef(false)
  const lastPaintedRef = useRef<string | null>(null)
  // Pointeurs actifs : à deux doigts on passe en pincement et on annule le
  // glissé en cours, sinon le jeton suivrait l'un des deux doigts.
  const pointersRef = useRef(new Map<number, { x: number; y: number }>())
  const pinchingRef = useRef(false)
  // Le pointerdown a-t-il été retenu ? Un clic droit sort avant tout traitement,
  // mais son pointerup arrive quand même : sans ce drapeau, il retomberait sur
  // le ping et un clic droit bloquerait la case ET pingerait.
  const acceptedDownRef = useRef(false)
  // Panoramique au glissé, une fois zoomé. Les autres gestes ont la priorité :
  // on n'y passe que si aucun jeton n'est saisi et qu'on ne peint pas.
  const panningRef = useRef(false)
  const pannedRef = useRef(false)
  const panLastRef = useRef<{ x: number; y: number } | null>(null)
  // Survol remonté ici : les PV et le dresseur se dessinent dans un calque
  // au-dessus de tous les jetons, donc hors du composant jeton.
  const [hoveredTokenId, setHoveredTokenId] = useState<number | null>(null)
  const [dragTokenId, setDragTokenId] = useState<number | null>(null)
  const [dragPoint, setDragPoint] = useState<{ x: number; y: number } | null>(null)
  const [dragCell, setDragCell] = useState<Cell | null>(null)

  const boardRect = () => boardRef.current?.getBoundingClientRect() ?? null

  const handleTokenPointerDown = useCallback((t: ResolvedToken) => {
    if (readOnly) return
    dragTokenRef.current = t
  }, [readOnly])

  const handlePointerDown = useCallback((e: ReactPointerEvent<HTMLDivElement>) => {
    if (readOnly) return
    // Bouton secondaire : réservé au blocage de case, traité par onContextMenu.
    if (e.button !== 0 && e.pointerType === 'mouse') {
      dragTokenRef.current = null
      return
    }
    const r = boardRect()
    if (!r) return
    acceptedDownRef.current = true
    pointersRef.current.set(e.pointerId, { x: e.clientX, y: e.clientY })
    if (pointersRef.current.size === 2) {
      const [a, b] = [...pointersRef.current.values()]
      pinchingRef.current = true
      dragTokenRef.current = null
      dragStartRef.current = null
      movedRef.current = false
      paintingRef.current = false
      setDragTokenId(null)
      setDragPoint(null)
      setDragCell(null)
      zoom.pinchStart(a, b)
      return
    }
    e.currentTarget.setPointerCapture(e.pointerId)
    dragStartRef.current = { x: e.clientX, y: e.clientY }
    movedRef.current = false

    // Panoramique : ni jeton saisi, ni coloriage, et le plateau dépasse du cadre.
    if (!dragTokenRef.current && !paintMode && zoom.canPan) {
      panningRef.current = true
      pannedRef.current = false
      panLastRef.current = { x: e.clientX, y: e.clientY }
    }

    // Coloriage : on peint dès l'appui, puis à chaque case traversée.
    if (paintMode && !dragTokenRef.current) {
      const cell = pointToCell(e.clientX, e.clientY, r, grid)
      if (cell) {
        paintingRef.current = true
        lastPaintedRef.current = cellKey(cell.col, cell.row)
        onCellPaint(cell)
      }
    }
  }, [readOnly, paintMode, grid, onCellPaint, zoom])

  const handlePointerMove = useCallback((e: ReactPointerEvent<HTMLDivElement>) => {
    if (readOnly) return
    const r = boardRect()
    if (!r) return

    if (pointersRef.current.has(e.pointerId)) {
      pointersRef.current.set(e.pointerId, { x: e.clientX, y: e.clientY })
    }
    if (pinchingRef.current) {
      const pts = [...pointersRef.current.values()]
      if (pts.length >= 2) zoom.pinchMove(pts[0], pts[1])
      return
    }

    if (paintingRef.current) {
      const cell = pointToCell(e.clientX, e.clientY, r, grid)
      if (!cell) return
      const key = cellKey(cell.col, cell.row)
      if (key === lastPaintedRef.current) return
      lastPaintedRef.current = key
      onCellPaint(cell)
      return
    }

    if (panningRef.current) {
      const start = dragStartRef.current
      const last = panLastRef.current
      panLastRef.current = { x: e.clientX, y: e.clientY }
      if (!pannedRef.current) {
        // Sous le seuil, c'est encore un clic : on ne bouge rien, pour que
        // pinger une case reste possible même zoomé.
        if (!start || Math.hypot(e.clientX - start.x, e.clientY - start.y) < DRAG_THRESHOLD_PX) return
        pannedRef.current = true
        return
      }
      if (last) zoom.panBy(e.clientX - last.x, e.clientY - last.y)
      return
    }

    const start = dragStartRef.current
    const token = dragTokenRef.current
    if (!start || !token) return
    if (!movedRef.current) {
      const dx = e.clientX - start.x
      const dy = e.clientY - start.y
      if (Math.hypot(dx, dy) < DRAG_THRESHOLD_PX) return
      if (!canMoveToken(token)) return
      movedRef.current = true
      setDragTokenId(token.token.id)
    }
    setDragPoint(pointToNorm(e.clientX, e.clientY, r))
    setDragCell(pointToCell(e.clientX, e.clientY, r, grid))
  }, [readOnly, grid, canMoveToken, onCellPaint, zoom])

  const endDrag = useCallback((e: ReactPointerEvent<HTMLDivElement>) => {
    if (readOnly) return
    // Relâchement d'un appui qu'on n'a pas retenu (clic droit) : rien à faire.
    if (!acceptedDownRef.current) {
      dragTokenRef.current = null
      return
    }
    acceptedDownRef.current = false
    if (e.currentTarget.hasPointerCapture(e.pointerId)) e.currentTarget.releasePointerCapture(e.pointerId)

    pointersRef.current.delete(e.pointerId)
    if (pinchingRef.current) {
      // Le second doigt relâché ne doit ni pinger, ni sélectionner.
      if (pointersRef.current.size < 2) {
        pinchingRef.current = false
        zoom.pinchEnd()
      }
      return
    }

    const r = boardRect()
    const token = dragTokenRef.current
    const moved = movedRef.current
    const painting = paintingRef.current
    const panned = pannedRef.current

    panningRef.current = false
    pannedRef.current = false
    panLastRef.current = null
    dragTokenRef.current = null
    dragStartRef.current = null
    movedRef.current = false
    paintingRef.current = false
    lastPaintedRef.current = null
    setDragTokenId(null)
    setDragPoint(null)
    setDragCell(null)

    // Un panoramique n'est pas un clic : il ne doit ni pinger, ni bloquer.
    if (painting || panned || !r) return

    if (token) {
      // Un simple tap sélectionne, un vrai glissé déplace.
      if (!moved) {
        onSelectToken(token)
        return
      }
      const cell = pointToCell(e.clientX, e.clientY, r, grid)
      if (cell) onMoveToken(token, cell)
      return
    }

    const cell = pointToCell(e.clientX, e.clientY, r, grid)
    if (cell) onCellActivate(cell)
  }, [readOnly, grid, onSelectToken, onMoveToken, onCellActivate, zoom])

  // Portée de déplacement : pendant un glissé, on éclaire doucement les cases
  // réellement atteignables depuis la case de DÉPART, d'après la statistique de
  // déplacement de l'espèce. Purement indicatif — rien n'empêche de poser le
  // Pokémon au-delà, c'est au MJ d'arbitrer.
  //
  // Contrairement à la portée d'une capacité, le déplacement contourne le
  // décor : cases bloquées et Pokémon debout arrêtent la progression, si bien
  // qu'un Pokémon cerné n'éclaire plus rien.
  const draggedToken = dragTokenId != null ? tokens.find((t) => t.token.id === dragTokenId) : undefined
  const moveCells = useMemo(() => {
    const distance = draggedToken?.species?.distance_deplacement ?? 0
    if (!draggedToken || distance <= 0) return new Set<string>()
    const occupied = new Set(
      tokens
        .filter((t) => t.token.id !== draggedToken.token.id && !t.isKo)
        .map((t) => cellKey(t.token.cell_col, t.token.cell_row))
    )
    return reachableCells(
      { col: draggedToken.token.cell_col, row: draggedToken.token.cell_row },
      distance,
      grid,
      (cell) => {
        const key = cellKey(cell.col, cell.row)
        return blocked.has(key) || occupied.has(key)
      }
    )
  }, [draggedToken, tokens, grid, blocked])

  const cells: { key: string; col: number; row: number }[] = []
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) cells.push({ key: cellKey(col, row), col, row })
  }
  const dragKey = dragCell ? cellKey(dragCell.col, dragCell.row) : null

  return (
    <div ref={wrapperRef} className="relative w-full h-full bg-black flex items-center justify-center overflow-hidden">
      <div
        ref={boardRef}
        className={`relative overflow-hidden [container-type:size] select-none ${readOnly ? '' : 'touch-none'} ${!readOnly && zoom.canPan && !paintMode ? 'cursor-grab active:cursor-grabbing' : ''}`}
        style={{
          width: box.width || '100%',
          height: box.height || '100%',
          transform: zoom.transform,
          transformOrigin: 'center center',
        }}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
        // Le menu contextuel du navigateur n'a rien à faire sur un plateau de jeu.
        onContextMenu={(e) => e.preventDefault()}
      >
        {backgroundUrl && (
          <img
            src={backgroundUrl}
            alt=""
            draggable={false}
            onLoad={(e) => {
              const { naturalWidth, naturalHeight } = e.currentTarget
              if (naturalWidth > 0 && naturalHeight > 0) setRatio(naturalWidth / naturalHeight)
            }}
            className="absolute inset-0 w-full h-full select-none"
          />
        )}

        {/* Reste au-dessus et en dessous de la bande de cases entières : masqué,
            pour qu'aucune demi-case ne soit jouable ni visible. */}
        {!bare && grid.offsetY > 0.001 && (
          <>
            <div className="absolute left-0 right-0 top-0 bg-black" style={{ height: `${grid.offsetY * 100}%` }} />
            <div className="absolute left-0 right-0 bottom-0 bg-black" style={{ height: `${grid.offsetY * 100}%` }} />
          </>
        )}

        <div
          className="absolute left-0 right-0 grid"
          style={{
            top: `${grid.offsetY * 100}%`,
            height: `${rows * grid.cellH * 100}%`,
            gridTemplateColumns: `repeat(${cols}, 1fr)`,
            gridTemplateRows: `repeat(${rows}, 1fr)`,
          }}
        >
          {cells.map((c) => {
            const tint = state.colored_cells[c.key]
            // Une case inaccessible ne fait partie d'aucune zone : ni portée de
            // capacité, ni déplacement. L'aperçu doit montrer ce qui est
            // réellement atteignable.
            const isBlocked = blocked.has(c.key)
            return (
              <div
                key={c.key}
                className={`relative ${bare ? '' : 'outline outline-1 -outline-offset-1 outline-ink/40'}`}
                style={{ backgroundColor: !bare && tint ? TILE_COLOR_CSS[tint] : undefined }}
              >
                {!bare && isBlocked && <div className="absolute inset-0 bg-black/35" />}
                {/* Aperçus de zone : coloration seule, sans liseré — la grille
                    porte déjà ses propres traits, en rajouter surcharge la carte. */}
                {!isBlocked && moveCells.has(c.key) && (
                  <div className="absolute inset-0 bg-white/12" />
                )}
                {!isBlocked && highlightedCells.has(c.key) && (
                  <div className="absolute inset-0 bg-cream/20" />
                )}
                {dragKey === c.key && (
                  <div className="absolute inset-0 bg-white/30 shadow-[inset_0_0_0_3px_#fff]" />
                )}
              </div>
            )
          })}
        </div>

        <div className="absolute inset-0">
          {tokens.map((t) => (
            <BattleToken
              key={t.token.id}
              resolved={t}
              grid={grid}
              selected={selectedTokenId === t.token.id}
              interactive={!readOnly}
              dragPoint={dragTokenId === t.token.id ? dragPoint : null}
              onPointerDown={() => handleTokenPointerDown(t)}
              onHoverChange={(h) => setHoveredTokenId(h ? t.token.id : (prev) => (prev === t.token.id ? null : prev))}
            />
          ))}
        </div>

        {/* Calque d'informations : toujours devant les jetons */}
        <div className="absolute inset-0 pointer-events-none z-[25]">
          {tokens.map((t) => {
            // Pendant un glissé, le jeton quitte sa case : ses informations
            // resteraient en arrière, on les masque le temps du déplacement.
            if (dragTokenId === t.token.id) return null
            const active = hoveredTokenId === t.token.id || selectedTokenId === t.token.id
            const canSeeHp = viewer.isAdmin || t.token.owner_player_id === viewer.playerId
            return (
              <BattleTokenInfo
                key={t.token.id}
                resolved={t}
                grid={grid}
                showHp={canSeeHp && (viewer.alwaysShowHp || active)}
                showOwner={active && !!t.owner}
              />
            )
          })}
        </div>

        <BattlePingLayer pings={pings} grid={grid} />
      </div>

      {zoom.scale > 1.01 && (
        <button
          onClick={zoom.reset}
          title="Revenir à l'image entière"
          className="absolute left-2 bottom-2 z-40 px-2.5 py-1.5 rounded text-xs font-bold border-2 border-ink bg-cream text-ink shadow-[var(--shadow-pixel-sm)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
        >
          {Math.round(zoom.scale * 100)} % · ⤢
        </button>
      )}
    </div>
  )
}
