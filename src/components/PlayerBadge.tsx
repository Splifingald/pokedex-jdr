import { useState } from 'react'
import type { Player } from '../types'
import { PlayerSettingsPopup } from './PlayerSettingsPopup'

interface Props {
  player: Player
  onLogout: () => void
}

export function PlayerBadge({ player, onLogout }: Props) {
  const [showSettings, setShowSettings] = useState(false)

  return (
    <>
      <button
        onClick={() => setShowSettings(true)}
        className="flex items-center gap-2 bg-black/20 rounded-full pl-1 pr-2 py-1 hover:bg-black/30 transition-colors"
      >
        <div
          className="w-6 h-6 rounded-full overflow-hidden shrink-0 border-2"
          style={{ borderColor: player.color }}
        >
          {player.image_url ? (
            <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full" style={{ backgroundColor: player.color }} />
          )}
        </div>
        <span className="hidden min-[400px]:inline text-white text-sm font-bold max-w-[8rem] truncate">{player.name}</span>
      </button>

      {showSettings && (
        <PlayerSettingsPopup
          player={player}
          onLogout={() => { onLogout(); setShowSettings(false) }}
          onClose={() => setShowSettings(false)}
        />
      )}
    </>
  )
}
