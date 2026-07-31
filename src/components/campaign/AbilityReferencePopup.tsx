import type { Attack } from '../../types'
import { ReferencePopupShell } from './ReferencePopupShell'
import { AttackDetailCard } from '../AttackDetailCard'
import { TypeBadge } from '../TypeBadge'

interface Props {
  attack: Attack
  onClose: () => void
  elevated?: boolean
}

export function AbilityReferencePopup({ attack, onClose, elevated }: Props) {
  return (
    <ReferencePopupShell icon="🥊" title={attack.nom} onClose={onClose} elevated={elevated}>
      <div className="mb-3">
        <TypeBadge type={attack.type} small />
      </div>
      <AttackDetailCard attack={attack} />
    </ReferencePopupShell>
  )
}
