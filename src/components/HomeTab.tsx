import { useState, useEffect, useRef } from 'react'
import type { Player, Pokemon, Attack, Item, PlayerPokemon, PokemonEvolution } from '../types'
import { DEFAULT_ACCUEIL_IMAGE_URL, ownedPokemonName, POKEDOLLAR_ITEM_NAME } from '../types'
import { usePlayerPokemon } from '../hooks/usePlayerPokemon'
import { usePlayerItems } from '../hooks/usePlayerItems'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { useDisplayAssets } from '../hooks/useDisplayAssets'
import { useGiftLootboxes } from '../hooks/useGiftLootboxes'
import { useToast } from '../context/ToastContext'
import { RoamingPokemonSprite } from './RoamingPokemonSprite'
import { PokemonDetailSheet } from './PokemonDetailSheet'
import { GiftPopup, type GiftReward } from './GiftPopup'
import { CasinoPopup } from './CasinoPopup'
import { MiniGamesPopup } from './MiniGamesPopup'
import { MiningPopup } from './MiningPopup'
import { PensionPopup } from './PensionPopup'
import { SafariPopup } from './SafariPopup'
import { AutoBattlePopup } from './AutoBattlePopup'
import { ChatPopup } from './chat/ChatPopup'
import { useChatMessages } from '../hooks/useChatMessages'
import { useChatUnread } from '../hooks/useChatUnread'
import { useMinigamesConfig } from '../hooks/useMinigamesConfig'
import { useMinigamesPlayerState } from '../hooks/useMinigamesPlayerState'
import { useCasinoConfig } from '../hooks/useCasinoConfig'
import { useCasinoPlayerState } from '../hooks/useCasinoPlayerState'
import { useMiningConfig } from '../hooks/useMiningConfig'
import { useMiningPlayerState } from '../hooks/useMiningPlayerState'
import { useAutoBattleConfig } from '../hooks/useAutoBattleConfig'
import { useAutoBattlePlayerState } from '../hooks/useAutoBattlePlayerState'
import { useSafariConfig } from '../hooks/useSafariConfig'
import { useSafariPlayerState } from '../hooks/useSafariPlayerState'
import { useTicketRegen, useSafariTicketRegen } from '../hooks/useTicketRegen'
import { TICKET_CASINO_ITEM_NAME, TICKET_TREMPETTE_ITEM_NAME, TICKET_MINING_ITEM_NAME, TICKET_AUTOBATTLE_ITEM_NAME, BERRY_SAFARI_ITEM_NAME, BALL_SAFARI_ITEM_NAME } from '../types'
import { hasAnyMinigameAvailable } from '../lib/magikarpGame'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { PixelIcon } from './icons/PixelIcon'
import { PHOTO_ICON, CASINO_MASCOT_ICON, MINIGAMES_ICON, MINING_ICON, PENSION_ICON, SAFARI_ICON, AUTOBATTLE_ICON } from '../lib/icons'
import { isGiftReady, resolveLootboxForSpecies, drawLootboxReward, randomNextGiftAt, maybeResetGiftTimerOnEntry } from '../lib/gifting'
import { logHistoryEvent } from '../lib/historyLog'

interface Props {
  player: Player | null
  players: Player[]
  isAdmin: boolean
  pokemonByName: Map<string, Pokemon>
  discoveredPokemon: Set<string>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  playerItems: ReturnType<typeof usePlayerItems>
  evolutionsByPokemonNom: Map<string, PokemonEvolution[]>
  canScan: boolean
  onScan: () => void
  onRequestLogin: () => void
}

// Fond d'accueil : image configurable dans Admin → Paramètres.
// "cover" priorise le remplissage de la hauteur (c'est déjà le facteur
// limitant sur écran étroit) mais évite les bandes vides sur écran large
// en agrandissant l'image jusqu'à couvrir aussi la largeur, quitte à
// rogner un peu le haut/bas.
const homeBgStyle = (url: string): React.CSSProperties => ({
  backgroundColor: '#4f9a41',
  backgroundImage: `url(${url})`,
  backgroundSize: 'cover',
  backgroundPosition: 'center',
  backgroundRepeat: 'no-repeat',
})

export function HomeTab({ player, players, isAdmin, pokemonByName, discoveredPokemon, attacksByName, itemsByName, playerItems, evolutionsByPokemonNom, canScan, onScan, onRequestLogin }: Props) {
  const { roster, updateXp, updateNickname, evolvePokemon, toggleInTeam, setNextGiftAt, addMove, removeMove, deleteOwnedPokemon, markEggRevealSeen } = usePlayerPokemon(player?.id ?? null)
  const { pokedollars, addItems, setPokedollars } = playerItems
  const { parameters } = useAdminParameters()
  const { backgrounds } = useDisplayAssets()
  const { lootboxes, lootboxItems, speciesAssignments } = useGiftLootboxes()
  const { config: minigamesConfig } = useMinigamesConfig()
  const { config: casinoConfig } = useCasinoConfig()
  const { config: miningConfig } = useMiningConfig()
  const { config: autoBattleConfig } = useAutoBattleConfig()
  const { config: safariConfig } = useSafariConfig()
  const { showToast } = useToast()

  const { state: minigamesTicketState, updateState: updateMinigamesTicketState } = useMinigamesPlayerState(player?.id ?? null)
  const { state: casinoTicketState, updateState: updateCasinoTicketState } = useCasinoPlayerState(player?.id ?? null)
  const { state: miningTicketState, updateState: updateMiningTicketState } = useMiningPlayerState(player?.id ?? null)
  const { state: autoBattleTicketState, updateState: updateAutoBattleTicketState } = useAutoBattlePlayerState(player?.id ?? null)
  const { state: safariTicketState, updateState: updateSafariTicketState } = useSafariPlayerState(player?.id ?? null)

  const sceneRef = useRef<HTMLDivElement>(null)
  const [selectedId, setSelectedId] = useState<number | null>(null)
  // true uniquement quand la fiche est ouverte depuis Safari, qui doit rester
  // ouvert derrière (contrairement à Mini-Jeux/Pension qui se ferment) — la
  // fiche doit alors passer au-dessus du popup Safari (z-50) plutôt que
  // d'être masquée par lui.
  const [selectedElevated, setSelectedElevated] = useState(false)
  const [jumpingId, setJumpingId] = useState<number | null>(null)
  const [giftPokemonId, setGiftPokemonId] = useState<number | null>(null)
  const [giftReward, setGiftReward] = useState<GiftReward | null>(null)
  const [showCasino, setShowCasino] = useState(false)
  const [showMiniGames, setShowMiniGames] = useState(false)
  const [showMining, setShowMining] = useState(false)
  const [showPension, setShowPension] = useState(false)
  const [showSafari, setShowSafari] = useState(false)
  const [showAutoBattle, setShowAutoBattle] = useState(false)
  const [showChat, setShowChat] = useState(false)
  const chat = useChatMessages()
  const { unreadCount, markSeen } = useChatUnread(chat.messages)

  // Régénération des tickets/ressources de mini-jeux en tâche de fond : dès
  // que l'app est ouverte et le jeu débloqué, sans avoir besoin d'ouvrir son
  // popup (les popups eux-mêmes n'affichent plus que le compte à rebours).
  const minigamesTicketCount = playerItems.inventory.find((r) => r.item_nom === TICKET_TREMPETTE_ITEM_NAME)?.quantity ?? 0
  const casinoTicketCount = playerItems.inventory.find((r) => r.item_nom === TICKET_CASINO_ITEM_NAME)?.quantity ?? 0
  const miningTicketCount = playerItems.inventory.find((r) => r.item_nom === TICKET_MINING_ITEM_NAME)?.quantity ?? 0
  const autoBattleTicketCount = playerItems.inventory.find((r) => r.item_nom === TICKET_AUTOBATTLE_ITEM_NAME)?.quantity ?? 0
  const safariBerryCount = playerItems.inventory.find((r) => r.item_nom === BERRY_SAFARI_ITEM_NAME)?.quantity ?? 0
  const safariBallCount = playerItems.inventory.find((r) => r.item_nom === BALL_SAFARI_ITEM_NAME)?.quantity ?? 0

  useTicketRegen(
    !!player && parameters.feature_minijeux_enabled && !!minigamesTicketState,
    player?.id ?? 0, TICKET_TREMPETTE_ITEM_NAME, minigamesTicketCount,
    minigamesTicketState?.next_ticket_at ?? null, minigamesConfig, playerItems, updateMinigamesTicketState
  )
  useTicketRegen(
    !!player && (casinoConfig.slots_enabled || casinoConfig.dice_enabled) && !!casinoTicketState,
    player?.id ?? 0, TICKET_CASINO_ITEM_NAME, casinoTicketCount,
    casinoTicketState?.next_ticket_at ?? null, casinoConfig, playerItems, updateCasinoTicketState
  )
  useTicketRegen(
    !!player && parameters.feature_mining_enabled && !!miningTicketState,
    player?.id ?? 0, TICKET_MINING_ITEM_NAME, miningTicketCount,
    miningTicketState?.next_ticket_at ?? null, miningConfig, playerItems, updateMiningTicketState
  )
  useTicketRegen(
    !!player && parameters.feature_autobattle_enabled && !!autoBattleTicketState,
    player?.id ?? 0, TICKET_AUTOBATTLE_ITEM_NAME, autoBattleTicketCount,
    autoBattleTicketState?.next_ticket_at ?? null, autoBattleConfig, playerItems, updateAutoBattleTicketState
  )
  useSafariTicketRegen(
    !!player && parameters.feature_safari_enabled && !!safariTicketState,
    player?.id ?? 0, BERRY_SAFARI_ITEM_NAME, BALL_SAFARI_ITEM_NAME, safariBerryCount, safariBallCount,
    safariTicketState?.next_berry_at ?? null, safariTicketState?.next_ball_at ?? null, safariConfig, playerItems, updateSafariTicketState
  )

  // Recalcul périodique de "maintenant" pour détecter les cadeaux devenus prêts
  // pendant que l'app reste ouverte — pas de compte à rebours affiché, juste
  // une réévaluation silencieuse toutes les 30s.
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const interval = window.setInterval(() => setNow(Date.now()), 30_000)
    return () => clearInterval(interval)
  }, [])

  const team = roster.filter((r) => r.in_team)
  const teamFull = player?.is_npc ? false : team.length >= parameters.max_team_size
  const selected = roster.find((r) => r.id === selectedId) ?? null
  const giftPokemon = roster.find((r) => r.id === giftPokemonId) ?? null

  const hasGift = (pp: PlayerPokemon) =>
    parameters.feature_gifting_enabled && isGiftReady(pp, player?.is_npc ?? false, new Date(now))

  // Saut aléatoire : un seul membre de l'équipe à la fois, toutes les 5–10 s
  const teamRef = useRef(team)
  useEffect(() => { teamRef.current = team }, [team])

  useEffect(() => {
    let cancelled = false
    let loopTimer: number
    let endTimer: number

    const loop = () => {
      loopTimer = window.setTimeout(() => {
        if (cancelled) return
        const current = teamRef.current
        if (current.length > 0) {
          const pick = current[Math.floor(Math.random() * current.length)]
          setJumpingId(pick.id)
          endTimer = window.setTimeout(() => { if (!cancelled) setJumpingId(null) }, 600)
        }
        loop()
      }, 5000 + Math.random() * 5000)
    }
    loop()

    return () => {
      cancelled = true
      clearTimeout(loopTimer)
      clearTimeout(endTimer)
    }
  }, [])

  const handleToggleInTeam = async (id: number, inTeam: boolean) => {
    const pp = roster.find((r) => r.id === id)
    await toggleInTeam(id, inTeam)
    if (pp) {
      if (player) {
        void logHistoryEvent('team', 'pokemon_move', player.id, {
          pokemon_nom: pp.pokemon_nom,
          player_pokemon_id: pp.id,
          nickname: pp.nickname,
          destination: inTeam ? 'team' : 'pc',
        })
      }
      await maybeResetGiftTimerOnEntry({
        giftingEnabled: parameters.feature_gifting_enabled,
        isNpc: player?.is_npc ?? false,
        wasInTeam: pp.in_team,
        willBeInTeam: inTeam,
        pokemonNom: pp.pokemon_nom,
        playerPokemonId: id,
        lootboxes,
        speciesAssignments,
        setNextGiftAt,
      })
    }
    showToast(`${pp ? ownedPokemonName(pp) : 'Pokémon'} ${inTeam ? "ajouté à l'équipe" : 'mis au PC'} !`)
  }

  const openGift = (pp: PlayerPokemon) => {
    const lootbox = resolveLootboxForSpecies(pp.pokemon_nom, lootboxes, speciesAssignments)
    const drawn = lootbox ? drawLootboxReward(lootbox.id, lootboxItems) : null
    setGiftReward(drawn ? { itemNom: drawn.item_nom, quantity: drawn.quantity } : null)
    setGiftPokemonId(pp.id)
  }

  const handleClaimGift = async () => {
    if (giftPokemon && giftReward) {
      const source = ownedPokemonName(giftPokemon)
      if (giftReward.itemNom === POKEDOLLAR_ITEM_NAME) {
        const total = pokedollars + giftReward.quantity
        await setPokedollars(total)
        if (player) {
          void logHistoryEvent('inventory', 'item_gift', player.id, { item_nom: POKEDOLLAR_ITEM_NAME, delta: giftReward.quantity, total, source })
        }
      } else {
        const existing = playerItems.inventory.find((r) => r.item_nom === giftReward.itemNom)
        const total = (existing?.quantity ?? 0) + giftReward.quantity
        await addItems(giftReward.itemNom, giftReward.quantity)
        if (player) {
          void logHistoryEvent('inventory', 'item_gift', player.id, { item_nom: giftReward.itemNom, delta: giftReward.quantity, total, source })
        }
      }
      const lootbox = resolveLootboxForSpecies(giftPokemon.pokemon_nom, lootboxes, speciesAssignments)
      if (lootbox) await setNextGiftAt(giftPokemon.id, randomNextGiftAt(lootbox))
    }
    setGiftPokemonId(null)
    setGiftReward(null)
  }

  const handleDelete = async (id: number) => {
    const pp = roster.find((r) => r.id === id)
    await deleteOwnedPokemon(id)
    setSelectedId(null)
    showToast(`${pp ? ownedPokemonName(pp) : 'Pokémon'} supprimé.`)
  }

  return (
    <div
      ref={sceneRef}
      className="flex-1 relative overflow-hidden"
      style={homeBgStyle(parameters.accueil_image_url?.trim() || backgrounds[0]?.image_url || DEFAULT_ACCUEIL_IMAGE_URL)}
    >
      {/* Équipe en déambulation */}
      {team.map((pp, idx) => (
        <RoamingPokemonSprite
          key={pp.id}
          playerPokemon={pp}
          pokemon={pokemonByName.get(pp.pokemon_nom)}
          index={idx}
          isJumping={jumpingId === pp.id}
          hasGift={hasGift(pp)}
          containerRef={sceneRef}
          onClick={() => (hasGift(pp) ? openGift(pp) : setSelectedId(pp.id))}
        />
      ))}

      {/* États vides */}
      {!player ? (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-3">
          <p className={`text-[#14320f] text-sm bg-cream/90 px-4 py-2.5 rounded-lg ${PIXEL_BORDER_SM}`}>
            Connectez-vous pour voir votre équipe.
          </p>
          <button
            onClick={onRequestLogin}
            className={`px-4 py-2 rounded-lg text-sm font-bold ${BUTTON_STYLE.green}`}
          >
            👤 Se connecter
          </button>
        </div>
      ) : team.length === 0 ? (
        <div className="absolute inset-0 flex items-center justify-center">
          <p className={`text-[#14320f] text-sm bg-cream/90 px-4 py-2.5 rounded-lg ${PIXEL_BORDER_SM}`}>
            Aucun Pokémon dans l'équipe.
          </p>
        </div>
      ) : null}

      {/* Chat global : bouton flottant en bas à gauche, visible uniquement connecté */}
      {player && parameters.feature_chat_enabled && (
        <button
          onClick={() => { setShowChat(true); markSeen() }}
          title="Chat"
          className="absolute left-2 sm:left-3 bottom-3 z-[35] w-10 h-10 sm:w-14 sm:h-14 rounded-full border-2 sm:border-[3px] border-ink bg-gradient-to-br from-[#3ea0e0] to-[#0f4a7a] flex items-center justify-center shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
        >
          <span className="text-xl sm:text-2xl">💬</span>
          {unreadCount > 0 && (
            <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] px-1 rounded-full bg-hp-red border-2 border-ink text-white text-[10px] font-bold flex items-center justify-center">
              {unreadCount > 9 ? '9+' : unreadCount}
            </span>
          )}
        </button>
      )}

      {/* Widgets épinglés à droite : plus petits sur mobile (~70%), en grille de
          6 lignes max par colonne sur PC (colonne suivante au-delà) */}
      <div className="absolute right-2 sm:right-3 top-1/2 -translate-y-1/2 z-[35] flex flex-col sm:grid sm:grid-flow-col sm:grid-rows-6 items-center gap-2 sm:gap-3">
        {player && parameters.feature_minijeux_enabled && hasAnyMinigameAvailable(minigamesConfig, roster) && (
          <button
            onClick={() => setShowMiniGames(true)}
            title="Mini-Jeux"
            className="w-10 h-10 sm:w-14 sm:h-14 rounded-full border-2 sm:border-[3px] border-ink bg-gradient-to-br from-[#2f8fd6] to-[#0f3f7a] flex items-center justify-center shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
          >
            <img src={MINIGAMES_ICON} alt="Mini-Jeux" className="pixelated w-6 h-6 sm:w-9 sm:h-9 object-contain" />
          </button>
        )}

        {player && (casinoConfig.slots_enabled || casinoConfig.dice_enabled) && (
          <button
            onClick={() => setShowCasino(true)}
            title="Casino"
            className="w-10 h-10 sm:w-14 sm:h-14 rounded-full border-2 sm:border-[3px] border-ink bg-gradient-to-br from-[#e0293f] to-[#7a0f1f] flex items-center justify-center shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
          >
            <img src={CASINO_MASCOT_ICON} alt="Casino" className="pixelated w-6 h-6 sm:w-9 sm:h-9 object-contain" />
          </button>
        )}

        {player && parameters.feature_mining_enabled && (
          <button
            onClick={() => setShowMining(true)}
            title="Fouille"
            className="w-10 h-10 sm:w-14 sm:h-14 rounded-full border-2 sm:border-[3px] border-ink bg-gradient-to-br from-[#c98a3e] to-[#6b4a1f] flex items-center justify-center shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
          >
            <img src={MINING_ICON} alt="Fouille" className="pixelated w-6 h-6 sm:w-9 sm:h-9 object-contain" />
          </button>
        )}

        {player && parameters.feature_pension_enabled && (
          <button
            onClick={() => setShowPension(true)}
            title="Pension Pokémon"
            className="w-10 h-10 sm:w-14 sm:h-14 rounded-full border-2 sm:border-[3px] border-ink bg-gradient-to-br from-[#7ec98f] to-[#2f6b3f] flex items-center justify-center shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
          >
            <img src={PENSION_ICON} alt="Pension Pokémon" className="pixelated w-6 h-6 sm:w-9 sm:h-9 object-contain" />
          </button>
        )}

        {player && parameters.feature_safari_enabled && (
          <button
            onClick={() => setShowSafari(true)}
            title="Safari"
            className="w-10 h-10 sm:w-14 sm:h-14 rounded-full border-2 sm:border-[3px] border-ink bg-gradient-to-br from-[#e0a83e] to-[#8a5a1f] flex items-center justify-center shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
          >
            <img src={SAFARI_ICON} alt="Safari" className="pixelated w-6 h-6 sm:w-9 sm:h-9 object-contain" />
          </button>
        )}

        {player && parameters.feature_autobattle_enabled && (
          <button
            onClick={() => setShowAutoBattle(true)}
            title="Combat Auto"
            className="w-10 h-10 sm:w-14 sm:h-14 rounded-full border-2 sm:border-[3px] border-ink bg-gradient-to-br from-[#8a3ee0] to-[#3f0f7a] flex items-center justify-center shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
          >
            <img src={AUTOBATTLE_ICON} alt="Combat Auto" className="pixelated w-6 h-6 sm:w-9 sm:h-9 object-contain" />
          </button>
        )}

        {canScan && (
          <button
            onClick={onScan}
            title="Scanner un Pokémon"
            className="w-10 h-10 sm:w-14 sm:h-14 rounded-full border-2 sm:border-[3px] border-ink bg-gradient-to-br from-hp-orange to-hp-red text-white flex items-center justify-center shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
          >
            <PixelIcon src={PHOTO_ICON} size={24} alt="Scanner un Pokémon" colored className="sm:!w-[34px] sm:!h-[34px]" />
          </button>
        )}
      </div>

      {selected && (
        <PokemonDetailSheet
          context="home"
          elevated={selectedElevated}
          pokemon={pokemonByName.get(selected.pokemon_nom)}
          playerPokemon={selected}
          attacksByName={attacksByName}
          isAdmin={isAdmin}
          teamFull={teamFull}
          isNpc={player?.is_npc ?? false}
          maxMoves={parameters.max_moves}
          onUpdateXp={updateXp}
          onRename={updateNickname}
          onToggleInTeam={handleToggleInTeam}
          onAddMove={addMove}
          onRemoveMove={removeMove}
          onDelete={handleDelete}
          onSetNextGiftAt={setNextGiftAt}
          pokemonByName={pokemonByName}
          itemsByName={itemsByName}
          evolutionsByPokemonNom={evolutionsByPokemonNom}
          playerItems={playerItems}
          onEvolve={evolvePokemon}
          onClose={() => { setSelectedId(null); setSelectedElevated(false) }}
        />
      )}

      {giftPokemon && (
        <GiftPopup
          pokemonDisplayName={ownedPokemonName(giftPokemon)}
          reward={giftReward}
          itemsByName={itemsByName}
          pokedollarImageUrl={itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url}
          onConfirm={handleClaimGift}
        />
      )}

      {showCasino && player && (
        <CasinoPopup
          player={player}
          playerItems={playerItems}
          pokedollarImageUrl={itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url}
          onClose={() => setShowCasino(false)}
        />
      )}

      {showMiniGames && player && (
        <MiniGamesPopup
          player={player}
          playerItems={playerItems}
          roster={roster}
          updateXp={updateXp}
          pokemonByName={pokemonByName}
          evolutionsByPokemonNom={evolutionsByPokemonNom}
          itemsByName={itemsByName}
          pokedollarImageUrl={itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url}
          onRequestPokemonDetail={(id) => { setShowMiniGames(false); setSelectedElevated(false); setSelectedId(id) }}
          onClose={() => setShowMiniGames(false)}
        />
      )}

      {showMining && player && (
        <MiningPopup
          player={player}
          playerItems={playerItems}
          itemsByName={itemsByName}
          pokedollarImageUrl={itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url}
          onClose={() => setShowMining(false)}
        />
      )}

      {showPension && player && (
        <PensionPopup
          player={player}
          roster={roster}
          pokemonByName={pokemonByName}
          itemsByName={itemsByName}
          evolutionsByPokemonNom={evolutionsByPokemonNom}
          onRequestPokemonDetail={(id) => { setShowPension(false); setSelectedElevated(false); setSelectedId(id) }}
          onMarkEggSeen={markEggRevealSeen}
          onClose={() => setShowPension(false)}
        />
      )}

      {showSafari && player && (
        <SafariPopup
          player={player}
          playerItems={playerItems}
          itemsByName={itemsByName}
          pokedollarImageUrl={itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url}
          onRequestPokemonDetail={(id) => { setSelectedElevated(true); setSelectedId(id) }}
          onClose={() => setShowSafari(false)}
        />
      )}

      {showAutoBattle && player && (
        <AutoBattlePopup
          player={player}
          playerItems={playerItems}
          roster={roster}
          pokemonByName={pokemonByName}
          attacksByName={attacksByName}
          itemsByName={itemsByName}
          evolutionsByPokemonNom={evolutionsByPokemonNom}
          pokedollarImageUrl={itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url}
          onRequestPokemonDetail={(id) => { setShowAutoBattle(false); setSelectedElevated(false); setSelectedId(id) }}
          onClose={() => setShowAutoBattle(false)}
        />
      )}

      {showChat && player && (
        <ChatPopup
          player={player}
          players={players}
          chat={chat}
          pokemonByName={pokemonByName}
          discoveredPokemon={discoveredPokemon}
          attacksByName={attacksByName}
          itemsByName={itemsByName}
          maxMessageLength={parameters.chat_max_message_length}
          spamLimitPerMinute={parameters.chat_spam_limit_per_minute}
          onClose={() => setShowChat(false)}
        />
      )}
    </div>
  )
}
