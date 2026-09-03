import { useEffect, useMemo, useState, useCallback, useRef, useSyncExternalStore } from 'react'
import { usePlayerContext } from '../context/PlayerContext'
import { usePlayers } from '../hooks/usePlayers'
import { usePokemon } from '../hooks/usePokemon'
import { useAttacks } from '../hooks/useAttacks'
import { useItems } from '../hooks/useItems'
import { useDisplayState } from '../hooks/useDisplayState'
import { useDisplayAssets } from '../hooks/useDisplayAssets'
import { useOnlineState } from '../hooks/useOnlineState'
import { useOnlineTokens } from '../hooks/useOnlineTokens'
import { useBoardPokemon } from '../hooks/useBoardPokemon'
import { useFullscreen } from '../hooks/useFullscreen'
import { resolveDisplayState } from '../lib/resolveDisplayState'
import { DisplayCanvas } from '../components/display/DisplayCanvas'
import { BattleScreen } from '../components/online/BattleScreen'
import { OnlineSettingsModal } from '../components/online/OnlineSettingsModal'
import { OnlineChrome } from '../components/online/OnlineChrome'
import { ConfirmPopup } from '../components/ConfirmPopup'
import { PlayerProfilePopup } from '../components/PlayerProfilePopup'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { useBattleLog } from '../hooks/useBattleLog'
import { getVitalsVersion, subscribeAllVitals } from '../lib/pokemonVitals'
import { buildEndgameEntries, applyEndgameRewards, type ItemGrant } from '../lib/endgame'
import { EndgameOutcomeModal } from '../components/online/EndgameOutcomeModal'
import { EndgameResultsPanel } from '../components/online/EndgameResultsPanel'
import { EndgameRewardsModal } from '../components/online/EndgameRewardsModal'
import { EndgameOverlay } from '../components/online/EndgameOverlay'
import { EndgameAckPanel } from '../components/online/EndgameAckPanel'
import { DiceResultOverlay, type DiceResult } from '../components/online/DiceResultOverlay'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import type { EndgameOutcome } from '../types'

// Écran partagé unique — servi à la fois par /display et /battle.
//
// C'est la seule surface commune du jeu : les joueurs y arrivent en mode
// « affichage » (l'image pilotée par le MJ) et basculent en mode « bataille »
// quand le MJ le décide, sans changer de page ni d'onglet.
//
// Contrairement à l'ancienne page /display, celle-ci est rendue DANS les
// providers (voir main.tsx) : elle doit savoir quel personnage joue, pour la
// barre latérale d'équipe, les pings et les récompenses de fin de partie.
export function OnlinePage() {
  const { player, updatePlayer } = usePlayerContext()
  const { players } = usePlayers()
  const { pokemon } = usePokemon()
  const { byName: attacksByName } = useAttacks()
  const { items, byName: itemsByName } = useItems()
  const online = useOnlineState()
  const battle = online.state.mode === 'battle'

  // Montés ici plutôt que dans BattleScreen : le bilan de fin de partie a
  // besoin des mêmes données, et deux abonnements temps réel sur les mêmes
  // tables seraient du gaspillage.
  const tokensApi = useOnlineTokens()
  const boardPokemon = useBoardPokemon(battle)

  const displayStateApi = useDisplayState()
  const { assets } = useDisplayAssets()
  const { toggle: toggleFullscreen } = useFullscreen()
  const [isAdmin] = useState(() => sessionStorage.getItem('adminMode') === 'true')
  const { parameters } = useAdminParameters()
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [showProfile, setShowProfile] = useState(false)
  const [choosingOutcome, setChoosingOutcome] = useState(false)
  const [savingRewards, setSavingRewards] = useState(false)

  // Résultat du lancer de dé : porté ici pour être affiché DANS le conteneur du
  // plateau, dont le centre n'est pas celui de la fenêtre quand la barre
  // latérale est ouverte. Durée alignée sur l'animation dice-result.
  const [diceResult, setDiceResult] = useState<DiceResult | null>(null)
  const diceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  useEffect(() => () => { if (diceTimerRef.current) clearTimeout(diceTimerRef.current) }, [])
  const handleRoll = useCallback((sides: number, value: number) => {
    setDiceResult({ sides, value, at: Date.now() })
    if (diceTimerRef.current) clearTimeout(diceTimerRef.current)
    diceTimerRef.current = setTimeout(() => setDiceResult(null), 3000)
  }, [])

  // ── Fin de partie ──
  const phase = online.state.endgame_phase
  const { rows: battleLog } = useBattleLog(battle)
  // Les PV vivent dans un store partagé : sans cet abonnement, le bilan
  // afficherait les valeurs figées au montage.
  const vitalsVersion = useSyncExternalStore(subscribeAllVitals, getVitalsVersion)
  const [confirmingReset, setConfirmingReset] = useState(false)

  useEffect(() => {
    document.title = battle ? 'Plateau de bataille' : 'Affichage'
  }, [battle])

  const pokemonByName = useMemo(() => new Map(pokemon.map((p) => [p.nom, p])), [pokemon])
  const displayed = useMemo(
    () => resolveDisplayState(displayStateApi.state, assets, pokemon, items, players),
    [displayStateApi.state, assets, pokemon, items, players]
  )

  const endgameEntries = useMemo(
    () => buildEndgameEntries({
      log: battleLog,
      tokens: tokensApi.tokens,
      ownedById: boardPokemon.byId,
      pokemonByName,
    }),
    // vitalsVersion force la reprise des PV du store à chaque édition
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [battleLog, tokensApi.tokens, boardPokemon.byId, pokemonByName, vitalsVersion]
  )

  const participantIds = useMemo(
    () => [...new Set(endgameEntries.filter((e) => e.isAlly && e.ownerPlayerId != null).map((e) => e.ownerPlayerId as number))],
    [endgameEntries]
  )

  // Le bouton de fin de partie s'invite sur le plateau dès qu'il ne reste plus
  // un seul ennemi debout — c'est le moment où le MJ en a besoin.
  const allEnemiesDown = useMemo(() => {
    const enemies = endgameEntries.filter((e) => !e.isAlly && e.stillOnBoard)
    return enemies.length > 0 && enemies.every((e) => e.isKo)
  }, [endgameEntries])

  const startEndgame = useCallback(async (outcome: EndgameOutcome) => {
    setChoosingOutcome(false)
    // La vue épurée passe à tout le monde : le plateau devient présentable.
    await online.updateOnlineState({ endgame_phase: 'pending', endgame_outcome: outcome, hide_layout: true })
  }, [online])

  const handleValidateRewards = useCallback(async (xpByPokemon: Map<number, number>, grants: ItemGrant[]) => {
    setSavingRewards(true)
    try {
      const rewards = await applyEndgameRewards(xpByPokemon, endgameEntries, grants, participantIds)
      await online.updateOnlineState({ endgame_phase: 'rewards', endgame_rewards: rewards, endgame_acked: [] })
    } finally {
      setSavingRewards(false)
    }
  }, [endgameEntries, participantIds, online])

  const ackRewards = useCallback(async () => {
    if (!player) return
    const next = [...new Set([...online.state.endgame_acked, player.id])]
    await online.updateOnlineState({ endgame_acked: next })
  }, [player, online])

  // Tout le monde a vu son récapitulatif : on referme et on repasse en
  // affichage. Seul le MJ déclenche, pour éviter des appels concurrents.
  useEffect(() => {
    if (!isAdmin || phase !== 'rewards' || participantIds.length === 0) return
    if (!participantIds.every((id) => online.state.endgame_acked.includes(id))) return
    void tokensApi.finishEndgame()
  }, [isAdmin, phase, participantIds, online.state.endgame_acked, tokensApi])

  // Le MJ doit choisir un décor avant de pouvoir jouer : les réglages s'ouvrent
  // d'eux-mêmes tant qu'aucun plateau n'est sélectionné.
  const needsBattleBackground = isAdmin && battle && !online.state.battle_background_nom
  const showSettings = isAdmin && (settingsOpen || needsBattleBackground)

  // Re-découper change le sens des coordonnées : une case (10,4) ne désigne
  // plus le même endroit du décor. On vide donc tout ce qui était posé.
  const handleColsChange = useCallback(async (cols: number) => {
    const next = Math.max(1, Math.min(60, cols))
    if (next === online.state.grid_cols) return
    const hasContent = tokensApi.tokens.length > 0
      || online.state.blocked_cells.length > 0
      || Object.keys(online.state.colored_cells).length > 0
    if (hasContent && !window.confirm('Re-découper le terrain retire tous les Pokémon posés, les cases bloquées et les couleurs. Continuer ?')) return
    await online.updateOnlineState({ grid_cols: next, blocked_cells: [], colored_cells: {} })
    await tokensApi.clearTokens()
  }, [online, tokensApi])

  return (
    <div className="fixed inset-0 w-screen h-screen overflow-hidden bg-black">
      {battle ? (
        <BattleScreen
          state={online.state}
          updateOnlineState={online.updateOnlineState}
          patchOnlineStateLocal={online.patchLocal}
          player={player}
          players={players}
          pokemonList={pokemon}
          pokemonByName={pokemonByName}
          attacksByName={attacksByName}
          isAdmin={isAdmin}
          tokensApi={tokensApi}
          boardPokemon={boardPokemon}
          onReset={() => setConfirmingReset(true)}
          onOpenProfile={() => setShowProfile(true)}
          boardOverlay={<DiceResultOverlay result={diceResult} />}
        />
      ) : (
        <DisplayCanvas
          backgroundUrl={displayed.backgroundUrl}
          npcs={displayed.npcs}
          pokemons={displayed.pokemons}
          items={displayed.items}
          className="w-full h-full"
        />
      )}

      {/* En mode affichage, l'image occupe tout l'écran : ce conteneur EST le plateau. */}
      {!battle && <DiceResultOverlay result={diceResult} />}

      <OnlineChrome
        player={player}
        isAdmin={isAdmin}
        onOpenSettings={() => setSettingsOpen(true)}
        onToggleFullscreen={toggleFullscreen}
        showProfileButton={!battle}
        onOpenProfile={() => setShowProfile(true)}
        onRoll={handleRoll}
      />

      {showSettings && (
        <OnlineSettingsModal
          online={online}
          requireBattleBackground={needsBattleBackground}
          onColsChange={(c) => void handleColsChange(c)}
          onReset={() => { setSettingsOpen(false); setConfirmingReset(true) }}
          onEndgame={() => { setSettingsOpen(false); setChoosingOutcome(true) }}
          canEndgame={battleLog.length > 0}
          onClose={() => setSettingsOpen(false)}
        />
      )}

      {/* Le bouton s'invite dès qu'il ne reste plus un ennemi debout */}
      {isAdmin && battle && phase === 'none' && allEnemiesDown && (
        <button
          onClick={() => setChoosingOutcome(true)}
          className={`absolute left-2 bottom-2 z-40 px-3 py-2 rounded text-sm font-bold ${BUTTON_STYLE.green}`}
        >
          🏁 Terminer la partie
        </button>
      )}

      {choosingOutcome && (
        <EndgameOutcomeModal
          onChoose={(o) => void startEndgame(o)}
          onCancel={() => setChoosingOutcome(false)}
        />
      )}

      {/* Le MJ prépare le bilan pendant que les joueurs patientent */}
      {isAdmin && phase === 'pending' && (
        <EndgameResultsPanel
          entries={endgameEntries}
          players={players}
          itemsList={items}
          pokemonByName={pokemonByName}
          saving={savingRewards}
          onValidate={(xp, grants) => void handleValidateRewards(xp, grants)}
          onCancel={() => void online.updateOnlineState({ endgame_phase: 'none', endgame_outcome: null })}
        />
      )}

      {!isAdmin && phase === 'pending' && <EndgameOverlay outcome={online.state.endgame_outcome} />}

      {!isAdmin && phase === 'rewards' && player && participantIds.includes(player.id) && (
        <EndgameRewardsModal
          playerId={player.id}
          outcome={online.state.endgame_outcome}
          rewards={online.state.endgame_rewards}
          itemsByName={itemsByName}
          acked={online.state.endgame_acked.includes(player.id)}
          onAck={() => void ackRewards()}
        />
      )}

      {isAdmin && phase === 'rewards' && (
        <EndgameAckPanel
          participants={players.filter((p) => participantIds.includes(p.id))}
          ackedIds={online.state.endgame_acked}
          onForceFinish={() => void tokensApi.finishEndgame()}
        />
      )}

      {showProfile && player && (
        <PlayerProfilePopup
          player={player}
          canEdit
          parameters={parameters}
          onUpdate={updatePlayer}
          onClose={() => setShowProfile(false)}
        />
      )}

      {confirmingReset && (
        <ConfirmPopup
          title="Réinitialiser le plateau ?"
          message="Tous les jetons, les cases bloquées, les cases coloriées, le fond et la taille de grille reviennent à zéro."
          confirmLabel="Réinitialiser"
          danger
          onConfirm={() => { void tokensApi.resetBoard(); setConfirmingReset(false) }}
          onCancel={() => setConfirmingReset(false)}
        />
      )}
    </div>
  )
}
