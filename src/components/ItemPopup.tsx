import type { Item, PlayerItem } from '../types'
import { sellValue } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { rarityBadgeStyle } from '../lib/rarityColors'
import { NumberInput } from './NumberInput'

interface Props {
  row: PlayerItem
  item: Item | undefined
  pokedollarImageUrl?: string | null
  onSetQuantity: (quantity: number) => void
  onSell: (rect: DOMRect) => void
  onClose: () => void
}

function PokedollarIcon({ imageUrl }: { imageUrl?: string | null }) {
  return imageUrl ? (
    <img src={imageUrl} alt="" className="inline w-[21px] h-[21px] object-contain align-[-5px]" />
  ) : (
    <span className="text-lg">💰</span>
  )
}

export function ItemPopup({ row, item, pokedollarImageUrl, onSetQuantity, onSell, onClose }: Props) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className="relative bg-gray-900 border-2 border-gray-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-xs w-full p-6">
        {item?.rarete && (
          <div className={`absolute top-3 left-3 border text-xs rounded-full px-2 py-0.5 ${rarityBadgeStyle(item.rarete)}`}>
            {item.rarete}
          </div>
        )}
        {item && (
          <div className="absolute top-3 right-3 text-yellow-300 text-sm font-bold flex items-center gap-1">
            <PokedollarIcon imageUrl={pokedollarImageUrl} /> {item.cout}
          </div>
        )}

        <div className="flex flex-col items-center text-center mt-6">
          <div className="w-20 h-20 flex items-center justify-center mb-3">
            {item?.image_url ? (
              <img src={item.image_url} alt={row.item_nom} className="w-full h-full object-contain" />
            ) : (
              <span className="text-5xl">🎒</span>
            )}
          </div>
          <h3 className="text-white text-lg mb-2">{row.item_nom}</h3>
          {item?.description ? (
            <p className="text-gray-400 text-sm mb-4">{item.description}</p>
          ) : !item ? (
            <p className="text-gray-500 text-xs mb-4 italic">Objet absent du catalogue</p>
          ) : null}

          <div className="flex items-center gap-3 mb-5">
            <button
              onClick={() => onSetQuantity(row.quantity - 1)}
              className={`w-9 h-9 rounded font-bold text-lg ${BUTTON_STYLE.gray}`}
            >
              −
            </button>
            <NumberInput
              min={0}
              value={row.quantity}
              onCommit={(v) => onSetQuantity(Math.max(0, v))}
              className="w-16 text-center bg-gray-800 border border-gray-700 rounded py-1.5 text-white"
            />
            <button
              onClick={() => onSetQuantity(row.quantity + 1)}
              className={`w-9 h-9 rounded font-bold text-lg ${BUTTON_STYLE.gray}`}
            >
              +
            </button>
          </div>
        </div>

        {item && (
          <div className="flex justify-center">
            <button
              disabled={row.quantity <= 0}
              onClick={(e) => onSell(e.currentTarget.getBoundingClientRect())}
              className={`px-5 py-1.5 rounded font-bold flex flex-col items-center leading-tight disabled:opacity-50 disabled:cursor-not-allowed ${BUTTON_STYLE.orange}`}
            >
              <span className="text-sm">SELL</span>
              <span className="text-sm font-normal flex items-center gap-0.5">
                <PokedollarIcon imageUrl={pokedollarImageUrl} /> {sellValue(item.cout)}
              </span>
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
