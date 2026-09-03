import type { Player } from '../../types'
import { PANEL_LG, CARD } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  participants: Player[]
  ackedIds: number[]
  onForceFinish: () => void
}

// Après validation : le MJ voit qui a lu son récapitulatif. Le retour en mode
// affichage se fait tout seul quand tout le monde a cliqué, mais un bouton de
// sortie évite de rester bloqué par quelqu'un qui a fermé son onglet.
export function EndgameAckPanel({ participants, ackedIds, onForceFinish }: Props) {
  const missing = participants.filter((p) => !ackedIds.includes(p.id))

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4">
      <div className={`${PANEL_LG} max-w-xs w-full p-6 text-ink`}>
        <div className="text-center mb-4">
          <div className="text-3xl mb-2">📬</div>
          <h3 className="text-ink text-lg">Récompenses distribuées</h3>
          <p className="text-ink-muted text-xs mt-2">
            {missing.length === 0
              ? 'Tout le monde a vu son récapitulatif.'
              : 'En attente de la lecture des joueurs.'}
          </p>
        </div>

        <div className="flex flex-col gap-1.5 mb-5">
          {participants.map((p) => {
            const done = ackedIds.includes(p.id)
            return (
              <div key={p.id} className={`${CARD} px-2.5 py-1.5 flex items-center gap-2`}>
                <span className="w-5 h-5 shrink-0 rounded-full overflow-hidden border border-ink" style={{ backgroundColor: p.color }}>
                  {p.image_url && <img src={p.image_url} alt="" className="w-full h-full object-cover" />}
                </span>
                <span className="flex-1 text-ink text-sm truncate">{p.name}</span>
                <span className={`text-xs font-bold ${done ? 'text-hp-green' : 'text-ink-muted-2'}`}>
                  {done ? '✓ lu' : '…'}
                </span>
              </div>
            )
          })}
          {participants.length === 0 && (
            <p className="text-ink-muted-2 text-xs italic">Aucun joueur n'a participé.</p>
          )}
        </div>

        <button onClick={onForceFinish} className={`w-full py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.green}`}>
          Terminer maintenant
        </button>
      </div>
    </div>
  )
}
