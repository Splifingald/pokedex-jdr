import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import type { MiningConfig, MiningItemDef, MiningGrid, MiningGridItem, MiningGridCell, MiningMove } from '../types'
import { generateProceduralGridLayout } from '../lib/mining'

export type DigResult =
  | { status: 'ok'; itemCompleted: boolean; itemNom?: string }
  | { status: 'already_dug' }
  | { status: 'grid_exhausted' }

export interface ExhaustedSnapshot {
  grid: MiningGrid
  items: MiningGridItem[]
  cells: MiningGridCell[]
}

// Une grille est terminée soit par épuisement des coups, soit — même s'il
// reste des coups — dès que tous ses objets ont été trouvés (creuser les
// cases vides restantes n'aurait plus aucun intérêt). `items.length === 0`
// n'est volontairement pas traité comme "terminé" : une grille sans objet
// (config mal réglée) resterait jouable jusqu'à épuisement des coups plutôt
// que de tourner en boucle instantanément.
function isGridCleared(items: MiningGridItem[]): boolean {
  return items.length > 0 && items.every((it) => it.completed)
}

// Possède la grille partagée en cours : tous les joueurs qui ont le popup
// Fouille ouvert pointent sur la même grille (mining_grids.is_active = true) et
// voient les cases se creuser en direct via Realtime. Les deux seules écritures
// concurrentes-sûres (créer/renouveler la grille, creuser une case) passent par
// les fonctions RPC mining_ensure_active_grid / mining_dig_cell — voir
// supabase/schema.sql pour le détail de leur logique atomique.
export function useMiningActiveGrid(
  playerId: number,
  config: MiningConfig,
  itemDefs: MiningItemDef[],
  configLoading: boolean,
  itemDefsLoading: boolean
) {
  const channelId = useRef(Math.random().toString(36).slice(2))
  const [grid, setGrid] = useState<MiningGrid | null>(null)
  const [items, setItems] = useState<MiningGridItem[]>([])
  const [cells, setCells] = useState<MiningGridCell[]>([])
  const [moves, setMoves] = useState<MiningMove[]>([])
  const [loading, setLoading] = useState(true)
  const [justExhaustedGridId, setJustExhaustedGridId] = useState<number | null>(null)
  const [exhaustedSnapshot, setExhaustedSnapshot] = useState<ExhaustedSnapshot | null>(null)
  const prevExhaustedRef = useRef<{ gridId: number; exhausted: boolean } | null>(null)

  const loadGrid = useCallback(async (gridId: number) => {
    const [gridRes, itemsRes, cellsRes, movesRes] = await Promise.all([
      supabase.from('mining_grids').select('*').eq('id', gridId).single(),
      supabase.from('mining_grid_items').select('*').eq('grid_id', gridId),
      supabase.from('mining_grid_cells').select('*').eq('grid_id', gridId),
      supabase.from('mining_moves').select('*').eq('grid_id', gridId).order('created_at', { ascending: false }).limit(500),
    ])
    if (gridRes.error) throw gridRes.error
    setGrid(gridRes.data as MiningGrid)
    setItems(itemsRes.data ?? [])
    setCells(cellsRes.data ?? [])
    setMoves(movesRes.data ?? [])
  }, [])

  // Retourne (en la générant si besoin) l'id de la grille active. Le layout
  // procédural candidat est calculé côté client (src/lib/mining.ts) mais n'est
  // utilisé par la RPC que si aucune grille active n'existe/n'a de coups
  // restants ET qu'aucune grille personnalisée n'est en file — sinon il est
  // simplement ignoré (travail perdu, sans conséquence).
  const ensureActiveGrid = useCallback(async () => {
    setLoading(true)
    try {
      const layout = generateProceduralGridLayout(config, itemDefs)
      const { data: gridId, error } = await supabase.rpc('mining_ensure_active_grid', { p_procedural: layout })
      if (error) throw error
      await loadGrid(gridId as number)
    } catch (err) {
      console.error('Erreur lors de la génération de la grille de Fouille :', err)
    } finally {
      setLoading(false)
    }
  }, [config, itemDefs, loadGrid])

  // Appelé au montage du popup Fouille, mais seulement une fois config ET
  // itemDefs réellement chargés — sinon generateProceduralGridLayout tournerait
  // avec les DEFAULTS de useMiningConfig (move_budget_pct: 50, tailles 4-6…) et
  // un itemDefs vide (aucun objet ne pourrait jamais apparaître), puisque ces
  // deux fetches sont asynchrones et n'ont pas encore résolu au moment où cet
  // effet se déclenche lors du tout premier rendu. Sans grille active existante
  // (le cas exact où ce candidat compte réellement), ce bug était invisible
  // sauf pile au moment où une nouvelle grille devait être générée.
  useEffect(() => {
    if (!configLoading && !itemDefsLoading) ensureActiveGrid()
    // eslint-disable-next-line react-hooks/exhaustive-deps -- ne doit se déclencher qu'au passage loading -> chargé, pas à chaque nouvelle référence de ensureActiveGrid
  }, [configLoading, itemDefsLoading])

  // Déclenche le renouvellement dès que la grille suivie localement est
  // épuisée — coups à zéro (moves_used >= move_budget) OU tous les objets
  // déjà trouvés (isGridCleared) — qu'elle soit encore is_active=true (cas du
  // joueur qui vient lui-même de la vider) ou déjà false (cas de tout autre
  // joueur, mis à jour par Realtime après qu'un tiers l'ait renouvelée en
  // premier) — mining_ensure_active_grid ne bascule is_active à false que pour
  // une grille qui satisfait déjà l'une de ces deux conditions, donc les
  // surveiller couvre les deux cas avec un seul effet, pour tout le monde
  // uniformément (pas de traitement spécial pour le joueur qui a creusé le
  // coup final ou complété le dernier objet). Les appels concurrents sont
  // sans risque : la RPC les sérialise via un verrou consultatif.
  useEffect(() => {
    if (grid && grid.is_active && (grid.moves_used >= grid.move_budget || isGridCleared(items))) {
      ensureActiveGrid()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- ne doit réagir qu'aux compteurs de la grille/objets, pas à chaque nouvelle référence de ensureActiveGrid
  }, [grid?.id, grid?.moves_used, grid?.move_budget, grid?.is_active, items])

  // Détecte la transition "pas épuisée -> épuisée" (pas juste l'état courant,
  // pour ignorer le cas rare d'un montage tombant déjà sur une grille en cours
  // de renouvellement) et fige un instantané de la grille au moment exact de la
  // transition — avant que ensureActiveGrid() (déclenché par l'effet ci-dessus,
  // dans le même cycle) n'écrase grid/items/cells avec la nouvelle grille via
  // loadGrid(). Sûr : ensureActiveGrid ne mute l'état que plus tard, après un
  // await, donc les deux effets lisent ici les mêmes valeurs pré-échange.
  useEffect(() => {
    if (!grid) return
    const nowExhausted = grid.is_active && (grid.moves_used >= grid.move_budget || isGridCleared(items))
    const prev = prevExhaustedRef.current
    if (prev?.gridId === grid.id && !prev.exhausted && nowExhausted) {
      setJustExhaustedGridId(grid.id)
      setExhaustedSnapshot({ grid, items, cells })
    }
    prevExhaustedRef.current = { gridId: grid.id, exhausted: nowExhausted }
  }, [grid, items, cells])

  const clearExhaustedNotice = useCallback(() => {
    setJustExhaustedGridId(null)
    setExhaustedSnapshot(null)
  }, [])

  // Realtime : synchronise la grille partagée entre tous les joueurs. Le
  // filtrage se fait en comparant aux ids déjà en état local plutôt qu'à
  // `grid` (évite une closure périmée sur un effet à dépendances vides).
  useEffect(() => {
    const channel = supabase
      .channel(`mining-active-grid-changes-${channelId.current}`)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'mining_grids' }, (payload) => {
        const row = payload.new as MiningGrid
        setGrid((prev) => (prev && row.id === prev.id ? row : prev))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'mining_grid_items' }, (payload) => {
        const row = payload.new as MiningGridItem
        setItems((prev) => (prev.some((r) => r.id === row.id) ? prev.map((r) => (r.id === row.id ? row : r)) : prev))
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'mining_grid_cells' }, (payload) => {
        const row = payload.new as MiningGridCell
        setCells((prev) => (prev.some((r) => r.id === row.id) ? prev.map((r) => (r.id === row.id ? row : r)) : prev))
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'mining_moves' }, (payload) => {
        const row = payload.new as MiningMove
        setMoves((prev) => (prev.some((r) => r.id === row.id) ? prev : [row, ...prev]))
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const digCell = useCallback(async (cellIndex: number): Promise<DigResult> => {
    if (!grid) return { status: 'grid_exhausted' }

    const { data, error } = await supabase.rpc('mining_dig_cell', {
      p_grid_id: grid.id,
      p_player_id: playerId,
      p_cell_index: cellIndex,
    })
    if (error) {
      console.error('Erreur lors du creusage :', error)
      // Repli sûr : on ne peut pas savoir si le coup a été consommé côté serveur,
      // on ne retente pas silencieusement — l'appelant remboursera le ticket.
      return { status: 'already_dug' }
    }

    const result = data as { status: 'ok' | 'already_dug' | 'grid_exhausted'; item_completed?: boolean; item_nom?: string }

    if (result.status === 'grid_exhausted') {
      await ensureActiveGrid()
      return { status: 'grid_exhausted' }
    }

    if (result.status === 'already_dug') {
      // Resynchronise immédiatement cette case (l'update Realtime devrait déjà
      // être en route, mais on ne veut pas attendre pour débloquer le joueur).
      const { data: cellRow } = await supabase
        .from('mining_grid_cells')
        .select('*')
        .eq('grid_id', grid.id)
        .eq('cell_index', cellIndex)
        .maybeSingle()
      if (cellRow) {
        const row = cellRow as MiningGridCell
        setCells((prev) => (prev.some((r) => r.id === row.id) ? prev.map((r) => (r.id === row.id ? row : r)) : prev))
      }
      return { status: 'already_dug' }
    }

    return { status: 'ok', itemCompleted: result.item_completed ?? false, itemNom: result.item_nom }
  }, [grid, playerId, ensureActiveGrid])

  return {
    grid, items, cells, moves, loading, ensureActiveGrid, digCell,
    justExhaustedGridId, exhaustedSnapshot, clearExhaustedNotice,
  }
}
