import type { PlayerPokemon, Attack, AutoBattleAbilityRule } from '../../types'
import { getStatusEffectDisplay, describeAbilityRule } from '../../lib/autoBattle'
import { TypeBadge } from '../TypeBadge'
import { PixelIcon } from '../icons/PixelIcon'
import { STAT_ICON, DICE_GENERIC_ICON } from '../../lib/icons'
import { getPrecisionColor } from '../../lib/precisionColor'
import { PANEL } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { useToast } from '../../context/ToastContext'

interface Props {
  playerPokemon: PlayerPokemon
  attacksByName: Map<string, Attack>
  abilityRulesByName: Map<string, AutoBattleAbilityRule>
  bannedAttacks: Set<string>
  precisionEnabled: boolean
  disabled: boolean
  onSelect: (ability: Attack) => void
}

// Grille 2 colonnes des capacités du pokémon en Combat Manuel (requirement :
// affichée sous le visuel de combat, au-dessus de l'historique, pendant tout
// le combat — pas un écran de sélection séparé comme AutoBattleAbilityPicker
// en mode Auto). `disabled` = un tour est en cours de résolution/animation
// (attend le prochain round_no), la grille reste visible mais non cliquable.
export function ManualBattleAbilityGrid({ playerPokemon, attacksByName, abilityRulesByName, bannedAttacks, precisionEnabled, disabled, onSelect }: Props) {
  const { showToast } = useToast()
  const abilities = playerPokemon.moves
    .map((nom) => attacksByName.get(nom))
    .filter((a): a is Attack => a != null)

  return (
    <div className="grid grid-cols-2 gap-2">
      {abilities.map((a) => {
        const ineligible = bannedAttacks.has(a.nom)
        const rule = abilityRulesByName.get(a.nom)
        const effectLines = describeAbilityRule(rule, a)
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
                    <span className="text-xs font-bold" style={{ color: getPrecisionColor(a.precision ?? 10) }}>{a.precision ?? 10}</span>
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
