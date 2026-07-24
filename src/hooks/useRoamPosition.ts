import { useState, useEffect } from 'react'

export interface RoamPos {
  left: number
  bottom: number
}

// Positions cibles de tous les sprites en déambulation, partagées entre les
// instances du hook pour pouvoir éviter les chevauchements lors du tirage.
const registry = new Map<number, RoamPos>()

// Zone sûre de déambulation (en % de la scène) — resserrée par rapport à la
// maquette pour que les grands sprites (304px) restent visibles à l'écran
const randomPos = (): RoamPos => ({
  left: 30 + Math.random() * 40,
  bottom: 8 + Math.random() * 22,
})

// Demi-dimensions estimées d'un sprite en % de la scène. Si deux sprites sont
// séparés d'au moins une demi-largeur OU une demi-hauteur, leur chevauchement
// ne peut pas dépasser 50 % de leur surface.
function halfSizePct(): { halfW: number; halfH: number } {
  const spriteW = Math.min(304, window.innerWidth * 0.8)
  const spriteH = Math.min(304, window.innerHeight * 0.45)
  const sceneW = Math.max(1, window.innerWidth)
  const sceneH = Math.max(1, window.innerHeight * 0.8)
  return { halfW: (spriteW / sceneW) * 50, halfH: (spriteH / sceneH) * 50 }
}

function separationFrom(cand: RoamPos, selfId: number): number {
  const { halfW, halfH } = halfSizePct()
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
function randomFreePos(selfId: number): RoamPos {
  let best = randomPos()
  let bestSep = separationFrom(best, selfId)
  for (let i = 0; i < 24 && bestSep < 1; i++) {
    const cand = randomPos()
    const sep = separationFrom(cand, selfId)
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
 */
export function useRoamPosition(id: number, speedBucket: number) {
  const duration = 24 / Math.max(1, Math.min(5, speedBucket))
  const [pos, setPos] = useState<RoamPos>(() => {
    const p = randomFreePos(id)
    registry.set(id, p)
    return p
  })

  useEffect(() => {
    let cancelled = false
    let timer: number

    const schedule = () => {
      timer = window.setTimeout(() => {
        if (cancelled) return
        const p = randomFreePos(id)
        registry.set(id, p)
        setPos(p)
        schedule()
      }, duration * 1000)
    }
    schedule()

    return () => {
      cancelled = true
      clearTimeout(timer)
      registry.delete(id)
    }
  }, [duration, id])

  return { pos, duration }
}
