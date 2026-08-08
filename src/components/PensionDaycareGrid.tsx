import { useMemo } from 'react'
import type { Pokemon, PlayerPokemon, PensionConfig, PensionXpGroup, PensionPair } from '../types'
import { usePlayers } from '../hooks/usePlayers'
import { resolveApplicableXpGroup } from '../lib/pension'
import { PensionDaycareCard } from './PensionDaycareCard'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  daycareRoster: PlayerPokemon[]
  pokemonByName: Map<string, Pokemon>
  pensionConfig: PensionConfig
  xpGroupByPokemonNom: Map<string, PensionXpGroup>
  pairsByPokemonId: Map<number, PensionPair[]>
  currentPlayerId: number
  now: number
  onSelectCard: (id: number) => void
  onRetrieve: (id: number) => void
  onOpenSelection: () => void
}

// Case vide : une simple ombre vectorielle à l'endroit où un pokémon se
// tiendrait. Si le joueur qui regarde n'a pas encore de pokémon en pension,
// un bouton ouvre PensionSelectionPopup ; sinon un simple texte explique que
// la place est réservée à un autre dresseur.
function PensionEmptySlot({ canAdd, onAdd }: { canAdd: boolean; onAdd: () => void }) {
  return (
    <div className="aspect-[2/3] min-w-0 rounded-lg border-2 border-dashed border-ink/25 bg-cream-secondary/30 flex flex-col items-center justify-center gap-2 p-2">
      <svg viewBox="0 0 48 16" className="w-2/5 text-ink" aria-hidden="true">
        <ellipse cx="24" cy="8" rx="22" ry="7" fill="currentColor" opacity="0.15" />
      </svg>
      {canAdd ? (
        <button onClick={onAdd} className={`px-2.5 py-1.5 rounded text-xs font-bold text-center ${BUTTON_STYLE.yellow}`}>
          Ajouter un pokémon
        </button>
      ) : (
        <p className="text-ink-muted-2 text-xs text-center leading-snug">
          Un pokémon supplémentaire peut être ajouté par un autre dresseur ici
        </p>
      )}
    </div>
  )
}

// Case minimale en dessous de laquelle un pokémon devient difficile à voir
// (sprite + pseudo + jauge XP) — au-delà de ce seuil la grille défile plutôt
// que de continuer à rétrécir les cases.
const MIN_TILE_PX = 96
const GAP_PX = 8

// Grille à emplacements fixes : toujours capacity_total colonnes égales sur une
// seule ligne, places vacantes affichées comme des cases vides plutôt que
// masquées — pour bien montrer combien de place il reste d'un coup d'œil.
// minmax(MIN_TILE_PX, 1fr) laisse les cases rétrécir puis, une fois ce
// plancher atteint (petits écrans / beaucoup de colonnes), la ligne défile
// horizontalement (overflow-x-auto) au lieu de continuer à les tasser.
export function PensionDaycareGrid({
  daycareRoster, pokemonByName, pensionConfig, xpGroupByPokemonNom, pairsByPokemonId, currentPlayerId, now, onSelectCard, onRetrieve, onOpenSelection,
}: Props) {
  const { players } = usePlayers()
  const playersById = useMemo(() => new Map(players.map((p) => [p.id, p])), [players])

  const emptySlots = Math.max(0, pensionConfig.capacity_total - daycareRoster.length)
  const canAdd = !daycareRoster.some((pp) => pp.player_id === currentPlayerId)
  const cols = Math.max(1, pensionConfig.capacity_total)

  return (
    <div className="overflow-x-auto">
      <div
        className="grid gap-2"
        style={{
          gridTemplateColumns: `repeat(${cols}, minmax(${MIN_TILE_PX}px, 1fr))`,
          minWidth: `${cols * MIN_TILE_PX + (cols - 1) * GAP_PX}px`,
        }}
      >
        {daycareRoster.map((pp) => (
          <PensionDaycareCard
            key={pp.id}
            playerPokemon={pp}
            pokemon={pokemonByName.get(pp.pokemon_nom)}
            owner={playersById.get(pp.player_id)}
            isMine={pp.player_id === currentPlayerId}
            pensionConfig={pensionConfig}
            applicable={resolveApplicableXpGroup(pp.pokemon_nom, xpGroupByPokemonNom, pensionConfig)}
            hasPair={(pairsByPokemonId.get(pp.id)?.length ?? 0) > 0}
            now={now}
            onSelect={() => onSelectCard(pp.id)}
            onRetrieve={() => onRetrieve(pp.id)}
          />
        ))}
        {Array.from({ length: emptySlots }, (_, i) => (
          <PensionEmptySlot key={`empty-${i}`} canAdd={canAdd} onAdd={onOpenSelection} />
        ))}
      </div>
    </div>
  )
}
