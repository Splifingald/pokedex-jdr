import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type {
  AutoBattleStatusEffect, AutoBattleTalentStat, AutoBattleWeather, AutoBattleWeatherEffect,
  AutoBattleWeatherEffectKind, AutoBattleWeatherTargetScope,
} from '../types'
import { useAutoBattleWeathers } from '../hooks/useAutoBattleWeathers'
import { useAttacks } from '../hooks/useAttacks'
import { NumberInput } from './NumberInput'
import { TypeBadge } from './TypeBadge'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { CloseIcon } from './icons/CloseIcon'
import {
  STATUS_EFFECT_LABEL, WEATHER_EFFECT_KIND_LABEL, WEATHER_TARGET_SCOPE_LABEL, describeWeatherEffect,
} from '../lib/autoBattle'
import { BATTLE_ANIMATION_IDS, getBattleAnimationLabel } from '../lib/battleAnimations'

// Mêmes constantes de style que AdminAutoBattleTalentsPanel — les trois panneaux
// d'effets de combat (capacités / talents / météo) doivent rester visuellement
// interchangeables.
const SELECT_CLASS = 'bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none'
const NUM_CLASS_SM = 'w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none'
const TEXT_CLASS = 'flex-1 min-w-0 bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none'

const STAT_LABEL: Record<AutoBattleTalentStat, string> = { damage: 'Dégâts', precision: 'Précision' }
const ALL_STATUSES = Object.keys(STATUS_EFFECT_LABEL) as AutoBattleStatusEffect[]

type EffectPatch = Partial<Omit<AutoBattleWeatherEffect, 'id' | 'weather_id' | 'created_at'>>

/**
 * Champs remis à NULL quand on change de `kind` : la contrainte
 * autobattle_weather_effects_fields rejette une écriture partielle, chaque
 * changement doit donc envoyer un groupe COHÉRENT (même convention que le
 * panneau des talents).
 */
const BLANK: EffectPatch = {
  stat: null,
  amount: null,
  target_scope: null,
  status: null,
  percent: null,
  damage_amount: null,
}

/** Valeurs minimales acceptées par les contraintes, pour chaque kind. */
function defaultsFor(kind: AutoBattleWeatherEffectKind): EffectPatch {
  switch (kind) {
    case 'stat_mod': return { stat: 'precision', amount: 1, target_scope: 'pokemon_type' }
    case 'inflict_status': return { status: 'frozen', percent: 10 }
    case 'damage': return { damage_amount: 5, percent: 100 }
  }
}

interface EffectRowProps {
  effect: AutoBattleWeatherEffect
  attackTypes: string[]
  onUpdate: (id: number, patch: EffectPatch) => void
  onRemove: (id: number) => void
}

function WeatherEffectRow({ effect, attackTypes, onUpdate, onRemove }: EffectRowProps) {
  const patch = (p: EffectPatch) => onUpdate(effect.id, p)

  const handleKindChange = (kind: AutoBattleWeatherEffectKind) => {
    // type_filter est volontairement CONSERVÉ d'un kind à l'autre : c'est la
    // même liste de types dans les trois cas, la remettre à zéro obligerait à
    // tout recocher pour un simple changement d'avis.
    patch({ ...BLANK, ...defaultsFor(kind), kind })
  }

  const toggleType = (value: string) => {
    const current = effect.type_filter ?? []
    patch({ type_filter: current.includes(value) ? current.filter((v) => v !== value) : [...current, value] })
  }

  // Le filtre est une liste d'INCLUSION : « tous sauf Sol et Roche » s'écrit en
  // cochant tout puis en décochant deux types, d'où les deux raccourcis.
  const typeChips = (emptyLabel: string) => (
    <div className="flex flex-col gap-1">
      <div className="flex items-center gap-2 flex-wrap">
        <span className="text-ink-muted-2 text-xs">
          {(effect.type_filter?.length ?? 0) === 0 ? emptyLabel : 'Types concernés'}
        </span>
        <button
          type="button"
          onClick={() => patch({ type_filter: attackTypes })}
          className={`text-xs px-2 py-0.5 rounded ${BUTTON_STYLE.gray}`}
        >
          Tout cocher
        </button>
        <button
          type="button"
          onClick={() => patch({ type_filter: [] })}
          className={`text-xs px-2 py-0.5 rounded ${BUTTON_STYLE.gray}`}
        >
          Tout décocher
        </button>
      </div>
      <div className="flex flex-wrap gap-1">
        {attackTypes.map((t) => {
          const on = effect.type_filter?.includes(t) ?? false
          return (
            <button
              key={t}
              type="button"
              onClick={() => toggleType(t)}
              className={`rounded transition-opacity ${on ? 'opacity-100' : 'opacity-35 hover:opacity-70'}`}
            >
              <TypeBadge type={t} small />
            </button>
          )
        })}
      </div>
    </div>
  )

  return (
    <div className={`flex flex-col gap-2 p-3 rounded ${PIXEL_BORDER_SM} bg-white`}>
      <div className="flex items-center gap-2 flex-wrap">
        <select
          value={effect.kind}
          onChange={(e) => handleKindChange(e.target.value as AutoBattleWeatherEffectKind)}
          className={SELECT_CLASS}
        >
          {(Object.keys(WEATHER_EFFECT_KIND_LABEL) as AutoBattleWeatherEffectKind[]).map((k) => (
            <option key={k} value={k}>{WEATHER_EFFECT_KIND_LABEL[k]}</option>
          ))}
        </select>
        <button onClick={() => onRemove(effect.id)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
          <CloseIcon className="w-3 h-3" />
        </button>
      </div>

      {effect.kind === 'stat_mod' && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2 flex-wrap">
            <select
              value={effect.stat ?? 'precision'}
              onChange={(e) => patch({ stat: e.target.value as AutoBattleTalentStat })}
              className={SELECT_CLASS}
            >
              {(Object.keys(STAT_LABEL) as AutoBattleTalentStat[]).map((s) => (
                <option key={s} value={s}>{STAT_LABEL[s]}</option>
              ))}
            </select>
            <NumberInput value={effect.amount ?? 0} fallback={0} onCommit={(v) => patch({ amount: v })} className={NUM_CLASS_SM} />
            <span className="text-ink-muted-2 text-xs">(négatif = malus)</span>
          </div>
          <label className="flex items-center gap-2 flex-wrap">
            <span className="text-ink-muted-2 text-xs">S’applique selon le type</span>
            <select
              value={effect.target_scope ?? 'pokemon_type'}
              onChange={(e) => patch({ target_scope: e.target.value as AutoBattleWeatherTargetScope })}
              className={SELECT_CLASS}
            >
              {(Object.keys(WEATHER_TARGET_SCOPE_LABEL) as AutoBattleWeatherTargetScope[]).map((s) => (
                <option key={s} value={s}>{WEATHER_TARGET_SCOPE_LABEL[s]}</option>
              ))}
            </select>
          </label>
          {typeChips('Tous les types')}
        </div>
      )}

      {effect.kind === 'inflict_status' && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2 flex-wrap">
            <select
              value={effect.status ?? 'frozen'}
              onChange={(e) => patch({ status: e.target.value as AutoBattleStatusEffect })}
              className={SELECT_CLASS}
            >
              {ALL_STATUSES.map((s) => <option key={s} value={s}>{STATUS_EFFECT_LABEL[s]}</option>)}
            </select>
            <NumberInput
              min={1}
              value={effect.percent ?? 10}
              fallback={10}
              onCommit={(v) => patch({ percent: Math.max(1, Math.min(100, v)) })}
              className={NUM_CLASS_SM}
            />
            <span className="text-ink-muted-2 text-xs">% de chances, chaque tour</span>
          </div>
          {typeChips('Tous les types')}
        </div>
      )}

      {effect.kind === 'damage' && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2 flex-wrap">
            <NumberInput
              min={1}
              value={effect.damage_amount ?? 5}
              fallback={5}
              onCommit={(v) => patch({ damage_amount: Math.max(1, v) })}
              className={NUM_CLASS_SM}
            />
            <span className="text-ink-muted-2 text-xs">dégâts, avec</span>
            <NumberInput
              min={1}
              value={effect.percent ?? 100}
              fallback={100}
              onCommit={(v) => patch({ percent: Math.max(1, Math.min(100, v)) })}
              className={NUM_CLASS_SM}
            />
            <span className="text-ink-muted-2 text-xs">% de chances, chaque tour</span>
          </div>
          {typeChips('Tous les types')}
        </div>
      )}

      <p className="text-ink-muted-2 text-xs italic">{describeWeatherEffect(effect, attackTypes)}</p>
    </div>
  )
}

export function AdminAutoBattleWeathersPanel() {
  const {
    weathers, effectsByWeather, loading,
    addWeather, updateWeather, removeWeather,
    addEffect, updateEffect, removeEffect,
  } = useAutoBattleWeathers()
  const { attacks, loading: attacksLoading } = useAttacks()

  // Types réellement utilisés par le catalogue d'attaques — c'est à ces libellés
  // que le moteur compare les filtres (pokemon.type et attacks.type partagent le
  // même vocabulaire), pas à une liste figée.
  const attackTypes = useMemo(
    () => [...new Set(attacks.map((a) => a.type).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'fr')),
    [attacks]
  )

  // Météos dépliées (repliées par défaut) : repliée, une météo tient sur une
  // ligne — son nom et le résumé de ses effets à droite.
  const [expanded, setExpanded] = useState<Set<number>>(new Set())
  const toggleExpanded = useCallback((id: number) => {
    setExpanded((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }, [])

  // Scroll + surbrillance de la météo fraîchement ajoutée (même mécanique que
  // AdminAutoBattleTalentsPanel : ref par callback lisant data-weather-id).
  const cardRefs = useRef(new Map<number, HTMLDivElement>())
  const setCardRef = useCallback((el: HTMLDivElement | null) => {
    if (!el) return
    const id = el.dataset.weatherId
    if (id) cardRefs.current.set(Number(id), el)
  }, [])
  const [justAddedId, setJustAddedId] = useState<number | null>(null)

  const [newNom, setNewNom] = useState('')

  const handleAdd = useCallback(async () => {
    const nom = newNom.trim()
    if (!nom) return
    const id = await addWeather(nom)
    setNewNom('')
    if (id != null) {
      setExpanded((prev) => new Set(prev).add(id))
      setJustAddedId(id)
    }
  }, [addWeather, newNom])

  useEffect(() => {
    if (justAddedId == null) return
    const el = cardRefs.current.get(justAddedId)
    if (!el) return
    el.scrollIntoView({ behavior: 'smooth', block: 'center' })
    const timeout = window.setTimeout(() => setJustAddedId(null), 1500)
    return () => window.clearTimeout(timeout)
  }, [justAddedId, weathers])

  const sortedWeathers = useMemo(
    () => [...weathers].sort((a, b) => a.nom.localeCompare(b.nom, 'fr')),
    [weathers]
  )

  if (loading || attacksLoading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
      <div className="flex items-center gap-2 mb-1">
        <span className="text-2xl">🌦️</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Météo</h3>
      </div>
      <p className="text-ink-muted-2 text-xs mb-5">
        Effets de terrain partagés par les deux camps. Une seule météo peut être active à la fois : en déclencher
        une remplace la précédente, et elle dure jusqu’à la fin du combat. Ses effets « à chaque tour » se jouent
        avant tout le reste du tour — avant l’ordre de passage, avant les statuts, avant les capacités.
        Une météo se déclenche depuis un talent ou une capacité ; sans effet, elle sert quand même de condition
        aux bonus de statistique des talents et des capacités.
      </p>

      <div className="flex items-center gap-2">
        <input
          type="text"
          value={newNom}
          onChange={(e) => setNewNom(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') void handleAdd() }}
          placeholder="Nom de la météo (Zénith, Tempête de sable…)"
          className={TEXT_CLASS}
        />
        <button
          onClick={() => void handleAdd()}
          disabled={!newNom.trim()}
          className={`text-xs px-3 py-2 rounded ${PIXEL_BORDER_SM} ${newNom.trim() ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
        >
          + Ajouter
        </button>
      </div>

      <div className="flex flex-col gap-4 mt-4">
        {sortedWeathers.length === 0 ? (
          <p className="text-ink-muted-2 text-sm">Aucune météo configurée.</p>
        ) : (
          sortedWeathers.map((weather) => {
            const effects = effectsByWeather.get(weather.id) ?? []
            const isOpen = expanded.has(weather.id)
            const recap = effects.length === 0
              ? 'Aucun effet — sert uniquement de condition'
              : effects.map((e) => describeWeatherEffect(e, attackTypes)).join(' · ')
            return (
              <div
                key={weather.id}
                ref={setCardRef}
                data-weather-id={weather.id}
                className={`flex flex-col gap-2 rounded transition-shadow duration-500 ${justAddedId === weather.id ? 'ring-4 ring-[#f0c419]' : ''}`}
              >
                <button
                  type="button"
                  onClick={() => toggleExpanded(weather.id)}
                  aria-expanded={isOpen}
                  className="flex items-center gap-2 text-left w-full"
                >
                  <span className="text-ink-muted-2 text-xs w-3 shrink-0">{isOpen ? '▾' : '▸'}</span>
                  <span className="text-base shrink-0">{weather.icon || '🌦️'}</span>
                  <span className="text-ink text-sm font-bold shrink-0">{weather.nom}</span>
                  {!isOpen && (
                    <span className="text-ink-muted-2 text-xs italic flex-1 min-w-0 truncate text-right">{recap}</span>
                  )}
                </button>
                {isOpen && (
                  <div className="flex flex-col gap-2 pl-2">
                    <div className="flex items-center gap-2 flex-wrap">
                      {/* Emoji de la pastille affichée en combat entre les deux
                          noms de pokémon. Champ texte libre : n'importe quel
                          emoji collé au clavier convient. */}
                      <input
                        type="text"
                        value={weather.icon ?? ''}
                        onChange={(e) => updateWeather(weather.id, { icon: e.target.value.trim() || null })}
                        placeholder="🌦️"
                        title="Emoji affiché en combat"
                        className="w-12 bg-white border-2 border-ink rounded px-1 py-1.5 text-ink text-lg text-center outline-none"
                      />
                      <input
                        type="text"
                        value={weather.nom}
                        onChange={(e) => updateWeather(weather.id, { nom: e.target.value })}
                        placeholder="Nom de la météo"
                        className={TEXT_CLASS}
                      />
                      <label className="flex items-center gap-2">
                        <span className="text-ink-muted-2 text-xs">Animation</span>
                        <select
                          value={weather.animation ?? ''}
                          onChange={(e) => updateWeather(weather.id, { animation: e.target.value === '' ? null : (e.target.value as AutoBattleWeather['animation']) })}
                          className={SELECT_CLASS}
                        >
                          <option value="">Idle (par défaut)</option>
                          {BATTLE_ANIMATION_IDS.map((a) => <option key={a} value={a}>{getBattleAnimationLabel(a)}</option>)}
                        </select>
                      </label>
                      <button
                        onClick={() => removeWeather(weather.id)}
                        className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}
                        title="Supprimer cette météo"
                      >
                        <CloseIcon className="w-3 h-3" />
                      </button>
                    </div>

                    {effects.map((e) => (
                      <WeatherEffectRow
                        key={e.id}
                        effect={e}
                        attackTypes={attackTypes}
                        onUpdate={updateEffect}
                        onRemove={removeEffect}
                      />
                    ))}

                    <button
                      onClick={() => void addEffect(weather.id)}
                      className="self-start bg-white border-2 border-dashed border-ink/40 rounded px-2 py-1.5 text-ink-muted-2 text-xs"
                    >
                      + Ajouter un effet à {weather.nom}
                    </button>
                  </div>
                )}
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}
