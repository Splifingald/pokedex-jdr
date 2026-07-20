import { useState, useRef, useEffect, useMemo } from 'react'
import type { Pokemon } from '../types'
import type { StatusId } from '../lib/status'
import { STATUS_LIST, getStatusInfo } from '../lib/status'
import { getMilestones, getMaxXp, clampXp } from '../lib/xpBonuses'
import { HpGauge } from './HpGauge'
import { XpGauge } from './XpGauge'
import { ImageLightbox } from './ImageLightbox'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { useHoldRepeat } from '../hooks/useHoldRepeat'

interface Props {
  pokemonNom: string
  pokemon: Pokemon | undefined
  hp: number
  maxHp: number
  onHpChange: (value: number) => void
  xp: number
  onXpChange: (value: number) => void
  status: StatusId
  onStatusChange: (value: StatusId) => void
  onBack: () => void
  onManageMoves: () => void
  movesCount: number
  maxMoves: number
}

export function PokemonDetailHeader({
  pokemonNom,
  pokemon,
  hp,
  maxHp,
  onHpChange,
  xp,
  onXpChange,
  status,
  onStatusChange,
  onBack,
  onManageMoves,
  movesCount,
  maxMoves,
}: Props) {
  const [lightboxOpen, setLightboxOpen] = useState(false)
  const hpRef = useRef(hp)
  useEffect(() => { hpRef.current = hp }, [hp])
  const decrementHold = useHoldRepeat(() => onHpChange(hpRef.current - 1))
  const incrementHold = useHoldRepeat(() => onHpChange(hpRef.current + 1))
  const milestones = useMemo(() => getMilestones(pokemon), [pokemon])
  const maxXp = useMemo(() => getMaxXp(pokemon), [pokemon])

  return (
    <div className="border-b border-gray-700 shrink-0">
      <button
        onClick={onBack}
        className="flex items-center gap-2 px-4 py-3 text-red-400 hover:text-red-300 border-b border-gray-800"
      >
        <span className="text-lg">◀</span>
        <span className="text-sm">Retour</span>
      </button>

      <div className="flex items-center justify-between gap-3 px-6 py-4">
        <h2 className="text-white text-2xl truncate flex-1 min-w-0">{pokemonNom}</h2>
        <button
          onClick={onManageMoves}
          title={`Gérer les capacités (${movesCount}/${maxMoves})`}
          className={`flex items-center gap-2 px-4 py-2 rounded font-bold text-sm shrink-0 ${BUTTON_STYLE.orange}`}
        >
          💥 Capacités
        </button>
      </div>

      <div className="bg-gray-800 flex items-center justify-center p-4 relative group" style={{ minHeight: '160px' }}>
        {pokemon?.image_illustree ? (
          <img
            src={pokemon.image_illustree}
            alt={pokemonNom}
            className={`max-h-56 w-full object-contain cursor-zoom-in transition-opacity group-hover:opacity-80 ${hp <= 0 ? 'grayscale opacity-50' : ''}`}
            onClick={() => setLightboxOpen(true)}
          />
        ) : (
          <div className="text-gray-600 text-center">
            <span className="text-6xl block">?</span>
          </div>
        )}
      </div>

      <div className="px-4 py-4">
        <div className="flex items-center gap-4 flex-wrap mb-2">
          <div className="flex items-center gap-2">
            <span className="text-gray-400 text-xs">HP</span>
            <button
              {...decrementHold}
              className="w-6 h-6 rounded bg-gray-800 border border-gray-600 text-white hover:bg-gray-700"
            >
              −
            </button>
            <input
              type="number"
              value={hp}
              onChange={(e) => onHpChange(parseInt(e.target.value) || 0)}
              className="w-14 bg-gray-900 border border-gray-700 rounded px-1 py-0.5 text-white text-sm text-center outline-none focus:border-blue-500"
            />
            <button
              {...incrementHold}
              className="w-6 h-6 rounded bg-gray-800 border border-gray-600 text-white hover:bg-gray-700"
            >
              +
            </button>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-gray-400 text-xs">Statut</span>
            <select
              value={status}
              onChange={(e) => onStatusChange(e.target.value as StatusId)}
              className="bg-gray-900 border border-gray-700 rounded px-2 py-1 text-white text-sm outline-none focus:border-blue-500"
            >
              {STATUS_LIST.map((s) => (
                <option key={s.id} value={s.id}>{s.label}</option>
              ))}
            </select>
          </div>
        </div>

        {status !== 'aucun' && (
          <div
            className="mb-2 rounded px-3 py-2 text-xs border"
            style={{ borderColor: getStatusInfo(status).color, backgroundColor: `${getStatusInfo(status).color}22`, color: getStatusInfo(status).color }}
          >
            <span className="font-bold">{getStatusInfo(status).label}</span> — {getStatusInfo(status).description}
          </div>
        )}

        <HpGauge current={hp} max={maxHp} />

        <div className="mt-3">
          <div className="flex items-center gap-2 mb-1">
            <span className="text-gray-400 text-xs">XP</span>
            <input
              type="number"
              value={xp}
              onChange={(e) => onXpChange(clampXp(parseInt(e.target.value) || 0, maxXp))}
              className="w-16 bg-gray-900 border border-gray-700 rounded px-1 py-0.5 text-blue-400 font-bold text-sm text-center outline-none focus:border-blue-500"
            />
          </div>
          {maxXp != null && <XpGauge current={xp} max={maxXp} milestones={milestones} />}
        </div>
      </div>

      {lightboxOpen && pokemon?.image_illustree && (
        <ImageLightbox src={pokemon.image_illustree} alt={pokemonNom} onClose={() => setLightboxOpen(false)} />
      )}
    </div>
  )
}
