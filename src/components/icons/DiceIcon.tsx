interface Props {
  sides: number
  size?: number
  className?: string
}

/** Contour et facettes de chaque dé. Le tracé extérieur porte la couleur, les
 *  segments intérieurs suggèrent le volume — un rendu vectoriel classique,
 *  bien plus lisible en petit qu'un aplat pixelisé. */
const DICE: Record<number, { outline: string; facets: string[] }> = {
  // Tétraèdre vu de face : une pointe en haut, une arête vers le centre.
  4: { outline: '12,2 22,20 2,20', facets: ['M12,2 L12,20', 'M12,2 L2,20', 'M12,2 L22,20'] },
  // Cube en perspective cavalière.
  6: { outline: '12,2 21,7 21,17 12,22 3,17 3,7', facets: ['M3,7 L12,12 L21,7', 'M12,12 L12,22'] },
  // Octaèdre : deux pyramides accolées.
  8: { outline: '12,1 21,12 12,23 3,12', facets: ['M3,12 L12,7 L21,12', 'M12,7 L12,23'] },
  // Trapézoèdre du D10 : pointe haute, ceinture, pointe basse.
  10: { outline: '12,1 21,10 12,23 3,10', facets: ['M3,10 L8,13 L12,9 L16,13 L21,10', 'M8,13 L12,23', 'M16,13 L12,23'] },
  // Dodécaèdre : face pentagonale au centre.
  12: { outline: '12,1 22,8 18,20 6,20 2,8', facets: ['M12,6 L17,10 L15,16 L9,16 L7,10 Z'] },
  // Icosaèdre : face triangulaire au centre.
  20: { outline: '12,1 21,6 21,17 12,22 3,17 3,6', facets: ['M12,5 L18,15 L6,15 Z', 'M12,5 L12,1', 'M18,15 L21,17', 'M6,15 L3,17'] },
}

// Dés polyédriques en SVG : le projet n'a que des faces de D6 en PNG, et un
// tracé vectoriel reste net à toute taille et se teinte librement.
export function DiceIcon({ sides, size = 32, className = '' }: Props) {
  const die = DICE[sides] ?? DICE[6]
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} className={className} aria-hidden="true">
      <polygon
        points={die.outline}
        fill="currentColor"
        stroke="#201c14"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      {die.facets.map((d, i) => (
        <path key={i} d={d} fill="none" stroke="#201c14" strokeWidth="1" strokeOpacity="0.45" strokeLinejoin="round" />
      ))}
    </svg>
  )
}
