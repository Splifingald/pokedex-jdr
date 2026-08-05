import type { Player, CarteLocation, Attack, Item, Pokemon, CampaignChapter, Encounter, DisplayAsset, DisplayState } from '../../types'
import { POKEDOLLAR_ITEM_NAME } from '../../types'
import type { ReferenceEntry, ReferenceIndex } from '../../hooks/useReferenceIndex'
import type { UpdateDisplayState } from '../../lib/displayActions'
import { PlayerReferencePopup } from './PlayerReferencePopup'
import { LocationReferencePopup } from './LocationReferencePopup'
import { AbilityReferencePopup } from './AbilityReferencePopup'
import { ItemReferencePopup } from './ItemReferencePopup'
import { DisplayControlBar } from './DisplayControlBar'
import { PokemonDetailSheet } from '../PokemonDetailSheet'
import { ChapterViewPopup } from './ChapterViewPopup'

interface Props {
  activeReference: ReferenceEntry | null
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  playersByName: Map<string, Player>
  locationsByName: Map<string, CarteLocation>
  encountersByLieu: Map<string, Encounter[]>
  /** Requis uniquement pour ouvrir une référence de type 'chapter' */
  chaptersByName?: Map<string, CampaignChapter>
  referenceIndex?: ReferenceIndex
  onToggleChapterDone?: (chapter: CampaignChapter) => void
  onSaveChapterNotes?: (chapter: CampaignChapter, notes: CampaignChapter['notes']) => void
  displayState?: DisplayState
  displayAssets?: DisplayAsset[]
  updateDisplayState?: UpdateDisplayState
  /** Masque la barre "Ajouter à l'affichage" (défaut true) — désactivée pour les popups
   * ouverts depuis l'Historique, qui n'a pas vocation à piloter l'écran joueurs en direct. */
  showDisplayBar?: boolean
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
  chaptersByName,
  referenceIndex,
  onToggleChapterDone,
  onSaveChapterNotes,
  displayState,
  displayAssets,
  updateDisplayState,
  showDisplayBar = true,
  onClose,
}: Props) {
  if (!activeReference) return null

  const displayBar =
    showDisplayBar && displayState && displayAssets && updateDisplayState ? (
      <DisplayControlBar
        key={`${activeReference.type}:${activeReference.name}`}
        entry={activeReference}
        displayState={displayState}
        displayAssets={displayAssets}
        updateDisplayState={updateDisplayState}
        players={[...playersByName.values()]}
      />
    ) : undefined

  if (activeReference.type === 'pokemon') {
    return (
      <PokemonDetailSheet
        context="pokedex"
        pokemon={pokemonByName.get(activeReference.name)}
        attacksByName={attacksByName}
        isAdmin={true}
        isDiscovered={true}
        displayBar={displayBar}
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
        displayBar={displayBar}
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
        attacksByName={attacksByName}
        displayBar={displayBar}
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
    return (
      <ItemReferencePopup
        item={item}
        pokedollarImageUrl={itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url}
        displayBar={displayBar}
        onClose={onClose}
      />
    )
  }
  if (activeReference.type === 'chapter') {
    const chapter = chaptersByName?.get(activeReference.name)
    if (!chapter || !referenceIndex || !displayState || !displayAssets || !updateDisplayState) return null
    return (
      <ChapterViewPopup
        chapter={chapter}
        referenceIndex={referenceIndex}
        pokemonByName={pokemonByName}
        attacksByName={attacksByName}
        itemsByName={itemsByName}
        playersByName={playersByName}
        locationsByName={locationsByName}
        encountersByLieu={encountersByLieu}
        chaptersByName={chaptersByName}
        displayState={displayState}
        displayAssets={displayAssets}
        updateDisplayState={updateDisplayState}
        onToggleDone={() => onToggleChapterDone?.(chapter)}
        onSaveNotes={(notes) => onSaveChapterNotes?.(chapter, notes)}
        onClose={onClose}
      />
    )
  }
  return null
}
