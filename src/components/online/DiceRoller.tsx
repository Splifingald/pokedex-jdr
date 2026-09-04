import { useState, useCallback, useSyncExternalStore } from 'react'
import {
  DICE_SIDES, readHistory, pushHistory, rollDie, subscribeDiceHistory, getDiceHistoryVersion,
} from '../../lib/diceRolls'
import { DiceIcon } from '../icons/DiceIcon'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'

interface Props {
  /** Le résultat est affiché par l'appelant, dans le conteneur du plateau. */
  onRoll: (sides: number, value: number) => void
}

// Lanceur de dés, en bas à droite de l'écran partagé.
//
// Le résultat est strictement local : il s'affiche chez celui qui lance, et
// l'historique des trois derniers résultats vit en mémoire. Aucun échange
// réseau, aucune écriture en base, et rien qui survive à un rechargement.
export function DiceRoller({ onRoll }: Props) {
  const [open, setOpen] = useState(false)
  const [hovered, setHovered] = useState<number | null>(null)
  // L'historique vit hors de React (module lib/diceRolls) : sans cet
  // abonnement, une remise à zéro venue d'ailleurs — nouvelle bataille,
  // plateau réinitialisé — laisserait les anciens résultats affichés.
  useSyncExternalStore(subscribeDiceHistory, getDiceHistoryVersion)

  const roll = useCallback((sides: number) => {
    const value = rollDie(sides)
    pushHistory(sides, value)
    onRoll(sides, value)
  }, [onRoll])

  return (
    <div
      className="absolute right-2 bottom-2 z-40 flex flex-col items-end gap-1.5"
      onMouseEnter={() => setOpen(true)}
      onMouseLeave={() => { setOpen(false); setHovered(null) }}
    >
      {open && (
        <div className={`flex flex-col-reverse gap-2 p-2 rounded ${PIXEL_BORDER_SM} bg-cream/95 shadow-[var(--shadow-pixel)]`}>
          {DICE_SIDES.map((sides) => {
            const history = hovered === sides ? readHistory(sides) : []
            return (
              <div key={sides} className="flex items-center justify-end gap-2">
                {/* Derniers résultats en colonne : le plus récent en haut et le
                    plus gros, les précédents décroissent. */}
                {history.length > 0 && (
                  <div className="flex flex-col items-end leading-none">
                    {history.map((v, i) => (
                      <span
                        key={i}
                        className={`font-bold ${i === 0 ? 'text-base text-ink' : i === 1 ? 'text-xs text-ink-muted' : 'text-[0.6rem] text-ink-muted-2'}`}
                      >
                        {v}
                      </span>
                    ))}
                  </div>
                )}
                <button
                  onClick={() => roll(sides)}
                  onMouseEnter={() => setHovered(sides)}
                  title={`Lancer un D${sides}`}
                  className={`w-14 rounded flex flex-col items-center justify-center py-1 text-[#e8933d] hover:text-[#f5b366] active:translate-x-[1px] active:translate-y-[1px] transition-all ${hovered === sides ? 'bg-cream-secondary' : ''}`}
                >
                  <DiceIcon sides={sides} size={40} />
                  <span className="text-ink text-xs font-bold leading-none mt-0.5">D{sides}</span>
                </button>
              </div>
            )
          })}
        </div>
      )}

      <button
        onClick={() => setOpen((v) => !v)}
        title="Lancer un dé"
        aria-label="Lancer un dé"
        className="w-14 h-14 rounded-full border-2 border-ink bg-gradient-to-br from-[#e8933d] to-[#8a4a0f] text-cream flex items-center justify-center shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
      >
        <DiceIcon sides={20} size={51} />
      </button>
    </div>
  )
}
