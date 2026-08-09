import type { Item, Pokemon, Trade } from '../../types'
import { isItemsPayload, tradeStatusLabel } from '../../lib/trade'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'

interface Props {
  trade: Trade
  itemsByName: Map<string, Item>
  pokemonByName: Map<string, Pokemon>
  onClick: () => void
}

function ItemsSummary({ items, itemsByName }: { items: { item_nom: string; quantity: number }[]; itemsByName: Map<string, Item> }) {
  if (items.length === 0) return <span className="text-ink-muted-2 italic">rien</span>
  return (
    <span className="inline-flex flex-wrap items-center gap-1">
      {items.map((e) => {
        const item = itemsByName.get(e.item_nom)
        return (
          <span key={e.item_nom} className="inline-flex items-center gap-0.5 bg-cream-secondary rounded px-1">
            {item?.image_url && <img src={item.image_url} alt="" className="w-4 h-4 object-contain pixelated" />}
            ×{e.quantity} {item?.nom ?? e.item_nom}
          </span>
        )
      })}
    </span>
  )
}

export function PokemonSummary({ nom, nickname, pokemonByName }: { nom: string | null; nickname?: string | null; pokemonByName: Map<string, Pokemon> }) {
  const pokemon = nom ? pokemonByName.get(nom) : undefined
  return (
    <span className="inline-flex items-center gap-1 bg-cream-secondary rounded px-1">
      {pokemon?.image_miniature && <img src={pokemon.image_miniature} alt="" className="w-4 h-4 object-contain pixelated" />}
      {nom ? (nickname?.trim() || nom) : "n'importe quel Pokémon non possédé"}
    </span>
  )
}

export function TradeCard({ trade, itemsByName, pokemonByName, onClick }: Props) {
  const statusColor = trade.status === 'completed' ? 'text-green-700' : trade.status === 'cancelled' ? 'text-hp-red' : 'text-[#a3841a]'

  return (
    <button
      onClick={onClick}
      className={`max-w-[85%] rounded-lg px-3 py-2 text-left text-xs text-ink bg-white ${PIXEL_BORDER_SM} hover:bg-cream-secondary transition-colors`}
    >
      <div className="flex items-center gap-1.5 mb-1 font-bold">
        <span>🔄 Échange</span>
        <span className={`ml-auto ${statusColor}`}>{tradeStatusLabel(trade.status)}</span>
      </div>
      {trade.kind === 'item' && isItemsPayload(trade.offer) && isItemsPayload(trade.request) ? (
        <p className="leading-relaxed">
          Propose <ItemsSummary items={trade.offer.items} itemsByName={itemsByName} /> contre <ItemsSummary items={trade.request.items} itemsByName={itemsByName} />
        </p>
      ) : !isItemsPayload(trade.offer) ? (
        <p className="leading-relaxed">
          Propose <PokemonSummary nom={trade.offer.pokemon_nom} nickname={trade.offer.nickname} pokemonByName={pokemonByName} /> contre{' '}
          <PokemonSummary nom={isItemsPayload(trade.request) ? null : trade.request.pokemon_nom} pokemonByName={pokemonByName} />
        </p>
      ) : null}
      <p className="text-ink-muted-2 mt-1">Toucher pour voir / répondre</p>
    </button>
  )
}
