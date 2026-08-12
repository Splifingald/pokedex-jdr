import { useState, useEffect, useRef, useCallback, type RefObject } from 'react'

export interface RoamPos {
  left: number
  bottom: number
}

// Dernière position connue de chaque sprite, conservée même après démontage
// (ex : changement d'onglet, qui démonte HomeTab) pour que le sprite réapparaisse
// là où il était plutôt que de sauter instantanément à une nouvelle position aléatoire.
const lastPos = new Map<number, RoamPos>()

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), Math.max(min, max))
}

// Dimensions réelles de la scène (le conteneur `overflow-hidden` de HomeTab).
// Si le conteneur n'est pas encore monté (tout premier rendu), on retombe sur
// la fenêtre — approximation raisonnable pour ce cas ponctuel uniquement.
function sceneSizePx(container: HTMLElement | null): { width: number; height: number } {
  if (container && container.clientWidth && container.clientHeight) {
    return { width: container.clientWidth, height: container.clientHeight }
  }
  return { width: window.innerWidth, height: window.innerHeight * 0.8 }
}

// Demi-dimensions estimées d'un sprite en % de la scène, utilisées pour ne
// jamais laisser le sprite dépasser les bords de la scène.
function halfSizePct(container: HTMLElement | null): { halfW: number; halfH: number } {
  const { width: sceneW, height: sceneH } = sceneSizePx(container)
  const spriteW = Math.min(304, sceneW * 0.8)
  const spriteH = Math.min(304, sceneH * 0.45)
  return { halfW: (spriteW / Math.max(1, sceneW)) * 50, halfH: (spriteH / Math.max(1, sceneH)) * 50 }
}

// Bornes de la zone sûre (en % de la scène) — `left` ancre le centre du
// sprite, `bottom` ancre son pied, donc les marges diffèrent sur chaque axe.
function boundsPct(container: HTMLElement | null): { minLeft: number; maxLeft: number; minBottom: number; maxBottom: number } {
  const { halfW, halfH } = halfSizePct(container)
  const marginLeft = Math.min(halfW, 49)
  return {
    minLeft: marginLeft,
    maxLeft: 100 - marginLeft,
    minBottom: 0,
    maxBottom: Math.max(0, 100 - halfH * 2),
  }
}

// Zone de déambulation naturelle : toute la largeur sûre, mais une bande peu
// profonde près du bas de la scène (effet de sol/prairie).
function randomPos(container: HTMLElement | null): RoamPos {
  const { minLeft, maxLeft } = boundsPct(container)
  return {
    left: minLeft + Math.random() * Math.max(0, maxLeft - minLeft),
    bottom: 8 + Math.random() * 22,
  }
}

// Ramène une position dans les bornes sûres actuelles — le point le plus
// proche à l'intérieur du rectangle, donc un « téléportage » minimal.
function clampToBounds(pos: RoamPos, container: HTMLElement | null): RoamPos {
  const { minLeft, maxLeft, minBottom, maxBottom } = boundsPct(container)
  return {
    left: clamp(pos.left, minLeft, maxLeft),
    bottom: clamp(pos.bottom, minBottom, maxBottom),
  }
}

// Durée d'un trajet pour la distance de déplacement la plus lente (1) —
// volontairement longue : même le Pokémon le plus mobile (distance 5, qui met
// SLOWEST/5, soit 5× moins de temps) ne doit jamais donner une impression de
// vitesse. Durée fixe par trajet (indépendante de la distance réellement
// parcourue) : plus simple et plus prévisible qu'une vitesse en %/s, et ça
// garantit un ratio exact de 5 entre la distance 1 et la distance 5.
const SLOWEST_MOVE_DURATION_S = 45

// `distance_deplacement` (0–5, cf. fiche Pokémon) pilote directement l'allure
// de déambulation : 0 = ne bouge jamais seul, 5 = se déplace 5× plus vite que
// 1 (mais reste toujours lent en valeur absolue, cf. SLOWEST_MOVE_DURATION_S).
function moveDurationS(distance: number): number {
  return SLOWEST_MOVE_DURATION_S / clamp(distance, 1, 5)
}

// --- Coordination globale (drag & redimensionnement) -----------------------
// Un seul sprite peut être saisi à la fois, mais pendant ce temps on veut
// figer TOUTE la déambulation (pas seulement celle du sprite saisi) pour ne
// pas perturber le drag avec des voisins qui continuent de dériver. Même
// mécanisme réutilisé lors d'un redimensionnement de fenêtre : on fige tout
// pendant que les dimensions bougent, puis on replace chaque sprite une fois
// que ça s'est stabilisé.
let dragActive = false
// Le Pokémon effectivement saisi par le joueur (absent lors d'un simple
// redimensionnement) — sert à lui appliquer le délai d'1s avant de reprendre
// sa déambulation, alors que les autres reprennent immédiatement.
let draggedId: number | null = null
const dragListeners = new Set<(active: boolean) => void>()

export function setGlobalDragActive(active: boolean, id?: number) {
  if (dragActive === active) return
  dragActive = active
  if (active) draggedId = id ?? null
  dragListeners.forEach((cb) => cb(active))
}

export function subscribeGlobalDrag(cb: (active: boolean) => void): () => void {
  dragListeners.add(cb)
  return () => { dragListeners.delete(cb) }
}

// Publié une fois par sprite après que le redimensionnement s'est stabilisé,
// pour qu'il ramène sa position dans les nouvelles bornes sûres.
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

// --- Coordination globale (appel groupé vers un point) ----------------------
// Pendant un appui (souris/doigt) sur le fond de la scène, tous les sprites
// convergent vers le point pressé, à leur propre allure habituelle (donc pas
// de saut instantané comme le gel de drag ci-dessus : on laisse la position
// changer normalement pour que la transition CSS existante s'anime). Relâché,
// ils marquent une pause d'1s avant de reprendre leur déambulation normale.
let attractActive = false
let attractTarget: RoamPos | null = null
const attractListeners = new Set<(active: boolean, target: RoamPos | null) => void>()

export function setGlobalAttract(active: boolean, target?: RoamPos) {
  attractActive = active
  attractTarget = active ? (target ?? attractTarget) : null
  attractListeners.forEach((cb) => cb(active, attractTarget))
}

function subscribeGlobalAttract(cb: (active: boolean, target: RoamPos | null) => void): () => void {
  attractListeners.add(cb)
  return () => { attractListeners.delete(cb) }
}

/**
 * Fait dériver un sprite vers une nouvelle position aléatoire en boucle, à
 * une allure dérivée de sa stat de distance de déplacement (0 = immobile, 5 =
 * le plus mobile, mais toujours lent). Les Pokémon ne se soucient pas les uns
 * des autres : ils peuvent librement se chevaucher.
 *
 * `containerRef` doit pointer vers la scène (conteneur `overflow-hidden`) afin
 * que les positions tirées restent bornées à sa taille réelle, pas à celle de
 * la fenêtre (qui peut différer, ex. barre latérale desktop).
 */
export function useRoamPosition(id: number, distance: number, containerRef: RefObject<HTMLElement | null>) {
  const [pos, setPos] = useState<RoamPos>(() => {
    // Réutilise la dernière position connue si ce sprite a déjà été affiché
    // (ex. retour sur l'onglet Accueil) pour éviter un saut visuel.
    const p = lastPos.get(id) ?? randomPos(containerRef.current)
    lastPos.set(id, p)
    return p
  })
  // Durée d'un trajet : ne dépend que de la stat de distance (constante pour
  // un sprite donné), jamais de l'état ni du trajet réellement tiré — élimine
  // tout risque de désynchronisation entre la position rendue et la durée de
  // transition CSS qui l'anime (qui donnerait l'impression d'un téléportage).
  const duration = moveDurationS(distance)

  const posRef = useRef(pos)
  useEffect(() => { posRef.current = pos }, [pos])

  // Rejoint tout de suite un appel groupé démarré avant le montage de ce
  // sprite (ex. Pokémon qui rejoint l'équipe pendant que le point est tenu).
  useEffect(() => {
    if (!attractActive || !attractTarget) return
    const clamped = clampToBounds(attractTarget, containerRef.current)
    lastPos.set(id, clamped)
    setPos(clamped)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Positions/mouvements déclenchés en dehors du flux normal de déambulation
  // (figé pendant un drag, téléporté après un redimensionnement) doivent
  // s'appliquer instantanément, sans transition CSS — consommé par
  // RoamingPokemonSprite juste avant d'animer un changement de `pos`.
  const instantRef = useRef(false)
  const consumeInstant = useCallback(() => {
    const v = instantRef.current
    instantRef.current = false
    return v
  }, [])

  useEffect(() => {
    let cancelled = false
    let timer: number | undefined
    // true tant qu'on n'a pas encore purgé le délai d'1s dû à un drag propre
    // à CE sprite — remis à false dès qu'un nouveau drag (le sien ou un
    // autre) démarre, pour re-déclencher le délai à chaque saisie.
    let waitedForOwnDrag = false

    const pickAndMove = () => {
      const target = randomPos(containerRef.current)
      setPos(target)
      lastPos.set(id, target)
      schedule(duration * 1000)
    }

    const schedule = (delayMs: number) => {
      timer = window.setTimeout(() => {
        if (cancelled) return
        if (dragActive || attractActive) {
          waitedForOwnDrag = false
          schedule(200)
          return
        }
        if (draggedId === id && !waitedForOwnDrag) {
          waitedForOwnDrag = true
          schedule(1000)
          return
        }
        pickAndMove()
      }, delayMs)
    }
    // distance 0 : ne se déplace jamais seul, mais reste soumis au
    // téléportage de bornes ci-dessous et à l'appel groupé ci-dessus.
    if (distance > 0) schedule(2000 + Math.random() * 3000)

    // Appel groupé : tant qu'il dure, chaque nouveau point pressé/déplacé fait
    // dériver ce sprite vers lui (transition CSS normale, même allure que la
    // déambulation habituelle). À la relâche, on impose une pause d'1s avant
    // de laisser la boucle ci-dessus reprendre son cycle normal.
    const unsubscribeAttract = subscribeGlobalAttract((active, target) => {
      if (cancelled) return
      if (active && target) {
        const clamped = clampToBounds(target, containerRef.current)
        lastPos.set(id, clamped)
        setPos(clamped)
      } else if (distance > 0) {
        // distance 0 : appelé comme les autres, mais ne reprend pas de
        // déambulation propre à la relâche (il ne bouge jamais seul).
        if (timer !== undefined) clearTimeout(timer)
        schedule(1000)
      }
    })

    // Une fois la fenêtre stabilisée après un redimensionnement, on ramène
    // immédiatement la position dans les nouvelles bornes sûres plutôt que
    // d'attendre le prochain cycle de déambulation naturel — s'applique à
    // tous les sprites, y compris ceux immobiles (distance 0). Ignoré si le
    // conteneur n'a pas encore de dimensions réelles (évite de calculer des
    // bornes bidon à partir d'une taille transitoire à 0).
    const unsubscribeResize = subscribeResizeSettled(() => {
      if (cancelled) return
      const container = containerRef.current
      if (!container || !container.clientWidth || !container.clientHeight) return
      const clamped = clampToBounds(posRef.current, container)
      if (clamped.left !== posRef.current.left || clamped.bottom !== posRef.current.bottom) {
        instantRef.current = true
        lastPos.set(id, clamped)
        setPos(clamped)
      }
    })

    return () => {
      cancelled = true
      if (timer !== undefined) clearTimeout(timer)
      unsubscribeAttract()
      unsubscribeResize()
    }
  }, [distance, duration, id, containerRef])

  // Permet un déplacement manuel (drag) : met à jour la position affichée et
  // le registre `lastPos`, sans perturber le minuteur de déambulation auto.
  const setManualPos = useCallback((p: RoamPos) => {
    lastPos.set(id, p)
    setPos(p)
  }, [id])

  return { pos, duration, setPos: setManualPos, consumeInstant }
}
