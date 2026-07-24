import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  onEnable: () => void
  onClose: () => void
}

export function FullscreenPromptModal({ onEnable, onClose }: Props) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-xs w-full p-6">
        <div className="text-center mb-5">
          <div className="text-4xl mb-2">⛶</div>
          <h3 className="text-ink text-lg">Activer le plein écran</h3>
          <p className="text-ink-muted text-xs mt-2">
            Vous pourrez l'activer à tout moment via le bouton ⚙️ en haut de l'écran.
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
