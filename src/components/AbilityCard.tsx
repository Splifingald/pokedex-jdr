import type { Attack } from '../types'
import { TypeBadge } from './TypeBadge'
import { AttackDetailCard } from './AttackDetailCard'
import { CARD } from '../lib/panelStyles'

interface Props {
  attack: Attack
  onRemove?: () => void
}

// Carte capacité détaillée : en-tête badge de type + nom, puis stats via AttackDetailCard
export function AbilityCard({ attack, onRemove }: Props) {
  return (
    <div className={`${CARD} p-2.5`}>
      <div className="flex items-center justify-between gap-2 mb-1.5">
        <div className="flex items-center gap-2 min-w-0">
          <TypeBadge type={attack.type} small />
          <span className="text-ink text-sm font-bold truncate">{attack.nom}</span>
        </div>
        {onRemove && (
          <button
            onClick={onRemove}
            className="text-ink-muted-2 hover:text-hp-red text-sm leading-none shrink-0"
            title="Retirer la capacité"
          >
            ✕
          </button>
        )}
      </div>
      <AttackDetailCard attack={attack} />
    </div>
  )
}
