import { useEffect, useRef } from 'react'
import type {
  AutoBattleVariant, AutoBattleLevel, AutoBattleLevelReward,
  AutoBattlePlayerVariantProgress, AutoBattlePlayerLevelState, Pokemon, Item,
} from '../../types'
import { pickLevelBannerReward } from '../../lib/autoBattle'
import { PokedollarIcon } from '../PokedollarIcon'
import { TypeBadge } from '../TypeBadge'
import { PixelIcon } from '../icons/PixelIcon'

interface Props {
  variant: AutoBattleVariant
  levels: AutoBattleLevel[] // triés par level_index, propres à cette variante
  rewardsByLevel: Map<number, AutoBattleLevelReward[]>
  progress: AutoBattlePlayerVariantProgress | undefined
  stateByLevel: Map<number, AutoBattlePlayerLevelState>
  pokemonByName: Map<string, Pokemon>
  itemsByName: Map<string, Item>
  pokedollarImageUrl?: string | null
  /** Icône signalant le mode de jeu du parcours (auto/manuel), réglée en admin (autobattle_config.mode_icon_auto_url / mode_icon_manual_url) — rien n'est affiché tant qu'elle n'est pas renseignée. */
  modeIconUrl?: string | null
}

// Espacement entre niveaux de la jauge : jusqu'à 2.5× l'espacement de base
// quand il y en a peu, réduit progressivement jusqu'à un plancher de 1.5×
// quand il y en a beaucoup (au-delà, la jauge défile horizontalement plutôt
// que de continuer à se resserrer).
// Diamètre d'une puce de niveau (w-6) — sert à calculer la largeur du
// remplissage de la jauge, qui s'arrête au centre de la puce courante.
const DOT_PX = 24
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

// Carte d'un parcours, de haut en bas :
//  1. ligne de titre — icône + nom du parcours à gauche, icône du mode de jeu
//     (auto/manuel, réglée en admin) à droite ;
//  2. image de bannière PLEINE LARGEUR de la carte (elle déborde donc le
//     padding horizontal, d'où les paddings portés par les lignes autour et
//     pas par la carte elle-même côté AutoBattlePopup), avec le compteur
//     "niveau courant / total" en haut à droite, le type de l'adversaire en
//     haut à gauche (seulement une fois découvert) et le Pokémon actuel au
//     centre, cerclé de blanc comme en mode Affichage (sticker-effect),
//     révélé en couleur ou en silhouette noire tant qu'il n'est pas découvert ;
//  3. la jauge de progression défilable horizontalement listant TOUS les
//     niveaux : barre noire derrière les puces, remplie en vert (même vert que
//     les niveaux validés) jusqu'à la puce courante, et l'aperçu de la
//     récompense sous chaque niveau (objet de plus haute valeur si plusieurs,
//     sinon XP en bleu). La jauge se recentre automatiquement sur le niveau
//     courant à l'ouverture.
// La carte entière est cliquable (voir AutoBattlePopup) : plus de bouton
// "Jouer" ici, le ticket n'est débité qu'à l'écran suivant. Variante "Terminé"
// quand la progression entière est complétée (traitement calqué sur l'état
// "grille épuisée" de Fouille : mention explicite par-dessus la bannière).
export function AutoBattleVariantBanner({
  variant, levels, rewardsByLevel, progress, stateByLevel, pokemonByName, itemsByName, pokedollarImageUrl, modeIconUrl,
}: Props) {
  const currentIndex = progress?.current_level_index ?? 0
  const completed = progress?.variant_completed ?? false
  const currentLevel = levels.find((l) => l.level_index === currentIndex)
  const currentLevelState = currentLevel ? stateByLevel.get(currentLevel.id) : undefined
  const discovered = currentLevelState?.discovered ?? false
  const currentLevelSpecies = currentLevel ? pokemonByName.get(currentLevel.opponent_pokemon_nom) : undefined
  const displayedCurrent = completed ? levels.length : currentIndex + 1
  const currentDotRef = useRef<HTMLDivElement>(null)
  const levelStripRef = useRef<HTMLDivElement>(null)
  const levelGapPx = computeLevelGapPx(levels.length)

  // Recentre la jauge de niveaux sur la puce courante — en pilotant nous-mêmes
  // le scrollLeft de la bande défilante plutôt qu'avec scrollIntoView : celui-
  // ci remonte toute la chaîne des conteneurs défilants et faisait donc aussi
  // défiler VERTICALEMENT la liste des parcours de la popup (une fois par
  // bannière montée, la dernière gagnant — la liste s'ouvrait tout en bas et
  // écrasait le recentrage sur le dernier parcours joué).
  useEffect(() => {
    const strip = levelStripRef.current
    const dot = currentDotRef.current
    if (!strip || !dot) return
    const stripRect = strip.getBoundingClientRect()
    const dotRect = dot.getBoundingClientRect()
    const delta = (dotRect.left - stripRect.left) - (stripRect.width - dotRect.width) / 2
    strip.scrollLeft += delta
  }, [])

  // Remplissage de la jauge : s'arrête au centre de la puce du niveau courant
  // (les puces sont espacées régulièrement de DOT_PX + levelGapPx), ou couvre
  // toute la barre quand le parcours est terminé.
  const fillWidthPx = currentIndex * (DOT_PX + levelGapPx) + DOT_PX / 2

  return (
    <div className="flex flex-col">
      <div className="flex items-center gap-2 px-3 pt-2.5 pb-2">
        <div className="w-7 h-7 shrink-0 flex items-center justify-center">
          {variant.icon_url ? (
            <img src={variant.icon_url} alt="" className="w-full h-full object-contain" />
          ) : (
            <span className="text-xl">⚔️</span>
          )}
        </div>
        <span className="flex-1 min-w-0 text-ink text-sm font-bold truncate">{variant.nom}</span>
        {completed && <span className="text-sm shrink-0">✅</span>}
        {modeIconUrl && (
          // Recolorée en text-ink (masque CSS, voir PixelIcon) pour être de la
          // même couleur que le titre à sa gauche.
          <span title={variant.game_mode === 'manual' ? 'Combat manuel' : 'Combat auto'} className="shrink-0 flex text-ink">
            <PixelIcon src={modeIconUrl} size={22} colored alt={variant.game_mode === 'manual' ? 'Combat manuel' : 'Combat auto'} />
          </span>
        )}
      </div>

      <div className={`relative w-full aspect-[4/1] overflow-hidden border-y-2 [container-type:size] ${completed ? 'border-[#4caf6b]' : 'border-ink'}`}>
        {variant.banner_url ? (
          <img src={variant.banner_url} alt="" className="absolute inset-0 w-full h-full object-cover" />
        ) : (
          <div className="absolute inset-0 bg-cream-secondary" />
        )}

        {/* Voile noir sur un parcours terminé : l'image passe en retrait et le
            "🏆 Terminé !" ressort par-dessus. */}
        {completed && <div className="absolute inset-0 bg-black/50" />}

        {/* Compteur masqué une fois le parcours terminé : la mention "Terminé !"
            au centre dit déjà tout, un "5 / 5" en plus fait doublon. */}
        {!completed && levels.length > 0 && (
          <div className="absolute top-1 right-1.5 z-10 bg-black/40 rounded px-1.5 py-0.5">
            <span className="text-white text-xs font-bold [text-shadow:0_1px_2px_rgba(0,0,0,0.6)]">
              {displayedCurrent} / {levels.length}
            </span>
          </div>
        )}

        {!completed && discovered && currentLevelSpecies?.type && (
          <div className="absolute top-1 left-1.5 z-10">
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
              className={`pixelated w-20 h-20 object-contain ${discovered ? 'sticker-effect' : 'sticker-effect-silhouette'}`}
            />
          ) : (
            <span className="text-white text-2xl font-black [text-shadow:0_2px_2px_rgba(0,0,0,0.6)]">?</span>
          )}
        </div>
      </div>

      {!completed && (
        <div ref={levelStripRef} className="w-full overflow-x-auto pt-2 pb-2.5">
          <div className="flex flex-col gap-0.5 w-max mx-auto px-3">
            <div className="relative flex items-center" style={{ gap: `${levelGapPx}px` }}>
              <div className="absolute left-0 right-0 top-1/2 -translate-y-1/2 h-1.5 bg-black rounded" />
              <div
                className="absolute left-0 top-1/2 -translate-y-1/2 h-1.5 bg-[#5fd67a] rounded"
                style={{ width: `${fillWidthPx}px` }}
              />
              {levels.map((lvl) => {
                const isCurrent = lvl.level_index === currentIndex
                const isLevelCompleted = stateByLevel.get(lvl.id)?.completed ?? false
                // Niveau courant : contour orange vif (+ halo de la même
                // teinte) pour rester repérable d'un coup d'oeil au milieu des
                // puces. Niveaux à venir : gris foncé plutôt que noir, pour se
                // détacher de la barre noire qui passe derrière.
                const colorClass = isCurrent
                  ? 'bg-black text-white border-[#ff9a2e] shadow-[0_0_0_2px_rgba(255,154,46,0.5)]'
                  : isLevelCompleted
                    ? 'bg-[#5fd67a] text-black border-[#5fd67a]'
                    : 'bg-[#4a4a4a] text-white border-white/60'
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
