import { useState, useRef, useEffect, useCallback, useMemo } from 'react'
import type { AdminParameters, Attack, CarteLocation, Pokemon } from '../types'
import { useCarteLocations } from '../hooks/useCarteLocations'
import { useEncounters } from '../hooks/useEncounters'
import { CarteImageViewer } from './CarteImageViewer'
import { EncounterTableModal } from './EncounterTableModal'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { NAV_ICON } from '../lib/icons'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  parameters: AdminParameters
  isAdmin: boolean
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
}

const MAX_SCALE = 5
const TAP_THRESHOLD = 6
// Tolérance de correspondance couleur : les images de couleurs subissent souvent
// une légère recompression/ré-encodage (CDN, export PNG) qui décale chaque canal
// de quelques valeurs — une correspondance exacte échoue presque toujours en pratique.
const COLOR_MATCH_MAX_DIST_SQ = 1200

interface Transform {
  scale: number
  x: number
  y: number
}

// Centre l'image sur cet axe si elle tient déjà entière dans le conteneur,
// sinon l'empêche de se décoller des bords
function clampAxis(pos: number, scaledSize: number, containerSize: number): number {
  if (scaledSize <= containerSize) return (containerSize - scaledSize) / 2
  return Math.max(containerSize - scaledSize, Math.min(0, pos))
}

function hexToRgb(hex: string): [number, number, number] | null {
  const clean = hex.trim().toLowerCase().replace(/^#/, '')
  if (clean.length !== 6) return null
  const r = parseInt(clean.slice(0, 2), 16)
  const g = parseInt(clean.slice(2, 4), 16)
  const b = parseInt(clean.slice(4, 6), 16)
  if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) return null
  return [r, g, b]
}

export function CarteTab({ parameters, isAdmin, pokemonByName, attacksByName }: Props) {
  const { locations } = useCarteLocations()
  const { encounters } = useEncounters()

  const containerRef = useRef<HTMLDivElement>(null)
  const imgRef = useRef<HTMLImageElement>(null)
  const canvasRef = useRef<HTMLCanvasElement | null>(null)

  const [transform, setTransform] = useState<Transform>({ scale: 1, x: 0, y: 0 })
  const transformRef = useRef(transform)
  useEffect(() => { transformRef.current = transform }, [transform])

  const [selected, setSelected] = useState<CarteLocation | null>(null)
  const [viewerOpen, setViewerOpen] = useState(false)
  const [colorMapError, setColorMapError] = useState(false)
  const [encounterModalOpen, setEncounterModalOpen] = useState(false)

  const matchingEncounterRows = useMemo(() => {
    if (!selected) return []
    const target = selected.titre.trim().toLowerCase()
    return encounters.filter((e) => e.lieu.trim().toLowerCase() === target)
  }, [selected, encounters])

  const pointers = useRef(new Map<number, { x: number; y: number }>())
  const dragStateRef = useRef<{ startX: number; startY: number; originX: number; originY: number; moved: number } | null>(null)
  const pinchStateRef = useRef<{ startDist: number; startScale: number } | null>(null)

  // Charge l'image de couleurs dans un canvas hors-écran une seule fois
  useEffect(() => {
    if (!parameters.carte_couleurs_image_url) return
    const img = new Image()
    img.crossOrigin = 'anonymous'
    img.onload = () => {
      const canvas = document.createElement('canvas')
      canvas.width = img.naturalWidth
      canvas.height = img.naturalHeight
      const ctx = canvas.getContext('2d')
      if (!ctx) return
      ctx.drawImage(img, 0, 0)
      canvasRef.current = canvas
      setColorMapError(false)
    }
    img.onerror = () => setColorMapError(true)
    img.src = parameters.carte_couleurs_image_url
  }, [parameters.carte_couleurs_image_url])

  // Le plus petit zoom qui garde l'image entière visible (largeur ET hauteur) dans le conteneur
  const getMinScale = useCallback((): number => {
    const imgEl = imgRef.current
    const container = containerRef.current
    if (!imgEl || !container || !imgEl.offsetWidth || !imgEl.offsetHeight) return 1
    const fitWidthScale = container.clientWidth / imgEl.offsetWidth
    const fitHeightScale = container.clientHeight / imgEl.offsetHeight
    return Math.min(1, fitWidthScale, fitHeightScale)
  }, [])

  const clampTransform = useCallback((t: Transform): Transform => {
    const imgEl = imgRef.current
    const container = containerRef.current
    if (!imgEl || !container) return t
    const scale = Math.max(getMinScale(), Math.min(MAX_SCALE, t.scale))
    const scaledW = imgEl.offsetWidth * scale
    const scaledH = imgEl.offsetHeight * scale
    return {
      scale,
      x: clampAxis(t.x, scaledW, container.clientWidth),
      y: clampAxis(t.y, scaledH, container.clientHeight),
    }
  }, [getMinScale])

  const zoomTo = useCallback((newScaleRaw: number, px: number, py: number) => {
    setTransform((prev) => {
      const newScale = Math.max(getMinScale(), Math.min(MAX_SCALE, newScaleRaw))
      const ratio = newScale / prev.scale
      const newX = px - (px - prev.x) * ratio
      const newY = py - (py - prev.y) * ratio
      return clampTransform({ scale: newScale, x: newX, y: newY })
    })
  }, [clampTransform, getMinScale])

  const handleTap = useCallback((clientX: number, clientY: number) => {
    const imgEl = imgRef.current
    const canvas = canvasRef.current
    if (!imgEl || !canvas) return
    const rect = imgEl.getBoundingClientRect()
    const fracX = (clientX - rect.left) / rect.width
    const fracY = (clientY - rect.top) / rect.height
    if (fracX < 0 || fracX > 1 || fracY < 0 || fracY > 1) {
      setSelected(null)
      setEncounterModalOpen(false)
      return
    }
    const px = Math.min(canvas.width - 1, Math.max(0, Math.floor(fracX * canvas.width)))
    const py = Math.min(canvas.height - 1, Math.max(0, Math.floor(fracY * canvas.height)))
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    try {
      const [r, g, b] = ctx.getImageData(px, py, 1, 1).data
      let best: CarteLocation | null = null
      let bestDist = Infinity
      for (const loc of locations) {
        const rgb = hexToRgb(loc.couleur)
        if (!rgb) continue
        const dist = (r - rgb[0]) ** 2 + (g - rgb[1]) ** 2 + (b - rgb[2]) ** 2
        if (dist < bestDist) {
          bestDist = dist
          best = loc
        }
      }
      setSelected(bestDist <= COLOR_MATCH_MAX_DIST_SQ ? best : null)
      setEncounterModalOpen(false)
    } catch {
      setColorMapError(true)
    }
  }, [locations])

  const handlePointerDown = (e: React.PointerEvent) => {
    (e.target as Element).setPointerCapture(e.pointerId)
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY })

    if (pointers.current.size === 1) {
      dragStateRef.current = {
        startX: e.clientX,
        startY: e.clientY,
        originX: transformRef.current.x,
        originY: transformRef.current.y,
        moved: 0,
      }
    } else if (pointers.current.size === 2) {
      const pts = Array.from(pointers.current.values())
      const dist = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y)
      pinchStateRef.current = { startDist: dist, startScale: transformRef.current.scale }
      dragStateRef.current = null
    }
  }

  const handlePointerMove = (e: React.PointerEvent) => {
    if (!pointers.current.has(e.pointerId)) return
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY })

    if (pointers.current.size === 2 && pinchStateRef.current) {
      const pts = Array.from(pointers.current.values())
      const dist = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y)
      const midX = (pts[0].x + pts[1].x) / 2
      const midY = (pts[0].y + pts[1].y) / 2
      const rect = containerRef.current!.getBoundingClientRect()
      const rawScale = pinchStateRef.current.startScale * (dist / pinchStateRef.current.startDist)
      zoomTo(rawScale, midX - rect.left, midY - rect.top)
      return
    }

    if (pointers.current.size === 1 && dragStateRef.current) {
      const dx = e.clientX - dragStateRef.current.startX
      const dy = e.clientY - dragStateRef.current.startY
      dragStateRef.current.moved = Math.hypot(dx, dy)
      const origin = dragStateRef.current
      setTransform((prev) => clampTransform({ ...prev, x: origin.originX + dx, y: origin.originY + dy }))
    }
  }

  const handlePointerUp = (e: React.PointerEvent) => {
    const wasSingleTap = pointers.current.size === 1 && !!dragStateRef.current && dragStateRef.current.moved < TAP_THRESHOLD
    pointers.current.delete(e.pointerId)
    if (pointers.current.size < 2) pinchStateRef.current = null
    if (wasSingleTap) handleTap(e.clientX, e.clientY)
    if (pointers.current.size === 0) dragStateRef.current = null
  }

  const handleWheel = (e: React.WheelEvent) => {
    e.preventDefault()
    const rect = containerRef.current!.getBoundingClientRect()
    const px = e.clientX - rect.left
    const py = e.clientY - rect.top
    const delta = -e.deltaY * 0.0015
    zoomTo(transformRef.current.scale * (1 + delta), px, py)
  }

  return (
    <div className="flex-1 flex flex-col overflow-hidden relative bg-app-bg">
      {!parameters.carte_image_url ? (
        <div className="flex-1 flex items-center justify-center text-[#7a7c9a] text-sm p-6 text-center">
          Aucune carte configurée. Ajoutez un lien d'image dans Admin → Paramètres.
        </div>
      ) : (
        <div
          ref={containerRef}
          className="flex-1 relative overflow-hidden touch-none select-none cursor-grab active:cursor-grabbing"
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          onPointerCancel={handlePointerUp}
          onWheel={handleWheel}
        >
          <div
            className="absolute top-0 left-0 origin-top-left"
            style={{ transform: `translate(${transform.x}px, ${transform.y}px) scale(${transform.scale})` }}
          >
            <img
              ref={imgRef}
              src={parameters.carte_image_url}
              alt="Carte"
              className="w-full h-auto block max-w-none"
              draggable={false}
            />
          </div>

          {colorMapError && (
            <div className="absolute top-2 left-2 right-2 bg-red-900/80 border border-red-700 text-red-200 text-xs rounded px-3 py-2">
              Impossible de lire l'image des couleurs (problème CORS ou lien invalide).
            </div>
          )}
        </div>
      )}

      {selected && (
        <div className="shrink-0 bg-cream border-t-4 border-ink rounded-t-2xl p-4 max-h-[45%] overflow-y-auto animate-[sheet-pop_0.25s_ease-out]">
          <div className="flex items-center gap-2 mb-2">
            {selected.type && (
              <span className="text-xs bg-cream-secondary border-2 border-ink rounded px-1.5 py-0.5 text-ink-muted uppercase">
                {selected.type}
              </span>
            )}
            <h3 className="text-ink font-bold flex-1">{selected.titre}</h3>
            {isAdmin && matchingEncounterRows.length > 0 && (
              <button
                onClick={() => setEncounterModalOpen(true)}
                title="Voir la table de rencontres"
                className={`w-7 h-7 shrink-0 rounded-md flex items-center justify-center ${BUTTON_STYLE.gray}`}
              >
                <PixelIcon src={NAV_ICON.rencontres!} size={16} colored className="text-ink" alt="" />
              </button>
            )}
            <button
              onClick={() => setSelected(null)}
              className={`w-7 h-7 shrink-0 rounded-md text-sm font-bold ${BUTTON_STYLE.gray}`}
            >
              <CloseIcon className="w-4 h-4 mx-auto" />
            </button>
          </div>
          {selected.image_url && (
            <button
              onClick={() => setViewerOpen(true)}
              className={`mb-2 px-3 py-1.5 rounded-md text-xs font-bold ${BUTTON_STYLE.blue}`}
            >
              🖼 Voir l'image
            </button>
          )}
          {selected.description && (
            <p className="text-ink-muted text-sm whitespace-pre-wrap">{selected.description}</p>
          )}
          {isAdmin && selected.admin_description && (
            <div className="mt-3 pt-3 border-t-2 border-[#cfc7a8]">
              <p className="text-[#a3841a] text-xs font-bold mb-1">🛠 Description admin</p>
              <p className="text-ink-muted text-sm whitespace-pre-wrap">{selected.admin_description}</p>
            </div>
          )}
        </div>
      )}

      {viewerOpen && selected?.image_url && (
        <CarteImageViewer imageUrl={selected.image_url} onClose={() => setViewerOpen(false)} />
      )}

      {encounterModalOpen && selected && matchingEncounterRows.length > 0 && (
        <EncounterTableModal
          lieu={selected.titre}
          rows={matchingEncounterRows}
          pokemonByName={pokemonByName}
          attacksByName={attacksByName}
          isAdmin={isAdmin}
          onClose={() => setEncounterModalOpen(false)}
        />
      )}
    </div>
  )
}
