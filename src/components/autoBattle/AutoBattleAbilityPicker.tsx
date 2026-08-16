import { useState } from 'react'
import type { Pokemon, PlayerPokemon, Attack, AutoBattleAbilityRule } from '../../types'
import { getStatusEffectDisplay, describeAbilityRule } from '../../lib/autoBattle'
import { isTypeSuperEffective, isAbilityBlockedByType } from '../../lib/typeChart'
import { TypeBadge } from '../TypeBadge'
import { PixelIcon } from '../icons/PixelIcon'
import { STAT_ICON, DICE_GENERIC_ICON } from '../../lib/icons'
import { AutoBattleLaunchBar } from './AutoBattleLaunchBar'
import { AbilityEffectLines } from './AbilityEffectLines'
import { getPrecisionColor, formatPrecision } from '../../lib/precisionColor'
import { PANEL } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { useToast } from '../../context/ToastContext'

interface Props {
  playerPokemon: PlayerPokemon
  opponentSpecies?: Pokemon
  /** Ce niveau a-t-il déjà été joué au moins une fois (autobattle_player_level_state.discovered) — même règle que AutoBattlePokemonPicker : le badge "Super Efficace" par capacité ne doit pas apparaître lors du tout premier combat contre cet adversaire. Spécifique au mode Auto : en Combat Manuel (ManualBattleAbilityGrid) le badge reste visible dès le premier combat. Les capacités SANS EFFET, elles, restent grisées même sur un adversaire non découvert : elles ne sont tout simplement pas jouables. */
  opponentDiscovered: boolean
  attacksByName: Map<string, Attack>
  abilityRulesByName: Map<string, AutoBattleAbilityRule>
  bannedAttacks: Set<string>
  precisionEnabled: boolean
  /** Lance réellement le combat (et débite le ticket) — appelée au bouton "Lancer", pas au tap sur une capacité, qui ne fait que la sélectionner. */
  onSelect: (ability: Attack) => void
  /** Plus aucun ticket : "Lancer" apparaît quand même une fois la capacité choisie, mais désactivé. */
  noTicket?: boolean
  onBack: () => void
}

// Sélection de la capacité — affiche TOUTES les capacités apprises par ce
// Pokémon (pas seulement les éligibles) : nom/type/dégâts de base + dé +
// précision (si le système est activé), jamais l'effet, contrairement à
// AttackDetailCard utilisé partout ailleurs dans l'app. Seules les capacités
// bannies (trop puissantes, voir autobattle_banned_attacks /
// AdminAutoBattleBannedAttacksPanel) restent visibles mais grisées avec un
// badge 🛑 BAN — non sélectionnables, un tap affiche un toast
// d'indisponibilité au lieu d'appeler onSelect. Plus de restriction aux
// capacités offensives : le système de ban gère désormais toutes les
// limitations manuellement.
//
// Choix en DEUX temps : le tap sélectionne la capacité (elle passe en jaune,
// enfoncée) et fait apparaître le bouton "Lancer" en bas d'écran — c'est lui
// qui déclenche le combat et le débit du ticket (voir handleSelectAbility
// dans AutoBattlePopup). Tant qu'il n'est pas pressé, le joueur peut changer
// d'avis ou revenir en arrière sans rien dépenser.
export function AutoBattleAbilityPicker({ playerPokemon, opponentSpecies, opponentDiscovered, attacksByName, abilityRulesByName, bannedAttacks, precisionEnabled, onSelect, noTicket, onBack }: Props) {
  const { showToast } = useToast()
  const [selected, setSelected] = useState<Attack | null>(null)
  const abilities = playerPokemon.moves
    .map((nom) => attacksByName.get(nom))
    .filter((a): a is Attack => a != null)

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <button onClick={onBack} className={`text-xs px-2 py-1 rounded font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
        <h4 className="text-ink text-base font-bold">Choisis une capacité</h4>
      </div>
      <div className="flex flex-col gap-2">
        {abilities.map((a) => {
          const rule = abilityRulesByName.get(a.nom)
          const banned = bannedAttacks.has(a.nom)
          // Immunité de type : cette capacité ne peut RIEN faire à l'adversaire
          // (voir src/lib/typeChart.ts, même règle que type_no_effect côté
          // serveur) — grisée et non sélectionnable, au même titre qu'une
          // capacité bannie. Seules les capacités qui VISENT l'adversaire sont
          // concernées : un soin/buff sur soi reste jouable (requirement).
          const noEffect = !banned && isAbilityBlockedByType(a, rule, opponentSpecies?.type)
          const ineligible = banned || noEffect
          const effectLines = describeAbilityRule(rule, a)
          // Super efficace : type de LA CAPACITÉ vs type de l'adversaire —
          // plus aucun rapport avec le type du pokémon qui la lance.
          const superEffective = opponentDiscovered && isTypeSuperEffective(a.type, opponentSpecies?.type)
          const isSelected = selected?.nom === a.nom
          return (
            <button
              key={a.nom}
              onClick={() => {
                if (noEffect) {
                  showToast(`Aucun effet sur un pokémon de type ${opponentSpecies?.type ?? ''}`.trim())
                } else if (banned) {
                  showToast("Cette capacité n'est pas disponible dans ce mode de jeu")
                } else {
                  setSelected(a)
                }
              }}
              className={`${PANEL} flex flex-wrap items-center gap-x-3 gap-y-1.5 p-2.5 text-left ${
                ineligible
                  ? 'opacity-40 grayscale cursor-not-allowed'
                  : isSelected
                    ? 'border-2 border-ink bg-[#f0e08f] shadow-none translate-x-[2px] translate-y-[2px] transition-all'
                    : BUTTON_STYLE.gray
              }`}
            >
              <TypeBadge type={a.type} small />
              <span className="flex-1 min-w-[6rem] text-ink text-sm font-bold truncate">{a.nom}</span>
              {!ineligible && superEffective && (
                <span className="text-xs font-bold px-2.5 py-1 rounded-full text-white bg-[#d9761e] whitespace-nowrap shrink-0">
                  Super Efficace
                </span>
              )}
              {noEffect && (
                <span className="text-xs font-bold px-2.5 py-1 rounded-full text-white bg-ink/70 whitespace-nowrap shrink-0">
                  Aucun effet
                </span>
              )}
              {banned ? (
                <span className="flex items-center gap-1 shrink-0">
                  <span className="text-sm">🛑</span>
                  <span className="text-ink text-xs font-bold">BAN</span>
                </span>
              ) : (
                <>
                  {a.degats_base != null && a.degats_base > 0 && (
                    <span className="flex items-center gap-1 shrink-0">
                      <PixelIcon src={STAT_ICON.damage} size={16} colored className="text-ink" />
                      <span className="text-ink text-sm font-bold">{a.degats_base}</span>
                    </span>
                  )}
                  {a.degats_de != null && (
                    <span className="flex items-center gap-1 shrink-0">
                      <PixelIcon src={DICE_GENERIC_ICON} size={16} colored className="text-ink" />
                      <span className="text-ink text-sm font-bold">{a.degats_de}</span>
                    </span>
                  )}
                  {precisionEnabled && (
                    <span className="flex items-center gap-1 shrink-0">
                      <span className="text-sm">🎯</span>
                      <span className="text-sm font-bold" style={{ color: getPrecisionColor(a.precision) }}>{formatPrecision(a.precision)}</span>
                    </span>
                  )}
                  {a.status_effect && (() => {
                    const statusDisplay = getStatusEffectDisplay(a.status_effect)
                    return (
                      <span
                        className="flex items-center gap-1 text-xs font-bold px-2 py-1 rounded-full text-white shrink-0 whitespace-nowrap"
                        style={{ backgroundColor: statusDisplay.color }}
                      >
                        <PixelIcon src={statusDisplay.iconSrc} size={14} colored />
                        {statusDisplay.label} {a.status_chance ?? 0}%
                      </span>
                    )
                  })()}
                  <AbilityEffectLines lines={effectLines} textClassName="text-sm" />
                </>
              )}
            </button>
          )
        })}
      </div>

      {selected && (
        <AutoBattleLaunchBar label={selected.nom} disabled={noTicket} onLaunch={() => onSelect(selected)} />
      )}
    </div>
  )
}
