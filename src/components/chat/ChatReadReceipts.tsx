import { useState } from 'react'
import type { Player } from '../../types'

interface Props {
  /** Joueurs dont ce message est le dernier lu (PNJ et joueur courant déjà exclus en amont) */
  readers: Player[]
}

// "Vu par" : avatars minuscules affichés sous le dernier message lu par chaque
// joueur. Un clic bascule entre les avatars et la liste des noms en clair.
export function ChatReadReceipts({ readers }: Props) {
  const [showNames, setShowNames] = useState(false)
  if (readers.length === 0) return null

  const names = readers.map((r) => r.name).join(', ')

  return (
    <div className="flex items-center justify-end gap-1 -mt-1.5">
      <span className="text-[10px] text-ink-muted-2 shrink-0">Vu par</span>
      <button
        onClick={() => setShowNames((v) => !v)}
        className="flex items-center gap-0.5 min-w-0"
        title={names}
      >
        {showNames ? (
          <span className="text-[10px] font-bold text-ink-muted text-left break-words">{names}</span>
        ) : (
          readers.map((reader) => (
            <div
              key={reader.id}
              className="w-4 h-4 rounded-full overflow-hidden shrink-0 border"
              style={{ borderColor: reader.color ?? '#a3841a' }}
            >
              {reader.image_url ? (
                <img src={reader.image_url} alt={reader.name} className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full" style={{ backgroundColor: reader.color ?? '#a3841a' }} />
              )}
            </div>
          ))
        )}
      </button>
    </div>
  )
}
