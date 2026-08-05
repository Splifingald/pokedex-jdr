import type { GiftTimerUnit, PensionConfig, PensionGroupConfig, PensionEggPoolEntry, PensionXpGroup, PlayerPokemon } from '../types'

// Groupe sentinelle (ne peut jamais venir du CSV pokemon_egg_groups, exclu de la
// liste des groupes réels dérivée de cette table) sous lequel est stockée la
// réserve d'œufs par défaut, utilisée par tout groupe en mode 'default'.
export const DEFAULT_EGG_POOL_GROUP = '__default__'

const UNIT_MS: Record<GiftTimerUnit, number> = {
  hours: 3_600_000,
  minutes: 60_000,
}

// Groupe spécial "universel" (insensible à la casse) : se reproduit avec
// n'importe quel autre pokémon ayant au moins un groupe réel, mais jamais avec
// un autre pokémon ALL/TOUS — voir pension_recompute_pairs (schema.sql) pour la
// logique serveur équivalente.
export function isAllGroup(groupe: string): boolean {
  const normalized = groupe.trim().toLowerCase()
  return normalized === 'all' || normalized === 'tous'
}

// Deux pokémon peuvent-ils former une paire de reproduction, d'après leurs
// groupes d'œufs respectifs ? Réutilisé à la fois pour le indice cœur de la
// liste de placement (compatibilité hypothétique) et pour le indice cœur de la
// grille de pension (appariement réellement en cours, voir pairsByPokemonId).
export function canPair(groupsA: string[], groupsB: string[]): boolean {
  const aIsAll = groupsA.some(isAllGroup)
  const bIsAll = groupsB.some(isAllGroup)
  if (aIsAll && bIsAll) return false
  if (aIsAll) return groupsB.some((g) => !isAllGroup(g))
  if (bIsAll) return groupsA.some((g) => !isAllGroup(g))
  const bSet = new Set(groupsB.map((g) => g.trim().toLowerCase()))
  return groupsA.some((g) => !isAllGroup(g) && bSet.has(g.trim().toLowerCase()))
}

export interface ApplicablePensionSettings {
  tickIntervalMs: number
  lifetimeXpCap: number
}

// Résout l'intervalle de tick et le plafond XP à vie applicables à une espèce.
// Les "groupes XP" sont un concept entièrement séparé des groupes d'œufs
// (assignation manuelle admin, une espèce appartient à au plus un groupe XP,
// voir pension_xp_groups/pension_xp_group_species) — simple lookup direct,
// repli sur pension_config si l'espèce n'est dans aucun groupe XP.
export function resolveApplicableXpGroup(
  pokemonNom: string,
  xpGroupByPokemonNom: Map<string, PensionXpGroup>,
  pensionConfig: PensionConfig
): ApplicablePensionSettings {
  const group = xpGroupByPokemonNom.get(pokemonNom)
  return {
    tickIntervalMs: group
      ? group.tick_interval_amount * UNIT_MS[group.tick_interval_unit]
      : pensionConfig.tick_interval_amount * UNIT_MS[pensionConfig.tick_interval_unit],
    lifetimeXpCap: group ? group.lifetime_xp_cap : pensionConfig.default_lifetime_xp_cap,
  }
}

export interface ProjectedDaycareXp {
  committedXp: number
  projectedExtraXp: number
  nextTickInMs: number | null
}

// Estimation en direct côté client de l'XP gagnée depuis le dernier tick
// serveur (pension-tick.js, @hourly) — purement pour l'affichage (jauge/
// compte à rebours) : la valeur qui compte réellement pour l'évolution reste
// `pp.xp`, mis à jour par le cron. `null` en nextTickInMs = plafond atteint,
// plus aucun tick à attendre. `speciesMaxXp` (getMaxXp(pokemon), ou null si
// l'espèce n'a pas de palier) plafonne la projection en plus du plafond à vie
// de la pension — un pokémon ne doit jamais paraître dépasser le max de sa
// propre jauge XP, même en estimation live (voir aussi pension-tick.js qui
// applique le même double plafond côté écriture réelle).
export function computeProjectedDaycareXp(
  pp: Pick<PlayerPokemon, 'xp' | 'in_daycare' | 'daycare_placed_at' | 'daycare_last_tick_at' | 'daycare_lifetime_xp' | 'daycare_capped'>,
  applicable: ApplicablePensionSettings,
  tickXpAmount: number,
  now: Date = new Date(),
  speciesMaxXp: number | null = null
): ProjectedDaycareXp {
  if (!pp.in_daycare || pp.daycare_capped) {
    return { committedXp: pp.xp, projectedExtraXp: 0, nextTickInMs: null }
  }

  const lastTick = pp.daycare_last_tick_at ?? pp.daycare_placed_at
  if (!lastTick) {
    return { committedXp: pp.xp, projectedExtraXp: 0, nextTickInMs: applicable.tickIntervalMs }
  }

  const elapsedMs = Math.max(0, now.getTime() - new Date(lastTick).getTime())
  const ticks = Math.floor(elapsedMs / applicable.tickIntervalMs)
  const remainingCap = Math.max(0, applicable.lifetimeXpCap - pp.daycare_lifetime_xp)
  const remainingToSpeciesMax = speciesMaxXp != null ? Math.max(0, speciesMaxXp - pp.xp) : Infinity
  const cap = Math.min(remainingCap, remainingToSpeciesMax)
  const projectedExtraXp = Math.min(ticks * tickXpAmount, cap)
  const nextTickInMs = projectedExtraXp >= cap
    ? null
    : applicable.tickIntervalMs - (elapsedMs - ticks * applicable.tickIntervalMs)

  return { committedXp: pp.xp, projectedExtraXp, nextTickInMs }
}

// Résout la fourchette d'éclosion effective d'un groupe (pour affichage admin
// uniquement — la valeur qui compte réellement pour le tirage vient du serveur,
// voir pension_recompute_pairs dans schema.sql, qui applique la même précédence).
export function resolveHatchRange(
  groupConfig: PensionGroupConfig | undefined,
  pensionConfig: PensionConfig
): { min: number; max: number; unit: GiftTimerUnit } {
  return {
    min: groupConfig?.hatch_timer_min ?? pensionConfig.default_hatch_timer_min,
    max: groupConfig?.hatch_timer_max ?? pensionConfig.default_hatch_timer_max,
    unit: groupConfig?.hatch_timer_unit ?? pensionConfig.default_hatch_timer_unit,
  }
}

// Résout la réserve d'œufs effective d'un groupe selon son egg_pool_mode —
// pour affichage admin uniquement. La production réelle utilise la même
// logique dupliquée côté serveur (pension-tick.js, voir resolveEggPool là-bas).
export function resolveEggPool(
  groupe: string,
  groupConfigByGroup: Map<string, PensionGroupConfig>,
  eggPoolByGroup: Map<string, PensionEggPoolEntry[]>
): PensionEggPoolEntry[] {
  const mode = groupConfigByGroup.get(groupe)?.egg_pool_mode ?? 'default'
  if (mode === 'none') return []
  if (mode === 'custom') return eggPoolByGroup.get(groupe) ?? []
  return eggPoolByGroup.get(DEFAULT_EGG_POOL_GROUP) ?? []
}

// Compte à rebours du prochain tick XP — "XXhXXm" au-delà d'une heure restante,
// "XXmXXs" en dessous (les secondes ne sont utiles/lisibles que sur la dernière
// ligne droite). Variante pension-spécifique de casino.ts::formatCountdownHM
// (qui reste XXhXXm partout, utilisé par Fouille/Mini-Jeux, non concernée par ce besoin).
export function formatPensionCountdown(ms: number): string {
  const totalSeconds = Math.max(0, Math.ceil(ms / 1000))
  if (totalSeconds < 3600) {
    const m = Math.floor(totalSeconds / 60)
    const s = totalSeconds % 60
    return `${String(m).padStart(2, '0')}m${String(s).padStart(2, '0')}s`
  }
  const totalMinutes = Math.ceil(ms / 60000)
  const h = Math.floor(totalMinutes / 60)
  const m = totalMinutes % 60
  return `${String(h).padStart(2, '0')}h${String(m).padStart(2, '0')}m`
}

// "+X xp en XXj"/"+X xp en XXh" — combien de temps il faudrait rester en
// pension pour engranger tout le potentiel restant (`remaining`, déjà plafonné
// par le cap à vie de la pension ET le max de la jauge de l'espèce), au rythme
// courant. Utilisé dans la liste de sélection pour donner une estimation
// concrète plutôt qu'un simple taux abstrait.
export function formatXpCapTimeframe(remaining: number, tickXpAmount: number, tickIntervalMs: number): string {
  if (remaining <= 0 || tickXpAmount <= 0) return ''
  const ticksNeeded = Math.ceil(remaining / tickXpAmount)
  const totalMs = ticksNeeded * tickIntervalMs
  const hours = totalMs / 3_600_000
  if (hours >= 24) {
    return `+${remaining} xp en ${Math.round(hours / 24)}j`
  }
  return `+${remaining} xp en ${Math.max(1, Math.round(hours))}h`
}

// Tirage pondéré d'une espèce "œuf" dans la réserve d'un groupe (probabilité =
// poids / somme des poids, même principe que les lootboxes de cadeaux). La
// production réelle d'œufs se fait côté serveur (pension-tick.js, logique JS
// dupliquée faute de chemin d'import partagé entre client TS et Netlify JS,
// même convention que le reste de ce projet).
export function pickWeightedEggSpecies(pool: Pick<PensionEggPoolEntry, 'pokemon_nom' | 'weight'>[]): string | null {
  const total = pool.reduce((sum, p) => sum + Math.max(0, p.weight), 0)
  if (total <= 0) return null
  let roll = Math.random() * total
  for (const entry of pool) {
    roll -= Math.max(0, entry.weight)
    if (roll < 0) return entry.pokemon_nom
  }
  return pool[pool.length - 1]?.pokemon_nom ?? null
}
