import type { PlayerPokemon, Attack } from '../../types'
import { getEligibleAbilities } from '../../lib/autoBattle'
import { TypeBadge } from '../TypeBadge'
import { PixelIcon } from '../icons/PixelIcon'
import { STAT_ICON, DICE_GENERIC_ICON } from '../../lib/icons'
import { PANEL } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  playerPokemon: PlayerPokemon
  attacksByName: Map<string, Attack>
  bannedAttacks: Set<string>
  onSelect: (ability: Attack) => void
  onBack: () => void
}

// Sélection de la capacité offensive — n'affiche que nom/type/dégâts de base
// + dé (requirement #10, dé désormais inclus dans le calcul de dégâts) :
// jamais l'effet, contrairement à AttackDetailCard utilisé partout ailleurs
// dans l'app. Capacités bannies (trop puissantes) exclues.
export function AutoBattleAbilityPicker({ playerPokemon, attacksByName, bannedAttacks, onSelect, onBack }: Props) {
  const abilities = getEligibleAbilities(playerPokemon.moves, attacksByName, bannedAttacks)

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <button onClick={onBack} className={`text-xs px-2 py-1 rounded font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
        <h4 className="text-ink text-base font-bold">Choisissez une capacité offensive</h4>
      </div>
      <div className="flex flex-col gap-2">
        {abilities.map((a) => (
          <button
            key={a.nom}
            onClick={() => onSelect(a)}
            className={`${PANEL} flex items-center gap-3 p-2.5 text-left ${BUTTON_STYLE.gray}`}
          >
            <TypeBadge type={a.type} small />
            <span className="flex-1 text-ink text-sm font-bold truncate">{a.nom}</span>
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
          </button>
        ))}
      </div>
    </div>
  )
}
