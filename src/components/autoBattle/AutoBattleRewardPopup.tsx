import type { AutoBattleReward, Item } from '../../types'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { PokedollarIcon } from '../PokedollarIcon'

interface Props {
  pokemonDisplayName: string
  rewards: AutoBattleReward[]
  itemsByName: Map<string, Item>
  pokedollarImageUrl?: string | null
  onConfirm: () => void
}

// Popup de récompense(s) de fin de niveau — affichée directement (pas de
// cadeau à révéler par clic, contrairement à GiftPopup : le combat lui-même
// est déjà la "révélation") : liste des récompenses + bouton "Continuer".
export function AutoBattleRewardPopup({ pokemonDisplayName, rewards, itemsByName, pokedollarImageUrl, onConfirm }: Props) {
  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/80 p-4">
      <div className="relative bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-xs w-full p-6">
        <div className="flex flex-col items-center text-center">
          <p className="text-ink text-base font-bold mb-4">{pokemonDisplayName} a remporté le combat !</p>
          {rewards.length === 0 ? (
            <p className="text-ink-muted-2 text-sm mb-3">Aucune récompense pour ce niveau.</p>
          ) : (
            <>
              <h3 className="text-ink text-lg font-bold mb-3">Récompenses</h3>
              <div className="flex flex-col gap-2 w-full mb-3">
                {rewards.map((reward, i) => {
                  if (reward.reward_type === 'xp') {
                    return (
                      <div key={i} className="flex items-center justify-center gap-2 animate-[celebrate-pop_0.4s_ease-out] bg-cream-secondary rounded px-3 py-2 border-2 border-ink">
                        <span className="text-blue-600 font-bold text-sm">+{reward.xp_amount} XP</span>
                      </div>
                    )
                  }
                  const item = itemsByName.get(reward.item_nom ?? '')
                  return (
                    <div key={i} className="flex items-center justify-center gap-2 animate-[celebrate-pop_0.4s_ease-out] bg-cream-secondary rounded px-3 py-2 border-2 border-ink">
                      <div className="w-8 h-8 shrink-0 flex items-center justify-center">
                        {item?.image_url ? (
                          <img src={item.image_url} alt="" className="w-full h-full object-contain" />
                        ) : (
                          <PokedollarIcon imageUrl={pokedollarImageUrl} className="w-full h-full" fallbackClassName="text-2xl" />
                        )}
                      </div>
                      <span className="text-ink font-bold text-sm">{reward.item_nom} ×{reward.quantity}</span>
                    </div>
                  )
                })}
              </div>
            </>
          )}
          <button onClick={onConfirm} className={`mt-2 px-5 py-2 rounded font-bold text-sm ${BUTTON_STYLE.yellow}`}>
            Continuer
          </button>
        </div>
      </div>
    </div>
  )
}
