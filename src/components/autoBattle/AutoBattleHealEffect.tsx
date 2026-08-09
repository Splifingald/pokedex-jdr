import { useMemo } from 'react'

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
    () => Array.from({ length: 6 }, (_, i) => ({
      id: i,
      left: 15 + Math.random() * 70,
      delay: Math.random() * 0.15,
      size: 4 + Math.random() * 5,
    })),
    // eslint-disable-next-line react-hooks/exhaustive-deps -- volontairement figé par occurrence (animKey), pas par amount
    [animKey]
  )

  return (
    <div key={animKey} className="absolute inset-0 pointer-events-none overflow-visible">
      {bubbles.map((b) => (
        <span
          key={b.id}
          className="absolute bottom-2 rounded-full bg-[#6be08a] border border-[#3fa860]"
          style={{ left: `${b.left}%`, width: b.size, height: b.size, animation: `heal-bubble-rise 0.9s ease-out ${b.delay}s forwards` }}
        />
      ))}
      <div className="absolute inset-x-0 top-0 flex items-center justify-center" style={{ opacity: 0, animation: 'damage-number-pop 0.8s ease-out 0.1s forwards' }}>
        <span className="text-2xl font-bold text-[#2f8f4f] [text-shadow:0_2px_0_rgba(255,255,255,0.5)]">+{amount} PV</span>
      </div>
    </div>
  )
}
