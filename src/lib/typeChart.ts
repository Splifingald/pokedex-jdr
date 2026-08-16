import type { Attack, AutoBattleAbilityRule } from '../types'

// Table des types — SOURCE DE VÉRITÉ CÔTÉ CLIENT, doublon exact des fonctions
// SQL type_super_effective / type_no_effect (voir supabase/schema.sql, section
// « Table des types ») : le serveur reste seul juge du combat, le client ne
// s'en sert que pour l'affichage (badges des écrans de sélection, tableau
// récapitulatif admin) et pour griser les capacités sans effet. Toute
// modification doit donc être faite AUX DEUX ENDROITS.
//
// Règle (voir requirement) : l'efficacité dépend du type de LA CAPACITÉ
// utilisée face au type du pokémon DÉFENSEUR — plus du tout des colonnes
// « Super Efficace 1..4 » de l'espèce attaquante (toujours importées depuis le
// CSV, mais désormais inutilisées), et plus aucune condition « la capacité
// doit être du même type que son lanceur ».

/** Types dans l'ordre d'affichage (tableau admin, listes) — libellés canoniques. */
export const ALL_TYPES = [
  'Acier', 'Combat', 'Dragon', 'Eau', 'Electrik', 'Fée', 'Feu', 'Glace', 'Insecte',
  'Normal', 'Plante', 'Poison', 'Psy', 'Roche', 'Sol', 'Spectre', 'Ténèbres', 'Vol',
] as const

/** Types de pokémon contre lesquels chaque type de capacité est SUPER EFFICACE (dégâts de base x2). */
export const TYPE_SUPER_EFFECTIVE: Record<string, string[]> = {
  Acier: ['Fée', 'Glace', 'Roche'],
  Combat: ['Acier', 'Glace', 'Normal', 'Roche', 'Ténèbres'],
  Dragon: ['Dragon'],
  Eau: ['Feu', 'Roche', 'Sol'],
  Electrik: ['Eau', 'Vol'],
  Fée: ['Combat', 'Dragon', 'Ténèbres'],
  Feu: ['Acier', 'Glace', 'Insecte', 'Plante'],
  Glace: ['Dragon', 'Plante', 'Sol', 'Vol'],
  Insecte: ['Plante', 'Psy', 'Ténèbres'],
  Normal: [],
  Plante: ['Eau', 'Roche', 'Sol'],
  Poison: ['Combat', 'Plante'],
  Psy: ['Combat', 'Poison'],
  Roche: ['Feu', 'Glace', 'Insecte', 'Vol'],
  Sol: ['Acier', 'Electrik', 'Feu', 'Poison', 'Roche'],
  Spectre: ['Psy', 'Spectre'],
  Ténèbres: ['Psy', 'Spectre'],
  Vol: ['Combat', 'Insecte', 'Plante'],
}

/** Types de pokémon sur lesquels chaque type de capacité n'a AUCUN effet (immunité totale). */
export const TYPE_NO_EFFECT: Record<string, string[]> = {
  Combat: ['Spectre'],
  Dragon: ['Fée'],
  Electrik: ['Sol'],
  Normal: ['Spectre'],
  Poison: ['Acier'],
  Psy: ['Ténèbres'],
  Sol: ['Vol'],
  Spectre: ['Normal'],
}

// Les données mélangent plusieurs orthographes du même type (« Électrik » /
// « Electrik », « Fée » / « Fee », « Ténèbres » / « Tenebr » côté CSV des
// attaques, « Fantôme » / « Spectre ») — voir TYPE_COLORS, qui garde les mêmes
// alias. On compare donc toujours des libellés normalisés : minuscules, sans
// accent, alias ramenés au libellé canonique. Même normalisation côté SQL
// (type_norm).
const TYPE_ALIASES: Record<string, string> = {
  fantome: 'spectre',
  tenebr: 'tenebres',
  metal: 'acier',
}

export function normalizeType(type: string | null | undefined): string {
  const base = (type ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase()
  return TYPE_ALIASES[base] ?? base
}

function chartHas(chart: Record<string, string[]>, abilityType: string | null | undefined, defenderType: string | null | undefined): boolean {
  const atk = normalizeType(abilityType)
  const def = normalizeType(defenderType)
  if (!atk || !def) return false
  const entry = Object.entries(chart).find(([key]) => normalizeType(key) === atk)
  return entry ? entry[1].some((t) => normalizeType(t) === def) : false
}

/** Cette capacité est-elle super efficace (dégâts de base x2) contre ce type de pokémon ? */
export function isTypeSuperEffective(abilityType: string | null | undefined, defenderType: string | null | undefined): boolean {
  return chartHas(TYPE_SUPER_EFFECTIVE, abilityType, defenderType)
}

/** Ce type de pokémon est-il totalement immunisé contre ce type de capacité ? */
export function isTypeNoEffect(abilityType: string | null | undefined, defenderType: string | null | undefined): boolean {
  return chartHas(TYPE_NO_EFFECT, abilityType, defenderType)
}

// Une capacité "touche" l'adversaire si elle lui inflige des dégâts, lui
// applique un statut, cible ses stats ou lui pose un Anti-Soin — MÊME
// prédicat que côté serveur (voir la branche d'invulnérabilité de
// autobattle_resolve_round_core). Une capacité auto-ciblée (soin sur soi, buff
// sur soi, météo…) n'a rien à faire subir à l'adversaire : elle reste jouable
// même face à un pokémon immunisé à son type (voir requirement).
export function abilityTargetsOpponent(ability: Attack, rule: AutoBattleAbilityRule | undefined): boolean {
  return ability.deals_damage
    || (ability.status_effect != null && !rule?.status_reversed)
    || rule?.stat_mod_target === 'opponent'
    || rule?.cancel_heal_duration_turns != null
}

/**
 * Cette capacité est-elle INJOUABLE contre ce défenseur ? Vrai seulement si le
 * type du défenseur est immunisé au type de la capacité ET que la capacité
 * cherche justement à l'affecter — les capacités auto-ciblées restent jouables.
 *
 * `piercedType` : type dont l'immunité est actuellement PERCÉE au profit du
 * joueur (perce-immunité encore actif, voir AutoBattleAbilityRule.
 * pierce_immunity_type et son miroir serveur autobattle_type_immune) — les
 * capacités que ce type bloquerait redeviennent jouables. Une capacité qui
 * porte elle-même le perce-immunité du type d'en face n'est jamais bloquée non
 * plus : c'est elle qui ouvre la brèche, dès son propre coup.
 */
export function isAbilityBlockedByType(
  ability: Attack,
  rule: AutoBattleAbilityRule | undefined,
  defenderType: string | null | undefined,
  piercedType?: string | null,
): boolean {
  if (!isTypeNoEffect(ability.type, defenderType)) return false
  const def = normalizeType(defenderType)
  if (piercedType && normalizeType(piercedType) === def) return false
  if (rule?.pierce_immunity_type && normalizeType(rule.pierce_immunity_type) === def) return false
  return abilityTargetsOpponent(ability, rule)
}
