import { useState, useEffect, useCallback, useRef } from 'react'
import type { RefObject } from 'react'

// Zoom du plateau de bataille : de « l'image entière tient à l'écran » (×1)
// jusqu'à ×2, à la molette ou au pincement.
//
// La transformation est appliquée à l'élément plateau lui-même, dont l'image,
// la grille, les jetons et les pings sont tous enfants : tout zoome donc
// ensemble et la grille reste collée à l'illustration par construction.
// `getBoundingClientRect()` tient compte des transformations CSS, si bien que
// la conversion pointeur → case continue de fonctionner sans rien changer.
//
// Échelle et décalage tiennent dans un SEUL état : le zoom ancré doit lire les
// deux et les réécrire d'un bloc, ce qu'une mise à jour fonctionnelle unique
// garantit sans passer par des refs lues pendant le rendu.

export const MIN_SCALE = 1
export const MAX_SCALE = 2

interface Point { x: number; y: number }
interface View { scale: number; x: number; y: number }

const IDENTITY: View = { scale: 1, x: 0, y: 0 }

export function useBoardZoom(
  wrapperRef: RefObject<HTMLElement | null>,
  box: { width: number; height: number },
  enabled: boolean
) {
  const [view, setView] = useState<View>(IDENTITY)

  /** Empêche de faire sortir le plateau du cadre : à ×1 il reste centré, et
   *  au-delà on ne peut le déplacer que de ce qui dépasse réellement. */
  const clamp = useCallback((v: View): View => {
    const scale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, v.scale))
    const maxX = Math.max(0, (box.width * scale - box.width) / 2)
    const maxY = Math.max(0, (box.height * scale - box.height) / 2)
    return {
      scale,
      x: Math.max(-maxX, Math.min(maxX, v.x)),
      y: Math.max(-maxY, Math.min(maxY, v.y)),
    }
  }, [box.width, box.height])

  /** Zoom ancré : le point du décor sous le curseur (ou entre les doigts) ne
   *  bouge pas. C'est ce qui rend la molette suffisante pour se déplacer, sans
   *  geste de panoramique séparé. `pan` est ajouté avant le zoom (pincement). */
  const zoomBy = useCallback((clientX: number, clientY: number, factor: number, pan: Point = { x: 0, y: 0 }) => {
    const wrapper = wrapperRef.current
    if (!wrapper) return
    const r = wrapper.getBoundingClientRect()
    const cx = r.left + r.width / 2
    const cy = r.top + r.height / 2
    setView((prev) => {
      const target = Math.max(MIN_SCALE, Math.min(MAX_SCALE, prev.scale * factor))
      const ratio = target / prev.scale
      const px = prev.x + pan.x
      const py = prev.y + pan.y
      return clamp({
        scale: target,
        x: (clientX - cx) * (1 - ratio) + px * ratio,
        y: (clientY - cy) * (1 - ratio) + py * ratio,
      })
    })
  }, [wrapperRef, clamp])

  /** Déplace le plateau du delta demandé, borné au cadre. Sert au panoramique
   *  au glissé, une fois zoomé. */
  const panBy = useCallback((dx: number, dy: number) => {
    setView((prev) => clamp({ ...prev, x: prev.x + dx, y: prev.y + dy }))
  }, [clamp])

  const reset = useCallback(() => setView(IDENTITY), [])

  // Écouteur natif plutôt que onWheel de React : il faut pouvoir appeler
  // preventDefault(), ce qu'un écouteur passif interdit.
  useEffect(() => {
    const wrapper = wrapperRef.current
    if (!wrapper || !enabled) return
    const onWheel = (e: WheelEvent) => {
      e.preventDefault()
      zoomBy(e.clientX, e.clientY, Math.exp(-e.deltaY * 0.0015))
    }
    wrapper.addEventListener('wheel', onWheel, { passive: false })
    return () => wrapper.removeEventListener('wheel', onWheel)
  }, [wrapperRef, enabled, zoomBy])

  // ── Pincement (deux doigts) : écartement = zoom, translation = panoramique ──
  const pinchRef = useRef<{ dist: number; center: Point } | null>(null)

  const pinchStart = useCallback((a: Point, b: Point) => {
    pinchRef.current = {
      dist: Math.hypot(a.x - b.x, a.y - b.y),
      center: { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 },
    }
  }, [])

  const pinchMove = useCallback((a: Point, b: Point) => {
    const start = pinchRef.current
    if (!start || start.dist === 0) return
    const dist = Math.hypot(a.x - b.x, a.y - b.y)
    const center = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }
    zoomBy(center.x, center.y, dist / start.dist, {
      x: center.x - start.center.x,
      y: center.y - start.center.y,
    })
    pinchRef.current = { dist, center }
  }, [zoomBy])

  const pinchEnd = useCallback(() => { pinchRef.current = null }, [])

  // Re-borné au rendu plutôt que dans un effet : si le cadre rétrécit (fenêtre
  // redimensionnée, image de ratio différent), le décalage mémorisé peut être
  // devenu trop grand. Le corriger ici est un simple calcul dérivé — pas de
  // setState en cascade, et le prochain geste réécrit de toute façon une
  // valeur déjà bornée.
  const v = clamp(view)
  const transform = `translate(${v.x}px, ${v.y}px) scale(${v.scale})`
  return {
    scale: v.scale,
    transform,
    reset,
    panBy,
    /** À ×1 le plateau tient déjà dans le cadre : rien à faire glisser. */
    canPan: v.scale > MIN_SCALE,
    pinchStart,
    pinchMove,
    pinchEnd,
  }
}
