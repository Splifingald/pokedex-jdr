import { useEffect, useState } from 'react'

// Sur mobile, l'ouverture du clavier virtuel ne redimensionne pas le viewport
// de mise en page (surtout sur iOS Safari) : un conteneur `fixed inset-0`
// reste ancré sur la hauteur totale de l'écran et le champ de saisie en bas
// se retrouve masqué sous le clavier. window.visualViewport reflète lui la
// zone réellement visible, donc on l'utilise pour recadrer le conteneur.
export function useVisualViewportHeight() {
  const [rect, setRect] = useState<{ height: number; offsetTop: number } | null>(null)

  useEffect(() => {
    const vv = window.visualViewport
    if (!vv) return
    const update = () => setRect({ height: vv.height, offsetTop: vv.offsetTop })
    update()
    vv.addEventListener('resize', update)
    vv.addEventListener('scroll', update)
    return () => {
      vv.removeEventListener('resize', update)
      vv.removeEventListener('scroll', update)
    }
  }, [])

  return rect
}
