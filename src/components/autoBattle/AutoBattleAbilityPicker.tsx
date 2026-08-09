import type { PlayerPokemon, Attack } from '../../types'
import { isDamagingAbility } from '../../lib/autoBattle'
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
  bannedAttacks: Set<string>
  precisionEnabled: boolean
  onSelect: (ability: Attack) => void
  onBack: () => void
}

// Sélection de la capacité offensive — affiche TOUTES les capacités apprises
// par ce Pokémon (pas seulement les éligibles) : nom/type/dégâts de base + dé
// + précision (si le système est activé), jamais l'effet, contrairement à
// AttackDetailCard utilisé partout ailleurs dans l'app. Les capacités
// bannies (trop puissantes) ou non-offensives restent visibles mais grisées
// avec un badge 🛑 BAN — non sélectionnables, un tap affiche un toast
// d'indisponibilité au lieu d'appeler onSelect.
export function AutoBattleAbilityPicker({ playerPokemon, attacksByName, bannedAttacks, precisionEnabled, onSelect, onBack }: Props) {
  const { showToast } = useToast()
  const abilities = playerPokemon.moves
    .map((nom) => attacksByName.get(nom))
    .filter((a): a is Attack => a != null)

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <button onClick={onBack} className={`text-xs px-2 py-1 rounded font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
        <h4 className="text-ink text-base font-bold">Choisissez une capacité offensive</h4>
      </div>
      <div className="flex flex-col gap-2">
        {abilities.map((a) => {
          const ineligible = bannedAttacks.has(a.nom) || !isDamagingAbility(a)
          return (
            <button
              key={a.nom}
              onClick={() => {
                if (ineligible) {
                  showToast("Cette capacité n'est pas disponible dans ce mode de jeu")
                } else {
                  onSelect(a)
                }
              }}
              className={`${PANEL} flex items-center gap-3 p-2.5 text-left ${ineligible ? 'opacity-40 grayscale cursor-not-allowed' : BUTTON_STYLE.gray}`}
            >
              <TypeBadge type={a.type} small />
              <span className="flex-1 text-ink text-sm font-bold truncate">{a.nom}</span>
              {ineligible ? (
                <span className="flex items-center gap-1 shrink-0">
                  <span className="text-sm">🛑</span>
                  <span className="text-ink text-xs font-bold">BAN</span>
                </span>
              ) : (
                <>
                  <span className="flex items-center gap-1 shrink-0">
                    <PixelIcon src={STAT_ICON.damage} size={16} colored className="text-ink" />
                    <span className="text-ink text-sm font-bold">{a.degats_base}</span>
                  </span>
                  {a.degats_de != null && (
                    <span className="flex items-center gap-1 shrink-0">
                      <PixelIcon src={DICE_GENERIC_ICON} size={16} colored className="text-ink" />
                      <span className="text-ink text-sm font-bold">{a.degats_de}</span>
                    </span>
                  )}
                  {precisionEnabled && (
                    <span className="flex items-center gap-1 shrink-0">
                      <span className="text-sm">🎯</span>
                      <span className="text-sm font-bold" style={{ color: getPrecisionColor(a.precision ?? 10) }}>{a.precision ?? 10}</span>
                    </span>
                  )}
                </>
              )}
            </button>
          )
        })}
      </div>
    </div>
  )
}
