import { useMemo } from 'react'
import { useDisplayState } from '../hooks/useDisplayState'
import { useBackgrounds } from '../hooks/useBackgrounds'
import { useDisplayAssets } from '../hooks/useDisplayAssets'
import { usePokemon } from '../hooks/usePokemon'
import { useItems } from '../hooks/useItems'
import { DisplayCanvas } from '../components/display/DisplayCanvas'
import { resolveDisplayState } from '../lib/resolveDisplayState'

// Écran plein écran destiné aux joueurs (TV/projecteur), ouvert dans un
// onglet séparé du navigateur. Se met à jour instantanément via Supabase
// Realtime quand l'admin change l'affichage depuis Admin → Affichage.
export function DisplayPage() {
  const { state } = useDisplayState()
  const { backgrounds } = useBackgrounds()
  const { assets } = useDisplayAssets()
  const { pokemon } = usePokemon()
  const { items } = useItems()

  const { backgroundUrl, npcs, pokemons, item } = useMemo(
    () => resolveDisplayState(state, backgrounds, assets, pokemon, items),
    [state, backgrounds, assets, pokemon, items]
  )

  return (
    <DisplayCanvas
      backgroundUrl={backgroundUrl}
      npcs={npcs}
      pokemons={pokemons}
      item={item}
      className="fixed inset-0 w-screen h-screen"
    />
  )
}
