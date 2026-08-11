import { useEffect, useRef, useState } from 'react'
import type { CSSProperties, ReactNode } from 'react'
import type { Pokemon, PlayerPokemon, AutoBattleStatusEffect, Attack, AutoBattleAbilityRule } from '../../types'
import { ownedPokemonName } from '../../types'
import { HpGauge } from '../HpGauge'
import { AutoBattleDamageNumber } from './AutoBattleDamageNumber'
import { AutoBattleFloatingText } from './AutoBattleFloatingText'
import { AutoBattleHealEffect } from './AutoBattleHealEffect'
import { AutoBattleDiceRoll } from './AutoBattleDiceRoll'
import { AutoBattleHistoryLog, type AutoBattleHistoryEntryData } from './AutoBattleHistoryLog'
import { getStatusEffectDisplay, STATUS_EFFECT_LABEL } from '../../lib/autoBattle'
import { PixelIcon } from '../icons/PixelIcon'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import type { AutoBattleTurn } from '../../types'

// Libellé du texte flottant affiché quand un statut fait passer le tour
// (paralysie/gel = une fois ; sommeil/confusion = tant que le dé ne tombe
// pas sur 4/5/6) — 'fear'/'burn'/'poison' ne passent jamais le tour donc
// n'ont pas d'entrée ici (voir AutoBattleTurn.status_tick côté serveur).
// Confusion ne SAUTE PAS le tour (contrairement à sommeil) : elle réduit
// juste la précision de l'attaque qui suit immédiatement, d'où son absence
// ici malgré le tirage de dé — voir status_tick plus bas.
const STATUS_SKIP_LABEL: Partial<Record<AutoBattleStatusEffect, string>> = {
  paralysis: 'Paralysé !',
  frozen: 'Gelé !',
  sleep: 'Endormi...',
}

// Pénalité de précision appliquée par confusion/peur — doit rester
// synchronisée avec v_status_precision_penalty côté serveur (voir
// autobattle_resolve_battle : les deux valent désormais 5), jamais redéfinie
// arbitrairement ici : ces valeurs sont un pur affichage de debug admin, le
// résultat réel (touché/raté) est toujours décidé par le serveur.
const PRECISION_MODIFIER_BY_STATUS: Partial<Record<AutoBattleStatusEffect, number>> = {
  confusion: -5,
  fear: -5,
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
  isAdmin?: boolean
  attacksByName?: Map<string, Attack>
  /** Style d'animation par capacité (voir autobattle_ability_rules.animation_style, réglable en admin) — 'soft' fait rester le pokémon sur place au lieu de bondir sur l'adversaire, voir attackTransform. */
  abilityRulesByName?: Map<string, AutoBattleAbilityRule>
  /** Dégâts par coup AVANT dé (espèce + bonus XP + multiplicateur type + dégâts de base de la capacité), voir autobattle_resolve_battle v_player_damage — sert à isoler la valeur du dé en debug admin (turn.damage - ce total). */
  playerDamagePerHit?: number
  /** Idem côté adversaire (v_opponent_damage). */
  opponentDamagePerHit?: number
  /** Combat Manuel (ManualBattleScreen) : `turns` grandit au fil des tours (un seul appel RPC par tour, voir autobattle_resolve_manual_round) plutôt que d'arriver résolu d'un bloc — l'effet de programmation des animations devient alors incrémental (ne rejoue jamais les tours déjà animés), voir le useEffect principal ci-dessous. Sans effet en Combat Auto (turns fixe pour tout le combat, comme avant). */
  /** Masque le bouton "Continuer" et appelle onContinue automatiquement dès que l'animation des tours actuellement disponibles est terminée (Combat Manuel : signale à ManualBattleScreen qu'il peut redonner la main au joueur, ou transitionner vers récompense/défaite si l'issue est connue). */
  hideContinueButton?: boolean
  /** Contenu injecté entre le visuel de combat et l'historique (Combat Manuel : la grille de sélection de capacité, voir requirement). */
  midSlot?: ReactNode
  /** Combat Manuel : pas de compte à rebours 3-2-1-GO, le combat "commence" dès le montage (voir useEffect du countdown). */
  skipCountdown?: boolean
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
interface AttackState { side: 'player' | 'opponent'; phase: AttackPhase; durations: PhaseDurations; soft: boolean }
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
// d'un bloc multi-attaques. `soft` (voir autobattle_ability_rules.
// animation_style) : le pokémon reste sur place — juste un léger
// grossissement/rétrécissement sur place (aucun `translate`) — au lieu du
// bond vers l'adversaire, pour les capacités où ça a plus de sens
// visuellement (soin/buff sur soi…).
function attackTransform(phase: AttackPhase, sign: 1 | -1, durations: PhaseDurations, soft: boolean): React.CSSProperties {
  if (soft) {
    switch (phase) {
      case 'anticipation':
        return { transform: 'scale(0.97)', transition: `transform ${durations.anticipation}ms ease-out` }
      case 'lunge':
        return { transform: 'scale(1.05)', transition: `transform ${durations.lunge}ms ease-in` }
      case 'strike-rise':
        return { transform: 'scale(1.12)', transition: `transform ${durations.strikeRise}ms ease-out` }
      case 'strike-land':
        return { transform: 'scale(1.16)', transition: `transform ${durations.strikeLand}ms ease-in` }
      case 'return':
        return { transform: 'scale(1)', transition: `transform ${durations.return}ms ease-out` }
    }
  }
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
  playerTypeBonus, opponentTypeBonus, onContinue, isAdmin = false, attacksByName, abilityRulesByName, playerDamagePerHit, opponentDamagePerHit,
  hideContinueButton = false, midSlot, skipCountdown = false,
}: Props) {
  const [countdownStep, setCountdownStep] = useState(-1)
  const [fighting, setFighting] = useState(skipCountdown)
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
  // Suivi persistant entre deux exécutions de l'effet de programmation
  // ci-dessous — nécessaire uniquement pour le Combat Manuel (`turns`
  // grandit au fil des tours, voir ManualBattleScreen) : sans ces refs,
  // chaque nouvelle exécution repartirait de zéro et rejouerait tout le
  // combat depuis le début à chaque tour. En Combat Auto, `turns` ne change
  // jamais après le montage donc l'effet ne s'exécute qu'une fois et ces
  // refs restent à leur valeur initiale — comportement strictement
  // identique à avant.
  const scheduledCountRef = useRef(0)
  const streakRef = useRef(0)
  const prevStreakAttackerRef = useRef<Side | null>(null)
  const battleStartRef = useRef<number | null>(null)
  const playerShieldActiveRef = useRef(false)
  const opponentShieldActiveRef = useRef(false)

  // Précision effective affichée en debug admin — reproduit EXACTEMENT
  // GREATEST(0, ability.precision - v_status_precision_penalty) côté
  // serveur (voir autobattle_resolve_battle), donc clampée à 0 seulement
  // (jamais un plancher artificiel à 1 : le serveur peut légitimement
  // amener la précision à 0, auquel cas l'attaque rate toujours).
  const getEffectivePrecision = (basePrecision: number, status: AutoBattleStatusEffect | null): { effective: number; modifier: number; statusLabel?: string } => {
    const modifier = status ? (PRECISION_MODIFIER_BY_STATUS[status] ?? 0) : 0
    const effective = Math.max(0, basePrecision + modifier)
    return { effective, modifier, statusLabel: status && modifier !== 0 ? STATUS_EFFECT_LABEL[status] : undefined }
  }

  // Compte à rebours 3…2…1…GO ! avant le premier coup, même idiome que
  // MagikarpGame — les deux pokémon sont déjà affichés pendant ce temps.
  // Combat Manuel (skipCountdown) : pas de compte à rebours, le joueur choisit
  // sa capacité à son rythme (voir midSlot) donc le combat "commence" dès que
  // possible sans mise en scène.
  useEffect(() => {
    if (skipCountdown) return
    const timers = COUNTDOWN_STEPS.map((_, i) =>
      window.setTimeout(() => setCountdownStep(i), i * COUNTDOWN_STEP_MS)
    )
    timers.push(window.setTimeout(() => setFighting(true), COUNTDOWN_STEPS.length * COUNTDOWN_STEP_MS))
    return () => timers.forEach(clearTimeout)
  }, [skipCountdown])

  useEffect(() => {
    if (!fighting) return
    // Rien de nouveau à programmer (Combat Manuel : l'effet se redéclenche à
    // chaque tour car `turns` grandit, voir dépendances plus bas, mais rien
    // à faire tant qu'aucun nouveau tour n'est arrivé depuis la dernière
    // exécution).
    if (scheduledCountRef.current >= turns.length) return
    const timers: number[] = []
    // TOUJOURS à 0 en début d'exécution, contrairement à streak/prevStreak-
    // Attacker/shields ci-dessous : window.setTimeout(fn, délai) est relatif
    // au moment où il est programmé ("maintenant"), pas à un instant fixe
    // depuis le début du combat — cursor n'a donc de sens QUE dans le
    // référentiel de CETTE exécution de l'effet. Le report d'une exécution à
    // l'autre (comme pour les autres refs) décalerait chaque nouveau lot de
    // tours (Combat Manuel) d'un délai supplémentaire égal à la durée totale
    // déjà écoulée des tours précédents, cumulatif à chaque tour — c'est
    // très exactement le bug corrigé ici (le combat semblait mettre de plus
    // en plus de temps à démarrer après chaque sélection de capacité).
    let cursor = 0
    let streak = streakRef.current
    let prevStreakAttacker: Side | null = prevStreakAttackerRef.current
    if (battleStartRef.current == null) battleStartRef.current = Date.now()
    const battleStart = battleStartRef.current
    // Suivi local du bouclier d'invulnérabilité — expire au tout début du
    // tour adverse suivant, que ce tour soit une vraie attaque ou non (voir
    // autobattle_resolve_battle) : même règle appliquée ici côté client,
    // sans dépendre d'un champ serveur dédié, pour rester synchronisé même
    // quand le bouclier expire "silencieusement" (préparation/tour passé/
    // tick de statut adverse) plutôt que via un raté explicite.
    let playerShieldActive = playerShieldActiveRef.current
    let opponentShieldActive = opponentShieldActiveRef.current
    setBattleDone(false)

    // Nom/icône/capacité affichés dans l'historique pour un côté donné — voir
    // AutoBattleHistoryLog (la bordure colorée de la carte suffit à distinguer
    // les deux camps, pas besoin d'un suffixe sur le nom). Combat Manuel :
    // préfère turn.ability_nom (la capacité effectivement jouée CE tour-là,
    // voir ManualBattleScreen) aux props fixes playerAbilityNom/
    // opponentAbilityNom (qui ne valent que pour tout le combat en Auto).
    const sideInfo = (side: Side, turn?: AutoBattleTurn) => side === 'player'
      ? { name: ownedPokemonName(playerPokemon), iconSrc: playerImageOverride ?? playerSpecies?.image_miniature, ability: turn?.ability_nom ?? playerAbilityNom }
      : { name: opponentNom, iconSrc: opponentImageOverride ?? opponentSpecies?.image_miniature, ability: turn?.ability_nom ?? opponentAbilityNom }

    const pushHistory = (
      side: Side,
      content: string | { before: string; status: AutoBattleStatusEffect; after: string },
      extra?: { damage?: number; heal?: number; superEffective?: boolean; basePrecision?: number; effectivePrecision?: number; diceRoll?: number; precisionStatus?: string }
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
        debugBasePrecision: extra?.basePrecision,
        debugEffectivePrecision: extra?.effectivePrecision,
        debugDiceRoll: extra?.diceRoll,
        debugPrecisionStatus: extra?.precisionStatus,
      }
      setHistoryEntries((prev) => [entry, ...prev])
    }

    for (let i = scheduledCountRef.current; i < turns.length; i++) {
      const turn = turns[i]
      const turnStart = cursor
      const attackerSide = turn.attacker
      const hitSide: Side = attackerSide === 'player' ? 'opponent' : 'player'

      // Confusion/peur (voir autobattle_resolve_battle) : le serveur émet
      // TOUJOURS, pour le tour qui les subit, un tour 'status_tick'
      // IMMÉDIATEMENT SUIVI, sans jamais aucun tour d'un autre camp entre les
      // deux, du vrai tour d'attaque du même attaquant (voir v_status_
      // precision_penalty : posé au tick, consommé dans le v_missed du tour
      // suivant, jamais persisté au-delà). Donc turns[i-1] suffit à détecter
      // "cette attaque a été jouée sous confusion/peur" — jamais besoin de
      // suivre un état à travers plusieurs tours comme pour le bouclier.
      // Peur : status_cured TOUJOURS true sur ce tick (un seul coup, puis
      // guérie). Confusion : comme le sommeil, un dé décide si elle guérit
      // CETTE fois (status_roll/status_cured) — si elle ne guérit pas,
      // v_player_status/v_opponent_status reste 'confusion' pour les tours
      // suivants, mais l'attaque de CE tour-ci est de toute façon jouée sous
      // la pénalité de précision (elle n'est jamais sautée, contrairement au
      // sommeil).
      const precedingTick = i > 0 ? turns[i - 1] : undefined
      const attackerPrecisionStatus: AutoBattleStatusEffect | null =
        precedingTick?.status_tick && precedingTick.attacker === attackerSide
        && (precedingTick.status === 'confusion' || precedingTick.status === 'fear')
          ? precedingTick.status
          : null

      // Le bouclier d'invulnérabilité expire EXACTEMENT 1 tour après avoir
      // été accordé, point — quel que soit le type de ce tour suivant et quel
      // que soit son attaquant (voir autobattle_resolve_battle : ce n'est
      // plus conditionné à "l'adversaire attaque", une rafale du même camp
      // qui l'a accordé le retire tout aussi bien). granted ci-dessous est
      // affecté à la fin de CETTE itération : ce test porte donc toujours sur
      // un bouclier accordé lors d'une itération précédente. SAUF si ce tour
      // est justement l'attaque adverse bloquée par ce bouclier
      // (turn.invulnerable_miss) : dans ce cas, effacer l'effet visuel
      // "estompé" dès maintenant (avant même que l'animation de cette
      // attaque ne commence à jouer) donnerait l'impression que le bouclier
      // a disparu AVANT d'avoir bloqué quoi que ce soit — on laisse alors le
      // gestionnaire de raté plus bas (au moment de l'impact, quand
      // "Invulnérable !" s'affiche) s'en charger, pour que le pokémon reste
      // visuellement estompé jusqu'à cet instant précis.
      if (playerShieldActive) {
        playerShieldActive = false
        if (!(turn.attacker === 'opponent' && turn.invulnerable_miss)) {
          timers.push(window.setTimeout(() => setPlayerInvulnerable(false), turnStart))
        }
      }
      if (opponentShieldActive) {
        opponentShieldActive = false
        if (!(turn.attacker === 'player' && turn.invulnerable_miss)) {
          timers.push(window.setTimeout(() => setOpponentInvulnerable(false), turnStart))
        }
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
          // Peur/confusion : la pénalité de précision qu'il vient de révéler
          // s'applique encore à l'attaque de ce même camp qui suit
          // IMMÉDIATEMENT (jamais de tour adverse entre les deux), qu'elle
          // soit guérie ce tick-ci ou non — le badge visuel doit donc rester
          // affiché jusqu'à la résolution de cette attaque (voir
          // attackerPrecisionStatus, qui la détecte via turns[i-1] et efface
          // le badge une fois cette attaque résolue si status_cured), pas ici.
          if (turn.status_cured && status !== 'confusion' && status !== 'fear') {
            if (attackerSide === 'player') setPlayerStatus(null)
            else setOpponentStatus(null)
          }
          // Sommeil : le tick est TOUJOURS 'skipped' désormais, guéri ou non
          // (voir autobattle_resolve_battle — l'effet s'applique au moins une
          // fois, comme la brûlure) — donc vérifié EN PREMIER, avant le
          // branchement générique sur turn.skipped, pour que "se réveille !"
          // prenne le pas sur "ne peut pas agir".
          if (status) {
            if (status === 'sleep' && turn.status_cured) {
              pushHistory(attackerSide, 'se réveille !', { damage: turn.damage })
            } else if (turn.skipped) {
              pushHistory(attackerSide, { before: 'ne peut pas agir (', status, after: ')' }, { damage: turn.damage })
            } else if (status === 'fear') {
              pushHistory(attackerSide, { before: "agit sous l'effet de ", status, after: '' }, { damage: turn.damage })
            } else if (turn.status_cured) {
              pushHistory(attackerSide, { before: "n'est plus affecté par ", status, after: '' }, { damage: turn.damage })
            } else {
              pushHistory(attackerSide, { before: 'souffre de ', status, after: '' }, { damage: turn.damage })
            }
          }
          // Idem pour le texte flottant "Endormi..." : pas de sens de
          // l'afficher sur le tick où le pokémon se réveille (déjà annoncé
          // par l'historique ci-dessus).
          if (turn.skipped && status && !(status === 'sleep' && turn.status_cured)) {
            setSkipSide(attackerSide)
            setSkipLabel(STATUS_SKIP_LABEL[status] ?? 'Tour passé !')
            setSkipKey((k) => k + 1)
          }
        }, revealAt))
        if (turn.skipped) {
          timers.push(window.setTimeout(() => setSkipSide(null), revealAt + FLYING_TEXT_MS))
        }
        cursor += turnDuration
        continue
      }

      if (turn.skipped) {
        timers.push(window.setTimeout(() => {
          setShownTurnIndex(i)
          setSkipSide(attackerSide)
          setSkipLabel(turn.preparing ? 'Préparation' : 'Tour passé !')
          setSkipKey((k) => k + 1)
          pushHistory(attackerSide, turn.preparing ? `se prépare à attaquer avec ${sideInfo(attackerSide, turn).ability}` : 'passe son tour')
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
        continue
      }

      // Animation "douce" (voir autobattle_ability_rules.animation_style,
      // réglable en admin) : le pokémon reste sur place au lieu de bondir sur
      // l'adversaire — pensé pour les capacités auto-ciblées (soin, buff sur
      // soi…) où un lunge vers l'adversaire n'a pas de sens, mais applicable
      // à n'importe quelle capacité. N'affecte que le déplacement de
      // l'ATTAQUANT (voir attackTransform) — dégâts/tremblement/flash sur la
      // cible inchangés.
      const attackAbilityNom = turn.ability_nom ?? (attackerSide === 'player' ? playerAbilityNom : opponentAbilityNom)
      const isSoftAttack = abilityRulesByName?.get(attackAbilityNom)?.animation_style === 'soft'

      timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'anticipation', durations, soft: isSoftAttack }), turnStart))
      if (!turn.missed) {
        timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'lunge', durations, soft: isSoftAttack }), turnStart + durations.anticipation))
        timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'strike-rise', durations, soft: isSoftAttack }), turnStart + durations.anticipation + durations.lunge))
        timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'strike-land', durations, soft: isSoftAttack }), turnStart + durations.anticipation + durations.lunge + durations.strikeRise))
      }

      const isSuperEffective = attackerSide === 'player' ? playerTypeBonus : opponentTypeBonus
      timers.push(window.setTimeout(() => {
        setShownTurnIndex(i)
        setAttackState({ side: attackerSide, phase: 'return', durations, soft: isSoftAttack })

        if (turn.missed) {
          setMissSide(turn.invulnerable_miss ? hitSide : attackerSide)
          setMissLabel(turn.invulnerable_miss ? 'Invulnérable !' : 'MANQUÉ')
          setMissKey((k) => k + 1)
          if (turn.invulnerable_miss) {
            // Le bouclier protège le CAMP VISÉ par cette attaque, pas
            // l'attaquant lui-même (hitSide = celui qui vient d'esquiver).
            if (hitSide === 'player') setPlayerInvulnerable(false)
            else setOpponentInvulnerable(false)
          }

          const abilityNom = turn.ability_nom ?? (attackerSide === 'player' ? playerAbilityNom : opponentAbilityNom)
          const ability = attacksByName?.get(abilityNom)
          const basePrecision = ability?.precision ?? 10
          const precisionInfo = isAdmin ? getEffectivePrecision(basePrecision, attackerPrecisionStatus) : null

          pushHistory(attackerSide, `a manqué son attaque ${sideInfo(attackerSide, turn).ability}`, {
            basePrecision: isAdmin ? basePrecision : undefined,
            effectivePrecision: isAdmin ? precisionInfo?.effective : undefined,
            diceRoll: undefined,
            precisionStatus: isAdmin ? precisionInfo?.statusLabel : undefined,
          })
          // Peur/confusion : cette attaque ratée (ou non) est précisément
          // celle sous l'effet révélé par le tick précédent (turns[i-1]) —
          // le badge a été délibérément laissé affiché jusqu'ici (voir le
          // bloc status_tick plus haut). Il ne disparaît que si CE tick a
          // effectivement guéri le statut (precedingTick.status_cured) : la
          // peur guérit toujours en un coup, mais la confusion peut persister
          // (comme le sommeil) et le badge doit alors rester affiché pour les
          // tours suivants.
          if (attackerPrecisionStatus && precedingTick?.status_cured) {
            if (attackerSide === 'player') setPlayerStatus(null)
            else setOpponentStatus(null)
          }
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

        const abilityNom = turn.ability_nom ?? (attackerSide === 'player' ? playerAbilityNom : opponentAbilityNom)
        const ability = attacksByName?.get(abilityNom)
        const basePrecision = ability?.precision ?? 10
        const precisionInfo = isAdmin ? getEffectivePrecision(basePrecision, attackerPrecisionStatus) : null
        // damagePerHit = tout ce qui compose turn.damage AVANT le dé (espèce +
        // XP + multiplicateur type + degats_base de la capacité, voir
        // autobattle_resolve_battle v_player_damage/v_opponent_damage) —
        // fourni tel quel par le serveur, jamais recalculé côté client
        // (contrairement à ability.degats_base seul, qui omettait la
        // composante espèce/XP/type et donnait une valeur de dé fausse). Non
        // fiable en Combat Manuel (la capacité change à chaque tour, ce total
        // ne correspond qu'à celle du tour où le combat a commencé) — le dé
        // debug admin y est donc simplement masqué (voir diceValue ci-dessous).
        const damagePerHit = turn.ability_nom ? undefined : (attackerSide === 'player' ? playerDamagePerHit : opponentDamagePerHit)
        const diceValue = isAdmin && damagePerHit != null ? turn.damage - damagePerHit : undefined

        pushHistory(attackerSide, `a utilisé ${sideInfo(attackerSide, turn).ability}`, {
          damage: turn.damage,
          heal: turn.heal,
          superEffective: isSuperEffective,
          basePrecision: isAdmin ? basePrecision : undefined,
          effectivePrecision: isAdmin ? precisionInfo?.effective : undefined,
          diceRoll: diceValue,
          precisionStatus: isAdmin ? precisionInfo?.statusLabel : undefined,
        })

        // Peur/confusion : même principe que côté raté ci-dessus — cette
        // attaque réussie était celle sous l'effet révélé par le tick
        // précédent (turns[i-1]), le badge ne disparaît que si ce tick a
        // effectivement guéri le statut (avant un éventuel NOUVEAU statut
        // appliqué par ce même coup plus bas, qui écrasera cet effacement le
        // cas échéant).
        if (attackerPrecisionStatus && precedingTick?.status_cured) {
          if (attackerSide === 'player') setPlayerStatus(null)
          else setOpponentStatus(null)
        }

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
    }

    scheduledCountRef.current = turns.length
    streakRef.current = streak
    prevStreakAttackerRef.current = prevStreakAttacker
    playerShieldActiveRef.current = playerShieldActive
    opponentShieldActiveRef.current = opponentShieldActive

    timers.push(window.setTimeout(() => {
      setBattleDone(true)
      // Combat Manuel (hideContinueButton) : pas de bouton "Continuer" à
      // cliquer, on signale nous-mêmes la fin d'animation de ce tour dès
      // qu'elle arrive, pour que ManualBattleScreen redonne la main au
      // joueur (ou transitionne vers récompense/défaite si l'issue est
      // connue) — voir onContinue.
      if (hideContinueButton) onContinue()
    }, cursor + 200))
    return () => timers.forEach(clearTimeout)
    // eslint-disable-next-line react-hooks/exhaustive-deps -- ne doit redémarrer que quand fighting passe à true ou que de nouveaux tours arrivent (Combat Manuel) ; les autres props (playerAbilityNom, isAdmin, etc.) sont volontairement lues via closure, jamais suivies en dépendance
  }, [fighting, turns])

  const playerKo = shownTurnIndex >= 0 && playerHp <= 0
  const opponentKo = shownTurnIndex >= 0 && opponentHp <= 0
  // Cas Métamorph : sprite de l'adversaire copié pour ce combat (voir
  // autobattle_resolve_battle) — remplace le sprite réel de Métamorph
  // partout où il est affiché sur cet écran.
  const playerSpriteSrc = playerImageOverride ?? playerSpecies?.image_miniature
  // Cas Métamorph configuré comme adversaire (voir autobattle_resolve_battle)
  // — même principe symétrique que playerSpriteSrc.
  const opponentSpriteSrc = opponentImageOverride ?? opponentSpecies?.image_miniature

  const playerAttackStyle = attackState?.side === 'player' ? attackTransform(attackState.phase, 1, attackState.durations, attackState.soft) : undefined
  const opponentAttackStyle = attackState?.side === 'opponent' ? attackTransform(attackState.phase, -1, attackState.durations, attackState.soft) : undefined

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

      {battleDone && !hideContinueButton && (
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

      {midSlot}

      {fighting && historyOpen && (
        <AutoBattleHistoryLog
          entries={historyEntries}
          onHide={() => setHistoryOpen(false)}
          isAdmin={isAdmin}
        />
      )}
    </div>
  )
}
