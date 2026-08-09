import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { Trade, TradeKind, TradeAcceptStatus, TradeCancelStatus, TradeItemsPayload, TradePokemonOfferPayload, TradePokemonRequestPayload } from '../types'

// Toutes les offres publiques (peu importe leur statut) — pas de filtre par
// joueur, n'importe qui peut voir/accepter une offre 'pending'.
export function useTrades() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [trades, setTrades] = useState<Trade[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    try {
      const { data, error } = await supabase.from('trades').select('*').order('created_at', { ascending: true }).limit(5000)
      if (error) throw error
      setTrades((data as Trade[]) ?? [])
    } catch (err) {
      console.error('Erreur lors du chargement des échanges :', err)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`trades-changes-${channelId.current}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'trades' },
        (payload) => {
          const row = payload.new as Trade
          setTrades((prev) => (prev.some((t) => t.id === row.id) ? prev : [...prev, row]))
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'trades' },
        (payload) => {
          const row = payload.new as Trade
          setTrades((prev) => prev.map((t) => (t.id === row.id ? row : t)))
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const createItemTrade = useCallback(async (
    proposerId: number,
    offer: TradeItemsPayload,
    request: TradeItemsPayload
  ): Promise<Trade | null> => {
    const { data, error } = await supabase
      .from('trades')
      .insert({ kind: 'item' as TradeKind, proposer_id: proposerId, offer, request })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de la création de l'échange :", error)
      return null
    }
    return data as Trade
  }, [])

  const createPokemonTrade = useCallback(async (
    proposerId: number,
    offer: TradePokemonOfferPayload,
    request: TradePokemonRequestPayload
  ): Promise<Trade | null> => {
    const { data, error } = await supabase
      .from('trades')
      .insert({ kind: 'pokemon' as TradeKind, proposer_id: proposerId, offer, request })
      .select()
      .single()
    if (error) {
      console.error("Erreur lors de la création de l'échange :", error)
      return null
    }
    return data as Trade
  }, [])

  const acceptTrade = useCallback(async (
    tradeId: number,
    playerId: number,
    chosenPlayerPokemonId?: number
  ): Promise<TradeAcceptStatus> => {
    const { data, error } = await supabase.rpc('trade_accept', {
      p_trade_id: tradeId,
      p_player_id: playerId,
      p_chosen_player_pokemon_id: chosenPlayerPokemonId ?? null,
    })
    if (error) {
      console.error("Erreur lors de l'acceptation de l'échange :", error)
      return 'error'
    }
    return (data as { status: TradeAcceptStatus })?.status ?? 'error'
  }, [])

  const cancelTrade = useCallback(async (tradeId: number, playerId: number): Promise<TradeCancelStatus> => {
    const { data, error } = await supabase.rpc('trade_cancel', { p_trade_id: tradeId, p_player_id: playerId })
    if (error) {
      console.error("Erreur lors de l'annulation de l'échange :", error)
      return 'error'
    }
    return (data as { status: TradeCancelStatus })?.status ?? 'error'
  }, [])

  return { trades, loading, createItemTrade, createPokemonTrade, acceptTrade, cancelTrade }
}
