import { BUTTON_STYLE } from '../lib/buttonStyles'
import { DICE_GENERIC_ICON } from '../lib/icons'
import { PixelIcon } from './icons/PixelIcon'

interface Props {
  pick: number | null
  onToggle: () => void
}

export function EncounterQuickPickBar({ pick, onToggle }: Props) {
  return (
    <button
      onClick={onToggle}
      className={`flex items-center gap-1.5 mb-2 px-2.5 py-1.5 rounded-md text-xs font-bold ${pick != null ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
    >
      <PixelIcon src={DICE_GENERIC_ICON} size={14} colored className="text-ink" alt="" />
      {pick != null ? `Tirage rapide : ${pick} (cliquer pour réinitialiser)` : 'Tirage rapide (1-20)'}
    </button>
  )
}
