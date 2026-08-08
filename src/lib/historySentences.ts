import type { Player, Pokemon, Item, HistoryInventoryPayload, HistoryPokedexPayload, HistoryTeamPayload, HistoryCombatPayload, HistoryMinigamePayload, HistoryMiningPayload, HistoryDaycarePayload, HistorySafariPayload } from '../types'
import { POKEDOLLAR_ITEM_NAME, TICKET_CASINO_ITEM_NAME, TICKET_TREMPETTE_ITEM_NAME, TICKET_MINING_ITEM_NAME } from '../types'
import type { ReferenceEntry } from '../hooks/useReferenceIndex'
import { getStatusInfo } from './status'
import type { DisplayHistoryEntry } from './historyGrouping'

// `ref.name` reste toujours le nom canonique (catalogue/espèce) pour que
// ReferenceDispatcher puisse le résoudre via playersByName/itemsByName/
// pokemonByName — `label` porte le texte affiché quand il diffère (pluriel).
export type SentencePart = { text: string } | { ref: ReferenceEntry; label?: string }

export interface SentenceContext {
  playersById: Map<number, Player>
  pokemonByName: Map<string, Pokemon>
  itemsByName: Map<string, Item>
}

function partLabel(part: SentencePart): string {
  return 'text' in part ? part.text : part.label ?? part.ref.name
}

export function sentenceToPlainText(parts: SentencePart[]): string {
  return parts.map(partLabel).join('')
}

function playerPart(ctx: SentenceContext, playerId: number): SentencePart {
  const p = ctx.playersById.get(playerId)
  if (!p) return { text: 'Joueur inconnu' }
  return { ref: { type: 'player', id: p.id, name: p.name, icon: p.image_url || undefined } }
}

function pokemonPart(ctx: SentenceContext, pokemonNom: string): SentencePart {
  const p = ctx.pokemonByName.get(pokemonNom)
  if (!p) return { text: pokemonNom }
  return { ref: { type: 'pokemon', id: p.id, name: p.nom, icon: p.image_miniature || undefined } }
}

// Pluriel géré uniquement pour les deux pseudo-objets qu'on contrôle
// (Pokédollar/Ticket Casino) — pas de données de genre/pluriel pour le
// catalogue d'objets libre, on garde le nom singulier tel quel.
function pluralItemLabel(itemNom: string, n: number): string {
  if (n === 1) return itemNom
  if (itemNom === POKEDOLLAR_ITEM_NAME) return 'Pokédollars'
  if (itemNom === TICKET_CASINO_ITEM_NAME) return 'Tickets Casino'
  if (itemNom === TICKET_TREMPETTE_ITEM_NAME) return 'Tickets Trempette'
  if (itemNom === TICKET_MINING_ITEM_NAME) return 'Tickets Fouille'
  return itemNom
}

function itemPart(ctx: SentenceContext, itemNom: string, n: number): SentencePart {
  const label = pluralItemLabel(itemNom, n)
  if (itemNom === POKEDOLLAR_ITEM_NAME) return { text: label } // pas de fiche catalogue
  const item = ctx.itemsByName.get(itemNom)
  if (!item) return { text: label }
  return { ref: { type: 'item', id: item.id, name: item.nom, icon: item.image_url ?? undefined }, label }
}

function inventorySentence(entry: DisplayHistoryEntry, ctx: SentenceContext): SentencePart[] {
  const payload = entry.payload as HistoryInventoryPayload
  const player = playerPart(ctx, entry.player_id)
  const totalSuffix: SentencePart = { text: ` (total : ${payload.total})` }

  switch (entry.action_type) {
    case 'item_add':
      return [player, { text: ' a ajouté ' }, { text: `${payload.delta} ` }, itemPart(ctx, payload.item_nom, payload.delta), { text: ' à son inventaire depuis ' }, { text: payload.source }, totalSuffix]
    case 'item_remove':
      return [player, { text: ' a retiré ' }, { text: `${payload.delta} ` }, itemPart(ctx, payload.item_nom, payload.delta), { text: ' à son inventaire depuis ' }, { text: payload.source }, totalSuffix]
    case 'item_sale':
      return [player, { text: ' a ajouté ' }, { text: `${payload.delta} ` }, itemPart(ctx, payload.item_nom, payload.delta), { text: ' à son inventaire depuis ' }, { text: payload.source }, totalSuffix]
    case 'item_gift':
      return [player, { text: ' a reçu ' }, { text: `${payload.delta} ` }, itemPart(ctx, payload.item_nom, payload.delta), { text: ' de la part de ' }, { text: payload.source }, { text: ' en cadeau' }, totalSuffix]
    case 'item_casino_win':
      return [player, { text: ' a gagné ' }, { text: `${payload.delta} ` }, itemPart(ctx, payload.item_nom, payload.delta), { text: ' au jeu de Casino ' }, { text: payload.source }, totalSuffix]
    case 'item_casino_spend':
      return [player, { text: ' a dépensé ' }, { text: `${payload.delta} ` }, itemPart(ctx, payload.item_nom, payload.delta), { text: ' au jeu de Casino ' }, { text: payload.source }, totalSuffix]
    case 'item_minigame_spend':
      return [player, { text: ' a dépensé ' }, { text: `${payload.delta} ` }, itemPart(ctx, payload.item_nom, payload.delta), { text: ' au jeu ' }, { text: payload.source }, totalSuffix]
    case 'item_mining_spend':
      return [player, { text: ' a dépensé ' }, { text: `${payload.delta} ` }, itemPart(ctx, payload.item_nom, payload.delta), { text: ' au jeu ' }, { text: payload.source }, totalSuffix]
    default:
      return [player, { text: ' a modifié son inventaire' }, totalSuffix]
  }
}

function pokedexSentence(entry: DisplayHistoryEntry, ctx: SentenceContext): SentencePart[] {
  const payload = entry.payload as HistoryPokedexPayload
  return [
    playerPart(ctx, entry.player_id),
    { text: ' a ajouté ' },
    pokemonPart(ctx, payload.pokemon_nom),
    { text: ' au Pokédex ' },
    { text: `(total : ${payload.total})` },
  ]
}

function teamSentence(entry: DisplayHistoryEntry, ctx: SentenceContext): SentencePart[] {
  const payload = entry.payload as HistoryTeamPayload
  const destinationLabel = payload.destination === 'team' ? 'équipe' : 'PC'
  const player = playerPart(ctx, entry.player_id)
  const pokemon = pokemonPart(ctx, payload.pokemon_nom)

  if (entry.action_type === 'pokemon_new') {
    return [player, { text: ' a obtenu ' }, pokemon, { text: `, ajouté à son ${destinationLabel}` }]
  }
  if (entry.action_type === 'pokemon_evolve') {
    const toPokemon = payload.to_pokemon_nom ? pokemonPart(ctx, payload.to_pokemon_nom) : { text: '???' }
    return [player, { text: ' : ' }, pokemon, { text: ' a évolué en ' }, toPokemon]
  }
  return [player, { text: ' a placé ' }, pokemon, { text: ` dans son ${destinationLabel}` }]
}

function combatSentence(entry: DisplayHistoryEntry, ctx: SentenceContext): SentencePart[] {
  const payload = entry.payload as HistoryCombatPayload
  const player = playerPart(ctx, entry.player_id)
  const pokemon = pokemonPart(ctx, payload.pokemon_nom)

  if (entry.action_type === 'ko') {
    return [player, { text: ' : ' }, pokemon, { text: payload.ko ? ' est K.O.' : " n'est plus K.O." }]
  }

  const label = payload.status_id ? getStatusInfo(payload.status_id).label : ''
  const lowered = label ? label.charAt(0).toLowerCase() + label.slice(1) : ''
  return [player, { text: ' : ' }, pokemon, { text: payload.status_gained ? ` est ${lowered}` : ` n'est plus ${lowered}` }]
}

function minigameSentence(entry: DisplayHistoryEntry, ctx: SentenceContext): SentencePart[] {
  const player = playerPart(ctx, entry.player_id)

  if (entry.action_type === 'mining_item_found') {
    const payload = entry.payload as HistoryMiningPayload
    return [player, { text: ' a déterré ' }, itemPart(ctx, payload.item_nom, 1), { text: ' !' }]
  }

  const payload = entry.payload as HistoryMinigamePayload
  const pokemon = pokemonPart(ctx, payload.pokemon_nom)
  const starsLabel = `${payload.stars} étoile${payload.stars > 1 ? 's' : ''}`
  return [
    player, { text: ' : ' }, pokemon, { text: ' a gagné ' }, { text: `${payload.xp_delta} XP` },
    { text: ` au jeu ${payload.game_nom} (score : ${payload.score}, ${starsLabel})` },
  ]
}

function daycareSentence(entry: DisplayHistoryEntry, ctx: SentenceContext): SentencePart[] {
  const payload = entry.payload as HistoryDaycarePayload
  const player = playerPart(ctx, entry.player_id)
  const pokemonRef = pokemonPart(ctx, payload.pokemon_nom)

  if (entry.action_type === 'daycare_drop_off') {
    return [player, { text: ' a déposé ' }, pokemonRef, { text: ' à la Pension Pokémon' }]
  }
  if (entry.action_type === 'daycare_pickup') {
    return [player, { text: ' a récupéré ' }, pokemonRef, { text: ' à la Pension Pokémon' }]
  }
  if (entry.action_type === 'daycare_pair_formed') {
    const partner = payload.partner_pokemon_nom ? pokemonPart(ctx, payload.partner_pokemon_nom) : { text: '???' }
    return [player, { text: ' : ' }, pokemonRef, { text: ' est compatible avec ' }, partner, { text: ' à la Pension Pokémon' }]
  }
  // daycare_egg_received
  const parentA = payload.parent_a_nom ? pokemonPart(ctx, payload.parent_a_nom) : { text: '???' }
  const parentB = payload.parent_b_nom ? pokemonPart(ctx, payload.parent_b_nom) : { text: '???' }
  return [player, { text: ' a reçu un œuf (' }, pokemonRef, { text: ') de ' }, parentA, { text: ' et ' }, parentB, { text: ' à la Pension Pokémon' }]
}

function safariSentence(entry: DisplayHistoryEntry, ctx: SentenceContext): SentencePart[] {
  const payload = entry.payload as HistorySafariPayload
  const player = playerPart(ctx, entry.player_id)
  const pokemonRef = pokemonPart(ctx, payload.pokemon_nom)

  if (entry.action_type === 'safari_berry_throw') {
    const delta = (payload.gauge_after ?? 0) - (payload.gauge_before ?? 0)
    return [player, { text: ' a lancé une Baie Framby sur ' }, pokemonRef, { text: ` au Safari (+${delta})` }]
  }
  if (entry.action_type === 'safari_capture') {
    return [player, { text: ' a capturé ' }, pokemonRef, { text: ' au Safari' }]
  }
  // safari_flee
  return [pokemonRef, { text: ' a fui le Safari (tentative de ' }, player, { text: ')' }]
}

export function buildSentenceParts(entry: DisplayHistoryEntry, ctx: SentenceContext): SentencePart[] {
  switch (entry.category) {
    case 'inventory':
      return inventorySentence(entry, ctx)
    case 'pokedex':
      return pokedexSentence(entry, ctx)
    case 'team':
      return teamSentence(entry, ctx)
    case 'combat':
      return combatSentence(entry, ctx)
    case 'minigame':
      return minigameSentence(entry, ctx)
    case 'daycare':
      return daycareSentence(entry, ctx)
    case 'safari':
      return safariSentence(entry, ctx)
    default:
      return [{ text: '' }]
  }
}
