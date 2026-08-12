import { useMemo, useRef, useState } from 'react'
import type { Player, PlayerPokemon, Pokemon, Attack, AutoBattleAbilityRule, AutoBattleManualRoundResult, PvpChallenge, PvpStartBattleResult } from '../types'
import { supabase } from '../lib/supabase'
import { usePvpConfig } from '../hooks/usePvpConfig'
import { usePvpChallenges } from '../hooks/usePvpChallenges'
import { usePvpChallengeAttempts } from '../hooks/usePvpChallengeAttempts'
import { useAutoBattleBannedAttacks } from '../hooks/useAutoBattleBannedAttacks'
import { useAutoBattleAbilityRules } from '../hooks/useAutoBattleAbilityRules'
import { generateIdempotencyKey } from '../lib/autoBattle'
import { getHpBreakdown } from '../lib/xpBonuses'
import { useToast } from '../context/ToastContext'
import { AutoBattlePokemonPicker } from './autoBattle/AutoBattlePokemonPicker'
import { AutoBattleCoinToss } from './autoBattle/AutoBattleCoinToss'
import { ManualBattleScreen } from './autoBattle/ManualBattleScreen'
import { PvpAbilityLoadoutPicker } from './PvpAbilityLoadoutPicker'
import { PvpChallengeBanner } from './PvpChallengeBanner'
import { PvpTrialBattleScreen } from './PvpTrialBattleScreen'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { PVP_ICON } from '../lib/icons'
import { logHistoryEvent } from '../lib/historyLog'

type View =
  | 'list'
  | 'past'
  | 'post-pick-pokemon'
  | 'post-pick-abilities'
  | 'trial'
  | 'attack-pick-pokemon'
  | 'attack-coin-toss'
  | 'attack-battle'
  | 'attack-lose'
  | 'attack-win'

const STATUS_MESSAGE: Record<string, string> = {
  invalid_abilities: 'Sélection de capacités invalide.',
  ineligible_pokemon: 'Ce pokémon ne peut pas être posé en défi (en pension ?).',
  ineligible_ability: "Cette capacité n'est plus disponible.",
  not_found: 'Défi introuvable.',
  challenge_inactive: 'Ce défi a été retiré entre-temps.',
  own_challenge: 'Vous ne pouvez pas attaquer votre propre défi.',
  not_started: 'Combat non initialisé, réessayez.',
}

interface Props {
  player: Player
  players: Player[]
  roster: PlayerPokemon[]
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  isAdmin?: boolean
  onClose: () => void
}

// Popup "Défi PvP" — structurellement modelé sur AutoBattlePopup mais bien
// plus petit (pas de ticket, pas de variantes/niveaux) : le seul état de
// progression est "ai-je un défi actif ?" (usePvpChallenges), pas de
// notion de ticket/récompense. Réutilise tel quel AutoBattlePokemonPicker
// (dépôt ET attaque), AutoBattleCoinToss et ManualBattleScreen (donc
// AutoBattleScreen) — voir pvp_resolve_round côté serveur, dont le JSON
// reprend volontairement le vocabulaire 'player'/'opponent' de Combat Auto
// pour permettre cette réutilisation sans aucune modification.
export function PvpPopup({ player, players, roster, pokemonByName, attacksByName, isAdmin, onClose }: Props) {
  const { config } = usePvpConfig()
  const { challenges, loading: challengesLoading, postChallenge, withdrawChallenge } = usePvpChallenges()
  const { attemptsByChallenge } = usePvpChallengeAttempts()
  const { bannedNames } = useAutoBattleBannedAttacks()
  const { rules: abilityRules } = useAutoBattleAbilityRules()
  const { showToast } = useToast()

  const abilityRulesByName = useMemo(() => {
    const map = new Map<string, AutoBattleAbilityRule>()
    for (const r of abilityRules) map.set(r.attack_nom, r)
    return map
  }, [abilityRules])

  const playersById = useMemo(() => new Map(players.map((p) => [p.id, p])), [players])

  const [view, setView] = useState<View>('list')
  const [postSelectedPokemon, setPostSelectedPokemon] = useState<PlayerPokemon | null>(null)
  // Contrôlé ici (pas dans PvpAbilityLoadoutPicker) pour survivre à un
  // aller-retour vers l'écran "Tester" (view 'trial'), qui démonte le picker.
  const [selectedAbilities, setSelectedAbilities] = useState<string[]>([])
  const [activeChallenge, setActiveChallenge] = useState<PvpChallenge | null>(null)
  const [attackSelectedPokemon, setAttackSelectedPokemon] = useState<PlayerPokemon | null>(null)
  const [firstAttacker, setFirstAttacker] = useState<'player' | 'opponent' | null>(null)
  const [pastChallenges, setPastChallenges] = useState<PvpChallenge[] | null>(null)
  const [pastLoading, setPastLoading] = useState(false)
  const submittingRef = useRef(false)

  const ownChallenge = challenges.find((c) => c.defender_player_id === player.id) ?? null
  const otherChallenges = challenges.filter((c) => c.defender_player_id !== player.id)

  const resetToList = () => {
    setView('list')
    setPostSelectedPokemon(null)
    setSelectedAbilities([])
    setActiveChallenge(null)
    setAttackSelectedPokemon(null)
    setFirstAttacker(null)
    submittingRef.current = false
  }

  const handlePostConfirm = async () => {
    if (!postSelectedPokemon || selectedAbilities.length === 0) return
    const result = await postChallenge(player.id, postSelectedPokemon.id, selectedAbilities)
    if (result.status !== 'ok') {
      showToast(STATUS_MESSAGE[result.status] ?? 'Dépôt du défi impossible pour le moment.')
      return
    }
    void logHistoryEvent('pvp', 'pvp_challenge_posted', player.id, {
      defender_player_id: player.id,
      defender_pokemon_nom: postSelectedPokemon.pokemon_nom,
      challenge_id: result.challenge_id ?? 0,
    })
    showToast('Défi posté !')
    resetToList()
  }

  const handleShowPast = async () => {
    if (view === 'past') { setView('list'); return }
    setView('past')
    if (pastChallenges != null) return
    setPastLoading(true)
    const { data, error } = await supabase
      .from('pvp_challenges')
      .select('*')
      .eq('active', false)
      .order('withdrawn_at', { ascending: false })
    if (error) {
      console.error('Erreur lors du chargement des défis passés :', error)
      setPastChallenges([])
    } else {
      setPastChallenges((data ?? []) as PvpChallenge[])
    }
    setPastLoading(false)
  }

  const handleWithdraw = async (challenge: PvpChallenge) => {
    const status = await withdrawChallenge(player.id, challenge.id)
    if (status !== 'ok') {
      showToast('Retrait du défi impossible pour le moment.')
      return
    }
    void logHistoryEvent('pvp', 'pvp_challenge_withdrawn', player.id, {
      defender_player_id: player.id,
      defender_pokemon_nom: challenge.pokemon_nom,
      challenge_id: challenge.id,
    })
    showToast('Défi retiré.')
  }

  const handlePlayChallenge = (challenge: PvpChallenge) => {
    setActiveChallenge(challenge)
    setAttackSelectedPokemon(null)
    setFirstAttacker(null)
    submittingRef.current = false
    setView('attack-pick-pokemon')
  }

  const handleStartBattle = async (pp: PlayerPokemon) => {
    if (!activeChallenge || submittingRef.current) return
    submittingRef.current = true
    setAttackSelectedPokemon(pp)

    let result: PvpStartBattleResult | null = null
    let rpcError: unknown
    try {
      const { data, error } = await supabase.rpc('pvp_start_battle', {
        p_attacker_player_id: player.id,
        p_challenge_id: activeChallenge.id,
        p_attacker_player_pokemon_id: pp.id,
        p_idempotency_key: generateIdempotencyKey(),
      })
      result = (data ?? null) as PvpStartBattleResult | null
      rpcError = error
    } catch (err) {
      rpcError = err
    }

    if (rpcError || !result || result.status !== 'ok' || !result.first_attacker) {
      if (rpcError) console.error('Erreur lors du démarrage du combat PvP :', rpcError)
      submittingRef.current = false
      showToast(STATUS_MESSAGE[result?.status ?? ''] ?? 'Combat impossible pour le moment.')
      resetToList()
      return
    }

    submittingRef.current = false
    setFirstAttacker(result.first_attacker)
    setView('attack-coin-toss')
  }

  // Typée AutoBattleManualRoundResult (pas PvpResolveRoundResult) pour que
  // ManualBattleScreen/AutoBattleScreen soient réutilisés sans aucune
  // modification (voir schema.sql, pvp_resolve_round renvoie volontairement
  // le même JSON — 'player' = l'attaquant, 'opponent' = le défenseur figé) :
  // les deux types ne diffèrent que par leurs unions `status`, jamais
  // comparées ici à autre chose que 'ok'.
  const handleSubmitRound = async (pp: PlayerPokemon, ability: Attack): Promise<AutoBattleManualRoundResult | null> => {
    if (!activeChallenge) return null

    let result: AutoBattleManualRoundResult | null = null
    let rpcError: unknown
    try {
      const { data, error } = await supabase.rpc('pvp_resolve_round', {
        p_attacker_player_id: player.id,
        p_challenge_id: activeChallenge.id,
        p_attacker_player_pokemon_id: pp.id,
        p_ability_nom: ability.nom,
        p_idempotency_key: generateIdempotencyKey(),
      })
      result = (data ?? null) as AutoBattleManualRoundResult | null
      rpcError = error
    } catch (err) {
      rpcError = err
    }

    if (rpcError || !result || result.status !== 'ok') {
      if (rpcError) console.error('Erreur lors de la résolution du tour PvP :', rpcError)
      showToast(STATUS_MESSAGE[result?.status ?? ''] ?? 'Combat impossible pour le moment.')
      return null
    }
    return result
  }

  const handleBattleFinished = (result: AutoBattleManualRoundResult) => {
    if (!activeChallenge || !attackSelectedPokemon) return
    void logHistoryEvent('pvp', result.outcome === 'win' ? 'pvp_attempt_win' : 'pvp_attempt_lose', player.id, {
      defender_player_id: activeChallenge.defender_player_id,
      defender_pokemon_nom: activeChallenge.pokemon_nom,
      attacker_pokemon_nom: attackSelectedPokemon.pokemon_nom,
      challenge_id: activeChallenge.id,
    })
    setView(result.outcome === 'win' ? 'attack-win' : 'attack-lose')
  }

  const attackOpponentSpecies = activeChallenge ? pokemonByName.get(activeChallenge.pokemon_nom) : undefined
  const attackSelectedSpecies = attackSelectedPokemon ? pokemonByName.get(attackSelectedPokemon.pokemon_nom) : undefined

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-0 sm:p-4"
      onClick={(e) => { if (e.target === e.currentTarget && view === 'list') onClose() }}
    >
      <div
        className="relative bg-cream w-full h-full overflow-hidden flex flex-col
          sm:h-auto sm:max-w-md sm:max-h-[85vh] sm:rounded-[var(--radius-pixel)] sm:border-[3px] sm:border-ink sm:shadow-[var(--shadow-pixel-lg)]"
      >
        {view !== 'attack-coin-toss' && view !== 'attack-battle' && (
          <button
            onClick={onClose}
            className="absolute right-3 top-3 z-20 w-8 h-8 rounded-full border-2 border-ink bg-cream shadow-[var(--shadow-pixel)] flex items-center justify-center text-ink hover:bg-black/10 active:shadow-none active:translate-x-[1px] active:translate-y-[1px] transition-all"
          >
            <CloseIcon className="w-4 h-4" />
          </button>
        )}

        <div className="flex-1 overflow-y-auto p-4 sm:p-5">
          {view === 'list' && (
            <>
              <div className="flex items-center gap-2 mb-4">
                <PixelIcon src={PVP_ICON} size={28} colored className="text-ink" />
                <h3 className="text-ink text-lg font-bold flex-1">{config.nom}</h3>
              </div>

              <div className="flex flex-col gap-4">
                {ownChallenge ? (
                  <>
                    <button onClick={() => void handleShowPast()} className={`self-end text-xs px-2.5 py-1.5 rounded font-bold shrink-0 ${BUTTON_STYLE.gray}`}>
                      📜 Voir les défis passés
                    </button>
                    <PvpChallengeBanner
                      challenge={ownChallenge}
                      defenderPlayer={player}
                      pokemonByName={pokemonByName}
                      attempts={attemptsByChallenge.get(ownChallenge.id) ?? []}
                      playersById={playersById}
                      isOwn
                      onPlay={() => {}}
                      onWithdraw={() => void handleWithdraw(ownChallenge)}
                    />
                  </>
                ) : (
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => setView('post-pick-pokemon')}
                      className={`flex-1 px-4 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.green}`}
                    >
                      ⚔️ Poster mon pokémon en défi
                    </button>
                    <button onClick={() => void handleShowPast()} className={`text-xs px-2.5 py-2.5 rounded font-bold shrink-0 ${BUTTON_STYLE.gray}`}>
                      📜 Voir les défis passés
                    </button>
                  </div>
                )}

                {challengesLoading ? (
                  <p className="text-ink-muted-2 text-sm">Chargement…</p>
                ) : otherChallenges.length === 0 ? (
                  <p className="text-ink-muted-2 text-sm text-center py-4">Aucun autre défi posté pour le moment.</p>
                ) : (
                  otherChallenges.map((challenge) => (
                    <PvpChallengeBanner
                      key={challenge.id}
                      challenge={challenge}
                      defenderPlayer={playersById.get(challenge.defender_player_id)}
                      pokemonByName={pokemonByName}
                      attempts={attemptsByChallenge.get(challenge.id) ?? []}
                      playersById={playersById}
                      isOwn={false}
                      onPlay={() => handlePlayChallenge(challenge)}
                      onWithdraw={() => {}}
                    />
                  ))
                )}
              </div>
            </>
          )}

          {view === 'past' && (
            <>
              <div className="flex items-center gap-2 mb-4">
                <button onClick={() => setView('list')} className={`text-xs px-2 py-1 rounded font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
                <h3 className="text-ink text-lg font-bold">Défis passés</h3>
              </div>
              <div className="flex flex-col gap-4">
                {pastLoading ? (
                  <p className="text-ink-muted-2 text-sm">Chargement…</p>
                ) : !pastChallenges || pastChallenges.length === 0 ? (
                  <p className="text-ink-muted-2 text-sm text-center py-4">Aucun défi passé.</p>
                ) : (
                  pastChallenges.map((challenge) => (
                    <PvpChallengeBanner
                      key={challenge.id}
                      challenge={challenge}
                      defenderPlayer={playersById.get(challenge.defender_player_id)}
                      pokemonByName={pokemonByName}
                      attempts={attemptsByChallenge.get(challenge.id) ?? []}
                      playersById={playersById}
                      isOwn={false}
                      readOnly
                      onPlay={() => {}}
                      onWithdraw={() => {}}
                    />
                  ))
                )}
              </div>
            </>
          )}

          {view === 'post-pick-pokemon' && (
            <AutoBattlePokemonPicker
              roster={roster}
              pokemonByName={pokemonByName}
              attacksByName={attacksByName}
              bannedAttacks={bannedNames}
              opponentDiscovered={false}
              onSelect={(pp) => { setPostSelectedPokemon(pp); setSelectedAbilities([]); setView('post-pick-abilities') }}
              onBack={resetToList}
            />
          )}

          {view === 'post-pick-abilities' && postSelectedPokemon && (
            <PvpAbilityLoadoutPicker
              playerPokemon={postSelectedPokemon}
              attacksByName={attacksByName}
              abilityRulesByName={abilityRulesByName}
              bannedAttacks={bannedNames}
              precisionEnabled={config.precision_enabled}
              loadoutMax={config.loadout_max}
              selected={selectedAbilities}
              onSelectedChange={setSelectedAbilities}
              onConfirm={() => void handlePostConfirm()}
              onTest={() => setView('trial')}
              trialAvailable={!!config.trial_pokemon_nom && !!config.trial_ability_nom}
              onBack={() => setView('post-pick-pokemon')}
            />
          )}

          {view === 'trial' && postSelectedPokemon && (
            <PvpTrialBattleScreen
              player={player}
              playerPokemon={postSelectedPokemon}
              playerSpecies={pokemonByName.get(postSelectedPokemon.pokemon_nom)}
              abilityNoms={selectedAbilities}
              dummyPokemonNom={config.trial_pokemon_nom}
              dummyMaxHp={config.trial_hp}
              pokemonByName={pokemonByName}
              attacksByName={attacksByName}
              abilityRulesByName={abilityRulesByName}
              isAdmin={isAdmin}
              onBack={() => setView('post-pick-abilities')}
            />
          )}

          {view === 'attack-pick-pokemon' && (
            <AutoBattlePokemonPicker
              roster={roster}
              pokemonByName={pokemonByName}
              attacksByName={attacksByName}
              bannedAttacks={bannedNames}
              opponentSpecies={attackOpponentSpecies}
              opponentDiscovered
              onSelect={(pp) => void handleStartBattle(pp)}
              onBack={resetToList}
            />
          )}

          {view === 'attack-coin-toss' && firstAttacker && (
            <AutoBattleCoinToss player={player} firstAttacker={firstAttacker} onDone={() => setView('attack-battle')} />
          )}

          {view === 'attack-battle' && activeChallenge && attackSelectedPokemon && firstAttacker && (
            <ManualBattleScreen
              firstAttacker={firstAttacker}
              playerPokemon={attackSelectedPokemon}
              playerSpecies={attackSelectedSpecies}
              playerMaxHp={Math.max(1, getHpBreakdown(attackSelectedSpecies, attackSelectedPokemon.xp).total)}
              opponentSpecies={attackOpponentSpecies}
              opponentNom={activeChallenge.pokemon_nom}
              opponentMaxHp={activeChallenge.max_hp}
              // Métamorph JOUEUR en mode Manuel n'est pas implémenté côté
              // pvp_resolve_round (limitation volontaire, voir schema.sql) —
              // vide plutôt que la boucle du défenseur, qui serait acceptée
              // ici mais rejetée par le serveur (validée contre les VRAIES
              // capacités apprises de l'attaquant, pas ce pool).
              opponentAbilityPool={[]}
              attacksByName={attacksByName}
              abilityRulesByName={abilityRulesByName}
              bannedAttacks={bannedNames}
              precisionEnabled={config.precision_enabled}
              isAdmin={isAdmin}
              onSubmitRound={(ability) => handleSubmitRound(attackSelectedPokemon, ability)}
              onFinished={handleBattleFinished}
              onDeclareTie={() => { showToast('Match nul — vous pouvez retenter votre chance quand vous voulez.'); resetToList() }}
            />
          )}

          {view === 'attack-win' && (
            <div className="flex flex-col items-center text-center gap-3 py-8">
              <span className="text-4xl">🏆</span>
              <p className="text-ink text-base font-bold">Défi remporté !</p>
              <button onClick={resetToList} className={`mt-2 px-5 py-2 rounded font-bold text-sm ${BUTTON_STYLE.yellow}`}>
                Continuer
              </button>
            </div>
          )}

          {view === 'attack-lose' && (
            <div className="flex flex-col items-center text-center gap-3 py-8">
              <span className="text-4xl">💥</span>
              <p className="text-ink text-base font-bold">Défi perdu…</p>
              <p className="text-ink-muted-2 text-sm">Vous pouvez retenter votre chance quand vous voulez.</p>
              <button onClick={resetToList} className={`mt-2 px-5 py-2 rounded font-bold text-sm ${BUTTON_STYLE.yellow}`}>
                Continuer
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
