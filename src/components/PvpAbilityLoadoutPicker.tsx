import type { PlayerPokemon, Attack, AutoBattleAbilityRule } from '../types'
import { getStatusEffectDisplay, describeAbilityRule } from '../lib/autoBattle'
import { TypeBadge } from './TypeBadge'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { STAT_ICON, DICE_GENERIC_ICON } from '../lib/icons'
import { getPrecisionColor } from '../lib/precisionColor'
import { PANEL } from '../lib/panelStyles'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { useToast } from '../context/ToastContext'

interface Props {
  playerPokemon: PlayerPokemon
  attacksByName: Map<string, Attack>
  abilityRulesByName: Map<string, AutoBattleAbilityRule>
  bannedAttacks: Set<string>
  precisionEnabled: boolean
  loadoutMax: number
  /** Contrôlé par le parent (PvpPopup) — survit à un aller-retour vers l'écran "Tester" (voir onTest), contrairement à un état local qui serait perdu au démontage. */
  selected: string[]
  onSelectedChange: (next: string[]) => void
  onConfirm: () => void
  /** Lance un combat d'essai avec la boucle actuelle (voir PvpTrialBattleScreen) — masqué si l'admin n'a configuré aucun pantin (trialAvailable). */
  onTest: () => void
  trialAvailable: boolean
  onBack: () => void
}

// Sélection ORDONNÉE de 1 à loadoutMax capacités, DOUBLONS AUTORISÉS (la
// boucle défensive du défi, voir pvp_challenges.ability_noms) — sans
// précédent dans l'app (AutoBattleAbilityPicker n'en sélectionne qu'une,
// one-shot, sans doublon possible). Chaque tap sur une capacité l'AJOUTE à
// la boucle (jamais un toggle : la même capacité peut être ajoutée plusieurs
// fois) ; le retrait se fait uniquement via la croix sur la puce
// récapitulative correspondante (par POSITION, pas par nom, à cause des
// doublons possibles) — pas de réordonnancement (seulement 4-8 éléments,
// retirer et rajouter dans le bon ordre suffit).
export function PvpAbilityLoadoutPicker({
  playerPokemon, attacksByName, abilityRulesByName, bannedAttacks, precisionEnabled, loadoutMax,
  selected, onSelectedChange, onConfirm, onTest, trialAvailable, onBack,
}: Props) {
  const { showToast } = useToast()
  const abilities = playerPokemon.moves
    .map((nom) => attacksByName.get(nom))
    .filter((a): a is Attack => a != null)

  const addAbility = (nom: string) => {
    if (bannedAttacks.has(nom)) {
      showToast("Cette capacité n'est pas disponible dans ce mode de jeu")
      return
    }
    if (selected.length >= loadoutMax) {
      showToast(`Vous ne pouvez choisir que ${loadoutMax} capacités maximum`)
      return
    }
    onSelectedChange([...selected, nom])
  }

  const removeAt = (index: number) => {
    onSelectedChange(selected.filter((_, i) => i !== index))
  }

  // Positions (1-based, dans l'ordre) où chaque capacité apparaît dans la
  // boucle — une capacité choisie 2 fois affiche ses DEUX badges d'index sur
  // sa ligne, voir requirement dédié.
  const indicesByName = new Map<string, number[]>()
  selected.forEach((nom, i) => {
    const list = indicesByName.get(nom)
    if (list) list.push(i + 1)
    else indicesByName.set(nom, [i + 1])
  })

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <button onClick={onBack} className={`text-xs px-2 py-1 rounded font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
        <h4 className="text-ink text-base font-bold flex-1">Choisissez votre boucle de capacités</h4>
      </div>
      <span className={`self-start text-xs font-bold px-2 py-1 rounded-full shrink-0 ${selected.length >= loadoutMax ? 'bg-[#f0e08f] text-ink' : 'bg-cream-secondary text-ink-muted-2'}`}>
        {selected.length} / {loadoutMax}
      </span>

      {selected.length > 0 && (
        <div className="flex flex-wrap gap-2 p-2 rounded bg-cream-secondary border-2 border-ink">
          {selected.map((nom, i) => (
            <div key={`${nom}-${i}`} className="flex items-center gap-1.5 pl-2 pr-1 py-1 rounded-full bg-cream border-2 border-ink text-xs font-bold">
              <span className="w-4 h-4 shrink-0 rounded-full bg-ink text-cream flex items-center justify-center text-[10px]">{i + 1}</span>
              <span className="text-ink">{nom}</span>
              <button onClick={() => removeAt(i)} className="w-4 h-4 shrink-0 flex items-center justify-center rounded-full hover:bg-black/10" title="Retirer de la boucle">
                <CloseIcon className="w-2.5 h-2.5" />
              </button>
            </div>
          ))}
        </div>
      )}

      <div className="flex flex-col gap-2">
        {abilities.map((a) => {
          const ineligible = bannedAttacks.has(a.nom)
          const indices = indicesByName.get(a.nom) ?? []
          const effectLines = describeAbilityRule(abilityRulesByName.get(a.nom), a)
          return (
            <button
              key={a.nom}
              onClick={() => addAbility(a.nom)}
              className={`${PANEL} flex flex-wrap items-center gap-x-3 gap-y-1.5 p-2.5 text-left ${
                ineligible ? 'opacity-40 grayscale cursor-not-allowed' : indices.length > 0 ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray
              }`}
            >
              {indices.length > 0 && (
                <span className="flex items-center gap-1 shrink-0">
                  {indices.map((idx) => (
                    <span key={idx} className="w-5 h-5 rounded-full bg-ink text-cream flex items-center justify-center text-xs font-bold">
                      {idx}
                    </span>
                  ))}
                </span>
              )}
              <TypeBadge type={a.type} small />
              <span className="flex-1 min-w-[6rem] text-ink text-sm font-bold truncate">{a.nom}</span>
              {ineligible ? (
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
                      <span className="text-sm font-bold" style={{ color: getPrecisionColor(a.precision ?? 10) }}>{a.precision ?? 10}</span>
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
                  {effectLines.length > 0 && (
                    <div className="w-full flex flex-col gap-0.5 mt-0.5">
                      {effectLines.map((line, i) => (
                        <span key={i} className="text-ink-muted-2 text-sm leading-tight">{line}</span>
                      ))}
                    </div>
                  )}
                </>
              )}
            </button>
          )
        })}
      </div>

      <div className="flex gap-2">
        <button
          onClick={onConfirm}
          disabled={selected.length === 0}
          className={`flex-1 px-4 py-2.5 rounded-lg text-sm font-bold disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.yellow}`}
        >
          Confirmer le défi
        </button>
        {trialAvailable && (
          <button
            onClick={onTest}
            disabled={selected.length === 0}
            className={`px-4 py-2.5 rounded-lg text-sm font-bold disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.blue}`}
          >
            Tester
          </button>
        )}
      </div>
    </div>
  )
}
