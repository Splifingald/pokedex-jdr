import type { Attack } from '../../types'
import { ReferencePopupShell } from './ReferencePopupShell'
import { AttackDetailCard } from '../AttackDetailCard'
import { TypeBadge } from '../TypeBadge'

interface Props {
  attack: Attack
  onClose: () => void
}

export function AbilityReferencePopup({ attack, onClose }: Props) {
  return (
    <ReferencePopupShell icon="🥊" title={attack.nom} onClose={onClose}>
      <div className="mb-3">
        <TypeBadge type={attack.type} small />
      </div>
      <AttackDetailCard attack={attack} />
    </ReferencePopupShell>
  )
}
