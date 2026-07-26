import type { Player, CarteLocation, Attack, Item, Pokemon, Encounter } from '../../types'
import type { ReferenceEntry } from '../../hooks/useReferenceIndex'
import { PlayerReferencePopup } from './PlayerReferencePopup'
import { LocationReferencePopup } from './LocationReferencePopup'
import { AbilityReferencePopup } from './AbilityReferencePopup'
import { ItemReferencePopup } from './ItemReferencePopup'
import { PokemonDetailSheet } from '../PokemonDetailSheet'

interface Props {
  activeReference: ReferenceEntry | null
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  playersByName: Map<string, Player>
  locationsByName: Map<string, CarteLocation>
  encountersByLieu: Map<string, Encounter[]>
  onClose: () => void
}

// Ouvre le popup d'info adapté au type de référence cliquée dans le texte du journal
export function ReferenceDispatcher({
  activeReference,
  pokemonByName,
  attacksByName,
  itemsByName,
  playersByName,
  locationsByName,
  encountersByLieu,
  onClose,
}: Props) {
  if (!activeReference) return null

  if (activeReference.type === 'pokemon') {
    return (
      <PokemonDetailSheet
        context="pokedex"
        pokemon={pokemonByName.get(activeReference.name)}
        attacksByName={attacksByName}
        isAdmin={true}
        isDiscovered={true}
        onClose={onClose}
      />
    )
  }
  if (activeReference.type === 'player') {
    const player = playersByName.get(activeReference.name)
    if (!player) return null
    return (
      <PlayerReferencePopup
        player={player}
        pokemonByName={pokemonByName}
        attacksByName={attacksByName}
        itemsByName={itemsByName}
        onClose={onClose}
      />
    )
  }
  if (activeReference.type === 'location') {
    const location = locationsByName.get(activeReference.name)
    if (!location) return null
    return (
      <LocationReferencePopup
        location={location}
        encounters={encountersByLieu.get(location.titre) ?? []}
        pokemonByName={pokemonByName}
        onClose={onClose}
      />
    )
  }
  if (activeReference.type === 'ability') {
    const attack = attacksByName.get(activeReference.name)
    if (!attack) return null
    return <AbilityReferencePopup attack={attack} onClose={onClose} />
  }
  if (activeReference.type === 'item') {
    const item = itemsByName.get(activeReference.name)
    if (!item) return null
    return <ItemReferencePopup item={item} onClose={onClose} />
  }
  return null
}
