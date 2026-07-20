import type { PlayerPokemon, Pokemon } from '../types'
import { TypeBadge } from './TypeBadge'
import { HpGauge } from './HpGauge'
import { XpMiniGauge } from './XpMiniGauge'
import { useLocalHp } from '../hooks/useLocalHp'
import { useLocalStatus } from '../hooks/useLocalStatus'
import { getMaxHp } from '../lib/maxHp'
import { getMilestones, getMaxXp } from '../lib/xpBonuses'
import { getStatusInfo } from '../lib/status'

interface Props {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  showHp: boolean
  onClick: () => void
}

export function PokemonOwnedCard({ playerPokemon, pokemon, showHp, onClick }: Props) {
  const maxHp = getMaxHp(playerPokemon, pokemon)
  const [hp] = useLocalHp(playerPokemon.id, maxHp)
  const [status] = useLocalStatus(playerPokemon.id)
  const milestones = getMilestones(pokemon)
  const maxXp = getMaxXp(pokemon)
  const isKo = showHp && hp <= 0

  return (
    <button
      onClick={onClick}
      className="flex flex-row items-stretch gap-3 bg-gray-800 border border-gray-700 rounded-lg p-3 hover:border-gray-500 transition-colors text-left"
    >
      <div className="w-20 h-20 shrink-0 flex items-center justify-center bg-gray-900 rounded">
        {pokemon?.image_miniature ? (
          <img
            src={pokemon.image_miniature}
            alt={pokemon.nom}
            className={`pixelated max-h-16 object-contain ${isKo ? 'grayscale opacity-50' : ''}`}
          />
        ) : (
          <span className="text-gray-600 text-3xl">?</span>
        )}
      </div>

      <div className="flex-1 min-w-0 flex flex-col justify-center gap-1">
        <div className="flex items-center justify-between gap-2">
          <span className="text-white text-sm font-bold truncate">{playerPokemon.pokemon_nom}</span>
          {pokemon && <TypeBadge type={pokemon.type} small />}
        </div>

        <div className="text-blue-400 text-xs font-bold">XP {playerPokemon.xp}</div>

        {maxXp != null && <XpMiniGauge xp={playerPokemon.xp} milestones={milestones} />}

        {status !== 'aucun' && (
          <div className="text-xs font-bold" style={{ color: getStatusInfo(status).color }}>
            {getStatusInfo(status).label}
          </div>
        )}

        {showHp && <HpGauge current={hp} max={maxHp} />}
      </div>
    </button>
  )
}
