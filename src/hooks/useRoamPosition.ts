import { useState, useEffect, type RefObject } from 'react'

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

    const schedule = () => {
      timer = window.setTimeout(() => {
        if (cancelled) return
        const p = randomFreePos(id, containerRef.current)
        registry.set(id, p)
        lastPos.set(id, p)
        setPos(p)
        schedule()
      }, duration * 1000)
    }
    schedule()

    return () => {
      cancelled = true
      clearTimeout(timer)
      // On ne retire que du registre actif (utilisé pour éviter les
      // chevauchements entre sprites montés) — `lastPos` reste pour permettre
      // une reprise à la même place lors d'un remontage.
      registry.delete(id)
    }
  }, [duration, id, containerRef])

  return { pos, duration }
}
