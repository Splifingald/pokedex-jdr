import { useEffect, useMemo } from 'react'
import { useDisplayState } from '../hooks/useDisplayState'
import { useDisplayAssets } from '../hooks/useDisplayAssets'
import { usePokemon } from '../hooks/usePokemon'
import { useItems } from '../hooks/useItems'
import { usePlayers } from '../hooks/usePlayers'
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
  const { assets } = useDisplayAssets()
  const { pokemon } = usePokemon()
  const { items } = useItems()
  const { players } = usePlayers()
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

  const { backgroundUrl, npcs, pokemons, items: displayItems } = useMemo(
    () => resolveDisplayState(state, assets, pokemon, items, players),
    [state, assets, pokemon, items, players]
  )

  return (
    <div className="fixed inset-0 w-screen h-screen">
      <DisplayCanvas backgroundUrl={backgroundUrl} npcs={npcs} pokemons={pokemons} items={displayItems} className="w-full h-full" />
      <button
        onClick={toggle}
        aria-label="Basculer le plein écran"
        className="absolute top-0 right-0 w-10 h-10 bg-white/5 hover:bg-white/20 active:bg-white/30 transition-colors"
      />
    </div>
  )
}
