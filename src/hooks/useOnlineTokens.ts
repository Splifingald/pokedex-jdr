import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { OnlinePlaceStatus, OnlineToken } from '../types'
import type { StatusId } from '../lib/status'

// Jetons posés sur le plateau : une ligne par jeton, donc chaque personne qui
// glisse son pion n'écrit que sa propre ligne (plusieurs joueurs déplacent en
// même temps — voir le commentaire de mining_grid_cells dans schema.sql).
//
// Les écritures passent par les RPC online_* : la règle « une seule case
// occupée, sauf jeton K.O. » croise deux tables et ne peut donc pas être une
// contrainte Postgres.

export interface FreeTokenInput {
  max_hp?: number | null
  current_hp?: number | null
  damage?: number | null
  status?: StatusId
  label?: string
}

export interface PlaceTokenInput {
  /** Jeton existant à déplacer, ou null pour une pose. */
  tokenId?: number | null
  ownerPlayerId?: number | null
  playerPokemonId?: number | null
  pokemonNom: string
  col: number
  row: number
  placedByAdmin?: boolean
  free?: FreeTokenInput | null
  /** PV max calculés côté client (les paliers d'XP sont parsés depuis des
   *  colonnes texte, impraticable en SQL). Sert au journal de bataille. */
  maxHp?: number
  /** Camp du jeton — voir OnlineToken.is_ally. */
  isAlly?: boolean
}

export function useOnlineTokens() {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [tokens, setTokens] = useState<OnlineToken[]>([])
  const [loading, setLoading] = useState(true)

  const fetchAll = useCallback(async () => {
    setLoading(true)
    try {
      const { data, error } = await supabase.from('online_tokens').select('*').order('id')
      if (error) throw error
      setTokens((data ?? []) as OnlineToken[])
    } catch (err) {
      console.error('Erreur de chargement des jetons du plateau :', err)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  useEffect(() => {
    const channel = supabase
      .channel(`online-tokens-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'online_tokens' }, (payload) => {
        const row = payload.new as OnlineToken
        setTokens((prev) => (prev.some((t) => t.id === row.id) ? prev.map((t) => (t.id === row.id ? row : t)) : [...prev, row]))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'online_tokens' }, (payload) => {
        const row = payload.new as OnlineToken
        setTokens((prev) => prev.map((t) => (t.id === row.id ? row : t)))
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'online_tokens' }, (payload) => {
        const id = (payload.old as { id: number }).id
        setTokens((prev) => prev.filter((t) => t.id !== id))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  /** Pose ou déplace un jeton. L'affichage est optimiste pour que le glissé ne
   *  « rebondisse » pas ; le serveur tranche et on refetch en cas de refus. */
  const placeToken = useCallback(async (input: PlaceTokenInput): Promise<OnlinePlaceStatus> => {
    if (input.tokenId != null) {
      setTokens((prev) => prev.map((t) => (t.id === input.tokenId ? { ...t, cell_col: input.col, cell_row: input.row } : t)))
    }
    const { data, error } = await supabase.rpc('online_place_token', {
      p_token_id: input.tokenId ?? null,
      p_owner_player_id: input.ownerPlayerId ?? null,
      p_player_pokemon_id: input.playerPokemonId ?? null,
      p_pokemon_nom: input.pokemonNom,
      p_cell_col: input.col,
      p_cell_row: input.row,
      p_placed_by_admin: input.placedByAdmin ?? false,
      p_free: input.free ?? null,
      p_max_hp: input.maxHp ?? 0,
      p_is_ally: input.isAlly ?? false,
    })
    if (error) {
      console.error('Erreur lors de la pose du jeton :', error)
      await fetchAll()
      return 'error'
    }
    const status = ((data as { status?: OnlinePlaceStatus } | null)?.status ?? 'error') as OnlinePlaceStatus
    if (status !== 'ok') await fetchAll()
    return status
  }, [fetchAll])

  const removeToken = useCallback(async (tokenId: number, playerId: number | null, isAdmin: boolean): Promise<OnlinePlaceStatus> => {
    setTokens((prev) => prev.filter((t) => t.id !== tokenId))
    const { data, error } = await supabase.rpc('online_remove_token', {
      p_token_id: tokenId,
      p_player_id: playerId,
      p_is_admin: isAdmin,
    })
    if (error) {
      console.error('Erreur lors du retrait du jeton :', error)
      await fetchAll()
      return 'error'
    }
    const status = ((data as { status?: OnlinePlaceStatus } | null)?.status ?? 'error') as OnlinePlaceStatus
    if (status !== 'ok') await fetchAll()
    return status
  }, [fetchAll])

  /** PV/statut/dégâts d'un jeton « espèce libre » (MJ). Les jetons adossés à un
   *  player_pokemon passent, eux, par lib/pokemonVitals. */
  const updateFreeToken = useCallback(async (
    tokenId: number,
    patch: Partial<Pick<OnlineToken, 'free_max_hp' | 'free_current_hp' | 'free_damage' | 'free_status' | 'free_label'>>
  ) => {
    setTokens((prev) => prev.map((t) => (t.id === tokenId ? { ...t, ...patch } : t)))
    const { error } = await supabase.from('online_tokens').update(patch).eq('id', tokenId)
    if (error) {
      console.error('Erreur lors de la mise à jour du jeton :', error)
      await fetchAll()
    }
  }, [fetchAll])

  /** Vide le plateau de son contenu (jetons), sans toucher au fond ni au
   *  découpage. Le `.neq('id', 0)` n'est pas décoratif : ce projet Supabase
   *  refuse les DELETE sans clause WHERE (même contournement que
   *  netlify/functions/import-display-assets.js). */
  const clearTokens = useCallback(async () => {
    setTokens([])
    const { error } = await supabase.from('online_tokens').delete().neq('id', 0)
    if (error) {
      console.error('Erreur lors du vidage du plateau :', error)
      await fetchAll()
    }
  }, [fetchAll])

  const resetBoard = useCallback(async () => {
    setTokens([])
    const { error } = await supabase.rpc('online_reset_board')
    if (error) {
      console.error('Erreur lors de la réinitialisation du plateau :', error)
      await fetchAll()
    }
  }, [fetchAll])

  /** Fin de partie validée : le journal est vidé et l'écran revient à l'affichage. */
  const finishEndgame = useCallback(async () => {
    const { error } = await supabase.rpc('online_finish_endgame')
    if (error) console.error('Erreur lors de la clôture de la partie :', error)
  }, [])

  /** Après un rétrécissement de la grille : purge silencieuse de ce qui déborde. */
  const pruneBoard = useCallback(async () => {
    const { error } = await supabase.rpc('online_prune_board')
    if (error) console.error('Erreur lors du nettoyage du plateau :', error)
    await fetchAll()
  }, [fetchAll])

  return { tokens, loading, placeToken, removeToken, updateFreeToken, clearTokens, resetBoard, finishEndgame, pruneBoard, refetch: fetchAll }
}
