import { useState, useMemo } from 'react'
import type { Item, Player, PlayerItem } from '../types'
import { POKEDOLLAR_ITEM_NAME, sellValue } from '../types'
import { usePlayerItems } from '../hooks/usePlayerItems'
import { ItemSearchInput } from './ItemSearchInput'
import { ItemPopup } from './ItemPopup'
import { NumberInput } from './NumberInput'
import { flyCoin } from '../lib/flyCoin'
import { useToast } from '../context/ToastContext'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  player: Player
  items: Item[]
  itemsByName: Map<string, Item>
  playerItems: ReturnType<typeof usePlayerItems>
}

function PokedollarRow({ itemsByName, playerItems }: Pick<Props, 'itemsByName' | 'playerItems'>) {
  const pokedollarItem = itemsByName.get(POKEDOLLAR_ITEM_NAME)
  const { pokedollars, setPokedollars } = playerItems

  return (
    <div className="flex items-center gap-3 bg-gray-800 border-2 border-yellow-600 rounded-lg p-3 mb-4">
      <div className="w-10 h-10 shrink-0 flex items-center justify-center">
        {pokedollarItem?.image_url ? (
          <img src={pokedollarItem.image_url} alt="" className="w-full h-full object-contain" />
        ) : (
          <span className="text-2xl">💰</span>
        )}
      </div>
      <span className="text-yellow-300 font-bold flex-1">Pokédollars</span>
      <div className="flex items-center gap-2">
        <button
          onClick={() => setPokedollars(pokedollars - 1)}
          className={`w-8 h-8 rounded font-bold ${BUTTON_STYLE.gray}`}
        >
          −
        </button>
        <NumberInput
          min={0}
          value={pokedollars}
          onCommit={(v) => setPokedollars(Math.max(0, v))}
          className="w-16 text-center bg-gray-900 border border-gray-700 rounded py-1 text-white"
        />
        <button
          onClick={() => setPokedollars(pokedollars + 1)}
          className={`w-8 h-8 rounded font-bold ${BUTTON_STYLE.gray}`}
        >
          +
        </button>
      </div>
    </div>
  )
}

export function SacTab({ items, itemsByName, playerItems }: Props) {
  const { inventory, addItem, setQuantity, sellOne } = playerItems
  const { showToast } = useToast()
  const [selectedId, setSelectedId] = useState<number | null>(null)

  const ownedItems = useMemo(
    () =>
      inventory
        .filter((r) => r.item_nom !== POKEDOLLAR_ITEM_NAME)
        .sort((a, b) => a.item_nom.localeCompare(b.item_nom, 'fr')),
    [inventory]
  )

  const selectedRow = selectedId != null ? inventory.find((r) => r.id === selectedId) : undefined

  const handleSelectItem = (item: Item) => {
    addItem(item.nom)
    showToast(`${item.nom} ajouté au Sac !`)
  }

  const pokedollarImageUrl = itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url

  const handleSell = (row: PlayerItem, rect: DOMRect) => {
    const item = itemsByName.get(row.item_nom)
    if (!item) return
    const value = sellValue(item.cout)
    flyCoin(rect, value, pokedollarImageUrl)
    sellOne(row, value)
  }

  return (
    <div className="flex-1 overflow-y-auto p-4">
      <div className="max-w-md mb-4">
        <ItemSearchInput options={items} onSelect={handleSelectItem} />
      </div>

      <PokedollarRow itemsByName={itemsByName} playerItems={playerItems} />

      {ownedItems.length === 0 ? (
        <p className="text-gray-500 text-sm text-center mt-8">Votre sac est vide.</p>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-3">
          {ownedItems.map((row) => {
            const item = itemsByName.get(row.item_nom)
            return (
              <button
                key={row.id}
                onClick={() => setSelectedId(row.id)}
                className="flex items-center gap-3 bg-gray-800 border border-gray-700 rounded-lg p-3 hover:bg-gray-700 transition-colors text-left"
              >
                <div className="w-10 h-10 shrink-0 flex items-center justify-center">
                  {item?.image_url ? (
                    <img src={item.image_url} alt="" className="w-full h-full object-contain" />
                  ) : (
                    <span className="text-2xl">{item ? '🎒' : '❓'}</span>
                  )}
                </div>
                <span className="text-white text-sm flex-1 truncate">{row.item_nom}</span>
                <span className="text-gray-400 text-sm font-bold">×{row.quantity}</span>
              </button>
            )
          })}
        </div>
      )}

      {selectedRow && (
        <ItemPopup
          row={selectedRow}
          item={itemsByName.get(selectedRow.item_nom)}
          pokedollarImageUrl={pokedollarImageUrl}
          onSetQuantity={(q) => setQuantity(selectedRow, q)}
          onSell={(rect) => handleSell(selectedRow, rect)}
          onClose={() => setSelectedId(null)}
        />
      )}
    </div>
  )
}
