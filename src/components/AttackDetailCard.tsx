import type { Attack } from '../types'
import { getPrecisionColor, formatPrecision } from '../lib/precisionColor'
import { PixelIcon } from './icons/PixelIcon'
import { STAT_ICON, DICE_GENERIC_ICON, ABILITY_DISTANCE_ICON } from '../lib/icons'

function MoveStatIcon({ icon, value, style }: { icon: React.ReactNode; value: React.ReactNode; style?: React.CSSProperties }) {
  return (
    <div className="flex items-center gap-1.5 text-xs">
      <span className="shrink-0 flex items-center">{icon}</span>
      <span className="text-ink" style={style}>{value ?? '—'}</span>
    </div>
  )
}

export function AttackDetailCard({ attack }: { attack: Attack }) {
  return (
    <div className="flex flex-col gap-1.5">
      {attack.effet && (
        <p className="text-ink-muted text-xs italic border-b border-ink/20 pb-1.5">{attack.effet}</p>
      )}
      <div className="grid grid-cols-2 gap-x-3 gap-y-1">
        <div className="flex flex-col gap-1">
          <MoveStatIcon icon={<PixelIcon src={ABILITY_DISTANCE_ICON} size={14} colored />} value={attack.distance} />
          <MoveStatIcon icon={<PixelIcon src={STAT_ICON.damage} size={14} colored />} value={attack.degats_base} />
          <MoveStatIcon icon={<PixelIcon src={DICE_GENERIC_ICON} size={14} colored />} value={attack.degats_de} />
        </div>
        <div className="flex flex-col gap-1">
          <MoveStatIcon icon="👤" value={attack.cible} />
          <MoveStatIcon
            icon="🎯"
            value={formatPrecision(attack.precision)}
            style={{ color: getPrecisionColor(attack.precision), fontWeight: 'bold' }}
          />
        </div>
      </div>
    </div>
  )
}
