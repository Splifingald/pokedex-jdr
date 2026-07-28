import { useState, useEffect, useCallback, type RefObject } from 'react'

export interface RoamPos {
  left: number
  bottom: number
}

// Positions cibles de tous les sprites en déambulation, partagées entre les
// instances du hook pour pouvoir éviter les chevauchements lors du tirage.
const registry = new Map<number, RoamPos>()

// Dernière position connue de chaque sprite, conservée même après démontage
// (ex : changement d'onglet, qui démonte HomeTab) pour que le sprite réapparaisse
// là où il était plutôt que de sauter instantanément à une nouvelle position aléatoire.
const lastPos = new Map<number, RoamPos>()

// Dimensions réelles de la scène (le conteneur `overflow-hidden` de HomeTab).
// Si le conteneur n'est pas encore monté (tout premier rendu), on retombe sur
// la fenêtre — approximation raisonnable pour ce cas ponctuel uniquement.
function sceneSizePx(container: HTMLElement | null): { width: number; height: number } {
  if (container && container.clientWidth && container.clientHeight) {
    return { width: container.clientWidth, height: container.clientHeight }
  }
  return { width: window.innerWidth, height: window.innerHeight * 0.8 }
}

// Demi-dimensions estimées d'un sprite en % de la scène. Si deux sprites sont
// séparés d'au moins une demi-largeur OU une demi-hauteur, leur chevauchement
// ne peut pas dépasser 50 % de leur surface.
function halfSizePct(container: HTMLElement | null): { halfW: number; halfH: number } {
  const { width: sceneW, height: sceneH } = sceneSizePx(container)
  const spriteW = Math.min(304, sceneW * 0.8)
  const spriteH = Math.min(304, sceneH * 0.45)
  return { halfW: (spriteW / Math.max(1, sceneW)) * 50, halfH: (spriteH / Math.max(1, sceneH)) * 50 }
}

// Zone sûre de déambulation (en % de la scène) — la marge horizontale est
// dérivée de la demi-largeur réelle du sprite pour qu'il ne dépasse jamais
// les bords de la scène, quelle que soit la taille de l'écran.
function randomPos(container: HTMLElement | null): RoamPos {
  const { halfW } = halfSizePct(container)
  const margin = Math.min(halfW, 49)
  return {
    left: margin + Math.random() * Math.max(0, 100 - 2 * margin),
    bottom: 8 + Math.random() * 22,
  }
}

function separationFrom(cand: RoamPos, selfId: number, container: HTMLElement | null): number {
  const { halfW, halfH } = halfSizePct(container)
  let worst = Infinity
  for (const [id, p] of registry) {
    if (id === selfId) continue
    // Marge normalisée : ≥ 1 sur au moins un axe ⇒ chevauchement ≤ 50 %
    const sep = Math.max(Math.abs(cand.left - p.left) / halfW, Math.abs(cand.bottom - p.bottom) / halfH)
    worst = Math.min(worst, sep)
  }
  return worst
}

// Tire une position en évitant plus de 50 % de chevauchement avec les autres
// sprites ; à défaut (petit écran, équipe nombreuse), garde le meilleur essai.
function randomFreePos(selfId: number, container: HTMLElement | null): RoamPos {
  let best = randomPos(container)
  let bestSep = separationFrom(best, selfId, container)
  for (let i = 0; i < 24 && bestSep < 1; i++) {
    const cand = randomPos(container)
    const sep = separationFrom(cand, selfId, container)
    if (sep > bestSep) {
      best = cand
      bestSep = sep
    }
  }
  return best
}

// --- Coordination globale (drag & redimensionnement) -----------------------
// Un seul sprite peut être saisi à la fois, mais pendant ce temps on veut
// figer TOUTE la déambulation (pas seulement celle du sprite saisi) pour ne
// pas perturber le drag avec des voisins qui continuent de dériver. Même
// mécanisme réutilisé lors d'un redimensionnement de fenêtre : on fige tout
// pendant que les dimensions bougent, puis on replace chaque sprite une fois
// que ça s'est stabilisé.
let dragActive = false
const dragListeners = new Set<(active: boolean) => void>()

export function setGlobalDragActive(active: boolean) {
  if (dragActive === active) return
  dragActive = active
  dragListeners.forEach((cb) => cb(active))
}

export function subscribeGlobalDrag(cb: (active: boolean) => void): () => void {
  dragListeners.add(cb)
  return () => { dragListeners.delete(cb) }
}

// Publié une fois par sprite après que le redimensionnement s'est stabilisé,
// pour qu'il retire une nouvelle position adaptée aux nouvelles dimensions.
const resizeSettledListeners = new Set<() => void>()

function subscribeResizeSettled(cb: () => void): () => void {
  resizeSettledListeners.add(cb)
  return () => { resizeSettledListeners.delete(cb) }
}

let resizeDebounceTimer: number | undefined
function handleWindowResize() {
  setGlobalDragActive(true)
  if (resizeDebounceTimer !== undefined) window.clearTimeout(resizeDebounceTimer)
  resizeDebounceTimer = window.setTimeout(() => {
    resizeDebounceTimer = undefined
    resizeSettledListeners.forEach((cb) => cb())
    setGlobalDragActive(false)
  }, 500)
}

if (typeof window !== 'undefined') {
  window.addEventListener('resize', handleWindowResize)
}

/**
 * Fait dériver un sprite vers une nouvelle position aléatoire en boucle.
 * La durée d'un déplacement est 24 / vitesse (vitesse 1–5), le glissement
 * étant assuré par une transition CSS sur left/bottom côté rendu.
 *
 * `containerRef` doit pointer vers la scène (conteneur `overflow-hidden`) afin
 * que les positions tirées restent bornées à sa taille réelle, pas à celle de
 * la fenêtre (qui peut différer, ex. barre latérale desktop).
 */
export function useRoamPosition(id: number, speedBucket: number, containerRef: RefObject<HTMLElement | null>) {
  const duration = 24 / Math.max(1, Math.min(5, speedBucket))
  const [pos, setPos] = useState<RoamPos>(() => {
    // Réutilise la dernière position connue si ce sprite a déjà été affiché
    // (ex. retour sur l'onglet Accueil) pour éviter un saut visuel.
    const p = lastPos.get(id) ?? randomFreePos(id, containerRef.current)
    registry.set(id, p)
    lastPos.set(id, p)
    return p
  })

  useEffect(() => {
    let cancelled = false
    let timer: number

    const moveNow = () => {
      const p = randomFreePos(id, containerRef.current)
      registry.set(id, p)
      lastPos.set(id, p)
      setPos(p)
    }

    const schedule = (delayMs: number) => {
      timer = window.setTimeout(() => {
        if (cancelled) return
        if (dragActive) {
          // Un drag (ou un redimensionnement en cours de stabilisation) est
          // en cours quelque part : on repousse ce déplacement au lieu de
          // l'annuler, pour reprendre dès que tout redevient libre.
          schedule(200)
          return
        }
        moveNow()
        schedule(duration * 1000)
      }, delayMs)
    }
    schedule(duration * 1000)

    // Une fois la fenêtre stabilisée après un redimensionnement, on retire
    // immédiatement une position adaptée aux nouvelles dimensions plutôt que
    // d'attendre le prochain cycle de déambulation naturel.
    const unsubscribeResize = subscribeResizeSettled(() => {
      if (cancelled) return
      window.clearTimeout(timer)
      moveNow()
      schedule(duration * 1000)
    })

    return () => {
      cancelled = true
      clearTimeout(timer)
      unsubscribeResize()
      // On ne retire que du registre actif (utilisé pour éviter les
      // chevauchements entre sprites montés) — `lastPos` reste pour permettre
      // une reprise à la même place lors d'un remontage.
      registry.delete(id)
    }
  }, [duration, id, containerRef])

  // Permet un déplacement manuel (drag) : met à jour la position affichée et
  // les registres partagés, sans perturber le minuteur de déambulation auto.
  const setManualPos = useCallback((p: RoamPos) => {
    registry.set(id, p)
    lastPos.set(id, p)
    setPos(p)
  }, [id])

  return { pos, duration, setPos: setManualPos }
}
