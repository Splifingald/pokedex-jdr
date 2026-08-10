interface Props {
  text: string
  animKey: number
  className?: string
}

// Texte flottant générique (raté / tour passé), même idiome que
// AutoBattleDamageNumber (remonté via `key={animKey}` à chaque occurrence).
export function AutoBattleFloatingText({ text, animKey, className = '' }: Props) {
  return (
    <div
      key={animKey}
      className="absolute inset-x-0 top-0 flex items-center justify-center pointer-events-none"
      style={{ animation: 'damage-number-pop 1.3s ease-out forwards' }}
    >
      <span className={`text-sm font-bold whitespace-nowrap [text-shadow:0_1px_2px_rgba(0,0,0,0.7)] ${className}`}>{text}</span>
    </div>
  )
}
