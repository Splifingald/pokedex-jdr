import { useEffect, useRef, useState } from 'react'
import type { CSSProperties } from 'react'
import type { Pokemon, PlayerPokemon, AutoBattleStatusEffect } from '../../types'
import { ownedPokemonName } from '../../types'
import { HpGauge } from '../HpGauge'
import { AutoBattleDamageNumber } from './AutoBattleDamageNumber'
import { AutoBattleFloatingText } from './AutoBattleFloatingText'
import { AutoBattleHealEffect } from './AutoBattleHealEffect'
import { AutoBattleDiceRoll } from './AutoBattleDiceRoll'
import { AutoBattleHistoryLog, type AutoBattleHistoryEntryData } from './AutoBattleHistoryLog'
import { getStatusEffectDisplay } from '../../lib/autoBattle'
import { PixelIcon } from '../icons/PixelIcon'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import type { AutoBattleTurn } from '../../types'

// Libellé du texte flottant affiché quand un statut fait passer le tour
// (paralysie/gel = une fois ; sommeil = tant que le dé ne tombe pas sur
// 4/5/6) — 'fear'/'confusion'/'burn'/'poison' ne passent jamais le tour donc
// n'ont pas d'entrée ici (voir AutoBattleTurn.status_tick côté serveur).
const STATUS_SKIP_LABEL: Partial<Record<AutoBattleStatusEffect, string>> = {
  paralysis: 'Paralysé !',
  frozen: 'Gelé !',
  sleep: 'Endormi...',
}

interface Props {
  playerPokemon: PlayerPokemon
  playerSpecies: Pokemon | undefined
  playerMaxHp: number
  playerAbilityNom: string
  /** Cas Métamorph : sprite de l'adversaire copié pour ce combat (voir autobattle_resolve_battle) — remplace playerSpecies.image_miniature partout où le sprite du joueur est affiché. */
  playerImageOverride?: string
  opponentSpecies: Pokemon | undefined
  opponentMaxHp: number
  opponentNom: string
  opponentAbilityNom: string
  /** Cas Métamorph configuré comme adversaire : sprite du joueur copié pour ce combat — remplace opponentSpecies.image_miniature partout où le sprite adverse est affiché. */
  opponentImageOverride?: string
  turns: AutoBattleTurn[]
  /** Le pokémon du joueur est-il super efficace contre le type de l'adversaire (voir requirement #17) */
  playerTypeBonus: boolean
  /** Idem pour l'adversaire contre le type du joueur */
  opponentTypeBonus: boolean
  onContinue: () => void
}

const COUNTDOWN_STEPS = ['3', '2', '1', 'GO !']

// Ralentissement global de toutes les animations/affichages de texte de
// l'écran de combat (1.3× plus lent que la base historique) — appliqué une
// fois ici à toutes les constantes de durée ci-dessous plutôt que dispersé
// dans chaque composant, pour garder un seul endroit à ajuster.
const GLOBAL_SLOWDOWN = 1.3

const COUNTDOWN_STEP_MS = 600 * GLOBAL_SLOWDOWN

// Durées de base des phases d'attaque (voir AttackPhase ci-dessous) — les
// dégâts sont appliqués au moment de l'impact (atterrissage, fin de
// 'strike-land'), pas au début du tour. GAP_MS est le temps mort après le
// retour avant le tour suivant. Un tour raté (système de précision) ou
// passé (effet spécial 'skip') garde la même durée totale que ces phases de
// base pour que le rythme reste prévisible, mais saute les phases de saut.
// Ces constantes sont des BASES : chaque tour applique en plus un multiple
// de vitesse (voir speedMultiplierForRepeat/computeDurations) qui les
// raccourcit quand la capacité est utilisée plusieurs fois d'affilée — donc
// jamais utilisées telles quelles pour programmer les timers, seulement via
// computeDurations(multiplier).
const ANTICIPATION_MS = 150 * GLOBAL_SLOWDOWN
const LUNGE_MS = 100 * GLOBAL_SLOWDOWN
const STRIKE_RISE_MS = 140 * GLOBAL_SLOWDOWN
const STRIKE_LAND_MS = 140 * GLOBAL_SLOWDOWN
const RETURN_MS = 250 * GLOBAL_SLOWDOWN
const GAP_MS = 150 * GLOBAL_SLOWDOWN
const HEAL_DELAY_MS = 250 * GLOBAL_SLOWDOWN // le soin apparaît après les dégâts, pas en même temps (base, voir computeDurations)
// Durée d'affichage des textes flottants (MANQUÉ / tour passé) — doit rester
// synchronisée avec la durée de l'animation 'damage-number-pop' utilisée par
// AutoBattleFloatingText (voir src/index.css), sans quoi le texte disparaît
// (démontage du composant) avant la fin de l'animation CSS.
const FLYING_TEXT_MS = 1300 * GLOBAL_SLOWDOWN
// Temps d'affichage du dé avant de révéler le résultat d'un tick de statut
// (Sommeil/Brûlure, voir turn.status_tick) — 0 si le tick n'a pas de dé
// (Poison, ou paralysie/gel/peur/confusion qui n'en lancent jamais).
const STATUS_DICE_MS = 700 * GLOBAL_SLOWDOWN
// Secousse/flash au moment de l'impact — durée alignée avec les animations
// CSS 'hit-shake'/'hit-flash' déclenchées en même temps (voir plus bas).
const SHAKE_MS = 300 * GLOBAL_SLOWDOWN
const FLASH_MS = 220 * GLOBAL_SLOWDOWN

// Vitesse d'enchaînement d'une capacité utilisée plusieurs fois d'affilée
// par le même camp (play_twice/play_three/play_random/repeat_until_fail,
// voir autobattle_resolve_battle) : la 2e activation du bloc anime 1.33×
// plus vite, la 3e 1.66× plus vite, la 4e (et au-delà) 2× plus vite —
// plafonné à 2×, sinon les blocs à répétitions élevées deviendraient
// illisibles. 'skip' n'est jamais concerné : son propre tour "passé" repasse
// toujours par l'autre camp avant de revenir (voir la RPC), donc il n'est
// jamais adjacent à un autre tour du même attaquant dans ce journal.
const MAX_SPEED_MULTIPLIER = 2
const SPEED_STEP = 1 / 3
function speedMultiplierForRepeat(repeatIndex: number): number {
  return Math.min(MAX_SPEED_MULTIPLIER, 1 + (repeatIndex - 1) * SPEED_STEP)
}

interface PhaseDurations { anticipation: number; lunge: number; strikeRise: number; strikeLand: number; return: number; gap: number; healDelay: number }
function computeDurations(multiplier: number): PhaseDurations {
  return {
    anticipation: ANTICIPATION_MS / multiplier,
    lunge: LUNGE_MS / multiplier,
    strikeRise: STRIKE_RISE_MS / multiplier,
    strikeLand: STRIKE_LAND_MS / multiplier,
    return: RETURN_MS / multiplier,
    gap: GAP_MS / multiplier,
    healDelay: HEAL_DELAY_MS / multiplier,
  }
}

type AttackPhase = 'anticipation' | 'lunge' | 'strike-rise' | 'strike-land' | 'return'
interface AttackState { side: 'player' | 'opponent'; phase: AttackPhase; durations: PhaseDurations }
type Side = 'player' | 'opponent'

// Style de transform du pokémon attaquant selon la phase en cours, combinant
// les axes X (avance vers l'adversaire) et Y (arc de saut) : petit recul
// (anticipation), petit bond en avant (lunge), grand saut qui monte haut en
// couvrant l'essentiel de la distance (strike-rise), puis retombe tout près
// de/sur l'adversaire (strike-land — c'est à la fin de cette phase que les
// dégâts sont appliqués, "quand le pokémon atteint la cible"), puis retour à
// la position de départ (return). Sur un tour raté, seules 'anticipation'
// puis 'return' sont jouées (petit mouvement sur place, jamais de saut).
// `sign` vaut +1 pour le joueur (avance vers la droite, l'adversaire) et -1
// pour l'adversaire (avance vers la gauche). `durations` vient du tour en
// cours (voir speedMultiplierForRepeat) : accéléré si ce tour fait partie
// d'un bloc multi-attaques.
function attackTransform(phase: AttackPhase, sign: 1 | -1, durations: PhaseDurations): React.CSSProperties {
  switch (phase) {
    case 'anticipation':
      return { transform: `translate(${sign * -8}px, 4px) scale(0.95)`, transition: `transform ${durations.anticipation}ms ease-out` }
    case 'lunge':
      return { transform: `translate(${sign * 20}px, -10px) scale(1.04)`, transition: `transform ${durations.lunge}ms ease-in` }
    case 'strike-rise':
      return { transform: `translate(${sign * 120}px, -55px) scale(1.1)`, transition: `transform ${durations.strikeRise}ms ease-out` }
    case 'strike-land':
      return { transform: `translate(${sign * 175}px, -6px) scale(1.2)`, transition: `transform ${durations.strikeLand}ms ease-in` }
    case 'return':
      return { transform: 'translate(0, 0) scale(1)', transition: `transform ${durations.return}ms ease-out` }
  }
}

// Filtre coloré "même sprite, teinté, avec transparence" pour matérialiser un
// statut actif : un calque de la couleur du statut, découpé à la silhouette
// du sprite via mask-image (le sprite lui-même sert de masque — transparent
// en dehors du dessin, opaque dessus), posé par-dessus l'image d'origine.
function statusOverlayStyle(status: AutoBattleStatusEffect, spriteUrl: string): CSSProperties {
  const maskProps = {
    WebkitMaskImage: `url(${spriteUrl})`,
    maskImage: `url(${spriteUrl})`,
    WebkitMaskSize: 'contain',
    maskSize: 'contain',
    WebkitMaskRepeat: 'no-repeat',
    maskRepeat: 'no-repeat',
    WebkitMaskPosition: 'center',
    maskPosition: 'center',
  }
  return {
    backgroundColor: getStatusEffectDisplay(status).color,
    opacity: 0.55,
    ...maskProps,
  } as CSSProperties
}

// Rejoue le journal de tours renvoyé par le RPC autobattle_resolve_battle
// (jamais recalculé côté client, voir requirement #37) : joueur à gauche,
// adversaire à droite. Chaque tour joue une petite séquence d'attaque
// (anticipation → bond → grand saut sur l'adversaire → retour), les dégâts
// n'étant appliqués (flash rouge + secousse + nombre flottant) qu'au moment
// de l'impact plutôt qu'au début du tour. Un tour raté (précision) affiche
// "MANQUÉ" et ne joue qu'un petit mouvement sur place ; un tour passé (effet
// spécial) affiche un texte dédié sans aucune animation d'attaque ; un soin
// (effet spécial) affiche des bulles vertes + le montant sur l'attaquant
// lui-même, après les dégâts. Les deux pokémon sont déjà visibles (pièce
// jouée) pendant le compte à rebours 3-2-1-GO avant le premier coup. Une
// fois le combat terminé, reste affiché avec un bouton "Continuer" plutôt
// que d'enchaîner automatiquement sur les récompenses/l'écran de défaite.
export function AutoBattleScreen({
  playerPokemon, playerSpecies, playerMaxHp, playerAbilityNom, playerImageOverride, opponentSpecies, opponentMaxHp, opponentNom, opponentAbilityNom, opponentImageOverride, turns,
  playerTypeBonus, opponentTypeBonus, onContinue,
}: Props) {
  const [countdownStep, setCountdownStep] = useState(-1)
  const [fighting, setFighting] = useState(false)
  const [playerHp, setPlayerHp] = useState(playerMaxHp)
  const [opponentHp, setOpponentHp] = useState(opponentMaxHp)
  const [shownTurnIndex, setShownTurnIndex] = useState(-1)
  const [attackState, setAttackState] = useState<AttackState | null>(null)
  const [shakeSide, setShakeSide] = useState<Side | null>(null)
  const [flashSide, setFlashSide] = useState<Side | null>(null)
  const [hitKey, setHitKey] = useState(0)
  const [lastDamage, setLastDamage] = useState<{ side: Side; damage: number; superEffective: boolean; color?: string } | null>(null)
  const [missSide, setMissSide] = useState<Side | null>(null)
  const [missKey, setMissKey] = useState(0)
  const [missLabel, setMissLabel] = useState('MANQUÉ')
  const [skipSide, setSkipSide] = useState<Side | null>(null)
  const [skipKey, setSkipKey] = useState(0)
  const [skipLabel, setSkipLabel] = useState('Tour passé !')
  const [recoilFx, setRecoilFx] = useState<{ side: Side; amount: number } | null>(null)
  const [recoilKey, setRecoilKey] = useState(0)
  const [playerInvulnerable, setPlayerInvulnerable] = useState(false)
  const [opponentInvulnerable, setOpponentInvulnerable] = useState(false)
  const [playerStatus, setPlayerStatus] = useState<AutoBattleStatusEffect | null>(null)
  const [opponentStatus, setOpponentStatus] = useState<AutoBattleStatusEffect | null>(null)
  const [diceRoll, setDiceRoll] = useState<{ side: Side; value: number } | null>(null)
  const [diceKey, setDiceKey] = useState(0)
  const [healSide, setHealSide] = useState<Side | null>(null)
  const [healKey, setHealKey] = useState(0)
  const [lastHeal, setLastHeal] = useState<{ side: Side; amount: number } | null>(null)
  const [battleDone, setBattleDone] = useState(turns.length === 0)
  // Historique du combat (requirement : liste locale, jamais persistée en
  // base — voir AutoBattleHistoryLog) : construit en direct pendant la
  // relecture des tours, pas dérivé de `turns` a posteriori, pour que
  // l'horodatage de chaque entrée reflète le moment réel où l'évènement est
  // révélé à l'écran plutôt qu'un timestamp serveur inexistant ici.
  const [historyEntries, setHistoryEntries] = useState<AutoBattleHistoryEntryData[]>([])
  const [historyOpen, setHistoryOpen] = useState(true)
  const historyIdRef = useRef(0)

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
    let cursor = 0
    let streak = 0
    let prevStreakAttacker: Side | null = null
    const battleStart = Date.now()
    // Suivi local du bouclier d'invulnérabilité — expire au tout début du
    // tour adverse suivant, que ce tour soit une vraie attaque ou non (voir
    // autobattle_resolve_battle) : même règle appliquée ici côté client,
    // sans dépendre d'un champ serveur dédié, pour rester synchronisé même
    // quand le bouclier expire "silencieusement" (préparation/tour passé/
    // tick de statut adverse) plutôt que via un raté explicite.
    let playerShieldActive = false
    let opponentShieldActive = false

    // Nom/icône/capacité affichés dans l'historique pour un côté donné — voir
    // AutoBattleHistoryLog (la bordure colorée de la carte suffit à distinguer
    // les deux camps, pas besoin d'un suffixe sur le nom).
    const sideInfo = (side: Side) => side === 'player'
      ? { name: ownedPokemonName(playerPokemon), iconSrc: playerImageOverride ?? playerSpecies?.image_miniature, ability: playerAbilityNom }
      : { name: opponentNom, iconSrc: opponentImageOverride ?? opponentSpecies?.image_miniature, ability: opponentAbilityNom }

    const pushHistory = (
      side: Side,
      content: string | { before: string; status: AutoBattleStatusEffect; after: string },
      extra?: { damage?: number; heal?: number; superEffective?: boolean }
    ) => {
      const info = sideInfo(side)
      historyIdRef.current += 1
      const entry: AutoBattleHistoryEntryData = {
        id: historyIdRef.current, elapsedMs: Date.now() - battleStart, side, pokemonName: info.name, iconSrc: info.iconSrc,
        text: typeof content === 'string' ? content : undefined,
        statusText: typeof content === 'string' ? undefined : (() => {
          const display = getStatusEffectDisplay(content.status)
          return { before: content.before, statusLabel: display.label, statusColor: display.color, after: content.after }
        })(),
        damage: extra?.damage && extra.damage > 0 ? extra.damage : undefined,
        heal: extra?.heal && extra.heal > 0 ? extra.heal : undefined,
        superEffective: extra?.superEffective,
      }
      setHistoryEntries((prev) => [entry, ...prev])
    }

    turns.forEach((turn, i) => {
      const turnStart = cursor
      const attackerSide = turn.attacker
      const hitSide: Side = attackerSide === 'player' ? 'opponent' : 'player'

      // Le bouclier d'invulnérabilité expire EXACTEMENT 1 tour après avoir
      // été accordé, point — quel que soit le type de ce tour suivant et quel
      // que soit son attaquant (voir autobattle_resolve_battle : ce n'est
      // plus conditionné à "l'adversaire attaque", une rafale du même camp
      // qui l'a accordé le retire tout aussi bien). granted ci-dessous est
      // affecté à la fin de CETTE itération : ce test porte donc toujours sur
      // un bouclier accordé lors d'une itération précédente.
      if (playerShieldActive) {
        playerShieldActive = false
        timers.push(window.setTimeout(() => setPlayerInvulnerable(false), turnStart))
      }
      if (opponentShieldActive) {
        opponentShieldActive = false
        timers.push(window.setTimeout(() => setOpponentInvulnerable(false), turnStart))
      }
      // Le suivi local (synchrone, pendant la programmation des timers) doit
      // être mis à jour ICI plutôt que dans les callbacks différés
      // (setTimeout) ci-dessous : ce .forEach programme TOUS les tours d'un
      // coup avant qu'aucune animation ne joue réellement, donc une
      // affectation faite dans un callback différé ne serait jamais visible
      // par les itérations suivantes de cette même boucle synchrone.
      if (turn.invulnerable_granted) {
        if (attackerSide === 'player') playerShieldActive = true
        else opponentShieldActive = true
      }

      // Position (1-based) de ce tour dans son bloc d'attaques consécutives
      // du même camp — voir speedMultiplierForRepeat ci-dessus. 'skipped' et
      // 'status_tick' n'appartiennent jamais à un tel bloc, cassent toujours
      // la série (un tick de statut n'est pas "réutiliser la capacité").
      if (turn.skipped || turn.status_tick) {
        streak = 0
        prevStreakAttacker = null
      } else {
        streak = attackerSide === prevStreakAttacker ? streak + 1 : 1
        prevStreakAttacker = attackerSide
      }
      const multiplier = (turn.skipped || turn.status_tick) ? 1 : speedMultiplierForRepeat(streak)
      const durations = computeDurations(multiplier)
      const impactOffset = durations.anticipation + durations.lunge + durations.strikeRise + durations.strikeLand
      const turnDuration = impactOffset + durations.return + durations.gap

      // Tick de statut (paralysie/gel/peur/confusion/sommeil/brûlure/poison,
      // voir autobattle_resolve_battle) : dé lancé en tout premier s'il y en
      // a un (Sommeil/Brûlure), puis dégâts passifs (Brûlure/Poison) et/ou
      // passage du tour (paralysie/gel/sommeil raté) révélés une fois le dé
      // retombé — toujours sur turn.attacker, le camp affecté par son propre
      // statut (jamais l'adversaire).
      if (turn.status_tick) {
        const status = turn.status
        const hasDice = turn.status_roll != null
        const revealAt = turnStart + durations.anticipation + (hasDice ? STATUS_DICE_MS : 0)
        if (hasDice) {
          timers.push(window.setTimeout(() => {
            setDiceRoll({ side: attackerSide, value: turn.status_roll! })
            setDiceKey((k) => k + 1)
          }, turnStart + durations.anticipation))
        }
        timers.push(window.setTimeout(() => {
          setShownTurnIndex(i)
          if (turn.damage > 0 && turn.attacker_hp_after != null) {
            const hpAfter = turn.attacker_hp_after
            if (attackerSide === 'player') setPlayerHp(hpAfter)
            else setOpponentHp(hpAfter)
            setShakeSide(attackerSide)
            setFlashSide(attackerSide)
            setLastDamage({ side: attackerSide, damage: turn.damage, superEffective: false, color: status ? getStatusEffectDisplay(status).color : undefined })
            setHitKey((k) => k + 1)
            window.setTimeout(() => setShakeSide(null), SHAKE_MS)
            window.setTimeout(() => setFlashSide(null), FLASH_MS)
          }
          if (turn.status_cured) {
            if (attackerSide === 'player') setPlayerStatus(null)
            else setOpponentStatus(null)
          }
          if (status) {
            if (turn.skipped) {
              pushHistory(attackerSide, { before: 'ne peut pas agir (', status, after: ')' }, { damage: turn.damage })
            } else if (turn.status_cured) {
              if (status === 'sleep') pushHistory(attackerSide, 'se réveille !', { damage: turn.damage })
              else pushHistory(attackerSide, { before: "n'est plus affecté par ", status, after: '' }, { damage: turn.damage })
            } else {
              pushHistory(attackerSide, { before: 'souffre de ', status, after: '' }, { damage: turn.damage })
            }
          }
          if (turn.skipped && status) {
            setSkipSide(attackerSide)
            setSkipLabel(STATUS_SKIP_LABEL[status] ?? 'Tour passé !')
            setSkipKey((k) => k + 1)
          }
        }, revealAt))
        if (turn.skipped) {
          timers.push(window.setTimeout(() => setSkipSide(null), revealAt + FLYING_TEXT_MS))
        }
        cursor += turnDuration
        return
      }

      if (turn.skipped) {
        timers.push(window.setTimeout(() => {
          setShownTurnIndex(i)
          setSkipSide(attackerSide)
          setSkipLabel(turn.preparing ? 'Préparation' : 'Tour passé !')
          setSkipKey((k) => k + 1)
          pushHistory(attackerSide, turn.preparing ? `se prépare à attaquer avec ${sideInfo(attackerSide).ability}` : 'passe son tour')
          // Invulnérabilité accordée dès la préparation (prepare_release +
          // invulnerable_next_turn combinés, voir autobattle_resolve_battle) —
          // protège le tour adverse qui suit immédiatement, pas celui après
          // la libération.
          if (turn.invulnerable_granted) {
            if (attackerSide === 'player') setPlayerInvulnerable(true)
            else setOpponentInvulnerable(true)
          }
        }, turnStart + durations.anticipation))
        timers.push(window.setTimeout(() => setSkipSide(null), turnStart + durations.anticipation + FLYING_TEXT_MS))
        cursor += turnDuration
        return
      }

      timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'anticipation', durations }), turnStart))
      if (!turn.missed) {
        timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'lunge', durations }), turnStart + durations.anticipation))
        timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'strike-rise', durations }), turnStart + durations.anticipation + durations.lunge))
        timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'strike-land', durations }), turnStart + durations.anticipation + durations.lunge + durations.strikeRise))
      }

      const isSuperEffective = attackerSide === 'player' ? playerTypeBonus : opponentTypeBonus
      timers.push(window.setTimeout(() => {
        setShownTurnIndex(i)
        setAttackState({ side: attackerSide, phase: 'return', durations })

        if (turn.missed) {
          setMissSide(attackerSide)
          setMissLabel(turn.invulnerable_miss ? 'Invulnérable !' : 'MANQUÉ')
          setMissKey((k) => k + 1)
          if (turn.invulnerable_miss) {
            // Le bouclier protège le CAMP VISÉ par cette attaque, pas
            // l'attaquant lui-même (hitSide = celui qui vient d'esquiver).
            if (hitSide === 'player') setPlayerInvulnerable(false)
            else setOpponentInvulnerable(false)
          }
          pushHistory(attackerSide, `a manqué son attaque ${sideInfo(attackerSide).ability}`)
          window.setTimeout(() => setMissSide(null), FLYING_TEXT_MS)
          return
        }

        if (hitSide === 'player') setPlayerHp(turn.defender_hp_after)
        else setOpponentHp(turn.defender_hp_after)
        setShakeSide(hitSide)
        setFlashSide(hitSide)
        setLastDamage({ side: hitSide, damage: turn.damage, superEffective: isSuperEffective })
        setHitKey((k) => k + 1)
        window.setTimeout(() => setShakeSide(null), SHAKE_MS)
        window.setTimeout(() => setFlashSide(null), FLASH_MS)
        pushHistory(attackerSide, `a utilisé ${sideInfo(attackerSide).ability}`, { damage: turn.damage, heal: turn.heal, superEffective: isSuperEffective })

        if (turn.heal != null && turn.attacker_hp_after != null) {
          const healAmount = turn.heal
          const attackerHpAfter = turn.attacker_hp_after
          window.setTimeout(() => {
            if (attackerSide === 'player') setPlayerHp(attackerHpAfter)
            else setOpponentHp(attackerHpAfter)
            setHealSide(attackerSide)
            setLastHeal({ side: attackerSide, amount: healAmount })
            setHealKey((k) => k + 1)
            if (turn.status_cured_by_heal) {
              if (attackerSide === 'player') setPlayerStatus(null)
              else setOpponentStatus(null)
            }
          }, durations.healDelay)
        }

        // Coup réussi ayant infligé un statut — à l'adversaire (hitSide)
        // normalement, à l'attaquant lui-même si status_applied_reversed
        // (voir autobattle_ability_rules.status_reversed).
        if (turn.status_applied) {
          const statusTarget = turn.status_applied_reversed ? attackerSide : hitSide
          if (statusTarget === 'player') setPlayerStatus(turn.status_applied)
          else setOpponentStatus(turn.status_applied)
          pushHistory(statusTarget, { before: 'est affecté par ', status: turn.status_applied, after: '' })
        }

        // Invulnérabilité accordée par ce coup à son auteur (voir
        // autobattle_ability_rules.invulnerable_next_turn) — silencieux ici,
        // le bouclier ne se révèle que quand il rate l'attaque adverse
        // suivante (turn.invulnerable_miss ci-dessus).
        if (turn.invulnerable_granted) {
          if (attackerSide === 'player') setPlayerInvulnerable(true)
          else setOpponentInvulnerable(true)
        }

        // Contre-coup : dégâts self-inflicted sur l'attaquant, après le
        // reste — attacker_hp_after reflète l'état final (soin ET
        // contre-coup combinés si les deux sont configurés sur la même
        // capacité, voir autobattle_resolve_battle).
        if (turn.recoil != null && turn.attacker_hp_after != null) {
          const recoilAmount = turn.recoil
          const attackerHpAfter = turn.attacker_hp_after
          window.setTimeout(() => {
            if (attackerSide === 'player') setPlayerHp(attackerHpAfter)
            else setOpponentHp(attackerHpAfter)
            setRecoilFx({ side: attackerSide, amount: recoilAmount })
            setRecoilKey((k) => k + 1)
          }, durations.healDelay)
        }
      }, turnStart + impactOffset))
      timers.push(window.setTimeout(() => setAttackState(null), turnStart + impactOffset + durations.return))
      cursor += turnDuration
    })
    timers.push(window.setTimeout(() => setBattleDone(true), cursor + 200))
    return () => timers.forEach(clearTimeout)
    // eslint-disable-next-line react-hooks/exhaustive-deps -- ne doit démarrer qu'une fois fighting passe à true (turns figé pour ce combat)
  }, [fighting])

  const playerKo = shownTurnIndex >= 0 && playerHp <= 0
  const opponentKo = shownTurnIndex >= 0 && opponentHp <= 0
  // Cas Métamorph : sprite de l'adversaire copié pour ce combat (voir
  // autobattle_resolve_battle) — remplace le sprite réel de Métamorph
  // partout où il est affiché sur cet écran.
  const playerSpriteSrc = playerImageOverride ?? playerSpecies?.image_miniature
  // Cas Métamorph configuré comme adversaire (voir autobattle_resolve_battle)
  // — même principe symétrique que playerSpriteSrc.
  const opponentSpriteSrc = opponentImageOverride ?? opponentSpecies?.image_miniature

  const playerAttackStyle = attackState?.side === 'player' ? attackTransform(attackState.phase, 1, attackState.durations) : undefined
  const opponentAttackStyle = attackState?.side === 'opponent' ? attackTransform(attackState.phase, -1, attackState.durations) : undefined

  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col items-center gap-2">
          <p className="text-ink text-base font-bold flex items-center justify-center gap-1.5 max-w-full">
            <span className="truncate">{ownedPokemonName(playerPokemon)}</span>
            {playerStatus && (() => {
              const statusDisplay = getStatusEffectDisplay(playerStatus)
              return (
                <span
                  className="flex items-center gap-1 text-[10px] font-bold px-1.5 py-0.5 rounded-full text-white shrink-0"
                  style={{ backgroundColor: statusDisplay.color }}
                >
                  <PixelIcon src={statusDisplay.iconSrc} size={12} colored />
                  {statusDisplay.label}
                </span>
              )
            })()}
            {playerInvulnerable && <span className="text-xs shrink-0" title="Invulnérable au prochain coup adverse">🛡️</span>}
          </p>
          <div
            className="relative w-24 h-24 flex items-center justify-center"
            style={{ ...playerAttackStyle, animation: shakeSide === 'player' ? `hit-shake ${SHAKE_MS}ms ease-in-out` : undefined }}
          >
            {playerSpriteSrc ? (
              <img
                src={playerSpriteSrc}
                alt=""
                className={`pixelated w-full h-full object-contain transition-opacity duration-500 ${playerKo ? 'grayscale opacity-40' : playerInvulnerable ? 'opacity-10' : ''}`}
              />
            ) : (
              <span className="text-4xl">?</span>
            )}
            {playerStatus && playerSpriteSrc && (
              <div className="absolute inset-0 pointer-events-none" style={statusOverlayStyle(playerStatus, playerSpriteSrc)} />
            )}
            {flashSide === 'player' && (
              <div className="absolute inset-0 bg-hp-red rounded-full pointer-events-none" style={{ animation: `hit-flash ${FLASH_MS}ms ease-out` }} />
            )}
            {lastDamage?.side === 'player' && (
              <AutoBattleDamageNumber damage={lastDamage.damage} animKey={hitKey} superEffective={lastDamage.superEffective} color={lastDamage.color} />
            )}
            {recoilFx?.side === 'player' && (
              <AutoBattleDamageNumber damage={recoilFx.amount} animKey={recoilKey} color="#dc2626" />
            )}
            {missSide === 'player' && (
              <AutoBattleFloatingText text={missLabel} animKey={missKey} className="text-ink-muted-2" />
            )}
            {skipSide === 'player' && (
              <AutoBattleFloatingText text={skipLabel} animKey={skipKey} className="text-white" />
            )}
            {healSide === 'player' && lastHeal?.side === 'player' && (
              <AutoBattleHealEffect amount={lastHeal.amount} animKey={healKey} />
            )}
            {diceRoll?.side === 'player' && (
              <AutoBattleDiceRoll value={diceRoll.value} animKey={diceKey} />
            )}
          </div>
          <div className="w-full max-w-[160px]">
            <HpGauge current={Math.max(0, playerHp)} max={playerMaxHp} />
          </div>
        </div>

        <div className="flex flex-col items-center gap-2">
          <p className="text-ink text-base font-bold flex items-center justify-center gap-1.5 max-w-full">
            <span className="truncate">{opponentNom}</span>
            {opponentStatus && (() => {
              const statusDisplay = getStatusEffectDisplay(opponentStatus)
              return (
                <span
                  className="flex items-center gap-1 text-[10px] font-bold px-1.5 py-0.5 rounded-full text-white shrink-0"
                  style={{ backgroundColor: statusDisplay.color }}
                >
                  <PixelIcon src={statusDisplay.iconSrc} size={12} colored />
                  {statusDisplay.label}
                </span>
              )
            })()}
            {opponentInvulnerable && <span className="text-xs shrink-0" title="Invulnérable au prochain coup adverse">🛡️</span>}
          </p>
          <div
            className="relative w-24 h-24 flex items-center justify-center"
            style={{ ...opponentAttackStyle, animation: shakeSide === 'opponent' ? `hit-shake ${SHAKE_MS}ms ease-in-out` : undefined }}
          >
            {opponentSpriteSrc ? (
              <img
                src={opponentSpriteSrc}
                alt=""
                className={`pixelated w-full h-full object-contain transition-opacity duration-500 ${opponentKo ? 'grayscale opacity-40' : opponentInvulnerable ? 'opacity-10' : ''}`}
              />
            ) : (
              <span className="text-4xl">?</span>
            )}
            {opponentStatus && opponentSpriteSrc && (
              <div className="absolute inset-0 pointer-events-none" style={statusOverlayStyle(opponentStatus, opponentSpriteSrc)} />
            )}
            {flashSide === 'opponent' && (
              <div className="absolute inset-0 bg-hp-red rounded-full pointer-events-none" style={{ animation: `hit-flash ${FLASH_MS}ms ease-out` }} />
            )}
            {lastDamage?.side === 'opponent' && (
              <AutoBattleDamageNumber damage={lastDamage.damage} animKey={hitKey} superEffective={lastDamage.superEffective} color={lastDamage.color} />
            )}
            {recoilFx?.side === 'opponent' && (
              <AutoBattleDamageNumber damage={recoilFx.amount} animKey={recoilKey} color="#dc2626" />
            )}
            {missSide === 'opponent' && (
              <AutoBattleFloatingText text={missLabel} animKey={missKey} className="text-ink-muted-2" />
            )}
            {skipSide === 'opponent' && (
              <AutoBattleFloatingText text={skipLabel} animKey={skipKey} className="text-white" />
            )}
            {healSide === 'opponent' && lastHeal?.side === 'opponent' && (
              <AutoBattleHealEffect amount={lastHeal.amount} animKey={healKey} />
            )}
            {diceRoll?.side === 'opponent' && (
              <AutoBattleDiceRoll value={diceRoll.value} animKey={diceKey} />
            )}
          </div>
          <div className="w-full max-w-[160px]">
            <HpGauge current={Math.max(0, opponentHp)} max={opponentMaxHp} />
          </div>
        </div>
      </div>

      {!fighting && countdownStep >= 0 && (
        <div key={countdownStep} className="text-center text-ink text-4xl font-bold animate-[celebrate-pop_0.52s_ease-out]">
          {COUNTDOWN_STEPS[countdownStep]}
        </div>
      )}

      {(playerKo || opponentKo) && (
        <p className="text-center text-hp-red text-xl font-bold animate-[celebrate-pop_0.52s_ease-out]">K.O. !</p>
      )}

      {battleDone && (
        <div className="flex items-center justify-center gap-2 mt-1">
          <button
            onClick={onContinue}
            className={`px-6 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.yellow}`}
          >
            Continuer
          </button>
          {!historyOpen && (
            <button
              onClick={() => setHistoryOpen(true)}
              className={`px-4 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.gray}`}
            >
              Voir l'historique
            </button>
          )}
        </div>
      )}

      {fighting && historyOpen && (
        <AutoBattleHistoryLog
          entries={historyEntries}
          onHide={() => setHistoryOpen(false)}
        />
      )}
    </div>
  )
}
