import type { SafariGaugeArea } from '../types'

// Retourne la zone de jauge active pour une position donnée (0-100) parmi les
// zones d'UN groupe. Même logique que le repli safari_throw_ball côté SQL :
// [min, max) sauf pour la dernière zone qui inclut 100.
export function resolveGaugeArea(areas: SafariGaugeArea[], position: number): SafariGaugeArea | null {
  if (areas.length === 0) return null
  const sorted = [...areas].sort((a, b) => a.min_value - b.min_value)
  const found = sorted.find((a) => position >= a.min_value && position < a.max_value)
  return found ?? sorted[sorted.length - 1]
}

// Valide qu'un ensemble de zones couvre 0-100 sans trou ni chevauchement.
// Retourne la liste des erreurs (vide = valide). Utilisé par l'admin avant
// d'autoriser l'enregistrement des zones d'un groupe.
export function validateGaugeAreas(areas: SafariGaugeArea[]): string[] {
  const errors: string[] = []
  if (areas.length === 0) {
    errors.push('Aucune zone configurée.')
    return errors
  }
  const sorted = [...areas].sort((a, b) => a.min_value - b.min_value)
  if (sorted[0].min_value !== 0) {
    errors.push('La première zone doit commencer à 0.')
  }
  if (sorted[sorted.length - 1].max_value !== 100) {
    errors.push('La dernière zone doit finir à 100.')
  }
  for (let i = 0; i < sorted.length - 1; i++) {
    if (sorted[i].max_value !== sorted[i + 1].min_value) {
      errors.push(`Trou ou chevauchement entre ${sorted[i].max_value} et ${sorted[i + 1].min_value}.`)
    }
  }
  for (const a of sorted) {
    if (a.catch_rate_pct < 0 || a.catch_rate_pct > 100) {
      errors.push(`Taux de capture invalide (${a.catch_rate_pct}%).`)
    }
  }
  return errors
}

export interface BestAreaCaptureStats {
  bestArea: SafariGaugeArea
  /** Probabilité (0-1) d'atteindre un jour la zone au meilleur taux de capture, baies infinies. */
  probReachBest: number
  /** "Risque maximal" : probReachBest × taux de la meilleure zone — stratégie qui refuse de capturer ailleurs que dans la meilleure zone, quitte à la dépasser et ne plus jamais pouvoir capturer. */
  captureProbabilityMaxRisk: number
  /** "Risque minimal" : probabilité de capture sous la stratégie OPTIMALE (à chaque jauge, on capture si le taux courant dépasse l'espérance de continuer, sinon on relance une baie) — toujours ≥ captureProbabilityMaxRisk. */
  captureProbabilityMinRisk: number
}

// Calcule, pour un groupe donné, trois indicateurs à baies infinies, modélisés
// comme une chaîne de Markov sur les positions entières 0-100 : depuis une
// position s, chaque lancer de baie ajoute un delta entier uniforme dans
// [min, max], plafonné à 100 — même tirage que safari_throw_berry côté SQL.
//
// 1) probReachBest : probabilité d'atteindre un jour la zone au MEILLEUR taux
//    de capture (pas forcément la dernière zone — ex: une zone verte à 80%
//    suivie d'une zone rouge à 10% signifie qu'on peut "dépasser" la
//    meilleure zone en lançant trop de baies, sans jamais pouvoir y revenir).
// 2) captureProbabilityMaxRisk : probReachBest × taux de la meilleure zone —
//    le joueur qui refuse de tenter sa chance ailleurs que dans la meilleure
//    zone ("tout miser").
// 3) captureProbabilityMinRisk : probabilité de capture sous la politique
//    OPTIMALE (arrêt optimal) — le joueur accepte de capturer dès qu'une zone
//    "assez bonne" est atteinte plutôt que de risquer de dépasser la
//    meilleure. C'est un problème d'arrêt optimal résolu par récurrence
//    descendante : V(s) = max(tauxCapture(s), espérance de V après une baie).
export function computeBestAreaCaptureStats(
  areas: SafariGaugeArea[],
  berryMinIncrease: number,
  berryMaxIncrease: number
): BestAreaCaptureStats | null {
  if (areas.length === 0) return null
  const sorted = [...areas].sort((a, b) => a.min_value - b.min_value)
  const bestArea = sorted.reduce((best, a) => (a.catch_rate_pct > best.catch_rate_pct ? a : best), sorted[0])

  const inTarget = (s: number) => s >= bestArea.min_value && (s < bestArea.max_value || bestArea.max_value === 100)
  const catchRateAt = (s: number) => (resolveGaugeArea(sorted, s)?.catch_rate_pct ?? 0) / 100

  const minInc = Math.max(0, Math.min(berryMinIncrease, berryMaxIncrease))
  const maxInc = Math.max(0, Math.max(berryMinIncrease, berryMaxIncrease))

  const P = new Array<number>(101).fill(0) // P[s] = probabilité d'atteindre un jour la meilleure zone
  const V = new Array<number>(101).fill(0) // V[s] = probabilité de capture sous la politique optimale

  if (maxInc <= 0) {
    // Les baies n'augmentent jamais la jauge : la position ne bouge jamais.
    for (let s = 0; s <= 100; s++) {
      P[s] = inTarget(s) ? 1 : 0
      V[s] = catchRateAt(s) // aucune progression possible : autant capturer tout de suite
    }
  } else {
    const n = maxInc - minInc + 1
    const zeroIncluded = minInc <= 0
    V[100] = catchRateAt(100) // en position 100, plus aucune baie ne peut progresser : capturer est la seule option rationnelle
    for (let s = 100; s >= 0; s--) {
      if (s < 100) {
        let sumOthersP = 0
        let sumOthersV = 0
        for (let delta = minInc; delta <= maxInc; delta++) {
          if (delta === 0) continue
          const next = Math.min(100, s + delta)
          sumOthersP += P[next]
          sumOthersV += V[next]
        }
        // Un lancer à +0 (si 0 est dans la plage) ramène au même état s :
        // on résout l'équation récursive algébriquement plutôt que de
        // récurser dessus (le terme +0 s'élimine des deux côtés — voir
        // commentaire de fonction pour la dérivation complète).
        const denom = n - (zeroIncluded ? 1 : 0)
        const continueP = denom > 0 ? sumOthersP / denom : 0
        const continueV = denom > 0 ? sumOthersV / denom : 0
        P[s] = inTarget(s) ? 1 : continueP
        V[s] = Math.max(catchRateAt(s), continueV)
      }
    }
  }

  // Position initiale : entier aléatoire uniforme dans [premièreZone.min, premièreZone.max)
  // — même tirage que safari_ensure_active_session côté SQL.
  const first = sorted[0]
  const initLo = first.min_value
  const initHi = Math.max(initLo, first.max_value - 1)
  let sumP = 0
  let sumV = 0
  let count = 0
  for (let s = initLo; s <= initHi; s++) { sumP += P[s]; sumV += V[s]; count++ }
  const probReachBest = count > 0 ? sumP / count : 0
  const captureProbabilityMinRisk = count > 0 ? sumV / count : 0

  return {
    bestArea,
    probReachBest,
    captureProbabilityMaxRisk: probReachBest * (bestArea.catch_rate_pct / 100),
    captureProbabilityMinRisk,
  }
}
