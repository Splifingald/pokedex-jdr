import { useEffect, useRef } from 'react'
import type {
  AutoBattleVariant, AutoBattleLevel, AutoBattleLevelReward,
  AutoBattlePlayerVariantProgress, AutoBattlePlayerLevelState, Pokemon, Item,
} from '../../types'
import { pickLevelBannerReward } from '../../lib/autoBattle'
import { PokedollarIcon } from '../PokedollarIcon'

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
        <span className="text-white text-xs font-bold leading-none [text-shadow:0_1px_1px_rgba(0,0,0,0.8)]">{reward.xp_amount}XP</span>
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

// Bannière de progression d'une variante : image de fond assombrie, compteur
// "niveau courant / total" en haut à droite, Pokémon actuel (révélé en
// couleur, ou en silhouette noire tant qu'il n'est pas découvert — jamais un
// simple "?", requirement #30), puis une jauge de progression défilable
// horizontalement listant TOUS les niveaux (avec une ligne de continuité
// noire derrière les puces, requirement #29), une coche au-dessus de chaque
// niveau déjà complété, et l'aperçu de la récompense sous chaque niveau
// (objet de plus haute valeur si plusieurs, sinon XP — requirement #31).
// La jauge se recentre automatiquement sur le niveau courant à l'ouverture
// (scrollIntoView sur la puce courante, partagé par les 3 lignes qui
// défilent ensemble dans le même conteneur). Variante "Terminé" quand la
// progression entière est complétée (pas de précédent existant pour un
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

  useEffect(() => {
    currentDotRef.current?.scrollIntoView({ inline: 'center', block: 'nearest' })
  }, [])

  return (
    <div className="relative w-full aspect-[2/1] rounded overflow-hidden border-2 border-ink">
      {variant.banner_url ? (
        <img src={variant.banner_url} alt="" className="absolute inset-0 w-full h-full object-cover" />
      ) : (
        <div className="absolute inset-0 bg-cream-secondary" />
      )}
      <div className="absolute inset-0 bg-black/50" />

      {levels.length > 0 && (
        <div className="absolute top-1.5 right-2 z-10 bg-black/40 rounded px-1.5 py-0.5">
          <span className="text-white text-xs font-bold [text-shadow:0_1px_2px_rgba(0,0,0,0.6)]">
            {displayedCurrent} / {levels.length}
          </span>
        </div>
      )}

      <div className="relative h-full flex flex-col items-center justify-between py-2 px-3 gap-1">
        {completed ? (
          <div className="flex-1 flex flex-col items-center justify-center gap-1">
            <span className="text-2xl">🏆</span>
            <p className="text-white text-sm font-bold [text-shadow:0_1px_2px_rgba(0,0,0,0.6)]">Terminé !</p>
          </div>
        ) : (
          <>
            <div className="flex-1 flex items-center justify-center">
              {currentLevelSpecies?.image_miniature ? (
                <img
                  src={currentLevelSpecies.image_miniature}
                  alt=""
                  className="pixelated w-24 h-24 object-contain"
                  style={discovered ? undefined : { filter: 'brightness(0)' }}
                />
              ) : (
                <span className="text-white text-2xl font-black [text-shadow:0_2px_2px_rgba(0,0,0,0.6)]">?</span>
              )}
            </div>

            <div className="w-full overflow-x-auto">
              <div className="flex flex-col gap-0.5 w-max mx-auto px-1">
                <div className="flex items-center gap-2">
                  {levels.map((lvl) => {
                    const isLevelCompleted = stateByLevel.get(lvl.id)?.completed ?? false
                    return (
                      <div key={lvl.id} className="w-6 h-4 shrink-0 flex items-center justify-center">
                        {isLevelCompleted && (
                          <span className="text-[#5fd67a] text-sm font-bold leading-none [text-shadow:0_1px_1px_rgba(0,0,0,0.8)]">✓</span>
                        )}
                      </div>
                    )
                  })}
                </div>

                <div className="relative flex items-center gap-2">
                  <div className="absolute left-0 right-0 top-1/2 -translate-y-1/2 h-1.5 bg-black rounded" />
                  {levels.map((lvl) => {
                    const isCurrent = lvl.level_index === currentIndex
                    return (
                      <div
                        key={lvl.id}
                        ref={isCurrent ? currentDotRef : undefined}
                        className={`relative z-10 w-6 h-6 shrink-0 rounded-full flex items-center justify-center text-xs font-bold border-2 bg-black text-white ${
                          isCurrent ? 'border-[#f0e08f] scale-110' : 'border-white/60'
                        }`}
                        title={`Niveau ${lvl.level_index + 1}`}
                      >
                        {lvl.level_index + 1}
                      </div>
                    )
                  })}
                </div>

                <div className="flex items-center gap-2">
                  {levels.map((lvl) => (
                    <LevelReward key={lvl.id} level={lvl} rewardsByLevel={rewardsByLevel} itemsByName={itemsByName} pokedollarImageUrl={pokedollarImageUrl} />
                  ))}
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
