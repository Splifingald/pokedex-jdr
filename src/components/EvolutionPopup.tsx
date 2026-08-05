import { useState, useEffect } from 'react'
import type { Pokemon } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { ConfettiRain, ConfettiBurst, Sparkles } from './ConfettiEffects'

interface Props {
  fromSpecies: Pokemon | undefined
  toSpecies: Pokemon | undefined
  fromDisplayName: string
  toDisplayName: string
  onDone: () => void
}

type Phase = 'enter' | 'flashing' | 'revealing' | 'done'

export function EvolutionPopup({ fromSpecies, toSpecies, fromDisplayName, toDisplayName, onDone }: Props) {
  const [phase, setPhase] = useState<Phase>('enter')
  const [showNewSprite, setShowNewSprite] = useState(false)

  useEffect(() => {
    const timers = [
      window.setTimeout(() => setPhase('flashing'), 300),
      window.setTimeout(() => setShowNewSprite(true), 300 + 1300),
      window.setTimeout(() => setPhase('revealing'), 300 + 2600),
      window.setTimeout(() => setPhase('done'), 300 + 2600 + 500),
    ]
    return () => timers.forEach((t) => clearTimeout(t))
  }, [])

  const sprite = showNewSprite ? toSpecies : fromSpecies
  const isFlashing = phase === 'flashing'
  const isRevealed = phase === 'revealing' || phase === 'done'
  const isSparkling = isFlashing || isRevealed

  return (
    <div className="fixed inset-0 z-[90] bg-black/90 flex flex-col items-center justify-center px-6 overflow-hidden">
      {isRevealed && <ConfettiRain />}

      {/* Même gabarit que les Pokémon en balade sur l'accueil (RoamingPokemonSprite) */}
      <div
        className={`relative w-[304px] h-[304px] max-w-[80vw] max-h-[45vh] flex items-center justify-center ${
          phase === 'revealing' ? 'animate-[evolution-shake_0.3s_ease-in-out]' : ''
        }`}
      >
        {isRevealed && (
          <div
            className="absolute w-full h-full rounded-full pointer-events-none animate-[evolution-burst_0.6s_ease-out_forwards]"
            style={{ background: 'radial-gradient(circle, rgba(255,255,255,0.95), rgba(255,215,120,0.5) 45%, transparent 72%)' }}
          />
        )}
        {isRevealed && <ConfettiBurst />}
        {isSparkling && <Sparkles />}

        {sprite?.image_miniature ? (
          <img
            src={sprite.image_miniature}
            alt=""
            className={`relative pixelated w-full h-full object-contain transition-[filter] duration-300 ${
              isFlashing ? 'animate-[evolution-flash_0.3s_steps(1)_infinite]' : ''
            } ${phase === 'enter' ? 'animate-[celebrate-pop_0.3s_ease-out]' : ''}`}
            style={!isFlashing ? { filter: 'drop-shadow(2px 4px 2px rgba(0,0,0,0.3))' } : undefined}
          />
        ) : (
          <span className="text-cream text-4xl">?</span>
        )}
      </div>

      {isRevealed && (
        <div className="relative mt-6 text-center animate-[celebrate-pop_0.4s_ease-out]">
          <p className="text-cream text-xl">
            {fromDisplayName} a évolué en <span className="font-bold">{toDisplayName}</span> !
          </p>
        </div>
      )}

      {phase === 'done' && (
        <button
          onClick={onDone}
          className={`relative mt-6 px-6 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.yellow}`}
        >
          Continuer
        </button>
      )}
    </div>
  )
}
