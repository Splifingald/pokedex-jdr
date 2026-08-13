import { PixelIcon } from './icons/PixelIcon'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PANEL_LG } from '../lib/panelStyles'
import { SAVE_ICON } from '../lib/icons'

interface Props {
  onSaveAndQuit: () => void
  onDiscardAndQuit: () => void
  onCancel: () => void
}

export function UnsavedChangesPopup({ onSaveAndQuit, onDiscardAndQuit, onCancel }: Props) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className={`${PANEL_LG} max-w-xs w-full p-6`}>
        <div className="text-center mb-5">
          <h3 className="text-ink text-lg">Modifications non enregistrées</h3>
          <p className="text-ink-muted text-sm mt-2">Que veux-tu faire avant de quitter ?</p>
        </div>
        <div className="flex flex-col gap-2">
          <button
            onClick={onSaveAndQuit}
            className={`py-2.5 rounded text-sm font-bold inline-flex items-center justify-center gap-1.5 ${BUTTON_STYLE.green}`}
          >
            <PixelIcon src={SAVE_ICON} size={16} />
            Enregistrer et quitter
          </button>
          <button
            onClick={onDiscardAndQuit}
            className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.red}`}
          >
            Quitter sans enregistrer
          </button>
          <button
            onClick={onCancel}
            className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.gray}`}
          >
            Annuler
          </button>
        </div>
      </div>
    </div>
  )
}
