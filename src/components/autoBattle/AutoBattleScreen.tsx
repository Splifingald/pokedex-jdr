import { useEffect, useState } from 'react'
import type { Pokemon, PlayerPokemon } from '../../types'
import { ownedPokemonName } from '../../types'
import { HpGauge } from '../HpGauge'
import { AutoBattleDamageNumber } from './AutoBattleDamageNumber'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import type { AutoBattleTurn } from '../../types'

interface Props {
  playerPokemon: PlayerPokemon
  playerSpecies: Pokemon | undefined
  playerMaxHp: number
  opponentSpecies: Pokemon | undefined
  opponentMaxHp: number
  opponentNom: string
  turns: AutoBattleTurn[]
  /** Le pokémon du joueur est-il super efficace contre le type de l'adversaire (voir requirement #17) */
  playerTypeBonus: boolean
  /** Idem pour l'adversaire contre le type du joueur */
  opponentTypeBonus: boolean
  onContinue: () => void
}

const COUNTDOWN_STEPS = ['3', '2', '1', 'GO !']
const COUNTDOWN_STEP_MS = 600

// Durées des phases d'attaque (voir AttackPhase ci-dessous) — les dégâts sont
// appliqués au moment de l'impact (atterrissage, fin de 'strike-land'), pas
// au début du tour. GAP_MS est le temps mort après le retour avant le tour suivant.
const ANTICIPATION_MS = 150
const LUNGE_MS = 100
const STRIKE_RISE_MS = 140
const STRIKE_LAND_MS = 140
const RETURN_MS = 250
const GAP_MS = 150
const IMPACT_OFFSET_MS = ANTICIPATION_MS + LUNGE_MS + STRIKE_RISE_MS + STRIKE_LAND_MS
const TURN_MS = IMPACT_OFFSET_MS + RETURN_MS + GAP_MS

type AttackPhase = 'anticipation' | 'lunge' | 'strike-rise' | 'strike-land' | 'return'
interface AttackState { side: 'player' | 'opponent'; phase: AttackPhase }

// Style de transform du pokémon attaquant selon la phase en cours, combinant
// les axes X (avance vers l'adversaire) et Y (arc de saut) : petit recul
// (anticipation), petit bond en avant (lunge), grand saut qui monte haut en
// couvrant l'essentiel de la distance (strike-rise), puis retombe tout près
// de/sur l'adversaire (strike-land — c'est à la fin de cette phase que les
// dégâts sont appliqués, "quand le pokémon atteint la cible"), puis retour à
// la position de départ (return). `sign` vaut +1 pour le joueur (avance vers
// la droite, l'adversaire) et -1 pour l'adversaire (avance vers la gauche).
function attackTransform(phase: AttackPhase, sign: 1 | -1): React.CSSProperties {
  switch (phase) {
    case 'anticipation':
      return { transform: `translate(${sign * -8}px, 4px) scale(0.95)`, transition: `transform ${ANTICIPATION_MS}ms ease-out` }
    case 'lunge':
      return { transform: `translate(${sign * 20}px, -10px) scale(1.04)`, transition: `transform ${LUNGE_MS}ms ease-in` }
    case 'strike-rise':
      return { transform: `translate(${sign * 120}px, -55px) scale(1.1)`, transition: `transform ${STRIKE_RISE_MS}ms ease-out` }
    case 'strike-land':
      return { transform: `translate(${sign * 175}px, -6px) scale(1.2)`, transition: `transform ${STRIKE_LAND_MS}ms ease-in` }
    case 'return':
      return { transform: 'translate(0, 0) scale(1)', transition: `transform ${RETURN_MS}ms ease-out` }
  }
}

// Rejoue le journal de tours renvoyé par le RPC autobattle_resolve_battle
// (jamais recalculé côté client, voir requirement #37) : joueur à gauche,
// adversaire à droite. Chaque tour joue une petite séquence d'attaque
// (anticipation → bond → grand saut sur l'adversaire → retour), les dégâts
// n'étant appliqués (flash rouge + secousse + nombre flottant) qu'au moment
// de l'impact plutôt qu'au début du tour. Les deux pokémon sont déjà visibles
// (pièce jouée) pendant le compte à rebours 3-2-1-GO avant le premier coup.
// Une fois le combat terminé, reste affiché avec un bouton "Continuer"
// plutôt que d'enchaîner automatiquement sur les récompenses/l'écran de défaite.
export function AutoBattleScreen({
  playerPokemon, playerSpecies, playerMaxHp, opponentSpecies, opponentMaxHp, opponentNom, turns,
  playerTypeBonus, opponentTypeBonus, onContinue,
}: Props) {
  const [countdownStep, setCountdownStep] = useState(-1)
  const [fighting, setFighting] = useState(false)
  const [playerHp, setPlayerHp] = useState(playerMaxHp)
  const [opponentHp, setOpponentHp] = useState(opponentMaxHp)
  const [shownTurnIndex, setShownTurnIndex] = useState(-1)
  const [attackState, setAttackState] = useState<AttackState | null>(null)
  const [shakeSide, setShakeSide] = useState<'player' | 'opponent' | null>(null)
  const [flashSide, setFlashSide] = useState<'player' | 'opponent' | null>(null)
  const [hitKey, setHitKey] = useState(0)
  const [lastDamage, setLastDamage] = useState<{ side: 'player' | 'opponent'; damage: number; superEffective: boolean } | null>(null)
  const [battleDone, setBattleDone] = useState(turns.length === 0)

  // Compte à rebours 3…2…1…GO ! avant le premier coup, même idiome que
  // MagikarpGame — les deux pokémon sont déjà affichés pendant ce temps.
  useEffect(() => {
    const timers = COUNTDOWN_STEPS.map((_, i) =>
      window.setTimeout(() => setCountdownStep(i), i * COUNTDOWN_STEP_MS)
    )
    timers.push(window.setTimeout(() => setFighting(true), COUNTDOWN_STEPS.length * COUNTDOWN_STEP_MS))
    return () => timers.forEach(clearTimeout)
  }, [])

  useEffect(() => {
    if (!fighting) return
    const timers: number[] = []
    turns.forEach((turn, i) => {
      const turnStart = i * TURN_MS
      const attackerSide = turn.attacker
      const hitSide = attackerSide === 'player' ? 'opponent' : 'player'

      timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'anticipation' }), turnStart))
      timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'lunge' }), turnStart + ANTICIPATION_MS))
      timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'strike-rise' }), turnStart + ANTICIPATION_MS + LUNGE_MS))
      timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'strike-land' }), turnStart + ANTICIPATION_MS + LUNGE_MS + STRIKE_RISE_MS))
      const isSuperEffective = attackerSide === 'player' ? playerTypeBonus : opponentTypeBonus
      timers.push(window.setTimeout(() => {
        setShownTurnIndex(i)
        if (hitSide === 'player') setPlayerHp(turn.defender_hp_after)
        else setOpponentHp(turn.defender_hp_after)
        setShakeSide(hitSide)
        setFlashSide(hitSide)
        setLastDamage({ side: hitSide, damage: turn.damage, superEffective: isSuperEffective })
        setHitKey((k) => k + 1)
        setAttackState({ side: attackerSide, phase: 'return' })
        window.setTimeout(() => setShakeSide(null), 300)
        window.setTimeout(() => setFlashSide(null), 220)
      }, turnStart + IMPACT_OFFSET_MS))
      timers.push(window.setTimeout(() => setAttackState(null), turnStart + IMPACT_OFFSET_MS + RETURN_MS))
    })
    timers.push(window.setTimeout(() => setBattleDone(true), turns.length * TURN_MS + 200))
    return () => timers.forEach(clearTimeout)
    // eslint-disable-next-line react-hooks/exhaustive-deps -- ne doit démarrer qu'une fois fighting passe à true (turns figé pour ce combat)
  }, [fighting])

  const playerKo = shownTurnIndex >= 0 && playerHp <= 0
  const opponentKo = shownTurnIndex >= 0 && opponentHp <= 0

  const playerAttackStyle = attackState?.side === 'player' ? attackTransform(attackState.phase, 1) : undefined
  const opponentAttackStyle = attackState?.side === 'opponent' ? attackTransform(attackState.phase, -1) : undefined

  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col items-center gap-2">
          <p className="text-ink text-base font-bold truncate max-w-full">{ownedPokemonName(playerPokemon)}</p>
          <div
            className="relative w-24 h-24 flex items-center justify-center"
            style={{ ...playerAttackStyle, animation: shakeSide === 'player' ? 'hit-shake 0.3s ease-in-out' : undefined }}
          >
            {playerSpecies?.image_miniature ? (
              <img
                src={playerSpecies.image_miniature}
                alt=""
                className={`pixelated w-full h-full object-contain ${playerKo ? 'grayscale opacity-40' : ''}`}
              />
            ) : (
              <span className="text-4xl">?</span>
            )}
            {flashSide === 'player' && (
              <div className="absolute inset-0 bg-hp-red rounded-full pointer-events-none" style={{ animation: 'hit-flash 0.22s ease-out' }} />
            )}
            {lastDamage?.side === 'player' && (
              <AutoBattleDamageNumber damage={lastDamage.damage} animKey={hitKey} superEffective={lastDamage.superEffective} />
            )}
          </div>
          <div className="w-full max-w-[160px]">
            <HpGauge current={Math.max(0, playerHp)} max={playerMaxHp} />
          </div>
        </div>

        <div className="flex flex-col items-center gap-2">
          <p className="text-ink text-base font-bold truncate max-w-full">{opponentNom}</p>
          <div
            className="relative w-24 h-24 flex items-center justify-center"
            style={{ ...opponentAttackStyle, animation: shakeSide === 'opponent' ? 'hit-shake 0.3s ease-in-out' : undefined }}
          >
            {opponentSpecies?.image_miniature ? (
              <img
                src={opponentSpecies.image_miniature}
                alt=""
                className={`pixelated w-full h-full object-contain ${opponentKo ? 'grayscale opacity-40' : ''}`}
              />
            ) : (
              <span className="text-4xl">?</span>
            )}
            {flashSide === 'opponent' && (
              <div className="absolute inset-0 bg-hp-red rounded-full pointer-events-none" style={{ animation: 'hit-flash 0.22s ease-out' }} />
            )}
            {lastDamage?.side === 'opponent' && (
              <AutoBattleDamageNumber damage={lastDamage.damage} animKey={hitKey} superEffective={lastDamage.superEffective} />
            )}
          </div>
          <div className="w-full max-w-[160px]">
            <HpGauge current={Math.max(0, opponentHp)} max={opponentMaxHp} />
          </div>
        </div>
      </div>

      {!fighting && countdownStep >= 0 && (
        <div key={countdownStep} className="text-center text-ink text-4xl font-bold animate-[celebrate-pop_0.4s_ease-out]">
          {COUNTDOWN_STEPS[countdownStep]}
        </div>
      )}

      {(playerKo || opponentKo) && (
        <p className="text-center text-hp-red text-xl font-bold animate-[celebrate-pop_0.4s_ease-out]">K.O. !</p>
      )}

      {battleDone && (
        <button
          onClick={onContinue}
          className={`self-center mt-1 px-6 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.yellow}`}
        >
          Continuer
        </button>
      )}
    </div>
  )
}
