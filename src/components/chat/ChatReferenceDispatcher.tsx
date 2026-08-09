import type { Item, Pokemon, Attack, CarteLocation } from '../../types'
import type { ReferenceEntry } from '../../hooks/useReferenceIndex'
import { PokemonDetailSheet } from '../PokemonDetailSheet'
import { ItemReferencePopup } from '../campaign/ItemReferencePopup'
import { LocationReferencePopup } from '../campaign/LocationReferencePopup'

interface Props {
  activeReference: ReferenceEntry | null
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  locationsByName: Map<string, CarteLocation>
  onClose: () => void
}

// Version restreinte de ReferenceDispatcher (campagne) pour le chat : uniquement
// objet/pokémon/lieu, popups strictement joueur (pas de displayBar, pas de champs
// admin sur la fiche Pokémon, pas de table de rencontres sur le lieu).
export function ChatReferenceDispatcher({ activeReference, pokemonByName, attacksByName, itemsByName, locationsByName, onClose }: Props) {
  if (!activeReference) return null

  if (activeReference.type === 'pokemon') {
    return (
      <PokemonDetailSheet
        context="pokedex"
        pokemon={pokemonByName.get(activeReference.name)}
        attacksByName={attacksByName}
        isAdmin={false}
        isDiscovered={true}
        elevated
        onClose={onClose}
      />
    )
  }
  if (activeReference.type === 'item') {
    const item = itemsByName.get(activeReference.name)
    if (!item) return null
    return <ItemReferencePopup item={item} onClose={onClose} />
  }
  if (activeReference.type === 'location') {
    const location = locationsByName.get(activeReference.name)
    if (!location) return null
    return (
      <LocationReferencePopup
        location={location}
        encounters={[]}
        pokemonByName={pokemonByName}
        attacksByName={attacksByName}
        hideEncounters
        onClose={onClose}
      />
    )
  }
  return null
}
