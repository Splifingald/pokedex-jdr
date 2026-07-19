import type { Pokemon } from '../types'
import { HpGauge } from './HpGauge'

interface Props {
  pokemonNom: string
  pokemon: Pokemon | undefined
  hp: number
  maxHp: number
  onHpChange: (value: number) => void
  xp: number
  onXpChange: (value: number) => void
  onBack: () => void
}

export function OwnedPokemonHeader({ pokemonNom, pokemon, hp, maxHp, onHpChange, xp, onXpChange, onBack }: Props) {
  return (
    <div className="border-b border-gray-700 shrink-0">
      <button
        onClick={onBack}
        className="flex items-center gap-2 px-4 py-3 text-red-400 hover:text-red-300 border-b border-gray-800"
      >
        <span className="text-lg">◀</span>
        <span className="text-sm">Retour</span>
      </button>

      <div className="flex items-center gap-4 px-4 py-4">
        <div className="w-16 h-16 shrink-0 flex items-center justify-center bg-gray-800 rounded">
          {pokemon?.image_miniature ? (
            <img
              src={pokemon.image_miniature}
              alt={pokemonNom}
              className={`pixelated max-h-14 object-contain ${hp <= 0 ? 'grayscale opacity-50' : ''}`}
            />
          ) : (
            <span className="text-gray-600 text-2xl">?</span>
          )}
        </div>

        <div className="flex-1 min-w-0">
          <h2 className="text-white text-xl mb-2 truncate">{pokemonNom}</h2>

          <div className="flex items-center gap-4 flex-wrap">
            <div className="flex items-center gap-2">
              <span className="text-gray-400 text-xs">HP</span>
              <button
                onClick={() => onHpChange(hp - 1)}
                className="w-6 h-6 rounded bg-gray-800 border border-gray-600 text-white hover:bg-gray-700"
              >
                −
              </button>
              <input
                type="number"
                value={hp}
                onChange={(e) => onHpChange(parseInt(e.target.value) || 0)}
                className="w-14 bg-gray-900 border border-gray-700 rounded px-1 py-0.5 text-white text-sm text-center outline-none focus:border-red-500"
              />
              <button
                onClick={() => onHpChange(hp + 1)}
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
          </div>

          <div className="mt-2 max-w-xs">
            <HpGauge current={hp} max={maxHp} />
          </div>
        </div>
      </div>
    </div>
  )
}
