import type { Attack } from '../../types'
import type { ResolvedToken } from '../../lib/onlineTokens'
import { getStatusInfo, type StatusId } from '../../lib/status'
import { STAT_ICON } from '../../lib/icons'
import { PIXEL_BORDER_SM, CARD } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { TypeBadge } from '../TypeBadge'
import { HpGauge } from '../HpGauge'
import { StatusSelect } from '../StatusSelect'
import { NumberInput } from '../NumberInput'
import { PixelIcon } from '../icons/PixelIcon'
import { AttackDetailCard } from '../AttackDetailCard'
import { useHoldRepeat } from '../../hooks/useHoldRepeat'

interface Props {
  resolved: ResolvedToken
  attacksByName: Map<string, Attack>
  /** Le spectateur peut-il modifier PV et statut ? (le sien, ou tout si MJ) */
  canEdit: boolean
  /** Capacité dont la portée est actuellement allumée sur le plateau. */
  selectedMove: string | null
  onSelectMove: (nom: string | null) => void
  onSetHp: (value: number) => void
  onSetStatus: (value: StatusId) => void
  onRemove?: () => void
  onBack: () => void
}

// Fiche de combat d'un jeton, affichée DANS la barre latérale plutôt qu'en
// pop-up : le plateau reste entièrement visible pendant qu'on la consulte.
// Reprend la moitié haute de OwnedVitals (PokemonDetailSheet) — PV, statut,
// jauge — et laisse volontairement de côté ce qui n'a pas sa place en combat :
// XP, évolution, localisation.
export function BattlePokemonRecap({
  resolved, attacksByName, canEdit, selectedMove, onSelectMove, onSetHp, onSetStatus, onRemove, onBack,
}: Props) {
  const { species, owned, displayName, hp, maxHp, status, damage, isFree, ownerName, isKo } = resolved
  const statusInfo = getStatusInfo(status)

  const decrementHold = useHoldRepeat(() => onSetHp(Math.max(0, hp - 1)))
  const incrementHold = useHoldRepeat(() => onSetHp(Math.min(maxHp, hp + 1)))

  const moveNames = owned ? owned.moves : []

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <button onClick={onBack} className={`px-2 py-1 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
        {onRemove && (
          <button onClick={onRemove} className={`ml-auto px-2 py-1 rounded text-xs font-bold ${BUTTON_STYLE.red}`}>
            Retirer du plateau
          </button>
        )}
      </div>

      <div className="flex items-center gap-3">
        <div className="w-14 h-14 shrink-0 flex items-center justify-center">
          {species?.image_miniature && (
            <img
              src={species.image_miniature}
              alt={displayName}
              className={`pixelated w-full h-full object-contain ${isKo ? 'grayscale opacity-50' : ''}`}
            />
          )}
        </div>
        <div className="min-w-0">
          <p className="text-ink font-bold truncate">{displayName}</p>
          <p className="text-ink-muted-2 text-xs truncate">{ownerName}</p>
          {species && <div className="mt-1"><TypeBadge type={species.type} small /></div>}
        </div>
      </div>

      <div>
        <div className="flex items-center gap-3 mb-2 flex-wrap">
          <div className="flex items-center gap-2 shrink-0">
            <span className="text-ink-muted-2 text-xs">PV</span>
            <button
              {...decrementHold}
              disabled={!canEdit}
              className={`w-6 h-6 rounded ${PIXEL_BORDER_SM} bg-cream-button text-ink hover:brightness-105 disabled:opacity-40`}
            >
              −
            </button>
            <NumberInput
              value={hp}
              onCommit={onSetHp}
              disabled={!canEdit}
              className="w-14 bg-white border-2 border-ink rounded px-1 py-0.5 text-ink text-sm text-center outline-none disabled:opacity-60"
            />
            <button
              {...incrementHold}
              disabled={!canEdit}
              className={`w-6 h-6 rounded ${PIXEL_BORDER_SM} bg-cream-button text-ink hover:brightness-105 disabled:opacity-40`}
            >
              +
            </button>
          </div>
          {canEdit && <StatusSelect value={status} onChange={onSetStatus} />}
        </div>

        {status !== 'aucun' && (
          <div
            className="mb-2 rounded px-3 py-2 text-xs border-2"
            style={{ borderColor: statusInfo.color, backgroundColor: `${statusInfo.color}22`, color: '#201c14' }}
          >
            <span className="font-bold" style={{ color: statusInfo.color }}>{statusInfo.label}</span>
            {' — '}{statusInfo.description}
          </div>
        )}

        <HpGauge current={hp} max={maxHp} onChange={canEdit ? onSetHp : undefined} />
      </div>

      <div className="grid grid-cols-2 gap-2">
        <div className={`${CARD} px-2 py-1.5 flex items-center gap-2`}>
          <PixelIcon src={STAT_ICON.damage} size={18} />
          <span className="text-ink text-sm font-bold">{damage}</span>
        </div>
        {species && (
          <div className={`${CARD} px-2 py-1.5 flex items-center gap-2`}>
            <PixelIcon src={STAT_ICON.distance} size={18} />
            <span className="text-ink text-sm font-bold">{species.distance_deplacement} cases</span>
          </div>
        )}
      </div>

      {species?.nom_talent && (
        <div className={`${CARD} px-2.5 py-2`}>
          <div className="flex items-center gap-2 mb-1">
            <PixelIcon src={STAT_ICON.talent} size={16} />
            <span className="text-ink text-sm font-bold">{species.nom_talent}</span>
          </div>
          {species.description_talent && (
            <p className="text-ink-muted text-xs">{species.description_talent}</p>
          )}
        </div>
      )}

      {!isFree && moveNames.length > 0 && (
        <div>
          <p className="text-ink-muted-2 text-xs mb-1.5">
            Capacités — toucher une capacité allume sa portée sur le plateau (visible par toi seul).
          </p>
          <div className="flex flex-col gap-1.5">
            {moveNames.map((nom) => {
              const attack = attacksByName.get(nom)
              const active = selectedMove === nom
              return (
                <div
                  key={nom}
                  onClick={() => onSelectMove(active ? null : nom)}
                  className={`${CARD} p-2 cursor-pointer hover:brightness-95 ${active ? 'ring-[3px] ring-select' : ''}`}
                >
                  <div className="flex items-center gap-2 mb-1 min-w-0">
                    {attack && <TypeBadge type={attack.type} small />}
                    <span className="text-ink text-sm font-bold truncate">{nom}</span>
                  </div>
                  {attack && <AttackDetailCard attack={attack} />}
                </div>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}
