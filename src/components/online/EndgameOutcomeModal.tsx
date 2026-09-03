import type { EndgameOutcome } from '../../types'
import { PANEL_LG } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  onChoose: (outcome: EndgameOutcome) => void
  onCancel: () => void
}

// Premier temps de la fin de partie : le MJ tranche. La victoire déclenche les
// confettis chez les joueurs ; dans les deux cas le plateau passe en vue épurée
// et le bilan s'ouvre — on peut récompenser même après une défaite.
export function EndgameOutcomeModal({ onChoose, onCancel }: Props) {
  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onCancel() }}
    >
      <div className={`${PANEL_LG} max-w-xs w-full p-6 text-ink`}>
        <div className="text-center mb-5">
          <div className="text-4xl mb-2">🏁</div>
          <h3 className="text-ink text-lg">Fin de la partie</h3>
          <p className="text-ink-muted text-xs mt-2">Comment ça s'est terminé pour les joueurs ?</p>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <button onClick={() => onChoose('lose')} className={`py-3 rounded text-sm font-bold ${BUTTON_STYLE.gray}`}>
            Défaite
          </button>
          <button onClick={() => onChoose('win')} className={`py-3 rounded text-sm font-bold ${BUTTON_STYLE.green}`}>
            Victoire 🎉
          </button>
        </div>
        <button onClick={onCancel} className={`w-full mt-3 py-2 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}>
          Annuler
        </button>
      </div>
    </div>
  )
}
