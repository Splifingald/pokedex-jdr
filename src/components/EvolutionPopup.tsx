import { useState, useEffect, useMemo } from 'react'
import type { Pokemon } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  fromSpecies: Pokemon | undefined
  toSpecies: Pokemon | undefined
  fromDisplayName: string
  toDisplayName: string
  onDone: () => void
}

type Phase = 'enter' | 'flashing' | 'revealing' | 'done'

const CONFETTI_COLORS = ['#4caf6b', '#e8933d', '#4a7fd6', '#dc0a2d', '#f0e08f']

function Confetti() {
  const pieces = useMemo(
    () =>
      Array.from({ length: 28 }, (_, i) => ({
        id: i,
        left: Math.random() * 100,
        delay: Math.random() * 0.4,
        duration: 1.1 + Math.random() * 0.6,
        color: CONFETTI_COLORS[i % CONFETTI_COLORS.length],
        size: 6 + Math.random() * 6,
      })),
    []
  )

  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      {pieces.map((p) => (
        <span
          key={p.id}
          className="absolute top-0 rounded-sm"
          style={{
            left: `${p.left}%`,
            width: p.size,
            height: p.size,
            backgroundColor: p.color,
            animation: `confetti-fall ${p.duration}s linear ${p.delay}s infinite`,
          }}
        />
      ))}
    </div>
  )
}

export function EvolutionPopup({ fromSpecies, toSpecies, fromDisplayName, toDisplayName, onDone }: Props) {
  const [phase, setPhase] = useState<Phase>('enter')
  const [showNewSprite, setShowNewSprite] = useState(false)

  useEffect(() => {
    const timers = [
      window.setTimeout(() => setPhase('flashing'), 300),
      window.setTimeout(() => setShowNewSprite(true), 300 + 900),
      window.setTimeout(() => setPhase('revealing'), 300 + 1800),
      window.setTimeout(() => setPhase('done'), 300 + 1800 + 500),
    ]
    return () => timers.forEach((t) => clearTimeout(t))
  }, [])

  const sprite = showNewSprite ? toSpecies : fromSpecies
  const isFlashing = phase === 'flashing'
  const isRevealed = phase === 'revealing' || phase === 'done'

  return (
    <div className="fixed inset-0 z-[90] bg-black/90 flex flex-col items-center justify-center px-6 overflow-hidden">
      {isRevealed && <Confetti />}
      <div className="relative w-56 h-56 flex items-center justify-center">
        {sprite?.image_miniature ? (
          <img
            src={sprite.image_miniature}
            alt=""
            className={`pixelated max-w-full max-h-full object-contain transition-[filter] duration-300 ${isFlashing ? 'animate-[evolution-flash_0.3s_steps(1)_infinite]' : ''}`}
            style={!isFlashing ? { filter: 'none' } : undefined}
          />
        ) : (
          <span className="text-cream text-4xl">?</span>
        )}
      </div>

      <div className={`mt-6 text-center transition-opacity duration-300 ${isRevealed ? 'opacity-100' : 'opacity-0'}`}>
        <p className="text-cream text-xl">
          {fromDisplayName} a évolué en <span className="font-bold">{toDisplayName}</span> !
        </p>
      </div>

      {phase === 'done' && (
        <button
          onClick={onDone}
          className={`mt-6 px-6 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.yellow}`}
        >
          Continuer
        </button>
      )}
    </div>
  )
}
