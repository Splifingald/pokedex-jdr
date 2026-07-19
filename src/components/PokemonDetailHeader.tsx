import { useState, useRef, useEffect } from 'react'
import type { Pokemon } from '../types'
import { HpGauge } from './HpGauge'
import { ImageLightbox } from './ImageLightbox'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { useHoldRepeat } from '../hooks/useHoldRepeat'

interface Props {
  pokemonNom: string
  pokemon: Pokemon | undefined
  hp: number
  maxHp: number
  onHpChange: (value: number) => void
  onMaxHpChange: (value: number) => void
  xp: number
  onXpChange: (value: number) => void
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
  onMaxHpChange,
  xp,
  onXpChange,
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
            <span className="text-gray-400 text-xs">XP</span>
            <input
              type="number"
              value={xp}
              onChange={(e) => onXpChange(parseInt(e.target.value) || 0)}
              className="w-16 bg-gray-900 border border-gray-700 rounded px-1 py-0.5 text-blue-400 font-bold text-sm text-center outline-none focus:border-blue-500"
            />
          </div>

          <div className="flex items-center gap-2">
            <span className="text-gray-400 text-xs">Max HP</span>
            <input
              type="number"
              value={maxHp}
              onChange={(e) => onMaxHpChange(parseInt(e.target.value) || 0)}
              title="Personnaliser les PV max de ce pokémon (n'affecte que le vôtre)"
              className="w-16 bg-gray-900 border border-gray-700 rounded px-1 py-0.5 text-white text-sm text-center outline-none focus:border-blue-500"
            />
          </div>
        </div>

        <HpGauge current={hp} max={maxHp} />
      </div>

      {lightboxOpen && pokemon?.image_illustree && (
        <ImageLightbox src={pokemon.image_illustree} alt={pokemonNom} onClose={() => setLightboxOpen(false)} />
      )}
    </div>
  )
}
