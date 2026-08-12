import { useState } from 'react'
import type { AutoBattleLevel, AutoBattleLevelReward, AutoBattleRewardType, AutoBattleGameMode, Pokemon, Attack, Item } from '../types'
import { useAutoBattleVariants } from '../hooks/useAutoBattleVariants'
import { useAutoBattleBannedAttacks } from '../hooks/useAutoBattleBannedAttacks'
import { usePokemon } from '../hooks/usePokemon'
import { useAttacks } from '../hooks/useAttacks'
import { useItems } from '../hooks/useItems'
import { getStatusEffectDisplay } from '../lib/autoBattle'
import { NumberInput } from './NumberInput'
import { PokemonSearchInput } from './PokemonSearchInput'
import { MoveSearchInput } from './MoveSearchInput'
import { ItemSearchInput } from './ItemSearchInput'
import { TypeBadge } from './TypeBadge'
import { PixelIcon } from './icons/PixelIcon'
import { STAT_ICON, DICE_GENERIC_ICON } from '../lib/icons'
import { getPrecisionColor } from '../lib/precisionColor'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { CloseIcon } from './icons/CloseIcon'

// Le sélecteur n'offre que XP / Objet : un badge n'est mécaniquement rien
// d'autre qu'un objet (voir types.ts) — 'badge' reste une valeur valide en
// base (compat. lignes existantes) mais n'est plus proposé comme choix
// distinct en admin, pour ne pas laisser croire à un système séparé.
const REWARD_TYPE_LABEL: Record<'xp' | 'item', string> = { xp: 'XP', item: 'Objet' }

// Positions 2 à 10 de la séquence de capacités adverses (mode Manuel) —
// chaque slot ne s'affiche que si le précédent est rempli, jusqu'à 10 au
// total (voir autobattle_levels.opponent_ability_nom_2..10 dans schema.sql).
const OPPONENT_ABILITY_EXTRA_KEYS = [
  'opponent_ability_nom_2', 'opponent_ability_nom_3', 'opponent_ability_nom_4',
  'opponent_ability_nom_5', 'opponent_ability_nom_6', 'opponent_ability_nom_7',
  'opponent_ability_nom_8', 'opponent_ability_nom_9', 'opponent_ability_nom_10',
] as const satisfies readonly (keyof AutoBattleLevel)[]
const isItemReward = (t: AutoBattleRewardType) => t === 'item' || t === 'badge'

// "Objet" cliqué mais pas encore d'objet choisi : seul cas où l'affichage
// diverge temporairement de reward.reward_type — passer sur "Objet" ne
// s'écrit en base qu'une fois un objet effectivement choisi (reward_type +
// item_nom + item_quantity envoyés ensemble). Écrire reward_type='item' seul
// violerait la contrainte autobattle_reward_item_fields (item_nom/quantity
// NOT NULL requis), ce qui provoquait un rejet serveur invisible et un
// fetchAll() de secours donnant l'impression que "la page se rafraîchit".
function RewardRow({
  reward, items, onUpdate, onRemove,
}: {
  reward: AutoBattleLevelReward
  items: Item[]
  onUpdate: (id: number, patch: Partial<Omit<AutoBattleLevelReward, 'id' | 'level_id' | 'created_at'>>) => void
  onRemove: (id: number) => void
}) {
  // true tant qu'on doit afficher le champ de recherche d'objet plutôt que
  // l'objet déjà choisi : soit parce qu'on vient de passer sur "Objet" sans
  // encore rien choisir, soit parce que l'admin a cliqué "Changer".
  const [editingItem, setEditingItem] = useState(false)
  const committedIsItem = isItemReward(reward.reward_type)
  const draftType: 'xp' | 'item' = editingItem || committedIsItem ? 'item' : 'xp'

  const handleTypeChange = (newType: 'xp' | 'item') => {
    if (newType === 'item') {
      setEditingItem(true)
      return
    }
    setEditingItem(false)
    onUpdate(reward.id, { reward_type: 'xp', xp_amount: reward.xp_amount ?? 1, item_nom: null, item_quantity: null })
  }

  const handleItemSelect = (itemNom: string) => {
    setEditingItem(false)
    onUpdate(reward.id, { reward_type: 'item', item_nom: itemNom, item_quantity: reward.item_quantity ?? 1 })
  }

  return (
    <div className={`flex flex-col gap-1.5 p-2 rounded ${PIXEL_BORDER_SM} bg-white`}>
      <div className="flex items-center gap-2">
        <select
          value={draftType}
          onChange={(e) => handleTypeChange(e.target.value as 'xp' | 'item')}
          className="bg-white border-2 border-ink rounded px-2 py-1 text-ink text-xs outline-none"
        >
          {(Object.keys(REWARD_TYPE_LABEL) as ('xp' | 'item')[]).map((t) => (
            <option key={t} value={t}>{REWARD_TYPE_LABEL[t]}</option>
          ))}
        </select>
        <div className="flex-1" />
        <button onClick={() => onRemove(reward.id)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
          <CloseIcon className="w-3 h-3" />
        </button>
      </div>

      {draftType === 'xp' && (
        <div className="flex items-center gap-2">
          <span className="text-ink-muted-2 text-xs">Montant XP</span>
          <NumberInput
            min={1}
            fallback={reward.xp_amount ?? 1}
            value={reward.xp_amount ?? 0}
            onCommit={(v) => onUpdate(reward.id, { xp_amount: Math.max(1, v) })}
            className="w-20 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
          />
        </div>
      )}

      {draftType === 'item' && (
        <div className="flex flex-col gap-1.5">
          {!editingItem && committedIsItem && reward.item_nom ? (
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 shrink-0 flex items-center justify-center">
                {items.find((i) => i.nom === reward.item_nom)?.image_url ? (
                  <img src={items.find((i) => i.nom === reward.item_nom)?.image_url ?? ''} alt="" className="w-full h-full object-contain" />
                ) : (
                  <span className="text-lg">🎒</span>
                )}
              </div>
              <span className="text-ink text-sm flex-1 truncate">{reward.item_nom}</span>
              <span className="text-ink-muted-2 text-xs shrink-0">×</span>
              <NumberInput
                min={1}
                fallback={reward.item_quantity ?? 1}
                value={reward.item_quantity ?? 1}
                onCommit={(v) => onUpdate(reward.id, { item_quantity: Math.max(1, v) })}
                className="w-16 shrink-0 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
              />
              <button onClick={() => setEditingItem(true)} className={`text-xs px-2 py-1 rounded shrink-0 ${BUTTON_STYLE.gray}`}>Changer</button>
            </div>
          ) : (
            <ItemSearchInput options={items} onSelect={(item) => handleItemSelect(item.nom)} />
          )}
        </div>
      )}
    </div>
  )
}

function RewardEditor({
  levelId, rewards, items,
  onAdd, onUpdate, onRemove,
}: {
  levelId: number
  rewards: AutoBattleLevelReward[]
  items: Item[]
  onAdd: (levelId: number) => void
  onUpdate: (id: number, patch: Partial<Omit<AutoBattleLevelReward, 'id' | 'level_id' | 'created_at'>>) => void
  onRemove: (id: number) => void
}) {
  return (
    <div className="flex flex-col gap-2">
      {rewards.length === 0 && <p className="text-ink-muted-2 text-xs italic">Aucune récompense — niveau de pacing, pas de gain à la clé.</p>}
      {rewards.map((r) => (
        <RewardRow key={r.id} reward={r} items={items} onUpdate={onUpdate} onRemove={onRemove} />
      ))}
      <button onClick={() => onAdd(levelId)} className={`text-xs px-3 py-1.5 rounded font-bold self-start ${BUTTON_STYLE.gray}`}>
        + Ajouter une récompense
      </button>
    </div>
  )
}

// Une position de la séquence de capacités adverses. La 1ʳᵉ (opponent_ability_
// nom) est toujours requise (attacks.opponent_ability_nom NOT NULL) — les 3
// suivantes (mode Manuel uniquement, voir types.ts) sont optionnelles et
// peuvent être retirées via "Changer" → laisser vide n'est pas possible ici,
// on utilise onClear pour repasser le champ à null.
function OpponentAbilitySlot({
  label, value, attacks, onSelect, onClear, clearable,
}: {
  label: string
  value: string | null
  attacks: Attack[]
  onSelect: (nom: string) => void
  onClear?: () => void
  clearable?: boolean
}) {
  const ability = attacks.find((a) => a.nom === value)
  return (
    <div>
      <p className="text-ink-muted-2 text-xs mb-1">{label}</p>
      {value ? (
        <div className="flex items-center gap-2 flex-wrap">
          <TypeBadge type={ability?.type ?? '?'} small />
          <span className="text-ink text-sm flex-1 truncate">{value}</span>
          <span className="flex items-center gap-1 shrink-0">
            <PixelIcon src={STAT_ICON.damage} size={14} colored className="text-ink" />
            <span className="text-ink text-sm font-bold">{ability?.degats_base ?? '—'}</span>
          </span>
          {ability?.degats_de != null && (
            <span className="flex items-center gap-1 shrink-0">
              <PixelIcon src={DICE_GENERIC_ICON} size={14} colored className="text-ink" />
              <span className="text-ink text-sm font-bold">{ability.degats_de}</span>
            </span>
          )}
          <span className="flex items-center gap-1 shrink-0">
            <span className="text-sm">🎯</span>
            <span className="text-sm font-bold" style={{ color: getPrecisionColor(ability?.precision ?? 10) }}>{ability?.precision ?? 10}</span>
          </span>
          {ability?.status_effect && (() => {
            const statusDisplay = getStatusEffectDisplay(ability.status_effect)
            return (
              <span
                className="flex items-center gap-1 text-xs font-bold px-2 py-1 rounded-full text-white shrink-0 whitespace-nowrap"
                style={{ backgroundColor: statusDisplay.color }}
              >
                <PixelIcon src={statusDisplay.iconSrc} size={14} colored />
                {statusDisplay.label} {ability.status_chance ?? 0}%
              </span>
            )
          })()}
          <button onClick={onClear ?? (() => onSelect(''))} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
            {clearable ? <CloseIcon className="w-3 h-3" /> : 'Changer'}
          </button>
        </div>
      ) : (
        <MoveSearchInput options={attacks} disabled={false} showDamage onSelect={(a) => onSelect(a.nom)} />
      )}
    </div>
  )
}

function LevelEditor({
  level, index, total, rewards, pokemon, attacks, items, bannedAttacks, manual,
  onUpdate, onMoveUp, onMoveDown, onDelete, onAddReward, onUpdateReward, onRemoveReward,
}: {
  level: AutoBattleLevel
  index: number
  total: number
  rewards: AutoBattleLevelReward[]
  pokemon: Pokemon[]
  attacks: Attack[]
  items: Item[]
  bannedAttacks: Set<string>
  manual: boolean
  onUpdate: (id: number, patch: Partial<Omit<AutoBattleLevel, 'id' | 'variant_id' | 'created_at'>>) => void
  onMoveUp: () => void
  onMoveDown: () => void
  onDelete: () => void
  onAddReward: (levelId: number) => void
  onUpdateReward: (id: number, patch: Partial<Omit<AutoBattleLevelReward, 'id' | 'level_id' | 'created_at'>>) => void
  onRemoveReward: (id: number) => void
}) {
  const [expanded, setExpanded] = useState(false)
  const opponentSpecies = pokemon.find((p) => p.nom === level.opponent_pokemon_nom)
  const damagingAttacks = attacks.filter((a) => !bannedAttacks.has(a.nom))
  const invalid = !level.opponent_pokemon_nom || !level.opponent_ability_nom

  return (
    <div className={`rounded ${PIXEL_BORDER_SM} ${invalid ? 'bg-red-50' : 'bg-cream-secondary'}`}>
      <div className="flex items-center gap-2 p-2">
        <button onClick={onMoveUp} disabled={index === 0} className={`text-xs px-1.5 py-1 rounded ${BUTTON_STYLE.gray} disabled:opacity-30`}>▲</button>
        <button onClick={onMoveDown} disabled={index === total - 1} className={`text-xs px-1.5 py-1 rounded ${BUTTON_STYLE.gray} disabled:opacity-30`}>▼</button>
        <button onClick={() => setExpanded((e) => !e)} className="flex-1 flex items-center gap-2 text-left">
          <span className="text-ink text-sm font-bold shrink-0">Niveau {index + 1}</span>
          <div className="w-6 h-6 shrink-0 flex items-center justify-center">
            {opponentSpecies?.image_miniature ? (
              <img src={opponentSpecies.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
            ) : (
              <span className="text-ink-muted-2 text-lg">?</span>
            )}
          </div>
          <span className="text-ink-muted-2 text-xs truncate">{level.opponent_pokemon_nom || 'Aucun opposant configuré'}</span>
          {invalid && <span className="text-hp-red text-xs font-bold shrink-0">⚠</span>}
        </button>
        <button onClick={onDelete} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
          <CloseIcon className="w-3 h-3" />
        </button>
      </div>

      {expanded && (
        <div className="flex flex-col gap-3 p-3 border-t-2 border-[#cfc7a8]">
          <div>
            <p className="text-ink-muted-2 text-xs mb-1">Pokémon adverse</p>
            {level.opponent_pokemon_nom ? (
              <div className="flex items-center gap-2 mb-1.5">
                <div className="w-8 h-8 shrink-0 rounded border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
                  {opponentSpecies?.image_miniature ? (
                    <img src={opponentSpecies.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
                  ) : (
                    <span className="text-ink-muted-2 text-sm">?</span>
                  )}
                </div>
                <span className="text-ink text-sm flex-1">{level.opponent_pokemon_nom}</span>
                <button onClick={() => onUpdate(level.id, { opponent_pokemon_nom: '' })} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>Changer</button>
              </div>
            ) : (
              <PokemonSearchInput
                options={pokemon}
                onSelect={(p) => onUpdate(level.id, {
                  opponent_pokemon_nom: p.nom,
                  opponent_hp: p.pv_base > 0 ? p.pv_base : 1,
                  opponent_base_damage: p.degats_base,
                })}
              />
            )}
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <p className="text-ink-muted-2 text-xs mb-1 flex items-center gap-1">
                <PixelIcon src={STAT_ICON.hp} size={14} colored className="text-ink" />
                PV de l'opposant
              </p>
              <NumberInput
                min={1}
                fallback={level.opponent_hp}
                value={level.opponent_hp}
                onCommit={(v) => onUpdate(level.id, { opponent_hp: Math.max(1, v) })}
                className="w-full bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none"
              />
            </div>
            <div className="flex-1">
              <p className="text-ink-muted-2 text-xs mb-1 flex items-center gap-1">
                <PixelIcon src={STAT_ICON.damage} size={14} colored className="text-ink" />
                Dégâts de base de l'opposant
              </p>
              <NumberInput
                min={0}
                fallback={level.opponent_base_damage}
                value={level.opponent_base_damage}
                onCommit={(v) => onUpdate(level.id, { opponent_base_damage: Math.max(0, v) })}
                className="w-full bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none"
              />
            </div>
          </div>

          {manual ? (
            <div className="flex flex-col gap-2">
              <p className="text-ink-muted-2 text-xs -mb-1">
                Séquence de capacités de l'opposant (mode Manuel) — jouées dans cet ordre, en boucle.
              </p>
              <OpponentAbilitySlot
                label="Capacité 1"
                value={level.opponent_ability_nom || null}
                attacks={damagingAttacks}
                onSelect={(nom) => onUpdate(level.id, { opponent_ability_nom: nom })}
              />
              {OPPONENT_ABILITY_EXTRA_KEYS.map((key, i) => {
                const prevKey = i === 0 ? null : OPPONENT_ABILITY_EXTRA_KEYS[i - 1]
                if (prevKey && !level[prevKey]) return null
                return (
                  <OpponentAbilitySlot
                    key={key}
                    label={`Capacité ${i + 2} (optionnelle)`}
                    value={level[key]}
                    attacks={damagingAttacks}
                    onSelect={(nom) => onUpdate(level.id, { [key]: nom })}
                    onClear={() => onUpdate(level.id, { [key]: null })}
                    clearable
                  />
                )
              })}
            </div>
          ) : (
            <OpponentAbilitySlot
              label="Capacité offensive de l'opposant"
              value={level.opponent_ability_nom || null}
              attacks={damagingAttacks}
              onSelect={(nom) => onUpdate(level.id, { opponent_ability_nom: nom })}
            />
          )}

          <div className="border-t-2 border-[#cfc7a8] pt-2">
            <p className="text-ink-muted-2 text-xs mb-2">Récompenses</p>
            <RewardEditor levelId={level.id} rewards={rewards} items={items} onAdd={onAddReward} onUpdate={onUpdateReward} onRemove={onRemoveReward} />
          </div>
        </div>
      )}
    </div>
  )
}

export function AdminAutoBattleVariantsPanel() {
  const {
    variants, levelsByVariant, rewardsByLevel, loading,
    addVariant, updateVariant, deleteVariant, swapVariantOrder,
    addLevel, updateLevel, swapLevelOrder, deleteLevel,
    addReward, updateReward, removeReward,
    resetVariantProgress, duplicateVariant,
  } = useAutoBattleVariants()
  const { bannedNames } = useAutoBattleBannedAttacks()
  const { pokemon } = usePokemon()
  const { attacks } = useAttacks()
  const { items } = useItems()
  const [selected, setSelected] = useState<number | null>(null)
  const [newVariantName, setNewVariantName] = useState('')

  if (loading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  const selectedVariant = variants.find((v) => v.id === selected) ?? null
  const selectedLevels = selected ? levelsByVariant.get(selected) ?? [] : []
  const canEnable = !!selectedVariant?.nom.trim() && !!selectedVariant.banner_url.trim() && !!selectedVariant.icon_url.trim() && selectedLevels.length > 0

  // Récapitulatif fusionné de toutes les récompenses de tous les niveaux de
  // la variante sélectionnée : XP additionnée en un seul total, objets (item/
  // badge — mécaniquement identiques, voir types.ts) regroupés par nom avec
  // quantités additionnées.
  const variantRewardTotals = selectedLevels.reduce(
    (acc, level) => {
      for (const r of rewardsByLevel.get(level.id) ?? []) {
        if (r.reward_type === 'xp') {
          acc.xp += r.xp_amount ?? 0
        } else if (r.item_nom) {
          acc.items.set(r.item_nom, (acc.items.get(r.item_nom) ?? 0) + (r.item_quantity ?? 0))
        }
      }
      return acc
    },
    { xp: 0, items: new Map<string, number>() }
  )

  const handleDuplicate = async (id: number) => {
    const copy = await duplicateVariant(id)
    if (copy) setSelected(copy.id)
  }

  const handleResetProgress = async () => {
    if (!selectedVariant) return
    const ok = window.confirm(
      `Réinitialiser la progression de "${selectedVariant.nom}" pour TOUS les joueurs ? Ils repartiront du niveau 1 et la variante ne sera plus marquée comme terminée. Cette action est irréversible.`
    )
    if (!ok) return
    await resetVariantProgress(selectedVariant.id)
  }

  return (
    <div className="flex flex-col md:flex-row gap-4 w-full items-start">
      <div className={`bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6 ${selected ? 'md:w-80 shrink-0' : ''}`}>
        <div className="flex items-center gap-2 mb-5">
          <span className="text-2xl">⚔️</span>
          <h3 className="text-[#a3841a] text-lg font-bold">Variantes</h3>
        </div>

        <div className="flex gap-2 mb-4">
          <input
            type="text"
            value={newVariantName}
            onChange={(e) => setNewVariantName(e.target.value)}
            placeholder="Nouvelle variante…"
            className="flex-1 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
          <button
            onClick={async () => { if (newVariantName.trim()) { const v = await addVariant(newVariantName.trim()); setNewVariantName(''); if (v) setSelected(v.id) } }}
            className={`px-3 py-2 rounded text-sm font-bold ${BUTTON_STYLE.yellow}`}
          >
            + Créer
          </button>
        </div>

        {variants.length === 0 ? (
          <p className="text-ink-muted-2 text-sm">Aucune variante pour l'instant.</p>
        ) : (
          <div className="flex flex-col gap-2">
            {variants.map((v, i) => (
              <div key={v.id} className="flex items-center gap-2">
                <button onClick={() => swapVariantOrder(v, variants[i - 1])} disabled={i === 0} className={`text-xs px-1.5 py-1 rounded ${BUTTON_STYLE.gray} disabled:opacity-30`}>▲</button>
                <button onClick={() => swapVariantOrder(v, variants[i + 1])} disabled={i === variants.length - 1} className={`text-xs px-1.5 py-1 rounded ${BUTTON_STYLE.gray} disabled:opacity-30`}>▼</button>
                <button
                  onClick={() => setSelected(selected === v.id ? null : v.id)}
                  className={`flex-1 text-left px-3 py-2 rounded text-sm font-bold ${PIXEL_BORDER_SM} ${selected === v.id ? 'bg-yellow-100 ring-2 ring-[#a3841a]' : 'bg-cream-secondary'}`}
                >
                  {v.nom || '(sans nom)'} {v.enabled && <span className="text-[#2f6b3f]">●</span>}
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {selectedVariant && (
        <div className="flex-1 min-w-0 bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
          <div className="flex items-center justify-end gap-2 mb-3">
            <button onClick={() => handleDuplicate(selectedVariant.id)} title="Dupliquer" className={`text-xs px-2 py-1.5 rounded ${BUTTON_STYLE.gray}`}>
              📋
            </button>
            <button onClick={() => deleteVariant(selectedVariant.id)} title="Supprimer" className={`text-xs px-2 py-1.5 rounded ${BUTTON_STYLE.gray}`}>
              <CloseIcon className="w-3 h-3" />
            </button>
            <button onClick={handleResetProgress} className={`text-xs px-3 py-1.5 rounded font-bold ${BUTTON_STYLE.gray}`}>
              ↺ Réinitialiser la progression (tous joueurs)
            </button>
          </div>
          <div className="flex flex-col gap-3 mb-4">
            <div>
              <label className="text-ink-muted-2 text-sm block mb-1">Nom</label>
              <input
                type="text"
                value={selectedVariant.nom}
                onChange={(e) => updateVariant(selectedVariant.id, { nom: e.target.value })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
            <div>
              <label className="text-ink-muted-2 text-sm block mb-1">Bannière (URL)</label>
              <input
                type="text"
                value={selectedVariant.banner_url}
                onChange={(e) => updateVariant(selectedVariant.id, { banner_url: e.target.value })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
            <div>
              <label className="text-ink-muted-2 text-sm block mb-1">Icône (URL)</label>
              <input
                type="text"
                value={selectedVariant.icon_url}
                onChange={(e) => updateVariant(selectedVariant.id, { icon_url: e.target.value })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
            <label className="flex items-center gap-2 text-sm text-ink-muted">
              <input
                type="checkbox"
                checked={selectedVariant.enabled}
                disabled={!canEnable}
                onChange={(e) => updateVariant(selectedVariant.id, { enabled: e.target.checked })}
                className="w-4 h-4"
              />
              <span>Activée {!canEnable && '(nom, bannière, icône et au moins un niveau requis)'}</span>
            </label>
            <div>
              <label className="text-ink-muted-2 text-sm block mb-1">Mode de jeu</label>
              <select
                value={selectedVariant.game_mode}
                onChange={(e) => updateVariant(selectedVariant.id, { game_mode: e.target.value as AutoBattleGameMode })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              >
                <option value="auto">Auto (une capacité choisie avant le combat)</option>
                <option value="manual">Manuel (une capacité choisie à chaque tour)</option>
              </select>
            </div>
          </div>

          <div className="border-t-2 border-[#cfc7a8] pt-3">
            <div className="flex items-center justify-between mb-2">
              <p className="text-ink-muted-2 text-sm font-bold">Niveaux ({selectedLevels.length})</p>
              <button onClick={() => addLevel(selectedVariant.id)} className={`text-xs px-3 py-1.5 rounded font-bold ${BUTTON_STYLE.gray}`}>+ Ajouter un niveau</button>
            </div>
            <div className="flex flex-col gap-2">
              {selectedLevels.map((level, i) => (
                <LevelEditor
                  key={level.id}
                  level={level}
                  index={i}
                  total={selectedLevels.length}
                  rewards={rewardsByLevel.get(level.id) ?? []}
                  pokemon={pokemon}
                  attacks={attacks}
                  items={items}
                  bannedAttacks={bannedNames}
                  manual={selectedVariant.game_mode === 'manual'}
                  onUpdate={updateLevel}
                  onMoveUp={() => i > 0 && swapLevelOrder(level, selectedLevels[i - 1])}
                  onMoveDown={() => i < selectedLevels.length - 1 && swapLevelOrder(level, selectedLevels[i + 1])}
                  onDelete={() => deleteLevel(level.id)}
                  onAddReward={(levelId) => addReward(levelId, { reward_type: 'xp', xp_amount: 1, item_nom: null, item_quantity: null, sort_order: (rewardsByLevel.get(levelId)?.length ?? 0) })}
                  onUpdateReward={updateReward}
                  onRemoveReward={removeReward}
                />
              ))}
            </div>
          </div>

          <div className="border-t-2 border-[#cfc7a8] pt-3 mt-3">
            <p className="text-ink-muted-2 text-sm font-bold mb-2">Récompenses totales de la variante</p>
            {variantRewardTotals.xp === 0 && variantRewardTotals.items.size === 0 ? (
              <p className="text-ink-muted-2 text-xs italic">Aucune récompense configurée sur cette variante.</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                {variantRewardTotals.xp > 0 && (
                  <span className="text-xs font-bold px-2 py-1 rounded bg-cream-secondary border-2 border-ink text-blue-600">
                    {variantRewardTotals.xp} XP
                  </span>
                )}
                {[...variantRewardTotals.items.entries()].map(([itemNom, qty]) => (
                  <span key={itemNom} className="flex items-center gap-1.5 text-xs font-bold px-2 py-1 rounded bg-cream-secondary border-2 border-ink text-ink">
                    <span className="w-4 h-4 shrink-0 flex items-center justify-center">
                      {items.find((it) => it.nom === itemNom)?.image_url ? (
                        <img src={items.find((it) => it.nom === itemNom)?.image_url ?? ''} alt="" className="w-full h-full object-contain" />
                      ) : (
                        <span className="text-xs">🎒</span>
                      )}
                    </span>
                    {itemNom} ×{qty}
                  </span>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
