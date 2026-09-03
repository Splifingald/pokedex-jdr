import type { ReactNode } from 'react'
import type { Attack, Player, PlayerPokemon, Pokemon } from '../../types'
import type { ResolvedToken } from '../../lib/onlineTokens'
import type { StatusId } from '../../lib/status'
import { PokemonOwnedCard } from '../PokemonOwnedCard'
import { BattlePokemonRecap } from './BattlePokemonRecap'

interface Props {
  /** Personnage du spectateur : sa pastille ouvre sa fiche de profil. */
  viewer: Player | null
  onOpenProfile: () => void
  /** Équipes affichées, dans l'ordre : chaque entrée garde son propriétaire,
   *  puisque le MJ peut incarner plusieurs personnages à la fois. */
  teamEntries: { pp: PlayerPokemon; owner: Player }[]
  teamLabel: string
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  /** Le MJ a-t-il autorisé le déplacement ? (toujours vrai pour le MJ lui-même) */
  canPlace: boolean
  /** Pokémon choisi et en attente d'une case. */
  pendingPokemonId: number | null
  /** Pokémon déjà posés : les cliquer ouvre leur fiche au lieu de les reposer. */
  placedPokemonIds: Set<number>
  onPickForPlacement: (pp: PlayerPokemon, owner: Player) => void
  selected: ResolvedToken | null
  canEditSelected: boolean
  selectedMove: string | null
  onSelectMove: (nom: string | null) => void
  onSetHp: (value: number) => void
  onSetStatus: (value: StatusId) => void
  onRemoveToken?: () => void
  onBack: () => void
  /** Bloc de contrôles injecté en tête pour le MJ. */
  adminControls?: ReactNode
}

// Barre latérale du plateau : liste de l'équipe, ou fiche détaillée du jeton
// sélectionné. On bascule de l'une à l'autre au lieu d'ouvrir une pop-up, pour
// que le plateau reste visible en permanence pendant un combat.
export function BattleSidebar({
  viewer, onOpenProfile, teamEntries, teamLabel, pokemonByName, attacksByName, canPlace, pendingPokemonId, placedPokemonIds, onPickForPlacement,
  selected, canEditSelected, selectedMove, onSelectMove, onSetHp, onSetStatus, onRemoveToken, onBack, adminControls,
}: Props) {
  // Pastille de profil : présente dans les deux vues de la barre, pour rester
  // accessible même quand on consulte la fiche d'un Pokémon.
  const header = viewer && (
    <button
      onClick={onOpenProfile}
      title={`Profil de ${viewer.name}`}
      className="flex items-center gap-2 w-full text-left"
    >
      <span
        className="w-10 h-10 shrink-0 rounded-full overflow-hidden border-[3px] border-ink shadow-[var(--shadow-pixel-sm)]"
        style={{ backgroundColor: viewer.color }}
      >
        {viewer.image_url && <img src={viewer.image_url} alt="" className="w-full h-full object-cover" />}
      </span>
      <span className="min-w-0">
        <span className="block text-ink text-sm font-bold truncate">{viewer.name}</span>
        <span className="block text-ink-muted-2 text-[0.6rem] leading-none">Voir mon profil</span>
      </span>
    </button>
  )

  if (selected) {
    return (
      <div className="h-full overflow-y-auto p-3 flex flex-col gap-3">
        {header}
        <BattlePokemonRecap
          resolved={selected}
          attacksByName={attacksByName}
          canEdit={canEditSelected}
          selectedMove={selectedMove}
          onSelectMove={onSelectMove}
          onSetHp={onSetHp}
          onSetStatus={onSetStatus}
          onRemove={onRemoveToken}
          onBack={onBack}
        />
      </div>
    )
  }

  return (
    <div className="h-full overflow-y-auto p-3 flex flex-col gap-3">
      {header}
      {adminControls}

      <div>
        <p className="text-ink-muted-2 text-xs mb-1.5">{teamLabel}</p>
        {teamEntries.length === 0 ? (
          <p className="text-ink-muted-2 text-xs italic">Aucun Pokémon dans l'équipe.</p>
        ) : (
          <div className="flex flex-col gap-2">
            {teamEntries.map(({ pp, owner }) => {
              const placed = placedPokemonIds.has(pp.id)
              return (
                <div
                  key={pp.id}
                  // Un Pokémon déjà posé reste cliquable même quand le MJ a
                  // coupé le déplacement : on ouvre sa fiche, on ne le bouge pas.
                  className={`relative rounded-[var(--radius-pixel-sm)] ${pendingPokemonId === pp.id ? 'ring-[3px] ring-shell' : ''} ${canPlace || placed ? '' : 'opacity-60 pointer-events-none'}`}
                >
                  <PokemonOwnedCard
                    playerPokemon={pp}
                    pokemon={pokemonByName.get(pp.pokemon_nom)}
                    variant="list"
                    onClick={() => onPickForPlacement(pp, owner)}
                  />
                  {placed && (
                    <span className="absolute right-1 bottom-1 px-1 py-0.5 rounded border-2 border-ink bg-cream text-ink text-[0.55rem] leading-none font-bold">
                      sur le plateau
                    </span>
                  )}
                </div>
              )
            })}
          </div>
        )}
        {canPlace && pendingPokemonId != null && (
          <p className="text-ink text-xs mt-2 font-bold">Touche une case du plateau pour le poser.</p>
        )}
        {!canPlace && (
          <p className="text-ink-muted-2 text-xs italic mt-2">
            Le MJ n'a pas (encore) autorisé le déplacement des Pokémon.
          </p>
        )}
      </div>
    </div>
  )
}
