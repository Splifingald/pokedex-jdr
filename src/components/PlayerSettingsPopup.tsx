import type { Player } from '../types'
import { useFullscreen } from '../hooks/useFullscreen'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  player: Player
  onLogout: () => void
  onClose: () => void
}

export function PlayerSettingsPopup({ player, onLogout, onClose }: Props) {
  const { isFullscreen, toggle } = useFullscreen()

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className="bg-gray-900 border-2 border-gray-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-xs w-full p-6">
        <div className="flex items-center justify-between mb-5">
          <h3 className="text-white text-lg">{player.name}</h3>
          <button onClick={onClose} className="text-gray-500 hover:text-white text-xl leading-none">✕</button>
        </div>

        <label className="flex items-center justify-between mb-5">
          <span className="text-gray-300 text-sm">⛶ Plein écran</span>
          <button
            type="button"
            onClick={toggle}
            role="switch"
            aria-checked={isFullscreen}
            className={`w-11 h-6 rounded-full transition-colors relative shrink-0 ${isFullscreen ? 'bg-blue-500' : 'bg-gray-700'}`}
          >
            <span
              className={`absolute top-0.5 w-5 h-5 bg-white rounded-full transition-transform ${isFullscreen ? 'translate-x-5' : 'translate-x-0.5'}`}
            />
          </button>
        </label>

        <button
          onClick={onLogout}
          className={`w-full py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.red}`}
        >
          Déconnecter
        </button>
      </div>
    </div>
  )
}
