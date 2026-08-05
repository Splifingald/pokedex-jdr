import { useMemo } from 'react'
import type { Pokemon, PlayerPokemon, PensionConfig, PensionXpGroup, PensionPair } from '../types'
import { usePlayers } from '../hooks/usePlayers'
import { resolveApplicableXpGroup } from '../lib/pension'
import { PensionDaycareCard } from './PensionDaycareCard'

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
}

// "En liberté" plutôt qu'en grille façon inventaire : une simple rangée qui
// s'enroule si besoin (capacité par défaut = 3 ; les sprites étant volontairement
// très grands, ça s'enroule vite sur petit écran, ce qui est normal).
export function PensionDaycareGrid({
  daycareRoster, pokemonByName, pensionConfig, xpGroupByPokemonNom, pairsByPokemonId, currentPlayerId, now, onSelectCard, onRetrieve,
}: Props) {
  const { players } = usePlayers()
  const playersById = useMemo(() => new Map(players.map((p) => [p.id, p])), [players])

  if (daycareRoster.length === 0) {
    return <p className="text-ink-muted-2 text-sm text-center py-6">Personne en pension pour l'instant.</p>
  }

  return (
    <div className="flex flex-wrap items-start justify-center gap-8 py-2">
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
    </div>
  )
}
