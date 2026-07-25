import type { PlayerPokemon, Pokemon } from '../types'
import { ownedPokemonName } from '../types'
import { TypeBadge } from './TypeBadge'
import { HpGauge } from './HpGauge'
import { XpMiniGauge } from './XpMiniGauge'
import { useLocalHp } from '../hooks/useLocalHp'
import { useLocalStatus } from '../hooks/useLocalStatus'
import { getMaxHp } from '../lib/maxHp'
import { getMilestones, getMaxXp } from '../lib/xpBonuses'
import { getStatusInfo } from '../lib/status'
import { PANEL } from '../lib/panelStyles'

interface Props {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  variant: 'grid' | 'list'
  /** Affiche le badge 💻 "au PC" (Pokémon hors équipe active) */
  showPcBadge?: boolean
  onClick: () => void
}

export function PokemonOwnedCard({ playerPokemon, pokemon, variant, showPcBadge = false, onClick }: Props) {
  const maxHp = getMaxHp(playerPokemon, pokemon)
  const [hp] = useLocalHp(playerPokemon.id, maxHp)
  const [status] = useLocalStatus(playerPokemon.id)
  const milestones = getMilestones(pokemon)
  const maxXp = getMaxXp(pokemon)
  const isKo = hp <= 0
  const displayName = ownedPokemonName(playerPokemon)

  const sprite = pokemon?.image_miniature ? (
    <img
      src={pokemon.image_miniature}
      alt={playerPokemon.pokemon_nom}
      className={`pixelated w-full h-full object-contain ${isKo ? 'grayscale opacity-50' : ''}`}
    />
  ) : (
    <span className="text-ink-muted-2 text-3xl">?</span>
  )

  if (variant === 'list') {
    return (
      <button
        onClick={onClick}
        className={`${PANEL} relative flex items-center gap-2.5 p-2 text-left w-full`}
      >
        <div className="w-11 h-11 shrink-0 rounded-md border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
          {sprite}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="text-ink text-sm font-bold truncate">{displayName}</span>
            {status !== 'aucun' && (
              <span className="text-[10px] font-bold shrink-0" style={{ color: getStatusInfo(status).color }}>
                {getStatusInfo(status).label}
              </span>
            )}
          </div>
          <HpGauge current={hp} max={maxHp} />
        </div>
        {showPcBadge && <span className="text-base shrink-0" title="Au PC">💻</span>}
        {pokemon && <TypeBadge type={pokemon.type} small />}
      </button>
    )
  }

  return (
    <button
      onClick={onClick}
      className={`${PANEL} relative flex flex-col gap-1.5 p-2 text-left`}
    >
      {showPcBadge && (
        <span
          className="absolute top-1.5 right-1.5 z-[1] text-sm bg-cream/95 border-2 border-ink rounded-md px-1"
          title="Au PC"
        >
          💻
        </span>
      )}

      <div className="w-full aspect-square rounded-md border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
        {sprite}
      </div>

      <div className="flex items-center justify-between gap-1.5 min-w-0">
        <span className="text-ink text-sm font-bold truncate">{displayName}</span>
        {pokemon && <TypeBadge type={pokemon.type} small />}
      </div>

      {maxXp != null ? (
        <XpMiniGauge xp={playerPokemon.xp} milestones={milestones} />
      ) : (
        <div className="text-xp-blue text-xs font-bold">XP {playerPokemon.xp}</div>
      )}

      {status !== 'aucun' && (
        <div className="text-xs font-bold" style={{ color: getStatusInfo(status).color }}>
          {getStatusInfo(status).label}
        </div>
      )}

      <HpGauge current={hp} max={maxHp} />
    </button>
  )
}
