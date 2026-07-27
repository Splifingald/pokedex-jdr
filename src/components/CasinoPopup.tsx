import { useState, useEffect, useCallback } from 'react'
import type { Player } from '../types'
import { TICKET_CASINO_ITEM_NAME } from '../types'
import { usePlayerItems } from '../hooks/usePlayerItems'
import { useCasinoConfig } from '../hooks/useCasinoConfig'
import { useCasinoPlayerState } from '../hooks/useCasinoPlayerState'
import { computeTicketRegen, isPurchaseCapReached, localDateString } from '../lib/casino'
import { CasinoSlotGame } from './CasinoSlotGame'
import { CasinoDiceGame } from './CasinoDiceGame'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { CASINO_ICON, CASINO_MASCOT_ICON } from '../lib/icons'
import { PixelIcon } from './icons/PixelIcon'

type View = 'list' | 'slots' | 'dice'

interface Props {
  player: Player
  playerItems: ReturnType<typeof usePlayerItems>
  pokedollarImageUrl?: string | null
  onClose: () => void
}

function formatCountdown(ms: number): string {
  const totalSeconds = Math.max(0, Math.ceil(ms / 1000))
  const h = Math.floor(totalSeconds / 3600)
  const m = Math.floor((totalSeconds % 3600) / 60)
  const s = totalSeconds % 60
  if (h > 0) return `${h}h ${String(m).padStart(2, '0')}m ${String(s).padStart(2, '0')}s`
  return `${m}m ${String(s).padStart(2, '0')}s`
}

function GameBanner({ bannerUrl, fallbackEmoji, className }: { bannerUrl: string; fallbackEmoji: string; className: string }) {
  return (
    <div className={`w-full bg-black/10 flex items-center justify-center overflow-hidden ${className}`}>
      {bannerUrl ? (
        <img src={bannerUrl} alt="" className="w-full h-full object-cover" />
      ) : (
        <span className="text-4xl">{fallbackEmoji}</span>
      )}
    </div>
  )
}

export function CasinoPopup({ player, playerItems, pokedollarImageUrl, onClose }: Props) {
  const { config } = useCasinoConfig()
  const { state, updateState } = useCasinoPlayerState(player.id)
  const [view, setView] = useState<View>('list')
  const [now, setNow] = useState(() => Date.now())

  const ticketRow = playerItems.inventory.find((r) => r.item_nom === TICKET_CASINO_ITEM_NAME)
  const ticketCount = ticketRow?.quantity ?? 0

  // Rattrape/avance le minuteur des tickets gratuits toutes les secondes tant que le popup est ouvert.
  const tickRegen = useCallback(async () => {
    if (!state) return
    const result = computeTicketRegen(state.next_ticket_at, ticketCount, config, new Date())
    if (result.ticketsGranted > 0) {
      await playerItems.addItems(TICKET_CASINO_ITEM_NAME, result.ticketsGranted)
    }
    if (result.nextTicketAt !== state.next_ticket_at) {
      await updateState({ next_ticket_at: result.nextTicketAt })
    }
  }, [state, ticketCount, config, playerItems, updateState])

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
    await playerItems.setPokedollars(playerItems.pokedollars - config.ticket_buy_cost)
    await playerItems.addItems(TICKET_CASINO_ITEM_NAME, 1)
    const sameDay = state.purchase_date === today
    await updateState({ purchase_count: sameDay ? state.purchase_count + 1 : 1, purchase_date: today })
  }

  const handlePlay = async (game: 'slots' | 'dice') => {
    if (ticketCount < 1 || !ticketRow) return
    await playerItems.setQuantity(ticketRow, ticketRow.quantity - 1)
    setView(game)
  }

  // Une partie ne peut que rapporter (le ticket est déjà dépensé) : le bouton
  // final de chaque jeu crédite directement les gains et revient à la liste,
  // pas de popup de récompense séparée.
  const handleFinish = async (amount: number) => {
    if (amount > 0) await playerItems.setPokedollars(playerItems.pokedollars + amount)
    setView('list')
  }

  const today = localDateString()
  const buyDisabled = !state || playerItems.pokedollars < config.ticket_buy_cost || isPurchaseCapReached(state, config, today)
  const purchasesLeft = state
    ? Math.max(0, config.ticket_daily_buy_cap - (state.purchase_date === today ? state.purchase_count : 0))
    : config.ticket_daily_buy_cap

  const countdownMs = state?.next_ticket_at ? new Date(state.next_ticket_at).getTime() - now : null

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
            ✕
          </button>
        )}

        {view === 'slots' && (
          <GameBanner bannerUrl={config.slots_banner_url} fallbackEmoji="🎰" className="aspect-[21/9] shrink-0" />
        )}
        {view === 'dice' && (
          <GameBanner bannerUrl={config.dice_banner_url} fallbackEmoji="🎲" className="aspect-[21/9] shrink-0" />
        )}

        <div className="flex-1 overflow-y-auto p-4 sm:p-5">
          {view === 'list' && (
            <>
              <div className="flex items-center gap-2 mb-4">
                <PixelIcon src={CASINO_MASCOT_ICON} size={28} colored className="text-ink" />
                <h3 className="text-ink text-lg font-bold">Casino</h3>
              </div>

              <div className={`flex items-center gap-3 p-3 rounded mb-4 ${PIXEL_BORDER_SM} bg-cream-secondary`}>
                <img src={CASINO_ICON.ticket} alt="" className="w-9 h-9 object-contain pixelated" />
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
                <button
                  onClick={handleBuyTicket}
                  disabled={buyDisabled}
                  title={`${purchasesLeft} achat(s) restant(s) aujourd'hui`}
                  className={`px-3 py-2 rounded text-xs font-bold shrink-0 disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.green}`}
                >
                  Acheter 💰{config.ticket_buy_cost}
                </button>
              </div>

              <div className="flex flex-col gap-3">
                {config.slots_enabled && (
                  <GameCard
                    nom={config.slots_nom}
                    iconUrl={config.slots_icon_url}
                    bannerUrl={config.slots_banner_url}
                    fallbackEmoji="🎰"
                    disabled={ticketCount < 1}
                    onPlay={() => handlePlay('slots')}
                  />
                )}
                {config.dice_enabled && (
                  <GameCard
                    nom={config.dice_nom}
                    iconUrl={config.dice_icon_url}
                    bannerUrl={config.dice_banner_url}
                    fallbackEmoji="🎲"
                    disabled={ticketCount < 1}
                    onPlay={() => handlePlay('dice')}
                  />
                )}
              </div>
            </>
          )}

          {view === 'slots' && (
            <>
              <h3 className="text-ink text-lg font-bold text-center mb-4">{config.slots_nom}</h3>
              <CasinoSlotGame config={config} pokedollarImageUrl={pokedollarImageUrl} onWin={handleFinish} />
            </>
          )}

          {view === 'dice' && (
            <>
              <h3 className="text-ink text-lg font-bold text-center mb-4">{config.dice_nom}</h3>
              <CasinoDiceGame config={config} player={player} pokedollarImageUrl={pokedollarImageUrl} onWin={handleFinish} />
            </>
          )}
        </div>
      </div>
    </div>
  )
}

function GameCard({
  nom, iconUrl, bannerUrl, fallbackEmoji, disabled, onPlay,
}: {
  nom: string
  iconUrl: string
  bannerUrl: string
  fallbackEmoji: string
  disabled: boolean
  onPlay: () => void
}) {
  return (
    <div className={`p-3 rounded ${PIXEL_BORDER_SM} bg-cream-secondary`}>
      <GameBanner bannerUrl={bannerUrl} fallbackEmoji={fallbackEmoji} className="h-24 rounded mb-2" />
      <div className="flex items-center gap-2">
        <div className="w-8 h-8 shrink-0 flex items-center justify-center">
          {iconUrl ? (
            <img src={iconUrl} alt="" className="w-full h-full object-contain" />
          ) : (
            <span className="text-xl">{fallbackEmoji}</span>
          )}
        </div>
        <span className="flex-1 text-ink text-sm font-bold truncate">{nom}</span>
        <button
          onClick={onPlay}
          disabled={disabled}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-bold shrink-0 disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.yellow}`}
        >
          <img src={CASINO_ICON.ticket} alt="" className="w-4 h-4 object-contain pixelated" />
          Jouer
        </button>
      </div>
    </div>
  )
}
