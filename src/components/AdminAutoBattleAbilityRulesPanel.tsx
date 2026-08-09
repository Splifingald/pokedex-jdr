import { useMemo } from 'react'
import type { Attack, AutoBattleAbilityRule, AutoBattleTurnEffect, AutoBattleHealType } from '../types'
import { useAutoBattleAbilityRules } from '../hooks/useAutoBattleAbilityRules'
import { useAttacks } from '../hooks/useAttacks'
import { MoveSearchInput } from './MoveSearchInput'
import { NumberInput } from './NumberInput'
import { TypeBadge } from './TypeBadge'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { CloseIcon } from './icons/CloseIcon'

const TURN_EFFECT_LABEL: Record<AutoBattleTurnEffect, string> = {
  skip: 'Passe son tour',
  play_twice: 'Joue deux fois',
  play_three: 'Joue trois fois',
  play_random: 'Nombre aléatoire de fois',
  repeat_until_fail: "Répète jusqu'à l'échec",
}

const HEAL_TYPE_LABEL: Record<AutoBattleHealType, string> = {
  static: 'Montant fixe',
  percent_damage: '% des dégâts infligés',
  use_stats: 'Utilise ses propres stats (dégâts + dé)',
}

function AbilityRuleRow({
  rule, attack, onUpdate, onRemove,
}: {
  rule: AutoBattleAbilityRule
  attack: Attack | undefined
  onUpdate: (attackNom: string, patch: Partial<Omit<AutoBattleAbilityRule, 'attack_nom' | 'created_at'>>) => void
  onRemove: (attackNom: string) => void
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

  return (
    <div className={`flex flex-col gap-2 p-3 rounded ${PIXEL_BORDER_SM} bg-white`}>
      <div className="flex items-center gap-2">
        <TypeBadge type={attack?.type ?? '?'} small />
        <span className="text-ink text-sm font-bold flex-1 truncate">{rule.attack_nom}</span>
        <button onClick={() => onRemove(rule.attack_nom)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
          <CloseIcon className="w-3 h-3" />
        </button>
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-ink-muted-2 text-xs">Effet sur les tours</label>
        <select
          value={rule.turn_effect ?? ''}
          onChange={(e) => handleTurnEffectChange(e.target.value)}
          className="bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none"
        >
          <option value="">Aucun</option>
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
              className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
            />
            <span className="text-ink-muted-2 text-xs">et</span>
            <NumberInput
              min={1}
              fallback={rule.turn_random_max ?? 4}
              value={rule.turn_random_max ?? 4}
              onCommit={(v) => onUpdate(rule.attack_nom, { turn_random_max: Math.max(v, rule.turn_random_min ?? 1) })}
              className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
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
              className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
            />
            <span className="text-ink-muted-2 text-xs">répétitions</span>
          </div>
        )}
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-ink-muted-2 text-xs">Effet de soin (sur son utilisateur, après les dégâts)</label>
        <select
          value={rule.heal_type ?? ''}
          onChange={(e) => handleHealTypeChange(e.target.value)}
          className="bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none"
        >
          <option value="">Aucun</option>
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
              className="w-16 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
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
              className="w-16 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
            />
            <span className="text-ink-muted-2 text-xs">%</span>
          </div>
        )}
      </div>
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

  const configuredNames = useMemo(() => new Set(rules.map((r) => r.attack_nom)), [rules])
  const selectableAttacks = useMemo(() => attacks.filter((a) => !configuredNames.has(a.nom)), [attacks, configuredNames])

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
      </p>

      <MoveSearchInput options={selectableAttacks} disabled={false} showDamage onSelect={(a) => addRule(a.nom)} />

      <div className="flex flex-col gap-2 mt-4">
        {rules.length === 0 ? (
          <p className="text-ink-muted-2 text-sm italic">Aucun effet spécial configuré pour l'instant.</p>
        ) : (
          rules.map((rule) => (
            <AbilityRuleRow key={rule.attack_nom} rule={rule} attack={attacksByName.get(rule.attack_nom)} onUpdate={updateRule} onRemove={removeRule} />
          ))
        )}
      </div>
    </div>
  )
}
