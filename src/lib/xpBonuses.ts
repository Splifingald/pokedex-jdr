import type { Pokemon } from '../types'

export type BonusKind = 'hp' | 'dmg' | 'text'

export interface Milestone {
  xp: number
  kind: BonusKind
  value: number | null
  label: string
}

export interface StatBreakdown {
  base: number
  bonus: number
  total: number
}

export const XP_LEVELS = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100] as const

const BONUS_REGEX = /^\+\s*(\d+)\s*(PV|DMG)$/i

function xpField(level: number): keyof Pokemon {
  return `xp_${level}` as keyof Pokemon
}

function parseMilestoneCell(raw: string | null | undefined): Omit<Milestone, 'xp'> | null {
  const trimmed = raw?.trim()
  if (!trimmed) return null
  const match = trimmed.match(BONUS_REGEX)
  if (match) {
    const value = parseInt(match[1], 10)
    const kind: BonusKind = match[2].toUpperCase() === 'PV' ? 'hp' : 'dmg'
    return { kind, value, label: trimmed }
  }
  return { kind: 'text', value: null, label: trimmed }
}

export function getMilestones(pokemon: Pokemon | undefined): Milestone[] {
  if (!pokemon) return []
  const result: Milestone[] = []
  for (const level of XP_LEVELS) {
    const parsed = parseMilestoneCell(pokemon[xpField(level)] as string | null)
    if (parsed) result.push({ xp: level, ...parsed })
  }
  return result
}

export function getMaxXp(pokemon: Pokemon | undefined): number | null {
  const milestones = getMilestones(pokemon)
  return milestones.length === 0 ? null : milestones[milestones.length - 1].xp
}

export function getHpBonus(pokemon: Pokemon | undefined, xp: number): number {
  return getMilestones(pokemon)
    .filter((m) => m.kind === 'hp' && xp >= m.xp)
    .reduce((sum, m) => sum + (m.value ?? 0), 0)
}

export function getDamageBonus(pokemon: Pokemon | undefined, xp: number): number {
  return getMilestones(pokemon)
    .filter((m) => m.kind === 'dmg' && xp >= m.xp)
    .reduce((sum, m) => sum + (m.value ?? 0), 0)
}

export function getHpBreakdown(pokemon: Pokemon | undefined, xp: number): StatBreakdown {
  const base = pokemon?.pv_base ?? 0
  const bonus = getHpBonus(pokemon, xp)
  return { base, bonus, total: base + bonus }
}

export function getDamageBreakdown(pokemon: Pokemon | undefined, xp: number): StatBreakdown {
  const base = pokemon?.degats_base ?? 0
  const bonus = getDamageBonus(pokemon, xp)
  return { base, bonus, total: base + bonus }
}

export function clampXp(value: number, maxXp: number | null): number {
  const floored = Math.max(0, value)
  return maxXp == null ? floored : Math.min(maxXp, floored)
}
