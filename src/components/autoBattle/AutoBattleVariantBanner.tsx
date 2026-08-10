import { useEffect, useRef } from 'react'
import type {
  AutoBattleVariant, AutoBattleLevel, AutoBattleLevelReward,
  AutoBattlePlayerVariantProgress, AutoBattlePlayerLevelState, Pokemon, Item,
} from '../../types'
import { pickLevelBannerReward } from '../../lib/autoBattle'
import { PokedollarIcon } from '../PokedollarIcon'
import { TypeBadge } from '../TypeBadge'

interface Props {
  variant: AutoBattleVariant
  levels: AutoBattleLevel[] // triés par level_index, propres à cette variante
  rewardsByLevel: Map<number, AutoBattleLevelReward[]>
  progress: AutoBattlePlayerVariantProgress | undefined
  stateByLevel: Map<number, AutoBattlePlayerLevelState>
  pokemonByName: Map<string, Pokemon>
  itemsByName: Map<string, Item>
  pokedollarImageUrl?: string | null
}

// Espacement entre niveaux de la jauge : jusqu'à 2.5× l'espacement de base
// quand il y en a peu, réduit progressivement jusqu'à un plancher de 1.5×
// quand il y en a beaucoup (au-delà, la jauge défile horizontalement plutôt
// que de continuer à se resserrer).
const BASE_GAP_PX = 8
const MAX_GAP_PX = BASE_GAP_PX * 2.5
const MIN_GAP_PX = BASE_GAP_PX * 1.5
const GAP_SHRINK_START = 4
const GAP_SHRINK_END = 12

function computeLevelGapPx(levelCount: number): number {
  if (levelCount <= GAP_SHRINK_START) return MAX_GAP_PX
  if (levelCount >= GAP_SHRINK_END) return MIN_GAP_PX
  const t = (levelCount - GAP_SHRINK_START) / (GAP_SHRINK_END - GAP_SHRINK_START)
  return MAX_GAP_PX - t * (MAX_GAP_PX - MIN_GAP_PX)
}

function LevelReward({
  level, rewardsByLevel, itemsByName, pokedollarImageUrl,
}: {
  level: AutoBattleLevel
  rewardsByLevel: Map<number, AutoBattleLevelReward[]>
  itemsByName: Map<string, Item>
  pokedollarImageUrl?: string | null
}) {
  const reward = pickLevelBannerReward(rewardsByLevel.get(level.id) ?? [], itemsByName)
  if (!reward) return <div className="w-6 h-6 shrink-0" />
  if (reward.reward_type === 'xp') {
    return (
      <div className="w-6 h-6 shrink-0 flex items-center justify-center">
        <span className="text-xp-blue text-xs font-bold leading-none [text-shadow:0_1px_1px_rgba(0,0,0,0.8)]">{reward.xp_amount} XP</span>
      </div>
    )
  }
  const item = itemsByName.get(reward.item_nom ?? '')
  return (
    <div className="w-6 h-6 shrink-0 flex items-center justify-center">
      {item?.image_url ? (
        <img src={item.image_url} alt="" className="w-full h-full object-contain" />
      ) : (
        <PokedollarIcon imageUrl={pokedollarImageUrl} size={18} />
      )}
    </div>
  )
}

// Bannière de progression d'une variante : image de fond assombrie (moitié
// moins haute qu'avant — juste assez pour le compteur "niveau courant /
// total" en haut à droite et le Pokémon actuel, révélé en couleur ou en
// silhouette noire tant qu'il n'est pas découvert, requirement #30), suivie
// juste en dessous (sans grand espace) d'une jauge de progression défilable
// horizontalement listant TOUS les niveaux (ligne de continuité noire
// derrière les puces, requirement #29 — contour vert une fois le niveau
// complété, plus de coche séparée) et l'aperçu de la récompense sous chaque
// niveau (objet de plus haute valeur si plusieurs, sinon XP en bleu avec un
// espace avant "XP" — requirement #31). La jauge se recentre automatiquement
// sur le niveau courant à l'ouverture (scrollIntoView sur la puce courante,
// partagée par les 2 lignes qui défilent ensemble). Variante "Terminé" quand
// la progression entière est complétée (pas de précédent existant pour un
// mini-jeu à plusieurs niveaux dans ce codebase — traitement calqué sur
// l'état "grille épuisée" de Fouille : bannière assombrie + mention explicite).
export function AutoBattleVariantBanner({
  variant, levels, rewardsByLevel, progress, stateByLevel, pokemonByName, itemsByName, pokedollarImageUrl,
}: Props) {
  const currentIndex = progress?.current_level_index ?? 0
  const completed = progress?.variant_completed ?? false
  const currentLevel = levels.find((l) => l.level_index === currentIndex)
  const currentLevelState = currentLevel ? stateByLevel.get(currentLevel.id) : undefined
  const discovered = currentLevelState?.discovered ?? false
  const currentLevelSpecies = currentLevel ? pokemonByName.get(currentLevel.opponent_pokemon_nom) : undefined
  const displayedCurrent = completed ? levels.length : currentIndex + 1
  const currentDotRef = useRef<HTMLDivElement>(null)
  const levelGapPx = computeLevelGapPx(levels.length)

  useEffect(() => {
    currentDotRef.current?.scrollIntoView({ inline: 'center', block: 'nearest' })
  }, [])

  return (
    <div className="flex flex-col gap-1">
      <div className="relative w-full aspect-[4/1] rounded overflow-hidden border-2 border-ink">
        {variant.banner_url ? (
          <img src={variant.banner_url} alt="" className="absolute inset-0 w-full h-full object-cover" />
        ) : (
          <div className="absolute inset-0 bg-cream-secondary" />
        )}
        <div className="absolute inset-0 bg-black/50" />

        {levels.length > 0 && (
          <div className="absolute top-1 right-1.5 z-10 bg-black/40 rounded px-1.5 py-0.5">
            <span className="text-white text-xs font-bold [text-shadow:0_1px_2px_rgba(0,0,0,0.6)]">
              {displayedCurrent} / {levels.length}
            </span>
          </div>
        )}

        {!completed && discovered && currentLevelSpecies?.type && (
          <div className="absolute bottom-1.5 right-1.5 z-10">
            <TypeBadge type={currentLevelSpecies.type} small />
          </div>
        )}

        <div className="relative h-full flex items-center justify-center px-3">
          {completed ? (
            <div className="flex items-center gap-1.5">
              <span className="text-xl">🏆</span>
              <p className="text-white text-sm font-bold [text-shadow:0_1px_2px_rgba(0,0,0,0.6)]">Terminé !</p>
            </div>
          ) : currentLevelSpecies?.image_miniature ? (
            <img
              src={currentLevelSpecies.image_miniature}
              alt=""
              className="pixelated w-20 h-20 object-contain"
              style={discovered ? undefined : { filter: 'brightness(0)' }}
            />
          ) : (
            <span className="text-white text-2xl font-black [text-shadow:0_2px_2px_rgba(0,0,0,0.6)]">?</span>
          )}
        </div>
      </div>

      {!completed && (
        <div className="w-full overflow-x-auto">
          <div className="flex flex-col gap-0.5 w-max mx-auto px-1">
            <div className="relative flex items-center" style={{ gap: `${levelGapPx}px` }}>
              <div className="absolute left-0 right-0 top-1/2 -translate-y-1/2 h-1.5 bg-black rounded" />
              {levels.map((lvl) => {
                const isCurrent = lvl.level_index === currentIndex
                const isLevelCompleted = stateByLevel.get(lvl.id)?.completed ?? false
                const colorClass = isCurrent
                  ? 'bg-black text-white border-[#f0e08f]'
                  : isLevelCompleted
                    ? 'bg-[#5fd67a] text-black border-[#5fd67a]'
                    : 'bg-black text-white border-white/60'
                return (
                  <div
                    key={lvl.id}
                    ref={isCurrent ? currentDotRef : undefined}
                    className={`relative z-10 w-6 h-6 shrink-0 rounded-full flex items-center justify-center text-xs font-bold ${isCurrent ? 'border-[3px]' : 'border-2'} ${colorClass} ${isCurrent ? 'scale-110' : ''}`}
                    title={`Niveau ${lvl.level_index + 1}`}
                  >
                    {lvl.level_index + 1}
                  </div>
                )
              })}
            </div>

            <div className="flex items-center" style={{ gap: `${levelGapPx}px` }}>
              {levels.map((lvl) => (
                <LevelReward key={lvl.id} level={lvl} rewardsByLevel={rewardsByLevel} itemsByName={itemsByName} pokedollarImageUrl={pokedollarImageUrl} />
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
