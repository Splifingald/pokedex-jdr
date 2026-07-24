import { useState, useEffect } from 'react'

export interface RoamPos {
  left: number
  bottom: number
}

// Zone sûre de déambulation (en % de la scène) — resserrée par rapport à la
// maquette pour que les grands sprites (304px) restent visibles à l'écran
const randomPos = (): RoamPos => ({
  left: 30 + Math.random() * 40,
  bottom: 8 + Math.random() * 22,
})

/**
 * Fait dériver un sprite vers une nouvelle position aléatoire en boucle.
 * La durée d'un déplacement est 12 / vitesse (vitesse 1–5), le glissement
 * étant assuré par une transition CSS sur left/bottom côté rendu.
 */
export function useRoamPosition(speedBucket: number) {
  const duration = 12 / Math.max(1, Math.min(5, speedBucket))
  const [pos, setPos] = useState<RoamPos>(randomPos)

  useEffect(() => {
    let cancelled = false
    let timer: number

    const schedule = () => {
      timer = window.setTimeout(() => {
        if (cancelled) return
        setPos(randomPos())
        schedule()
      }, duration * 1000)
    }
    schedule()

    return () => {
      cancelled = true
      clearTimeout(timer)
    }
  }, [duration])

  return { pos, duration }
}
