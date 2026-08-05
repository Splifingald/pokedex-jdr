import { useState, useEffect, useCallback } from 'react'
import type { Player, PlayerPokemon, Pokemon, PokemonEvolution, Item } from '../types'
import { TICKET_TREMPETTE_ITEM_NAME, POKEDOLLAR_ITEM_NAME } from '../types'
import { usePlayerItems } from '../hooks/usePlayerItems'
import { useMinigamesConfig } from '../hooks/useMinigamesConfig'
import { useMinigamesPlayerState } from '../hooks/useMinigamesPlayerState'
import { computeTicketRegen, isPurchaseCapReached, localDateString, formatCountdown } from '../lib/casino'
import { isMagikarpAvailable, selectBestMagikarp } from '../lib/magikarpGame'
import { GameCard, GameBanner } from './CasinoGameCard'
import { MagikarpGame } from './miniGames/MagikarpGame'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { MINIGAMES_ICON, MINIGAMES_TICKET_ICON } from '../lib/icons'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { PokedollarIcon } from './PokedollarIcon'
import { logHistoryEvent } from '../lib/historyLog'

type View = 'list' | 'magikarp'

interface Props {
  player: Player
  playerItems: ReturnType<typeof usePlayerItems>
  roster: PlayerPokemon[]
  updateXp: (id: number, xp: number) => Promise<void>
  pokemonByName: Map<string, Pokemon>
  evolutionsByPokemonNom: Map<string, PokemonEvolution[]>
  itemsByName: Map<string, Item>
  pokedollarImageUrl?: string | null
  onRequestPokemonDetail: (id: number) => void
  onClose: () => void
}

export function MiniGamesPopup({
  player, playerItems, roster, updateXp, pokemonByName, evolutionsByPokemonNom, itemsByName,
  pokedollarImageUrl, onRequestPokemonDetail, onClose,
}: Props) {
  const { config } = useMinigamesConfig()
  const { state, updateState } = useMinigamesPlayerState(player.id)
  const [view, setView] = useState<View>('list')
  const [now, setNow] = useState(() => Date.now())

  const ticketRow = playerItems.inventory.find((r) => r.item_nom === TICKET_TREMPETTE_ITEM_NAME)
  const ticketCount = ticketRow?.quantity ?? 0

  // Rattrape/avance le minuteur des tickets gratuits toutes les secondes tant que le popup est ouvert.
  const tickRegen = useCallback(async () => {
    if (!state) return
    const result = computeTicketRegen(state.next_ticket_at, ticketCount, config, new Date())
    if (result.ticketsGranted > 0) {
      await playerItems.addItems(TICKET_TREMPETTE_ITEM_NAME, result.ticketsGranted)
      void logHistoryEvent('inventory', 'item_add', player.id, {
        item_nom: TICKET_TREMPETTE_ITEM_NAME,
        delta: result.ticketsGranted,
        total: ticketCount + result.ticketsGranted,
        source: 'la recharge de tickets',
      })
    }
    if (result.nextTicketAt !== state.next_ticket_at) {
      await updateState({ next_ticket_at: result.nextTicketAt })
    }
  }, [state, ticketCount, config, playerItems, updateState, player.id])

  useEffect(() => {
    tickRegen()
    const interval = window.setInterval(() => {
      setNow(Date.now())
      tickRegen()
    }, 1000)
    return () => clearInterval(interval)
    // eslint-disable-next-line react-hooks/exhaustive-deps -- tickRegen intentionally excluded: it's rebuilt every render and only state?.next_ticket_at / ticketCount should restart the interval
  }, [state?.next_ticket_at, ticketCount])

  const handleBuyTicket = async () => {
    if (!state) return
    const today = localDateString()
    if (playerItems.pokedollars < config.ticket_buy_cost) return
    if (isPurchaseCapReached(state, config, today)) return
    const pokedollarTotal = playerItems.pokedollars - config.ticket_buy_cost
    await playerItems.setPokedollars(pokedollarTotal)
    void logHistoryEvent('inventory', 'item_remove', player.id, {
      item_nom: POKEDOLLAR_ITEM_NAME,
      delta: config.ticket_buy_cost,
      total: pokedollarTotal,
      source: "l'achat de tickets Mini-Jeux",
    })
    await playerItems.addItems(TICKET_TREMPETTE_ITEM_NAME, 1)
    void logHistoryEvent('inventory', 'item_add', player.id, {
      item_nom: TICKET_TREMPETTE_ITEM_NAME,
      delta: 1,
      total: ticketCount + 1,
      source: "l'achat de tickets Mini-Jeux",
    })
    const sameDay = state.purchase_date === today
    await updateState({ purchase_count: sameDay ? state.purchase_count + 1 : 1, purchase_date: today })
  }

  const handlePlay = async (game: 'magikarp') => {
    if (ticketCount < 1 || !ticketRow) return
    const total = ticketRow.quantity - 1
    await playerItems.setQuantity(ticketRow, total)
    void logHistoryEvent('inventory', 'item_minigame_spend', player.id, {
      item_nom: TICKET_TREMPETTE_ITEM_NAME,
      delta: 1,
      total,
      source: config.magikarp_nom,
    })
    setView(game)
  }

  const today = localDateString()
  const buyDisabled = !state || playerItems.pokedollars < config.ticket_buy_cost || isPurchaseCapReached(state, config, today)
  const purchasesLeft = state
    ? Math.max(0, config.ticket_daily_buy_cap - (state.purchase_date === today ? state.purchase_count : 0))
    : config.ticket_daily_buy_cap

  const countdownMs = state?.next_ticket_at ? new Date(state.next_ticket_at).getTime() - now : null

  const magikarp = selectBestMagikarp(roster, config.magikarp_numero)
  const magikarpSpecies = magikarp ? pokemonByName.get(magikarp.pokemon_nom) : undefined

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-0 sm:p-4"
      onClick={(e) => { if (e.target === e.currentTarget && view === 'list') onClose() }}
    >
      <div
        className="relative bg-cream w-full h-full overflow-hidden flex flex-col
          sm:h-auto sm:max-w-md sm:max-h-[85vh] sm:rounded-[var(--radius-pixel)] sm:border-[3px] sm:border-ink sm:shadow-[var(--shadow-pixel-lg)]"
      >
        {view === 'list' && (
          <button
            onClick={onClose}
            className="absolute right-3 top-3 z-10 w-8 h-8 rounded-full flex items-center justify-center text-ink hover:bg-black/10"
          >
            <CloseIcon className="w-4 h-4" />
          </button>
        )}

        {view === 'magikarp' && (
          <GameBanner bannerUrl={config.magikarp_banner_url} fallbackEmoji="🐟" className="aspect-[10/3] shrink-0" />
        )}

        <div className="flex-1 overflow-y-auto p-4 sm:p-5">
          {view === 'list' && (
            <>
              <div className="flex items-center gap-2 mb-4">
                <PixelIcon src={MINIGAMES_ICON} size={28} colored className="text-ink" />
                <h3 className="text-ink text-lg font-bold">Mini-Jeux</h3>
              </div>

              <div className={`flex items-center gap-3 p-3 rounded mb-4 ${PIXEL_BORDER_SM} bg-cream-secondary`}>
                <img src={MINIGAMES_TICKET_ICON} alt="" className="w-9 h-9 object-contain pixelated" />
                <div className="flex-1">
                  <p className="text-ink text-sm font-bold">
                    {ticketCount} / {config.ticket_max} tickets
                  </p>
                  <p className="text-ink-muted-2 text-xs">
                    {ticketCount >= config.ticket_max || countdownMs === null
                      ? 'Plafond atteint'
                      : `Prochain ticket dans ${formatCountdown(countdownMs)}`}
                  </p>
                </div>
                {config.ticket_buy_cost > 0 && (
                  <button
                    onClick={handleBuyTicket}
                    disabled={buyDisabled}
                    title={`${purchasesLeft} achat(s) restant(s) aujourd'hui`}
                    className={`px-3 py-2 rounded text-xs font-bold shrink-0 disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.green}`}
                  >
                    Acheter <PokedollarIcon imageUrl={pokedollarImageUrl} size={16} className="align-[-3px]" />{config.ticket_buy_cost}
                  </button>
                )}
              </div>

              <div className="flex flex-col gap-3">
                {isMagikarpAvailable(config, roster) && (
                  <GameCard
                    nom={config.magikarp_nom}
                    iconUrl={config.magikarp_icon_url}
                    bannerUrl={config.magikarp_banner_url}
                    fallbackEmoji="🐟"
                    disabled={ticketCount < 1}
                    onPlay={() => handlePlay('magikarp')}
                    ticketIconUrl={MINIGAMES_TICKET_ICON}
                    extraBadge={
                      <span className="text-xs text-ink-muted-2 font-bold">🏆 {state?.magikarp_high_score ?? 0}</span>
                    }
                  />
                )}
              </div>
            </>
          )}

          {view === 'magikarp' && magikarp && (
            <MagikarpGame
              config={config}
              player={player}
              magikarp={magikarp}
              pokemon={magikarpSpecies}
              pokemonByName={pokemonByName}
              evolutionsByPokemonNom={evolutionsByPokemonNom}
              itemsByName={itemsByName}
              playerItemsInventory={playerItems.inventory}
              updateXp={updateXp}
              priorHighScore={state?.magikarp_high_score ?? 0}
              updateMinigamesState={updateState}
              onRequestPokemonDetail={onRequestPokemonDetail}
              onDone={() => setView('list')}
            />
          )}
        </div>
      </div>
    </div>
  )
}
