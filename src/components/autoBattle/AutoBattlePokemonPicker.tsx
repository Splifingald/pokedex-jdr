import { useMemo } from 'react'
import type { Pokemon, PlayerPokemon, Attack } from '../../types'
import { ownedPokemonName } from '../../types'
import { getEligiblePlayerPokemon } from '../../lib/autoBattle'
import { PANEL } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  roster: PlayerPokemon[]
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  bannedAttacks: Set<string>
  onSelect: (pp: PlayerPokemon) => void
  onBack: () => void
}

// Sélection du pokémon combattant — même structure de grille de cartes que
// PensionPlacementList (Équipe + PC, pension exclue), filtrée aux pokémon
// ayant au moins une capacité offensive apprise (voir requirement #6/#9),
// bannies exclues.
export function AutoBattlePokemonPicker({ roster, pokemonByName, attacksByName, bannedAttacks, onSelect, onBack }: Props) {
  const eligible = useMemo(
    () => getEligiblePlayerPokemon(roster, attacksByName, bannedAttacks),
    [roster, attacksByName, bannedAttacks]
  )

  if (eligible.length === 0) {
    return (
      <div className="flex flex-col items-center gap-3 py-6">
        <p className="text-ink-muted-2 text-sm text-center">
          Aucun pokémon avec une capacité offensive apprise (et hors pension) n'est disponible pour combattre.
        </p>
        <button onClick={onBack} className={`text-xs px-3 py-1.5 rounded font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <button onClick={onBack} className={`text-xs px-2 py-1 rounded font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
        <h4 className="text-ink text-base font-bold">Choisissez votre pokémon</h4>
      </div>
      <div className="grid grid-cols-2 gap-2">
        {eligible.map((pp) => {
          const species = pokemonByName.get(pp.pokemon_nom)
          return (
            <button
              key={pp.id}
              onClick={() => onSelect(pp)}
              className={`${PANEL} flex flex-col items-center gap-1.5 p-2.5 text-left ${BUTTON_STYLE.gray}`}
            >
              <div className="w-14 h-14 shrink-0 rounded-md border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
                {species?.image_miniature ? (
                  <img src={species.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
                ) : (
                  <span className="text-ink-muted-2 text-2xl">?</span>
                )}
              </div>
              <span className="text-ink text-sm font-bold truncate w-full text-center">{ownedPokemonName(pp)}</span>
              {pp.in_team && <span className="text-ink-muted-2 text-xs">Équipe</span>}
            </button>
          )
        })}
      </div>
    </div>
  )
}
