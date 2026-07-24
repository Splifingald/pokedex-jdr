import { useState, useMemo } from 'react'
import type { Player } from '../types'
import { normalizeSearch } from '../lib/normalizeSearch'

interface Props {
  players: Player[]
  loading: boolean
  isAdmin: boolean
  onSelect: (player: Player) => void
  onClose: () => void
}

function PlayerRow({ p, onSelect }: { p: Player; onSelect: (player: Player) => void }) {
  return (
    <button
      onClick={() => onSelect(p)}
      className="flex items-center gap-3 bg-cream-secondary border-2 border-ink rounded-lg px-3 py-2 hover:brightness-105 transition-all text-left shadow-[var(--shadow-pixel-sm)]"
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
      <span className="text-ink text-sm font-bold">{p.name}</span>
      <span
        className="w-2.5 h-2.5 rounded-full ml-auto shrink-0"
        style={{ backgroundColor: p.color }}
      />
    </button>
  )
}

export function LoginModal({ players, loading, isAdmin, onSelect, onClose }: Props) {
  const [npcQuery, setNpcQuery] = useState('')

  const regularPlayers = useMemo(() => players.filter((p) => !p.is_npc), [players])
  const npcs = useMemo(() => players.filter((p) => p.is_npc), [players])

  const filteredNpcs = useMemo(() => {
    const q = normalizeSearch(npcQuery.trim())
    if (!q) return npcs
    return npcs.filter((p) => normalizeSearch(p.name).includes(q))
  }, [npcs, npcQuery])

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-sm w-full p-6 max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-5">
          <h3 className="text-ink text-lg">Qui joue ?</h3>
          <button onClick={onClose} className="text-ink-muted-2 hover:text-ink text-xl leading-none">✕</button>
        </div>

        {loading ? (
          <p className="text-ink-muted-2 text-sm text-center py-4">Chargement…</p>
        ) : regularPlayers.length === 0 ? (
          <p className="text-ink-muted-2 text-sm text-center py-4">Aucun joueur pour l'instant. Demandez à l'admin d'en créer un.</p>
        ) : (
          <div className="flex flex-col gap-2">
            {regularPlayers.map((p) => (
              <PlayerRow key={p.id} p={p} onSelect={onSelect} />
            ))}
          </div>
        )}

        {isAdmin && (
          <div className="mt-5 pt-4 border-t-2 border-[#cfc7a8]">
            <p className="text-purple-800 text-xs font-bold mb-2">PNJ</p>
            <input
              type="text"
              value={npcQuery}
              onChange={(e) => setNpcQuery(e.target.value)}
              placeholder="Rechercher un PNJ…"
              className="w-full bg-white border-2 border-ink rounded-md px-3 py-2 text-ink text-sm placeholder-ink-muted-2 outline-none mb-2"
            />
            {npcs.length === 0 ? (
              <p className="text-ink-muted-2 text-sm text-center py-2">Aucun PNJ pour l'instant.</p>
            ) : filteredNpcs.length === 0 ? (
              <p className="text-ink-muted-2 text-sm text-center py-2">Aucun résultat.</p>
            ) : (
              <div className="flex flex-col gap-2 max-h-64 overflow-y-auto">
                {filteredNpcs.map((p) => (
                  <PlayerRow key={p.id} p={p} onSelect={onSelect} />
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
