import type { PlayerPokemon, Pokemon } from '../types'
import { TypeBadge } from './TypeBadge'
import { HpGauge } from './HpGauge'
import { useLocalHp } from '../hooks/useLocalHp'

interface Props {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  showHp: boolean
  onClick: () => void
}

export function PokemonOwnedCard({ playerPokemon, pokemon, showHp, onClick }: Props) {
  const maxHp = pokemon?.pv_base ?? 0
  const [hp] = useLocalHp(playerPokemon.id, maxHp)
  const isKo = showHp && hp <= 0

  return (
    <button
      onClick={onClick}
      className="flex flex-col bg-gray-800 border border-gray-700 rounded-lg p-3 hover:border-gray-500 transition-colors text-left"
    >
      <div className="flex items-center justify-center bg-gray-900 rounded mb-2" style={{ minHeight: '80px' }}>
        {pokemon?.image_miniature ? (
          <img
            src={pokemon.image_miniature}
            alt={pokemon.nom}
            className={`pixelated max-h-20 object-contain ${isKo ? 'grayscale opacity-50' : ''}`}
          />
        ) : (
          <span className="text-gray-600 text-3xl">?</span>
        )}
      </div>

      <div className="flex items-center justify-between gap-2 mb-1">
        <span className="text-white text-sm font-bold truncate">{playerPokemon.pokemon_nom}</span>
        {pokemon && <TypeBadge type={pokemon.type} small />}
      </div>

      <div className="text-blue-400 text-xs font-bold mb-2">XP {playerPokemon.xp}</div>

      {showHp && <HpGauge current={hp} max={maxHp} />}
    </button>
  )
}
