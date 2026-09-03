import { useState, useEffect } from 'react'
import type { RefObject } from 'react'
import { fitBox } from '../lib/onlineBoard'

// Cadrage « image entière » du plateau de bataille : la plus grande boîte au
// ratio de l'image qui tienne dans le conteneur, centrée, bandes noires
// autour si besoin.
//
// Fait en JS plutôt qu'en CSS parce que le rectangle obtenu doit être EXACTEMENT
// celui de l'image : c'est lui qu'on mesure pour convertir pointeur → case et
// pointeur → curseur normalisé. Avec aspect-ratio + max-width/max-height, la
// boîte se contente d'être visuellement correcte, sans garantie sur les deux
// dimensions à la fois.

export function useFittedBox(containerRef: RefObject<HTMLElement | null>, ratio: number) {
  const [box, setBox] = useState({ width: 0, height: 0 })

  useEffect(() => {
    const el = containerRef.current
    if (!el) return
    const measure = () => {
      const rect = el.getBoundingClientRect()
      setBox((prev) => {
        const next = fitBox(rect.width, rect.height, ratio)
        return Math.abs(prev.width - next.width) < 0.5 && Math.abs(prev.height - next.height) < 0.5 ? prev : next
      })
    }
    measure()
    const observer = new ResizeObserver(measure)
    observer.observe(el)
    return () => observer.disconnect()
  }, [containerRef, ratio])

  return box
}
