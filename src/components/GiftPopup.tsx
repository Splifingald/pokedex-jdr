import { useState } from 'react'
import type { Item } from '../types'
import { POKEDOLLAR_ITEM_NAME } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { GIFT_ICON } from '../lib/icons'

export interface GiftReward {
  itemNom: string
  quantity: number
}

interface Props {
  pokemonDisplayName: string
  reward: GiftReward | null
  itemsByName: Map<string, Item>
  pokedollarImageUrl?: string | null
  onConfirm: () => void
}

function PokedollarIcon({ imageUrl }: { imageUrl?: string | null }) {
  return imageUrl ? (
    <img src={imageUrl} alt="" className="inline w-[21px] h-[21px] object-contain align-[-5px]" />
  ) : (
    <span className="text-lg">💰</span>
  )
}

export function GiftPopup({ pokemonDisplayName, reward, itemsByName, pokedollarImageUrl, onConfirm }: Props) {
  const [revealed, setRevealed] = useState(false)

  const isPokedollar = reward?.itemNom === POKEDOLLAR_ITEM_NAME
  const item = reward && !isPokedollar ? itemsByName.get(reward.itemNom) : undefined

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="relative bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-xs w-full p-6">
        {!revealed ? (
          <button
            onClick={() => setRevealed(true)}
            className="flex flex-col items-center text-center w-full"
          >
            <p className="text-ink text-base mb-4">
              {pokemonDisplayName} a trouvé quelque chose pour toi !
            </p>
            <span
              className="inline-block w-24 h-24 [filter:drop-shadow(2px_4px_2px_rgba(0,0,0,0.3))]"
              style={{ animation: 'gift-wiggle 0.6s ease-in-out infinite' }}
            >
              <img src={GIFT_ICON} alt="" className="pixelated w-full h-full object-contain" />
            </span>
          </button>
        ) : (
          <div className="flex flex-col items-center text-center">
            {!reward ? (
              <p className="text-ink-muted text-sm mb-5">…mais n'a rien trouvé cette fois-ci.</p>
            ) : (
              <>
                <div className="w-20 h-20 flex items-center justify-center mb-3 animate-[celebrate-pop_0.4s_ease-out]">
                  {isPokedollar ? (
                    <span className="text-5xl">💰</span>
                  ) : item?.image_url ? (
                    <img src={item.image_url} alt={reward.itemNom} className="w-full h-full object-contain" />
                  ) : (
                    <img src={GIFT_ICON} alt="" className="pixelated w-full h-full object-contain" />
                  )}
                </div>
                <h3 className="text-ink text-lg mb-1">
                  {isPokedollar ? (
                    <>+{reward.quantity} <PokedollarIcon imageUrl={pokedollarImageUrl} /></>
                  ) : (
                    <>{reward.itemNom} ×{reward.quantity}</>
                  )}
                </h3>
                {!isPokedollar && item?.description && (
                  <p className="text-ink-muted text-sm mb-1">{item.description}</p>
                )}
              </>
            )}
            <button
              onClick={onConfirm}
              className={`mt-4 px-5 py-2 rounded font-bold text-sm ${BUTTON_STYLE.yellow}`}
            >
              Continuer
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
