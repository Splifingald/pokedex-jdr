import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PANEL_LG } from '../lib/panelStyles'

interface Props {
  onClose: () => void
}

export function AddToHomeScreenModal({ onClose }: Props) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className={`${PANEL_LG} max-w-xs w-full p-6 text-ink`}>
        <div className="text-center mb-4">
          <div className="text-4xl mb-2">🔔</div>
          <h3 className="text-ink text-lg">Ajoute l'app à l'écran d'accueil</h3>
          <p className="text-ink-muted text-xs mt-2">
            Sur iPhone/iPad, les notifications ne fonctionnent que si l'app est installée sur l'écran d'accueil.
          </p>
        </div>
        <ol className="text-ink-muted text-xs mb-5 list-decimal list-inside space-y-1.5">
          <li>Appuie sur le bouton <strong>Partager</strong> de Safari</li>
          <li>Choisis <strong>Sur l'écran d'accueil</strong></li>
          <li>Ouvre l'app depuis l'icône créée, puis réactive les notifications ici</li>
        </ol>
        <button onClick={onClose} className={`w-full py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.blue}`}>
          Compris
        </button>
      </div>
    </div>
  )
}
