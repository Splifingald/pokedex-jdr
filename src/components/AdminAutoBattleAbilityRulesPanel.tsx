import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type {
  Attack, AutoBattleAbilityRule, AutoBattleTurnEffect, AutoBattleHealType,
  AutoBattleRecoilType, AutoBattleBonusDamageType, AutoBattleBonusDamageCondition,
} from '../types'
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
  prepare_release: 'Prépare puis libère (2 tours)',
}

const HEAL_TYPE_LABEL: Record<AutoBattleHealType, string> = {
  static: 'Montant fixe',
  percent_damage: '% des dégâts infligés',
  use_stats: 'Utilise ses propres stats (dégâts + dé)',
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
  has_status: 'Le pokémon est actuellement affecté par un statut',
}

function AbilityRuleRow({
  rule, attack, onUpdate, onRemove, rowRef, highlighted,
}: {
  rule: AutoBattleAbilityRule
  attack: Attack | undefined
  onUpdate: (attackNom: string, patch: Partial<Omit<AutoBattleAbilityRule, 'attack_nom' | 'created_at'>>) => void
  onRemove: (attackNom: string) => void
  rowRef?: (el: HTMLDivElement | null) => void
  highlighted?: boolean
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
      onUpdate(rule.attack_nom, { bonus_damage_condition: 'dice_equals', bonus_damage_condition_dice_value: rule.bonus_damage_condition_dice_value ?? 6 })
    } else {
      onUpdate(rule.attack_nom, { bonus_damage_condition: value as AutoBattleBonusDamageCondition, bonus_damage_condition_dice_value: null })
    }
  }

  return (
    <div
      ref={rowRef}
      data-attack-nom={rule.attack_nom}
      className={`flex flex-col gap-2 p-3 rounded ${PIXEL_BORDER_SM} bg-white transition-shadow duration-500 ${highlighted ? 'ring-4 ring-[#f0c419]' : ''}`}
    >
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

      <label className="flex items-center gap-2">
        <input
          type="checkbox"
          checked={rule.invulnerable_next_turn}
          onChange={(e) => onUpdate(rule.attack_nom, { invulnerable_next_turn: e.target.checked })}
          className="w-4 h-4"
        />
        <span className="text-ink-muted-2 text-xs">Rend invulnérable au prochain tour adverse (rate automatiquement)</span>
      </label>

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

      <div className="flex flex-col gap-1">
        <label className="text-ink-muted-2 text-xs">Contre-coup (dégâts sur son utilisateur, après le reste)</label>
        <select
          value={rule.recoil_type ?? ''}
          onChange={(e) => handleRecoilTypeChange(e.target.value)}
          className="bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none"
        >
          <option value="">Aucun</option>
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
              className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
            />
            <span className="text-ink-muted-2 text-xs">et</span>
            <NumberInput
              min={0}
              fallback={rule.recoil_max ?? 8}
              value={rule.recoil_max ?? 8}
              onCommit={(v) => onUpdate(rule.attack_nom, { recoil_max: Math.max(v, rule.recoil_min ?? 0) })}
              className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
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
              className="w-16 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
            />
            <span className="text-ink-muted-2 text-xs">%</span>
          </div>
        )}
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-ink-muted-2 text-xs">Dégâts additionnels conditionnels</label>
        <select
          value={rule.bonus_damage_type ?? ''}
          onChange={(e) => handleBonusTypeChange(e.target.value)}
          className="bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none"
        >
          <option value="">Aucun</option>
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
              className="w-16 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
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
              className="w-16 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
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
              className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
            />
            <span className="text-ink-muted-2 text-xs">et</span>
            <NumberInput
              min={1}
              fallback={rule.bonus_damage_max ?? 8}
              value={rule.bonus_damage_max ?? 8}
              onCommit={(v) => onUpdate(rule.attack_nom, { bonus_damage_max: Math.max(v, rule.bonus_damage_min ?? 1) })}
              className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
            />
          </div>
        )}
        {rule.bonus_damage_type && (
          <div className="flex flex-col gap-1 mt-1">
            <span className="text-ink-muted-2 text-xs">Condition</span>
            <select
              value={rule.bonus_damage_condition ?? ''}
              onChange={(e) => handleBonusConditionChange(e.target.value)}
              className="bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none"
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
                  className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
                />
              </div>
            )}
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

  const handleAddRule = async (attackNom: string) => {
    await addRule(attackNom)
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
      </p>

      <MoveSearchInput options={selectableAttacks} disabled={false} showDamage onSelect={(a) => void handleAddRule(a.nom)} />

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
              onUpdate={updateRule}
              onRemove={removeRule}
              rowRef={setRowRef}
              highlighted={rule.attack_nom === justAddedNom}
            />
          ))
        )}
      </div>

      <MoveSearchInput options={selectableAttacks} disabled={false} showDamage onSelect={(a) => void handleAddRule(a.nom)} className="mt-4" />
    </div>
  )
}
