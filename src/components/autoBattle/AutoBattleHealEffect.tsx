import { useMemo, type CSSProperties } from 'react'

interface Props {
  amount: number
  animKey: number
}

// Bulles vertes montantes + nombre de PV rendus, sur le pokémon qui se
// soigne (toujours après les dégâts qu'il vient d'infliger, voir
// AutoBattleScreen) — remonté via `key={animKey}` à chaque occurrence, même
// idiome que AutoBattleDamageNumber.
export function AutoBattleHealEffect({ amount, animKey }: Props) {
  const bubbles = useMemo(
    () => Array.from({ length: 14 }, (_, i) => ({
      id: i,
      left: 5 + Math.random() * 90,
      top: 5 + Math.random() * 85,
      drift: (Math.random() - 0.5) * 40,
      delay: Math.random() * 0.25,
      size: 9 + Math.random() * 12,
    })),
    // eslint-disable-next-line react-hooks/exhaustive-deps -- volontairement figé par occurrence (animKey), pas par amount
    [animKey]
  )

  return (
    <div key={animKey} className="absolute inset-0 pointer-events-none overflow-visible">
      {bubbles.map((b) => (
        <span
          key={b.id}
          className="absolute rounded-full bg-[#4ff08a] border-2 border-[#2fb85e]"
          style={{
            left: `${b.left}%`, top: `${b.top}%`, width: b.size, height: b.size,
            boxShadow: '0 0 10px 3px rgba(79, 240, 138, 0.9)',
            '--bx': `${b.drift}px`,
            animation: `heal-bubble-rise 1.4s ease-out ${b.delay}s forwards`,
          } as CSSProperties}
        />
      ))}
      <div className="absolute inset-x-0 top-0 flex items-center justify-center" style={{ opacity: 0, animation: 'damage-number-pop 1.3s ease-out 0.1s forwards' }}>
        <span className="text-2xl font-bold text-[#2f8f4f] [text-shadow:0_2px_0_rgba(255,255,255,0.5)]">+{amount} PV</span>
      </div>
    </div>
  )
}
