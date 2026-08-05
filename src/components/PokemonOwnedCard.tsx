import type { PlayerPokemon, Pokemon } from '../types'
import { ownedPokemonName } from '../types'
import { TypeBadge } from './TypeBadge'
import { HpGauge } from './HpGauge'
import { PixelIcon } from './icons/PixelIcon'
import { useLocalHp } from '../hooks/useLocalHp'
import { useLocalStatus } from '../hooks/useLocalStatus'
import { getMaxHp } from '../lib/maxHp'
import { getStatusInfo } from '../lib/status'
import { STATUS_ICON, PC_ICON } from '../lib/icons'
import { PANEL } from '../lib/panelStyles'

interface Props {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  variant: 'grid' | 'list'
  /** Affiche le badge "au PC" (Pokémon hors équipe active) */
  showPcBadge?: boolean
  /** Affiche le badge "en pension" — prime sur showPcBadge dans le même coin (en pension implique déjà au PC) */
  showDaycareBadge?: boolean
  onClick: () => void
}

export function PokemonOwnedCard({ playerPokemon, pokemon, variant, showPcBadge = false, showDaycareBadge = false, onClick }: Props) {
  const maxHp = getMaxHp(playerPokemon, pokemon)
  const [hp] = useLocalHp(playerPokemon.id, maxHp)
  const [status] = useLocalStatus(playerPokemon.id)
  const isKo = hp <= 0
  const displayName = ownedPokemonName(playerPokemon)
  const hasStatus = status !== 'aucun'
  const statusInfo = getStatusInfo(status)
  // Contour épais coloré par statut, en plus du panneau standard — override
  // en style inline car les classes border-* de PANEL priment sinon en CSS.
  const statusOutlineStyle = hasStatus
    ? { borderWidth: 4, borderColor: statusInfo.color, borderStyle: 'solid' as const }
    : undefined
  // K.O. prime sur le statut dans le badge (info la plus critique)
  const showBadge = isKo || hasStatus
  const badgeSrc = isKo ? STATUS_ICON.ko : statusInfo.iconSrc
  const badgeTitle = isKo ? 'K.O.' : statusInfo.label

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
        style={statusOutlineStyle}
        className={`${PANEL} relative flex items-center gap-2.5 p-2 text-left w-full`}
      >
        <div className="relative w-11 h-11 shrink-0">
          <div className="w-full h-full rounded-md border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
            {sprite}
          </div>
          {showBadge && badgeSrc && (
            <span
              className="absolute -top-1 -left-1 z-[1] flex items-center justify-center bg-cream/95 border-2 border-ink rounded px-0.5"
              title={badgeTitle}
            >
              <PixelIcon src={badgeSrc} size={14} />
            </span>
          )}
        </div>
        <div className="flex-1 min-w-0">
          <span className="text-ink text-sm font-bold truncate block">{displayName}</span>
          <HpGauge current={hp} max={maxHp} />
        </div>
        {showDaycareBadge ? (
          <span className="shrink-0 text-base" title="En pension">🏡</span>
        ) : (
          showPcBadge && <span className="text-ink shrink-0" title="Au PC"><PixelIcon src={PC_ICON} size={16} colored /></span>
        )}
        {pokemon && <TypeBadge type={pokemon.type} small />}
      </button>
    )
  }

  return (
    <button
      onClick={onClick}
      style={statusOutlineStyle}
      className={`${PANEL} relative flex flex-col gap-1.5 p-2 text-left`}
    >
      {showBadge && badgeSrc && (
        <span
          className="absolute top-1.5 left-1.5 z-[1] w-7 h-7 flex items-center justify-center bg-cream/95 border-2 border-ink rounded-md"
          title={badgeTitle}
        >
          <PixelIcon src={badgeSrc} size={22} />
        </span>
      )}

      {showDaycareBadge ? (
        <span
          className="absolute top-1.5 right-1.5 z-[1] w-7 h-7 flex items-center justify-center bg-cream/95 border-2 border-ink rounded-md text-lg"
          title="En pension"
        >
          🏡
        </span>
      ) : (
        showPcBadge && (
          <span
            className="absolute top-1.5 right-1.5 z-[1] w-7 h-7 flex items-center justify-center bg-cream/95 border-2 border-ink rounded-md"
            title="Au PC"
          >
            <PixelIcon src={PC_ICON} size={22} />
          </span>
        )
      )}

      <div className="w-full aspect-square rounded-md border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
        {sprite}
      </div>

      <div className="flex items-center justify-between gap-1.5 min-w-0">
        <span className="text-ink text-sm font-bold truncate">{displayName}</span>
        {pokemon && <TypeBadge type={pokemon.type} small />}
      </div>

      <HpGauge current={hp} max={maxHp} showValue={false} />
    </button>
  )
}
