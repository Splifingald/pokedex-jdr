// Ancrages du dégradé de couleur pour la précision (1 à 10)
const ANCHORS: [number, [number, number, number]][] = [
  [10, [34, 197, 94]],   // green-500
  [8, [250, 204, 21]],   // yellow-400
  [6, [249, 115, 22]],   // orange-500
  [4, [239, 68, 68]],    // red-500
  [1, [127, 29, 29]],    // red-900
]

const FALLBACK = 'rgb(156, 163, 175)' // gray-400

export function getPrecisionColor(precision: number | null): string {
  if (precision == null) return FALLBACK
  const p = Math.max(1, Math.min(10, precision))

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
