import type { EndgameOutcome, EndgameRewards, Item } from '../../types'
import { PANEL_LG, CARD } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  playerId: number
  outcome: EndgameOutcome | null
  rewards: EndgameRewards
  itemsByName: Map<string, Item>
  acked: boolean
  onAck: () => void
}

// Récapitulatif remis au joueur en fin de partie. Les gains sont DÉJÀ en base
// quand cette fenêtre s'ouvre : le bouton ne fait qu'accuser réception, ce qui
// permet au MJ de savoir quand tout le monde a vu son bilan.
export function EndgameRewardsModal({ playerId, outcome, rewards, itemsByName, acked, onAck }: Props) {
  const mine = rewards[String(playerId)] ?? { xp: [], items: [] }
  const nothing = mine.xp.length === 0 && mine.items.length === 0

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4">
      <div className={`${PANEL_LG} max-w-xs w-full max-h-[85vh] overflow-y-auto p-6 text-ink`}>
        <div className="text-center mb-4">
          <div className="text-4xl mb-2">{outcome === 'win' ? '🎉' : '🏁'}</div>
          <h3 className="text-ink text-lg">{outcome === 'win' ? 'Victoire !' : 'Fin de la partie'}</h3>
        </div>

        {nothing ? (
          <p className="text-ink-muted text-sm text-center mb-5">Pas de récompense cette fois-ci.</p>
        ) : (
          <div className="flex flex-col gap-4 mb-5">
            {mine.xp.length > 0 && (
              <div>
                <p className="text-ink-muted-2 text-xs mb-1.5">Expérience gagnée</p>
                <div className="flex flex-col gap-1.5">
                  {mine.xp.map((x) => (
                    <div key={x.player_pokemon_id} className={`${CARD} px-2.5 py-1.5 flex items-center gap-2`}>
                      <span className="flex-1 text-ink text-sm truncate">{x.nom}</span>
                      <span className="text-xp-blue text-sm font-bold">+{x.gained} XP</span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {mine.items.length > 0 && (
              <div>
                <p className="text-ink-muted-2 text-xs mb-1.5">Objets reçus</p>
                <div className="flex flex-col gap-1.5">
                  {mine.items.map((it, i) => {
                    const item = itemsByName.get(it.item_nom)
                    return (
                      <div key={`${it.item_nom}-${i}`} className={`${CARD} px-2.5 py-1.5 flex items-center gap-2`}>
                        <span className="w-6 h-6 shrink-0 flex items-center justify-center">
                          {item?.image_url && <img src={item.image_url} alt="" className="pixelated w-full h-full object-contain" />}
                        </span>
                        <span className="flex-1 text-ink text-sm truncate">{it.item_nom}</span>
                        <span className="text-ink text-sm font-bold">×{it.quantity}</span>
                      </div>
                    )
                  })}
                </div>
              </div>
            )}
          </div>
        )}

        <button
          onClick={onAck}
          disabled={acked}
          className={`w-full py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.green} disabled:opacity-60`}
        >
          {acked ? 'En attente des autres joueurs…' : 'OK'}
        </button>
      </div>
    </div>
  )
}
