import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type {
  Attack, AutoBattleAbilityRule, AutoBattleTurnEffect, AutoBattleHealType, AutoBattleHealDotType,
  AutoBattleRecoilType, AutoBattleBonusDamageType, AutoBattleBonusDamageCondition,
  AutoBattleStatModTarget, AutoBattleStatModDirection, AutoBattleStatModStat, AutoBattleStatModValueType, AutoBattleStatModDurationType,
  AutoBattleStatusEffect, AutoBattleKeepGoingBonusType, AutoBattleIgnoreStatusBlock,
  AutoBattleWeather, AutoBattleDotType, AutoBattleWeightTarget, AutoBattleWeightComparison,
  AutoBattlePercentHpBasis,
} from '../types'
import { ALL_TYPES } from '../lib/typeChart'
import { useAutoBattleAbilityRules } from '../hooks/useAutoBattleAbilityRules'
import { useAutoBattleWeathers } from '../hooks/useAutoBattleWeathers'
import { useAttacks } from '../hooks/useAttacks'
import { MoveSearchInput } from './MoveSearchInput'
import { NumberInput } from './NumberInput'
import { TypeBadge } from './TypeBadge'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { CloseIcon } from './icons/CloseIcon'
import { STATUS_EFFECT_LABEL } from '../lib/autoBattle'

const TURN_EFFECT_LABEL: Record<AutoBattleTurnEffect, string> = {
  skip: 'Passe son tour',
  play_twice: 'Joue deux fois',
  play_three: 'Joue trois fois',
  play_random: 'Nombre aléatoire de fois',
  repeat_until_fail: "Répète jusqu'à l'échec",
  prepare_release: 'Prépare puis libère (2 tours)',
  charge_double_next: 'Joue 2 fois au prochain tour',
  first_and_replay: 'Passe premier et rejoue',
}

// Seuls ces trois statuts font passer le tour de leur porteur — les seuls
// qu'une capacité puisse donc « ignorer » (voir ignore_status_block).
const IGNORE_STATUS_BLOCK_VALUES: AutoBattleIgnoreStatusBlock[] = ['sleep', 'paralysis', 'frozen']

const KEEP_GOING_BONUS_TYPE_LABEL: Record<AutoBattleKeepGoingBonusType, string> = {
  flat: 'Montant fixe',
  percent_damage: 'Pourcentage des dégâts de base du pokémon',
}

const HEAL_TYPE_LABEL: Record<AutoBattleHealType, string> = {
  static: 'Montant fixe',
  percent_damage: '% des dégâts infligés',
  use_stats: 'Utilise ses propres stats (dégâts + dé)',
}

const HEAL_DOT_TYPE_LABEL: Record<AutoBattleHealDotType, string> = {
  flat: 'Montant fixe',
  percent_max_hp: '% des PV max',
  percent_damage: '% des dégâts infligés (au moment où le soin est accordé)',
}

const RECOIL_TYPE_LABEL: Record<AutoBattleRecoilType, string> = {
  range: 'Montant fixe ou fourchette',
  percent_damage: '% des dégâts infligés',
}

const BONUS_DAMAGE_TYPE_LABEL: Record<AutoBattleBonusDamageType, string> = {
  multiply: 'Multiplicateur',
  flat: 'Montant fixe',
  range: 'Fourchette',
}

const BONUS_DAMAGE_CONDITION_LABEL: Record<AutoBattleBonusDamageCondition, string> = {
  took_damage_last_turn: 'A subi des dégâts au dernier tour adverse',
  first_use: "C'est la toute première capacité utilisée par ce camp",
  dice_equals: 'Le dé de dégâts de cette capacité tombe sur une valeur précise',
  has_status: "L'adversaire est actuellement affecté par un statut",
  self_has_status: "L'utilisateur de la capacité est lui-même affecté par un statut",
  weight_ratio: 'Comparaison des poids des deux pokémon',
}

// Condition 'weight_ratio' : « poids(cible du test) <comparaison> X % du poids
// de l'autre » — voir autobattle_weight_condition côté SQL.
const WEIGHT_TARGET_LABEL: Record<AutoBattleWeightTarget, string> = {
  self: "L'utilisateur de la capacité pèse",
  opponent: "L'adversaire pèse",
}

const WEIGHT_COMPARISON_LABEL: Record<AutoBattleWeightComparison, string> = {
  greater: 'plus de',
  lower: 'moins de',
}

// Base des dégâts en % des PV de la cible (voir percent_hp_damage_basis).
const PERCENT_HP_BASIS_LABEL: Record<AutoBattlePercentHpBasis, string> = {
  current: 'PV restants de la cible (dégâts décroissants)',
  max: 'PV max de la cible (montant constant)',
}

// Effets persistants offensifs : mêmes deux formes de montant pour les dégâts
// par tour et le vol de vie par tour (voir AutoBattleDotType).
const DOT_TYPE_LABEL: Record<AutoBattleDotType, string> = {
  flat: 'Montant fixe',
  percent_max_hp: "% des PV max de l'adversaire",
}

// Cible et sens sont deux réglages INDÉPENDANTS : les quatre combinaisons sont
// permises, dont le malus qu'une capacité s'inflige à elle-même (façon Close
// Combat) ou le bonus offert à l'adversaire.
const STAT_MOD_TARGET_LABEL: Record<AutoBattleStatModTarget, string> = {
  opponent: "Sur l'adversaire",
  self: 'Sur son utilisateur',
}

const STAT_MOD_DIRECTION_LABEL: Record<AutoBattleStatModDirection, string> = {
  debuff: 'Baisse la stat (malus)',
  buff: 'Augmente la stat (bonus)',
}

const STAT_MOD_STAT_LABEL: Record<AutoBattleStatModStat, string> = {
  damage: 'Dégâts de base',
  precision: 'Précision',
}

const STAT_MOD_VALUE_TYPE_LABEL: Record<AutoBattleStatModValueType, string> = {
  flat: 'Montant fixe',
  range: 'Fourchette',
  percent: 'Pourcentage des dégâts de base',
}

const STAT_MOD_DURATION_TYPE_LABEL: Record<AutoBattleStatModDurationType, string> = {
  turns: 'Un nombre de tours',
  battle_end: "Jusqu'à la fin du combat",
}

const SELECT_CLASS = 'bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none'
const NUM_CLASS_SM = 'w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none'
const NUM_CLASS_MD = 'w-16 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none'

// Catalogue des effets spéciaux : leur libellé, leur regroupement thématique et
// le test qui dit si une capacité l'a DÉJÀ posé (son réglage « racine »). Une
// seule table pour deux usages, qui doivent rester d'accord :
//  - le menu « + Ajouter un effet spécial » d'une carte = les effets INACTIFS ;
//  - le repérage des capacités décrites dans le CSV mais encore sans aucun
//    effet configuré (voir hasAnyEffect / missingEffect dans le panneau).
type EffectDef = {
  value: string
  label: string
  group: string
  isActive: (rule: AutoBattleAbilityRule) => boolean
}

const EFFECT_DEFS: EffectDef[] = [
  { value: 'turn', label: 'Effet sur les tours', group: 'Rythme des tours', isActive: (r) => r.turn_effect != null },
  { value: 'percenthp', label: 'Dégâts en % des PV de la cible', group: 'Dégâts', isActive: (r) => r.percent_hp_damage_percent != null },
  { value: 'bonus', label: 'Dégâts additionnels conditionnels', group: 'Dégâts', isActive: (r) => r.bonus_damage_type != null },
  { value: 'recoil', label: 'Contre-coup', group: 'Dégâts', isActive: (r) => r.recoil_type != null },
  { value: 'heal', label: 'Soin instantané', group: 'Soins', isActive: (r) => r.heal_type != null },
  // L'effet est actif dès qu'il a une durée, QUELLE QU'ELLE SOIT : un nombre de
  // tours, ou « jusqu'au réveil » (auquel cas heal_dot_duration_turns est
  // justement nul — ne tester que cette colonne faisait disparaître toute la
  // carte de réglages dès qu'on cochait la case, en donnant l'impression que la
  // configuration avait été effacée).
  { value: 'healdot', label: 'Soin passif (heal over time)', group: 'Soins', isActive: (r) => r.heal_dot_duration_turns != null || r.heal_dot_until_awake },
  { value: 'cancelheal', label: 'Anti-Soin', group: 'Soins', isActive: (r) => r.cancel_heal_duration_turns != null },
  { value: 'damagedot', label: 'Dégâts persistants (damage over time)', group: 'Dégâts', isActive: (r) => r.damage_dot_duration_turns != null },
  { value: 'leechdot', label: 'Vol de vie persistant (life steal over time)', group: 'Dégâts', isActive: (r) => r.leech_dot_duration_turns != null },
  { value: 'statusdot', label: 'Tentative de statut persistante (status over time)', group: 'Dégâts', isActive: (r) => r.status_dot_duration_turns != null },
  { value: 'cleardot', label: 'Dissipe les effets persistants subis', group: 'Soins', isActive: (r) => r.clear_damage_dot },
  { value: 'curestatus', label: 'Guérit son propre statut', group: 'Soins', isActive: (r) => r.cure_status },
  { value: 'clearweather', label: 'Dissipe la météo en cours', group: 'Terrain', isActive: (r) => r.clear_weather },
  { value: 'pierceimmunity', label: "Perce l'immunité d'un type", group: 'Dégâts', isActive: (r) => r.pierce_immunity_type != null },
  { value: 'requirestatus', label: 'Ne marche que sur une cible sous statut', group: 'Rythme des tours', isActive: (r) => r.requires_target_status != null },
  // Même raisonnement que pour le soin passif : en mode « jusqu'au premier
  // raté », keep_going_turns est nul par construction.
  { value: 'keepgoing', label: 'Continue sur sa lancée (rejeu automatique)', group: 'Rythme des tours', isActive: (r) => r.keep_going_turns != null || r.keep_going_until_fail },
  { value: 'ignorestatus', label: 'Utilisable malgré un statut bloquant', group: 'Rythme des tours', isActive: (r) => r.ignore_status_block != null },
  { value: 'statmod', label: 'Modificateur de stat', group: 'Statistiques', isActive: (r) => r.stat_mod_target != null },
  { value: 'invuln', label: 'Invulnérabilité au prochain tour adverse', group: 'Défense', isActive: (r) => r.invulnerable_next_turn },
  { value: 'prevention', label: 'Prévention (bloque les dégâts super efficaces)', group: 'Défense', isActive: (r) => r.prevention_duration_turns != null },
  { value: 'weather', label: 'Déclenche une météo', group: 'Terrain', isActive: (r) => r.weather_id != null },
]

/** Vrai dès qu'un effet spécial quelconque est configuré sur cette capacité. */
function hasAnyEffect(rule: AutoBattleAbilityRule): boolean {
  // status_reversed ne figure pas dans EFFECT_DEFS (il n'est pas « ajoutable »,
  // il ne s'affiche que si le CSV donne un statut à la capacité) mais le cocher
  // reste un réglage de combat à part entière.
  return rule.status_reversed || EFFECT_DEFS.some((def) => def.isActive(rule))
}

/** Une ligne de la liste : la capacité du catalogue et ses effets (réels ou vides). */
type AbilityRow = {
  nom: string
  /** Absent pour une règle orpheline : capacité disparue du catalogue depuis. */
  attack: Attack | undefined
  rule: AutoBattleAbilityRule
  configured: boolean
  missingEffect: boolean
}

// Toutes les capacités du catalogue sont désormais listées, y compris celles
// qui n'ont aucune ligne en base : elles s'affichent sur cette règle vide, et
// la ligne n'est réellement créée qu'au premier réglage (voir handleUpdate).
function emptyRule(attackNom: string): AutoBattleAbilityRule {
  return {
    attack_nom: attackNom,
    turn_effect: null, turn_random_min: null, turn_random_max: null, repeat_max_iterations: null,
    heal_type: null, heal_amount: null, heal_percent: null,
    status_reversed: false,
    recoil_type: null, recoil_min: null, recoil_max: null, recoil_percent: null,
    invulnerable_next_turn: false,
    bonus_damage_type: null, bonus_damage_multiplier: null, bonus_damage_flat: null,
    bonus_damage_min: null, bonus_damage_max: null,
    bonus_damage_condition: null, bonus_damage_condition_dice_value: null, bonus_damage_status_filter: null,
    bonus_damage_weight_target: null, bonus_damage_weight_comparison: null, bonus_damage_weight_percent: null,
    stat_mod_target: null, stat_mod_direction: null, stat_mod_stat: null, stat_mod_value_type: null,
    stat_mod_flat: null, stat_mod_min: null, stat_mod_max: null, stat_mod_percent: null,
    stat_mod_duration_type: null, stat_mod_duration_turns: null, stat_mod_max_uses: null,
    stat_mod_type_filter: null, stat_mod_weather_condition: null, stat_mod_weather_id: null,
    heal_dot_type: null, heal_dot_amount: null, heal_dot_percent: null, heal_dot_duration_turns: null,
    heal_dot_until_awake: false,
    damage_dot_type: null, damage_dot_amount: null, damage_dot_percent: null, damage_dot_duration_turns: null,
    leech_dot_type: null, leech_dot_amount: null, leech_dot_percent: null, leech_dot_duration_turns: null,
    status_dot_status: null, status_dot_chance: null, status_dot_duration_turns: null,
    pierce_immunity_type: null, pierce_immunity_turns: null,
    requires_target_status: null,
    clear_damage_dot: false, clear_weather: false, cure_status: false,
    cancel_heal_duration_turns: null,
    percent_hp_damage_percent: null, percent_hp_damage_basis: null,
    prevention_duration_turns: null,
    keep_going_turns: null, keep_going_until_fail: false,
    keep_going_bonus_type: null, keep_going_bonus_flat: null, keep_going_bonus_percent: null,
    ignore_status_block: null,
    weather_id: null, weather_chance: null,
    created_at: '',
  }
}

// Un effet actif est affiché dans une carte avec son propre bouton de
// retrait — les effets inactifs ne s'affichent nulle part par défaut, ils
// n'apparaissent que dans le menu "+ Ajouter un effet spécial" en bas de
// carte (voir EFFECT_DEFS ci-dessus). Ça évite d'avoir 11
// sections quasi-vides ("Aucun") visibles en permanence pour chaque capacité.
function EffectSection({ label, onRemove, children }: { label: string; onRemove: () => void; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1 p-2 rounded border-2 border-ink/15 bg-white/60">
      <div className="flex items-center justify-between gap-2">
        <span className="text-ink text-xs font-bold">{label}</span>
        <button onClick={onRemove} title="Retirer cet effet" className="text-ink-muted-2 hover:text-ink shrink-0">
          <CloseIcon className="w-3 h-3" />
        </button>
      </div>
      {children}
    </div>
  )
}

// Regroupe logiquement les effets actifs par thème (rythme / dégâts / soins /
// stats / défense) — l'en-tête de catégorie ne s'affiche que s'il y a au
// moins un effet actif dedans (sinon la catégorie entière disparaît).
function EffectCategory({ label, children }: { label: string; children: React.ReactNode }) {
  const items = (Array.isArray(children) ? children : [children]).filter(Boolean)
  if (items.length === 0) return null
  return (
    <div className="flex flex-col gap-1.5">
      <span className="text-[#a3841a] text-[11px] font-bold uppercase tracking-wide">{label}</span>
      <div className="flex flex-col gap-1.5">{items}</div>
    </div>
  )
}

function AbilityRuleRow({
  rule, attack, attackTypes, weathers, onUpdate, onRemove, rowRef, highlighted, expanded, onToggle,
  configured, missingEffect,
}: {
  rule: AutoBattleAbilityRule
  attack: Attack | undefined
  /** La capacité a-t-elle vraiment une ligne en base ? Sinon `rule` est une règle vide, créée à la volée au premier réglage. */
  configured: boolean
  /** Le CSV décrit un effet spécial pour cette capacité, mais rien n'est configuré ici. */
  missingEffect: boolean
  /** Types élémentaires réellement présents dans le catalogue d'attaques — seule source fiable pour le filtre de type du modificateur de stat, qui est comparé côté SQL à attacks.type. */
  attackTypes: string[]
  /** Météos configurées (voir AdminAutoBattleWeathersPanel), triées par nom — la règle n'en stocke que l'id. */
  weathers: AutoBattleWeather[]
  onUpdate: (attackNom: string, patch: Partial<Omit<AutoBattleAbilityRule, 'attack_nom' | 'created_at'>>) => void
  onRemove: (attackNom: string) => void
  rowRef?: (el: HTMLDivElement | null) => void
  highlighted?: boolean
  /** Repliée par défaut : la liste tient alors sur une ligne par capacité. */
  expanded: boolean
  onToggle: () => void
}) {
  const handleTurnEffectChange = (value: string) => {
    if (value === '') {
      onUpdate(rule.attack_nom, { turn_effect: null, turn_random_min: null, turn_random_max: null, repeat_max_iterations: null })
    } else if (value === 'play_random') {
      onUpdate(rule.attack_nom, {
        turn_effect: 'play_random',
        turn_random_min: rule.turn_random_min ?? 1,
        turn_random_max: rule.turn_random_max ?? 4,
        repeat_max_iterations: null,
      })
    } else if (value === 'repeat_until_fail') {
      onUpdate(rule.attack_nom, {
        turn_effect: 'repeat_until_fail',
        repeat_max_iterations: rule.repeat_max_iterations ?? 6,
        turn_random_min: null,
        turn_random_max: null,
      })
    } else {
      onUpdate(rule.attack_nom, { turn_effect: value as AutoBattleTurnEffect, turn_random_min: null, turn_random_max: null, repeat_max_iterations: null })
    }
  }

  const handleHealTypeChange = (value: string) => {
    if (value === '') {
      onUpdate(rule.attack_nom, { heal_type: null, heal_amount: null, heal_percent: null })
    } else if (value === 'static') {
      onUpdate(rule.attack_nom, { heal_type: 'static', heal_amount: rule.heal_amount ?? 10, heal_percent: null })
    } else if (value === 'percent_damage') {
      onUpdate(rule.attack_nom, { heal_type: 'percent_damage', heal_percent: rule.heal_percent ?? 50, heal_amount: null })
    } else {
      onUpdate(rule.attack_nom, { heal_type: 'use_stats', heal_amount: null, heal_percent: null })
    }
  }

  const handleRecoilTypeChange = (value: string) => {
    if (value === '') {
      onUpdate(rule.attack_nom, { recoil_type: null, recoil_min: null, recoil_max: null, recoil_percent: null })
    } else if (value === 'range') {
      onUpdate(rule.attack_nom, { recoil_type: 'range', recoil_min: rule.recoil_min ?? 1, recoil_max: rule.recoil_max ?? 8, recoil_percent: null })
    } else {
      onUpdate(rule.attack_nom, { recoil_type: 'percent_damage', recoil_percent: rule.recoil_percent ?? 25, recoil_min: null, recoil_max: null })
    }
  }

  const handleBonusTypeChange = (value: string) => {
    if (value === '') {
      onUpdate(rule.attack_nom, {
        bonus_damage_type: null, bonus_damage_multiplier: null, bonus_damage_flat: null,
        bonus_damage_min: null, bonus_damage_max: null, bonus_damage_condition: null, bonus_damage_condition_dice_value: null,
        bonus_damage_status_filter: null,
        bonus_damage_weight_target: null, bonus_damage_weight_comparison: null, bonus_damage_weight_percent: null,
      })
      return
    }
    const condition = rule.bonus_damage_condition ?? 'has_status'
    const diceValue = condition === 'dice_equals' ? (rule.bonus_damage_condition_dice_value ?? 6) : null
    if (value === 'multiply') {
      onUpdate(rule.attack_nom, { bonus_damage_type: 'multiply', bonus_damage_multiplier: rule.bonus_damage_multiplier ?? 1.5, bonus_damage_flat: null, bonus_damage_min: null, bonus_damage_max: null, bonus_damage_condition: condition, bonus_damage_condition_dice_value: diceValue })
    } else if (value === 'flat') {
      onUpdate(rule.attack_nom, { bonus_damage_type: 'flat', bonus_damage_flat: rule.bonus_damage_flat ?? 10, bonus_damage_multiplier: null, bonus_damage_min: null, bonus_damage_max: null, bonus_damage_condition: condition, bonus_damage_condition_dice_value: diceValue })
    } else {
      onUpdate(rule.attack_nom, { bonus_damage_type: 'range', bonus_damage_min: rule.bonus_damage_min ?? 1, bonus_damage_max: rule.bonus_damage_max ?? 8, bonus_damage_multiplier: null, bonus_damage_flat: null, bonus_damage_condition: condition, bonus_damage_condition_dice_value: diceValue })
    }
  }

  const handleBonusConditionChange = (value: string) => {
    if (value === 'dice_equals') {
      onUpdate(rule.attack_nom, { bonus_damage_condition: 'dice_equals', bonus_damage_condition_dice_value: rule.bonus_damage_condition_dice_value ?? 6, bonus_damage_status_filter: null, bonus_damage_weight_target: null, bonus_damage_weight_comparison: null, bonus_damage_weight_percent: null })
    } else if (value === 'has_status' || value === 'self_has_status') {
      // Les deux conditions de statut partagent bonus_damage_status_filter :
      // passer de l'une à l'autre garde le statut déjà choisi.
      onUpdate(rule.attack_nom, { bonus_damage_condition: value, bonus_damage_condition_dice_value: null, bonus_damage_weight_target: null, bonus_damage_weight_comparison: null, bonus_damage_weight_percent: null })
    } else if (value === 'weight_ratio') {
      // La condition de poids exige ses trois réglages (voir la contrainte
      // autobattle_ability_rules_bonus_damage_weight_check) : posés d'un coup
      // avec des valeurs par défaut lisibles (« pèse plus de 200 % du poids de
      // l'adversaire »).
      onUpdate(rule.attack_nom, {
        bonus_damage_condition: 'weight_ratio', bonus_damage_condition_dice_value: null, bonus_damage_status_filter: null,
        bonus_damage_weight_target: rule.bonus_damage_weight_target ?? 'self',
        bonus_damage_weight_comparison: rule.bonus_damage_weight_comparison ?? 'greater',
        bonus_damage_weight_percent: rule.bonus_damage_weight_percent ?? 200,
      })
    } else {
      onUpdate(rule.attack_nom, { bonus_damage_condition: value as AutoBattleBonusDamageCondition, bonus_damage_condition_dice_value: null, bonus_damage_status_filter: null, bonus_damage_weight_target: null, bonus_damage_weight_comparison: null, bonus_damage_weight_percent: null })
    }
  }

  const handleBonusStatusFilterChange = (value: string) => {
    onUpdate(rule.attack_nom, { bonus_damage_status_filter: value === '' ? null : (value as AutoBattleStatusEffect) })
  }

  const handleStatModTargetChange = (value: string) => {
    if (value === '') {
      onUpdate(rule.attack_nom, {
        stat_mod_target: null, stat_mod_direction: null, stat_mod_stat: null, stat_mod_value_type: null,
        stat_mod_flat: null, stat_mod_min: null, stat_mod_max: null, stat_mod_percent: null,
        stat_mod_duration_type: null, stat_mod_duration_turns: null, stat_mod_max_uses: null,
      })
      return
    }
    const target = value as AutoBattleStatModTarget
    onUpdate(rule.attack_nom, {
      stat_mod_target: target,
      // Sens jamais laissé implicite à l'écriture : à défaut de choix déjà fait,
      // on pose celui de l'ancienne convention (adversaire = malus, soi = bonus),
      // que l'admin peut ensuite inverser librement.
      stat_mod_direction: rule.stat_mod_direction ?? (target === 'opponent' ? 'debuff' : 'buff'),
      stat_mod_stat: rule.stat_mod_stat ?? 'damage',
      stat_mod_value_type: rule.stat_mod_value_type ?? 'flat',
      stat_mod_flat: rule.stat_mod_flat ?? 3,
      stat_mod_duration_type: rule.stat_mod_duration_type ?? 'turns',
      stat_mod_duration_turns: rule.stat_mod_duration_turns ?? 3,
    })
  }

  // Météo levée par la capacité : weather_id et weather_chance vont toujours
  // ensemble (la contrainte CHECK exige 1..100 dès que la chance est posée).
  const handleWeatherToggle = (on: boolean) => {
    if (!on) {
      onUpdate(rule.attack_nom, { weather_id: null, weather_chance: null })
      return
    }
    onUpdate(rule.attack_nom, {
      weather_id: rule.weather_id ?? weathers[0]?.id ?? null,
      weather_chance: rule.weather_chance ?? 100,
    })
  }

  const handleStatModStatChange = (value: string) => {
    // La précision n'a pas de "pourcentage de dégâts de base" — repasse sur
    // montant fixe si on quitte 'damage' alors qu'un % était sélectionné.
    const nextValueType = value === 'precision' && rule.stat_mod_value_type === 'percent' ? 'flat' : rule.stat_mod_value_type
    onUpdate(rule.attack_nom, {
      stat_mod_stat: value as AutoBattleStatModStat,
      stat_mod_value_type: nextValueType,
      stat_mod_flat: nextValueType === 'flat' ? (rule.stat_mod_flat ?? 3) : null,
      stat_mod_percent: nextValueType === 'percent' ? rule.stat_mod_percent : null,
    })
  }

  const handleStatModValueTypeChange = (value: string) => {
    if (value === 'flat') {
      onUpdate(rule.attack_nom, { stat_mod_value_type: 'flat', stat_mod_flat: rule.stat_mod_flat ?? 3, stat_mod_min: null, stat_mod_max: null, stat_mod_percent: null })
    } else if (value === 'range') {
      onUpdate(rule.attack_nom, { stat_mod_value_type: 'range', stat_mod_min: rule.stat_mod_min ?? 1, stat_mod_max: rule.stat_mod_max ?? 5, stat_mod_flat: null, stat_mod_percent: null })
    } else {
      onUpdate(rule.attack_nom, { stat_mod_value_type: 'percent', stat_mod_percent: rule.stat_mod_percent ?? 20, stat_mod_flat: null, stat_mod_min: null, stat_mod_max: null })
    }
  }

  const handleStatModDurationTypeChange = (value: string) => {
    if (value === 'battle_end') {
      onUpdate(rule.attack_nom, { stat_mod_duration_type: 'battle_end', stat_mod_duration_turns: null })
    } else {
      onUpdate(rule.attack_nom, { stat_mod_duration_type: 'turns', stat_mod_duration_turns: rule.stat_mod_duration_turns ?? 3 })
    }
  }

  // Le type détermine si le montant par tour est un nombre fixe de PV ou un
  // pourcentage (des PV max de son utilisateur, ou des dégâts infligés par le
  // coup qui accorde l'effet) — résolu en un montant fixe une seule fois par
  // le serveur au moment de l'octroi, voir autobattle_ability_rules.
  const handleHealDotTypeChange = (value: string) => {
    // Durée : on ne la (re)pose QUE si l'effet n'est pas en mode "jusqu'au
    // réveil", où elle doit rester nulle — sinon changer le type de montant
    // ferait cohabiter les deux durées et l'écriture serait rejetée par la
    // contrainte autobattle_ability_rules_heal_dot_fields.
    const duration = rule.heal_dot_until_awake ? null : (rule.heal_dot_duration_turns ?? 3)
    if (value === 'percent_max_hp') {
      onUpdate(rule.attack_nom, { heal_dot_type: 'percent_max_hp', heal_dot_percent: rule.heal_dot_percent ?? 10, heal_dot_amount: null, heal_dot_duration_turns: duration })
    } else if (value === 'percent_damage') {
      onUpdate(rule.attack_nom, { heal_dot_type: 'percent_damage', heal_dot_percent: rule.heal_dot_percent ?? 25, heal_dot_amount: null, heal_dot_duration_turns: duration })
    } else {
      onUpdate(rule.attack_nom, { heal_dot_type: 'flat', heal_dot_amount: rule.heal_dot_amount ?? 5, heal_dot_percent: null, heal_dot_duration_turns: duration })
    }
  }

  const handleHealDotRemove = () => {
    onUpdate(rule.attack_nom, { heal_dot_type: null, heal_dot_amount: null, heal_dot_percent: null, heal_dot_duration_turns: null, heal_dot_until_awake: false })
  }

  // Durée du soin passif : soit un nombre de tours, soit "jusqu'au réveil"
  // (exclusifs — côté SQL, heal_dot_duration_turns doit être nul dans le
  // second cas, voir la contrainte autobattle_ability_rules_heal_dot_fields).
  const handleHealDotUntilAwakeToggle = (enabled: boolean) => {
    onUpdate(rule.attack_nom, enabled
      ? { heal_dot_until_awake: true, heal_dot_duration_turns: null }
      : { heal_dot_until_awake: false, heal_dot_duration_turns: rule.heal_dot_duration_turns ?? 3 })
  }

  const handleKeepGoingBonusTypeChange = (value: string) => {
    if (value === 'percent_damage') {
      onUpdate(rule.attack_nom, { keep_going_bonus_type: 'percent_damage', keep_going_bonus_percent: rule.keep_going_bonus_percent ?? 20, keep_going_bonus_flat: null })
    } else {
      onUpdate(rule.attack_nom, { keep_going_bonus_type: 'flat', keep_going_bonus_flat: rule.keep_going_bonus_flat ?? 5, keep_going_bonus_percent: null })
    }
  }

  // Les deux durées sont exclusives côté SQL (voir la contrainte
  // autobattle_ability_rules_keep_going_fields) : passer à "jusqu'au premier
  // raté" doit donc vider keep_going_turns, et inversement.
  const handleKeepGoingDurationChange = (value: string) => {
    onUpdate(rule.attack_nom, value === 'until_fail'
      ? { keep_going_until_fail: true, keep_going_turns: null }
      : { keep_going_until_fail: false, keep_going_turns: rule.keep_going_turns ?? 2 })
  }

  const handleKeepGoingToggle = (enabled: boolean) => {
    if (enabled) {
      onUpdate(rule.attack_nom, {
        keep_going_turns: rule.keep_going_turns ?? 2,
        keep_going_until_fail: false,
        keep_going_bonus_type: rule.keep_going_bonus_type ?? 'flat',
        keep_going_bonus_flat: (rule.keep_going_bonus_type ?? 'flat') === 'flat' ? (rule.keep_going_bonus_flat ?? 5) : null,
        keep_going_bonus_percent: rule.keep_going_bonus_type === 'percent_damage' ? (rule.keep_going_bonus_percent ?? 20) : null,
      })
    } else {
      onUpdate(rule.attack_nom, { keep_going_turns: null, keep_going_until_fail: false, keep_going_bonus_type: null, keep_going_bonus_flat: null, keep_going_bonus_percent: null })
    }
  }

  const handlePreventionToggle = (enabled: boolean) => {
    onUpdate(rule.attack_nom, { prevention_duration_turns: enabled ? (rule.prevention_duration_turns ?? 3) : null })
  }

  const handleCancelHealToggle = (enabled: boolean) => {
    onUpdate(rule.attack_nom, { cancel_heal_duration_turns: enabled ? (rule.cancel_heal_duration_turns ?? 3) : null })
  }

  const handlePercentHpDamageToggle = (enabled: boolean) => {
    onUpdate(rule.attack_nom, enabled
      ? { percent_hp_damage_percent: rule.percent_hp_damage_percent ?? 50, percent_hp_damage_basis: rule.percent_hp_damage_basis ?? 'current' }
      : { percent_hp_damage_percent: null, percent_hp_damage_basis: null })
  }

  // Effets persistants OFFENSIFS (dégâts par tour, vol de vie par tour) : même
  // structure que le soin passif — un type de montant, la valeur associée
  // (l'autre restant nulle, voir les contraintes autobattle_ability_rules_
  // damage_dot_fields/_leech_dot_fields) et une durée en tours.
  const handleDamageDotTypeChange = (value: string) => {
    const duration = rule.damage_dot_duration_turns ?? 3
    if (value === 'percent_max_hp') {
      onUpdate(rule.attack_nom, { damage_dot_type: 'percent_max_hp', damage_dot_percent: rule.damage_dot_percent ?? 10, damage_dot_amount: null, damage_dot_duration_turns: duration })
    } else {
      onUpdate(rule.attack_nom, { damage_dot_type: 'flat', damage_dot_amount: rule.damage_dot_amount ?? 5, damage_dot_percent: null, damage_dot_duration_turns: duration })
    }
  }

  const handleDamageDotRemove = () => {
    onUpdate(rule.attack_nom, { damage_dot_type: null, damage_dot_amount: null, damage_dot_percent: null, damage_dot_duration_turns: null })
  }

  const handleLeechDotTypeChange = (value: string) => {
    const duration = rule.leech_dot_duration_turns ?? 3
    if (value === 'percent_max_hp') {
      onUpdate(rule.attack_nom, { leech_dot_type: 'percent_max_hp', leech_dot_percent: rule.leech_dot_percent ?? 10, leech_dot_amount: null, leech_dot_duration_turns: duration })
    } else {
      onUpdate(rule.attack_nom, { leech_dot_type: 'flat', leech_dot_amount: rule.leech_dot_amount ?? 5, leech_dot_percent: null, leech_dot_duration_turns: duration })
    }
  }

  const handleLeechDotRemove = () => {
    onUpdate(rule.attack_nom, { leech_dot_type: null, leech_dot_amount: null, leech_dot_percent: null, leech_dot_duration_turns: null })
  }

  // Tentative de statut persistante : statut, probabilité et durée vont
  // toujours ensemble (contrainte autobattle_ability_rules_status_dot_fields).
  const handleStatusDotToggle = (enabled: boolean) => {
    onUpdate(rule.attack_nom, enabled
      ? {
        status_dot_status: rule.status_dot_status ?? 'sleep',
        status_dot_chance: rule.status_dot_chance ?? 30,
        status_dot_duration_turns: rule.status_dot_duration_turns ?? 3,
      }
      : { status_dot_status: null, status_dot_chance: null, status_dot_duration_turns: null })
  }

  // Perce-immunité : le type et la durée vont toujours ensemble (contrainte
  // autobattle_ability_rules_pierce_immunity_fields).
  const handlePierceImmunityToggle = (enabled: boolean) => {
    onUpdate(rule.attack_nom, enabled
      ? { pierce_immunity_type: rule.pierce_immunity_type ?? 'Spectre', pierce_immunity_turns: rule.pierce_immunity_turns ?? 3 }
      : { pierce_immunity_type: null, pierce_immunity_turns: null })
  }

  const handleRequiresTargetStatusToggle = (enabled: boolean) => {
    onUpdate(rule.attack_nom, { requires_target_status: enabled ? (rule.requires_target_status ?? 'sleep') : null })
  }

  const isHealDotActive = rule.heal_dot_duration_turns != null || rule.heal_dot_until_awake
  const isKeepGoingActive = rule.keep_going_turns != null || rule.keep_going_until_fail
  const healDotType = rule.heal_dot_type ?? 'flat'

  // Effets inactifs proposés dans le menu "+ Ajouter un effet spécial" en bas
  // de carte, groupés par thème (mêmes groupes que EffectCategory ci-dessus).
  // Un effet retiré de sa carte réapparaît automatiquement ici. La météo n'est
  // proposée que s'il en existe au moins une à lever — sinon l'effet serait
  // inerte et l'admin n'aurait rien à choisir. Rien à calculer tant que la
  // ligne est repliée : tout le catalogue de capacités est rendu d'un bloc.
  const addableEffects = expanded
    ? EFFECT_DEFS.filter((def) => !def.isActive(rule) && (def.value !== 'weather' || weathers.length > 0))
    : []

  const groupedAddableEffects = new Map<string, EffectDef[]>()
  for (const opt of addableEffects) {
    const list = groupedAddableEffects.get(opt.group) ?? []
    list.push(opt)
    groupedAddableEffects.set(opt.group, list)
  }

  const handleAddEffect = (key: string) => {
    switch (key) {
      case 'turn': handleTurnEffectChange('play_twice'); break
      case 'percenthp': handlePercentHpDamageToggle(true); break
      case 'bonus': handleBonusTypeChange('flat'); break
      case 'recoil': handleRecoilTypeChange('range'); break
      case 'heal': handleHealTypeChange('static'); break
      case 'healdot': handleHealDotTypeChange('flat'); break
      case 'cancelheal': handleCancelHealToggle(true); break
      case 'statmod': handleStatModTargetChange('opponent'); break
      case 'invuln': onUpdate(rule.attack_nom, { invulnerable_next_turn: true }); break
      case 'keepgoing': handleKeepGoingToggle(true); break
      case 'ignorestatus': onUpdate(rule.attack_nom, { ignore_status_block: 'sleep' }); break
      case 'prevention': handlePreventionToggle(true); break
      case 'weather': handleWeatherToggle(true); break
      case 'damagedot': handleDamageDotTypeChange('flat'); break
      case 'leechdot': handleLeechDotTypeChange('flat'); break
      case 'statusdot': handleStatusDotToggle(true); break
      case 'cleardot': onUpdate(rule.attack_nom, { clear_damage_dot: true }); break
      case 'curestatus': onUpdate(rule.attack_nom, { cure_status: true }); break
      case 'clearweather': onUpdate(rule.attack_nom, { clear_weather: true }); break
      case 'pierceimmunity': handlePierceImmunityToggle(true); break
      case 'requirestatus': handleRequiresTargetStatusToggle(true); break
    }
  }

  return (
    <div
      ref={rowRef}
      data-attack-nom={rule.attack_nom}
      className={`flex flex-col gap-2 p-3 rounded transition-shadow duration-500 ${
        missingEffect ? 'border-2 border-[#c0392b] bg-[#fdecea]' : `${PIXEL_BORDER_SM} bg-white`
      } ${highlighted ? 'ring-4 ring-[#f0c419]' : ''}`}
    >
      {/* Vue repliée : type + nom, plus un rappel « effet manquant » quand le
          CSV décrit un effet spécial qu'aucun réglage ne traduit encore. Toute
          la ligne est cliquable pour déplier ; la suppression n'est offerte
          qu'une fois dépliée, pour ne pas risquer un clic malheureux en
          parcourant la liste. */}
      <button
        type="button"
        onClick={onToggle}
        className="flex items-center gap-2 text-left w-full"
        aria-expanded={expanded}
      >
        <span className="text-ink-muted-2 text-xs w-3 shrink-0">{expanded ? '▾' : '▸'}</span>
        <TypeBadge type={attack?.type ?? '?'} small />
        <span className={`text-sm flex-1 truncate ${configured ? 'text-ink font-bold' : 'text-ink-muted-2'}`}>{rule.attack_nom}</span>
        {missingEffect && (
          <span className="shrink-0 text-[#c0392b] text-[11px] font-bold whitespace-nowrap">⚠ effet à configurer</span>
        )}
      </button>

      {!expanded ? null : (
      <>
      {/* L'effet décrit dans le CSV (colonne « Effet ») : c'est la consigne à
          traduire en réglages ci-dessous. */}
      {attack?.effet && attack.effet.trim() !== '' && (
        <p className={`text-xs italic px-2 py-1.5 rounded border-2 ${missingEffect ? 'border-[#c0392b]/40 text-[#c0392b]' : 'border-ink/15 text-ink-muted-2'}`}>
          {attack.effet}
        </p>
      )}

      {/* Plus de réglage d'animation ici : elle vient désormais uniquement des
          colonnes « Animation » / « Animation 2 » du CSV des attaques (voir
          src/lib/battleAnimations.ts). */}

      {attack?.status_effect && (
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={rule.status_reversed}
            onChange={(e) => onUpdate(rule.attack_nom, { status_reversed: e.target.checked })}
            className="w-4 h-4"
          />
          <span className="text-ink-muted-2 text-xs">Statut inversé (s'applique à son utilisateur, pas à l'adversaire)</span>
        </label>
      )}

      <EffectCategory label="Rythme des tours">
        {rule.turn_effect != null && (
          <EffectSection label="Effet sur les tours" onRemove={() => handleTurnEffectChange('')}>
            <select value={rule.turn_effect} onChange={(e) => handleTurnEffectChange(e.target.value)} className={SELECT_CLASS}>
              {(Object.keys(TURN_EFFECT_LABEL) as AutoBattleTurnEffect[]).map((t) => (
                <option key={t} value={t}>{TURN_EFFECT_LABEL[t]}</option>
              ))}
            </select>
            {rule.turn_effect === 'play_random' && (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">Entre</span>
                <NumberInput
                  min={1}
                  fallback={rule.turn_random_min ?? 1}
                  value={rule.turn_random_min ?? 1}
                  onCommit={(v) => onUpdate(rule.attack_nom, { turn_random_min: Math.max(1, Math.min(v, rule.turn_random_max ?? 4)) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">et</span>
                <NumberInput
                  min={1}
                  fallback={rule.turn_random_max ?? 4}
                  value={rule.turn_random_max ?? 4}
                  onCommit={(v) => onUpdate(rule.attack_nom, { turn_random_max: Math.max(v, rule.turn_random_min ?? 1) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">fois</span>
              </div>
            )}
            {rule.turn_effect === 'repeat_until_fail' && (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">Maximum</span>
                <NumberInput
                  min={1}
                  fallback={rule.repeat_max_iterations ?? 6}
                  value={rule.repeat_max_iterations ?? 6}
                  onCommit={(v) => onUpdate(rule.attack_nom, { repeat_max_iterations: Math.max(1, v) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">répétitions</span>
              </div>
            )}
          </EffectSection>
        )}
        {isKeepGoingActive && (
          <EffectSection label="Continue sur sa lancée (rejeu automatique, bonus cumulatif)" onRemove={() => handleKeepGoingToggle(false)}>
            <select
              value={rule.keep_going_until_fail ? 'until_fail' : 'turns'}
              onChange={(e) => handleKeepGoingDurationChange(e.target.value)}
              className={SELECT_CLASS}
            >
              <option value="turns">Pendant un nombre de tours</option>
              <option value="until_fail">Jusqu'au premier raté</option>
            </select>
            {rule.keep_going_until_fail ? (
              <span className="text-ink-muted-2 text-xs mt-1">
                Se rejoue à chaque tour (une seule fois par tour, capacité imposée) tant qu'elle touche — la main revient au premier raté.
              </span>
            ) : (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">Se rejoue pendant</span>
                <NumberInput
                  min={1}
                  fallback={rule.keep_going_turns ?? 2}
                  value={rule.keep_going_turns ?? 2}
                  onCommit={(v) => onUpdate(rule.attack_nom, { keep_going_turns: Math.max(1, v) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">tours de plus (capacité imposée)</span>
              </div>
            )}
            <select value={rule.keep_going_bonus_type ?? 'flat'} onChange={(e) => handleKeepGoingBonusTypeChange(e.target.value)} className={`${SELECT_CLASS} mt-1`}>
              {(Object.keys(KEEP_GOING_BONUS_TYPE_LABEL) as AutoBattleKeepGoingBonusType[]).map((t) => (
                <option key={t} value={t}>{KEEP_GOING_BONUS_TYPE_LABEL[t]}</option>
              ))}
            </select>
            {(rule.keep_going_bonus_type ?? 'flat') === 'flat' ? (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">+</span>
                <NumberInput
                  min={0}
                  fallback={rule.keep_going_bonus_flat ?? 5}
                  value={rule.keep_going_bonus_flat ?? 5}
                  onCommit={(v) => onUpdate(rule.attack_nom, { keep_going_bonus_flat: Math.max(0, v) })}
                  className={NUM_CLASS_MD}
                />
                <span className="text-ink-muted-2 text-xs">dégâts par réutilisation (cumulatif)</span>
              </div>
            ) : (
              <div className="flex items-center gap-2 mt-1">
                <NumberInput
                  min={1}
                  fallback={rule.keep_going_bonus_percent ?? 20}
                  value={rule.keep_going_bonus_percent ?? 20}
                  onCommit={(v) => onUpdate(rule.attack_nom, { keep_going_bonus_percent: Math.max(1, v) })}
                  className={NUM_CLASS_MD}
                />
                <span className="text-ink-muted-2 text-xs">% des dégâts de base du pokémon (hors dégâts de la capacité) par réutilisation (cumulatif)</span>
              </div>
            )}
            <span className="text-ink-muted-2 text-[11px] mt-1">
              La 1ère utilisation n'a aucun bonus, la 2e en a un, la 3e le double, etc. La chaîne s'interrompt toujours au premier raté, ou si un statut bloquant (paralysie, gel, sommeil) fait passer le tour.
            </span>
          </EffectSection>
        )}
        {rule.ignore_status_block != null && (
          <EffectSection label="Utilisable malgré un statut bloquant" onRemove={() => onUpdate(rule.attack_nom, { ignore_status_block: null })}>
            <select
              value={rule.ignore_status_block}
              onChange={(e) => onUpdate(rule.attack_nom, { ignore_status_block: e.target.value as AutoBattleIgnoreStatusBlock })}
              className={SELECT_CLASS}
            >
              {IGNORE_STATUS_BLOCK_VALUES.map((s) => (
                <option key={s} value={s}>{STATUS_EFFECT_LABEL[s]}</option>
              ))}
            </select>
            <span className="text-ink-muted-2 text-xs mt-1">
              Ce statut-là ne fait plus passer le tour de son utilisateur quand cette capacité est jouée (les deux autres continuent de le bloquer, et le statut évolue normalement dans tous les cas).
            </span>
          </EffectSection>
        )}
        {rule.requires_target_status != null && (
          <EffectSection
            label="Ne fonctionne que sur une cible sous statut"
            onRemove={() => handleRequiresTargetStatusToggle(false)}
          >
            <select
              value={rule.requires_target_status}
              onChange={(e) => onUpdate(rule.attack_nom, { requires_target_status: e.target.value as AutoBattleStatusEffect })}
              className={SELECT_CLASS}
            >
              {(Object.keys(STATUS_EFFECT_LABEL) as AutoBattleStatusEffect[]).map((s) => (
                <option key={s} value={s}>{STATUS_EFFECT_LABEL[s]}</option>
              ))}
            </select>
            <span className="text-ink-muted-2 text-xs mt-1">
              Si la cible n'est pas affectée par exactement ce statut au moment du coup, la capacité échoue :
              aucun dégât, aucun effet, et le tour est consommé (comme un raté).
            </span>
          </EffectSection>
        )}
      </EffectCategory>

      <EffectCategory label="Dégâts">
        {rule.percent_hp_damage_percent != null && (
          <EffectSection label="Dégâts en % des PV de la cible (remplace les dégâts habituels)" onRemove={() => handlePercentHpDamageToggle(false)}>
            <select
              value={rule.percent_hp_damage_basis ?? 'current'}
              onChange={(e) => onUpdate(rule.attack_nom, { percent_hp_damage_basis: e.target.value as AutoBattlePercentHpBasis })}
              className={SELECT_CLASS}
            >
              {(Object.keys(PERCENT_HP_BASIS_LABEL) as AutoBattlePercentHpBasis[]).map((b) => (
                <option key={b} value={b}>{PERCENT_HP_BASIS_LABEL[b]}</option>
              ))}
            </select>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-ink-muted-2 text-xs">Inflige</span>
              <NumberInput
                min={1}
                fallback={rule.percent_hp_damage_percent ?? 50}
                value={rule.percent_hp_damage_percent ?? 50}
                onCommit={(v) => onUpdate(rule.attack_nom, { percent_hp_damage_percent: Math.max(1, Math.min(100, v)) })}
                className={NUM_CLASS_SM}
              />
              <span className="text-ink-muted-2 text-xs">
                {rule.percent_hp_damage_basis === 'max' ? '% des PV max de la cible' : '% des PV restants de la cible'}
              </span>
            </div>
            <span className="text-ink-muted-2 text-[11px] mt-1">
              {rule.percent_hp_damage_basis === 'max'
                ? 'Montant constant tout le combat : ces dégâts-là peuvent mettre K.O.'
                : "Dégâts décroissants à mesure que la cible s'affaiblit — ils ne peuvent jamais l'achever seuls (façon Ultimapoing)."}
            </span>
          </EffectSection>
        )}
        {rule.bonus_damage_type != null && (
          <EffectSection label="Dégâts additionnels conditionnels" onRemove={() => handleBonusTypeChange('')}>
            <select value={rule.bonus_damage_type} onChange={(e) => handleBonusTypeChange(e.target.value)} className={SELECT_CLASS}>
              {(Object.keys(BONUS_DAMAGE_TYPE_LABEL) as AutoBattleBonusDamageType[]).map((t) => (
                <option key={t} value={t}>{BONUS_DAMAGE_TYPE_LABEL[t]}</option>
              ))}
            </select>
            {rule.bonus_damage_type === 'multiply' && (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">×</span>
                <input
                  type="number"
                  step="0.1"
                  min="0.1"
                  value={rule.bonus_damage_multiplier ?? 1.5}
                  onChange={(e) => onUpdate(rule.attack_nom, { bonus_damage_multiplier: Math.max(0.1, parseFloat(e.target.value) || 1) })}
                  className={NUM_CLASS_MD}
                />
              </div>
            )}
            {rule.bonus_damage_type === 'flat' && (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">+</span>
                <NumberInput
                  min={1}
                  fallback={rule.bonus_damage_flat ?? 10}
                  value={rule.bonus_damage_flat ?? 10}
                  onCommit={(v) => onUpdate(rule.attack_nom, { bonus_damage_flat: Math.max(1, v) })}
                  className={NUM_CLASS_MD}
                />
              </div>
            )}
            {rule.bonus_damage_type === 'range' && (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">Entre</span>
                <NumberInput
                  min={1}
                  fallback={rule.bonus_damage_min ?? 1}
                  value={rule.bonus_damage_min ?? 1}
                  onCommit={(v) => onUpdate(rule.attack_nom, { bonus_damage_min: Math.max(1, Math.min(v, rule.bonus_damage_max ?? 8)) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">et</span>
                <NumberInput
                  min={1}
                  fallback={rule.bonus_damage_max ?? 8}
                  value={rule.bonus_damage_max ?? 8}
                  onCommit={(v) => onUpdate(rule.attack_nom, { bonus_damage_max: Math.max(v, rule.bonus_damage_min ?? 1) })}
                  className={NUM_CLASS_SM}
                />
              </div>
            )}
            <div className="flex flex-col gap-1 mt-1">
              <span className="text-ink-muted-2 text-xs">Condition</span>
              <select
                value={rule.bonus_damage_condition ?? ''}
                onChange={(e) => handleBonusConditionChange(e.target.value)}
                className={SELECT_CLASS}
              >
                {(Object.keys(BONUS_DAMAGE_CONDITION_LABEL) as AutoBattleBonusDamageCondition[]).map((c) => (
                  <option key={c} value={c}>{BONUS_DAMAGE_CONDITION_LABEL[c]}</option>
                ))}
              </select>
              {rule.bonus_damage_condition === 'dice_equals' && (
                <div className="flex items-center gap-2 mt-1">
                  <span className="text-ink-muted-2 text-xs">Si le dé tombe sur</span>
                  <NumberInput
                    min={1}
                    fallback={rule.bonus_damage_condition_dice_value ?? 1}
                    value={rule.bonus_damage_condition_dice_value ?? 1}
                    onCommit={(v) => onUpdate(rule.attack_nom, { bonus_damage_condition_dice_value: Math.max(1, v) })}
                    className={NUM_CLASS_SM}
                  />
                </div>
              )}
              {(rule.bonus_damage_condition === 'has_status' || rule.bonus_damage_condition === 'self_has_status') && (
                <div className="flex items-center gap-2 mt-1">
                  <span className="text-ink-muted-2 text-xs">Statut</span>
                  <select
                    value={rule.bonus_damage_status_filter ?? ''}
                    onChange={(e) => handleBonusStatusFilterChange(e.target.value)}
                    className={SELECT_CLASS}
                  >
                    <option value="">N'importe quel statut</option>
                    {(Object.keys(STATUS_EFFECT_LABEL) as AutoBattleStatusEffect[]).map((s) => (
                      <option key={s} value={s}>{STATUS_EFFECT_LABEL[s]}</option>
                    ))}
                  </select>
                </div>
              )}
              {/* Comparaison des poids (pokemon.poids, colonne « Poids » du
                  CSV) : se lit comme une phrase — « L'utilisateur pèse plus de
                  200 % du poids de l'adversaire ». */}
              {rule.bonus_damage_condition === 'weight_ratio' && (
                <div className="flex items-center gap-2 mt-1 flex-wrap">
                  <select
                    value={rule.bonus_damage_weight_target ?? 'self'}
                    onChange={(e) => onUpdate(rule.attack_nom, { bonus_damage_weight_target: e.target.value as AutoBattleWeightTarget })}
                    className={SELECT_CLASS}
                  >
                    {(Object.keys(WEIGHT_TARGET_LABEL) as AutoBattleWeightTarget[]).map((t) => (
                      <option key={t} value={t}>{WEIGHT_TARGET_LABEL[t]}</option>
                    ))}
                  </select>
                  <select
                    value={rule.bonus_damage_weight_comparison ?? 'greater'}
                    onChange={(e) => onUpdate(rule.attack_nom, { bonus_damage_weight_comparison: e.target.value as AutoBattleWeightComparison })}
                    className={SELECT_CLASS}
                  >
                    {(Object.keys(WEIGHT_COMPARISON_LABEL) as AutoBattleWeightComparison[]).map((c) => (
                      <option key={c} value={c}>{WEIGHT_COMPARISON_LABEL[c]}</option>
                    ))}
                  </select>
                  <NumberInput
                    min={1}
                    fallback={rule.bonus_damage_weight_percent ?? 100}
                    value={rule.bonus_damage_weight_percent ?? 100}
                    onCommit={(v) => onUpdate(rule.attack_nom, { bonus_damage_weight_percent: Math.max(1, v) })}
                    className={NUM_CLASS_MD}
                  />
                  <span className="text-ink-muted-2 text-xs">
                    % du poids {rule.bonus_damage_weight_target === 'opponent' ? "de l'utilisateur" : "de l'adversaire"}
                  </span>
                </div>
              )}
            </div>
          </EffectSection>
        )}
        {rule.damage_dot_duration_turns != null && (
          <EffectSection label="Dégâts persistants (rongent l'adversaire à chaque début de SON tour)" onRemove={handleDamageDotRemove}>
            <select value={rule.damage_dot_type ?? 'flat'} onChange={(e) => handleDamageDotTypeChange(e.target.value)} className={SELECT_CLASS}>
              {(Object.keys(DOT_TYPE_LABEL) as AutoBattleDotType[]).map((t) => (
                <option key={t} value={t}>{DOT_TYPE_LABEL[t]}</option>
              ))}
            </select>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-ink-muted-2 text-xs">Inflige</span>
              {(rule.damage_dot_type ?? 'flat') === 'flat' ? (
                <>
                  <NumberInput
                    min={1}
                    fallback={rule.damage_dot_amount ?? 5}
                    value={rule.damage_dot_amount ?? 5}
                    onCommit={(v) => onUpdate(rule.attack_nom, { damage_dot_amount: Math.max(1, v) })}
                    className={NUM_CLASS_SM}
                  />
                  <span className="text-ink-muted-2 text-xs">PV par tour</span>
                </>
              ) : (
                <>
                  <NumberInput
                    min={1}
                    fallback={rule.damage_dot_percent ?? 10}
                    value={rule.damage_dot_percent ?? 10}
                    onCommit={(v) => onUpdate(rule.attack_nom, { damage_dot_percent: Math.max(1, Math.min(100, v)) })}
                    className={NUM_CLASS_SM}
                  />
                  <span className="text-ink-muted-2 text-xs">% des PV max de l'adversaire, par tour</span>
                </>
              )}
            </div>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-ink-muted-2 text-xs">Pendant</span>
              <NumberInput
                min={1}
                fallback={rule.damage_dot_duration_turns ?? 3}
                value={rule.damage_dot_duration_turns ?? 3}
                onCommit={(v) => onUpdate(rule.attack_nom, { damage_dot_duration_turns: Math.max(1, v) })}
                className={NUM_CLASS_SM}
              />
              <span className="text-ink-muted-2 text-xs">tours de combat</span>
            </div>
          </EffectSection>
        )}
        {rule.leech_dot_duration_turns != null && (
          <EffectSection label="Vol de vie persistant (les PV volés à l'adversaire reviennent à son utilisateur)" onRemove={handleLeechDotRemove}>
            <select value={rule.leech_dot_type ?? 'flat'} onChange={(e) => handleLeechDotTypeChange(e.target.value)} className={SELECT_CLASS}>
              {(Object.keys(DOT_TYPE_LABEL) as AutoBattleDotType[]).map((t) => (
                <option key={t} value={t}>{DOT_TYPE_LABEL[t]}</option>
              ))}
            </select>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-ink-muted-2 text-xs">Vole</span>
              {(rule.leech_dot_type ?? 'flat') === 'flat' ? (
                <>
                  <NumberInput
                    min={1}
                    fallback={rule.leech_dot_amount ?? 5}
                    value={rule.leech_dot_amount ?? 5}
                    onCommit={(v) => onUpdate(rule.attack_nom, { leech_dot_amount: Math.max(1, v) })}
                    className={NUM_CLASS_SM}
                  />
                  <span className="text-ink-muted-2 text-xs">PV par tour</span>
                </>
              ) : (
                <>
                  <NumberInput
                    min={1}
                    fallback={rule.leech_dot_percent ?? 10}
                    value={rule.leech_dot_percent ?? 10}
                    onCommit={(v) => onUpdate(rule.attack_nom, { leech_dot_percent: Math.max(1, Math.min(100, v)) })}
                    className={NUM_CLASS_SM}
                  />
                  <span className="text-ink-muted-2 text-xs">% des PV max de l'adversaire, par tour</span>
                </>
              )}
            </div>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-ink-muted-2 text-xs">Pendant</span>
              <NumberInput
                min={1}
                fallback={rule.leech_dot_duration_turns ?? 3}
                value={rule.leech_dot_duration_turns ?? 3}
                onCommit={(v) => onUpdate(rule.attack_nom, { leech_dot_duration_turns: Math.max(1, v) })}
                className={NUM_CLASS_SM}
              />
              <span className="text-ink-muted-2 text-xs">tours de combat</span>
            </div>
          </EffectSection>
        )}
        {rule.status_dot_duration_turns != null && (
          <EffectSection
            label="Tentative de statut persistante (un jet à chaque début de tour de l'adversaire)"
            onRemove={() => handleStatusDotToggle(false)}
          >
            <div className="flex items-center gap-2 flex-wrap">
              <select
                value={rule.status_dot_status ?? 'sleep'}
                onChange={(e) => onUpdate(rule.attack_nom, { status_dot_status: e.target.value as AutoBattleStatusEffect })}
                className={SELECT_CLASS}
              >
                {(Object.keys(STATUS_EFFECT_LABEL) as AutoBattleStatusEffect[]).map((s) => (
                  <option key={s} value={s}>{STATUS_EFFECT_LABEL[s]}</option>
                ))}
              </select>
              <NumberInput
                min={1}
                fallback={rule.status_dot_chance ?? 30}
                value={rule.status_dot_chance ?? 30}
                onCommit={(v) => onUpdate(rule.attack_nom, { status_dot_chance: Math.max(1, Math.min(100, v)) })}
                className={NUM_CLASS_SM}
              />
              <span className="text-ink-muted-2 text-xs">% de chances par tour</span>
            </div>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-ink-muted-2 text-xs">Pendant</span>
              <NumberInput
                min={1}
                fallback={rule.status_dot_duration_turns ?? 3}
                value={rule.status_dot_duration_turns ?? 3}
                onCommit={(v) => onUpdate(rule.attack_nom, { status_dot_duration_turns: Math.max(1, v) })}
                className={NUM_CLASS_SM}
              />
              <span className="text-ink-muted-2 text-xs">tours de combat</span>
            </div>
            <span className="text-ink-muted-2 text-[11px] mt-1">
              Aucun jet tant que l'adversaire a déjà un statut (un seul à la fois) : l'effet le guette jusqu'à
              expiration. Un statut posé ainsi ne se manifeste qu'au tour suivant de sa victime.
            </span>
          </EffectSection>
        )}
        {rule.pierce_immunity_type != null && (
          <EffectSection label="Perce-immunité (lève l'immunité d'un type, dès ce coup-ci)" onRemove={() => handlePierceImmunityToggle(false)}>
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-ink-muted-2 text-xs">Immunité levée pour les pokémon de type</span>
              <select
                value={rule.pierce_immunity_type}
                onChange={(e) => onUpdate(rule.attack_nom, { pierce_immunity_type: e.target.value })}
                className={SELECT_CLASS}
              >
                {ALL_TYPES.map((t) => (
                  <option key={t} value={t}>{t}</option>
                ))}
              </select>
            </div>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-ink-muted-2 text-xs">Pendant</span>
              <NumberInput
                min={1}
                fallback={rule.pierce_immunity_turns ?? 3}
                value={rule.pierce_immunity_turns ?? 3}
                onCommit={(v) => onUpdate(rule.attack_nom, { pierce_immunity_turns: Math.max(1, v) })}
                className={NUM_CLASS_SM}
              />
              <span className="text-ink-muted-2 text-xs">tours de combat</span>
            </div>
          </EffectSection>
        )}
        {rule.recoil_type != null && (
          <EffectSection label="Contre-coup (dégâts sur son utilisateur, après le reste)" onRemove={() => handleRecoilTypeChange('')}>
            <select value={rule.recoil_type} onChange={(e) => handleRecoilTypeChange(e.target.value)} className={SELECT_CLASS}>
              {(Object.keys(RECOIL_TYPE_LABEL) as AutoBattleRecoilType[]).map((t) => (
                <option key={t} value={t}>{RECOIL_TYPE_LABEL[t]}</option>
              ))}
            </select>
            {rule.recoil_type === 'range' && (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">Entre</span>
                <NumberInput
                  min={0}
                  fallback={rule.recoil_min ?? 1}
                  value={rule.recoil_min ?? 1}
                  onCommit={(v) => onUpdate(rule.attack_nom, { recoil_min: Math.max(0, Math.min(v, rule.recoil_max ?? 8)) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">et</span>
                <NumberInput
                  min={0}
                  fallback={rule.recoil_max ?? 8}
                  value={rule.recoil_max ?? 8}
                  onCommit={(v) => onUpdate(rule.attack_nom, { recoil_max: Math.max(v, rule.recoil_min ?? 0) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">PV (même valeur des deux côtés = montant fixe)</span>
              </div>
            )}
            {rule.recoil_type === 'percent_damage' && (
              <div className="flex items-center gap-2 mt-1">
                <NumberInput
                  min={1}
                  fallback={rule.recoil_percent ?? 25}
                  value={rule.recoil_percent ?? 25}
                  onCommit={(v) => onUpdate(rule.attack_nom, { recoil_percent: Math.max(1, v) })}
                  className={NUM_CLASS_MD}
                />
                <span className="text-ink-muted-2 text-xs">%</span>
              </div>
            )}
          </EffectSection>
        )}
      </EffectCategory>

      <EffectCategory label="Soins">
        {rule.heal_type != null && (
          <EffectSection label="Soin instantané (sur son utilisateur, après les dégâts)" onRemove={() => handleHealTypeChange('')}>
            <select value={rule.heal_type} onChange={(e) => handleHealTypeChange(e.target.value)} className={SELECT_CLASS}>
              {(Object.keys(HEAL_TYPE_LABEL) as AutoBattleHealType[]).map((t) => (
                <option key={t} value={t}>{HEAL_TYPE_LABEL[t]}</option>
              ))}
            </select>
            {rule.heal_type === 'static' && (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">Montant</span>
                <NumberInput
                  min={1}
                  fallback={rule.heal_amount ?? 10}
                  value={rule.heal_amount ?? 10}
                  onCommit={(v) => onUpdate(rule.attack_nom, { heal_amount: Math.max(1, v) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">PV</span>
              </div>
            )}
            {rule.heal_type === 'percent_damage' && (
              <div className="flex items-center gap-2 mt-1">
                <NumberInput
                  min={1}
                  fallback={rule.heal_percent ?? 50}
                  value={rule.heal_percent ?? 50}
                  onCommit={(v) => onUpdate(rule.attack_nom, { heal_percent: Math.max(1, Math.min(100, v)) })}
                  className={NUM_CLASS_MD}
                />
                <span className="text-ink-muted-2 text-xs">%</span>
              </div>
            )}
          </EffectSection>
        )}
        {isHealDotActive && (
          <EffectSection label="Soin passif (soigne son utilisateur à chaque début de son tour)" onRemove={handleHealDotRemove}>
            <select value={healDotType} onChange={(e) => handleHealDotTypeChange(e.target.value)} className={SELECT_CLASS}>
              {(Object.keys(HEAL_DOT_TYPE_LABEL) as AutoBattleHealDotType[]).map((t) => (
                <option key={t} value={t}>{HEAL_DOT_TYPE_LABEL[t]}</option>
              ))}
            </select>
            {healDotType === 'flat' && (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">Soigne</span>
                <NumberInput
                  min={1}
                  fallback={rule.heal_dot_amount ?? 5}
                  value={rule.heal_dot_amount ?? 5}
                  onCommit={(v) => onUpdate(rule.attack_nom, { heal_dot_amount: Math.max(1, v) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">PV par tour</span>
              </div>
            )}
            {healDotType !== 'flat' && (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">Soigne</span>
                <NumberInput
                  min={1}
                  fallback={rule.heal_dot_percent ?? 10}
                  value={rule.heal_dot_percent ?? 10}
                  onCommit={(v) => onUpdate(rule.attack_nom, { heal_dot_percent: Math.max(1, Math.min(100, v)) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">
                  {healDotType === 'percent_max_hp' ? '% de ses PV max, par tour' : '% des dégâts infligés par ce coup, par tour'}
                </span>
              </div>
            )}
            {!rule.heal_dot_until_awake && (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">Pendant</span>
                <NumberInput
                  min={1}
                  fallback={rule.heal_dot_duration_turns ?? 3}
                  value={rule.heal_dot_duration_turns ?? 3}
                  onCommit={(v) => onUpdate(rule.attack_nom, { heal_dot_duration_turns: Math.max(1, v) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">tours de combat</span>
              </div>
            )}
            <label className="flex items-center gap-2 mt-1">
              <input
                type="checkbox"
                checked={rule.heal_dot_until_awake}
                onChange={(e) => handleHealDotUntilAwakeToggle(e.target.checked)}
                className="w-4 h-4"
              />
              <span className="text-ink-muted-2 text-xs">Continue jusqu'au réveil (tant que son utilisateur dort)</span>
            </label>
          </EffectSection>
        )}
        {rule.clear_damage_dot && (
          <EffectSection
            label="Purge des effets persistants (sur son utilisateur, coup réussi)"
            onRemove={() => onUpdate(rule.attack_nom, { clear_damage_dot: false })}
          >
            <p className="text-ink-muted-2 text-xs">
              Retire les trois effets persistants posés par une capacité et qu'il subit : dégâts persistants,
              vol de vie persistant et tentative de statut persistante. Ne touche ni aux statuts eux-mêmes
              (brûlure, poison — voir « Guérit son statut »), ni à la météo.
            </p>
          </EffectSection>
        )}
        {rule.cure_status && (
          <EffectSection
            label="Guérit son statut (n'importe lequel, sur un coup réussi)"
            onRemove={() => onUpdate(rule.attack_nom, { cure_status: false })}
          >
            <p className="text-ink-muted-2 text-xs">
              Le statut de son utilisateur est levé, quel qu'il soit — paralysie, sommeil, brûlure, poison…
            </p>
          </EffectSection>
        )}
        {rule.cancel_heal_duration_turns != null && (
          <EffectSection label="Anti-Soin (annule tous les soins adverses, sur un coup réussi)" onRemove={() => handleCancelHealToggle(false)}>
            <div className="flex items-center gap-2">
              <span className="text-ink-muted-2 text-xs">Pendant</span>
              <NumberInput
                min={1}
                fallback={rule.cancel_heal_duration_turns ?? 3}
                value={rule.cancel_heal_duration_turns ?? 3}
                onCommit={(v) => onUpdate(rule.attack_nom, { cancel_heal_duration_turns: Math.max(1, v) })}
                className={NUM_CLASS_SM}
              />
              <span className="text-ink-muted-2 text-xs">tours de combat</span>
            </div>
          </EffectSection>
        )}
      </EffectCategory>

      <EffectCategory label="Statistiques">
        {rule.stat_mod_target != null && (
          <EffectSection label="Modificateur de stat (bonus ou malus, sur un coup réussi)" onRemove={() => handleStatModTargetChange('')}>
            {/* Cible et sens sont indépendants : « sur son utilisateur » +
                « baisse » donne le malus qu'une capacité s'inflige à elle-même. */}
            <div className="flex items-center gap-2 flex-wrap">
              <select value={rule.stat_mod_target} onChange={(e) => handleStatModTargetChange(e.target.value)} className={SELECT_CLASS}>
                {(Object.keys(STAT_MOD_TARGET_LABEL) as AutoBattleStatModTarget[]).map((t) => (
                  <option key={t} value={t}>{STAT_MOD_TARGET_LABEL[t]}</option>
                ))}
              </select>
              <select
                value={rule.stat_mod_direction ?? (rule.stat_mod_target === 'opponent' ? 'debuff' : 'buff')}
                onChange={(e) => onUpdate(rule.attack_nom, { stat_mod_direction: e.target.value as AutoBattleStatModDirection })}
                className={SELECT_CLASS}
              >
                {(Object.keys(STAT_MOD_DIRECTION_LABEL) as AutoBattleStatModDirection[]).map((d) => (
                  <option key={d} value={d}>{STAT_MOD_DIRECTION_LABEL[d]}</option>
                ))}
              </select>
            </div>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-ink-muted-2 text-xs">Stat visée</span>
              <select
                value={rule.stat_mod_stat ?? 'damage'}
                onChange={(e) => handleStatModStatChange(e.target.value)}
                className={SELECT_CLASS}
              >
                {(Object.keys(STAT_MOD_STAT_LABEL) as AutoBattleStatModStat[]).map((s) => (
                  <option key={s} value={s}>{STAT_MOD_STAT_LABEL[s]}</option>
                ))}
              </select>
            </div>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-ink-muted-2 text-xs">Montant</span>
              <select
                value={rule.stat_mod_value_type ?? 'flat'}
                onChange={(e) => handleStatModValueTypeChange(e.target.value)}
                className={SELECT_CLASS}
              >
                {(Object.keys(STAT_MOD_VALUE_TYPE_LABEL) as AutoBattleStatModValueType[])
                  .filter((v) => v !== 'percent' || rule.stat_mod_stat === 'damage')
                  .map((v) => (
                    <option key={v} value={v}>{STAT_MOD_VALUE_TYPE_LABEL[v]}</option>
                  ))}
              </select>
            </div>
            {rule.stat_mod_value_type === 'flat' && (
              <div className="flex items-center gap-2 mt-1">
                <NumberInput
                  min={1}
                  fallback={rule.stat_mod_flat ?? 3}
                  value={rule.stat_mod_flat ?? 3}
                  onCommit={(v) => onUpdate(rule.attack_nom, { stat_mod_flat: Math.max(1, v) })}
                  className={NUM_CLASS_MD}
                />
              </div>
            )}
            {rule.stat_mod_value_type === 'range' && (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">Entre</span>
                <NumberInput
                  min={1}
                  fallback={rule.stat_mod_min ?? 1}
                  value={rule.stat_mod_min ?? 1}
                  onCommit={(v) => onUpdate(rule.attack_nom, { stat_mod_min: Math.max(1, Math.min(v, rule.stat_mod_max ?? 5)) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">et</span>
                <NumberInput
                  min={1}
                  fallback={rule.stat_mod_max ?? 5}
                  value={rule.stat_mod_max ?? 5}
                  onCommit={(v) => onUpdate(rule.attack_nom, { stat_mod_max: Math.max(v, rule.stat_mod_min ?? 1) })}
                  className={NUM_CLASS_SM}
                />
              </div>
            )}
            {rule.stat_mod_value_type === 'percent' && (
              <div className="flex items-center gap-2 mt-1">
                <NumberInput
                  min={1}
                  fallback={rule.stat_mod_percent ?? 20}
                  value={rule.stat_mod_percent ?? 20}
                  onCommit={(v) => onUpdate(rule.attack_nom, { stat_mod_percent: Math.max(1, Math.min(100, v)) })}
                  className={NUM_CLASS_MD}
                />
                <span className="text-ink-muted-2 text-xs">% des dégâts de base (calculés en tout début de combat)</span>
              </div>
            )}
            <div className="flex items-center gap-2 mt-1">
              <span className="text-ink-muted-2 text-xs">Durée</span>
              <select
                value={rule.stat_mod_duration_type ?? 'turns'}
                onChange={(e) => handleStatModDurationTypeChange(e.target.value)}
                className={SELECT_CLASS}
              >
                {(Object.keys(STAT_MOD_DURATION_TYPE_LABEL) as AutoBattleStatModDurationType[]).map((d) => (
                  <option key={d} value={d}>{STAT_MOD_DURATION_TYPE_LABEL[d]}</option>
                ))}
              </select>
              {rule.stat_mod_duration_type === 'turns' && (
                <>
                  <NumberInput
                    min={1}
                    fallback={rule.stat_mod_duration_turns ?? 3}
                    value={rule.stat_mod_duration_turns ?? 3}
                    onCommit={(v) => onUpdate(rule.attack_nom, { stat_mod_duration_turns: Math.max(1, v) })}
                    className={NUM_CLASS_SM}
                  />
                  <span className="text-ink-muted-2 text-xs">tours de combat</span>
                </>
              )}
            </div>
            {(rule.stat_mod_stat ?? 'damage') === 'damage' && (
              <div className="flex items-center gap-2 mt-1">
                <span className="text-ink-muted-2 text-xs">Limiter au type</span>
                <select
                  value={rule.stat_mod_type_filter ?? ''}
                  onChange={(e) => onUpdate(rule.attack_nom, { stat_mod_type_filter: e.target.value === '' ? null : e.target.value })}
                  className={SELECT_CLASS}
                >
                  <option value="">Toutes les capacités</option>
                  {attackTypes.map((t) => <option key={t} value={t}>{t}</option>)}
                </select>
              </div>
            )}
            <div className="flex items-center gap-2 mt-1">
              <span className="text-ink-muted-2 text-xs">Limite d'usages réussis</span>
              <NumberInput
                min={1}
                fallback={rule.stat_mod_max_uses ?? 1}
                value={rule.stat_mod_max_uses ?? 0}
                onCommit={(v) => onUpdate(rule.attack_nom, { stat_mod_max_uses: v <= 0 ? null : v })}
                className={NUM_CLASS_SM}
              />
              <span className="text-ink-muted-2 text-xs">(0 = illimité)</span>
            </div>
            {/* Condition « météo en cours » : hors condition, la capacité se joue
                normalement mais n'applique aucun buff/debuff. Un seul select
                porte les quatre cas et écrit toujours le couple cohérent
                stat_mod_weather_condition + stat_mod_weather_id. */}
            <div className="flex items-center gap-2 mt-1">
              <span className="text-ink-muted-2 text-xs">Seulement par</span>
              <select
                value={rule.stat_mod_weather_condition === 'this' ? `w${rule.stat_mod_weather_id ?? ''}` : (rule.stat_mod_weather_condition ?? '')}
                onChange={(e) => {
                  const v = e.target.value
                  if (v === '') onUpdate(rule.attack_nom, { stat_mod_weather_condition: null, stat_mod_weather_id: null })
                  else if (v === 'any' || v === 'none') onUpdate(rule.attack_nom, { stat_mod_weather_condition: v, stat_mod_weather_id: null })
                  else onUpdate(rule.attack_nom, { stat_mod_weather_condition: 'this', stat_mod_weather_id: Number(v.slice(1)) })
                }}
                className={SELECT_CLASS}
              >
                <option value="">N'importe quel temps</option>
                <option value="any">N'importe quelle météo active</option>
                <option value="none">Aucune météo active</option>
                {weathers.map((w) => <option key={w.id} value={`w${w.id}`}>{w.nom}</option>)}
              </select>
            </div>
          </EffectSection>
        )}
      </EffectCategory>

      <EffectCategory label="Terrain">
        {rule.weather_id != null && (
          <EffectSection label="Déclenche une météo" onRemove={() => handleWeatherToggle(false)}>
            <div className="flex items-center gap-2 flex-wrap">
              <select
                value={rule.weather_id ?? ''}
                onChange={(e) => onUpdate(rule.attack_nom, { weather_id: e.target.value === '' ? null : Number(e.target.value) })}
                className={SELECT_CLASS}
              >
                {weathers.map((w) => <option key={w.id} value={w.id}>{w.nom}</option>)}
              </select>
              <NumberInput
                min={1}
                fallback={100}
                value={rule.weather_chance ?? 100}
                onCommit={(v) => onUpdate(rule.attack_nom, { weather_chance: Math.max(1, Math.min(100, v)) })}
                className={NUM_CLASS_SM}
              />
              <span className="text-ink-muted-2 text-xs">% de chances</span>
            </div>
            <span className="text-ink-muted-2 text-[11px] mt-1">
              À chaque utilisation qui a touché. Une météo déjà en cours est remplacée ; ses effets « à chaque
              tour » commencent au tour suivant.
            </span>
          </EffectSection>
        )}
        {rule.clear_weather && (
          <EffectSection
            label="Dissipe la météo en cours"
            onRemove={() => onUpdate(rule.attack_nom, { clear_weather: false })}
          >
            <p className="text-ink-muted-2 text-xs">
              Sur un coup réussi, la météo en cours (quelle qu'elle soit) disparaît — c'est un état de terrain
              partagé, elle cesse donc pour les deux camps.
            </p>
          </EffectSection>
        )}
      </EffectCategory>

      <EffectCategory label="Défense">
        {rule.invulnerable_next_turn && (
          <EffectSection label="Invulnérabilité au prochain tour adverse" onRemove={() => onUpdate(rule.attack_nom, { invulnerable_next_turn: false })}>
            <span className="text-ink-muted-2 text-xs">Rend son utilisateur invulnérable au prochain tour adverse (rate automatiquement).</span>
          </EffectSection>
        )}
        {rule.prevention_duration_turns != null && (
          <EffectSection label="Prévention (bloque les dégâts super efficaces)" onRemove={() => handlePreventionToggle(false)}>
            <div className="flex items-center gap-2">
              <span className="text-ink-muted-2 text-xs">Pendant</span>
              <NumberInput
                min={1}
                fallback={rule.prevention_duration_turns ?? 3}
                value={rule.prevention_duration_turns ?? 3}
                onCommit={(v) => onUpdate(rule.attack_nom, { prevention_duration_turns: Math.max(1, v) })}
                className={NUM_CLASS_SM}
              />
              <span className="text-ink-muted-2 text-xs">tours de combat</span>
            </div>
            <span className="text-ink-muted-2 text-[11px] mt-1">
              Les attaques adverses touchent toujours, mais perdent leur bonus de dégâts « super efficace ».
            </span>
          </EffectSection>
        )}
      </EffectCategory>

      {addableEffects.length > 0 && (
        <select
          value=""
          onChange={(e) => { if (e.target.value) handleAddEffect(e.target.value) }}
          className="bg-white border-2 border-dashed border-ink/40 rounded px-2 py-1.5 text-ink-muted-2 text-xs outline-none mt-1"
        >
          <option value="">+ Ajouter un effet spécial…</option>
          {[...groupedAddableEffects.entries()].map(([group, opts]) => (
            <optgroup key={group} label={group}>
              {opts.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
            </optgroup>
          ))}
        </select>
      )}

      {/* La capacité ne quitte plus la liste (tout le catalogue est affiché) :
          ce bouton efface simplement tous ses réglages d'un coup. */}
      {configured && (
        <div className="flex justify-end border-t-2 border-[#cfc7a8] pt-2 mt-1">
          <button
            onClick={() => onRemove(rule.attack_nom)}
            className={`flex items-center gap-1.5 text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}
          >
            <CloseIcon className="w-3 h-3" />
            Effacer tous les effets de cette capacité
          </button>
        </div>
      )}
      </>
      )}
    </div>
  )
}

// Effets spéciaux des capacités : rythme des tours (passe son tour / joue
// plusieurs fois de suite) et/ou soin (montant fixe, % des dégâts infligés,
// ou dérivé des propres stats de la capacité) — gérés librement par l'admin,
// s'appliquent aussi bien au choix du joueur qu'à la capacité configurée
// pour l'adversaire (voir supabase/schema.sql autobattle_resolve_battle).
export function AdminAutoBattleAbilityRulesPanel() {
  const { rules, loading: rulesLoading, addRule, updateRule, removeRule } = useAutoBattleAbilityRules()
  const { attacks, loading: attacksLoading } = useAttacks()
  const { weathers, loading: weathersLoading } = useAutoBattleWeathers()

  const sortedWeathers = useMemo(
    () => [...weathers].sort((a, b) => a.nom.localeCompare(b.nom, 'fr')),
    [weathers]
  )

  const attacksByName = useMemo(() => {
    const map = new Map<string, Attack>()
    for (const a of attacks) map.set(a.nom, a)
    return map
  }, [attacks])

  // Types élémentaires réellement utilisés par le catalogue d'attaques — le
  // filtre de type du modificateur de stat est comparé côté SQL à
  // attacks.type, c'est donc la seule liste qui garantisse une correspondance
  // (TYPE_COLORS contient en plus des alias orthographiques).
  const attackTypes = useMemo(
    () => [...new Set(attacks.map((a) => a.type).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'fr')),
    [attacks]
  )

  const rulesByName = useMemo(() => {
    const map = new Map<string, AutoBattleAbilityRule>()
    for (const r of rules) map.set(r.attack_nom, r)
    return map
  }, [rules])

  const [sortMode, setSortMode] = useState<'name' | 'type'>('name')
  const [onlyMissing, setOnlyMissing] = useState(false)

  // TOUT le catalogue d'attaques est listé, configuré ou non : une capacité
  // sans ligne en base s'affiche sur une règle vide et n'est réellement créée
  // qu'au premier réglage (voir handleUpdate). S'y ajoutent les éventuelles
  // règles orphelines (capacité disparue du CSV depuis) pour pouvoir les
  // nettoyer, elles ne disparaissent donc pas de l'écran.
  const rows = useMemo(() => {
    const list: AbilityRow[] = attacks.map((attack) => {
      const rule = rulesByName.get(attack.nom)
      const effectiveRule = rule ?? emptyRule(attack.nom)
      return {
        nom: attack.nom,
        attack,
        rule: effectiveRule,
        configured: rule != null,
        // « Effet manquant » = le CSV décrit un effet spécial (colonne
        // « Effet ») alors qu'aucun réglage ne le traduit ici et que la
        // capacité n'a pas non plus de statut mini-jeu venu du CSV (auquel cas
        // la description est déjà couverte). Description vide = capacité sans
        // effet spécial prévu : rien à signaler.
        missingEffect: (attack.effet ?? '').trim() !== '' && attack.status_effect == null && !hasAnyEffect(effectiveRule),
      }
    })
    for (const rule of rules) {
      if (!attacksByName.has(rule.attack_nom)) {
        list.push({ nom: rule.attack_nom, attack: undefined, rule, configured: true, missingEffect: false })
      }
    }
    if (sortMode === 'name') {
      list.sort((a, b) => a.nom.localeCompare(b.nom, 'fr'))
    } else {
      list.sort((a, b) => {
        const cmp = (a.attack?.type ?? '').localeCompare(b.attack?.type ?? '', 'fr')
        return cmp !== 0 ? cmp : a.nom.localeCompare(b.nom, 'fr')
      })
    }
    return list
  }, [attacks, rules, rulesByName, attacksByName, sortMode])

  const missingCount = useMemo(() => rows.filter((r) => r.missingEffect).length, [rows])

  // La ligne en base n'est créée qu'au premier réglage réellement posé : tant
  // qu'on ne fait que parcourir ou déplier la liste (qui contient maintenant
  // tout le catalogue), rien n'est écrit. Le ref évite un second INSERT si
  // deux réglages partent avant que l'état `rules` ne soit rafraîchi.
  const createdRef = useRef(new Set<string>())
  const handleUpdate = useCallback(async (attackNom: string, patch: Partial<Omit<AutoBattleAbilityRule, 'attack_nom' | 'created_at'>>) => {
    if (!rulesByName.has(attackNom) && !createdRef.current.has(attackNom)) {
      createdRef.current.add(attackNom)
      await addRule(attackNom)
    }
    await updateRule(attackNom, patch)
  }, [rulesByName, addRule, updateRule])

  const handleRemove = useCallback((attackNom: string) => {
    // La ligne redevient « non configurée » : il faudra la recréer au prochain
    // réglage, sinon l'UPDATE porterait sur une ligne inexistante.
    createdRef.current.delete(attackNom)
    void removeRule(attackNom)
  }, [removeRule])

  // Sélectionner une capacité dans la recherche sert à la RETROUVER : on
  // retrouve sa ligne après le tri et on scrolle jusqu'à elle, avec un bref
  // halo pour la repérer facilement.
  const rowRefs = useRef(new Map<string, HTMLDivElement>())
  // Callback ref stable (pas recréée à chaque rendu) : lit le nom de la
  // capacité depuis data-attack-nom plutôt que de fermer sur `rule` dans le
  // .map ci-dessous, pour rester conforme à react-hooks/refs (pas de lecture
  // de ref pendant le rendu).
  const setRowRef = useCallback((el: HTMLDivElement | null) => {
    if (!el) return
    const nom = el.dataset.attackNom
    if (nom) rowRefs.current.set(nom, el)
  }, [])
  const [revealedNom, setRevealedNom] = useState<string | null>(null)
  // Lignes dépliées (repliées par défaut) — l'ajout et la recherche déplient
  // automatiquement la ligne concernée.
  const [expanded, setExpanded] = useState<Set<string>>(new Set())
  // Sous filtre « à configurer », une ligne DÉPLIÉE reste visible même une fois
  // son premier effet posé : sinon la carte disparaîtrait sous les doigts au
  // moment précis où on commence à la régler. Elle quitte la liste au repli.
  const visibleRows = useMemo(
    () => (onlyMissing ? rows.filter((r) => r.missingEffect || expanded.has(r.nom)) : rows),
    [rows, onlyMissing, expanded]
  )

  const toggleExpanded = useCallback((nom: string) => {
    setExpanded((prev) => {
      const next = new Set(prev)
      if (next.has(nom)) next.delete(nom)
      else next.add(nom)
      return next
    })
  }, [])

  /** Sélection depuis la barre de recherche : déplie la capacité et défile jusqu'à elle. */
  const handleSelectAttack = (attackNom: string) => {
    // Le filtre « à configurer » masquerait la ligne cherchée : on le lève.
    setOnlyMissing(false)
    setExpanded((prev) => new Set(prev).add(attackNom))
    setRevealedNom(attackNom)
  }

  useEffect(() => {
    if (!revealedNom) return
    const el = rowRefs.current.get(revealedNom)
    if (!el) return
    el.scrollIntoView({ behavior: 'smooth', block: 'center' })
    const timeout = window.setTimeout(() => setRevealedNom(null), 1500)
    return () => window.clearTimeout(timeout)
  }, [revealedNom, visibleRows])

  if (rulesLoading || attacksLoading || weathersLoading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">✨</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Effets spéciaux des capacités</h3>
      </div>
      <p className="text-ink-muted-2 text-sm mb-3">
        S'appliquent que la capacité soit choisie par un joueur ou configurée pour un opposant.
        Toutes les capacités du catalogue sont listées : déplie celle que tu veux régler, ou passe par la
        recherche pour défiler directement jusqu'à elle.
      </p>

      <MoveSearchInput options={attacks} disabled={false} showDamage onSelect={(a) => handleSelectAttack(a.nom)} />

      {/* Indicateur de travail restant : les capacités dont le CSV décrit un
          effet spécial sans qu'aucun réglage ne le traduise encore. */}
      {missingCount > 0 ? (
        <div className="flex items-center gap-2 flex-wrap mt-3 p-2 rounded border-2 border-[#c0392b] bg-[#fdecea]">
          <span className="text-[#c0392b] text-sm font-bold">
            ⚠ {missingCount} capacité{missingCount > 1 ? 's' : ''} sans effet configuré
          </span>
          <span className="text-ink-muted-2 text-xs flex-1">
            (le CSV leur décrit un effet, mais rien n'est réglé ici)
          </span>
          <button
            onClick={() => setOnlyMissing((v) => !v)}
            className={`text-xs px-2.5 py-1 rounded font-bold ${onlyMissing ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
          >
            {onlyMissing ? 'Tout afficher' : 'Voir uniquement celles-ci'}
          </button>
        </div>
      ) : (
        <p className="text-ink-muted-2 text-xs mt-3">
          Toutes les capacités décrites dans le CSV ont un effet configuré.
        </p>
      )}

      {rows.length > 1 && (
        <div className="flex items-center gap-2 mt-3">
          <span className="text-ink-muted-2 text-xs">Trier par</span>
          <button
            onClick={() => setSortMode('name')}
            className={`text-xs px-2.5 py-1 rounded font-bold ${sortMode === 'name' ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
          >
            Alphabétique
          </button>
          <button
            onClick={() => setSortMode('type')}
            className={`text-xs px-2.5 py-1 rounded font-bold ${sortMode === 'type' ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
          >
            Type
          </button>
        </div>
      )}

      <div className="flex flex-col gap-2 mt-4">
        {visibleRows.length === 0 ? (
          <p className="text-ink-muted-2 text-sm italic">
            {rows.length === 0 ? 'Aucune capacité dans le catalogue.' : 'Aucune capacité à configurer.'}
          </p>
        ) : (
          visibleRows.map((row) => (
            <AbilityRuleRow
              key={row.nom}
              rule={row.rule}
              attack={row.attack}
              configured={row.configured}
              missingEffect={row.missingEffect}
              attackTypes={attackTypes}
              weathers={sortedWeathers}
              onUpdate={(nom, patch) => void handleUpdate(nom, patch)}
              onRemove={handleRemove}
              rowRef={setRowRef}
              highlighted={row.nom === revealedNom}
              expanded={expanded.has(row.nom)}
              onToggle={() => toggleExpanded(row.nom)}
            />
          ))
        )}
      </div>

      <MoveSearchInput options={attacks} disabled={false} showDamage onSelect={(a) => handleSelectAttack(a.nom)} className="mt-4" />
    </div>
  )
}
