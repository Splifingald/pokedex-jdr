import type { PlayerPokemon, Pokemon } from '../types'
import { OwnedPokemonHeader } from './OwnedPokemonHeader'
import { TypeBadge } from './TypeBadge'
import { useLocalHp } from '../hooks/useLocalHp'

interface Props {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  teamFull: boolean
  onUpdateXp: (id: number, xp: number) => void
  onToggleInTeam: (id: number, inTeam: boolean) => void
  onManageMoves: () => void
  onBack: () => void
}

export function PokemonDetailView({ playerPokemon, pokemon, teamFull, onUpdateXp, onToggleInTeam, onManageMoves, onBack }: Props) {
  const maxHp = pokemon?.pv_base ?? 0
  const [hp, setHp] = useLocalHp(playerPokemon.id, maxHp)

  const disableTeamToggle = !playerPokemon.in_team && teamFull

  return (
    <div className="flex flex-col h-full bg-gray-900 overflow-y-auto">
      <OwnedPokemonHeader
        pokemonNom={playerPokemon.pokemon_nom}
        pokemon={pokemon}
        hp={hp}
        maxHp={maxHp}
        onHpChange={setHp}
        xp={playerPokemon.xp}
        onXpChange={(xp) => onUpdateXp(playerPokemon.id, xp)}
        onBack={onBack}
      />

      <div className="px-4 py-4 flex flex-col gap-3">
        {pokemon && (
          <div className="flex items-center gap-2">
            <span className="text-gray-400 text-sm">Type</span>
            <TypeBadge type={pokemon.type} />
          </div>
        )}

        <div title={disableTeamToggle ? 'Équipe complète' : undefined}>
          <button
            onClick={() => onToggleInTeam(playerPokemon.id, !playerPokemon.in_team)}
            disabled={disableTeamToggle}
            className="w-full py-2.5 bg-gray-800 border border-gray-600 text-white rounded hover:bg-gray-700 transition-colors disabled:opacity-40 disabled:cursor-not-allowed text-sm font-bold"
          >
            {playerPokemon.in_team ? '📦 Mettre au PC' : '⚔️ Ajouter à l\'équipe'}
          </button>
        </div>

        <button
          onClick={onManageMoves}
          className="w-full py-2.5 bg-red-700 border border-red-500 text-white rounded hover:bg-red-600 transition-colors text-sm font-bold"
        >
          🥊 Gérer les capacités ({playerPokemon.moves.length})
        </button>
      </div>
    </div>
  )
}
