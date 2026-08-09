import { useMemo, useState } from 'react'
import type { Player, Item, Pokemon, Attack, PlayerItem, PlayerPokemon, Trade, TradeKind, TradeItemEntry, TradeItemsPayload, TradePokemonRequestPayload, TradeAcceptStatus } from '../../types'
import { TRADE_MAX_ITEMS } from '../../types'
import type { useTrades } from '../../hooks/useTrades'
import type { useChatMessages } from '../../hooks/useChatMessages'
import { isItemsPayload, hasAllItems, matchingOwnedPokemon, tradeFallbackText, tradeStatusLabel } from '../../lib/trade'
import { normalizeSearch } from '../../lib/normalizeSearch'
import { PokemonDetailSheet } from '../PokemonDetailSheet'
import { NumberInput } from '../NumberInput'
import { TradeSwapAnimation } from './TradeSwapAnimation'
import { CloseIcon } from '../icons/CloseIcon'
import { PixelIcon } from '../icons/PixelIcon'
import { NAV_ICON } from '../../lib/icons'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  player: Player
  players: Player[]
  inventory: PlayerItem[]
  roster: PlayerPokemon[]
  itemsByName: Map<string, Item>
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  trades: ReturnType<typeof useTrades>
  chat: ReturnType<typeof useChatMessages>
  existingTrade?: Trade
  onClose: () => void
}

interface SwapAnimState {
  leftPokemon: Pokemon | undefined
  leftNickname: string | null
  rightPokemon: Pokemon | undefined
  rightNickname: string | null
}

const ACCEPT_ERROR_LABEL: Record<Exclude<TradeAcceptStatus, 'ok'>, string> = {
  not_found: "Cet échange n'existe plus.",
  already_resolved: 'Cet échange a déjà été conclu ou annulé.',
  cannot_accept_own: 'Tu ne peux pas accepter ta propre offre.',
  offer_no_longer_available: "Le proposeur ne possède plus ce qu'il proposait.",
  insufficient_items: 'Il te manque des objets pour accepter.',
  no_pokemon_chosen: 'Choisis un Pokémon à donner en échange.',
  not_owner: "Ce Pokémon ne t'appartient plus.",
  wrong_species: "L'espèce choisie ne correspond pas à la demande.",
  already_owned: 'Le proposeur possède déjà cette espèce — choisis-en une autre.',
  error: "Une erreur est survenue, réessaie.",
}

function ItemChip({ entry, item, onRemove, onQuantityChange, max }: {
  entry: TradeItemEntry
  item: Item | undefined
  onRemove?: () => void
  onQuantityChange?: (q: number) => void
  max?: number
}) {
  return (
    <div className="flex items-center gap-2 bg-white border-2 border-ink rounded-lg px-2 py-1.5 min-w-0">
      {item?.image_url ? (
        <img src={item.image_url} alt="" className="w-6 h-6 object-contain pixelated shrink-0" />
      ) : (
        <span className="text-lg shrink-0">🎒</span>
      )}
      <span className="flex-1 min-w-0 text-ink text-xs font-bold truncate">{item?.nom ?? entry.item_nom}</span>
      {onQuantityChange ? (
        <div className="flex items-center gap-1 shrink-0">
          <button onClick={() => onQuantityChange(entry.quantity - 1)} className="w-5 h-5 rounded bg-cream-secondary border border-ink text-ink text-xs font-bold">−</button>
          <NumberInput
            value={entry.quantity}
            min={1}
            fallback={1}
            onCommit={(q) => onQuantityChange(Math.max(1, max != null ? Math.min(q, max) : q))}
            className="w-10 bg-cream-secondary border border-ink rounded text-ink text-xs font-bold text-center"
          />
          <button
            onClick={() => onQuantityChange(entry.quantity + 1)}
            disabled={max != null && entry.quantity >= max}
            className="w-5 h-5 rounded bg-cream-secondary border border-ink text-ink text-xs font-bold disabled:opacity-40"
          >+</button>
        </div>
      ) : (
        <span className="text-ink text-xs font-bold shrink-0">×{entry.quantity}</span>
      )}
      {onRemove && (
        <button onClick={onRemove} className="w-5 h-5 rounded bg-cream-secondary border border-ink text-ink text-xs shrink-0">✕</button>
      )}
    </div>
  )
}

function ItemAddSearch({ candidates, itemsByName, onAdd }: { candidates: { item_nom: string; max?: number }[]; itemsByName: Map<string, Item>; onAdd: (itemNom: string) => void }) {
  const [query, setQuery] = useState('')
  const matches = useMemo(() => {
    const q = normalizeSearch(query.trim())
    if (!q) return []
    return candidates.filter((c) => normalizeSearch(itemsByName.get(c.item_nom)?.nom ?? c.item_nom).includes(q)).slice(0, 8)
  }, [query, candidates, itemsByName])

  return (
    <div className="relative">
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Ajouter un objet…"
        className="w-full bg-white border-2 border-ink rounded-lg px-3 py-1.5 text-ink text-sm placeholder-ink-muted-2 outline-none"
      />
      {query && (
        <div className="absolute z-10 top-full left-0 right-0 mt-1 bg-cream border-2 border-ink rounded-lg shadow-[var(--shadow-pixel)] max-h-48 overflow-y-auto">
          {matches.length === 0 ? (
            <p className="text-ink-muted-2 text-xs px-3 py-2">Aucun résultat</p>
          ) : (
            matches.map((c) => {
              const item = itemsByName.get(c.item_nom)
              return (
                <button
                  key={c.item_nom}
                  onClick={() => { onAdd(c.item_nom); setQuery('') }}
                  className="w-full flex items-center gap-2 px-3 py-2 border-b border-[#cfc7a8] last:border-b-0 hover:bg-cream-secondary transition-colors text-left"
                >
                  {item?.image_url ? <img src={item.image_url} alt="" className="w-5 h-5 object-contain pixelated" /> : <span>🎒</span>}
                  <span className="flex-1 text-ink text-sm truncate">{item?.nom ?? c.item_nom}</span>
                  {c.max != null && <span className="text-ink-muted-2 text-xs shrink-0">×{c.max}</span>}
                </button>
              )
            })
          )}
        </div>
      )}
    </div>
  )
}

function PokemonListRow({ pp, pokemonByName, selected, onSelect, onInfo }: {
  pp: PlayerPokemon
  pokemonByName: Map<string, Pokemon>
  selected: boolean
  onSelect: () => void
  onInfo: () => void
}) {
  const pokemon = pokemonByName.get(pp.pokemon_nom)
  return (
    <div className={`flex items-center gap-2 pl-1 pr-2 py-1 rounded-lg border-2 ${selected ? 'border-hp-orange bg-cream-secondary' : 'border-ink bg-white'}`}>
      <button onClick={onSelect} className="flex items-center gap-2 flex-1 min-w-0 text-left py-0.5">
        <div className="w-8 h-8 flex items-center justify-center shrink-0">
          {pokemon?.image_miniature ? (
            <img src={pokemon.image_miniature} alt="" className="w-full h-full object-contain pixelated" />
          ) : (
            <span className="text-xl">❓</span>
          )}
        </div>
        <span className="text-ink text-xs font-bold truncate">{pp.nickname?.trim() || pp.pokemon_nom}</span>
      </button>
      <button
        onClick={onInfo}
        title="Plus d'infos"
        className="w-6 h-6 rounded-full border-2 border-ink bg-cream-secondary text-ink text-xs font-bold shrink-0 flex items-center justify-center"
      >
        i
      </button>
    </div>
  )
}

function PokemonTile({ nom, nickname, pokemonByName, selected, onClick, placeholder }: {
  nom: string | null
  nickname?: string | null
  pokemonByName: Map<string, Pokemon>
  selected?: boolean
  onClick?: () => void
  placeholder?: string
}) {
  const pokemon = nom ? pokemonByName.get(nom) : undefined
  const Tag = onClick ? 'button' : 'div'
  return (
    <Tag
      onClick={onClick}
      className={`flex flex-col items-center gap-1 p-2 rounded-lg border-2 ${selected ? 'border-hp-orange bg-cream-secondary' : 'border-ink bg-white'}`}
    >
      <div className="w-16 h-16 flex items-center justify-center">
        {nom ? (
          pokemon?.image_miniature ? (
            <img src={pokemon.image_miniature} alt={nom} className="w-full h-full object-contain pixelated" />
          ) : (
            <span className="text-3xl">❓</span>
          )
        ) : (
          <span className="text-3xl">❓</span>
        )}
      </div>
      <span className="text-ink text-xs font-bold text-center leading-tight">
        {nom ? (nickname?.trim() || nom) : (placeholder ?? '???')}
      </span>
    </Tag>
  )
}

export function TradePopup({ player, players, inventory, roster, itemsByName, pokemonByName, attacksByName, trades, chat, existingTrade, onClose }: Props) {
  const viewerIsProposer = existingTrade ? existingTrade.proposer_id === player.id : false
  const isPending = existingTrade ? existingTrade.status === 'pending' : true

  const [kind, setKind] = useState<TradeKind | null>(existingTrade?.kind ?? null)
  const [editing, setEditing] = useState(!existingTrade)

  const initialSelfItems = existingTrade && isItemsPayload(existingTrade.request) ? existingTrade.request.items : []
  const initialWantItems = existingTrade && isItemsPayload(existingTrade.offer) ? existingTrade.offer.items : []
  const [selfItems, setSelfItems] = useState<TradeItemEntry[]>(initialSelfItems)
  const [wantItems, setWantItems] = useState<TradeItemEntry[]>(initialWantItems)

  const [selfPokemonId, setSelfPokemonId] = useState<number | null>(null)
  const initialWantRequest = existingTrade && !isItemsPayload(existingTrade.offer) ? (existingTrade.offer as { pokemon_nom: string }) : null
  const [wantPokemonNom, setWantPokemonNom] = useState<string | null>(initialWantRequest?.pokemon_nom ?? null)
  const [wantAny, setWantAny] = useState(false)
  const [pokemonQuery, setPokemonQuery] = useState('')

  const [submitting, setSubmitting] = useState(false)
  const [actionError, setActionError] = useState<string | null>(null)
  const [resultMessage, setResultMessage] = useState<string | null>(null)
  const [infoPokemon, setInfoPokemon] = useState<PlayerPokemon | null>(null)
  const [swapAnim, setSwapAnim] = useState<SwapAnimState | null>(null)

  const proposerPlayer = existingTrade ? players.find((p) => p.id === existingTrade.proposer_id) : undefined

  const startCounter = () => {
    if (!existingTrade) return
    if (existingTrade.kind === 'item' && isItemsPayload(existingTrade.offer) && isItemsPayload(existingTrade.request)) {
      setSelfItems(existingTrade.request.items)
      setWantItems(existingTrade.offer.items)
    } else if (existingTrade.kind === 'pokemon' && !isItemsPayload(existingTrade.offer)) {
      const offer = existingTrade.offer as { pokemon_nom: string }
      const request = existingTrade.request as TradePokemonRequestPayload
      setWantPokemonNom(offer.pokemon_nom)
      setWantAny(false)
      const matches = matchingOwnedPokemon(request, roster)
      setSelfPokemonId(matches[0]?.id ?? null)
    }
    setEditing(true)
  }

  const removeSelfItem = (itemNom: string) => setSelfItems((prev) => prev.filter((e) => e.item_nom !== itemNom))
  const removeWantItem = (itemNom: string) => setWantItems((prev) => prev.filter((e) => e.item_nom !== itemNom))

  const inventoryCandidates = useMemo(
    () => inventory.filter((r) => r.quantity > 0 && !selfItems.some((e) => e.item_nom === r.item_nom)).map((r) => ({ item_nom: r.item_nom, max: r.quantity })),
    [inventory, selfItems]
  )
  const catalogCandidates = useMemo(
    () => [...itemsByName.values()].filter((it) => !wantItems.some((e) => e.item_nom === it.nom)).map((it) => ({ item_nom: it.nom })),
    [itemsByName, wantItems]
  )

  // La recherche "Je veux" (espèce demandée à l'autre joueur) n'est pas limitée
  // aux espèces découvertes par le proposeur — contrairement aux références du
  // chat, ce n'est pas un spoiler de savoir qu'une espèce existe pour la demander
  // en échange. Seules les espèces cachées (admin) restent exclues.
  const requestablePokemonList = useMemo(
    () => [...pokemonByName.values()].filter((p) => !p.cache),
    [pokemonByName]
  )
  const pokemonMatches = useMemo(() => {
    const q = normalizeSearch(pokemonQuery.trim())
    if (!q) return []
    return requestablePokemonList.filter((p) => normalizeSearch(p.nom).includes(q)).slice(0, 8)
  }, [pokemonQuery, requestablePokemonList])

  const canSubmit = kind === 'item'
    ? selfItems.length > 0 && wantItems.length > 0
    : kind === 'pokemon'
      ? selfPokemonId != null && (wantAny || wantPokemonNom != null)
      : false

  const handleSubmit = async () => {
    if (!canSubmit || submitting) return
    setSubmitting(true)
    setActionError(null)
    try {
      if (kind === 'item') {
        const offer: TradeItemsPayload = { items: selfItems }
        const request: TradeItemsPayload = { items: wantItems }
        const trade = await trades.createItemTrade(player.id, offer, request)
        if (!trade) { setActionError("Erreur lors de la création de l'échange."); return }
        const text = tradeFallbackText('item', offer, request, itemsByName)
        await chat.sendTradeMessage(player.id, text, trade.id)
      } else if (kind === 'pokemon' && selfPokemonId != null) {
        const selfPp = roster.find((r) => r.id === selfPokemonId)
        if (!selfPp) { setActionError('Pokémon introuvable.'); return }
        const offer = { player_pokemon_id: selfPp.id, pokemon_nom: selfPp.pokemon_nom, nickname: selfPp.nickname }
        const request: TradePokemonRequestPayload = { pokemon_nom: wantAny ? null : wantPokemonNom }
        const trade = await trades.createPokemonTrade(player.id, offer, request)
        if (!trade) { setActionError("Erreur lors de la création de l'échange."); return }
        const text = tradeFallbackText('pokemon', offer, request, itemsByName)
        await chat.sendTradeMessage(player.id, text, trade.id)
      }
      onClose()
    } finally {
      setSubmitting(false)
    }
  }

  const handleAccept = async () => {
    if (!existingTrade || submitting) return
    setSubmitting(true)
    setActionError(null)
    try {
      const status = await trades.acceptTrade(existingTrade.id, player.id, existingTrade.kind === 'pokemon' ? (effectiveSelfPokemonId ?? undefined) : undefined)
      if (status === 'ok') {
        if (existingTrade.kind === 'pokemon' && !isItemsPayload(existingTrade.offer)) {
          const chosenPp = roster.find((r) => r.id === effectiveSelfPokemonId)
          setSwapAnim({
            leftPokemon: chosenPp ? pokemonByName.get(chosenPp.pokemon_nom) : undefined,
            leftNickname: chosenPp?.nickname ?? null,
            rightPokemon: pokemonByName.get(existingTrade.offer.pokemon_nom),
            rightNickname: existingTrade.offer.nickname,
          })

          // Message de conclusion (visible par tout le monde, avec "Voir l'échange")
          // + notification instantanée au proposeur, absent au moment de l'action.
          const offeredLabel = existingTrade.offer.nickname?.trim() || existingTrade.offer.pokemon_nom
          const acceptedLabel = chosenPp?.nickname?.trim() || chosenPp?.pokemon_nom || '???'
          const completedText = `${proposerPlayer?.name ?? 'Un joueur'} a échangé son ${offeredLabel} contre le ${acceptedLabel} de ${player.name}`
          void chat.sendTradeMessage(player.id, completedText, existingTrade.id, 'trade_completed')
          void fetch('/.netlify/functions/send-trade-notification', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ tradeId: existingTrade.id }),
          }).catch((err) => console.error("Erreur lors de l'envoi de la notification d'échange :", err))
        } else {
          setResultMessage('Échange conclu !')
        }
      } else {
        setActionError(ACCEPT_ERROR_LABEL[status])
      }
    } finally {
      setSubmitting(false)
    }
  }

  const handleCancel = async () => {
    if (!existingTrade || submitting) return
    setSubmitting(true)
    setActionError(null)
    try {
      const status = await trades.cancelTrade(existingTrade.id, player.id)
      if (status === 'ok') onClose()
      else setActionError("Impossible d'annuler cet échange.")
    } finally {
      setSubmitting(false)
    }
  }

  const acceptCandidates = useMemo(
    () => existingTrade?.kind === 'pokemon' && !isItemsPayload(existingTrade.request)
      ? matchingOwnedPokemon(existingTrade.request as TradePokemonRequestPayload, roster)
      : [],
    [existingTrade, roster]
  )

  // Présélection dérivée (pas de state/effet) : tant que le joueur n'a rien
  // choisi explicitement, l'unique candidat correspondant à la demande est
  // considéré sélectionné — plusieurs candidats nécessitent un choix explicite.
  const inAcceptFlow = !editing && existingTrade?.status === 'pending' && !viewerIsProposer && existingTrade?.kind === 'pokemon'
  const effectiveSelfPokemonId = inAcceptFlow && selfPokemonId == null && acceptCandidates.length === 1
    ? acceptCandidates[0].id
    : selfPokemonId

  const readOnlyRequestItems = existingTrade && isItemsPayload(existingTrade.request) ? existingTrade.request.items : []
  const readOnlyOfferItems = existingTrade && isItemsPayload(existingTrade.offer) ? existingTrade.offer.items : []
  const readOnlyItemsOk = hasAllItems(readOnlyRequestItems, inventory)

  return (
    <div className="fixed inset-0 z-[65] flex items-center justify-center bg-black/80 p-4" onClick={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className="bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-lg w-full min-h-[30rem] max-h-[92vh] flex flex-col overflow-hidden">
        <div className="flex items-center gap-2 p-3 border-b-2 border-[#cfc7a8] shrink-0">
          <span className="text-xl">🔄</span>
          <h3 className="text-ink font-bold flex-1">Échange</h3>
          {existingTrade && !editing && <span className="text-xs font-bold text-ink-muted">{tradeStatusLabel(existingTrade.status)}</span>}
          <button onClick={onClose} className={`w-8 h-8 rounded-md text-sm font-bold ${BUTTON_STYLE.gray}`}>
            <CloseIcon className="w-4 h-4 mx-auto" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {kind === null && (
            <div>
              <p className="text-ink-muted text-sm mb-3 text-center">Que veux-tu échanger ?</p>
              <div className="grid grid-cols-2 gap-3">
                <button
                  onClick={() => setKind('item')}
                  className="aspect-square rounded-lg border-2 sm:border-[3px] border-ink bg-gradient-to-br from-[#3ea0e0] to-[#0f4a7a] flex flex-col items-center justify-center gap-2 shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
                >
                  <PixelIcon src={NAV_ICON.sac!} size={40} colored className="text-white" />
                  <span className="text-white text-sm font-bold">Objets</span>
                </button>
                <button
                  onClick={() => setKind('pokemon')}
                  className="aspect-square rounded-lg border-2 sm:border-[3px] border-ink bg-gradient-to-br from-[#e0293f] to-[#7a0f1f] flex flex-col items-center justify-center gap-2 shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
                >
                  <PixelIcon src={NAV_ICON.equipe!} size={40} colored className="text-white" />
                  <span className="text-white text-sm font-bold">Pokémon</span>
                </button>
              </div>
            </div>
          )}

          {kind === 'item' && (
            <div className="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] gap-2 items-start">
              <div>
                <p className="text-ink-muted text-xs font-bold mb-2 text-center">Moi</p>
                <div className="space-y-1.5 min-h-[2.5rem]">
                  {(editing ? selfItems : readOnlyRequestItems).map((e) => (
                    <ItemChip
                      key={e.item_nom}
                      entry={e}
                      item={itemsByName.get(e.item_nom)}
                      onRemove={editing ? () => removeSelfItem(e.item_nom) : undefined}
                      onQuantityChange={editing ? (q) => setSelfItems((prev) => prev.map((x) => x.item_nom === e.item_nom ? { ...x, quantity: Math.max(1, q) } : x)) : undefined}
                      max={editing ? inventory.find((r) => r.item_nom === e.item_nom)?.quantity : undefined}
                    />
                  ))}
                  {!editing && readOnlyRequestItems.length === 0 && <p className="text-ink-muted-2 text-xs italic">Rien</p>}
                </div>
                {editing && selfItems.length < TRADE_MAX_ITEMS && (
                  <div className="mt-2">
                    <ItemAddSearch candidates={inventoryCandidates} itemsByName={itemsByName} onAdd={(nom) => setSelfItems((prev) => [...prev, { item_nom: nom, quantity: 1 }])} />
                  </div>
                )}
              </div>

              <div className="flex items-center justify-center h-full pt-8 text-2xl text-ink-muted-2">🔁</div>

              <div>
                <p className="text-ink-muted text-xs font-bold mb-2 text-center">Je veux</p>
                <div className="space-y-1.5 min-h-[2.5rem]">
                  {(editing ? wantItems : readOnlyOfferItems).map((e) => (
                    <ItemChip
                      key={e.item_nom}
                      entry={e}
                      item={itemsByName.get(e.item_nom)}
                      onRemove={editing ? () => removeWantItem(e.item_nom) : undefined}
                      onQuantityChange={editing ? (q) => setWantItems((prev) => prev.map((x) => x.item_nom === e.item_nom ? { ...x, quantity: Math.max(1, q) } : x)) : undefined}
                    />
                  ))}
                  {!editing && readOnlyOfferItems.length === 0 && <p className="text-ink-muted-2 text-xs italic">Rien</p>}
                </div>
                {editing && wantItems.length < TRADE_MAX_ITEMS && (
                  <div className="mt-2">
                    <ItemAddSearch candidates={catalogCandidates} itemsByName={itemsByName} onAdd={(nom) => setWantItems((prev) => [...prev, { item_nom: nom, quantity: 1 }])} />
                  </div>
                )}
              </div>
            </div>
          )}

          {kind === 'pokemon' && (
            <div className="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] gap-2 items-start">
              <div>
                <p className="text-ink-muted text-xs font-bold mb-2 text-center">Moi</p>
                {editing ? (
                  <div className="space-y-1.5 max-h-56 overflow-y-auto">
                    {roster.map((pp) => (
                      <PokemonListRow
                        key={pp.id}
                        pp={pp}
                        pokemonByName={pokemonByName}
                        selected={selfPokemonId === pp.id}
                        onSelect={() => setSelfPokemonId(pp.id)}
                        onInfo={() => setInfoPokemon(pp)}
                      />
                    ))}
                  </div>
                ) : existingTrade?.status === 'pending' && !viewerIsProposer ? (
                  acceptCandidates.length > 0 && (
                    <>
                      {acceptCandidates.length > 1 && (
                        <p className="text-ink-muted text-xs font-bold mb-1.5 text-center">Sélectionne le Pokémon à échanger</p>
                      )}
                      <div className="space-y-1.5 max-h-56 overflow-y-auto">
                        {acceptCandidates.map((pp) => (
                          <PokemonListRow
                            key={pp.id}
                            pp={pp}
                            pokemonByName={pokemonByName}
                            selected={effectiveSelfPokemonId === pp.id}
                            onSelect={() => setSelfPokemonId(pp.id)}
                            onInfo={() => setInfoPokemon(pp)}
                          />
                        ))}
                      </div>
                    </>
                  )
                ) : (
                  <PokemonTile
                    nom={isItemsPayload(existingTrade!.request) ? null : (existingTrade!.request as TradePokemonRequestPayload).pokemon_nom}
                    pokemonByName={pokemonByName}
                    placeholder="N'importe lequel"
                  />
                )}
              </div>

              <div className="flex items-center justify-center h-full pt-8 text-2xl text-ink-muted-2">🔁</div>

              <div>
                <p className="text-ink-muted text-xs font-bold mb-2 text-center">Je veux</p>
                {editing ? (
                  <div className="space-y-2">
                    <PokemonTile nom={wantAny ? null : wantPokemonNom} pokemonByName={pokemonByName} placeholder="N'importe lequel" />
                    <label className="flex items-center gap-2 text-xs text-ink-muted">
                      <input type="checkbox" checked={wantAny} onChange={(e) => setWantAny(e.target.checked)} className="w-4 h-4" />
                      N'importe quel Pokémon non possédé
                    </label>
                    {!wantAny && (
                      <div className="relative">
                        <input
                          type="text"
                          value={pokemonQuery}
                          onChange={(e) => setPokemonQuery(e.target.value)}
                          placeholder="Rechercher une espèce…"
                          className="w-full bg-white border-2 border-ink rounded-lg px-3 py-1.5 text-ink text-sm placeholder-ink-muted-2 outline-none"
                        />
                        {pokemonQuery && (
                          <div className="absolute z-10 top-full left-0 right-0 mt-1 bg-cream border-2 border-ink rounded-lg shadow-[var(--shadow-pixel)] max-h-40 overflow-y-auto">
                            {pokemonMatches.length === 0 ? (
                              <p className="text-ink-muted-2 text-xs px-3 py-2">Aucun résultat</p>
                            ) : (
                              pokemonMatches.map((p) => (
                                <button
                                  key={p.nom}
                                  onClick={() => { setWantPokemonNom(p.nom); setPokemonQuery('') }}
                                  className="w-full flex items-center gap-2 px-3 py-2 border-b border-[#cfc7a8] last:border-b-0 hover:bg-cream-secondary transition-colors text-left"
                                >
                                  <img src={p.image_miniature} alt="" className="w-6 h-6 object-contain pixelated" />
                                  <span className="text-ink text-sm truncate">{p.nom}</span>
                                </button>
                              ))
                            )}
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                ) : (
                  <PokemonTile
                    nom={isItemsPayload(existingTrade!.offer) ? null : (existingTrade!.offer as { pokemon_nom: string }).pokemon_nom}
                    nickname={isItemsPayload(existingTrade!.offer) ? null : (existingTrade!.offer as { nickname: string | null }).nickname}
                    pokemonByName={pokemonByName}
                  />
                )}
              </div>
            </div>
          )}

          {actionError && <p className="text-hp-red text-xs font-bold mt-3 text-center">{actionError}</p>}
          {resultMessage && <p className="text-green-700 text-sm font-bold mt-3 text-center">{resultMessage}</p>}
        </div>

        {kind !== null && (
          <div className="p-3 border-t-2 border-[#cfc7a8] shrink-0 flex flex-col gap-2">
            {editing && (
              <button
                onClick={handleSubmit}
                disabled={!canSubmit || submitting}
                className={`w-full px-4 py-2.5 rounded-lg text-sm font-bold ${canSubmit && !submitting ? BUTTON_STYLE.green : 'bg-[#3a3c58] text-[#7a7c9a] border-2 border-[#6a6a6a] cursor-not-allowed'}`}
              >
                Demander l'échange
              </button>
            )}

            {!editing && existingTrade && (
              <>
                {viewerIsProposer && isPending && (
                  <button onClick={handleCancel} disabled={submitting} className={`w-full px-4 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.red}`}>
                    Annuler l'échange
                  </button>
                )}
                {!viewerIsProposer && isPending && !resultMessage && (
                  <>
                    {(existingTrade.kind === 'item' ? !readOnlyItemsOk : acceptCandidates.length === 0) ? (
                      <p className="text-hp-red text-sm font-bold text-center">
                        {existingTrade.kind === 'item' ? "Vous n'avez pas les objets demandés" : "Vous n'avez pas le Pokémon demandé"}
                      </p>
                    ) : (
                      <button
                        onClick={handleAccept}
                        disabled={submitting || (existingTrade.kind === 'pokemon' && effectiveSelfPokemonId == null)}
                        className={`w-full px-4 py-2.5 rounded-lg text-sm font-bold ${
                          !submitting && (existingTrade.kind === 'item' || effectiveSelfPokemonId != null) ? BUTTON_STYLE.green : 'bg-[#3a3c58] text-[#7a7c9a] border-2 border-[#6a6a6a] cursor-not-allowed'
                        }`}
                      >
                        Accepter l'échange
                      </button>
                    )}
                    <button onClick={startCounter} className={`w-full px-4 py-2 rounded-lg text-sm font-bold ${BUTTON_STYLE.blue}`}>
                      Faire une contre-offre
                    </button>
                  </>
                )}
              </>
            )}
          </div>
        )}
      </div>

      {infoPokemon && (
        <PokemonDetailSheet
          context="pokemon"
          pokemon={pokemonByName.get(infoPokemon.pokemon_nom)}
          playerPokemon={infoPokemon}
          attacksByName={attacksByName}
          isAdmin={false}
          elevated
          onClose={() => setInfoPokemon(null)}
        />
      )}

      {swapAnim && proposerPlayer && (
        <TradeSwapAnimation
          leftPlayer={player}
          rightPlayer={proposerPlayer}
          leftPokemon={swapAnim.leftPokemon}
          leftNickname={swapAnim.leftNickname}
          rightPokemon={swapAnim.rightPokemon}
          rightNickname={swapAnim.rightNickname}
          onDone={() => { setSwapAnim(null); setResultMessage('Échange conclu !') }}
        />
      )}
    </div>
  )
}
