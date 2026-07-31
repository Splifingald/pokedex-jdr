import type { AdminParameters, Player } from '../types'

export interface StatBlock {
  charisme: number
  intelligence: number
  sagesse: number
  dexterite: number
}

export type StatKey = keyof StatBlock

export const STAT_LABELS: Record<StatKey, string> = {
  charisme: 'Charisme',
  intelligence: 'Intelligence',
  sagesse: 'Sagesse',
  dexterite: 'Dextérité',
}

export interface StatPointConfig {
  stat_points_base: number
  stat_min: number
  stat_max: number
  stat_points_per_level: number
}

export function toStatPointConfig(parameters: AdminParameters): StatPointConfig {
  return {
    stat_points_base: parameters.stat_points_base,
    stat_min: parameters.stat_min,
    stat_max: parameters.stat_max,
    stat_points_per_level: parameters.stat_points_per_level,
  }
}

export function playerStats(player: Player): StatBlock {
  return {
    charisme: player.stat_charisme,
    intelligence: player.stat_intelligence,
    sagesse: player.stat_sagesse,
    dexterite: player.stat_dexterite,
  }
}

// Budget total de points de stats à un niveau donné : base + points gagnés depuis le niveau 1
export function totalBudget(level: number, config: StatPointConfig): number {
  return config.stat_points_base + Math.max(0, level - 1) * config.stat_points_per_level
}

export function sumStats(stats: StatBlock): number {
  return stats.charisme + stats.intelligence + stats.sagesse + stats.dexterite
}

export function remainingPoints(stats: StatBlock, level: number, config: StatPointConfig): number {
  return totalBudget(level, config) - sumStats(stats)
}

// Modificateur de jet de dé associé à une valeur de stat (formule standard type d20 : moitié de
// l'écart à 10, arrondi vers le bas). 10-11 = 0, 12-13 = +1, 8-9 = -1, etc.
export function statModifier(value: number): number {
  return Math.floor((value - 10) / 2)
}

export function formatStatModifier(value: number): string {
  const mod = statModifier(value)
  return mod >= 0 ? `+${mod}` : `${mod}`
}

// Ajuste la valeur demandée pour une seule stat : bornée à [stat_min, stat_max], et bornée par
// le budget restant compte tenu des 3 autres stats déjà fixées.
export function clampStatValue(
  current: StatBlock,
  key: StatKey,
  requestedValue: number,
  level: number,
  config: StatPointConfig
): number {
  const rangeClamped = Math.min(config.stat_max, Math.max(config.stat_min, requestedValue))
  const others = sumStats(current) - current[key]
  const maxAllowedByBudget = totalBudget(level, config) - others
  return Math.min(rangeClamped, Math.max(config.stat_min, maxAllowedByBudget))
}
