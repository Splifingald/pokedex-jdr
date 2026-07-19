import type { Player } from '../types'

interface Props {
  players: Player[]
  loading: boolean
  onSelect: (player: Player) => void
  onClose: () => void
}

export function LoginModal({ players, loading, onSelect, onClose }: Props) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="bg-gray-900 border-2 border-gray-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-sm w-full p-6">
        <div className="flex items-center justify-between mb-5">
          <h3 className="text-white text-lg">Qui joue ?</h3>
          <button onClick={onClose} className="text-gray-500 hover:text-white text-xl leading-none">✕</button>
        </div>

        {loading ? (
          <p className="text-gray-500 text-sm text-center py-4">Chargement…</p>
        ) : players.length === 0 ? (
          <p className="text-gray-500 text-sm text-center py-4">Aucun joueur pour l'instant. Demandez à l'admin d'en créer un.</p>
        ) : (
          <div className="flex flex-col gap-2 max-h-96 overflow-y-auto">
            {players.map((p) => (
              <button
                key={p.id}
                onClick={() => onSelect(p)}
                className="flex items-center gap-3 bg-gray-800 border border-gray-700 rounded px-3 py-2 hover:bg-gray-700 transition-colors text-left"
              >
                <div
                  className="w-10 h-10 rounded-full overflow-hidden shrink-0 border-2"
                  style={{ borderColor: p.color }}
                >
                  {p.image_url ? (
                    <img src={p.image_url} alt={p.name} className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full" style={{ backgroundColor: p.color }} />
                  )}
                </div>
                <span className="text-white text-sm font-bold">{p.name}</span>
                <span
                  className="w-2.5 h-2.5 rounded-full ml-auto shrink-0"
                  style={{ backgroundColor: p.color }}
                />
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
