import type {
  AutoBattleVariant, AutoBattleLevel, AutoBattleLevelReward,
  AutoBattlePlayerVariantProgress, AutoBattlePlayerLevelState, Pokemon, Item,
} from '../../types'
import { buildMilestoneWindow, pickBannerPreviewReward } from '../../lib/autoBattle'
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

// Bannière de progression d'une variante : image de fond assombrie, jauge de
// progression (niveau courant + 3 suivants, requirement #29), Pokémon actuel
// (révélé ou "?" géant, requirement #30) et aperçu de la récompense la plus
// significative (requirement #31). Variante "Terminé" quand la progression
// entière est complétée (pas de précédent existant pour un mini-jeu à
// plusieurs niveaux dans ce codebase — traitement calqué sur l'état
// "grille épuisée" de Fouille : bannière assombrie + mention explicite).
export function AutoBattleVariantBanner({
  variant, levels, rewardsByLevel, progress, stateByLevel, pokemonByName, itemsByName, pokedollarImageUrl,
}: Props) {
  const currentIndex = progress?.current_level_index ?? 0
  const completed = progress?.variant_completed ?? false
  const currentLevel = levels.find((l) => l.level_index === currentIndex)
  const currentLevelState = currentLevel ? stateByLevel.get(currentLevel.id) : undefined
  const discovered = currentLevelState?.discovered ?? false
  const opponentSpecies = discovered && currentLevel ? pokemonByName.get(currentLevel.opponent_pokemon_nom) : undefined
  const window_ = buildMilestoneWindow(currentIndex, levels.length)
  const previewReward = currentLevel ? pickBannerPreviewReward(rewardsByLevel.get(currentLevel.id) ?? []) : null
  const previewItem = previewReward && previewReward.reward_type !== 'xp' ? itemsByName.get(previewReward.item_nom ?? '') : undefined

  return (
    <div className="relative w-full aspect-[3/1] rounded overflow-hidden border-2 border-ink">
      {variant.banner_url ? (
        <img src={variant.banner_url} alt="" className="absolute inset-0 w-full h-full object-cover" />
      ) : (
        <div className="absolute inset-0 bg-cream-secondary" />
      )}
      <div className="absolute inset-0 bg-black/50" />

      <div className="relative h-full flex flex-col items-center justify-between p-1.5 gap-0.5">
        {completed ? (
          <div className="flex-1 flex flex-col items-center justify-center gap-0.5">
            <span className="text-xl">🏆</span>
            <p className="text-white text-xs font-bold [text-shadow:0_1px_2px_rgba(0,0,0,0.6)]">Terminé !</p>
          </div>
        ) : (
          <>
            <div className="flex-1 flex items-center justify-center">
              {opponentSpecies?.image_miniature ? (
                <img src={opponentSpecies.image_miniature} alt="" className="pixelated w-9 h-9 object-contain" />
              ) : (
                <span className="text-white text-xl font-black [text-shadow:0_2px_2px_rgba(0,0,0,0.6)]">?</span>
              )}
            </div>

            <div className="flex items-center gap-1">
              {window_.map((idx) => {
                const lvl = levels.find((l) => l.level_index === idx)
                const isCurrent = idx === currentIndex
                return (
                  <div
                    key={idx}
                    className={`w-4 h-4 rounded-full flex items-center justify-center text-[8px] font-bold border ${
                      isCurrent ? 'bg-[#f0e08f] border-ink text-ink scale-110' : 'bg-white/70 border-white/40 text-ink-muted-2'
                    }`}
                    title={lvl ? `Niveau ${idx + 1}` : undefined}
                  >
                    {idx + 1}
                  </div>
                )
              })}
            </div>

            {previewReward && (
              <div className="flex items-center gap-1 bg-white/85 rounded px-1.5 py-0.5">
                {previewReward.reward_type === 'xp' ? (
                  <span className="text-ink text-[10px] font-bold">{previewReward.xp_amount} XP</span>
                ) : (
                  <>
                    {previewItem?.image_url ? (
                      <img src={previewItem.image_url} alt="" className="w-3 h-3 object-contain" />
                    ) : (
                      <PokedollarIcon imageUrl={pokedollarImageUrl} size={12} />
                    )}
                    <span className="text-ink text-[10px] font-bold truncate max-w-[100px]">{previewReward.item_nom}</span>
                  </>
                )}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}
