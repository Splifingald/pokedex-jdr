import { useState, useEffect, useMemo, type CSSProperties } from 'react'
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

// Pluie de confettis continue, jouée en boucle tant que l'évolution est révélée.
function ConfettiRain() {
  const pieces = useMemo(
    () =>
      Array.from({ length: 36 }, (_, i) => ({
        id: i,
        left: Math.random() * 100,
        delay: Math.random() * 0.5,
        duration: 1.1 + Math.random() * 0.7,
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

// Éclat de confettis unique qui part du centre au moment de la révélation.
function ConfettiBurst() {
  const pieces = useMemo(
    () =>
      Array.from({ length: 30 }, (_, i) => {
        const angle = Math.random() * Math.PI * 2
        const distance = 140 + Math.random() * 160
        return {
          id: i,
          tx: Math.cos(angle) * distance,
          ty: Math.sin(angle) * distance,
          delay: Math.random() * 0.15,
          duration: 0.7 + Math.random() * 0.4,
          color: CONFETTI_COLORS[i % CONFETTI_COLORS.length],
          size: 6 + Math.random() * 6,
        }
      }),
    []
  )

  return (
    <div className="absolute inset-0 flex items-center justify-center overflow-hidden pointer-events-none">
      {pieces.map((p) => (
        <span
          key={p.id}
          className="absolute rounded-sm"
          style={{
            width: p.size,
            height: p.size,
            backgroundColor: p.color,
            '--tx': `${p.tx}px`,
            '--ty': `${p.ty}px`,
            animation: `confetti-burst ${p.duration}s ease-out ${p.delay}s forwards`,
          } as CSSProperties}
        />
      ))}
    </div>
  )
}

// Étincelles qui scintillent autour du Pokémon pendant les flashs et la révélation.
function Sparkles() {
  const pieces = useMemo(
    () =>
      Array.from({ length: 10 }, (_, i) => {
        const angle = (i / 10) * Math.PI * 2
        const radius = 46 + Math.random() * 10
        return {
          id: i,
          left: 50 + Math.cos(angle) * radius,
          top: 50 + Math.sin(angle) * radius,
          delay: Math.random() * 1.2,
          duration: 0.9 + Math.random() * 0.6,
        }
      }),
    []
  )

  return (
    <div className="absolute inset-0 pointer-events-none">
      {pieces.map((p) => (
        <span
          key={p.id}
          className="absolute text-cream text-lg"
          style={{
            left: `${p.left}%`,
            top: `${p.top}%`,
            animation: `evolution-sparkle ${p.duration}s ease-in-out ${p.delay}s infinite`,
          }}
        >
          ✨
        </span>
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
