import { PANEL_LG } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  onOpen: () => void
  onClose: () => void
}

// Invitation à rejoindre le plateau, affichée dès que le MJ lance une bataille.
//
// Pourquoi une invitation et pas une ouverture automatique : le plateau vit
// dans son propre onglet (/battle), et les navigateurs bloquent window.open
// quand il ne découle pas d'un clic. Un bouton est donc le seul moyen fiable
// d'ouvrir l'onglet — et ça évite de voler le focus à quelqu'un en pleine
// consultation de son sac.
export function BattleInviteModal({ onOpen, onClose }: Props) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className={`${PANEL_LG} max-w-xs w-full p-6 text-ink`}>
        <div className="text-center mb-5">
          <div className="text-4xl mb-2">⚔️</div>
          <h3 className="text-ink text-lg">Une bataille commence !</h3>
          <p className="text-ink-muted text-xs mt-2">
            Le plateau s'ouvre dans un nouvel onglet — tu gardes celui-ci pour ton Pokédex et ton sac.
          </p>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <button onClick={onClose} className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.gray}`}>
            Plus tard
          </button>
          <button onClick={onOpen} className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.green}`}>
            Ouvrir ↗
          </button>
        </div>
      </div>
    </div>
  )
}
