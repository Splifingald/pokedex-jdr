// Ancrages du dégradé de couleur pour la précision (1 à 10)
const ANCHORS: [number, [number, number, number]][] = [
  [10, [34, 197, 94]],   // green-500
  [8, [250, 204, 21]],   // yellow-400
  [6, [249, 115, 22]],   // orange-500
  [4, [239, 68, 68]],    // red-500
  [1, [127, 29, 29]],    // red-900
]

// Précision ABSOLUE : case vide ("-") ou 0 dans le CSV des attaques. La
// capacité ne peut alors JAMAIS rater — son jet de précision n'est même pas
// calculé (voir v_player_never_miss / v_opponent_never_miss dans
// supabase/schema.sql : `v_missed := (NOT never_miss) AND random() >= …`), y
// compris sous Peur/Confusion ou avec un debuff de précision. À distinguer
// d'une précision explicite de 10, qui vaut 100% par défaut mais reste
// réductible par un statut ou un modificateur.
export function isAbsolutePrecision(precision: number | null | undefined): boolean {
  return precision == null || precision === 0
}

// Affichage unique pour toute l'app : "-" pour une précision absolue (surtout
// pas "10", qui laisserait croire à une capacité seulement très fiable, ni
// "0", qui suggérerait l'inverse — une capacité qui rate toujours).
export function formatPrecision(precision: number | null | undefined): string {
  return isAbsolutePrecision(precision) ? '-' : String(precision)
}

export function getPrecisionColor(precision: number | null | undefined): string {
  // Une précision absolue est strictement meilleure qu'un 10 : même couleur
  // que le haut de l'échelle, jamais le rouge d'un "0" pris au pied de la
  // lettre ni un gris d'information manquante.
  if (isAbsolutePrecision(precision)) return `rgb(${ANCHORS[0][1].join(', ')})`
  const p = Math.max(1, Math.min(10, precision as number))

  for (let i = 0; i < ANCHORS.length - 1; i++) {
    const [hi, hiColor] = ANCHORS[i]
    const [lo, loColor] = ANCHORS[i + 1]
    if (p <= hi && p >= lo) {
      const t = hi === lo ? 0 : (p - lo) / (hi - lo)
      const rgb = hiColor.map((c, idx) => Math.round(loColor[idx] + t * (c - loColor[idx])))
      return `rgb(${rgb[0]}, ${rgb[1]}, ${rgb[2]})`
    }
  }

  return `rgb(${ANCHORS[0][1].join(', ')})`
}
