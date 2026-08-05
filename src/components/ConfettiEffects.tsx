import { useMemo, type CSSProperties } from 'react'

export const CONFETTI_COLORS = ['#4caf6b', '#e8933d', '#4a7fd6', '#dc0a2d', '#f0e08f']

// Pluie de confettis continue, jouée en boucle tant qu'un état est révélé.
export function ConfettiRain() {
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
export function ConfettiBurst() {
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

// Étincelles qui scintillent autour d'un élément pendant une révélation.
export function Sparkles() {
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
