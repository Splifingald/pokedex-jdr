import { useState, useEffect, useCallback } from 'react'
import type { Player, PlayerPokemon, Pokemon, Attack, PokemonEvolution, Item, AutoBattleVariant, AutoBattleLevel, AutoBattleResolveResult } from '../types'
import { TICKET_AUTOBATTLE_ITEM_NAME, POKEDOLLAR_ITEM_NAME, ownedPokemonName } from '../types'
import { supabase } from '../lib/supabase'
import { usePlayerItems } from '../hooks/usePlayerItems'
import { useAutoBattleConfig } from '../hooks/useAutoBattleConfig'
import { useAutoBattlePlayerState } from '../hooks/useAutoBattlePlayerState'
import { useAutoBattleVariants } from '../hooks/useAutoBattleVariants'
import { useAutoBattleProgress } from '../hooks/useAutoBattleProgress'
import { computeTicketRegen, isPurchaseCapReached, localDateString, formatCountdown } from '../lib/casino'
import { generateIdempotencyKey } from '../lib/autoBattle'
import { getEvolutionOptions } from '../lib/evolution'
import { useToast } from '../context/ToastContext'
import { GameBanner } from './CasinoGameCard'
import { AutoBattleVariantBanner } from './autoBattle/AutoBattleVariantBanner'
import { AutoBattlePokemonPicker } from './autoBattle/AutoBattlePokemonPicker'
import { AutoBattleAbilityPicker } from './autoBattle/AutoBattleAbilityPicker'
import { AutoBattleCoinToss } from './autoBattle/AutoBattleCoinToss'
import { AutoBattleScreen } from './autoBattle/AutoBattleScreen'
import { AutoBattleRewardPopup } from './autoBattle/AutoBattleRewardPopup'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { AUTOBATTLE_ICON, AUTOBATTLE_TICKET_ICON } from '../lib/icons'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { PokedollarIcon } from './PokedollarIcon'
import { logHistoryEvent } from '../lib/historyLog'

type View = 'list' | 'pick-pokemon' | 'pick-ability' | 'coin-toss' | 'battle' | 'reward' | 'lose'

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
}

export function AutoBattlePopup({
  player, playerItems, roster, pokemonByName, attacksByName, itemsByName, evolutionsByPokemonNom,
  pokedollarImageUrl, onRequestPokemonDetail, onClose,
}: Props) {
  const { config } = useAutoBattleConfig()
  const { state, updateState } = useAutoBattlePlayerState(player.id)
  const { variants, levelsByVariant, rewardsByLevel, loading: variantsLoading } = useAutoBattleVariants()
  const { progressByVariant, stateByLevel } = useAutoBattleProgress(player.id)
  const { showToast } = useToast()

  const [view, setView] = useState<View>('list')
  const [now, setNow] = useState(() => Date.now())
  const [activeVariant, setActiveVariant] = useState<AutoBattleVariant | null>(null)
  const [activeLevel, setActiveLevel] = useState<AutoBattleLevel | null>(null)
  const [selectedPokemon, setSelectedPokemon] = useState<PlayerPokemon | null>(null)
  const [battleResult, setBattleResult] = useState<AutoBattleResolveResult | null>(null)
  const [evolutionEligible, setEvolutionEligible] = useState(false)
  const [showEvolvePrompt, setShowEvolvePrompt] = useState(false)

  const ticketRow = playerItems.inventory.find((r) => r.item_nom === TICKET_AUTOBATTLE_ITEM_NAME)
  const ticketCount = ticketRow?.quantity ?? 0

  const tickRegen = useCallback(async () => {
    if (!state) return
    const result = computeTicketRegen(state.next_ticket_at, ticketCount, config, new Date())
    if (result.ticketsGranted > 0) {
      await playerItems.addItems(TICKET_AUTOBATTLE_ITEM_NAME, result.ticketsGranted)
      void logHistoryEvent('inventory', 'item_add', player.id, {
        item_nom: TICKET_AUTOBATTLE_ITEM_NAME,
        delta: result.ticketsGranted,
        total: ticketCount + result.ticketsGranted,
        source: 'la recharge de tickets',
      })
    }
    if (result.nextTicketAt !== state.next_ticket_at) {
      await updateState({ next_ticket_at: result.nextTicketAt })
    }
  }, [state, ticketCount, config, playerItems, updateState, player.id])

  useEffect(() => {
    tickRegen()
    const interval = window.setInterval(() => {
      setNow(Date.now())
      tickRegen()
    }, 1000)
    return () => clearInterval(interval)
    // eslint-disable-next-line react-hooks/exhaustive-deps -- tickRegen intentionally excluded: rebuilt every render, only state?.next_ticket_at / ticketCount should restart the interval
  }, [state?.next_ticket_at, ticketCount])

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
    setView('pick-pokemon')
  }

  const handleSelectAbility = async (pp: PlayerPokemon, ability: Attack) => {
    if (!activeLevel) return
    if (ticketCount < 1 || !ticketRow) {
      showToast('Aucun ticket disponible.')
      return
    }

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
      return
    }

    setBattleResult(result)
    setView('coin-toss')
  }

  const handleBattleFinished = () => {
    if (!battleResult || !activeVariant || !activeLevel || !selectedPokemon) return
    const opponentSpecies = pokemonByName.get(battleResult.opponent_pokemon_nom ?? '')

    if (battleResult.outcome === 'win') {
      void logHistoryEvent('autobattle', 'autobattle_win', player.id, {
        variant_nom: activeVariant.nom,
        pokemon_nom: selectedPokemon.pokemon_nom,
        player_pokemon_id: selectedPokemon.id,
        nickname: selectedPokemon.nickname,
        level_index: activeLevel.level_index,
        opponent_pokemon_nom: battleResult.opponent_pokemon_nom ?? '',
      })
      if (battleResult.variant_completed) {
        void logHistoryEvent('autobattle', 'autobattle_variant_completed', player.id, {
          variant_nom: activeVariant.nom,
          pokemon_nom: selectedPokemon.pokemon_nom,
          player_pokemon_id: selectedPokemon.id,
          nickname: selectedPokemon.nickname,
          level_index: activeLevel.level_index,
          opponent_pokemon_nom: battleResult.opponent_pokemon_nom ?? '',
          variant_completed: true,
        })
      }

      const xpReward = (battleResult.rewards ?? []).find((r) => r.reward_type === 'xp')
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
        opponent_pokemon_nom: opponentSpecies?.nom ?? battleResult.opponent_pokemon_nom ?? '',
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

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-0 sm:p-4"
      onClick={(e) => { if (e.target === e.currentTarget && view === 'list') onClose() }}
    >
      <div
        className="relative bg-cream w-full h-full overflow-hidden flex flex-col
          sm:h-auto sm:max-w-md sm:max-h-[85vh] sm:rounded-[var(--radius-pixel)] sm:border-[3px] sm:border-ink sm:shadow-[var(--shadow-pixel-lg)]"
      >
        <button
          onClick={onClose}
          className="absolute right-3 top-3 z-20 w-8 h-8 rounded-full flex items-center justify-center text-ink bg-cream/70 hover:bg-black/10"
        >
          <CloseIcon className="w-4 h-4" />
        </button>

        {view === 'battle' && activeLevel && battleResult?.turns && selectedPokemon && (
          <GameBanner bannerUrl={activeVariant?.banner_url ?? ''} fallbackEmoji="⚔️" className="aspect-[10/3] shrink-0" />
        )}

        <div className="flex-1 overflow-y-auto p-4 sm:p-5">
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
                ) : variants.filter((v) => v.enabled).length === 0 ? (
                  <p className="text-ink-muted-2 text-sm text-center py-4">Aucun parcours disponible pour le moment.</p>
                ) : (
                  variants.filter((v) => v.enabled).map((variant) => {
                    const levels = levelsByVariant.get(variant.id) ?? []
                    const progress = progressByVariant.get(variant.id)
                    const completed = progress?.variant_completed ?? false
                    return (
                      <div key={variant.id} className={`p-3 rounded ${PIXEL_BORDER_SM} bg-cream-secondary flex flex-col gap-2`}>
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
                          <div className="flex-1 min-w-0">
                            <span className="block text-ink text-sm font-bold truncate">{variant.nom}</span>
                            {completed && <span className="text-xs text-ink-muted-2 font-bold">🏆 Terminé</span>}
                          </div>
                          <button
                            onClick={() => handlePlayVariant(variant)}
                            disabled={ticketCount < 1 || completed || levels.length === 0}
                            className={`flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-bold shrink-0 disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.yellow}`}
                          >
                            <img src={AUTOBATTLE_TICKET_ICON} alt="" className="w-4 h-4 object-contain pixelated" />
                            Jouer
                          </button>
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
              onSelect={(pp) => { setSelectedPokemon(pp); setView('pick-ability') }}
              onBack={resetToList}
            />
          )}

          {view === 'pick-ability' && selectedPokemon && (
            <AutoBattleAbilityPicker
              playerPokemon={selectedPokemon}
              attacksByName={attacksByName}
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
              opponentSpecies={opponentSpecies}
              opponentMaxHp={battleResult.opponent_hp ?? 1}
              opponentNom={battleResult.opponent_pokemon_nom ?? ''}
              turns={battleResult.turns}
              onFinished={handleBattleFinished}
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
