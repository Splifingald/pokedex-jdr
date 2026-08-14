import { useEffect, useMemo, useState } from 'react'
import type { Pokemon, PlayerPokemon, Attack, AutoBattleAbilityRule, AutoBattleTurn, AutoBattleManualRoundResult } from '../../types'
import { AutoBattleScreen } from './AutoBattleScreen'
import { ManualBattleAbilityGrid } from './ManualBattleAbilityGrid'
import { PixelIcon } from '../icons/PixelIcon'
import { AUTOBATTLE_TICKET_ICON } from '../../lib/icons'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

// Nombre de rounds complets (chacun résout jusqu'à 2 flips, un tour de
// chaque camp — voir autobattle_resolve_manual_round) sans le moindre PV
// perdu d'aucun côté avant de proposer d'abandonner en match nul — évite
// les combats où deux pokémon s'annulent indéfiniment (aucun des deux ne
// peut jamais entamer l'autre) sans issue possible autrement.
const STALEMATE_ROUNDS_THRESHOLD = 3

interface Props {
  playerPokemon: PlayerPokemon
  playerSpecies: Pokemon | undefined
  playerMaxHp: number
  opponentSpecies: Pokemon | undefined
  opponentNom: string
  opponentMaxHp: number
  /** Capacités CONFIGURÉES sur le niveau pour l'adversaire (jusqu'à 10, voir AutoBattleLevel.opponent_ability_nom_2..10) — remplace le mouvepool du joueur dans la grille de sélection si son pokémon est Métamorph (copie le mouvepool adverse, voir requirement dédié ; contrairement à l'adversaire Métamorph qui pioche au hasard dans CELUI du joueur, ici le joueur choisit toujours laquelle jouer). */
  opponentAbilityPool: string[]
  /** Qui attaque en premier CE combat (tiré au sort par autobattle_start_manual_battle, révélé au joueur via AutoBattleCoinToss AVANT le montage de cet écran, voir AutoBattlePopup) — fixe pour tout le combat, sert uniquement à afficher "(1er)"/"(2ème)" sur l'invite de sélection. */
  firstAttacker: 'player' | 'opponent'
  /** Tours de talent joués à l'OUVERTURE du combat (voir autobattle_start_manual_battle) : animés avant que la grille de sélection ne devienne cliquable. Tableau vide si aucun talent n'est en jeu. */
  startTurns: AutoBattleTurn[]
  /** Le pokémon du joueur porte-t-il le talent 'transform' (anciennement le cas spécial Métamorph) ? Décidé par le parent à partir des talents chargés, pour rester aligné sur le serveur — qui applique la même règle, bascule globale des talents comprise. */
  playerTransforms: boolean
  /** Idem pour l'adversaire du niveau — sert au sprite copié affiché dès l'ouverture. */
  opponentTransforms: boolean
  attacksByName: Map<string, Attack>
  abilityRulesByName: Map<string, AutoBattleAbilityRule>
  bannedAttacks: Set<string>
  precisionEnabled: boolean
  isAdmin?: boolean
  /** Envoie le tour au serveur (voir autobattle_resolve_manual_round) — renvoie null en cas d'erreur réseau/RPC (déjà signalée par le parent via toast). */
  onSubmitRound: (ability: Attack) => Promise<AutoBattleManualRoundResult | null>
  onFinished: (result: AutoBattleManualRoundResult) => void
  /** Bouton "Déclarer égalité" (voir STALEMATE_ROUNDS_THRESHOLD) : crédite 1 Ticket Combat et ramène à la sélection du parcours — géré par le parent (AutoBattlePopup), pas cet écran, qui ne touche jamais à l'inventaire lui-même. */
  onDeclareTie: () => void
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
  playerPokemon, playerSpecies, playerMaxHp, opponentSpecies, opponentNom, opponentMaxHp, firstAttacker, startTurns, playerTransforms, opponentTransforms, opponentAbilityPool,
  attacksByName, abilityRulesByName, bannedAttacks, precisionEnabled, isAdmin, onSubmitRound, onFinished, onDeclareTie,
}: Props) {
  // Les tours d'ouverture (talents) sont déjà résolus côté serveur au moment du
  // tirage au sort : ils amorcent le journal, et `busy` démarre à vrai pour que
  // la grille reste verrouillée le temps de leur animation (relâchée par
  // handleAnimationCaughtUp, comme après un tour normal).
  const [turns, setTurns] = useState<AutoBattleTurn[]>(startTurns)
  const [busy, setBusy] = useState(startTurns.length > 0)
  const [pendingResult, setPendingResult] = useState<AutoBattleManualRoundResult | null>(null)
  const [roundCount, setRoundCount] = useState(0)

  // Métamorph JOUEUR : le mouvepool "connu" pour ce combat n'est plus le
  // sien mais l'ensemble des capacités configurées sur le niveau adverse
  // (dédupliqué — plusieurs positions peuvent pointer vers la même capacité,
  // voir opponentAbilityPool) — connu dès le montage (playerSpecies vient du
  // roster, pas d'un résultat de tour), pas besoin d'attendre le 1er round.
  const isPlayerMetamorph = playerTransforms
  // Sprite copié par le talent 'transform', dérivé LOCALEMENT : le serveur ne le
  // renvoie qu'avec le résultat d'un round, ce qui laissait le vrai sprite du
  // transformé à l'écran pendant toute l'ouverture (animations de talent puis
  // attente de la 1ère sélection de capacité). Même règle que côté serveur, à
  // partir des deux espèces déjà connues ici.
  const startPlayerImageOverride = playerTransforms ? opponentSpecies?.image_miniature : undefined
  const startOpponentImageOverride = opponentTransforms
    ? (startPlayerImageOverride ?? playerSpecies?.image_miniature)
    : undefined
  const abilityNoms = useMemo(
    () => isPlayerMetamorph ? [...new Set(opponentAbilityPool)] : playerPokemon.moves,
    [isPlayerMetamorph, opponentAbilityPool, playerPokemon.moves]
  )
  // Badge Super Efficace par capacité (voir ManualBattleAbilityGrid) : type
  // et liste "super efficace" EFFECTIFS, ceux copiés de l'adversaire si
  // Métamorph — jamais les siens propres dans ce cas (voir autobattle_
  // resolve_manual_round, même règle côté serveur pour le calcul réel).
  const effectivePlayerSpecies = isPlayerMetamorph ? opponentSpecies : playerSpecies

  // Une seule capacité réellement jouable (soit le pokémon n'en connaît
  // qu'une, soit toutes les autres sont bannies, voir autobattle_banned_
  // attacks) : plus vraiment un "choix", le combat se joue tout seul avec
  // cette capacité — la grille reste affichée (grisée) pour transparence,
  // mais onSelect est déclenché automatiquement à chaque tour au lieu
  // d'attendre un tap (voir l'effet ci-dessous).
  const eligibleAbilities = useMemo(
    () => abilityNoms
      .map((nom) => attacksByName.get(nom))
      .filter((a): a is Attack => a != null && !bannedAttacks.has(a.nom)),
    [abilityNoms, attacksByName, bannedAttacks]
  )
  const autoPlayAbility = eligibleAbilities.length === 1 ? eligibleAbilities[0] : null

  // Capacités dont le tour suivant est ENTIÈREMENT déterminé par le serveur
  // (2e tour d'un cycle 'prepare_release'/'skip', ou réutilisation forcée
  // d'une chaîne "Continue sur sa lancée") : laisser le joueur "choisir" à ce
  // moment-là n'aurait aucun effet, le serveur rejoue de toute façon la même
  // capacité. C'est LE SERVEUR qui le dit, via player_forced_ability_nom
  // renvoyé à chaque tour (voir autobattle_resolve_manual_round /
  // pvp_resolve_round) — plus de déduction côté client à partir du
  // turn_effect, qui ne pouvait pas connaître l'état de la chaîne en cours.
  const [forcedAbility, setForcedAbility] = useState<Attack | null>(null)
  const autoAbility = autoPlayAbility ?? forcedAbility

  const handleSelect = async (ability: Attack) => {
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
    setRoundCount((c) => c + 1)

    if (!autoPlayAbility) {
      const forcedNom = result.player_forced_ability_nom
      setForcedAbility(forcedNom ? attacksByName.get(forcedNom) ?? null : null)
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
    const timeout = window.setTimeout(() => void handleSelect(autoAbility), 0)
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

  // Voir STALEMATE_ROUNDS_THRESHOLD : les deux pokémon n'ont pas perdu un
  // seul PV après ce nombre de rounds complets — situation de blocage
  // mutuel (aucun des deux ne peut jamais entamer l'autre) sans autre issue
  // que d'abandonner. pendingResult.outcome !IS NULL exclurait cet écran de
  // toute façon (transition vers récompense/défaite), pas besoin de le
  // revérifier ici.
  const isStalemate = roundCount >= STALEMATE_ROUNDS_THRESHOLD
    && pendingResult?.player_hp === playerMaxHp
    && pendingResult?.opponent_hp === opponentMaxHp

  return (
    <AutoBattleScreen
      playerPokemon={playerPokemon}
      playerSpecies={playerSpecies}
      playerMaxHp={playerMaxHp}
      playerAbilityNom=""
      playerImageOverride={pendingResult?.player_image_override ?? startPlayerImageOverride ?? undefined}
      opponentSpecies={opponentSpecies}
      opponentMaxHp={opponentMaxHp}
      opponentNom={opponentNom}
      opponentAbilityNom=""
      opponentImageOverride={pendingResult?.opponent_image_override ?? startOpponentImageOverride ?? undefined}
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
              {/* L'ordre des tours peut CHANGER en cours de combat (voir
                  turn_effect 'first_and_replay'/'charge_double_next' : le camp
                  qui gagne une action supplémentaire reprend la main en
                  premier) — on préfère donc l'ordre du prochain round renvoyé
                  par le serveur à la valeur figée du tirage initial. */}
              Sélectionne la capacité à utiliser {(pendingResult?.first_attacker ?? firstAttacker) === 'player' ? '(1er)' : '(2ème)'}
            </p>
          )}
          <ManualBattleAbilityGrid
            abilityNoms={abilityNoms}
            playerSpecies={effectivePlayerSpecies}
            opponentSpecies={opponentSpecies}
            attacksByName={attacksByName}
            abilityRulesByName={abilityRulesByName}
            bannedAttacks={bannedAttacks}
            precisionEnabled={precisionEnabled}
            disabled={busy || !!autoPlayAbility || !!forcedAbility}
            onSelect={(ability) => void handleSelect(ability)}
          />
          {isStalemate && (
            <button
              onClick={onDeclareTie}
              disabled={busy}
              className={`flex items-center justify-center gap-2 px-4 py-2 rounded-lg text-sm font-bold ${busy ? 'opacity-40 cursor-not-allowed' : BUTTON_STYLE.gray}`}
            >
              Déclarer égalité
              <span className="flex items-center gap-1">
                +1 <PixelIcon src={AUTOBATTLE_TICKET_ICON} size={16} colored />
              </span>
            </button>
          )}
        </div>
      }
    />
  )
}
