interface Props {
  damage: number
  animKey: number
  superEffective?: boolean
  /** Couleur CSS du nombre — orange (dégâts normaux) par défaut, rouge pour
   * la brûlure, violet pour le poison (voir AutoBattleScreen/STATUS_EFFECT_COLOR). */
  color?: string
}

// Nombre de dégâts flottant, joué une fois puis figé (le composant est
// remonté via `key={animKey}` par l'appelant à chaque coup) — même idiome que
// jumpKey dans MagikarpGame.tsx. Pas de précédent existant pour ce composant
// (aucun autre mini-jeu n'affiche de nombre de dégâts). Si le coup est
// super efficace (bonus de type, voir requirement #17), affiche aussi un
// texte "Super Efficace !" au-dessus et agrandit le nombre de dégâts.
export function AutoBattleDamageNumber({ damage, animKey, superEffective = false, color = '#e8933d' }: Props) {
  return (
    <div
      key={animKey}
      className="absolute inset-x-0 top-0 flex flex-col items-center pointer-events-none"
      style={{ animation: 'damage-number-pop 1.3s ease-out forwards' }}
    >
      {superEffective && (
        <span className="text-[#ffd85e] text-xs font-bold whitespace-nowrap [text-shadow:0_1px_2px_rgba(0,0,0,0.7)]">
          Super Efficace !
        </span>
      )}
      <span
        className={`${superEffective ? 'text-3xl' : 'text-2xl'} font-bold [text-shadow:0_2px_0_rgba(0,0,0,0.3)]`}
        style={{ color }}
      >
        -{damage}PV
      </span>
    </div>
  )
}
