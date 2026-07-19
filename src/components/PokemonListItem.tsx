import { memo } from 'react'
import type { Pokemon } from '../types'
import { EyeIcon } from './icons/EyeIcon'

interface Props {
  pokemon: Pokemon
  isDiscovered: boolean
  isAdmin: boolean
  isSelected: boolean
  isOwnedByPlayer: boolean
  onClick: () => void
}

export const PokemonListItem = memo(function PokemonListItem({
  pokemon,
  isDiscovered,
  isAdmin,
  isSelected,
  isOwnedByPlayer,
  onClick,
}: Props) {
  const visible = isDiscovered || isAdmin

  return (
    <button
      onClick={onClick}
      className={`w-full flex items-center gap-3 px-4 py-2.5 text-left transition-colors border-b border-gray-800
        ${isSelected ? 'bg-red-900 border-l-4 border-l-red-400' : 'hover:bg-gray-800'}
      `}
    >
      <span className={`text-sm font-bold w-10 shrink-0 ${visible ? 'text-red-400' : 'text-gray-500'}`}>
        #{pokemon.numero}
      </span>

      {visible ? (
        <>
          {pokemon.image_miniature ? (
            <img
              src={pokemon.image_miniature}
              alt={pokemon.nom}
              className="w-10 h-10 object-contain shrink-0 pixelated"
              loading="lazy"
            />
          ) : (
            <div className="w-10 h-10 shrink-0 rounded bg-gray-700 flex items-center justify-center text-gray-500 text-xs">?</div>
          )}
          <span className="text-white text-sm truncate flex-1 min-w-0">{pokemon.nom}</span>
          {isAdmin && pokemon.cache && (
            <span className="ml-2 shrink-0 text-xs bg-purple-900 text-purple-300 border border-purple-700 rounded px-1 py-0.5 leading-none">CACHÉ</span>
          )}
          {isOwnedByPlayer ? (
            <img
              src="/pwa-icons/pokeball.svg"
              alt="Dans votre roster"
              title="Vous possédez ce pokémon"
              className="ml-1 shrink-0 w-4 h-4"
            />
          ) : (
            isAdmin && (
              <span title={isDiscovered ? 'Découvert par les joueurs' : 'Pas encore découvert'} className="ml-1 shrink-0">
                <EyeIcon
                  className={`w-4 h-4 text-white transition-opacity ${isDiscovered ? 'opacity-100' : 'opacity-20'}`}
                />
              </span>
            )
          )}
        </>
      ) : (
        <>
          <div className="w-10 h-10 shrink-0 rounded bg-gray-800 border border-gray-600 flex items-center justify-center">
            <span className="text-gray-600 text-lg">?</span>
          </div>
          <span className="text-gray-600 text-sm">???</span>
        </>
      )}
    </button>
  )
})
