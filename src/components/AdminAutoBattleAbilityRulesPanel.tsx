import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type {
  Attack, AutoBattleAbilityRule, AutoBattleTurnEffect, AutoBattleHealType, AutoBattleHealDotType,
  AutoBattleRecoilType, AutoBattleBonusDamageType, AutoBattleBonusDamageCondition,
  AutoBattleStatModTarget, AutoBattleStatModStat, AutoBattleStatModValueType, AutoBattleStatModDurationType,
  AutoBattleStatusEffect, AutoBattleKeepGoingBonusType, AutoBattleIgnoreStatusBlock,
} from '../types'
import { useAutoBattleAbilityRules } from '../hooks/useAutoBattleAbilityRules'
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
}

const STAT_MOD_TARGET_LABEL: Record<AutoBattleStatModTarget, string> = {
  opponent: "Baisse une stat de l'adversaire",
  self: 'Augmente une stat de son utilisateur',
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

// Un effet actif est affiché dans une carte avec son propre bouton de
// retrait — les effets inactifs ne s'affichent nulle part par défaut, ils
// n'apparaissent que dans le menu "+ Ajouter un effet spécial" en bas de
// carte (voir INACTIVE_EFFECT_DEFS dans AbilityRuleRow). Ça évite d'avoir 11
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
  rule, attack, attackTypes, onUpdate, onRemove, rowRef, highlighted, expanded, onToggle,
}: {
  rule: AutoBattleAbilityRule
  attack: Attack | undefined
  /** Types élémentaires réellement présents dans le catalogue d'attaques — seule source fiable pour le filtre de type du modificateur de stat, qui est comparé côté SQL à attacks.type. */
  attackTypes: string[]
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
      onUpdate(rule.attack_nom, { bonus_damage_condition: 'dice_equals', bonus_damage_condition_dice_value: rule.bonus_damage_condition_dice_value ?? 6, bonus_damage_status_filter: null })
    } else if (value === 'has_status' || value === 'self_has_status') {
      // Les deux conditions de statut partagent bonus_damage_status_filter :
      // passer de l'une à l'autre garde le statut déjà choisi.
      onUpdate(rule.attack_nom, { bonus_damage_condition: value, bonus_damage_condition_dice_value: null })
    } else {
      onUpdate(rule.attack_nom, { bonus_damage_condition: value as AutoBattleBonusDamageCondition, bonus_damage_condition_dice_value: null, bonus_damage_status_filter: null })
    }
  }

  const handleBonusStatusFilterChange = (value: string) => {
    onUpdate(rule.attack_nom, { bonus_damage_status_filter: value === '' ? null : (value as AutoBattleStatusEffect) })
  }

  const handleStatModTargetChange = (value: string) => {
    if (value === '') {
      onUpdate(rule.attack_nom, {
        stat_mod_target: null, stat_mod_stat: null, stat_mod_value_type: null,
        stat_mod_flat: null, stat_mod_min: null, stat_mod_max: null, stat_mod_percent: null,
        stat_mod_duration_type: null, stat_mod_duration_turns: null, stat_mod_max_uses: null,
      })
      return
    }
    onUpdate(rule.attack_nom, {
      stat_mod_target: value as AutoBattleStatModTarget,
      stat_mod_stat: rule.stat_mod_stat ?? 'damage',
      stat_mod_value_type: rule.stat_mod_value_type ?? 'flat',
      stat_mod_flat: rule.stat_mod_flat ?? 3,
      stat_mod_duration_type: rule.stat_mod_duration_type ?? 'turns',
      stat_mod_duration_turns: rule.stat_mod_duration_turns ?? 3,
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
    onUpdate(rule.attack_nom, { percent_hp_damage_percent: enabled ? (rule.percent_hp_damage_percent ?? 50) : null })
  }

  // L'effet est actif dès qu'il a une durée, QUELLE QU'ELLE SOIT : un nombre
  // de tours, ou "jusqu'au réveil" (auquel cas heal_dot_duration_turns est
  // justement nul — ne tester que cette colonne faisait disparaître toute la
  // carte de réglages dès qu'on cochait la case, en donnant l'impression que
  // la configuration avait été effacée).
  const isHealDotActive = rule.heal_dot_duration_turns != null || rule.heal_dot_until_awake
  // Même raisonnement pour la chaîne "Continue sur sa lancée" : en mode
  // "jusqu'au premier raté", keep_going_turns est nul par construction.
  const isKeepGoingActive = rule.keep_going_turns != null || rule.keep_going_until_fail
  const healDotType = rule.heal_dot_type ?? 'flat'

  // Effets inactifs proposés dans le menu "+ Ajouter un effet spécial" en bas
  // de carte, groupés par thème (mêmes groupes que EffectCategory ci-dessus).
  // Un effet retiré de sa carte réapparaît automatiquement ici.
  const addableEffects: { value: string; label: string; group: string }[] = []
  if (rule.turn_effect == null) addableEffects.push({ value: 'turn', label: 'Effet sur les tours', group: 'Rythme des tours' })
  if (rule.percent_hp_damage_percent == null) addableEffects.push({ value: 'percenthp', label: 'Dégâts en % des PV restants', group: 'Dégâts' })
  if (rule.bonus_damage_type == null) addableEffects.push({ value: 'bonus', label: 'Dégâts additionnels conditionnels', group: 'Dégâts' })
  if (rule.recoil_type == null) addableEffects.push({ value: 'recoil', label: 'Contre-coup', group: 'Dégâts' })
  if (rule.heal_type == null) addableEffects.push({ value: 'heal', label: 'Soin instantané', group: 'Soins' })
  if (!isHealDotActive) addableEffects.push({ value: 'healdot', label: 'Soin passif (heal over time)', group: 'Soins' })
  if (rule.cancel_heal_duration_turns == null) addableEffects.push({ value: 'cancelheal', label: 'Anti-Soin', group: 'Soins' })
  if (!isKeepGoingActive) addableEffects.push({ value: 'keepgoing', label: 'Continue sur sa lancée (rejeu automatique)', group: 'Rythme des tours' })
  if (rule.ignore_status_block == null) addableEffects.push({ value: 'ignorestatus', label: 'Utilisable malgré un statut bloquant', group: 'Rythme des tours' })
  if (rule.stat_mod_target == null) addableEffects.push({ value: 'statmod', label: 'Modificateur de stat', group: 'Statistiques' })
  if (!rule.invulnerable_next_turn) addableEffects.push({ value: 'invuln', label: 'Invulnérabilité au prochain tour adverse', group: 'Défense' })
  if (rule.prevention_duration_turns == null) addableEffects.push({ value: 'prevention', label: 'Prévention (bloque les dégâts super efficaces)', group: 'Défense' })

  const groupedAddableEffects = new Map<string, typeof addableEffects>()
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
    }
  }

  return (
    <div
      ref={rowRef}
      data-attack-nom={rule.attack_nom}
      className={`flex flex-col gap-2 p-3 rounded ${PIXEL_BORDER_SM} bg-white transition-shadow duration-500 ${highlighted ? 'ring-4 ring-[#f0c419]' : ''}`}
    >
      {/* Vue repliée : type + nom, rien d'autre. Toute la ligne est cliquable
          pour déplier ; la suppression n'est offerte qu'une fois dépliée, pour
          ne pas risquer un clic malheureux en parcourant la liste. */}
      <button
        type="button"
        onClick={onToggle}
        className="flex items-center gap-2 text-left w-full"
        aria-expanded={expanded}
      >
        <span className="text-ink-muted-2 text-xs w-3 shrink-0">{expanded ? '▾' : '▸'}</span>
        <TypeBadge type={attack?.type ?? '?'} small />
        <span className="text-ink text-sm font-bold flex-1 truncate">{rule.attack_nom}</span>
      </button>

      {!expanded ? null : (
      <>
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
      </EffectCategory>

      <EffectCategory label="Dégâts">
        {rule.percent_hp_damage_percent != null && (
          <EffectSection label="Dégâts en % des PV restants (remplace les dégâts habituels)" onRemove={() => handlePercentHpDamageToggle(false)}>
            <div className="flex items-center gap-2">
              <span className="text-ink-muted-2 text-xs">Inflige</span>
              <NumberInput
                min={1}
                fallback={rule.percent_hp_damage_percent ?? 50}
                value={rule.percent_hp_damage_percent ?? 50}
                onCommit={(v) => onUpdate(rule.attack_nom, { percent_hp_damage_percent: Math.max(1, Math.min(100, v)) })}
                className={NUM_CLASS_SM}
              />
              <span className="text-ink-muted-2 text-xs">% des PV restants de la cible</span>
            </div>
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
          <EffectSection label="Modificateur de stat (baisse adverse ou hausse sur soi, sur un coup réussi)" onRemove={() => handleStatModTargetChange('')}>
            <select value={rule.stat_mod_target} onChange={(e) => handleStatModTargetChange(e.target.value)} className={SELECT_CLASS}>
              {(Object.keys(STAT_MOD_TARGET_LABEL) as AutoBattleStatModTarget[]).map((t) => (
                <option key={t} value={t}>{STAT_MOD_TARGET_LABEL[t]}</option>
              ))}
            </select>
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

      <div className="flex justify-end border-t-2 border-[#cfc7a8] pt-2 mt-1">
        <button
          onClick={() => onRemove(rule.attack_nom)}
          className={`flex items-center gap-1.5 text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}
        >
          <CloseIcon className="w-3 h-3" />
          Retirer cette capacité
        </button>
      </div>
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

  // La recherche porte sur TOUT le catalogue, y compris les capacités déjà
  // configurées : sélectionner une capacité déjà présente sert à la RETROUVER
  // (on déplie sa ligne et on scrolle jusqu'à elle) plutôt qu'à la recréer.
  const configuredNames = useMemo(() => new Set(rules.map((r) => r.attack_nom)), [rules])

  const [sortMode, setSortMode] = useState<'name' | 'type'>('name')
  const sortedRules = useMemo(() => {
    const list = [...rules]
    if (sortMode === 'name') {
      list.sort((a, b) => a.attack_nom.localeCompare(b.attack_nom, 'fr'))
    } else {
      list.sort((a, b) => {
        const typeA = attacksByName.get(a.attack_nom)?.type ?? ''
        const typeB = attacksByName.get(b.attack_nom)?.type ?? ''
        const cmp = typeA.localeCompare(typeB, 'fr')
        return cmp !== 0 ? cmp : a.attack_nom.localeCompare(b.attack_nom, 'fr')
      })
    }
    return list
  }, [rules, sortMode, attacksByName])

  // Ajouter une capacité l'insère quelque part dans la liste triée (pas
  // forcément en fin de liste) : on la retrouve après le tri et on scrolle
  // jusqu'à elle, avec un bref halo pour la repérer facilement.
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
  const [justAddedNom, setJustAddedNom] = useState<string | null>(null)
  // Lignes dépliées (repliées par défaut) — l'ajout et la recherche déplient
  // automatiquement la ligne concernée.
  const [expanded, setExpanded] = useState<Set<string>>(new Set())
  const toggleExpanded = useCallback((nom: string) => {
    setExpanded((prev) => {
      const next = new Set(prev)
      if (next.has(nom)) next.delete(nom)
      else next.add(nom)
      return next
    })
  }, [])

  /** Sélection depuis la barre de recherche : crée la règle si besoin, puis la révèle. */
  const handleSelectAttack = async (attackNom: string) => {
    if (!configuredNames.has(attackNom)) await addRule(attackNom)
    setExpanded((prev) => new Set(prev).add(attackNom))
    setJustAddedNom(attackNom)
  }

  useEffect(() => {
    if (!justAddedNom) return
    const el = rowRefs.current.get(justAddedNom)
    if (!el) return
    el.scrollIntoView({ behavior: 'smooth', block: 'center' })
    const timeout = window.setTimeout(() => setJustAddedNom(null), 1500)
    return () => window.clearTimeout(timeout)
  }, [justAddedNom, sortedRules])

  if (rulesLoading || attacksLoading) {
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
        La recherche sert aussi à retrouver une capacité déjà configurée : elle se déplie et défile jusqu'à toi.
      </p>

      <MoveSearchInput options={attacks} disabled={false} showDamage onSelect={(a) => void handleSelectAttack(a.nom)} />

      {rules.length > 1 && (
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
        {sortedRules.length === 0 ? (
          <p className="text-ink-muted-2 text-sm italic">Aucun effet spécial configuré pour l'instant.</p>
        ) : (
          sortedRules.map((rule) => (
            <AbilityRuleRow
              key={rule.attack_nom}
              rule={rule}
              attack={attacksByName.get(rule.attack_nom)}
              attackTypes={attackTypes}
              onUpdate={updateRule}
              onRemove={removeRule}
              rowRef={setRowRef}
              highlighted={rule.attack_nom === justAddedNom}
              expanded={expanded.has(rule.attack_nom)}
              onToggle={() => toggleExpanded(rule.attack_nom)}
            />
          ))
        )}
      </div>

      <MoveSearchInput options={attacks} disabled={false} showDamage onSelect={(a) => void handleSelectAttack(a.nom)} className="mt-4" />
    </div>
  )
}
