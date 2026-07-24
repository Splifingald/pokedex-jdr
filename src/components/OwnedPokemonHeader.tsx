import { useRef, useEffect, useMemo } from 'react'
import type { Pokemon } from '../types'
import type { StatusId } from '../lib/status'
import { STATUS_LIST, getStatusInfo } from '../lib/status'
import { getMilestones, getMaxXp } from '../lib/xpBonuses'
import { HpGauge } from './HpGauge'
import { XpGauge } from './XpGauge'
import { NumberInput } from './NumberInput'
import { TypeBadge } from './TypeBadge'
import { BUTTON_STYLE, type ButtonColor } from '../lib/buttonStyles'
import { PANEL, PIXEL_BORDER_SM } from '../lib/panelStyles'
import { useHoldRepeat } from '../hooks/useHoldRepeat'

interface Props {
  pokemonNom: string
  pokemon: Pokemon | undefined
  hp: number
  maxHp: number
  onHpChange: (value: number) => void
  xp: number
  onXpChange: (value: number) => void
  status: StatusId
  onStatusChange: (value: StatusId) => void
  onBack: () => void
  actionLabel: string
  actionTitle?: string
  actionColor?: ButtonColor
  onAction: () => void
}

export function OwnedPokemonHeader({
  pokemonNom,
  pokemon,
  hp,
  maxHp,
  onHpChange,
  xp,
  onXpChange,
  status,
  onStatusChange,
  onBack,
  actionLabel,
  actionTitle,
  actionColor = 'blue',
  onAction,
}: Props) {
  const hpRef = useRef(hp)
  useEffect(() => { hpRef.current = hp }, [hp])
  const decrementHold = useHoldRepeat(() => onHpChange(hpRef.current - 1))
  const incrementHold = useHoldRepeat(() => onHpChange(hpRef.current + 1))
  const milestones = useMemo(() => getMilestones(pokemon), [pokemon])
  const maxXp = useMemo(() => getMaxXp(pokemon), [pokemon])

  return (
    <div className="shrink-0 px-4 pt-3">
      <button
        onClick={onBack}
        className="flex items-center gap-2 mb-3 text-cream hover:text-white"
      >
        <span className="text-lg">◀</span>
        <span className="text-sm">Retour</span>
      </button>

      <div className={`${PANEL} p-3.5`}>
        <div className="flex items-center gap-4">
          <div className={`w-16 h-16 shrink-0 flex items-center justify-center rounded-lg ${PIXEL_BORDER_SM} bg-cream-secondary overflow-hidden`}>
            {pokemon?.image_miniature ? (
              <img
                src={pokemon.image_miniature}
                alt={pokemonNom}
                className={`pixelated max-h-14 object-contain ${hp <= 0 ? 'grayscale opacity-50' : ''}`}
              />
            ) : (
              <span className="text-ink-muted-2 text-2xl">?</span>
            )}
          </div>

          <div className="flex-1 min-w-0">
            <div className="flex items-center justify-between gap-3 mb-2">
              <div className="flex items-center gap-2 flex-1 min-w-0">
                <h2 className="text-ink text-xl truncate">{pokemonNom}</h2>
                {pokemon && <TypeBadge type={pokemon.type} small />}
              </div>
              <button
                onClick={onAction}
                title={actionTitle}
                className={`px-4 py-2 rounded-md font-bold text-sm shrink-0 ${BUTTON_STYLE[actionColor]}`}
              >
                {actionLabel}
              </button>
            </div>

            <div className="flex items-center gap-4 flex-wrap">
              <div className="flex items-center gap-2">
                <span className="text-ink-muted-2 text-xs">PV</span>
                <button
                  {...decrementHold}
                  className={`w-6 h-6 rounded ${PIXEL_BORDER_SM} bg-cream-button text-ink hover:brightness-105`}
                >
                  −
                </button>
                <NumberInput
                  value={hp}
                  onCommit={onHpChange}
                  className="w-14 bg-white border-2 border-ink rounded px-1 py-0.5 text-ink text-sm text-center outline-none"
                />
                <button
                  {...incrementHold}
                  className={`w-6 h-6 rounded ${PIXEL_BORDER_SM} bg-cream-button text-ink hover:brightness-105`}
                >
                  +
                </button>
              </div>

              <div className="flex items-center gap-2">
                <span className="text-ink-muted-2 text-xs">Statut</span>
                <select
                  value={status}
                  onChange={(e) => onStatusChange(e.target.value as StatusId)}
                  className="bg-white border-2 border-ink rounded px-2 py-1 text-ink text-sm outline-none"
                >
                  {STATUS_LIST.map((s) => (
                    <option key={s.id} value={s.id}>{s.label}</option>
                  ))}
                </select>
              </div>
            </div>
          </div>
        </div>

        {status !== 'aucun' && (
          <div
            className="mt-2 rounded px-3 py-2 text-xs border-2"
            style={{ borderColor: getStatusInfo(status).color, backgroundColor: `${getStatusInfo(status).color}22`, color: '#201c14' }}
          >
            <span className="font-bold" style={{ color: getStatusInfo(status).color }}>{getStatusInfo(status).label}</span>
            {' — '}{getStatusInfo(status).description}
          </div>
        )}

        <div className="mt-2 flex flex-col gap-2">
          <HpGauge current={hp} max={maxHp} />
          {maxXp != null ? (
            <XpGauge xp={xp} max={maxXp} milestones={milestones} onXpChange={onXpChange} />
          ) : (
            <div className="flex items-center gap-2">
              <span className="text-ink-muted-2 text-xs">Expérience</span>
              <button
                onClick={() => onXpChange(Math.max(0, xp - 1))}
                className={`w-6 h-6 rounded ${PIXEL_BORDER_SM} bg-cream-button text-ink hover:brightness-105`}
              >
                −
              </button>
              <NumberInput
                value={xp}
                onCommit={(v) => onXpChange(Math.max(0, v))}
                className="w-16 bg-white border-2 border-ink rounded px-1 py-0.5 text-xp-blue font-bold text-sm text-center outline-none"
              />
              <button
                onClick={() => onXpChange(xp + 1)}
                className={`w-6 h-6 rounded ${PIXEL_BORDER_SM} bg-cream-button text-ink hover:brightness-105`}
              >
                +
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
