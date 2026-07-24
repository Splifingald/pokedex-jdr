import { useMemo } from 'react'
import type { Pokemon, PlayerPokemon } from '../types'
import { useRoamPosition } from '../hooks/useRoamPosition'
import { useLocalHp } from '../hooks/useLocalHp'
import { getMaxHp } from '../lib/maxHp'

interface Props {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  index: number
  isJumping: boolean
  onClick: () => void
}

// Pseudo-vitesse stable (1–5) dérivée du nom : le modèle de données n'a pas
// de stat de vitesse, mais on veut des allures de déambulation variées.
function speedBucket(nom: string): number {
  let h = 0
  for (let i = 0; i < nom.length; i++) h = (h * 31 + nom.charCodeAt(i)) | 0
  return (Math.abs(h) % 5) + 1
}

export function RoamingPokemonSprite({ playerPokemon, pokemon, index, isJumping, onClick }: Props) {
  const speed = useMemo(() => speedBucket(playerPokemon.pokemon_nom), [playerPokemon.pokemon_nom])
  const { pos, duration } = useRoamPosition(speed)
  const maxHp = getMaxHp(playerPokemon, pokemon)
  const [hp] = useLocalHp(playerPokemon.id, maxHp)
  const isKo = hp <= 0

  const bobDuration = 2.2 + index * 0.35
  const bobDelay = index * 0.5

  return (
    <button
      onClick={onClick}
      className="absolute flex flex-col items-center z-[2] -translate-x-1/2"
      style={{
        left: `${pos.left}%`,
        bottom: `${pos.bottom}%`,
        transition: `left ${duration}s linear, bottom ${duration}s linear`,
      }}
    >
      {/* Couche saut (une seule à la fois, pilotée par HomeTab) */}
      <div style={isJumping ? { animation: 'jump-pop 0.55s ease-out 1' } : undefined}>
        {/* Couche flottement continu — conteneur transparent : simple zone cliquable,
            le Pokémon semble se déplacer librement dans la prairie */}
        <div
          className="w-[912px] h-[912px] max-w-[95vw] max-h-[70vh] flex items-center justify-center"
          style={{ animation: `idle-bob ${bobDuration}s ease-in-out ${bobDelay}s infinite` }}
        >
          {pokemon?.image_miniature ? (
            <img
              src={pokemon.image_miniature}
              alt={playerPokemon.pokemon_nom}
              className={`pixelated max-w-full max-h-full object-contain [filter:drop-shadow(2px_4px_2px_rgba(0,0,0,0.3))] ${isKo ? 'grayscale opacity-50' : ''}`}
            />
          ) : (
            <span className="text-[#14320f] text-4xl">?</span>
          )}
        </div>
      </div>

      {/* PV affichés seulement si le Pokémon n'est pas au max */}
      {hp < maxHp && (
        <span className="mt-1 px-1.5 py-0.5 rounded text-xs text-[#14320f] bg-cream/90 whitespace-nowrap">
          {hp}/{maxHp} PV
        </span>
      )}
    </button>
  )
}
