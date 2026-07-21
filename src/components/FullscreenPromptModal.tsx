import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  onEnable: () => void
  onClose: () => void
}

export function FullscreenPromptModal({ onEnable, onClose }: Props) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="bg-gray-900 border-2 border-gray-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-xs w-full p-6">
        <div className="text-center mb-5">
          <div className="text-4xl mb-2">⛶</div>
          <h3 className="text-white text-lg">Activer le plein écran</h3>
          <p className="text-gray-400 text-xs mt-2">
            Vous pourrez l'activer à tout moment en cliquant sur votre profil joueur.
          </p>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <button onClick={onClose} className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.gray}`}>
            Fermer
          </button>
          <button onClick={onEnable} className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.blue}`}>
            OK
          </button>
        </div>
      </div>
    </div>
  )
}
