import type { Player } from '../types'

interface Props {
  player: Player
  onLogout: () => void
}

export function PlayerBadge({ player, onLogout }: Props) {
  return (
    <div className="flex items-center gap-2 bg-black/20 rounded-full pl-1 pr-2 py-1">
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
      <span className="text-white text-sm font-bold max-w-[8rem] truncate">{player.name}</span>
      <button
        onClick={onLogout}
        title="Se déconnecter"
        className="text-gray-300 hover:text-white text-sm leading-none ml-1"
      >
        ✕
      </button>
    </div>
  )
}
