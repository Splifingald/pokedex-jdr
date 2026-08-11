import type { Attack } from '../types'
import { TypeBadge } from './TypeBadge'
import { AttackDetailCard } from './AttackDetailCard'
import { CARD } from '../lib/panelStyles'
import { CloseIcon } from './icons/CloseIcon'

interface Props {
  attack: Attack
  onRemove?: () => void
  onClick?: () => void
}

// Carte capacité détaillée : en-tête badge de type + nom, puis stats via AttackDetailCard
export function AbilityCard({ attack, onRemove, onClick }: Props) {
  return (
    <div
      className={`${CARD} p-2.5 ${onClick ? 'cursor-pointer hover:brightness-95' : ''}`}
      onClick={onClick}
    >
      <div className="flex items-center justify-between gap-2 mb-1.5">
        <div className="flex items-center gap-2 min-w-0">
          <TypeBadge type={attack.type} small />
          <span className="text-ink text-sm font-bold truncate">{attack.nom}</span>
        </div>
        {onRemove && (
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); onRemove() }}
            className="text-ink-muted-2 hover:text-hp-red text-sm leading-none shrink-0"
            title="Retirer la capacité"
          >
            <CloseIcon className="w-3.5 h-3.5" />
          </button>
        )}
      </div>
      <AttackDetailCard attack={attack} />
    </div>
  )
}
