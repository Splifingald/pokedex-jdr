interface Props {
  damage: number
  animKey: number
}

// Nombre de dégâts flottant, joué une fois puis figé (le composant est
// remonté via `key={animKey}` par l'appelant à chaque coup) — même idiome que
// jumpKey dans MagikarpGame.tsx. Pas de précédent existant pour ce composant
// (aucun autre mini-jeu n'affiche de nombre de dégâts).
export function AutoBattleDamageNumber({ damage, animKey }: Props) {
  return (
    <span
      key={animKey}
      className="absolute left-1/2 top-0 -translate-x-1/2 text-hp-red text-2xl font-bold pointer-events-none [text-shadow:0_2px_0_rgba(0,0,0,0.3)]"
      style={{ animation: 'damage-number-pop 0.7s ease-out forwards' }}
    >
      -{damage}PV
    </span>
  )
}
