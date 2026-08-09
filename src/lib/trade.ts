import type { Item, Player, Pokemon, PlayerItem, PlayerPokemon, Trade, TradeItemEntry, TradeItemsPayload, TradePokemonOfferPayload, TradePokemonRequestPayload, ChatMessage } from '../types'
import { POKEDOLLAR_ITEM_NAME } from '../types'

export function isItemsPayload(payload: Trade['offer'] | Trade['request']): payload is TradeItemsPayload {
  return 'items' in payload
}

function describeItems(items: TradeItemEntry[], itemsByName: Map<string, Item>): string {
  if (items.length === 0) return 'rien'
  return items
    .map((e) => {
      const label = e.item_nom === POKEDOLLAR_ITEM_NAME ? 'Pokédollar' : (itemsByName.get(e.item_nom)?.nom ?? e.item_nom)
      return `${e.quantity} ${label}`
    })
    .join(', ')
}

// Texte de repli stocké comme content du message chat (journal/historique/notifications) —
// le rendu riche de la bulle (TradeCard) ne s'appuie pas sur ce texte.
export function tradeFallbackText(
  kind: Trade['kind'],
  offer: Trade['offer'],
  request: Trade['request'],
  itemsByName: Map<string, Item>
): string {
  if (kind === 'item' && isItemsPayload(offer) && isItemsPayload(request)) {
    return `Propose ${describeItems(offer.items, itemsByName)} contre ${describeItems(request.items, itemsByName)}`
  }
  const offerPayload = offer as TradePokemonOfferPayload
  const requestPayload = request as TradePokemonRequestPayload
  const offeredLabel = offerPayload.nickname?.trim() || offerPayload.pokemon_nom
  const requestedLabel = requestPayload.pokemon_nom ?? "n'importe quel Pokémon non possédé"
  return `Propose ${offeredLabel} contre ${requestedLabel}`
}

// Le joueur possède-t-il tout ce qui est demandé côté objets ? (pour activer "Accepter l'échange")
export function hasAllItems(items: TradeItemEntry[], inventory: PlayerItem[]): boolean {
  return items.every((e) => (inventory.find((r) => r.item_nom === e.item_nom)?.quantity ?? 0) >= e.quantity)
}

// Le joueur possède-t-il une instance correspondant à l'espèce précise demandée ?
// Pour une demande "n'importe quel Pokémon non possédé", on ne connaît pas le
// roster du proposeur côté client (vie privée) : on propose tout le roster du
// joueur ici, trade_accept revalide l'éligibilité ('already_owned') côté serveur.
export function matchingOwnedPokemon(request: TradePokemonRequestPayload, roster: PlayerPokemon[]): PlayerPokemon[] {
  if (request.pokemon_nom) {
    return roster.filter((r) => r.pokemon_nom === request.pokemon_nom)
  }
  return roster
}

export function tradeStatusLabel(status: Trade['status']): string {
  if (status === 'completed') return 'Terminé'
  if (status === 'cancelled') return 'Annulé'
  return 'En attente'
}

export function findTradeForMessage(message: ChatMessage, trades: Trade[]): Trade | undefined {
  return message.trade_id != null ? trades.find((t) => t.id === message.trade_id) : undefined
}

// Texte de repli du message de conclusion ("[Proposeur] a échangé son [X] contre
// le [Y] de [Accepteur]") — le rendu riche de la bulle (TradeCompletedCard) ne
// s'appuie pas sur ce texte, réservé au journal/historique/notifications.
export function tradeCompletedFallbackText(trade: Trade, players: Player[]): string {
  if (trade.kind !== 'pokemon' || isItemsPayload(trade.offer)) return 'Échange conclu'
  const proposer = players.find((p) => p.id === trade.proposer_id)
  const accepter = players.find((p) => p.id === trade.accepted_by)
  const offeredLabel = trade.offer.nickname?.trim() || trade.offer.pokemon_nom
  const acceptedLabel = trade.resolved_pokemon_nickname?.trim() || trade.resolved_pokemon_nom || '???'
  return `${proposer?.name ?? 'Un joueur'} a échangé son ${offeredLabel} contre le ${acceptedLabel} de ${accepter?.name ?? 'un joueur'}`
}

export interface SwapAnimProps {
  leftPlayer: Player
  rightPlayer: Player
  leftPokemon: Pokemon | undefined
  leftNickname: string | null
  rightPokemon: Pokemon | undefined
  rightNickname: string | null
}

// Reconstruit les props de TradeSwapAnimation depuis un échange Pokémon déjà
// conclu (pour le rejeu via "Voir l'échange", indépendamment de qui regarde) —
// left = ce que l'acceptant a cédé (résolu à l'acceptation), right = ce que le
// proposeur avait mis en jeu (dénormalisé à la création), même convention que
// TradePopup.handleAccept.
export function buildSwapAnimProps(trade: Trade, players: Player[], pokemonByName: Map<string, Pokemon>): SwapAnimProps | null {
  if (trade.kind !== 'pokemon' || trade.status !== 'completed' || trade.accepted_by == null || isItemsPayload(trade.offer)) return null
  const accepter = players.find((p) => p.id === trade.accepted_by)
  const proposer = players.find((p) => p.id === trade.proposer_id)
  if (!accepter || !proposer) return null
  return {
    leftPlayer: accepter,
    rightPlayer: proposer,
    leftPokemon: trade.resolved_pokemon_nom ? pokemonByName.get(trade.resolved_pokemon_nom) : undefined,
    leftNickname: trade.resolved_pokemon_nickname,
    rightPokemon: pokemonByName.get(trade.offer.pokemon_nom),
    rightNickname: trade.offer.nickname,
  }
}
