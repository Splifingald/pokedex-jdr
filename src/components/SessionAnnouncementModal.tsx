import type { OnlineState } from '../types'
import { splitSessionAt } from '../lib/onlineSession'
import { PANEL_LG } from '../lib/panelStyles'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  state: OnlineState
  onClose: () => void
}

// Annonce de la prochaine session, affichée à l'ouverture de l'app.
// Volontairement sans mémoire de fermeture : elle réapparaît à chaque
// ouverture tant que l'annonce est active, mais ne commence à s'afficher qu'à
// N jours de l'échéance (voir shouldShowSessionAnnouncement).
export function SessionAnnouncementModal({ state, onClose }: Props) {
  const { label } = splitSessionAt(state.session_at)

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className={`${PANEL_LG} max-w-xs w-full p-6 text-ink`}>
        <div className="text-center mb-5">
          <div className="text-4xl mb-2">📅</div>
          <h3 className="text-ink text-lg">Prochaine session</h3>
          <p className="text-ink font-bold text-xl mt-2">{label}</p>
          {state.session_message.trim() && (
            <p className="text-ink-muted text-sm mt-3 whitespace-pre-wrap">{state.session_message}</p>
          )}
        </div>
        <button onClick={onClose} className={`w-full py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.green}`}>
          À bientôt !
        </button>
      </div>
    </div>
  )
}
