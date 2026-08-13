import { useEffect, useState } from 'react'
import type { Player, PlayerPokemon, Pokemon, Attack, AutoBattleAbilityRule, AutoBattleTurn, AutoBattleManualRoundResult, PvpTrialStartResult } from '../types'
import { supabase } from '../lib/supabase'
import { generateIdempotencyKey, normalizeFirstAttacker } from '../lib/autoBattle'
import { getHpBreakdown } from '../lib/xpBonuses'
import { useToast } from '../context/ToastContext'
import { AutoBattleScreen } from './autoBattle/AutoBattleScreen'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  player: Player
  playerPokemon: PlayerPokemon
  playerSpecies: Pokemon | undefined
  /** Boucle EN COURS DE CONSTRUCTION (pas encore postée, voir PvpAbilityLoadoutPicker) — snapshotée côté serveur au démarrage (pvp_trial_start), jamais relue depuis ce composant après coup. */
  abilityNoms: string[]
  dummyPokemonNom: string
  dummyMaxHp: number
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  abilityRulesByName: Map<string, AutoBattleAbilityRule>
  /** Quitter le test à tout moment (avant, pendant ou après le combat) — retourne à la sélection de capacités, celle-ci reste intacte côté parent (voir PvpPopup, `selected` y est contrôlé). */
  onBack: () => void
}

type View = 'choose-start' | 'battle'

const STATUS_MESSAGE: Record<string, string> = {
  invalid_abilities: 'Sélection de capacités invalide.',
  ineligible_pokemon: 'Ce pokémon ne peut pas combattre (en pension ?).',
  ineligible_ability: "Cette capacité n'est plus disponible.",
  trial_not_configured: "Le mode d'essai n'est pas configuré par l'admin.",
  not_started: 'Combat non initialisé, réessaie.',
}

// Combat d'ESSAI (voir supabase/schema.sql pvp_trial_start/pvp_trial_resolve_
// round) : 100% automatique des deux côtés une fois lancé (aucune capacité
// choisie interactivement, contrairement à ManualBattleScreen) — ce
// composant se contente de rappeler pvp_trial_resolve_round en boucle dès
// que la main revient, à 1.5× la vitesse d'animation normale (voir
// speedMultiplier sur AutoBattleScreen), jusqu'à l'issue. Le bouton "Quitter"
// reste visible à tout moment (avant/pendant/après le combat) — aucune
// récompense, aucun écran de fin dédié, juste un retour à la sélection.
export function PvpTrialBattleScreen({
  player, playerPokemon, playerSpecies, abilityNoms, dummyPokemonNom, dummyMaxHp, pokemonByName,
  attacksByName, abilityRulesByName, onBack,
}: Props) {
  const { showToast } = useToast()
  const [view, setView] = useState<View>('choose-start')
  const [starting, setStarting] = useState(false)
  const [firstAttacker, setFirstAttacker] = useState<'player' | 'opponent' | null>(null)
  const [turns, setTurns] = useState<AutoBattleTurn[]>([])
  const [pendingResult, setPendingResult] = useState<AutoBattleManualRoundResult | null>(null)
  const [busy, setBusy] = useState(false)
  const [done, setDone] = useState(false)

  const dummySpecies = pokemonByName.get(dummyPokemonNom)
  const playerMaxHp = Math.max(1, getHpBreakdown(playerSpecies, playerPokemon.xp).total)

  const handleStart = async (playerStarts: boolean) => {
    if (starting) return
    setStarting(true)
    let result: PvpTrialStartResult | null = null
    let rpcError: unknown
    try {
      const { data, error } = await supabase.rpc('pvp_trial_start', {
        p_player_id: player.id,
        p_player_pokemon_id: playerPokemon.id,
        p_ability_noms: abilityNoms,
        p_player_starts: playerStarts,
        p_idempotency_key: generateIdempotencyKey(),
      })
      result = (data ?? null) as PvpTrialStartResult | null
      rpcError = error
    } catch (err) {
      rpcError = err
    }

    if (rpcError || !result || result.status !== 'ok' || !result.first_attacker) {
      if (rpcError) console.error("Erreur lors du démarrage du combat d'essai :", rpcError)
      setStarting(false)
      showToast(STATUS_MESSAGE[result?.status ?? ''] ?? "Combat d'essai impossible pour le moment.")
      return
    }

    setFirstAttacker(normalizeFirstAttacker(result.first_attacker))
    setStarting(false)
    setView('battle')
  }

  // Aucune capacité choisie ici (contrairement à ManualBattleScreen) : les
  // deux côtés cyclent automatiquement côté serveur, voir pvp_trial_resolve_round.
  const submitRound = async () => {
    let result: AutoBattleManualRoundResult | null = null
    let rpcError: unknown
    try {
      const { data, error } = await supabase.rpc('pvp_trial_resolve_round', {
        p_player_id: player.id,
        p_idempotency_key: generateIdempotencyKey(),
      })
      result = (data ?? null) as AutoBattleManualRoundResult | null
      rpcError = error
    } catch (err) {
      rpcError = err
    }

    if (rpcError || !result || result.status !== 'ok') {
      if (rpcError) console.error("Erreur lors de la résolution du tour d'essai :", rpcError)
      showToast(STATUS_MESSAGE[result?.status ?? ''] ?? "Combat d'essai impossible pour le moment.")
      setBusy(false)
      return
    }

    const taggedTurns = (result.turns ?? []).map((turn) => ({
      ...turn,
      ability_nom: turn.attacker === 'player' ? result!.player_ability_nom : result!.opponent_ability_nom,
    }))
    setTurns((prev) => [...prev, ...taggedTurns])
    setPendingResult(result)
  }

  // Redéclenche un round dès que la main revient (busy repasse à false, voir
  // handleAnimationCaughtUp) — au montage de la vue 'battle' comme après
  // chaque tour, sans jamais attendre d'action du joueur.
  useEffect(() => {
    if (view !== 'battle' || done || busy) return
    setBusy(true)
    void submitRound()
    // eslint-disable-next-line react-hooks/exhaustive-deps -- ne doit se redéclencher que sur ces signaux ; submitRound est volontairement exclu (fermeture recréée à chaque rendu, toujours à jour)
  }, [view, done, busy])

  // Appelé par AutoBattleScreen (hideContinueButton) dès que l'animation des
  // tours actuellement disponibles est terminée — pas un clic joueur.
  const handleAnimationCaughtUp = () => {
    if (pendingResult?.outcome) {
      setDone(true)
      return
    }
    setBusy(false)
  }

  if (view === 'choose-start') {
    return (
      <div className="flex flex-col items-center gap-4 py-6">
        <button onClick={onBack} className={`self-start text-xs px-2 py-1 rounded font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
        <p className="text-ink text-base font-bold text-center">Qui attaque en premier ?</p>
        <div className="flex gap-3">
          <button
            onClick={() => void handleStart(true)}
            disabled={starting}
            className={`px-5 py-2.5 rounded-lg text-sm font-bold disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.yellow}`}
          >
            Je commence
          </button>
          <button
            onClick={() => void handleStart(false)}
            disabled={starting}
            className={`px-5 py-2.5 rounded-lg text-sm font-bold disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.gray}`}
          >
            L'adversaire commence
          </button>
        </div>
      </div>
    )
  }

  if (!firstAttacker) return null

  return (
    <div className="flex flex-col gap-3">
      <AutoBattleScreen
        playerPokemon={playerPokemon}
        playerSpecies={playerSpecies}
        playerMaxHp={playerMaxHp}
        playerAbilityNom=""
        opponentSpecies={dummySpecies}
        opponentMaxHp={dummyMaxHp}
        opponentNom={dummyPokemonNom}
        opponentAbilityNom=""
        turns={turns}
        playerTypeBonus={pendingResult?.player_type_bonus ?? false}
        opponentTypeBonus={pendingResult?.opponent_type_bonus ?? false}
        onContinue={handleAnimationCaughtUp}
        hideContinueButton
        skipCountdown
        speedMultiplier={1.5}
        // Toujours vrai ici (indépendamment du vrai statut admin du joueur) :
        // dans ce mode d'essai uniquement, tout le monde voit le détail
        // habituellement réservé aux admins (précision effective, dégâts,
        // soin...) dans l'historique des tours — utile pour affiner sa boucle
        // avant de poser un défi réel.
        isAdmin
        attacksByName={attacksByName}
        abilityRulesByName={abilityRulesByName}
      />
      <button onClick={onBack} className={`self-center px-4 py-2 rounded-lg text-sm font-bold ${BUTTON_STYLE.gray}`}>
        Quitter le test et retourner à la sélection
      </button>
    </div>
  )
}
