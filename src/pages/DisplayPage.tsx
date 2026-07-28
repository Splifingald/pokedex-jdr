import { useEffect, useMemo } from 'react'
import { useDisplayState } from '../hooks/useDisplayState'
import { useBackgrounds } from '../hooks/useBackgrounds'
import { useDisplayAssets } from '../hooks/useDisplayAssets'
import { usePokemon } from '../hooks/usePokemon'
import { useItems } from '../hooks/useItems'
import { useFullscreen } from '../hooks/useFullscreen'
import { DisplayCanvas } from '../components/display/DisplayCanvas'
import { resolveDisplayState } from '../lib/resolveDisplayState'

// Écran plein écran destiné aux joueurs (TV/projecteur), ouvert dans un
// onglet séparé du navigateur. Se met à jour instantanément via Supabase
// Realtime quand l'admin change l'affichage depuis Admin → Affichage —
// et Entrée/Espace recharge la page en secours si le Realtime n'est pas
// activé côté Supabase pour la table display_state.
export function DisplayPage() {
  const { state } = useDisplayState()
  const { backgrounds } = useBackgrounds()
  const { assets } = useDisplayAssets()
  const { pokemon } = usePokemon()
  const { items } = useItems()
  const { toggle } = useFullscreen()

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault()
        window.location.reload()
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [])

  const { backgroundUrl, npcs, pokemons, item } = useMemo(
    () => resolveDisplayState(state, backgrounds, assets, pokemon, items),
    [state, backgrounds, assets, pokemon, items]
  )

  return (
    <div className="fixed inset-0 w-screen h-screen">
      <DisplayCanvas backgroundUrl={backgroundUrl} npcs={npcs} pokemons={pokemons} item={item} className="w-full h-full" />
      <button
        onClick={toggle}
        aria-label="Basculer le plein écran"
        className="absolute top-0 right-0 w-10 h-10 bg-white/5 hover:bg-white/20 active:bg-white/30 transition-colors"
      />
    </div>
  )
}
