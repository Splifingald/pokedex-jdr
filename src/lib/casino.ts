import type { CasinoConfig, CasinoPlayerState, SlotSymbol } from '../types'

const REGEN_UNIT_MS: Record<CasinoConfig['ticket_regen_unit'], number> = {
  hours: 3_600_000,
  minutes: 60_000,
}

export interface TicketRegenResult {
  ticketsGranted: number
  nextTicketAt: string | null
}

// Calcule combien de tickets gratuits accorder et le prochain horodatage d'octroi.
// Le minuteur est en pause tant que l'inventaire est au plafond (ticket_max) : pas
// d'accumulation silencieuse au-delà, il repart à zéro dès qu'un ticket est dépensé.
// La boucle rattrape les tickets manqués (joueur absent plusieurs jours), plafonnée au max.
export function computeTicketRegen(
  nextTicketAt: string | null,
  ticketCount: number,
  config: Pick<CasinoConfig, 'ticket_max' | 'ticket_regen_amount' | 'ticket_regen_unit'>,
  now: Date = new Date()
): TicketRegenResult {
  if (ticketCount >= config.ticket_max) {
    return { ticketsGranted: 0, nextTicketAt: null }
  }

  const intervalMs = config.ticket_regen_amount * REGEN_UNIT_MS[config.ticket_regen_unit]

  if (nextTicketAt === null) {
    return { ticketsGranted: 0, nextTicketAt: new Date(now.getTime() + intervalMs).toISOString() }
  }

  let count = ticketCount
  let armedAt = new Date(nextTicketAt).getTime()
  let granted = 0

  while (count < config.ticket_max && armedAt <= now.getTime()) {
    count += 1
    granted += 1
    armedAt += intervalMs
  }

  return {
    ticketsGranted: granted,
    nextTicketAt: count >= config.ticket_max ? null : new Date(armedAt).toISOString(),
  }
}

const SLOT_SYMBOLS: SlotSymbol[] = ['pokeball', 'superball', 'hyperball', 'masterball']

const SLOT_WEIGHT_KEY: Record<SlotSymbol, keyof CasinoConfig> = {
  pokeball: 'slots_pokeball_weight',
  superball: 'slots_superball_weight',
  hyperball: 'slots_hyperball_weight',
  masterball: 'slots_masterball_weight',
}

// Tirage pondéré : la probabilité de chaque symbole est son poids / somme des poids
// (poids égaux par défaut = équiprobable, comme avant l'ajout de ce réglage admin).
function rollWeightedSymbol(config: CasinoConfig): SlotSymbol {
  const weights = SLOT_SYMBOLS.map((s) => Math.max(0, config[SLOT_WEIGHT_KEY[s]] as number))
  const total = weights.reduce((sum, w) => sum + w, 0)
  if (total <= 0) return SLOT_SYMBOLS[Math.floor(Math.random() * SLOT_SYMBOLS.length)]

  let roll = Math.random() * total
  for (let i = 0; i < SLOT_SYMBOLS.length; i++) {
    roll -= weights[i]
    if (roll < 0) return SLOT_SYMBOLS[i]
  }
  return SLOT_SYMBOLS[SLOT_SYMBOLS.length - 1]
}

export function rollSlotSymbols(config: CasinoConfig): [SlotSymbol, SlotSymbol, SlotSymbol] {
  return [rollWeightedSymbol(config), rollWeightedSymbol(config), rollWeightedSymbol(config)]
}

const SLOT_VALUE_KEY: Record<SlotSymbol, keyof CasinoConfig> = {
  pokeball: 'slots_pokeball_value',
  superball: 'slots_superball_value',
  hyperball: 'slots_hyperball_value',
  masterball: 'slots_masterball_value',
}

export function slotSymbolValue(symbol: SlotSymbol, config: CasinoConfig): number {
  return config[SLOT_VALUE_KEY[symbol]] as number
}

export type SlotMatchTier = 'none' | 'two' | 'three'

export interface SlotResult {
  perSymbolValue: [number, number, number]
  matchedIndices: number[]
  matchTier: SlotMatchTier
  multiplier: number
  total: number
}

// Le joueur gagne toujours quelque chose : somme des 3 symboles × multiplicateur
// (×1 si aucun match, ×match2 si 2 identiques, ×match3 si les 3 identiques).
export function computeSlotResult(symbols: [SlotSymbol, SlotSymbol, SlotSymbol], config: CasinoConfig): SlotResult {
  const perSymbolValue = symbols.map((s) => slotSymbolValue(s, config)) as [number, number, number]
  const sum = perSymbolValue.reduce((total, v) => total + v, 0)
  const [a, b, c] = symbols
  const allMatch = a === b && b === c
  const matchedIndices = allMatch ? [0, 1, 2] : a === b ? [0, 1] : b === c ? [1, 2] : a === c ? [0, 2] : []
  const matchTier: SlotMatchTier = allMatch ? 'three' : matchedIndices.length ? 'two' : 'none'
  const multiplier = allMatch ? config.slots_match3_multiplier : matchedIndices.length ? config.slots_match2_multiplier : 1
  return { perSymbolValue, matchedIndices, matchTier, multiplier, total: sum * multiplier }
}

export function computeSlotMaxPayout(config: CasinoConfig): number {
  const maxValue = Math.max(
    config.slots_pokeball_value, config.slots_superball_value,
    config.slots_hyperball_value, config.slots_masterball_value
  )
  return maxValue * 3 * config.slots_match3_multiplier
}

// Espérance de gain par partie : énumère les 4×4×4 combinaisons de rouleaux
// possibles, pondérées par leur probabilité (poids/somme des poids par rouleau).
export function computeSlotExpectedValue(config: CasinoConfig): number {
  const weights = SLOT_SYMBOLS.map((s) => Math.max(0, config[SLOT_WEIGHT_KEY[s]] as number))
  const total = weights.reduce((a, b) => a + b, 0)
  if (total <= 0) return 0

  let ev = 0
  for (let i = 0; i < SLOT_SYMBOLS.length; i++) {
    for (let j = 0; j < SLOT_SYMBOLS.length; j++) {
      for (let k = 0; k < SLOT_SYMBOLS.length; k++) {
        const p = (weights[i] / total) * (weights[j] / total) * (weights[k] / total)
        if (p === 0) continue
        const combo: [SlotSymbol, SlotSymbol, SlotSymbol] = [SLOT_SYMBOLS[i], SLOT_SYMBOLS[j], SLOT_SYMBOLS[k]]
        ev += p * computeSlotResult(combo, config).total
      }
    }
  }
  return ev
}

export function pickAiTarget(config: Pick<CasinoConfig, 'dice_ai_target_min' | 'dice_ai_target_max'>): number {
  const { dice_ai_target_min: min, dice_ai_target_max: max } = config
  return min + Math.floor(Math.random() * Math.max(1, max - min + 1))
}

export function rollDicePair(): [number, number] {
  return [1 + Math.floor(Math.random() * 6), 1 + Math.floor(Math.random() * 6)]
}

// L'IA continue de lancer tant qu'elle n'a pas atteint sa cible secrète — et,
// comme le joueur joue toujours en premier et que son total final est donc déjà
// connu, elle continue aussi tant qu'elle reste derrière lui même après avoir
// atteint sa cible (elle ne s'arrête que si elle a atteint sa cible ET égalé/dépassé le joueur).
export function shouldAiHit(aiTotal: number, target: number, playerTotal: number): boolean {
  return aiTotal < target || aiTotal < playerTotal
}

// Utilisé uniquement pour éviter une égalité : force un lancer qui fait dépasser 21
// à l'IA (elle "triche" en perdant), garantissant que le joueur gagne les égalités.
export function forceAiBustRoll(aiTotal: number): [number, number] {
  const needed = Math.max(2, 22 - aiTotal)
  const die1 = Math.min(6, needed - 1)
  const die2 = Math.max(1, Math.min(6, needed - die1))
  return [die1, die2]
}

export interface AiRollStep {
  dice: [number, number]
  totalAfter: number
  forced?: boolean
}

export interface AiTurnResult {
  steps: AiRollStep[]
  outcome: 'win' | 'lose'
}

// Simule tout le tour de l'IA d'un coup (elle relance tant qu'elle n'a pas
// atteint sa cible secrète), puis compare au total du joueur. Une égalité est
// impossible par conception : l'IA "triche" avec un lancer forcé qui la fait
// dépasser 21, garantissant la victoire du joueur.
export function simulateAiTurn(startAiTotal: number, target: number, playerTotal: number): AiTurnResult {
  let total = startAiTotal
  const steps: AiRollStep[] = []

  while (total <= 21 && shouldAiHit(total, target, playerTotal)) {
    const dice = rollDicePair()
    total += dice[0] + dice[1]
    steps.push({ dice, totalAfter: total })
  }

  if (total > 21) {
    return { steps, outcome: 'win' }
  }
  if (total > playerTotal) {
    return { steps, outcome: 'lose' }
  }
  if (total < playerTotal) {
    return { steps, outcome: 'win' }
  }

  const dice = forceAiBustRoll(total)
  total += dice[0] + dice[1]
  steps.push({ dice, totalAfter: total, forced: true })
  return { steps, outcome: 'win' }
}

// Compare la date d'achat stockée (jour local "YYYY-MM-DD") au jour courant :
// un jour différent réinitialise implicitement le plafond quotidien.
export function isPurchaseCapReached(
  state: Pick<CasinoPlayerState, 'purchase_count' | 'purchase_date'>,
  config: Pick<CasinoConfig, 'ticket_daily_buy_cap'>,
  today: string
): boolean {
  if (state.purchase_date !== today) return false
  return state.purchase_count >= config.ticket_daily_buy_cap
}

export function localDateString(now: Date = new Date()): string {
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

// ── Calculateurs de gains espérés (admin) ──────────────────────
// Le vrai "espérance de gain" du dé dépend des choix du joueur (rester/continuer/
// encaisser), donc il n'existe pas de vraie EV unique. Les deux fonctions ci-dessous
// supposent le même scénario fixe pour rester comparables entre elles : le joueur
// joue "prudent" (il tire tant que son total n'atteint pas la cible max possible de
// l'IA, puis reste) et pousse jusqu'à la dernière manche sans jamais encaisser avant.

// Distribution du total final (ou bust) en lançant 2d6 répétés jusqu'à atteindre `target`
// — même logique que l'IA (simulateAiTurn), réutilisée ici pour modéliser le joueur.
function finalTotalDistribution(target: number): { finals: Map<number, number>; bustProb: number } {
  const rollDist: number[] = new Array(13).fill(0)
  for (let d1 = 1; d1 <= 6; d1++) for (let d2 = 1; d2 <= 6; d2++) rollDist[d1 + d2] += 1 / 36

  let current = new Map<number, number>([[0, 1]])
  const finals = new Map<number, number>()
  let bustProb = 0

  while (current.size > 0) {
    const next = new Map<number, number>()
    for (const [total, p] of current) {
      for (let sum = 2; sum <= 12; sum++) {
        const prob = p * rollDist[sum]
        const newTotal = total + sum
        if (newTotal > 21) bustProb += prob
        else if (newTotal >= target) finals.set(newTotal, (finals.get(newTotal) ?? 0) + prob)
        else next.set(newTotal, (next.get(newTotal) ?? 0) + prob)
      }
    }
    current = next
  }
  return { finals, bustProb }
}

// P(le joueur gagne une manche), en supposant qu'il reste dès que son total atteint
// dice_ai_target_max (le seuil le plus sûr).
//
// L'IA ne s'arrête plus seulement à sa propre cible : elle continue tant qu'elle est
// encore derrière le total du joueur (shouldAiHit), donc son seuil d'arrêt effectif
// pour un total joueur P donné est max(cible, P) — on ne peut pas la modéliser
// indépendamment du joueur comme avant. On recalcule donc sa distribution avec ce
// seuil composé, pour chaque total joueur possible et chaque cible IA possible.
// Une égalité (l'IA s'arrête pile sur P) est une victoire du joueur (triche forcée).
export function computeDiceRoundWinProbability(config: CasinoConfig): number {
  const { finals: playerFinals } = finalTotalDistribution(config.dice_ai_target_max)
  const { dice_ai_target_min: min, dice_ai_target_max: max } = config
  const targets = Array.from({ length: Math.max(1, max - min + 1) }, (_, i) => min + i)
  const targetWeight = 1 / targets.length

  let winProb = 0
  for (const [playerTotal, pProb] of playerFinals) {
    let pWinGivenPlayerTotal = 0
    for (const target of targets) {
      const { finals: aiFinals, bustProb: aiBust } = finalTotalDistribution(Math.max(target, playerTotal))
      // aiTotal >= playerTotal ici par construction du seuil : aiTotal === playerTotal
      // est une égalité (triche forcée, joueur gagne), aiTotal > playerTotal est une victoire IA.
      let pWinGivenTarget = aiBust
      for (const [aiTotal, aProb] of aiFinals) {
        if (aiTotal <= playerTotal) pWinGivenTarget += aProb
      }
      pWinGivenPlayerTotal += targetWeight * pWinGivenTarget
    }
    winProb += pProb * pWinGivenPlayerTotal
  }
  return winProb
}

export function computeDiceMaxPayout(config: CasinoConfig): number {
  return config.dice_initial_gain * Math.pow(2, Math.max(0, config.dice_max_rounds - 1))
}

// Gain espéré en supposant que le joueur pousse jusqu'au bout avec la stratégie
// prudente ci-dessus sans jamais encaisser avant : gain max pondéré par la probabilité
// de remporter effectivement toutes les manches.
export function computeDiceExpectedValue(config: CasinoConfig): number {
  const p = computeDiceRoundWinProbability(config)
  return Math.pow(p, config.dice_max_rounds) * computeDiceMaxPayout(config)
}
