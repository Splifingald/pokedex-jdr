export interface DiceResult {
  sides: number
  value: number
  /** Instant du lancer : sert de clé de rendu pour relancer l'animation. */
  at: number
}

interface Props {
  result: DiceResult | null
}

// Résultat d'un lancer, en grand. Rendu DANS le conteneur du plateau et non
// par-dessus la fenêtre entière : centré sur la fenêtre, il tombait à côté du
// plateau dès que la barre latérale d'équipe était ouverte.
export function DiceResultOverlay({ result }: Props) {
  if (!result) return null
  return (
    <div
      // La clé inclut l'instant du lancer : relancer doit repartir du début de
      // l'animation, donc produire un élément neuf.
      key={result.at}
      className="absolute inset-0 z-[50] flex items-center justify-center pointer-events-none animate-[dice-result_3s_ease-out_forwards]"
    >
      <div className="flex flex-col items-center">
        <span
          className="text-cream font-bold leading-none drop-shadow-[5px_5px_0_rgba(0,0,0,0.85)]"
          style={{ fontSize: 'min(34vh, 26vw)' }}
        >
          {result.value}
        </span>
        <span
          className="text-cream font-bold leading-none drop-shadow-[3px_3px_0_rgba(0,0,0,0.85)]"
          style={{ fontSize: 'min(7vh, 5vw)' }}
        >
          D{result.sides}
        </span>
      </div>
    </div>
  )
}
