import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PANEL_LG } from '../lib/panelStyles'
import { PixelIcon } from './icons/PixelIcon'
import { SETTINGS_ICON } from '../lib/icons'

interface Props {
  loading: boolean
  onEnable: () => void
  onClose: () => void
}

export function NotificationPromptModal({ loading, onEnable, onClose }: Props) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className={`${PANEL_LG} max-w-xs w-full p-6 text-ink`}>
        <div className="text-center mb-5">
          <div className="text-4xl mb-2">🔔</div>
          <h3 className="text-ink text-lg">Activer les notifications</h3>
          <p className="text-ink-muted text-xs mt-2">
            Pour être prévenu des cadeaux, échanges et messages même quand l'app est fermée.
          </p>
          <p className="text-ink-muted text-xs mt-2 inline-flex flex-wrap items-center justify-center gap-1">
            Tu pourras les activer à tout moment via le bouton <PixelIcon src={SETTINGS_ICON} size={12} colored /> en haut de l'écran.
          </p>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <button
            onClick={onClose}
            disabled={loading}
            className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.gray} disabled:opacity-60`}
          >
            Plus tard
          </button>
          <button
            onClick={onEnable}
            disabled={loading}
            className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.blue} disabled:opacity-60`}
          >
            {loading ? 'Activation…' : 'Activer'}
          </button>
        </div>
      </div>
    </div>
  )
}
