import { useEffect, useMemo, useState } from 'react'
import type { Pokemon, PlayerPokemon, Attack, AutoBattleAbilityRule, AutoBattleTurn, AutoBattleManualRoundResult } from '../../types'
import { AutoBattleScreen } from './AutoBattleScreen'
import { ManualBattleAbilityGrid } from './ManualBattleAbilityGrid'

interface Props {
  playerPokemon: PlayerPokemon
  playerSpecies: Pokemon | undefined
  playerMaxHp: number
  opponentSpecies: Pokemon | undefined
  opponentNom: string
  opponentMaxHp: number
  /** Qui attaque en premier CE combat (tiré au sort par autobattle_start_manual_battle, révélé au joueur via AutoBattleCoinToss AVANT le montage de cet écran, voir AutoBattlePopup) — fixe pour tout le combat, sert uniquement à afficher "(1er)"/"(2ème)" sur l'invite de sélection. */
  firstAttacker: 'player' | 'opponent'
  attacksByName: Map<string, Attack>
  abilityRulesByName: Map<string, AutoBattleAbilityRule>
  bannedAttacks: Set<string>
  precisionEnabled: boolean
  isAdmin?: boolean
  /** Envoie le tour au serveur (voir autobattle_resolve_manual_round) — renvoie null en cas d'erreur réseau/RPC (déjà signalée par le parent via toast). */
  onSubmitRound: (ability: Attack) => Promise<AutoBattleManualRoundResult | null>
  onFinished: (result: AutoBattleManualRoundResult) => void
}

// Écran de combat Manuel — requirement : animations STRICTEMENT identiques
// au mode Auto. Plutôt que dupliquer la chorégraphie d'attaque (anticipation/
// lunge/strike/soin/statut/etc.), cet écran est une fine coquille autour
// d'AutoBattleScreen : une SEULE instance couvre tout le combat (jamais
// remontée), nourrie d'un tableau `turns` qui grandit à chaque tour (voir
// AutoBattleScreen — son effet de programmation d'animation est incrémental
// pour cette raison précise). La grille de sélection (ManualBattleAbilityGrid,
// sous le visuel, au-dessus de l'historique — requirement) est injectée via
// AutoBattleScreen.midSlot ; hideContinueButton fait que c'est CET écran,
// pas un clic joueur, qui décide de la suite une fois l'animation d'un tour
// terminée (voir handleAnimationCaughtUp). Le tirage au sort "qui attaque en
// premier" est joué AVANT le montage de cet écran (voir AutoBattlePopup —
// autobattle_start_manual_battle décide first_attacker dès le choix du
// pokémon, plus besoin de le différer ici jusqu'au 1er tour).
export function ManualBattleScreen({
  playerPokemon, playerSpecies, playerMaxHp, opponentSpecies, opponentNom, opponentMaxHp, firstAttacker,
  attacksByName, abilityRulesByName, bannedAttacks, precisionEnabled, isAdmin, onSubmitRound, onFinished,
}: Props) {
  const [turns, setTurns] = useState<AutoBattleTurn[]>([])
  const [busy, setBusy] = useState(false)
  const [pendingResult, setPendingResult] = useState<AutoBattleManualRoundResult | null>(null)

  // Une seule capacité réellement jouable (soit le pokémon n'en connaît
  // qu'une, soit toutes les autres sont bannies, voir autobattle_banned_
  // attacks) : plus vraiment un "choix", le combat se joue tout seul avec
  // cette capacité — la grille reste affichée (grisée) pour transparence,
  // mais onSelect est déclenché automatiquement à chaque tour au lieu
  // d'attendre un tap (voir l'effet ci-dessous).
  const eligibleAbilities = useMemo(
    () => playerPokemon.moves
      .map((nom) => attacksByName.get(nom))
      .filter((a): a is Attack => a != null && !bannedAttacks.has(a.nom)),
    [playerPokemon.moves, attacksByName, bannedAttacks]
  )
  const autoPlayAbility = eligibleAbilities.length === 1 ? eligibleAbilities[0] : null

  // Capacités à rythme sur 2 tours (voir autobattle_ability_rules.turn_effect
  // 'prepare_release'/'skip', pleinement actifs en Manuel) : le 2e tour d'un
  // cycle (libération, ou passage forcé) est ENTIÈREMENT déterminé par le
  // serveur dès le 1er tour — laisser le joueur "choisir" quoi que ce soit à
  // ce moment-là n'aurait aucun effet (le serveur force de toute façon la
  // même capacité, voir v_player_preparing/v_player_skip_pending côté RPC) et
  // induirait en erreur. forcedAbility retient cette capacité pour le tour
  // SUIVANT uniquement — remis à null une fois ce tour forcé joué, qu'il
  // s'agisse ou non lui-même du début d'un nouveau cycle (un pur
  // 'prepare_release'/'skip' ne s'enchaîne jamais tout seul sur 2 cycles
  // d'affilée sans un nouveau choix explicite entretemps).
  const [forcedAbility, setForcedAbility] = useState<Attack | null>(null)
  const autoAbility = autoPlayAbility ?? forcedAbility

  const handleSelect = async (ability: Attack, forced: boolean) => {
    if (busy) return
    setBusy(true)
    const result = await onSubmitRound(ability)
    if (!result || result.status !== 'ok') {
      setBusy(false)
      return
    }
    // Décoration client-only (voir AutoBattleTurn.ability_nom) : la capacité
    // change à chaque tour en mode Manuel, contrairement au mode Auto où
    // AutoBattleScreen la reçoit comme prop fixe pour tout le combat.
    const taggedTurns = (result.turns ?? []).map((turn) => ({
      ...turn,
      ability_nom: turn.attacker === 'player' ? result.player_ability_nom : result.opponent_ability_nom,
    }))
    setTurns((prev) => [...prev, ...taggedTurns])
    setPendingResult(result)

    if (!autoPlayAbility) {
      if (forced) {
        setForcedAbility(null)
      } else {
        const turnEffect = abilityRulesByName.get(ability.nom)?.turn_effect
        setForcedAbility(turnEffect === 'prepare_release' || turnEffect === 'skip' ? ability : null)
      }
    }
  }

  // Partie Automatique (capacité unique) et rythme forcé (voir ci-dessus) :
  // redéclenche handleSelect dès que la main revient (busy repasse à false)
  // sans attendre de tap — au 1er montage aussi bien qu'après chaque tour.
  useEffect(() => {
    if (!autoAbility || busy) return
    // setTimeout (délai nul) plutôt qu'un appel direct : handleSelect
    // déclenche setBusy(true) en tout premier, et l'appeler de façon
    // synchrone depuis le corps de l'effet enchaînerait les rendus.
    const timeout = window.setTimeout(() => void handleSelect(autoAbility, true), 0)
    return () => window.clearTimeout(timeout)
    // eslint-disable-next-line react-hooks/exhaustive-deps -- ne doit se redéclencher que sur ces deux signaux ; handleSelect/onSubmitRound sont volontairement exclus (fermeture recréée à chaque rendu, toujours à jour)
  }, [autoAbility, busy])

  // Appelé par AutoBattleScreen (hideContinueButton) dès que l'animation des
  // tours actuellement disponibles est terminée — pas un clic joueur.
  const handleAnimationCaughtUp = () => {
    if (pendingResult?.outcome) {
      onFinished(pendingResult)
      return
    }
    setBusy(false)
  }

  return (
    <AutoBattleScreen
      playerPokemon={playerPokemon}
      playerSpecies={playerSpecies}
      playerMaxHp={playerMaxHp}
      playerAbilityNom=""
      opponentSpecies={opponentSpecies}
      opponentMaxHp={opponentMaxHp}
      opponentNom={opponentNom}
      opponentAbilityNom=""
      turns={turns}
      playerTypeBonus={pendingResult?.player_type_bonus ?? false}
      opponentTypeBonus={pendingResult?.opponent_type_bonus ?? false}
      onContinue={handleAnimationCaughtUp}
      hideContinueButton
      skipCountdown
      isAdmin={isAdmin}
      attacksByName={attacksByName}
      abilityRulesByName={abilityRulesByName}
      midSlot={
        <div className="flex flex-col gap-2">
          {autoPlayAbility ? (
            <p className="text-ink text-sm font-bold text-center">Partie Automatique, une seule capacité possible</p>
          ) : !busy && !forcedAbility && (
            <p className="text-ink text-sm font-bold text-center">
              Sélectionne la capacité à utiliser {firstAttacker === 'player' ? '(1er)' : '(2ème)'}
            </p>
          )}
          <ManualBattleAbilityGrid
            playerPokemon={playerPokemon}
            attacksByName={attacksByName}
            abilityRulesByName={abilityRulesByName}
            bannedAttacks={bannedAttacks}
            precisionEnabled={precisionEnabled}
            disabled={busy || !!autoPlayAbility || !!forcedAbility}
            onSelect={(ability) => void handleSelect(ability, false)}
          />
        </div>
      }
    />
  )
}
