import type { Player, Pokemon, Trade } from '../../types'
import { isItemsPayload } from '../../lib/trade'
import { PokemonSummary } from './TradeCard'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  trade: Trade
  players: Player[]
  pokemonByName: Map<string, Pokemon>
  onReplay: () => void
}

// Message de conclusion d'un échange Pokémon (distinct de la carte de
// proposition TradeCard) : phrase + bouton "Voir l'échange" qui rejoue
// l'animation de swap, visible par n'importe qui dans le chat.
export function TradeCompletedCard({ trade, players, pokemonByName, onReplay }: Props) {
  if (trade.kind !== 'pokemon' || isItemsPayload(trade.offer)) return null

  const proposer = players.find((p) => p.id === trade.proposer_id)
  const accepter = players.find((p) => p.id === trade.accepted_by)

  return (
    <div className={`max-w-[85%] rounded-lg px-3 py-2 text-xs text-ink bg-white ${PIXEL_BORDER_SM}`}>
      <p className="leading-relaxed">
        <span className="font-bold">{proposer?.name ?? 'Un joueur'}</span> a échangé son{' '}
        <PokemonSummary nom={trade.offer.pokemon_nom} nickname={trade.offer.nickname} pokemonByName={pokemonByName} /> contre le{' '}
        <PokemonSummary nom={trade.resolved_pokemon_nom} nickname={trade.resolved_pokemon_nickname} pokemonByName={pokemonByName} /> de{' '}
        <span className="font-bold">{accepter?.name ?? 'un joueur'}</span>
      </p>
      <button onClick={onReplay} className={`mt-2 w-full px-2 py-1 rounded text-xs font-bold ${BUTTON_STYLE.blue}`}>
        Voir l'échange
      </button>
    </div>
  )
}
