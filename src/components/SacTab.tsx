import { useState, useMemo } from 'react'
import type { Item, Player, PlayerItem } from '../types'
import { POKEDOLLAR_ITEM_NAME, sellValue } from '../types'
import { usePlayerItems } from '../hooks/usePlayerItems'
import { ItemSearchInput } from './ItemSearchInput'
import { ItemPopup } from './ItemPopup'
import { NumberInput } from './NumberInput'
import { Chip } from './Chip'
import { flyCoin } from '../lib/flyCoin'
import { useToast } from '../context/ToastContext'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PANEL } from '../lib/panelStyles'

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
    <div className={`${PANEL} flex items-center gap-3 p-3 mb-3.5`}>
      <div className="w-10 h-10 shrink-0 flex items-center justify-center">
        {pokedollarItem?.image_url ? (
          <img src={pokedollarItem.image_url} alt="" className="w-full h-full object-contain" />
        ) : (
          <span className="text-2xl">💰</span>
        )}
      </div>
      <span className="text-ink font-bold flex-1">Pokédollars</span>
      <div className="flex items-center gap-2">
        <button
          onClick={() => setPokedollars(pokedollars - 1)}
          className={`w-8 h-8 rounded-md font-bold ${BUTTON_STYLE.gray}`}
        >
          −
        </button>
        <NumberInput
          min={0}
          value={pokedollars}
          onCommit={(v) => setPokedollars(Math.max(0, v))}
          className="w-16 text-center bg-white border-2 border-ink rounded-md py-1 text-ink"
        />
        <button
          onClick={() => setPokedollars(pokedollars + 1)}
          className={`w-8 h-8 rounded-md font-bold ${BUTTON_STYLE.gray}`}
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
  const [category, setCategory] = useState('Tous')

  const ownedItems = useMemo(
    () =>
      inventory
        .filter((r) => r.item_nom !== POKEDOLLAR_ITEM_NAME)
        .sort((a, b) => a.item_nom.localeCompare(b.item_nom, 'fr')),
    [inventory]
  )

  // Catégories réelles présentes dans le sac (champ `type` du catalogue)
  const categories = useMemo(() => {
    const types = new Set<string>()
    for (const row of ownedItems) {
      const t = itemsByName.get(row.item_nom)?.type
      if (t) types.add(t)
    }
    return ['Tous', ...[...types].sort((a, b) => a.localeCompare(b, 'fr'))]
  }, [ownedItems, itemsByName])

  const filteredItems = useMemo(
    () =>
      category === 'Tous'
        ? ownedItems
        : ownedItems.filter((r) => itemsByName.get(r.item_nom)?.type === category),
    [ownedItems, category, itemsByName]
  )

  const ownedQty = useMemo(
    () => new Map(ownedItems.map((r) => [r.item_nom, r.quantity])),
    [ownedItems]
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
      <div className="max-w-md mb-3.5">
        <ItemSearchInput options={items} ownedQty={ownedQty} onSelect={handleSelectItem} />
      </div>

      <PokedollarRow itemsByName={itemsByName} playerItems={playerItems} />

      {categories.length > 1 && (
        <div className="flex gap-1.5 flex-wrap mb-3.5">
          {categories.map((c) => (
            <Chip key={c} label={c} active={category === c} onClick={() => setCategory(c)} />
          ))}
        </div>
      )}

      {filteredItems.length === 0 ? (
        <p className="text-[#7a7c9a] text-sm text-center mt-8">
          {ownedItems.length === 0 ? 'Votre sac est vide.' : 'Aucun objet dans cette catégorie.'}
        </p>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-2.5">
          {filteredItems.map((row) => {
            const item = itemsByName.get(row.item_nom)
            return (
              <div key={row.id} className={`${PANEL} flex items-center gap-2.5 p-2`}>
                <button
                  onClick={() => setSelectedId(row.id)}
                  className="flex items-center gap-2.5 flex-1 min-w-0 text-left"
                >
                  <div className="w-9 h-9 shrink-0 rounded-md border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
                    {item?.image_url ? (
                      <img src={item.image_url} alt="" className="max-w-[85%] max-h-[85%] object-contain" />
                    ) : (
                      <span className="text-xl">{item ? '🎒' : '❓'}</span>
                    )}
                  </div>
                  <span className="text-ink text-sm flex-1 truncate">{row.item_nom}</span>
                </button>
                <button
                  onClick={() => setQuantity(row, Math.max(0, row.quantity - 1))}
                  className={`w-7 h-7 rounded-md font-bold text-sm shrink-0 ${BUTTON_STYLE.gray}`}
                >
                  −
                </button>
                <span className="min-w-6 text-center text-ink text-sm font-bold shrink-0">{row.quantity}</span>
                <button
                  onClick={() => setQuantity(row, row.quantity + 1)}
                  className={`w-7 h-7 rounded-md font-bold text-sm shrink-0 ${BUTTON_STYLE.gray}`}
                >
                  +
                </button>
              </div>
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
