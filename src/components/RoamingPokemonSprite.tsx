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
        {/* Couche flottement continu */}
        <div
          className="w-[76px] h-[76px] rounded-lg border-2 border-ink bg-cream/85 flex items-center justify-center overflow-hidden shadow-[var(--shadow-pixel)]"
          style={{ animation: `idle-bob ${bobDuration}s ease-in-out ${bobDelay}s infinite` }}
        >
          {pokemon?.image_miniature ? (
            <img
              src={pokemon.image_miniature}
              alt={playerPokemon.pokemon_nom}
              className={`pixelated max-w-[90%] max-h-[90%] object-contain ${isKo ? 'grayscale opacity-50' : ''}`}
            />
          ) : (
            <span className="text-ink-muted-2 text-2xl">?</span>
          )}
        </div>
      </div>

      <span className="mt-1 px-1.5 py-0.5 rounded text-xs text-[#14320f] bg-cream/90 whitespace-nowrap">
        {hp}/{maxHp} PV
      </span>
    </button>
  )
}
