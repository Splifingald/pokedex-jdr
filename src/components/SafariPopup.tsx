import { useState, useEffect, useMemo } from 'react'
import type { Player, Item } from '../types'
import { BERRY_SAFARI_ITEM_NAME, BALL_SAFARI_ITEM_NAME, POKEDOLLAR_ITEM_NAME } from '../types'
import { usePlayerItems } from '../hooks/usePlayerItems'
import { usePlayerPokemon } from '../hooks/usePlayerPokemon'
import { useSafariConfig } from '../hooks/useSafariConfig'
import { useSafariPlayerState } from '../hooks/useSafariPlayerState'
import { useSafariGroups } from '../hooks/useSafariGroups'
import { useSafariSession } from '../hooks/useSafariSession'
import { useSafariBallAttempts } from '../hooks/useSafariBallAttempts'
import { usePlayers } from '../hooks/usePlayers'
import { usePokemon } from '../hooks/usePokemon'
import { formatCountdownHM, formatCountdown } from '../lib/casino'
import { GameBanner } from './CasinoGameCard'
import { SafariBoard } from './SafariBoard'
import { SafariMoveFeed } from './SafariMoveFeed'
import { SafariCaughtPopup } from './SafariCaughtPopup'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { SAFARI_ICON } from '../lib/icons'
import { logHistoryEvent } from '../lib/historyLog'

interface Props {
  player: Player
  playerItems: ReturnType<typeof usePlayerItems>
  itemsByName: Map<string, Item>
  pokedollarImageUrl?: string | null
  onRequestPokemonDetail: (id: number) => void
  onClose: () => void
}

export function SafariPopup({ player, playerItems, itemsByName, pokedollarImageUrl, onRequestPokemonDetail, onClose }: Props) {
  const { config, loading: configLoading } = useSafariConfig()
  const { state } = useSafariPlayerState(player.id)
  const { areasByGroup, loading: groupsLoading } = useSafariGroups()
  const { session, sessionPokemon, moves, loading: sessionLoading, throwBerry, throwBall } = useSafariSession(player.id)
  const { hasAttempted } = useSafariBallAttempts(player.id)
  const { players } = usePlayers()
  const { pokemon } = usePokemon()
  const { addOwnedPokemon } = usePlayerPokemon(player.id)

  const [now, setNow] = useState(() => Date.now())
  const [selectedSlot, setSelectedSlot] = useState<number | null>(null)
  const [caught, setCaught] = useState<{ nom: string; imageUrl: string | undefined; playerPokemonId: number } | null>(null)

  const playersById = useMemo(() => {
    const map = new Map<number, Player>()
    for (const p of players) map.set(p.id, p)
    return map
  }, [players])

  const pokemonByName = useMemo(() => {
    const map = new Map<string, typeof pokemon[number]>()
    for (const p of pokemon) map.set(p.nom, p)
    return map
  }, [pokemon])

  const sessionPokemonById = useMemo(() => {
    const map = new Map<number, typeof sessionPokemon[number]>()
    for (const sp of sessionPokemon) map.set(sp.id, sp)
    return map
  }, [sessionPokemon])

  const berryItem = itemsByName.get(BERRY_SAFARI_ITEM_NAME)
  const ballItem = itemsByName.get(BALL_SAFARI_ITEM_NAME)
  const berryRow = playerItems.inventory.find((r) => r.item_nom === BERRY_SAFARI_ITEM_NAME)
  const ballRow = playerItems.inventory.find((r) => r.item_nom === BALL_SAFARI_ITEM_NAME)
  const berryCount = berryRow?.quantity ?? 0
  const ballCount = ballRow?.quantity ?? 0

  // La régénération des Baies/Balls (octroi + minuteurs) tourne en tâche de
  // fond dans HomeTab dès que le jeu est débloqué — ce popup ne fait
  // qu'afficher le compte à rebours, il ne crédite plus rien lui-même.
  useEffect(() => {
    const interval = window.setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(interval)
  }, [])

  const handleBuyBerry = async () => {
    if (!berryItem || playerItems.pokedollars < berryItem.achat) return
    const pokedollarTotal = playerItems.pokedollars - berryItem.achat
    await playerItems.setPokedollars(pokedollarTotal)
    void logHistoryEvent('inventory', 'item_remove', player.id, { item_nom: POKEDOLLAR_ITEM_NAME, delta: berryItem.achat, total: pokedollarTotal, source: "l'achat de Baie Framby" })
    await playerItems.addItems(BERRY_SAFARI_ITEM_NAME, 1)
    void logHistoryEvent('inventory', 'item_add', player.id, { item_nom: BERRY_SAFARI_ITEM_NAME, delta: 1, total: berryCount + 1, source: "l'achat de Baie Framby" })
  }

  const handleBuyBall = async () => {
    if (!ballItem || playerItems.pokedollars < ballItem.achat) return
    const pokedollarTotal = playerItems.pokedollars - ballItem.achat
    await playerItems.setPokedollars(pokedollarTotal)
    void logHistoryEvent('inventory', 'item_remove', player.id, { item_nom: POKEDOLLAR_ITEM_NAME, delta: ballItem.achat, total: pokedollarTotal, source: "l'achat de Safari Ball" })
    await playerItems.addItems(BALL_SAFARI_ITEM_NAME, 1)
    void logHistoryEvent('inventory', 'item_add', player.id, { item_nom: BALL_SAFARI_ITEM_NAME, delta: 1, total: ballCount + 1, source: "l'achat de Safari Ball" })
  }

  const selected = sessionPokemon.find((sp) => sp.slot === selectedSlot) ?? null

  const handleThrowBerry = async () => {
    if (!selected || berryCount < 1 || !berryRow) return
    const spentTotal = berryRow.quantity - 1
    await playerItems.setQuantity(berryRow, spentTotal)
    const result = await throwBerry(selected.id)
    if (result.status !== 'ok') {
      await playerItems.addItems(BERRY_SAFARI_ITEM_NAME, 1)
      return
    }
    void logHistoryEvent('safari', 'safari_berry_throw', player.id, {
      pokemon_nom: selected.pokemon_nom, session_pokemon_id: selected.id, gauge_before: result.gaugeBefore, gauge_after: result.gaugeAfter,
    })
  }

  const handleThrowBall = async () => {
    if (!selected || ballCount < 1 || !ballRow || hasAttempted(selected.id)) return
    const spentTotal = ballRow.quantity - 1
    await playerItems.setQuantity(ballRow, spentTotal)
    const result = await throwBall(selected.id)
    if (result.status !== 'ok') {
      await playerItems.addItems(BALL_SAFARI_ITEM_NAME, 1)
      return
    }
    if (result.success) {
      void logHistoryEvent('safari', 'safari_capture', player.id, { pokemon_nom: selected.pokemon_nom, session_pokemon_id: selected.id })
      const species = pokemonByName.get(selected.pokemon_nom)
      const created = await addOwnedPokemon(selected.pokemon_nom, species?.numero ?? '', false)
      if (created) {
        setCaught({ nom: selected.pokemon_nom, imageUrl: species?.image_miniature, playerPokemonId: created.id })
      }
    } else {
      void logHistoryEvent('safari', 'safari_flee', player.id, { pokemon_nom: selected.pokemon_nom, session_pokemon_id: selected.id })
    }
    setSelectedSlot(null)
  }

  const berryCountdownMs = state?.next_berry_at ? new Date(state.next_berry_at).getTime() - now : null
  const berryCapped = config.berry_reward_interval_amount === 0 || berryCount >= config.berry_reward_max || berryCountdownMs === null
  const ballCountdownMs = state?.next_ball_at ? new Date(state.next_ball_at).getTime() - now : null
  const ballCapped = config.ball_reward_interval_amount === 0 || ballCount >= config.ball_reward_max || ballCountdownMs === null

  const sessionCountdownMs = session ? new Date(session.expires_at).getTime() - now : null
  const sessionExpired = sessionCountdownMs !== null && sessionCountdownMs <= 0

  const loading = configLoading || groupsLoading || sessionLoading

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-0 sm:p-4"
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

        <GameBanner bannerUrl={config.banner_url} fallbackEmoji="🦁" className="aspect-[21/4.5] shrink-0" />

        <div className="flex items-start justify-between gap-3 px-4 pt-3 sm:px-5">
          <div className="flex items-center gap-2 min-w-0">
            <PixelIcon src={SAFARI_ICON} size={24} colored className="text-ink shrink-0" />
            <h3 className="text-ink text-lg font-bold truncate">{config.nom}</h3>
          </div>
          <div className="text-right shrink-0 text-xs">
            {session && !sessionExpired && sessionCountdownMs !== null && (
              <p className="text-ink-muted-2">Session : {formatCountdown(sessionCountdownMs)}</p>
            )}
            {sessionExpired && <p className="text-ink-muted-2">Session terminée, revenez bientôt</p>}
            {config.berry_reward_interval_amount > 0 && (
              <p className="text-ink-muted-2 flex items-center justify-end gap-1">
                {berryItem?.image_url && <img src={berryItem.image_url} alt="" className="w-4 h-4 object-contain pixelated" />}
                {berryCapped ? 'Plafond atteint' : `+1 dans ${formatCountdownHM(berryCountdownMs ?? 0)}`}
              </p>
            )}
            {config.ball_reward_interval_amount > 0 && (
              <p className="text-ink-muted-2 flex items-center justify-end gap-1">
                {ballItem?.image_url && <img src={ballItem.image_url} alt="" className="w-4 h-4 object-contain pixelated" />}
                {ballCapped ? 'Plafond atteint' : `+1 dans ${formatCountdownHM(ballCountdownMs ?? 0)}`}
              </p>
            )}
          </div>
        </div>

        <div className="flex-1 overflow-y-auto overflow-x-hidden p-4 sm:p-5">
          {loading ? (
            <p className="text-ink-muted-2 text-sm text-center py-6">Chargement…</p>
          ) : (
            <div className="flex flex-col gap-5">
              <SafariBoard
                sessionPokemon={sessionPokemon}
                pokemonByName={pokemonByName}
                areasByGroup={areasByGroup}
                playersById={playersById}
                selectedSlot={selectedSlot}
                onSelectSlot={setSelectedSlot}
                berryItem={berryItem}
                ballItem={ballItem}
                berryCount={berryCount}
                ballCount={ballCount}
                hasAttempted={hasAttempted}
                berryMinIncrease={config.berry_min_increase}
                berryMaxIncrease={config.berry_max_increase}
                pokedollarImageUrl={pokedollarImageUrl}
                onThrowBerry={handleThrowBerry}
                onThrowBall={handleThrowBall}
                onBuyBerry={handleBuyBerry}
                onBuyBall={handleBuyBall}
              />

              <div className="border-t-2 border-[#cfc7a8] pt-3">
                <SafariMoveFeed moves={moves} playersById={playersById} sessionPokemonById={sessionPokemonById} areasByGroup={areasByGroup} />
              </div>
            </div>
          )}
        </div>
      </div>

      {caught && (
        <SafariCaughtPopup
          pokemonName={caught.nom}
          imageUrl={caught.imageUrl}
          onContinue={() => {
            const id = caught.playerPokemonId
            setCaught(null)
            onRequestPokemonDetail(id)
          }}
        />
      )}
    </div>
  )
}
