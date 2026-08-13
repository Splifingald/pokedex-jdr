import { useState, useMemo } from 'react'
import type { AutoBattleVariant, AutoBattleLevel, AutoBattleLevelReward, AutoBattleRewardType, AutoBattleGameMode, Pokemon, PokemonEvolution, Attack, Item } from '../types'
import { useAutoBattleVariants } from '../hooks/useAutoBattleVariants'
import { useAutoBattleBannedAttacks } from '../hooks/useAutoBattleBannedAttacks'
import { usePokemon } from '../hooks/usePokemon'
import { useAttacks } from '../hooks/useAttacks'
import { useItems } from '../hooks/useItems'
import { usePokemonEvolutions } from '../hooks/usePokemonEvolutions'
import { getStatusEffectDisplay } from '../lib/autoBattle'
import { getAttaquesWithPreEvolutions } from '../lib/pokemonFacts'
import { NumberInput } from './NumberInput'
import { PokemonSearchInput } from './PokemonSearchInput'
import { MoveSearchInput } from './MoveSearchInput'
import { ItemSearchInput } from './ItemSearchInput'
import { TypeBadge } from './TypeBadge'
import { PixelIcon } from './icons/PixelIcon'
import { STAT_ICON, DICE_GENERIC_ICON } from '../lib/icons'
import { getPrecisionColor, formatPrecision } from '../lib/precisionColor'
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
// Séquence complète (position 1 incluse), dans l'ordre de jeu.
const ABILITY_KEYS = ['opponent_ability_nom', ...OPPONENT_ABILITY_EXTRA_KEYS] as const satisfies readonly (keyof AutoBattleLevel)[]
const isItemReward = (t: AutoBattleRewardType) => t === 'item' || t === 'badge'

// Récompenses cumulées d'une liste de niveaux : XP additionnée, objets (item/
// badge — mécaniquement identiques, voir types.ts) regroupés par nom avec
// quantités additionnées. Sert au récapitulatif de la ligne de liste comme à
// celui du bas du panneau d'édition.
function computeRewardTotals(levels: AutoBattleLevel[], rewardsByLevel: Map<number, AutoBattleLevelReward[]>) {
  const totals = { xp: 0, items: new Map<string, number>() }
  for (const level of levels) {
    for (const r of rewardsByLevel.get(level.id) ?? []) {
      if (r.reward_type === 'xp') {
        totals.xp += r.xp_amount ?? 0
      } else if (r.item_nom) {
        totals.items.set(r.item_nom, (totals.items.get(r.item_nom) ?? 0) + (r.item_quantity ?? 0))
      }
    }
  }
  return totals
}

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

// Une capacité déjà configurée dans la séquence adverse : récapitulatif
// complet (type / dégâts / dé / précision / statut) + retrait.
function ConfiguredAbilityRow({
  nom, position, attacks, onRemove,
}: {
  nom: string
  /** Rang dans la séquence (mode Manuel) — masqué en mode Auto, où il n'y en a qu'une. */
  position?: number
  attacks: Attack[]
  onRemove: () => void
}) {
  const ability = attacks.find((a) => a.nom === nom)
  return (
    <div className={`flex items-center gap-2 flex-wrap p-1.5 rounded ${PIXEL_BORDER_SM} bg-white`}>
      {position != null && <span className="text-ink-muted-2 text-xs font-bold shrink-0">{position}.</span>}
      <TypeBadge type={ability?.type ?? '?'} small />
      <span className="text-ink text-sm flex-1 truncate">{nom}</span>
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
        <span className="text-sm font-bold" style={{ color: getPrecisionColor(ability?.precision) }}>{formatPrecision(ability?.precision)}</span>
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
      <button onClick={onRemove} title="Retirer" className={`text-xs px-2 py-1 rounded shrink-0 ${BUTTON_STYLE.gray}`}>
        <CloseIcon className="w-3 h-3" />
      </button>
    </div>
  )
}

// Séquence de capacités de l'opposant, dans l'ordre où il les joue (en boucle
// en mode Manuel — mode Auto : une seule, la nouvelle remplace l'ancienne).
// Trois façons d'en ajouter une, de haut en bas :
//  1. les capacités APPRENABLES par le pokémon adverse (mêmes règles que la
//     fiche Pokémon : ses attaques + celles de ses pré-évolutions), en un clic ;
//  2. la recherche libre, pour n'importe quelle capacité du jeu ;
//  3. rien — la liste en dessous montre ce qui est déjà configuré.
// Les positions sont stockées à plat (opponent_ability_nom + _2.._10, voir
// schema.sql) mais réécrites en bloc à chaque ajout/retrait, ce qui garantit
// qu'il n'y a jamais de trou dans la séquence.
function OpponentAbilitiesEditor({
  level, attacks, selectableAttacks, learnableMoves, bannedAttacks, manual, onUpdate,
}: {
  level: AutoBattleLevel
  /** Toutes les capacités, pour l'affichage des lignes déjà configurées (y compris une capacité bannie configurée avant son ban). */
  attacks: Attack[]
  /** Capacités proposables à l'ajout (bannies exclues). */
  selectableAttacks: Attack[]
  learnableMoves: string[]
  bannedAttacks: Set<string>
  manual: boolean
  onUpdate: (id: number, patch: Partial<Omit<AutoBattleLevel, 'id' | 'variant_id' | 'created_at'>>) => void
}) {
  const configured = ABILITY_KEYS.map((k) => level[k]).filter((n): n is string => !!n)
  const atCap = manual && configured.length >= ABILITY_KEYS.length

  const writeList = (next: string[]) => {
    const patch: Record<string, string | null> = { opponent_ability_nom: next[0] ?? '' }
    OPPONENT_ABILITY_EXTRA_KEYS.forEach((k, i) => { patch[k] = next[i + 1] ?? null })
    onUpdate(level.id, patch as Partial<Omit<AutoBattleLevel, 'id' | 'variant_id' | 'created_at'>>)
  }

  // Mode Auto : une seule capacité, donc remplacement pur et simple. En mode
  // Manuel, une même capacité peut occuper plusieurs positions de la séquence
  // (l'opposant la rejoue plus souvent) — rien n'est donc retiré des listes
  // d'ajout une fois configuré.
  const addAbility = (nom: string) => {
    if (!manual) { writeList([nom]); return }
    if (atCap) return
    writeList([...configured, nom])
  }

  return (
    <div className="flex flex-col gap-2">
      <p className="text-ink-muted-2 text-xs">
        {manual
          ? "Séquence de capacités de l'opposant (mode Manuel) — jouées dans cet ordre, en boucle."
          : "Capacité offensive de l'opposant"}
      </p>

      {level.opponent_pokemon_nom && (
        <div>
          <p className="text-ink-muted-2 text-xs mb-1">Capacités apprenables par {level.opponent_pokemon_nom}</p>
          {learnableMoves.length === 0 ? (
            <p className="text-ink-muted-2 text-xs italic">Aucune capacité renseignée sur cette espèce.</p>
          ) : (
            <div className="flex flex-wrap gap-1.5">
              {learnableMoves.map((nom) => {
                const ability = attacks.find((a) => a.nom === nom)
                const banned = bannedAttacks.has(nom)
                return (
                  <button
                    key={nom}
                    onClick={() => { if (!banned && !atCap) addAbility(nom) }}
                    disabled={banned || atCap}
                    title={banned ? 'Capacité bannie' : atCap ? 'Séquence complète (10 capacités)' : `Ajouter ${nom}`}
                    className={`flex items-center gap-1.5 px-2 py-1 rounded text-xs font-bold ${BUTTON_STYLE.gray} disabled:opacity-40 disabled:cursor-not-allowed`}
                  >
                    <TypeBadge type={ability?.type ?? '?'} small />
                    <span className="text-ink">{nom}</span>
                    {banned && <span>🛑</span>}
                  </button>
                )
              })}
            </div>
          )}
        </div>
      )}

      <MoveSearchInput
        options={selectableAttacks}
        disabled={atCap}
        showDamage
        onSelect={(a) => addAbility(a.nom)}
      />

      {configured.length === 0 ? (
        <p className="text-hp-red text-xs font-bold">Aucune capacité configurée — le niveau est incomplet.</p>
      ) : (
        <div className="flex flex-col gap-1.5">
          {configured.map((nom, i) => (
            <ConfiguredAbilityRow
              key={`${nom}-${i}`}
              nom={nom}
              position={manual ? i + 1 : undefined}
              attacks={attacks}
              onRemove={() => writeList(configured.filter((_, j) => j !== i))}
            />
          ))}
        </div>
      )}
    </div>
  )
}

function LevelEditor({
  level, index, total, rewards, pokemon, pokemonByName, evolutionsByPokemonNom, attacks, items, bannedAttacks, manual,
  onUpdate, onMoveUp, onMoveDown, onDelete, onAddReward, onUpdateReward, onRemoveReward,
}: {
  level: AutoBattleLevel
  index: number
  total: number
  rewards: AutoBattleLevelReward[]
  pokemon: Pokemon[]
  pokemonByName: Map<string, Pokemon>
  evolutionsByPokemonNom: Map<string, PokemonEvolution[]>
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
  // Mêmes capacités que celles listées par la fiche Pokémon : celles de
  // l'espèce + celles de ses pré-évolutions.
  const learnableMoves = getAttaquesWithPreEvolutions(opponentSpecies, pokemonByName, evolutionsByPokemonNom)

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

          <OpponentAbilitiesEditor
            level={level}
            attacks={attacks}
            selectableAttacks={damagingAttacks}
            learnableMoves={learnableMoves}
            bannedAttacks={bannedAttacks}
            manual={manual}
            onUpdate={onUpdate}
          />

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
  // Évolutions : servent à lister les capacités apprenables d'un opposant en
  // incluant celles de ses pré-évolutions, comme la fiche Pokémon.
  const { byPokemonNom: evolutionsByPokemonNom } = usePokemonEvolutions()
  const pokemonByName = useMemo(() => new Map(pokemon.map((p) => [p.nom, p])), [pokemon])
  const [selected, setSelected] = useState<number | null>(null)
  const [newVariantName, setNewVariantName] = useState('')

  if (loading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  const handleDuplicate = async (id: number) => {
    const copy = await duplicateVariant(id)
    if (copy) setSelected(copy.id)
  }

  const handleResetProgress = async (variant: AutoBattleVariant) => {
    const ok = window.confirm(
      `Réinitialiser la progression de "${variant.nom}" pour TOUS les joueurs ? Ils repartiront du niveau 1 et la variante ne sera plus marquée comme terminée. Cette action est irréversible.`
    )
    if (!ok) return
    await resetVariantProgress(variant.id)
  }

  // Liste TOUJOURS pleine largeur : l'édition d'une variante se déplie
  // directement sous sa ligne (même principe que les niveaux à l'intérieur
  // d'une variante), au lieu de rétrécir la liste pour afficher un second
  // panneau à côté.
  return (
    <div className="w-full">
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
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
            {/* La variante de la ligne courante s'appelle `selectedVariant` :
                le panneau d'édition dépliable en dessous est le même code
                qu'avant son déplacement dans la liste. */}
            {variants.map((selectedVariant, i) => {
              const selectedLevels = levelsByVariant.get(selectedVariant.id) ?? []
              const canEnable = !!selectedVariant.nom.trim() && !!selectedVariant.banner_url.trim()
                && !!selectedVariant.icon_url.trim() && selectedLevels.length > 0
              const variantRewardTotals = computeRewardTotals(selectedLevels, rewardsByLevel)
              const isOpen = selected === selectedVariant.id
              return (
                <div key={selectedVariant.id} className={`rounded ${PIXEL_BORDER_SM} ${isOpen ? 'bg-yellow-50 ring-2 ring-[#a3841a]' : 'bg-cream-secondary'}`}>
                  <div className="flex items-center gap-2 p-2">
                    <div className="flex flex-col shrink-0">
                      <button onClick={() => swapVariantOrder(selectedVariant, variants[i - 1])} disabled={i === 0} className={`text-[10px] leading-none px-1.5 py-0.5 rounded ${BUTTON_STYLE.gray} disabled:opacity-30`}>▲</button>
                      <button onClick={() => swapVariantOrder(selectedVariant, variants[i + 1])} disabled={i === variants.length - 1} className={`text-[10px] leading-none px-1.5 py-0.5 rounded mt-0.5 ${BUTTON_STYLE.gray} disabled:opacity-30`}>▼</button>
                    </div>

                    <button
                      onClick={() => setSelected(isOpen ? null : selectedVariant.id)}
                      className="flex-1 min-w-0 flex items-center gap-2 text-left"
                    >
                      <span className="w-7 h-7 shrink-0 flex items-center justify-center">
                        {selectedVariant.icon_url ? (
                          <img src={selectedVariant.icon_url} alt="" className="w-full h-full object-contain" />
                        ) : (
                          <span className="text-lg">⚔️</span>
                        )}
                      </span>
                      <span className="text-ink text-sm font-bold truncate">{selectedVariant.nom || '(sans nom)'}</span>
                      <span className="text-ink-muted-2 text-xs shrink-0">{selectedLevels.length} niv.</span>
                    </button>

                    {/* Récapitulatif des récompenses du parcours : icônes seules
                        (pas de nom ni de quantité), l'XP restant chiffrée. */}
                    <div className="flex flex-wrap items-center justify-end gap-1 shrink-0 max-w-[12rem]">
                      {variantRewardTotals.xp > 0 && (
                        <span className="text-xp-blue text-xs font-bold">{variantRewardTotals.xp} XP</span>
                      )}
                      {[...variantRewardTotals.items.keys()].map((itemNom) => {
                        const image = items.find((it) => it.nom === itemNom)?.image_url
                        return (
                          <span key={itemNom} title={itemNom} className="w-5 h-5 shrink-0 flex items-center justify-center">
                            {image ? <img src={image} alt="" className="w-full h-full object-contain" /> : <span className="text-xs">🎒</span>}
                          </span>
                        )
                      })}
                    </div>

                    {/* Activation directement dans la liste : plus de case à
                        cocher dans le panneau d'édition, ni de pastille verte. */}
                    <button
                      role="switch"
                      aria-checked={selectedVariant.enabled}
                      disabled={!canEnable && !selectedVariant.enabled}
                      onClick={() => updateVariant(selectedVariant.id, { enabled: !selectedVariant.enabled })}
                      title={canEnable || selectedVariant.enabled ? (selectedVariant.enabled ? 'Activée' : 'Désactivée') : 'Nom, bannière, icône et au moins un niveau requis'}
                      className={`w-10 h-6 shrink-0 rounded-full ${PIXEL_BORDER_SM} flex items-center p-0.5 transition-colors disabled:opacity-40 disabled:cursor-not-allowed ${selectedVariant.enabled ? 'bg-[#5fd67a] justify-end' : 'bg-cream-button justify-start'}`}
                    >
                      <span className="w-4 h-4 rounded-full bg-white border-2 border-ink" />
                    </button>
                  </div>

                  {isOpen && (
                    <div className="p-3 border-t-2 border-[#cfc7a8]">
                      <div className="flex items-center justify-end gap-2 mb-3">
                        <button onClick={() => handleDuplicate(selectedVariant.id)} title="Dupliquer" className={`text-xs px-2 py-1.5 rounded ${BUTTON_STYLE.gray}`}>
                          📋
                        </button>
                        <button onClick={() => deleteVariant(selectedVariant.id)} title="Supprimer" className={`text-xs px-2 py-1.5 rounded ${BUTTON_STYLE.gray}`}>
                          <CloseIcon className="w-3 h-3" />
                        </button>
                        <button onClick={() => handleResetProgress(selectedVariant)} className={`text-xs px-3 py-1.5 rounded font-bold ${BUTTON_STYLE.gray}`}>
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
                        {!canEnable && (
                          <p className="text-ink-muted-2 text-xs italic">
                            Activation impossible tant qu'il manque le nom, la bannière, l'icône ou au moins un niveau.
                          </p>
                        )}
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
                              pokemonByName={pokemonByName}
                              evolutionsByPokemonNom={evolutionsByPokemonNom}
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
            })}
          </div>
        )}
      </div>
    </div>
  )
}
