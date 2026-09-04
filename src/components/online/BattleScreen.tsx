import { useState, useMemo, useRef, useCallback, useSyncExternalStore } from 'react'
import type { Attack, OnlineState, OnlineTileColor, Player, PlayerPokemon, Pokemon } from '../../types'
import type { UpdateOnlineState } from '../../hooks/useOnlineState'
import type { Cell } from '../../lib/onlineBoard'
import type { ResolvedToken } from '../../lib/onlineTokens'
import type { StatusId } from '../../lib/status'
import { cellKey } from '../../lib/onlineBoard'
import { canInspectToken, canMoveToken, resolveToken, resolveTurnOrder } from '../../lib/onlineTokens'
import { getMaxHp } from '../../lib/maxHp'
import { abilityRange, rangeCells } from '../../lib/abilityRange'
import { getVitalsVersion, setVitalsHp, setVitalsStatus, subscribeAllVitals } from '../../lib/pokemonVitals'
import { useOnlinePings } from '../../hooks/useOnlinePings'
import { useDisplayAssets } from '../../hooks/useDisplayAssets'
import type { useOnlineTokens } from '../../hooks/useOnlineTokens'
import type { useBoardPokemon } from '../../hooks/useBoardPokemon'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { BattleBoard } from './BattleBoard'
import { BattleSidebar } from './BattleSidebar'
import { TurnOrderBar } from './TurnOrderBar'
import { AdminBattleControls, type AdminTool, type PaintChoice } from './AdminBattleControls'

interface Props {
  state: OnlineState
  updateOnlineState: UpdateOnlineState
  patchOnlineStateLocal: (data: Partial<Omit<OnlineState, 'id' | 'updated_at'>>) => void
  player: Player | null
  players: Player[]
  pokemonList: Pokemon[]
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  isAdmin: boolean
  /** Jetons et Pokémon du plateau sont montés par la page : la fin de partie en
   *  a besoin elle aussi, et deux abonnements temps réel pour la même table
   *  seraient du gaspillage. */
  tokensApi: ReturnType<typeof useOnlineTokens>
  boardPokemon: ReturnType<typeof useBoardPokemon>
  /** Réinitialisation : la confirmation et l'appel vivent au niveau de la page,
   *  qui porte aussi le même bouton dans ses réglages. */
  onReset: () => void
  onOpenProfile: () => void
  /** Rendu centré DANS le conteneur du plateau (résultat de dé) — et non sur la
   *  fenêtre, où la barre latérale décalerait le centre. */
  boardOverlay?: React.ReactNode
}

const ADMIN_COLOR = '#dc0a2d'
const PAINT_FLUSH_MS = 250

export function BattleScreen({
  state, updateOnlineState, patchOnlineStateLocal, player, players,
  pokemonList, pokemonByName, attacksByName, isAdmin, tokensApi, boardPokemon, onReset, onOpenProfile, boardOverlay,
}: Props) {
  const { tokens: rawTokens, placeToken, removeToken, updateFreeToken } = tokensApi
  const { byId: ownedById, byPlayerId } = boardPokemon
  const { battleBackgrounds } = useDisplayAssets()
  const { pings, sendPing } = useOnlinePings({
    enabled: true,
    playerName: isAdmin ? 'MJ' : (player?.name ?? '?'),
    playerColor: isAdmin ? ADMIN_COLOR : (player?.color ?? ADMIN_COLOR),
    canSend: true,
  })

  // Deux notions distinctes : ce que MONTRE le panneau latéral, et ce qui est
  // mis en avant SUR le plateau (contour, PV, dresseur). Re-cliquer un jeton
  // retire la mise en avant sans refermer sa fiche.
  const [selectedTokenId, setSelectedTokenId] = useState<number | null>(null)
  const [boardFocusId, setBoardFocusId] = useState<number | null>(null)
  const [pendingPokemon, setPendingPokemon] = useState<{ pp: PlayerPokemon; owner: Player } | null>(null)
  const [pendingFree, setPendingFree] = useState<{ species: Pokemon; maxHp: number; damage: number; label: string } | null>(null)
  const [selectedMove, setSelectedMove] = useState<string | null>(null)
  // Le MJ peut incarner plusieurs personnages à la fois : leurs équipes
  // s'ajoutent à la suite dans la barre latérale.
  const [incarnated, setIncarnated] = useState<Player[]>([])
  // Camp par personnage incarné. Défaut : un vrai joueur est allié, un PNJ est
  // ennemi — le MJ peut renverser au cas par cas.
  const [allyFlags, setAllyFlags] = useState<Record<number, boolean>>({})
  const isAlly = useCallback((playerId: number) => {
    if (playerId in allyFlags) return allyFlags[playerId]
    return !(players.find((p) => p.id === playerId)?.is_npc ?? false)
  }, [allyFlags, players])
  const [tool, setTool] = useState<AdminTool>('ping')
  const [paintColor, setPaintColor] = useState<PaintChoice>('blocked')
  const [sidebarOpen, setSidebarOpen] = useState(true)

  // Les PV vivent dans un store partagé (lib/pokemonVitals) : sans cet
  // abonnement global, une édition faite dans la fiche ne rafraîchirait pas
  // les jauges des jetons du plateau.
  const vitalsVersion = useSyncExternalStore(subscribeAllVitals, getVitalsVersion)

  const playersById = useMemo(() => new Map(players.map((p) => [p.id, p])), [players])
  const tokens = useMemo(
    () => rawTokens.map((t) => resolveToken(t, { ownedById, pokemonByName, playersById })),
    // vitalsVersion force la reprise des PV du store à chaque édition
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [rawTokens, ownedById, pokemonByName, playersById, vitalsVersion]
  )
  const selected = tokens.find((t) => t.token.id === selectedTokenId) ?? null
  // Un seul réglage porte trois informations : visible, compact, en bas.
  const turnOrder = useMemo(() => {
    const p = state.turn_order_position
    return {
      visible: p !== 'hidden',
      compact: p === 'compact_top' || p === 'compact_bottom',
      atBottom: p === 'bottom' || p === 'compact_bottom',
    }
  }, [state.turn_order_position])

  const turnOrdered = useMemo(
    () => resolveTurnOrder(tokens, state.turn_order),
    [tokens, state.turn_order]
  )
  const placedPokemonIds = useMemo(
    () => new Set(tokens.map((t) => t.token.player_pokemon_id).filter((id): id is number => id != null)),
    [tokens]
  )

  const backgroundUrl = useMemo(
    () => battleBackgrounds.find((b) => b.nom === state.battle_background_nom)?.image_url ?? '',
    [battleBackgrounds, state.battle_background_nom]
  )

  const sidebarAvailable = isAdmin || state.players_sidebar_enabled
  const canPlace = isAdmin || state.players_move_enabled
  // Le MJ pose autant de jetons qu'il veut ; incarner des personnages lui donne
  // leurs équipes, à la suite, dans la barre latérale. Chaque entrée garde son
  // propriétaire : c'est lui qui décide du camp du jeton posé.
  const teamEntries = useMemo(() => {
    const owners = isAdmin ? incarnated : (player ? [player] : [])
    return owners.flatMap((owner) =>
      (byPlayerId.get(owner.id) ?? []).filter((pp) => pp.in_team).map((pp) => ({ pp, owner }))
    )
  }, [byPlayerId, isAdmin, incarnated, player])

  // Portée de la capacité choisie : surlignage strictement local, sélectionner
  // une capacité ne l'utilise pas et n'est diffusé à personne.
  const highlightedCells = useMemo(() => {
    if (!selected || !selectedMove) return new Set<string>()
    const attack = attacksByName.get(selectedMove)
    if (!attack) return new Set<string>()
    const origin = { col: selected.token.cell_col, row: selected.token.cell_row }
    return rangeCells(origin, abilityRange(attack.distance), state.grid_cols, state.grid_rows)
  }, [selected, selectedMove, attacksByName, state.grid_cols, state.grid_rows])

  // Coloriage : repeinture locale immédiate, une seule écriture groupée à la fin
  // du glissé (un glissé traverse facilement vingt cases).
  const paintTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const paintDraftRef = useRef<{ colored: Record<string, OnlineTileColor>; blocked: string[] } | null>(null)

  const flushPaint = useCallback(() => {
    paintTimerRef.current = null
    const draft = paintDraftRef.current
    paintDraftRef.current = null
    if (draft) void updateOnlineState({ colored_cells: draft.colored, blocked_cells: draft.blocked })
  }, [updateOnlineState])

  // Peindre couvre les deux calques : les teintes sont de simples repères, le
  // noir « Bloquée » rend la case inaccessible. Les deux s'excluent sur une même
  // case, et la gomme retire l'un comme l'autre.
  const handleCellPaint = useCallback((cell: Cell) => {
    if (!isAdmin || tool !== 'paint') return
    const key = cellKey(cell.col, cell.row)
    const base = paintDraftRef.current ?? { colored: state.colored_cells, blocked: state.blocked_cells }
    const colored = { ...base.colored }
    let blocked = base.blocked
    if (paintColor === null) {
      delete colored[key]
      blocked = blocked.filter((k) => k !== key)
    } else if (paintColor === 'blocked') {
      delete colored[key]
      if (!blocked.includes(key)) blocked = [...blocked, key]
    } else {
      blocked = blocked.filter((k) => k !== key)
      colored[key] = paintColor
    }
    const next = { colored, blocked }
    paintDraftRef.current = next
    patchOnlineStateLocal({ colored_cells: colored, blocked_cells: blocked })
    if (paintTimerRef.current) clearTimeout(paintTimerRef.current)
    paintTimerRef.current = setTimeout(flushPaint, PAINT_FLUSH_MS)
  }, [isAdmin, tool, paintColor, state.colored_cells, state.blocked_cells, patchOnlineStateLocal, flushPaint])

  const handleCellActivate = useCallback((cell: Cell) => {
    // Une pose en attente prime sur tout le reste : le joueur a choisi un
    // Pokémon dans la barre latérale et désigne maintenant sa case.
    if (pendingPokemon) {
      const { pp, owner } = pendingPokemon
      void placeToken({
        ownerPlayerId: owner.id,
        playerPokemonId: pp.id,
        pokemonNom: pp.pokemon_nom,
        col: cell.col,
        row: cell.row,
        placedByAdmin: isAdmin,
        maxHp: getMaxHp(pp, pokemonByName.get(pp.pokemon_nom)),
        isAlly: isAlly(owner.id),
      })
      setPendingPokemon(null)
      return
    }
    if (pendingFree && isAdmin) {
      void placeToken({
        pokemonNom: pendingFree.species.nom,
        col: cell.col,
        row: cell.row,
        placedByAdmin: true,
        free: {
          max_hp: pendingFree.maxHp,
          current_hp: pendingFree.maxHp,
          damage: pendingFree.damage,
          label: pendingFree.label,
        },
        maxHp: pendingFree.maxHp,
        isAlly: false,
      })
      setPendingFree(null)
      return
    }
    if (isAdmin && tool === 'paint') return // déjà traité par handleCellPaint
    sendPing(cell.col, cell.row)
  }, [pendingPokemon, pendingFree, isAdmin, tool, placeToken, sendPing, pokemonByName, isAlly])

  const handleMoveToken = useCallback((t: ResolvedToken, cell: Cell) => {
    void placeToken({
      tokenId: t.token.id,
      ownerPlayerId: t.token.owner_player_id,
      playerPokemonId: t.token.player_pokemon_id,
      pokemonNom: t.token.pokemon_nom,
      col: cell.col,
      row: cell.row,
      placedByAdmin: isAdmin,
      isAlly: t.token.is_ally,
    })
  }, [placeToken, isAdmin])

  // Cliquer un Pokémon de l'équipe : s'il est déjà sur le plateau, on ouvre sa
  // fiche et on le sélectionne plutôt que de redemander où le poser.
  // Amorcer une pose, c'est désigner une case au clic suivant : rester sur
  // l'outil « Colorier » peindrait cette case au lieu d'y poser le Pokémon.
  const armPlacement = useCallback(() => setTool('ping'), [])

  const handlePickFromTeam = useCallback((pp: PlayerPokemon, owner: Player) => {
    const placed = tokens.find((t) => t.token.player_pokemon_id === pp.id)
    setPendingFree(null)
    if (placed) {
      setPendingPokemon(null)
      setSelectedTokenId(placed.token.id)
      setBoardFocusId(placed.token.id)
      setSelectedMove(null)
      return
    }
    setPendingPokemon({ pp, owner })
    armPlacement()
  }, [tokens, armPlacement])

  const handleSelectToken = useCallback((t: ResolvedToken) => {
    // Un jeton qu'on n'a pas le droit d'inspecter (celui d'un autre joueur)
    // sert quand même à pointer : on pinge sa case.
    if (!canInspectToken(t, player?.id ?? null, isAdmin)) {
      sendPing(t.token.cell_col, t.token.cell_row)
      return
    }
    // Re-cliquer le jeton déjà mis en avant le retire du plateau seulement :
    // sa fiche reste ouverte dans le panneau.
    if (boardFocusId === t.token.id) {
      setBoardFocusId(null)
      return
    }
    setSelectedTokenId(t.token.id)
    setBoardFocusId(t.token.id)
    setSelectedMove(null)
  }, [player, isAdmin, boardFocusId, sendPing])

  const handleSetHp = useCallback((value: number) => {
    if (!selected) return
    if (selected.owned) setVitalsHp(selected.owned.id, value, selected.maxHp)
    else void updateFreeToken(selected.token.id, { free_current_hp: Math.max(0, Math.min(selected.maxHp, value)) })
  }, [selected, updateFreeToken])

  const handleSetStatus = useCallback((value: StatusId) => {
    if (!selected) return
    if (selected.owned) setVitalsStatus(selected.owned.id, value)
    else void updateFreeToken(selected.token.id, { free_status: value })
  }, [selected, updateFreeToken])

  const adminControls = isAdmin ? (
    <AdminBattleControls
      players={players}
      incarnated={incarnated}
      onIncarnate={(p) => setIncarnated((prev) => (prev.some((c) => c.id === p.id) ? prev : [...prev, p]))}
      onRelease={(id) => setIncarnated((prev) => prev.filter((c) => c.id !== id))}
      isAlly={isAlly}
      onToggleAlly={(id) => setAllyFlags((prev) => ({ ...prev, [id]: !isAlly(id) }))}
      pokemonCatalog={pokemonList}
      onPlaceFreeSpecies={(species, maxHp, damage, label) => { setPendingFree({ species, maxHp, damage, label }); armPlacement() }}
      tool={tool}
      onToolChange={setTool}
      paintColor={paintColor}
      onPaintColorChange={setPaintColor}
      onReset={onReset}
    />
  ) : undefined

  return (
    <div className="w-full h-full bg-cream flex flex-col md:flex-row overflow-hidden safe-overlay">
        {sidebarAvailable && sidebarOpen && (
          <aside className="h-[42%] md:h-full md:w-80 shrink-0 border-b-[3px] md:border-b-0 md:border-r-[3px] border-ink bg-cream overflow-hidden">
            <BattleSidebar
              viewer={player}
              onOpenProfile={onOpenProfile}
              teamEntries={teamEntries}
              teamLabel={isAdmin ? (incarnated.length > 0 ? 'Équipes incarnées' : 'Incarne un personnage pour voir son équipe') : 'Mon équipe'}
              pokemonByName={pokemonByName}
              attacksByName={attacksByName}
              canPlace={canPlace}
              pendingPokemonId={pendingPokemon?.pp.id ?? null}
              onPickForPlacement={handlePickFromTeam}
              placedPokemonIds={placedPokemonIds}
              selected={selected}
              canEditSelected={!!selected && (isAdmin || selected.token.owner_player_id === player?.id)}
              selectedMove={selectedMove}
              onSelectMove={setSelectedMove}
              onSetHp={handleSetHp}
              onSetStatus={handleSetStatus}
              onRemoveToken={selected ? () => { void removeToken(selected.token.id, player?.id ?? null, isAdmin); setSelectedTokenId(null); setBoardFocusId(null) } : undefined}
              onBack={() => { setSelectedTokenId(null); setBoardFocusId(null); setSelectedMove(null) }}
              adminControls={adminControls}
            />
          </aside>
        )}

        <div className="relative flex-1 min-h-0">
          <BattleBoard
            state={state}
            backgroundUrl={backgroundUrl}
            tokens={tokens}
            viewer={{ playerId: player?.id ?? null, isAdmin, alwaysShowHp: false }}
            selectedTokenId={boardFocusId}
            highlightedCells={highlightedCells}
            paintMode={isAdmin && tool === 'paint'}
            readOnly={false}
            pings={pings}
            canMoveToken={(t) => canMoveToken(t, player?.id ?? null, isAdmin, state.players_move_enabled)}
            onSelectToken={handleSelectToken}
            onMoveToken={handleMoveToken}
            onCellActivate={handleCellActivate}
            onCellPaint={handleCellPaint}
            // Saisir un jeton désélectionne la capacité en cours : sa portée et
            // l'aperçu de déplacement se superposeraient sinon, deux zones de
            // même teinte dont on ne saurait plus laquelle dit quoi.
            onTokenDragStart={() => setSelectedMove(null)}
            onRowsChange={isAdmin ? (rows) => void updateOnlineState({ grid_rows: rows }) : undefined}
          />

          {boardOverlay}

          <div className="absolute left-2 top-2 flex items-center gap-2 z-40">
            {sidebarAvailable && (
              <button
                onClick={() => setSidebarOpen((v) => !v)}
                className={`px-2.5 py-1.5 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}
              >
                {sidebarOpen ? '◀ Masquer' : '▶ Mon équipe'}
              </button>
            )}
            {(pendingPokemon || pendingFree) && (
              <span className="px-2.5 py-1.5 rounded text-xs font-bold bg-cream border-2 border-ink text-ink shadow-[var(--shadow-pixel-sm)]">
                Touche une case pour poser
              </span>
            )}
          </div>

          {/* Ordre du tour : visible par tous ; le MJ choisit la forme et le côté */}
          {turnOrder.visible && (
          <div className={`absolute left-1/2 -translate-x-1/2 z-[45] ${turnOrder.atBottom ? 'bottom-3' : 'top-3'}`}>
            <TurnOrderBar
              ordered={turnOrdered}
              activeTokenId={state.turn_active_token_id}
              isAdmin={isAdmin}
              compact={turnOrder.compact}
              onReorder={(ids) => void updateOnlineState({ turn_order: ids })}
              onToggleActive={(id) => void updateOnlineState({
                turn_active_token_id: state.turn_active_token_id === id ? null : id,
              })}
            />
          </div>
          )}

      </div>
    </div>
  )
}
