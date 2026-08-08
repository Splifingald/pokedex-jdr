import type { Pokemon, PlayerPokemon, PensionConfig, PensionXpGroup } from '../types'
import { PensionPlacementList } from './PensionPlacementList'
import { CloseIcon } from './icons/CloseIcon'

interface Props {
  pcRoster: PlayerPokemon[]
  daycareRoster: PlayerPokemon[]
  pokemonByName: Map<string, Pokemon>
  pensionConfig: PensionConfig
  xpGroupByPokemonNom: Map<string, PensionXpGroup>
  eggGroupsByPokemonNom: Map<string, string[]>
  daycareFull: boolean
  onPlace: (id: number) => void
  onClose: () => void
}

// Ouvert depuis le bouton "Ajouter un pokémon" d'un emplacement vide de la
// grille de pension (voir PensionDaycareGrid) — se ferme automatiquement
// une fois un pokémon placé avec succès (voir
// PensionPopup::handlePlaceFromSelection côté appelant).
export function PensionSelectionPopup({
  pcRoster, daycareRoster, pokemonByName, pensionConfig, xpGroupByPokemonNom, eggGroupsByPokemonNom, daycareFull, onPlace, onClose,
}: Props) {
  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className="relative bg-cream w-full max-w-xl max-h-[85vh] overflow-hidden flex flex-col border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)]">
        <button
          onClick={onClose}
          className="absolute right-3 top-3 z-10 w-8 h-8 rounded-full flex items-center justify-center text-ink hover:bg-black/10"
        >
          <CloseIcon className="w-4 h-4" />
        </button>

        <h3 className="text-ink text-lg font-bold px-5 pt-5 pb-1 pr-12">Ajouter un pokémon à la pension</h3>

        <div className="flex-1 overflow-y-auto px-5 pb-5">
          <PensionPlacementList
            pcRoster={pcRoster}
            daycareRoster={daycareRoster}
            pokemonByName={pokemonByName}
            pensionConfig={pensionConfig}
            xpGroupByPokemonNom={xpGroupByPokemonNom}
            eggGroupsByPokemonNom={eggGroupsByPokemonNom}
            daycareFull={daycareFull}
            onPlace={onPlace}
          />
        </div>
      </div>
    </div>
  )
}
