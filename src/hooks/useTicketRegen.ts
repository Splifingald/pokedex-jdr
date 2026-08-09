import { useCallback, useEffect } from 'react'
import type { CasinoConfig } from '../types'
import { computeTicketRegen } from '../lib/casino'
import type { usePlayerItems } from './usePlayerItems'
import { logHistoryEvent } from '../lib/historyLog'

type TicketConfig = Pick<CasinoConfig, 'ticket_max' | 'ticket_regen_amount' | 'ticket_regen_unit'>

// Fait avancer le minuteur de régénération de tickets d'un mini-jeu dès que
// l'app est ouverte et le jeu débloqué — indépendamment de l'ouverture du
// popup du jeu. Un seul appelant (monté dans HomeTab) doit s'en charger par
// joueur/jeu pour éviter un octroi en double.
export function useTicketRegen(
  enabled: boolean,
  playerId: number,
  itemName: string,
  ticketCount: number,
  nextTicketAt: string | null,
  config: TicketConfig,
  playerItems: Pick<ReturnType<typeof usePlayerItems>, 'addItems'>,
  updateState: (patch: { next_ticket_at: string | null }) => Promise<void>
) {
  const tick = useCallback(async () => {
    const result = computeTicketRegen(nextTicketAt, ticketCount, config, new Date())
    if (result.ticketsGranted > 0) {
      await playerItems.addItems(itemName, result.ticketsGranted)
      void logHistoryEvent('inventory', 'item_add', playerId, {
        item_nom: itemName,
        delta: result.ticketsGranted,
        total: ticketCount + result.ticketsGranted,
        source: 'la recharge de tickets',
      })
    }
    if (result.nextTicketAt !== nextTicketAt) {
      await updateState({ next_ticket_at: result.nextTicketAt })
    }
  }, [nextTicketAt, ticketCount, config, itemName, playerId, playerItems, updateState])

  useEffect(() => {
    if (!enabled) return
    tick()
    const interval = window.setInterval(tick, 1000)
    return () => clearInterval(interval)
    // eslint-disable-next-line react-hooks/exhaustive-deps -- tick intentionally excluded: rebuilt every render, only enabled/nextTicketAt/ticketCount should restart the interval
  }, [enabled, nextTicketAt, ticketCount])
}

// Variante Safari : deux minuteurs indépendants (Baie / Ball) partagés dans une même boucle.
export function useSafariTicketRegen(
  enabled: boolean,
  playerId: number,
  berryItemName: string,
  ballItemName: string,
  berryCount: number,
  ballCount: number,
  nextBerryAt: string | null,
  nextBallAt: string | null,
  config: {
    berry_reward_max: number
    berry_reward_interval_amount: number
    berry_reward_interval_unit: CasinoConfig['ticket_regen_unit']
    ball_reward_max: number
    ball_reward_interval_amount: number
    ball_reward_interval_unit: CasinoConfig['ticket_regen_unit']
  },
  playerItems: Pick<ReturnType<typeof usePlayerItems>, 'addItems'>,
  updateState: (patch: { next_berry_at?: string | null; next_ball_at?: string | null }) => Promise<void>
) {
  const tick = useCallback(async () => {
    const berryResult = computeTicketRegen(
      nextBerryAt, berryCount,
      { ticket_max: config.berry_reward_max, ticket_regen_amount: config.berry_reward_interval_amount, ticket_regen_unit: config.berry_reward_interval_unit },
      new Date()
    )
    const ballResult = computeTicketRegen(
      nextBallAt, ballCount,
      { ticket_max: config.ball_reward_max, ticket_regen_amount: config.ball_reward_interval_amount, ticket_regen_unit: config.ball_reward_interval_unit },
      new Date()
    )
    if (config.berry_reward_interval_amount > 0 && berryResult.ticketsGranted > 0) {
      await playerItems.addItems(berryItemName, berryResult.ticketsGranted)
      void logHistoryEvent('inventory', 'item_add', playerId, {
        item_nom: berryItemName, delta: berryResult.ticketsGranted, total: berryCount + berryResult.ticketsGranted, source: 'la recharge automatique',
      })
    }
    if (config.ball_reward_interval_amount > 0 && ballResult.ticketsGranted > 0) {
      await playerItems.addItems(ballItemName, ballResult.ticketsGranted)
      void logHistoryEvent('inventory', 'item_add', playerId, {
        item_nom: ballItemName, delta: ballResult.ticketsGranted, total: ballCount + ballResult.ticketsGranted, source: 'la recharge automatique',
      })
    }
    const patch: { next_berry_at?: string | null; next_ball_at?: string | null } = {}
    if (config.berry_reward_interval_amount > 0 && berryResult.nextTicketAt !== nextBerryAt) patch.next_berry_at = berryResult.nextTicketAt
    if (config.ball_reward_interval_amount > 0 && ballResult.nextTicketAt !== nextBallAt) patch.next_ball_at = ballResult.nextTicketAt
    if (Object.keys(patch).length > 0) await updateState(patch)
  }, [nextBerryAt, nextBallAt, berryCount, ballCount, config, berryItemName, ballItemName, playerId, playerItems, updateState])

  useEffect(() => {
    if (!enabled) return
    tick()
    const interval = window.setInterval(tick, 1000)
    return () => clearInterval(interval)
    // eslint-disable-next-line react-hooks/exhaustive-deps -- tick intentionally excluded: rebuilt every render, only enabled/timers/counts should restart the interval
  }, [enabled, nextBerryAt, nextBallAt, berryCount, ballCount])
}
