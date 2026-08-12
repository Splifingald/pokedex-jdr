import { useState, useEffect, useRef, useMemo } from 'react'
import type { Player, PlayerPokemon, Pokemon, Attack, PokemonEvolution, Item, AutoBattleVariant, AutoBattleLevel, AutoBattleResolveResult, AutoBattleManualRoundResult, AutoBattleStartManualBattleResult, AutoBattleAbilityRule } from '../types'
import { TICKET_AUTOBATTLE_ITEM_NAME, POKEDOLLAR_ITEM_NAME, ownedPokemonName } from '../types'
import { supabase } from '../lib/supabase'
import { usePlayerItems } from '../hooks/usePlayerItems'
import { useAutoBattleConfig } from '../hooks/useAutoBattleConfig'
import { useAutoBattlePlayerState } from '../hooks/useAutoBattlePlayerState'
import { useAutoBattleVariants } from '../hooks/useAutoBattleVariants'
import { useAutoBattleProgress } from '../hooks/useAutoBattleProgress'
import { useAutoBattleBannedAttacks } from '../hooks/useAutoBattleBannedAttacks'
import { useAutoBattleAbilityRules } from '../hooks/useAutoBattleAbilityRules'
import { isPurchaseCapReached, localDateString, formatCountdown } from '../lib/casino'
import { generateIdempotencyKey } from '../lib/autoBattle'
import { getHpBreakdown } from '../lib/xpBonuses'
import { getEvolutionOptions } from '../lib/evolution'
import { useToast } from '../context/ToastContext'
import { GameBanner } from './CasinoGameCard'
import { AutoBattleVariantBanner } from './autoBattle/AutoBattleVariantBanner'
import { AutoBattlePokemonPicker } from './autoBattle/AutoBattlePokemonPicker'
import { AutoBattleAbilityPicker } from './autoBattle/AutoBattleAbilityPicker'
import { AutoBattleCoinToss } from './autoBattle/AutoBattleCoinToss'
import { AutoBattleScreen } from './autoBattle/AutoBattleScreen'
import { ManualBattleScreen } from './autoBattle/ManualBattleScreen'
import { AutoBattleRewardPopup } from './autoBattle/AutoBattleRewardPopup'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { AUTOBATTLE_ICON, AUTOBATTLE_TICKET_ICON } from '../lib/icons'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { PokedollarIcon } from './PokedollarIcon'
import { logHistoryEvent } from '../lib/historyLog'

type View = 'list' | 'pick-pokemon' | 'pick-ability' | 'coin-toss' | 'battle' | 'manual-coin-toss' | 'manual-battle' | 'reward' | 'lose'

// Messages affichés au joueur pour chaque statut non-'ok' renvoyé par le RPC
// autobattle_resolve_battle (voir supabase/schema.sql) — évite qu'un rejet
// serveur reste invisible ("rien ne se passe" côté joueur).
const STATUS_MESSAGE: Record<string, string> = {
  no_ticket: 'Aucun ticket disponible.',
  wrong_level: 'Ce niveau a déjà été mis à jour, réessayez.',
  ineligible_pokemon: 'Ce pokémon ne peut pas combattre (en pension ?).',
  ineligible_ability: "Cette capacité n'est plus disponible.",
  variant_disabled: 'Ce parcours est désactivé.',
  variant_completed: 'Ce parcours est déjà terminé.',
  invalid_level: 'Niveau mal configuré, contactez un admin.',
  duplicate_request: 'Combat déjà résolu.',
  not_found: 'Niveau introuvable.',
  wrong_mode: 'Ce parcours a changé de mode de jeu, réessayez.',
  not_started: 'Combat non initialisé, réessayez.',
}

interface Props {
  player: Player
  playerItems: ReturnType<typeof usePlayerItems>
  roster: PlayerPokemon[]
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  evolutionsByPokemonNom: Map<string, PokemonEvolution[]>
  pokedollarImageUrl?: string | null
  onRequestPokemonDetail: (id: number) => void
  onClose: () => void
  isAdmin?: boolean
}

export function AutoBattlePopup({
  player, playerItems, roster, pokemonByName, attacksByName, itemsByName, evolutionsByPokemonNom,
  pokedollarImageUrl, onRequestPokemonDetail, onClose, isAdmin,
}: Props) {
  const { config } = useAutoBattleConfig()
  const { state, updateState } = useAutoBattlePlayerState(player.id)
  const { variants, levelsByVariant, rewardsByLevel, loading: variantsLoading } = useAutoBattleVariants()
  const { progressByVariant, stateByLevel } = useAutoBattleProgress(player.id)
  const { bannedNames } = useAutoBattleBannedAttacks()
  const { rules: abilityRules } = useAutoBattleAbilityRules()
  const { showToast } = useToast()

  const abilityRulesByName = useMemo(() => {
    const map = new Map<string, AutoBattleAbilityRule>()
    for (const r of abilityRules) map.set(r.attack_nom, r)
    return map
  }, [abilityRules])

  const [view, setView] = useState<View>('list')
  // Bannière du combat (GameBanner, voir plus bas) : reste toujours visible en
  // haut (hors de la zone défilante), mais se réduit progressivement jusqu'à
  // la moitié de sa hauteur de base pendant qu'on scrolle dans le contenu en
  // dessous, pour laisser plus de place à ce contenu. bannerFullHeight suit
  // la largeur réelle du conteneur (ResizeObserver, jamais sa propre hauteur —
  // qu'on modifie nous-mêmes ci-dessous — pour ne pas créer de boucle) et en
  // déduit la hauteur "pleine" via le même ratio 10/3 que l'ancien aspect-
  // [10/3] qu'elle remplace. scrollShrink (0 → 1) vient du scrollTop de la
  // zone défilante, remis à 0 à chaque changement de vue.
  const bannerWrapRef = useRef<HTMLDivElement>(null)
  const scrollContainerRef = useRef<HTMLDivElement>(null)
  const [bannerFullHeight, setBannerFullHeight] = useState<number | null>(null)
  const [scrollShrink, setScrollShrink] = useState(0)
  const BANNER_SHRINK_SCROLL_PX = 100

  // Ajuste l'état pendant le rendu plutôt que dans un effet (pattern
  // recommandé par React pour "réinitialiser un état quand une prop change",
  // voir react.dev/learn/you-might-not-need-an-effect) — scrollContainerRef a
  // aussi `key={view}` plus bas, qui démonte/remonte le conteneur défilant à
  // chaque changement de vue et remet donc son scrollTop à 0 nativement, sans
  // avoir besoin d'une manipulation DOM impérative ici.
  const [prevView, setPrevView] = useState(view)
  if (view !== prevView) {
    setPrevView(view)
    setScrollShrink(0)
  }

  useEffect(() => {
    if (view !== 'battle' && view !== 'manual-battle') return
    const el = bannerWrapRef.current
    if (!el) return
    const ro = new ResizeObserver((entries) => {
      const width = entries[0]?.contentRect.width
      if (width) setBannerFullHeight(width * 3 / 10)
    })
    ro.observe(el)
    return () => ro.disconnect()
  }, [view])

  const handleScrollContainerScroll = (e: React.UIEvent<HTMLDivElement>) => {
    const t = e.currentTarget.scrollTop
    setScrollShrink(Math.max(0, Math.min(1, t / BANNER_SHRINK_SCROLL_PX)))
  }

  const [now, setNow] = useState(() => Date.now())
  const [activeVariant, setActiveVariant] = useState<AutoBattleVariant | null>(null)
  const [activeLevel, setActiveLevel] = useState<AutoBattleLevel | null>(null)
  const [selectedPokemon, setSelectedPokemon] = useState<PlayerPokemon | null>(null)
  const [selectedAbilityNom, setSelectedAbilityNom] = useState('')
  const [battleResult, setBattleResult] = useState<AutoBattleResolveResult | null>(null)
  const [evolutionEligible, setEvolutionEligible] = useState(false)
  const [showEvolvePrompt, setShowEvolvePrompt] = useState(false)
  // Verrou synchrone (ref, pas de state — pas de délai de rendu) contre un
  // double-appel de handleSelectAbility (double-tap, réseau lent laissant le
  // temps d'un second tap avant le changement de vue) : sans lui, deux
  // combats étaient réellement résolus côté serveur (2 tickets débités, 2
  // RPC exécutées) alors qu'un seul restait visible à l'écran (le second
  // résultat écrasant le premier), rendant le bug quasi invisible.
  const submittingRef = useRef(false)
  // Combat Manuel : verrou contre un double-appel de handleStartManualBattle
  // (double-tap sur le picker, réseau lent) — sans lui, un tirage au sort
  // demandé une seule fois par le joueur pouvait débiter deux tickets (voir
  // handleStartManualBattle).
  const startingRef = useRef(false)
  // Combat Manuel : qui attaque en premier, tiré au sort par
  // autobattle_start_manual_battle dès le choix du pokémon (voir
  // handleStartManualBattle) — révélé via AutoBattleCoinToss (view
  // 'manual-coin-toss') puis transmis à ManualBattleScreen pour le badge
  // "(1er)"/"(2ème)" sur l'invite de sélection de capacité.
  const [manualFirstAttacker, setManualFirstAttacker] = useState<'player' | 'opponent' | null>(null)

  const ticketRow = playerItems.inventory.find((r) => r.item_nom === TICKET_AUTOBATTLE_ITEM_NAME)
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
      source: "l'achat de tickets Combat Auto",
    })
    await playerItems.addItems(TICKET_AUTOBATTLE_ITEM_NAME, 1)
    void logHistoryEvent('inventory', 'item_add', player.id, {
      item_nom: TICKET_AUTOBATTLE_ITEM_NAME,
      delta: 1,
      total: ticketCount + 1,
      source: "l'achat de tickets Combat Auto",
    })
    const sameDay = state.purchase_date === today
    await updateState({ purchase_count: sameDay ? state.purchase_count + 1 : 1, purchase_date: today })
  }

  const handlePlayVariant = (variant: AutoBattleVariant) => {
    const levels = levelsByVariant.get(variant.id) ?? []
    const progress = progressByVariant.get(variant.id)
    if (progress?.variant_completed) return
    const currentIndex = progress?.current_level_index ?? 0
    const level = levels.find((l) => l.level_index === currentIndex)
    if (!level) return
    setActiveVariant(variant)
    setActiveLevel(level)
    setSelectedPokemon(null)
    setBattleResult(null)
    setEvolutionEligible(false)
    setShowEvolvePrompt(false)
    setManualFirstAttacker(null)
    startingRef.current = false
    setView('pick-pokemon')
  }

  // Combat Manuel : appelée quand le joueur choisit son pokémon — crée le
  // combat côté serveur et tire au sort qui attaque en premier (voir
  // autobattle_start_manual_battle) AVANT même la grille de sélection de
  // capacité, pour pouvoir jouer le tirage au sort (AutoBattleCoinToss, voir
  // view 'manual-coin-toss') dès ce moment-là, comme en Combat Auto. Le
  // ticket est débité ICI, au moment où le tirage au sort est lancé — voir
  // requirement : reculer AVANT ce point (pendant le choix du pokémon) ne
  // coûte rien, mais une fois le tirage lancé c'est définitif, même si le
  // joueur recule ensuite sans jouer un seul tour (autobattle_resolve_
  // manual_round ne touche plus du tout aux tickets). startingRef (voir plus
  // haut) évite un double-appel (double-tap sur le picker, réseau lent) qui
  // débiterait deux tickets pour un seul tirage au sort demandé.
  const handleStartManualBattle = async (pp: PlayerPokemon) => {
    if (!activeLevel || startingRef.current) return
    if (ticketCount < 1 || !ticketRow) {
      showToast('Aucun ticket disponible.')
      return
    }
    startingRef.current = true
    setSelectedPokemon(pp)

    let result: AutoBattleStartManualBattleResult | null = null
    let rpcError: unknown
    try {
      const idempotencyKey = generateIdempotencyKey()
      const { data, error } = await supabase.rpc('autobattle_start_manual_battle', {
        p_player_id: player.id,
        p_level_id: activeLevel.id,
        p_player_pokemon_id: pp.id,
        p_idempotency_key: idempotencyKey,
      })
      result = (data ?? null) as AutoBattleStartManualBattleResult | null
      rpcError = error
    } catch (err) {
      rpcError = err
    }

    if (rpcError || !result || result.status !== 'ok' || !result.first_attacker) {
      if (rpcError) console.error('Erreur lors du démarrage du combat Combat Manuel :', rpcError)
      startingRef.current = false
      showToast(STATUS_MESSAGE[result?.status ?? ''] ?? 'Combat impossible pour le moment.')
      return
    }

    const spentTotal = ticketRow.quantity - 1
    void playerItems.setQuantity(ticketRow, spentTotal)
    void logHistoryEvent('inventory', 'item_autobattle_spend', player.id, {
      item_nom: TICKET_AUTOBATTLE_ITEM_NAME,
      delta: 1,
      total: spentTotal,
      source: activeVariant?.nom ?? config.nom,
    })

    setManualFirstAttacker(result.first_attacker)
    setView('manual-coin-toss')
  }

  // Combat Manuel : appelée par ManualBattleScreen à chaque capacité choisie
  // par le joueur (un tour = un appel RPC, voir autobattle_resolve_manual_
  // round — le ticket a déjà été débité par handleStartManualBattle ci-
  // dessus). Retourne null en cas d'erreur réseau/RPC — ManualBattleScreen
  // se contente alors de redonner la main sans planter, le toast suffit.
  const handleSubmitManualRound = async (pp: PlayerPokemon, ability: Attack): Promise<AutoBattleManualRoundResult | null> => {
    if (!activeLevel) return null

    let result: AutoBattleManualRoundResult | null = null
    let rpcError: unknown
    try {
      const idempotencyKey = generateIdempotencyKey()
      const { data, error } = await supabase.rpc('autobattle_resolve_manual_round', {
        p_player_id: player.id,
        p_level_id: activeLevel.id,
        p_player_pokemon_id: pp.id,
        p_ability_nom: ability.nom,
        p_idempotency_key: idempotencyKey,
      })
      result = (data ?? null) as AutoBattleManualRoundResult | null
      rpcError = error
    } catch (err) {
      rpcError = err
    }

    if (rpcError || !result || result.status !== 'ok') {
      if (rpcError) console.error('Erreur lors de la résolution du tour Combat Manuel :', rpcError)
      showToast(STATUS_MESSAGE[result?.status ?? ''] ?? 'Combat impossible pour le moment.')
      return null
    }

    if (result.outcome === 'win') {
      void playerItems.refetch()
    }
    return result
  }

  const handleManualBattleFinished = (result: AutoBattleManualRoundResult) => {
    setBattleResult(result as AutoBattleResolveResult)
    handleBattleFinished(result)
  }

  const handleSelectAbility = async (pp: PlayerPokemon, ability: Attack) => {
    if (!activeLevel) return
    if (submittingRef.current) return
    if (ticketCount < 1 || !ticketRow) {
      showToast('Aucun ticket disponible.')
      return
    }
    submittingRef.current = true
    setSelectedAbilityNom(ability.nom)

    const spentTotal = ticketRow.quantity - 1
    await playerItems.setQuantity(ticketRow, spentTotal)
    void logHistoryEvent('inventory', 'item_autobattle_spend', player.id, {
      item_nom: TICKET_AUTOBATTLE_ITEM_NAME,
      delta: 1,
      total: spentTotal,
      source: activeVariant?.nom ?? config.nom,
    })

    let result: AutoBattleResolveResult | null = null
    let rpcError: unknown
    try {
      const idempotencyKey = generateIdempotencyKey()
      const { data, error } = await supabase.rpc('autobattle_resolve_battle', {
        p_player_id: player.id,
        p_level_id: activeLevel.id,
        p_player_pokemon_id: pp.id,
        p_ability_nom: ability.nom,
        p_idempotency_key: idempotencyKey,
      })
      result = (data ?? null) as AutoBattleResolveResult | null
      rpcError = error
    } catch (err) {
      rpcError = err
    }

    if (rpcError || !result || result.status !== 'ok') {
      if (rpcError) console.error('Erreur lors de la résolution du combat Combat Auto :', rpcError)
      await playerItems.addItems(TICKET_AUTOBATTLE_ITEM_NAME, 1)
      void logHistoryEvent('inventory', 'item_add', player.id, {
        item_nom: TICKET_AUTOBATTLE_ITEM_NAME,
        delta: 1,
        total: spentTotal + 1,
        source: 'combat refusé',
      })
      showToast(STATUS_MESSAGE[result?.status ?? ''] ?? 'Combat impossible pour le moment.')
      setView('list')
      submittingRef.current = false
      return
    }

    // Les récompenses (objets/badges) sont créditées côté serveur par le RPC,
    // pas via les setInventory optimistes habituels de usePlayerItems — on
    // force un refetch dès maintenant (pendant l'animation coin-toss/combat)
    // plutôt que de compter sur le Realtime pour que le Sac les reflète sans
    // attendre un rechargement de l'app (même raison que MiningPopup).
    if (result.outcome === 'win') {
      void playerItems.refetch()
    }

    setBattleResult(result)
    setView('coin-toss')
    submittingRef.current = false
  }

  // Accepte un résultat explicite (mode Manuel : ManualBattleScreen appelle
  // ceci dès la fin d'animation du tour final, avant même que setBattleResult
  // n'ait eu le temps de re-rendre — lire l'état battleResult ici serait donc
  // stale) ; par défaut lit l'état (mode Auto : le bouton "Continuer" de
  // AutoBattleScreen n'a pas de résultat à passer, battleResult est déjà à
  // jour depuis handleSelectAbility).
  const handleBattleFinished = (result: AutoBattleResolveResult | AutoBattleManualRoundResult | null = battleResult) => {
    if (!result || !activeVariant || !activeLevel || !selectedPokemon) return
    const opponentSpecies = pokemonByName.get(result.opponent_pokemon_nom ?? '')

    if (result.outcome === 'win') {
      void logHistoryEvent('autobattle', 'autobattle_win', player.id, {
        variant_nom: activeVariant.nom,
        pokemon_nom: selectedPokemon.pokemon_nom,
        player_pokemon_id: selectedPokemon.id,
        nickname: selectedPokemon.nickname,
        level_index: activeLevel.level_index,
        opponent_pokemon_nom: result.opponent_pokemon_nom ?? '',
      })
      if (result.variant_completed) {
        void logHistoryEvent('autobattle', 'autobattle_variant_completed', player.id, {
          variant_nom: activeVariant.nom,
          pokemon_nom: selectedPokemon.pokemon_nom,
          player_pokemon_id: selectedPokemon.id,
          nickname: selectedPokemon.nickname,
          level_index: activeLevel.level_index,
          opponent_pokemon_nom: result.opponent_pokemon_nom ?? '',
          variant_completed: true,
        })
      }

      const xpReward = (result.rewards ?? []).find((r) => r.reward_type === 'xp')
      const finalXp = xpReward?.xp_after ?? selectedPokemon.xp
      const options = getEvolutionOptions(
        { ...selectedPokemon, xp: finalXp },
        pokemonByName.get(selectedPokemon.pokemon_nom),
        evolutionsByPokemonNom,
        pokemonByName,
        itemsByName,
        playerItems.inventory
      )
      if (options.length > 0) setEvolutionEligible(true)
      setView('reward')
    } else {
      void logHistoryEvent('autobattle', 'autobattle_lose', player.id, {
        variant_nom: activeVariant.nom,
        pokemon_nom: selectedPokemon.pokemon_nom,
        player_pokemon_id: selectedPokemon.id,
        nickname: selectedPokemon.nickname,
        level_index: activeLevel.level_index,
        opponent_pokemon_nom: opponentSpecies?.nom ?? result.opponent_pokemon_nom ?? '',
      })
      setView('lose')
    }
  }

  const resetToList = () => {
    setActiveVariant(null)
    setActiveLevel(null)
    setSelectedPokemon(null)
    setBattleResult(null)
    setEvolutionEligible(false)
    setShowEvolvePrompt(false)
    setView('list')
  }

  // Combat Manuel : bouton "Déclarer égalité" (voir ManualBattleScreen,
  // STALEMATE_ROUNDS_THRESHOLD) — crédite 1 ticket (le combat en a déjà
  // coûté 1 au tirage au sort, voir handleStartManualBattle) et ramène à la
  // sélection du parcours. Le combat en cours sur le serveur (autobattle_
  // manual_battles) reste tel quel : une prochaine tentative sur ce niveau
  // le purgera et en redémarrera un neuf, comme pour tout abandon en cours.
  const handleDeclareTie = async () => {
    const spentTotal = ticketCount + 1
    await playerItems.addItems(TICKET_AUTOBATTLE_ITEM_NAME, 1)
    void logHistoryEvent('inventory', 'item_add', player.id, {
      item_nom: TICKET_AUTOBATTLE_ITEM_NAME,
      delta: 1,
      total: spentTotal,
      source: 'Égalité déclarée en Combat Manuel',
    })
    resetToList()
  }

  const handleRewardConfirm = () => {
    if (evolutionEligible && !showEvolvePrompt) {
      setShowEvolvePrompt(true)
      return
    }
    resetToList()
  }

  const today = localDateString()
  const buyDisabled = !state || playerItems.pokedollars < config.ticket_buy_cost || isPurchaseCapReached(state, config, today)
  const purchasesLeft = state
    ? Math.max(0, config.ticket_daily_buy_cap - (state.purchase_date === today ? state.purchase_count : 0))
    : config.ticket_daily_buy_cap
  const countdownMs = state?.next_ticket_at ? new Date(state.next_ticket_at).getTime() - now : null

  const activeSpecies = selectedPokemon ? pokemonByName.get(selectedPokemon.pokemon_nom) : undefined
  const opponentSpecies = battleResult ? pokemonByName.get(battleResult.opponent_pokemon_nom ?? '') : undefined
  // Espèce adverse du NIVEAU (pas du résultat de combat, pas encore résolu
  // avant le 1er appel RPC) — sert au badge Super Efficace par capacité dans
  // AutoBattleAbilityPicker, affiché AVANT que le combat ne soit lancé.
  const activeLevelOpponentSpecies = activeLevel ? pokemonByName.get(activeLevel.opponent_pokemon_nom) : undefined

  // Variantes déjà terminées reléguées en bas de liste (ordre stable sinon).
  const sortedEnabledVariants = [...variants.filter((v) => v.enabled)].sort((a, b) => {
    const aDone = progressByVariant.get(a.id)?.variant_completed ?? false
    const bDone = progressByVariant.get(b.id)?.variant_completed ?? false
    return Number(aDone) - Number(bDone)
  })

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-0 sm:p-4"
      onClick={(e) => { if (e.target === e.currentTarget && view === 'list') onClose() }}
    >
      <div
        className="relative bg-cream w-full h-full overflow-hidden flex flex-col
          sm:h-auto sm:max-w-md sm:max-h-[85vh] sm:rounded-[var(--radius-pixel)] sm:border-[3px] sm:border-ink sm:shadow-[var(--shadow-pixel-lg)]"
      >
        {view !== 'coin-toss' && view !== 'battle' && view !== 'manual-coin-toss' && view !== 'manual-battle' && (
          <button
            onClick={onClose}
            className="absolute right-3 top-3 z-20 w-8 h-8 rounded-full border-2 border-ink bg-cream shadow-[var(--shadow-pixel)] flex items-center justify-center text-ink hover:bg-black/10 active:shadow-none active:translate-x-[1px] active:translate-y-[1px] transition-all"
          >
            <CloseIcon className="w-4 h-4" />
          </button>
        )}

        {(view === 'battle' || view === 'manual-battle') && activeLevel && (
          <div
            ref={bannerWrapRef}
            className="w-full shrink-0 overflow-hidden"
            style={{
              height: bannerFullHeight != null ? bannerFullHeight * (1 - scrollShrink * 0.5) : undefined,
              transition: 'height 120ms ease-out',
            }}
          >
            <GameBanner bannerUrl={activeVariant?.banner_url ?? ''} fallbackEmoji="⚔️" className="w-full h-full" />
          </div>
        )}

        <div key={view} ref={scrollContainerRef} onScroll={handleScrollContainerScroll} className="flex-1 overflow-y-auto p-4 sm:p-5">
          {view === 'list' && (
            <>
              <div className="flex items-center gap-2 mb-4">
                <PixelIcon src={AUTOBATTLE_ICON} size={28} colored className="text-ink" />
                <h3 className="text-ink text-lg font-bold">{config.nom}</h3>
              </div>

              <div className={`flex items-center gap-3 p-3 rounded mb-4 ${PIXEL_BORDER_SM} bg-cream-secondary`}>
                <img src={AUTOBATTLE_TICKET_ICON} alt="" className="w-9 h-9 object-contain pixelated" />
                <div className="flex-1">
                  <p className="text-ink text-sm font-bold">{ticketCount} / {config.ticket_max} tickets</p>
                  <p className="text-ink-muted-2 text-xs">
                    {ticketCount >= config.ticket_max || countdownMs === null
                      ? 'Plafond atteint'
                      : `Prochain ticket dans ${formatCountdown(countdownMs)}`}
                  </p>
                </div>
                {config.ticket_buy_cost > 0 && (
                  <button
                    onClick={handleBuyTicket}
                    disabled={buyDisabled}
                    title={`${purchasesLeft} achat(s) restant(s) aujourd'hui`}
                    className={`px-3 py-2 rounded text-xs font-bold shrink-0 disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.green}`}
                  >
                    Acheter <PokedollarIcon imageUrl={pokedollarImageUrl} size={16} className="align-[-3px]" />{config.ticket_buy_cost}
                  </button>
                )}
              </div>

              <div className="flex flex-col gap-4">
                {variantsLoading ? (
                  <p className="text-ink-muted-2 text-sm">Chargement…</p>
                ) : sortedEnabledVariants.length === 0 ? (
                  <p className="text-ink-muted-2 text-sm text-center py-4">Aucun parcours disponible pour le moment.</p>
                ) : (
                  sortedEnabledVariants.map((variant) => {
                    const levels = levelsByVariant.get(variant.id) ?? []
                    const progress = progressByVariant.get(variant.id)
                    const completed = progress?.variant_completed ?? false
                    return (
                      <div key={variant.id} className={`p-3 rounded ${PIXEL_BORDER_SM} bg-cream-secondary flex flex-col gap-1`}>
                        <AutoBattleVariantBanner
                          variant={variant}
                          levels={levels}
                          rewardsByLevel={rewardsByLevel}
                          progress={progress}
                          stateByLevel={stateByLevel}
                          pokemonByName={pokemonByName}
                          itemsByName={itemsByName}
                          pokedollarImageUrl={pokedollarImageUrl}
                        />
                        <div className="flex items-center gap-2">
                          <div className="w-8 h-8 shrink-0 flex items-center justify-center">
                            {variant.icon_url ? (
                              <img src={variant.icon_url} alt="" className="w-full h-full object-contain" />
                            ) : (
                              <span className="text-xl">⚔️</span>
                            )}
                          </div>
                          <div className="flex-1 min-w-0 flex items-center gap-1.5">
                            <span className="block text-ink text-sm font-bold truncate">{variant.nom}</span>
                            {completed && <span className="text-sm shrink-0">✅</span>}
                          </div>
                          {!completed && (
                            <button
                              onClick={() => handlePlayVariant(variant)}
                              disabled={ticketCount < 1 || levels.length === 0}
                              className={`flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-bold shrink-0 disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.yellow}`}
                            >
                              <img src={AUTOBATTLE_TICKET_ICON} alt="" className="w-4 h-4 object-contain pixelated" />
                              Jouer
                            </button>
                          )}
                        </div>
                      </div>
                    )
                  })
                )}
              </div>
            </>
          )}

          {view === 'pick-pokemon' && (
            <AutoBattlePokemonPicker
              roster={roster}
              pokemonByName={pokemonByName}
              attacksByName={attacksByName}
              bannedAttacks={bannedNames}
              opponentSpecies={activeLevel ? pokemonByName.get(activeLevel.opponent_pokemon_nom) : undefined}
              opponentDiscovered={activeLevel ? (stateByLevel.get(activeLevel.id)?.discovered ?? false) : false}
              onSelect={(pp) => {
                if (activeVariant?.game_mode === 'manual') {
                  void handleStartManualBattle(pp)
                } else {
                  setSelectedPokemon(pp)
                  setView('pick-ability')
                }
              }}
              onBack={resetToList}
            />
          )}

          {view === 'manual-coin-toss' && manualFirstAttacker && (
            <AutoBattleCoinToss
              player={player}
              firstAttacker={manualFirstAttacker}
              onDone={() => setView('manual-battle')}
            />
          )}

          {view === 'manual-battle' && activeLevel && selectedPokemon && manualFirstAttacker && (
            <ManualBattleScreen
              firstAttacker={manualFirstAttacker}
              playerPokemon={selectedPokemon}
              playerSpecies={activeSpecies}
              playerMaxHp={Math.max(1, getHpBreakdown(activeSpecies, selectedPokemon.xp).total)}
              opponentSpecies={pokemonByName.get(activeLevel.opponent_pokemon_nom)}
              opponentNom={activeLevel.opponent_pokemon_nom}
              opponentMaxHp={activeLevel.opponent_hp}
              opponentAbilityPool={[
                activeLevel.opponent_ability_nom, activeLevel.opponent_ability_nom_2, activeLevel.opponent_ability_nom_3,
                activeLevel.opponent_ability_nom_4, activeLevel.opponent_ability_nom_5, activeLevel.opponent_ability_nom_6,
                activeLevel.opponent_ability_nom_7, activeLevel.opponent_ability_nom_8, activeLevel.opponent_ability_nom_9,
                activeLevel.opponent_ability_nom_10,
              ].filter((n): n is string => !!n)}
              attacksByName={attacksByName}
              abilityRulesByName={abilityRulesByName}
              bannedAttacks={bannedNames}
              precisionEnabled={config.precision_enabled}
              isAdmin={isAdmin}
              onSubmitRound={(ability) => handleSubmitManualRound(selectedPokemon, ability)}
              onFinished={handleManualBattleFinished}
              onDeclareTie={() => void handleDeclareTie()}
            />
          )}

          {view === 'pick-ability' && selectedPokemon && (
            <AutoBattleAbilityPicker
              playerPokemon={selectedPokemon}
              playerSpecies={activeSpecies}
              opponentSpecies={activeLevelOpponentSpecies}
              attacksByName={attacksByName}
              abilityRulesByName={abilityRulesByName}
              bannedAttacks={bannedNames}
              precisionEnabled={config.precision_enabled}
              onSelect={(ability) => void handleSelectAbility(selectedPokemon, ability)}
              onBack={() => setView('pick-pokemon')}
            />
          )}

          {view === 'coin-toss' && battleResult?.coin_toss_first && (
            <AutoBattleCoinToss
              player={player}
              firstAttacker={battleResult.coin_toss_first}
              onDone={() => setView('battle')}
            />
          )}

          {view === 'battle' && battleResult?.turns && selectedPokemon && (
            <AutoBattleScreen
              playerPokemon={selectedPokemon}
              playerSpecies={activeSpecies}
              playerMaxHp={battleResult.player_max_hp ?? 1}
              playerAbilityNom={battleResult.player_ability_nom_override ?? selectedAbilityNom}
              playerImageOverride={battleResult.player_image_override ?? undefined}
              opponentSpecies={opponentSpecies}
              opponentMaxHp={battleResult.opponent_hp ?? 1}
              opponentNom={battleResult.opponent_pokemon_nom ?? ''}
              opponentAbilityNom={battleResult.opponent_ability_nom_override ?? battleResult.opponent_ability_nom ?? ''}
              opponentImageOverride={battleResult.opponent_image_override ?? undefined}
              turns={battleResult.turns}
              playerTypeBonus={battleResult.player_type_bonus ?? false}
              opponentTypeBonus={battleResult.opponent_type_bonus ?? false}
              onContinue={() => handleBattleFinished()}
              isAdmin={isAdmin}
              attacksByName={attacksByName}
              abilityRulesByName={abilityRulesByName}
              playerDamagePerHit={battleResult.player_damage_per_hit}
              opponentDamagePerHit={battleResult.opponent_damage_per_hit}
            />
          )}

          {view === 'lose' && (
            <div className="flex flex-col items-center text-center gap-3 py-8">
              <span className="text-4xl">💥</span>
              <p className="text-ink text-base font-bold">Combat perdu…</p>
              <p className="text-ink-muted-2 text-sm">Réessayez plus tard avec un nouveau ticket.</p>
              <button onClick={resetToList} className={`mt-2 px-5 py-2 rounded font-bold text-sm ${BUTTON_STYLE.yellow}`}>
                Continuer
              </button>
            </div>
          )}

          {view === 'reward' && showEvolvePrompt && selectedPokemon && (
            <div className="relative flex flex-col items-center text-center py-6 animate-[celebrate-pop_0.3s_ease-out]">
              <p className="text-ink text-base mb-4">
                ✨ {ownedPokemonName(selectedPokemon)} peut évoluer ! Voir votre Pokémon ?
              </p>
              <div className="flex gap-3">
                <button
                  onClick={() => { onRequestPokemonDetail(selectedPokemon.id); resetToList() }}
                  className={`px-5 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.yellow}`}
                >
                  Oui
                </button>
                <button onClick={resetToList} className={`px-5 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.gray}`}>
                  Non
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {view === 'reward' && !showEvolvePrompt && selectedPokemon && battleResult?.rewards && (
        <AutoBattleRewardPopup
          pokemonDisplayName={ownedPokemonName(selectedPokemon)}
          rewards={battleResult.rewards}
          itemsByName={itemsByName}
          pokedollarImageUrl={pokedollarImageUrl}
          onConfirm={handleRewardConfirm}
        />
      )}
    </div>
  )
}
