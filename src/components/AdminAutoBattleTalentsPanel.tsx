import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type {
  AutoBattleStatusEffect, AutoBattleTalent, AutoBattleTalentHpCondition, AutoBattleTalentKind,
  AutoBattleTalentStat, AutoBattleTalentStatusCondition, AutoBattleTalentTrigger, AutoBattleTalentValueType,
  AutoBattleWeather, Pokemon,
} from '../types'
import { useAutoBattleTalents } from '../hooks/useAutoBattleTalents'
import { useAutoBattleWeathers } from '../hooks/useAutoBattleWeathers'
import { useAttacks } from '../hooks/useAttacks'
import { usePokemon } from '../hooks/usePokemon'
import { PokemonSearchInput } from './PokemonSearchInput'
import { NumberInput } from './NumberInput'
import { TypeBadge } from './TypeBadge'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { CloseIcon } from './icons/CloseIcon'
import { STATUS_EFFECT_LABEL, TALENT_KIND_LABEL, TALENT_TRIGGER_LABEL, describeTalent } from '../lib/autoBattle'
import { BATTLE_ANIMATION_IDS, getBattleAnimationLabel } from '../lib/battleAnimations'

// Mêmes constantes de style que AdminAutoBattleAbilityRulesPanel — les deux
// panneaux configurent la même famille d'effets (par capacité / par espèce) et
// doivent rester visuellement interchangeables.
const SELECT_CLASS = 'bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none'
const NUM_CLASS_SM = 'w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none'
const TEXT_CLASS = 'flex-1 min-w-0 bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none'

const STAT_LABEL: Record<AutoBattleTalentStat, string> = { damage: 'Dégâts', precision: 'Précision' }
const HP_CONDITION_LABEL: Record<AutoBattleTalentHpCondition, string> = {
  below: 'PV inférieurs ou égaux à',
  above: 'PV supérieurs ou égaux à',
}
const VALUE_TYPE_LABEL: Record<AutoBattleTalentValueType, string> = {
  flat: 'Montant fixe',
  percent_max_hp: '% des PV max',
  range: 'Fourchette aléatoire',
}
const ALL_STATUSES = Object.keys(STATUS_EFFECT_LABEL) as AutoBattleStatusEffect[]

/**
 * Champs de la ligne remis à NULL quand on change de `kind` : les contraintes
 * CHECK de la table rejettent une écriture partielle, chaque changement doit
 * donc envoyer un groupe de champs COHÉRENT (même convention que le panneau des
 * effets spéciaux de capacité).
 */
const BLANK: Omit<AutoBattleTalent, 'id' | 'pokemon_nom' | 'nom' | 'kind' | 'animation' | 'created_at'> = {
  stat: null,
  amount: null,
  amount_max: null,
  percent: null,
  value_type: null,
  type_filter: null,
  status_filter: null,
  hp_condition: null,
  hp_percent: null,
  opponent_status: null,
  self_status: null,
  require_damage_taken: false,
  trigger: null,
  dice_value: null,
  max_uses: null,
  weather_id: null,
  weather_condition: null,
  weather_condition_id: null,
}

/** Valeurs minimales acceptées par les contraintes, pour chaque kind. */
function defaultsFor(kind: AutoBattleTalentKind): Partial<AutoBattleTalent> {
  switch (kind) {
    case 'stat_boost': return { stat: 'damage', amount: 1 }
    case 'poison_damage_boost':
    case 'burn_damage_boost': return { amount: 2 }
    case 'priority': return { amount: 1 }
    case 'inflict_status': return { status_filter: ['poison'], percent: 30, trigger: 'each_turn' }
    case 'status_immunity': return { status_filter: ['poison'] }
    case 'type_immunity':
    case 'type_damage_to_heal': return { type_filter: [] }
    case 'dice_bonus_damage': return { dice_value: 1, amount: 5 }
    case 'heal_below_hp': return { hp_percent: 50, value_type: 'flat', amount: 10 }
    // weather_id reste null : c'est à l'admin de choisir la météo, et la
    // contrainte autobattle_talents_set_weather_fields ne l'exige pas (voir
    // schema.sql — une météo supprimée doit pouvoir vider la colonne).
    case 'set_weather': return { percent: 100, trigger: 'battle_start' }
    default: return {}
  }
}

interface RowProps {
  talent: AutoBattleTalent
  attackTypes: string[]
  weathers: AutoBattleWeather[]
  /** Noms des météos par id — le talent ne stocke qu'un id (voir describeTalent). */
  weatherNames: Map<number, string>
  highlighted: boolean
  rowRef: (el: HTMLDivElement | null) => void
  onUpdate: (id: number, patch: Partial<Omit<AutoBattleTalent, 'id' | 'created_at'>>) => void
  onRemove: (id: number) => void
}

function TalentRow({ talent, attackTypes, weathers, weatherNames, highlighted, rowRef, onUpdate, onRemove }: RowProps) {
  const patch = (p: Partial<Omit<AutoBattleTalent, 'id' | 'created_at'>>) => onUpdate(talent.id, p)

  const handleKindChange = (kind: AutoBattleTalentKind) => {
    patch({ ...BLANK, ...defaultsFor(kind), kind })
  }

  const toggleInList = (key: 'type_filter' | 'status_filter', value: string) => {
    const current = (talent[key] as string[] | null) ?? []
    const next = current.includes(value) ? current.filter((v) => v !== value) : [...current, value]
    patch({ [key]: next } as Partial<AutoBattleTalent>)
  }

  const statusCondSelect = (key: 'opponent_status' | 'self_status', label: string) => (
    <label className="flex items-center gap-2 flex-wrap">
      <span className="text-ink-muted-2 text-xs">{label}</span>
      <select
        value={talent[key] ?? ''}
        onChange={(e) => patch({ [key]: e.target.value === '' ? null : (e.target.value as AutoBattleTalentStatusCondition) } as Partial<AutoBattleTalent>)}
        className={SELECT_CLASS}
      >
        <option value="">Aucune condition</option>
        <option value="any">N'importe quel statut</option>
        {ALL_STATUSES.map((s) => <option key={s} value={s}>{STATUS_EFFECT_LABEL[s]}</option>)}
      </select>
    </label>
  )

  const typeChips = (emptyLabel: string) => (
    <div className="flex flex-col gap-1">
      <span className="text-ink-muted-2 text-xs">
        {(talent.type_filter?.length ?? 0) === 0 ? emptyLabel : 'Types sélectionnés'}
      </span>
      <div className="flex flex-wrap gap-1">
        {attackTypes.map((t) => {
          const on = talent.type_filter?.includes(t) ?? false
          return (
            <button
              key={t}
              type="button"
              onClick={() => toggleInList('type_filter', t)}
              className={`rounded transition-opacity ${on ? 'opacity-100' : 'opacity-35 hover:opacity-70'}`}
            >
              <TypeBadge type={t} small />
            </button>
          )
        })}
      </div>
    </div>
  )

  // Condition « météo en cours » d'un bonus de stat : un seul select porte les
  // quatre cas (aucune condition / n'importe laquelle / aucune météo / une météo
  // précise), et écrit toujours un groupe cohérent weather_condition +
  // weather_condition_id.
  const weatherCondSelect = () => (
    <label className="flex items-center gap-2 flex-wrap">
      <span className="text-ink-muted-2 text-xs">Météo</span>
      <select
        value={talent.weather_condition === 'this' ? `w${talent.weather_condition_id ?? ''}` : (talent.weather_condition ?? '')}
        onChange={(e) => {
          const v = e.target.value
          if (v === '') patch({ weather_condition: null, weather_condition_id: null })
          else if (v === 'any' || v === 'none') patch({ weather_condition: v, weather_condition_id: null })
          else patch({ weather_condition: 'this', weather_condition_id: Number(v.slice(1)) })
        }}
        className={SELECT_CLASS}
      >
        <option value="">Aucune condition</option>
        <option value="any">N'importe quelle météo</option>
        <option value="none">Aucune météo active</option>
        {weathers.map((w) => <option key={w.id} value={`w${w.id}`}>{w.nom}</option>)}
      </select>
    </label>
  )

  const statusChips = () => (
    <div className="flex flex-col gap-1">
      <span className="text-ink-muted-2 text-xs">Statuts concernés</span>
      <div className="flex flex-wrap gap-1">
        {ALL_STATUSES.map((s) => {
          const on = talent.status_filter?.includes(s) ?? false
          return (
            <button
              key={s}
              type="button"
              onClick={() => toggleInList('status_filter', s)}
              className={`px-2 py-1 rounded text-xs ${PIXEL_BORDER_SM} ${on ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
            >
              {STATUS_EFFECT_LABEL[s]}
            </button>
          )
        })}
      </div>
    </div>
  )

  return (
    <div
      ref={rowRef}
      data-talent-id={talent.id}
      className={`flex flex-col gap-2 p-3 rounded ${PIXEL_BORDER_SM} bg-white transition-shadow duration-500 ${highlighted ? 'ring-4 ring-[#f0c419]' : ''}`}
    >
      <div className="flex items-center gap-2">
        <input
          type="text"
          value={talent.nom}
          onChange={(e) => patch({ nom: e.target.value })}
          placeholder="Nom du talent"
          className={TEXT_CLASS}
        />
        <button onClick={() => onRemove(talent.id)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
          <CloseIcon className="w-3 h-3" />
        </button>
      </div>

      <div className="flex items-center gap-2 flex-wrap">
        <select value={talent.kind} onChange={(e) => handleKindChange(e.target.value as AutoBattleTalentKind)} className={SELECT_CLASS}>
          {(Object.keys(TALENT_KIND_LABEL) as AutoBattleTalentKind[]).map((k) => (
            <option key={k} value={k}>{TALENT_KIND_LABEL[k]}</option>
          ))}
        </select>
        <label className="flex items-center gap-2">
          <span className="text-ink-muted-2 text-xs">Animation</span>
          <select
            value={talent.animation ?? ''}
            onChange={(e) => patch({ animation: e.target.value === '' ? null : (e.target.value as AutoBattleTalent['animation']) })}
            className={SELECT_CLASS}
          >
            <option value="">Idle (par défaut)</option>
            {BATTLE_ANIMATION_IDS.map((a) => <option key={a} value={a}>{getBattleAnimationLabel(a)}</option>)}
          </select>
        </label>
      </div>

      {talent.kind === 'stat_boost' && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2 flex-wrap">
            <select
              value={talent.stat ?? 'damage'}
              onChange={(e) => patch({ stat: e.target.value as AutoBattleTalentStat })}
              className={SELECT_CLASS}
            >
              {(Object.keys(STAT_LABEL) as AutoBattleTalentStat[]).map((s) => (
                <option key={s} value={s}>{STAT_LABEL[s]}</option>
              ))}
            </select>
            <NumberInput value={talent.amount ?? 0} fallback={0} onCommit={(v) => patch({ amount: v })} className={NUM_CLASS_SM} />
            <span className="text-ink-muted-2 text-xs">(négatif = malus)</span>
          </div>
          {typeChips('Toutes les capacités')}
          <div className="flex items-center gap-2 flex-wrap">
            <select
              value={talent.hp_condition ?? ''}
              onChange={(e) => {
                const v = e.target.value as AutoBattleTalentHpCondition | ''
                patch(v === '' ? { hp_condition: null, hp_percent: null } : { hp_condition: v, hp_percent: talent.hp_percent ?? 50 })
              }}
              className={SELECT_CLASS}
            >
              <option value="">Sans condition de PV</option>
              {(Object.keys(HP_CONDITION_LABEL) as AutoBattleTalentHpCondition[]).map((c) => (
                <option key={c} value={c}>{HP_CONDITION_LABEL[c]}</option>
              ))}
            </select>
            {talent.hp_condition && (
              <>
                <NumberInput
                  min={1}
                  value={talent.hp_percent ?? 50}
                  fallback={50}
                  onCommit={(v) => patch({ hp_percent: Math.max(1, Math.min(100, v)) })}
                  className={NUM_CLASS_SM}
                />
                <span className="text-ink-muted-2 text-xs">% des PV max</span>
              </>
            )}
          </div>
          {statusCondSelect('opponent_status', 'Statut de l’adversaire')}
          {statusCondSelect('self_status', 'Son propre statut')}
          {weatherCondSelect()}
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={talent.require_damage_taken}
              // Le plafond n'a de sens que pour un bonus cumulatif : on le
              // remet à null en décochant (groupe de champs cohérent).
              onChange={(e) => patch({ require_damage_taken: e.target.checked, max_uses: e.target.checked ? talent.max_uses : null })}
              className="w-4 h-4"
            />
            <span className="text-ink-muted-2 text-xs">Cumulatif : le bonus s’ajoute à chaque coup direct encaissé (brûlure et poison exclus)</span>
          </label>
          {talent.require_damage_taken && (
            <div className="flex items-center gap-2 flex-wrap pl-6">
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={talent.max_uses != null}
                  onChange={(e) => patch({ max_uses: e.target.checked ? (talent.max_uses ?? 3) : null })}
                  className="w-4 h-4"
                />
                <span className="text-ink-muted-2 text-xs">Limiter le nombre de déclenchements</span>
              </label>
              {talent.max_uses != null && (
                <>
                  <NumberInput
                    min={1}
                    value={talent.max_uses}
                    fallback={3}
                    onCommit={(v) => patch({ max_uses: Math.max(1, v) })}
                    className={NUM_CLASS_SM}
                  />
                  <span className="text-ink-muted-2 text-xs">fois maximum</span>
                </>
              )}
            </div>
          )}
        </div>
      )}

      {(talent.kind === 'poison_damage_boost' || talent.kind === 'burn_damage_boost' || talent.kind === 'priority') && (
        <div className="flex items-center gap-2">
          <span className="text-ink-muted-2 text-xs">
            {talent.kind === 'priority' ? 'Priorité (0 = normale)' : 'Dégâts supplémentaires par tick'}
          </span>
          <NumberInput value={talent.amount ?? 0} fallback={0} onCommit={(v) => patch({ amount: v })} className={NUM_CLASS_SM} />
        </div>
      )}

      {talent.kind === 'inflict_status' && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2 flex-wrap">
            <select
              value={talent.status_filter?.[0] ?? 'poison'}
              onChange={(e) => patch({ status_filter: [e.target.value as AutoBattleStatusEffect] })}
              className={SELECT_CLASS}
            >
              {ALL_STATUSES.map((s) => <option key={s} value={s}>{STATUS_EFFECT_LABEL[s]}</option>)}
            </select>
            <NumberInput
              min={1}
              value={talent.percent ?? 30}
              fallback={30}
              onCommit={(v) => patch({ percent: Math.max(1, Math.min(100, v)) })}
              className={NUM_CLASS_SM}
            />
            <span className="text-ink-muted-2 text-xs">% de chances</span>
          </div>
          <select
            value={talent.trigger ?? 'each_turn'}
            onChange={(e) => {
              const trigger = e.target.value as AutoBattleTalentTrigger
              patch({ trigger, type_filter: trigger === 'on_ability_type' ? (talent.type_filter ?? []) : null })
            }}
            className={SELECT_CLASS}
          >
            {(Object.keys(TALENT_TRIGGER_LABEL) as AutoBattleTalentTrigger[]).map((t) => (
              <option key={t} value={t}>{TALENT_TRIGGER_LABEL[t]}</option>
            ))}
          </select>
          {talent.trigger === 'on_ability_type' && typeChips('Tous les types de capacité')}
        </div>
      )}

      {talent.kind === 'set_weather' && (
        <div className="flex flex-col gap-2">
          {weathers.length === 0 ? (
            <p className="text-ink-muted-2 text-xs italic">
              Aucune météo n’existe encore — crée-la dans l’onglet 🌦️ Météo.
            </p>
          ) : (
            <div className="flex items-center gap-2 flex-wrap">
              <select
                value={talent.weather_id ?? ''}
                onChange={(e) => patch({ weather_id: e.target.value === '' ? null : Number(e.target.value) })}
                className={SELECT_CLASS}
              >
                <option value="">Choisir une météo…</option>
                {weathers.map((w) => <option key={w.id} value={w.id}>{w.nom}</option>)}
              </select>
              <NumberInput
                min={1}
                value={talent.percent ?? 100}
                fallback={100}
                onCommit={(v) => patch({ percent: Math.max(1, Math.min(100, v)) })}
                className={NUM_CLASS_SM}
              />
              <span className="text-ink-muted-2 text-xs">% de chances</span>
            </div>
          )}
          <select
            value={talent.trigger ?? 'battle_start'}
            onChange={(e) => {
              const trigger = e.target.value as AutoBattleTalentTrigger
              patch({ trigger, type_filter: trigger === 'on_ability_type' ? (talent.type_filter ?? []) : null })
            }}
            className={SELECT_CLASS}
          >
            {(Object.keys(TALENT_TRIGGER_LABEL) as AutoBattleTalentTrigger[]).map((t) => (
              <option key={t} value={t}>{TALENT_TRIGGER_LABEL[t]}</option>
            ))}
          </select>
          {talent.trigger === 'on_ability_type' && typeChips('Tous les types de capacité')}
        </div>
      )}

      {talent.kind === 'status_immunity' && statusChips()}

      {(talent.kind === 'type_immunity' || talent.kind === 'type_damage_to_heal') && typeChips('Aucun type — talent sans effet')}

      {talent.kind === 'dice_bonus_damage' && (
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-ink-muted-2 text-xs">Quand le dé vaut</span>
          <NumberInput min={1} value={talent.dice_value ?? 1} fallback={1} onCommit={(v) => patch({ dice_value: Math.max(1, v) })} className={NUM_CLASS_SM} />
          <span className="text-ink-muted-2 text-xs">, dégâts</span>
          <NumberInput value={talent.amount ?? 0} fallback={0} onCommit={(v) => patch({ amount: v })} className={NUM_CLASS_SM} />
        </div>
      )}

      {talent.kind === 'heal_below_hp' && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="text-ink-muted-2 text-xs">Se déclenche sous</span>
            <NumberInput
              min={1}
              value={talent.hp_percent ?? 50}
              fallback={50}
              onCommit={(v) => patch({ hp_percent: Math.max(1, Math.min(100, v)) })}
              className={NUM_CLASS_SM}
            />
            <span className="text-ink-muted-2 text-xs">% des PV max</span>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <select
              value={talent.value_type ?? 'flat'}
              onChange={(e) => {
                const vt = e.target.value as AutoBattleTalentValueType
                // Groupe cohérent : voir autobattle_talents_heal_fields.
                if (vt === 'percent_max_hp') patch({ value_type: vt, percent: talent.percent ?? 25, amount: null, amount_max: null })
                else if (vt === 'range') patch({ value_type: vt, amount: talent.amount ?? 5, amount_max: talent.amount_max ?? 15, percent: null })
                else patch({ value_type: vt, amount: talent.amount ?? 10, amount_max: null, percent: null })
              }}
              className={SELECT_CLASS}
            >
              {(Object.keys(VALUE_TYPE_LABEL) as AutoBattleTalentValueType[]).map((v) => (
                <option key={v} value={v}>{VALUE_TYPE_LABEL[v]}</option>
              ))}
            </select>
            {talent.value_type === 'percent_max_hp' ? (
              <>
                <NumberInput min={1} value={talent.percent ?? 25} fallback={25} onCommit={(v) => patch({ percent: Math.max(1, Math.min(100, v)) })} className={NUM_CLASS_SM} />
                <span className="text-ink-muted-2 text-xs">%</span>
              </>
            ) : talent.value_type === 'range' ? (
              <>
                <NumberInput min={1} value={talent.amount ?? 5} fallback={5} onCommit={(v) => patch({ amount: Math.max(1, Math.min(v, talent.amount_max ?? v)) })} className={NUM_CLASS_SM} />
                <span className="text-ink-muted-2 text-xs">à</span>
                <NumberInput min={1} value={talent.amount_max ?? 15} fallback={15} onCommit={(v) => patch({ amount_max: Math.max(talent.amount ?? 1, v) })} className={NUM_CLASS_SM} />
                <span className="text-ink-muted-2 text-xs">PV</span>
              </>
            ) : (
              <>
                <NumberInput min={1} value={talent.amount ?? 10} fallback={10} onCommit={(v) => patch({ amount: Math.max(1, v) })} className={NUM_CLASS_SM} />
                <span className="text-ink-muted-2 text-xs">PV</span>
              </>
            )}
          </div>
        </div>
      )}

      <p className="text-ink-muted-2 text-xs italic">{describeTalent(talent, weatherNames)}</p>
    </div>
  )
}

export function AdminAutoBattleTalentsPanel() {
  const { talents, talentsByPokemon, loading, addTalent, updateTalent, removeTalent } = useAutoBattleTalents()
  const { weathers, weatherNames, loading: weathersLoading } = useAutoBattleWeathers()
  const { attacks, loading: attacksLoading } = useAttacks()
  const { pokemon, loading: pokemonLoading } = usePokemon()

  const pokemonByName = useMemo(() => new Map(pokemon.map((p) => [p.nom, p])), [pokemon])

  // Types réellement utilisés par le catalogue d'attaques — c'est à `attacks.type`
  // que le moteur compare les filtres, pas à une liste figée de types.
  const attackTypes = useMemo(
    () => [...new Set(attacks.map((a) => a.type).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'fr')),
    [attacks]
  )

  const sortedWeathers = useMemo(
    () => [...weathers].sort((a, b) => a.nom.localeCompare(b.nom, 'fr')),
    [weathers]
  )

  // Espèces dépliées (repliées par défaut) : une espèce repliée tient sur une
  // seule ligne — sprite, n° de dex, nom, et le résumé de ses talents à droite.
  const [expanded, setExpanded] = useState<Set<string>>(new Set())
  const toggleExpanded = useCallback((nom: string) => {
    setExpanded((prev) => {
      const next = new Set(prev)
      if (next.has(nom)) next.delete(nom)
      else next.add(nom)
      return next
    })
  }, [])

  const [sortMode, setSortMode] = useState<'name' | 'numero'>('name')
  const sortedSpecies = useMemo(() => {
    const noms = [...talentsByPokemon.keys()]
    return noms.sort((a, b) => {
      if (sortMode === 'numero') {
        const na = pokemonByName.get(a)?.numero ?? ''
        const nb = pokemonByName.get(b)?.numero ?? ''
        const cmp = na.localeCompare(nb, 'fr', { numeric: true })
        if (cmp !== 0) return cmp
      }
      return a.localeCompare(b, 'fr')
    })
  }, [talentsByPokemon, sortMode, pokemonByName])

  // Scroll + surbrillance de la ligne fraîchement ajoutée (même mécanique que
  // AdminAutoBattleAbilityRulesPanel : ref par callback lisant data-talent-id,
  // stable d'un rendu à l'autre).
  const rowRefs = useRef(new Map<number, HTMLDivElement>())
  const setRowRef = useCallback((el: HTMLDivElement | null) => {
    if (!el) return
    const id = el.dataset.talentId
    if (id) rowRefs.current.set(Number(id), el)
  }, [])
  const [justAddedId, setJustAddedId] = useState<number | null>(null)
  // Espèce à révéler après une recherche qui a trouvé une espèce DÉJÀ configurée
  // (aucun talent créé, donc rien à surligner par id).
  const [justFoundNom, setJustFoundNom] = useState<string | null>(null)
  const speciesRefs = useRef(new Map<string, HTMLDivElement>())
  const setSpeciesRef = useCallback((el: HTMLDivElement | null) => {
    if (!el) return
    const nom = el.dataset.speciesNom
    if (nom) speciesRefs.current.set(nom, el)
  }, [])

  const addTalentTo = useCallback(async (pokemonNom: string, defaultNom: string) => {
    const id = await addTalent(pokemonNom, defaultNom)
    setExpanded((prev) => new Set(prev).add(pokemonNom))
    if (id != null) setJustAddedId(id)
  }, [addTalent])

  /**
   * Sélection depuis la barre de recherche : une espèce déjà configurée est
   * simplement RETROUVÉE (dépliée + défilement), pas dupliquée — pour lui
   * ajouter un talent de plus, le bouton dédié est à l'intérieur de sa carte.
   */
  const handleSelectPokemon = async (p: Pokemon) => {
    if (talentsByPokemon.has(p.nom)) {
      setExpanded((prev) => new Set(prev).add(p.nom))
      setJustFoundNom(p.nom)
      return
    }
    await addTalentTo(p.nom, p.nom_talent?.trim() || p.nom)
  }

  useEffect(() => {
    if (justAddedId == null) return
    const el = rowRefs.current.get(justAddedId)
    if (!el) return
    el.scrollIntoView({ behavior: 'smooth', block: 'center' })
    const timeout = window.setTimeout(() => setJustAddedId(null), 1500)
    return () => window.clearTimeout(timeout)
  }, [justAddedId, sortedSpecies])

  useEffect(() => {
    if (!justFoundNom) return
    const el = speciesRefs.current.get(justFoundNom)
    if (!el) return
    el.scrollIntoView({ behavior: 'smooth', block: 'center' })
    const timeout = window.setTimeout(() => setJustFoundNom(null), 1500)
    return () => window.clearTimeout(timeout)
  }, [justFoundNom, sortedSpecies])

  if (loading || attacksLoading || pokemonLoading || weathersLoading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
      <div className="flex items-center gap-2 mb-1">
        <span className="text-2xl">🧬</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Talents des pokémon</h3>
      </div>
      <p className="text-ink-muted-2 text-xs mb-5">
        Effets passifs propres à une espèce, actifs dans tous les modes de combat et pour les deux camps
        (l’adversaire d’un parcours bénéficie donc du talent de son espèce). Une espèce peut en cumuler plusieurs.
        La recherche sert aussi à retrouver une espèce déjà configurée : elle se déplie et défile jusqu’à toi.
      </p>

      <PokemonSearchInput options={pokemon} onSelect={(p) => void handleSelectPokemon(p)} placeholder="Chercher ou ajouter un pokémon…" />

      {sortedSpecies.length > 1 && (
        <div className="flex items-center gap-2 mt-4">
          <span className="text-ink-muted-2 text-xs">Trier par</span>
          <button
            onClick={() => setSortMode('name')}
            className={`text-xs px-2 py-1 rounded ${sortMode === 'name' ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
          >
            Nom
          </button>
          <button
            onClick={() => setSortMode('numero')}
            className={`text-xs px-2 py-1 rounded ${sortMode === 'numero' ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
          >
            N° Pokédex
          </button>
        </div>
      )}

      <div className="flex flex-col gap-4 mt-4">
        {talents.length === 0 ? (
          <p className="text-ink-muted-2 text-sm">Aucun talent configuré.</p>
        ) : (
          sortedSpecies.map((nom) => {
            const species = pokemonByName.get(nom)
            const list = talentsByPokemon.get(nom) ?? []
            const isOpen = expanded.has(nom)
            // Résumé de la vue repliée : le même texte que sous chaque carte,
            // enchaîné quand l'espèce cumule plusieurs talents.
            const recap = list.map((t) => describeTalent(t, weatherNames)).join(' · ')
            return (
              <div
                key={nom}
                ref={setSpeciesRef}
                data-species-nom={nom}
                className={`flex flex-col gap-2 rounded transition-shadow duration-500 ${justFoundNom === nom ? 'ring-4 ring-[#f0c419]' : ''}`}
              >
                <button
                  type="button"
                  onClick={() => toggleExpanded(nom)}
                  aria-expanded={isOpen}
                  className="flex items-center gap-2 text-left w-full"
                >
                  <span className="text-ink-muted-2 text-xs w-3 shrink-0">{isOpen ? '▾' : '▸'}</span>
                  <div className="w-8 h-8 shrink-0 rounded border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
                    {species?.image_miniature ? (
                      <img src={species.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
                    ) : (
                      <span className="text-ink-muted-2 text-sm">?</span>
                    )}
                  </div>
                  {species && <span className="text-ink-muted-2 text-xs shrink-0">#{species.numero}</span>}
                  <span className="text-ink text-sm font-bold shrink-0">{nom}</span>
                  {!isOpen && (
                    <span className="text-ink-muted-2 text-xs italic flex-1 min-w-0 truncate text-right">{recap}</span>
                  )}
                </button>
                {isOpen && (
                  <div className="flex flex-col gap-2 pl-2">
                    {list.map((t) => (
                      <TalentRow
                        key={t.id}
                        talent={t}
                        attackTypes={attackTypes}
                        weathers={sortedWeathers}
                        weatherNames={weatherNames}
                        highlighted={justAddedId === t.id}
                        rowRef={setRowRef}
                        onUpdate={updateTalent}
                        onRemove={removeTalent}
                      />
                    ))}
                    {/* Ajouter un 2e talent à une espèce déjà configurée passe
                        par ici : la barre de recherche, elle, se contente de
                        retrouver une espèce existante. */}
                    <button
                      onClick={() => void addTalentTo(nom, species?.nom_talent?.trim() || nom)}
                      className="self-start bg-white border-2 border-dashed border-ink/40 rounded px-2 py-1.5 text-ink-muted-2 text-xs"
                    >
                      + Ajouter un talent à {nom}
                    </button>
                  </div>
                )}
              </div>
            )
          })
        )}
      </div>

      {talents.length > 0 && (
        <div className="mt-5">
          <PokemonSearchInput options={pokemon} onSelect={(p) => void handleSelectPokemon(p)} placeholder="Chercher ou ajouter un pokémon…" />
        </div>
      )}
    </div>
  )
}
