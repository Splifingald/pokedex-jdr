import { useState, useEffect, useMemo } from 'react'
import type { Player, Item } from '../types'
import { TICKET_MINING_ITEM_NAME, POKEDOLLAR_ITEM_NAME } from '../types'
import { usePlayerItems } from '../hooks/usePlayerItems'
import { useMiningConfig } from '../hooks/useMiningConfig'
import { useMiningPlayerState } from '../hooks/useMiningPlayerState'
import { useMiningItemDefs } from '../hooks/useMiningItemDefs'
import { useMiningActiveGrid } from '../hooks/useMiningActiveGrid'
import { usePlayers } from '../hooks/usePlayers'
import { isPurchaseCapReached, localDateString, formatCountdownHM } from '../lib/casino'
import { GameBanner } from './CasinoGameCard'
import { MiningGridGame } from './MiningGridGame'
import { MiningItemFoundPopup } from './MiningItemFoundPopup'
import { MiningGridExhaustedPopup } from './MiningGridExhaustedPopup'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { MINING_ICON, MINING_TICKET_ICON } from '../lib/icons'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { PokedollarIcon } from './PokedollarIcon'
import { logHistoryEvent } from '../lib/historyLog'

interface Props {
  player: Player
  playerItems: ReturnType<typeof usePlayerItems>
  itemsByName: Map<string, Item>
  pokedollarImageUrl?: string | null
  onClose: () => void
}

export function MiningPopup({ player, playerItems, itemsByName, pokedollarImageUrl, onClose }: Props) {
  const { config, loading: configLoading } = useMiningConfig()
  const { state, updateState } = useMiningPlayerState(player.id)
  const { itemDefs, loading: itemDefsLoading } = useMiningItemDefs()
  const { players } = usePlayers()
  const {
    grid, items, cells, moves, loading: gridLoading, digCell,
    justExhaustedGridId, exhaustedSnapshot, clearExhaustedNotice,
  } = useMiningActiveGrid(player.id, config, itemDefs, configLoading, itemDefsLoading)
  const [now, setNow] = useState(() => Date.now())
  const [foundItemNom, setFoundItemNom] = useState<string | null>(null)

  const playersById = useMemo(() => {
    const map = new Map<number, Player>()
    for (const p of players) map.set(p.id, p)
    return map
  }, [players])

  const ticketRow = playerItems.inventory.find((r) => r.item_nom === TICKET_MINING_ITEM_NAME)
  const ticketCount = ticketRow?.quantity ?? 0

  // La régénération des tickets (octroi + minuteur) tourne en tâche de fond
  // dans HomeTab dès que le jeu est débloqué — ce popup ne fait qu'afficher
  // le compte à rebours, il ne crédite plus rien lui-même.
  useEffect(() => {
    const interval = window.setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(interval)
  }, [])

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
      source: "l'achat de tickets Fouille",
    })
    await playerItems.addItems(TICKET_MINING_ITEM_NAME, 1)
    void logHistoryEvent('inventory', 'item_add', player.id, {
      item_nom: TICKET_MINING_ITEM_NAME,
      delta: 1,
      total: ticketCount + 1,
      source: "l'achat de tickets Fouille",
    })
    const sameDay = state.purchase_date === today
    await updateState({ purchase_count: sameDay ? state.purchase_count + 1 : 1, purchase_date: today })
  }

  // Une case creusée coûte toujours 1 ticket, dépensé avant l'appel RPC (même
  // convention "dépense à l'entrée" que Casino/Mini-Jeux) — remboursé si le
  // serveur refuse le coup (case déjà prise entretemps, ou grille épuisée entretemps).
  const handleDigCell = async (cellIndex: number) => {
    if (ticketCount < 1 || !ticketRow || !grid) return
    const spentTotal = ticketRow.quantity - 1
    await playerItems.setQuantity(ticketRow, spentTotal)
    void logHistoryEvent('inventory', 'item_mining_spend', player.id, {
      item_nom: TICKET_MINING_ITEM_NAME,
      delta: 1,
      total: spentTotal,
      source: config.nom,
    })

    const digGridId = grid.id
    const digGridSize = grid.size
    const result = await digCell(cellIndex)

    if (result.status !== 'ok') {
      await playerItems.addItems(TICKET_MINING_ITEM_NAME, 1)
      void logHistoryEvent('inventory', 'item_add', player.id, {
        item_nom: TICKET_MINING_ITEM_NAME,
        delta: 1,
        total: spentTotal + 1,
        source: result.status === 'already_dug' ? 'case déjà creusée' : 'grille épuisée',
      })
      return
    }

    if (result.itemCompleted && result.itemNom) {
      void logHistoryEvent('minigame', 'mining_item_found', player.id, {
        item_nom: result.itemNom,
        grid_id: digGridId,
        grid_size: digGridSize,
      })
      setFoundItemNom(result.itemNom)
      // La récompense est upsertée côté serveur par mining_dig_cell (pas par ce
      // client), donc pas via les setInventory optimistes habituels de
      // usePlayerItems — on force un refetch plutôt que de compter sur le
      // Realtime pour la refléter à temps dans le Sac au moment où le joueur
      // ferme ce popup.
      void playerItems.refetch()
    }
  }

  const today = localDateString()
  const buyDisabled = !state || playerItems.pokedollars < config.ticket_buy_cost || isPurchaseCapReached(state, config, today)
  const purchasesLeft = state
    ? Math.max(0, config.ticket_daily_buy_cap - (state.purchase_date === today ? state.purchase_count : 0))
    : config.ticket_daily_buy_cap

  const countdownMs = state?.next_ticket_at ? new Date(state.next_ticket_at).getTime() - now : null
  const ticketCapped = ticketCount >= config.ticket_max || countdownMs === null

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 sm:p-4 safe-overlay"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div
        className="relative bg-cream w-full h-full overflow-hidden flex flex-col
          sm:h-auto sm:max-w-2xl sm:max-h-[85vh] sm:rounded-[var(--radius-pixel)] sm:border-[3px] sm:border-ink sm:shadow-[var(--shadow-pixel-lg)]"
      >
        <button
          onClick={onClose}
          className="absolute right-3 top-3 z-10 w-8 h-8 rounded-full border-2 border-ink bg-cream shadow-[var(--shadow-pixel)] flex items-center justify-center text-ink hover:bg-black/10 active:shadow-none active:translate-x-[1px] active:translate-y-[1px] transition-all"
        >
          <CloseIcon className="w-4 h-4" />
        </button>

        <GameBanner bannerUrl={config.banner_url} fallbackEmoji="⛏️" className="aspect-[21/4.5] shrink-0" />

        <div className="flex items-start justify-between gap-3 px-4 pt-3 sm:px-5">
          <div className="flex items-center gap-2 min-w-0">
            <PixelIcon src={MINING_ICON} size={24} colored className="text-ink shrink-0" />
            <h3 className="text-ink text-lg font-bold truncate">{config.nom}</h3>
          </div>
          <div className="text-right shrink-0">
            <div className="flex items-center justify-end gap-2">
              <img src={MINING_TICKET_ICON} alt="" className="w-5 h-5 object-contain pixelated" />
              <span className="text-ink text-sm font-bold">{ticketCount}/{config.ticket_max}</span>
              {config.ticket_buy_cost > 0 && (
                <button
                  onClick={handleBuyTicket}
                  disabled={buyDisabled}
                  title={`${purchasesLeft} achat(s) restant(s) aujourd'hui`}
                  className={`px-2 py-1 rounded text-[11px] font-bold disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.green}`}
                >
                  Acheter <PokedollarIcon imageUrl={pokedollarImageUrl} size={13} className="align-[-2px]" />{config.ticket_buy_cost}
                </button>
              )}
            </div>
            <p className="text-ink-muted-2 text-xs mt-0.5">
              {ticketCapped ? 'Plafond atteint' : `+1 dans ${formatCountdownHM(countdownMs)}`}
            </p>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-4 sm:p-5">
          <MiningGridGame
            grid={grid}
            items={items}
            cells={cells}
            moves={moves}
            loading={gridLoading}
            players={players}
            itemsByName={itemsByName}
            ticketCount={ticketCount}
            hiddenCellImageUrl={config.hidden_cell_image_url}
            emptyCellImageUrl={config.empty_cell_image_url}
            now={now}
            onDigCell={handleDigCell}
          />
        </div>
      </div>

      {foundItemNom && (
        <MiningItemFoundPopup
          itemNom={foundItemNom}
          itemsByName={itemsByName}
          onConfirm={() => setFoundItemNom(null)}
        />
      )}
      {!foundItemNom && justExhaustedGridId && exhaustedSnapshot && (
        <MiningGridExhaustedPopup
          snapshot={exhaustedSnapshot}
          itemsByName={itemsByName}
          playersById={playersById}
          hiddenCellImageUrl={config.hidden_cell_image_url}
          emptyCellImageUrl={config.empty_cell_image_url}
          onDone={clearExhaustedNotice}
        />
      )}
    </div>
  )
}
