import type { Pokemon, Attack, AutoBattleAbilityRule, AutoBattleWeatherEffect } from '../../types'
import { getStatusEffectDisplay, describeAbilityRule, weatherAffectsAbility } from '../../lib/autoBattle'
import { getSuperEfficace } from '../../lib/pokemonFacts'
import { TypeBadge } from '../TypeBadge'
import { PixelIcon } from '../icons/PixelIcon'
import { STAT_ICON, DICE_GENERIC_ICON } from '../../lib/icons'
import { getPrecisionColor, formatPrecision } from '../../lib/precisionColor'
import { PANEL } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { useToast } from '../../context/ToastContext'

interface Props {
  /** Noms des capacités à afficher — le mouvepool du pokémon normalement, ou l'ensemble des capacités configurées sur le niveau adverse si le pokémon du joueur est Métamorph (voir ManualBattleScreen : le joueur choisit toujours laquelle jouer, contrairement à l'adversaire Métamorph qui pioche au hasard). */
  abilityNoms: string[]
  /** Espèce EFFECTIVEMENT combattante (celle copiée par Métamorph le cas échéant, voir AutoBattlePopup) — même badge Super Efficace par capacité que AutoBattleAbilityPicker. */
  playerSpecies?: Pokemon
  opponentSpecies?: Pokemon
  attacksByName: Map<string, Attack>
  abilityRulesByName: Map<string, AutoBattleAbilityRule>
  bannedAttacks: Set<string>
  precisionEnabled: boolean
  /** Emoji de la météo en cours (voir autobattle_weathers.icon) — null si aucune météo n'est levée. */
  weatherIcon?: string | null
  /** Nom de la météo en cours, pour l'infobulle de la pastille. */
  weatherNom?: string | null
  /** Effets de la météo en cours — décident quelles capacités portent la pastille (voir weatherAffectsAbility). */
  weatherEffects?: AutoBattleWeatherEffect[]
  disabled: boolean
  onSelect: (ability: Attack) => void
}

// Grille 2 colonnes des capacités jouables en Combat Manuel (requirement :
// affichée sous le visuel de combat, au-dessus de l'historique, pendant tout
// le combat — pas un écran de sélection séparé comme AutoBattleAbilityPicker
// en mode Auto). `disabled` = un tour est en cours de résolution/animation
// (attend le prochain round_no), la grille reste visible mais non cliquable.
export function ManualBattleAbilityGrid({ abilityNoms, playerSpecies, opponentSpecies, attacksByName, abilityRulesByName, bannedAttacks, precisionEnabled, weatherIcon, weatherNom, weatherEffects, disabled, onSelect }: Props) {
  const { showToast } = useToast()
  const abilities = abilityNoms
    .map((nom) => attacksByName.get(nom))
    .filter((a): a is Attack => a != null)
  const isSuperEffectiveSpecies = opponentSpecies != null
    && getSuperEfficace(playerSpecies).includes(opponentSpecies.type)

  return (
    <div className="grid grid-cols-2 gap-2">
      {abilities.map((a) => {
        const ineligible = bannedAttacks.has(a.nom)
        const rule = abilityRulesByName.get(a.nom)
        const effectLines = describeAbilityRule(rule, a)
        const superEffective = isSuperEffectiveSpecies && playerSpecies != null
          && a.type.toLowerCase().trim() === playerSpecies.type.toLowerCase().trim()
        // Météo : la pastille ne s'affiche que si CETTE capacité est concernée
        // (voir weatherAffectsAbility) — un buff des attaques Eau la pose sur
        // toutes les capacités Eau offensives, et sur elles seules.
        const weatherAffects = !ineligible && weatherAffectsAbility(weatherEffects, a, precisionEnabled)
        return (
          <button
            key={a.nom}
            onClick={() => {
              if (disabled) return
              if (ineligible) {
                showToast("Cette capacité n'est pas disponible dans ce mode de jeu")
              } else {
                onSelect(a)
              }
            }}
            disabled={disabled && !ineligible}
            className={`${PANEL} flex flex-col gap-1 p-2 text-left ${ineligible || disabled ? 'opacity-40 grayscale cursor-not-allowed' : BUTTON_STYLE.gray}`}
          >
            <div className="flex items-center gap-1.5 flex-wrap">
              <TypeBadge type={a.type} small />
              <span className="flex-1 min-w-[4rem] text-ink text-xs font-bold truncate">{a.nom}</span>
              {ineligible && (
                <span className="flex items-center gap-1 shrink-0">
                  <span className="text-xs">🛑</span>
                  <span className="text-ink text-xs font-bold">BAN</span>
                </span>
              )}
              {!ineligible && superEffective && (
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full text-white bg-[#d9761e] whitespace-nowrap shrink-0">
                  Super Efficace
                </span>
              )}
              {/* Pastille météo en DERNIER de la ligne : elle se pose donc en
                  haut à droite de la carte, après le badge Super Efficace, sans
                  jamais le recouvrir — dans le flux plutôt qu'en absolu, la
                  ligne étant flex-wrap, les deux se replacent proprement quand
                  la place manque. */}
              {weatherAffects && (
                <span
                  className="text-sm leading-none shrink-0"
                  title={weatherNom ? `Capacité influencée par : ${weatherNom}` : 'Capacité influencée par la météo'}
                >
                  {weatherIcon || '🌦️'}
                </span>
              )}
            </div>
            {!ineligible && (
              <div className="flex items-center gap-2 flex-wrap">
                {a.degats_base != null && a.degats_base > 0 && (
                  <span className="flex items-center gap-1 shrink-0">
                    <PixelIcon src={STAT_ICON.damage} size={14} colored className="text-ink" />
                    <span className="text-ink text-xs font-bold">{a.degats_base}</span>
                  </span>
                )}
                {a.degats_de != null && (
                  <span className="flex items-center gap-1 shrink-0">
                    <PixelIcon src={DICE_GENERIC_ICON} size={14} colored className="text-ink" />
                    <span className="text-ink text-xs font-bold">{a.degats_de}</span>
                  </span>
                )}
                {precisionEnabled && (
                  <span className="flex items-center gap-1 shrink-0">
                    <span className="text-xs">🎯</span>
                    <span className="text-xs font-bold" style={{ color: getPrecisionColor(a.precision) }}>{formatPrecision(a.precision)}</span>
                  </span>
                )}
                {a.status_effect && (() => {
                  const statusDisplay = getStatusEffectDisplay(a.status_effect)
                  return (
                    <span
                      className="flex items-center gap-1 text-[10px] font-bold px-1.5 py-0.5 rounded-full text-white shrink-0 whitespace-nowrap"
                      style={{ backgroundColor: statusDisplay.color }}
                    >
                      <PixelIcon src={statusDisplay.iconSrc} size={12} colored />
                      {statusDisplay.label} {a.status_chance ?? 0}%
                    </span>
                  )
                })()}
              </div>
            )}
            {!ineligible && effectLines.length > 0 && (
              <div className="flex flex-col gap-0.5 mt-0.5">
                {effectLines.map((line, i) => (
                  <span key={i} className="text-ink-muted-2 text-xs leading-tight">{line}</span>
                ))}
              </div>
            )}
          </button>
        )
      })}
    </div>
  )
}
