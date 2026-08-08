import { useState } from 'react'
import type { AutoBattleReward, Item } from '../../types'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { GIFT_ICON } from '../../lib/icons'
import { PokedollarIcon } from '../PokedollarIcon'

interface Props {
  pokemonDisplayName: string
  rewards: AutoBattleReward[]
  itemsByName: Map<string, Item>
  pokedollarImageUrl?: string | null
  onConfirm: () => void
}

// Popup de récompense(s) de fin de niveau — même idiome reveal-puis-confirm
// que GiftPopup, étendu à une LISTE de récompenses (un niveau peut octroyer
// XP + objet + badge simultanément, voir requirement #25/#26) plutôt qu'une
// seule : nouveau composant frère plutôt qu'une modification de GiftPopup,
// pour ne pas toucher ses autres appelants (HomeTab, MiningPopup...).
export function AutoBattleRewardPopup({ pokemonDisplayName, rewards, itemsByName, pokedollarImageUrl, onConfirm }: Props) {
  const [revealed, setRevealed] = useState(false)

  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/80 p-4">
      <div className="relative bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-xs w-full p-6">
        {!revealed ? (
          <button onClick={() => setRevealed(true)} className="flex flex-col items-center text-center w-full">
            <p className="text-ink text-base mb-4">{pokemonDisplayName} a remporté le combat !</p>
            <span
              className="inline-block w-24 h-24 [filter:drop-shadow(2px_4px_2px_rgba(0,0,0,0.3))]"
              style={{ animation: 'gift-wiggle 0.6s ease-in-out infinite' }}
            >
              <img src={GIFT_ICON} alt="" className="pixelated w-full h-full object-contain" />
            </span>
          </button>
        ) : (
          <div className="flex flex-col items-center text-center">
            <h3 className="text-ink text-lg font-bold mb-3">Récompenses</h3>
            <div className="flex flex-col gap-2 w-full mb-3">
              {rewards.map((reward, i) => {
                if (reward.reward_type === 'xp') {
                  return (
                    <div key={i} className="flex items-center justify-center gap-2 animate-[celebrate-pop_0.4s_ease-out] bg-cream-secondary rounded px-3 py-2 border-2 border-ink">
                      <span className="text-ink font-bold text-sm">+{reward.xp_amount} XP</span>
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
            <button onClick={onConfirm} className={`mt-2 px-5 py-2 rounded font-bold text-sm ${BUTTON_STYLE.yellow}`}>
              Continuer
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
