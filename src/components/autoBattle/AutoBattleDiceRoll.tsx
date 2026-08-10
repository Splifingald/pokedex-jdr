import { DICE_ICON } from '../../lib/icons'

interface Props {
  value: number
  animKey: number
}

// Lancer de dé pour les statuts avec chance de guérison (Sommeil/Brûlure) —
// réutilise les faces de dé du mini-jeu Casino (DICE_ICON) et l'animation
// 'dice-shake' déjà utilisée là-bas (voir CasinoDiceGame.tsx) : tremble
// brièvement puis se fige sur la valeur tirée, avant de s'estomper comme les
// autres effets flottants (damage-number-pop), remonté via `key={animKey}`
// à chaque occurrence.
export function AutoBattleDiceRoll({ value, animKey }: Props) {
  return (
    <div
      key={animKey}
      className="absolute inset-x-0 top-0 flex items-center justify-center pointer-events-none"
      style={{ animation: 'damage-number-pop 1s ease-out forwards' }}
    >
      <img
        src={DICE_ICON[value]}
        alt={String(value)}
        className="w-8 h-8 object-contain pixelated"
        style={{ animation: 'dice-shake 0.3s ease-in-out 1' }}
      />
    </div>
  )
}
