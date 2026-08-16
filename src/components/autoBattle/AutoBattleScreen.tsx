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
import { AutoBattleAttackVfx } from './AutoBattleAttackVfx'
import { getStatusEffectDisplay, STATUS_EFFECT_LABEL } from '../../lib/autoBattle'
import { isAbsolutePrecision } from '../../lib/precisionColor'
import {
  battleAnimationStyle, battleAnimationSquashesTarget, getBattleAnimationVfx,
  BATTLE_DEFAULT_REACH_PX, type BattleAnimationId, type BattleVfxKind,
} from '../../lib/battleAnimations'
import { TYPE_COLORS } from '../../lib/typeColors'
import { PixelIcon } from '../icons/PixelIcon'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'
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
  /** Règles admin par capacité (autobattle_ability_rules) — sert au détail des calculs de dégâts/soin en debug admin (heal_type, percent_hp_damage_percent…). L'animation, elle, ne vient QUE du CSV des attaques (voir animationFor). */
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
  /** Multiplie la vitesse des phases d'attaque (voir computeDurations) — 2 = deux fois plus rapide (durées divisées par 2). Utilisé par le mode "Tester" du PvP (combat 100% automatique des deux côtés, voir PvpTrialBattleScreen) pour un retour rapide ; absent partout ailleurs (défaut 1, comportement inchangé). */
  speedMultiplier?: number
}

const COUNTDOWN_STEPS = ['3', '2', '1', 'GO !']

/** Durée d'affichage de la bulle de météo (ms) — même valeur que la bulle de talent d'AutoBattlePokemonPicker. */
const WEATHER_TIP_DURATION = 3000

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
interface AttackState { side: 'player' | 'opponent'; phase: AttackPhase; durations: PhaseDurations; animation: BattleAnimationId }
type Side = 'player' | 'opponent'

// Effet projeté en vol (rayon/projectile) du coup en cours — voir
// AutoBattleAttackVfx. Monté au départ de 'strike-rise' et démonté peu après
// l'impact, indépendamment de attackState (dont les phases servent au
// déplacement du sprite, pas au vol de l'effet).
interface AttackVfxState { side: Side; kind: BattleVfxKind; color: string; travelMs: number; damage: number }

// Durée de l'écrasement de la cible sur un coup 'Stomp' — remplace la
// secousse habituelle (SHAKE_MS), doit rester alignée sur l'animation CSS
// 'battle-stomp-squash' (voir src/index.css).
const SQUASH_MS = 420 * GLOBAL_SLOWDOWN

// Le déplacement du sprite attaquant est décrit par l'animation choisie pour
// la capacité (colonne "Animation" du CSV, voir src/lib/battleAnimations.ts) :
// chacune donne son propre transform pour la phase en cours. Le découpage en
// phases, lui, ne change jamais — petit recul (anticipation), élan (lunge),
// puis les deux phases du coup lui-même (strike-rise/strike-land, les dégâts
// tombant TOUJOURS à la fin de 'strike-land'), puis retour (return) — si bien
// qu'aucune animation ne peut modifier le rythme du combat. Sur un tour raté,
// seules 'anticipation' puis 'return' sont jouées. `sign` vaut +1 pour le
// joueur (l'adversaire est à sa droite) et -1 pour l'adversaire. `durations`
// vient du tour en cours (voir speedMultiplierForRepeat) : accéléré si ce tour
// fait partie d'un bloc multi-attaques.
function attackTransform(phase: AttackPhase, sign: 1 | -1, durations: PhaseDurations, animation: BattleAnimationId, reachPx: number): React.CSSProperties {
  return battleAnimationStyle(animation, phase, sign, durations, reachPx)
}

// Style du conteneur d'un sprite : réaction à un coup reçu (secousse ou
// écrasement) si le pokémon vient d'être touché, sinon animation d'attaque
// s'il est en train d'attaquer. Les deux passent par la propriété CSS
// `animation` (ou par un `transform` transitionné), d'où cette fusion
// explicite plutôt qu'un spread : la réaction au coup reçu prime toujours.
function spriteContainerStyle(
  attackStyle: React.CSSProperties | undefined,
  shaken: boolean,
  squashed: boolean
): React.CSSProperties {
  const reaction = squashed
    ? `battle-stomp-squash ${SQUASH_MS}ms ease-out`
    : shaken ? `hit-shake ${SHAKE_MS}ms ease-in-out` : undefined
  if (!reaction) return attackStyle ?? {}
  return { ...attackStyle, animation: reaction }
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
  playerTypeBonus, opponentTypeBonus, onContinue, isAdmin = false, attacksByName, abilityRulesByName,
  hideContinueButton = false, midSlot, skipCountdown = false, speedMultiplier = 1,
}: Props) {
  const [countdownStep, setCountdownStep] = useState(-1)
  const [fighting, setFighting] = useState(skipCountdown)
  const [playerHp, setPlayerHp] = useState(playerMaxHp)
  const [opponentHp, setOpponentHp] = useState(opponentMaxHp)
  const [shownTurnIndex, setShownTurnIndex] = useState(-1)
  const [attackState, setAttackState] = useState<AttackState | null>(null)
  const [attackVfx, setAttackVfx] = useState<AttackVfxState | null>(null)
  const [vfxKey, setVfxKey] = useState(0)
  const [shakeSide, setShakeSide] = useState<Side | null>(null)
  const [squashSide, setSquashSide] = useState<Side | null>(null)
  const [flashSide, setFlashSide] = useState<Side | null>(null)
  const [hitKey, setHitKey] = useState(0)
  const [lastDamage, setLastDamage] = useState<{ side: Side; damage: number; superEffective: boolean; color?: string } | null>(null)
  const [missSide, setMissSide] = useState<Side | null>(null)
  const [missKey, setMissKey] = useState(0)
  const [missLabel, setMissLabel] = useState('MANQUÉ')
  const [skipSide, setSkipSide] = useState<Side | null>(null)
  const [skipKey, setSkipKey] = useState(0)
  const [skipLabel, setSkipLabel] = useState('Tour passé !')
  // Déclenchement d'un talent d'espèce (voir AutoBattleTurn.talent_tick) : nom
  // du talent en texte flottant doré au-dessus du pokémon concerné.
  const [talentSide, setTalentSide] = useState<Side | null>(null)
  const [talentKey, setTalentKey] = useState(0)
  const [talentLabel, setTalentLabel] = useState('')
  // Météo en cours (voir AutoBattleTurn.weather_tick) : pastille ronde posée
  // entre les deux noms de pokémon. Une seule à la fois, remplacée par le
  // prochain tour weather_set — aucune ne s'éteint d'elle-même, elle dure
  // jusqu'à la fin du combat. `details` vient du serveur (une ligne par effet,
  // voir autobattle_weather_details) : le client n'a jamais à relire la config.
  const [activeWeather, setActiveWeather] = useState<{ nom: string; icon: string | null; details: string[] } | null>(null)
  // Bulle de description ouverte au clic sur la pastille — éphémère (3 s ou dès
  // que l'utilisateur fait autre chose), même mécanique que les talents dans
  // AutoBattlePokemonPicker.
  const [weatherTipOpen, setWeatherTipOpen] = useState(false)
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
  const historyIdRef = useRef(0)
  // Distance réelle (px) entre le centre des deux sprites : elle dépend de la
  // largeur du popup (~175px sur mobile, davantage dès `sm:`), et c'est elle
  // qui décide où atterrit un bond / jusqu'où va un rayon ou un projectile.
  // Mesurée sur les COLONNES et non sur les sprites : les colonnes ne sont
  // jamais déplacées par une animation, leur centre reste donc valable même
  // au milieu d'une attaque.
  const playerColRef = useRef<HTMLDivElement | null>(null)
  const opponentColRef = useRef<HTMLDivElement | null>(null)
  const [reachPx, setReachPx] = useState(BATTLE_DEFAULT_REACH_PX)
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
  // Voir le commentaire détaillé plus bas (autobattle_resolve_battle a le
  // même concept côté serveur, v_round_no) : le bouclier ne s'éteint QUE
  // quand son propriétaire recommence à jouer APRÈS avoir vu l'adversaire
  // jouer au moins un coup depuis qu'il a été accordé — pas juste "au tour
  // suivant", pour survivre à une rafale adverse entière (play_twice/
  // play_three/...) plutôt que de disparaître dès son 1er coup.
  const playerShieldSeenOpponentTurnRef = useRef(false)
  const opponentShieldSeenPlayerTurnRef = useRef(false)
  // Capacité en deux tours (turn_effect = 'prepare_release') : passe à true au
  // tour de préparation (turn.preparing) et retombe à false au tour de
  // libération, qui joue alors "Animation 2" au lieu de "Animation" (voir
  // src/lib/battleAnimations.ts). Même raison d'être en ref que les boucliers
  // ci-dessus : en Combat Manuel les deux tours arrivent dans deux exécutions
  // successives de l'effet de programmation.
  const playerReleasingRef = useRef(false)
  const opponentReleasingRef = useRef(false)

  // Précision effective affichée en debug admin — reproduit EXACTEMENT
  // GREATEST(0, ability.precision - v_status_precision_penalty +
  // precision_mod_amount) côté serveur (voir autobattle_resolve_round_core/
  // autobattle_resolve_battle), donc clampée à 0 seulement (jamais un
  // plancher artificiel à 1 : le serveur peut légitimement amener la
  // précision à 0, auquel cas l'attaque rate toujours). precisionModAmount
  // = turn.precision_mod_amount, déjà signé (buff positif / debuff négatif),
  // voir AutoBattleAbilityRule.stat_mod_stat = 'precision'.
  const getEffectivePrecision = (
    basePrecision: number,
    status: AutoBattleStatusEffect | null,
    precisionModAmount: number
  ): { effective: number; statusModifier: number; statusLabel?: string; precisionModAmount: number } => {
    const statusModifier = status ? (PRECISION_MODIFIER_BY_STATUS[status] ?? 0) : 0
    const effective = Math.max(0, basePrecision + statusModifier + precisionModAmount)
    return { effective, statusModifier, statusLabel: status && statusModifier !== 0 ? STATUS_EFFECT_LABEL[status] : undefined, precisionModAmount }
  }

  // Détail complet du calcul de précision en admin, même esprit que
  // damageFormula plus bas ("X (base) - Y (statut) + Z (buff) = total").
  // Une précision ABSOLUE (case vide ou 0 dans le CSV) n'a aucune formule à
  // montrer : le serveur ne lance pas le dé du tout et aucun statut ni
  // modificateur n'entre en jeu (voir isAbsolutePrecision) — afficher
  // "10 (précision de base) - 5 (Peur) = 5/10" serait purement faux.
  const buildPrecisionDebug = (
    precision: number | null | undefined,
    status: AutoBattleStatusEffect | null,
    precisionModAmount: number
  ): string => {
    if (isAbsolutePrecision(precision)) return 'Précision absolue (-) : ne peut jamais rater'
    const basePrecision = precision as number
    const info = getEffectivePrecision(basePrecision, status, precisionModAmount)
    let formula = `${basePrecision} (précision de base)`
    if (info.statusModifier !== 0) {
      formula += ` ${info.statusModifier > 0 ? '+' : '-'} ${Math.abs(info.statusModifier)} (${info.statusLabel})`
    }
    if (info.precisionModAmount !== 0) {
      formula += ` ${info.precisionModAmount > 0 ? '+' : '-'} ${Math.abs(info.precisionModAmount)} (${info.precisionModAmount > 0 ? 'buff' : 'debuff'})`
    }
    formula += ` = ${info.effective}/10`
    return formula
  }

  useEffect(() => {
    const measure = () => {
      const left = playerColRef.current?.getBoundingClientRect()
      const right = opponentColRef.current?.getBoundingClientRect()
      if (!left || !right) return
      const distance = Math.abs((right.left + right.width / 2) - (left.left + left.width / 2))
      if (distance > 0) setReachPx(distance)
    }
    measure()
    // ResizeObserver plutôt que l'évènement `resize` : le popup peut changer
    // de largeur sans que la fenêtre bouge (ouverture du clavier, apparition
    // de la grille de capacités en Combat Manuel…).
    const observer = new ResizeObserver(measure)
    if (playerColRef.current) observer.observe(playerColRef.current)
    return () => observer.disconnect()
  }, [])

  // Bulle de météo : affichage éphémère, elle se ferme d'elle-même au bout de
  // 3 s ou dès que l'utilisateur fait autre chose (clic n'importe où, scroll,
  // resize) — décalque d'AutoBattlePokemonPicker pour les talents. Capture sur
  // `document` et pas `window` : le scroll du corps de la popup de combat ne
  // remonte pas jusqu'à window, même en phase de capture.
  useEffect(() => {
    if (!weatherTipOpen) return
    const close = () => setWeatherTipOpen(false)
    const timer = window.setTimeout(close, WEATHER_TIP_DURATION)
    document.addEventListener('pointerdown', close, true)
    document.addEventListener('scroll', close, true)
    window.addEventListener('resize', close)
    return () => {
      window.clearTimeout(timer)
      document.removeEventListener('pointerdown', close, true)
      document.removeEventListener('scroll', close, true)
      window.removeEventListener('resize', close)
    }
  }, [weatherTipOpen])

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
    // Sauvegarde de TOUT ce que cet effet s'apprête à écrire dans des refs :
    // si son nettoyage survient avant que le moindre timer n'ait pu s'exécuter,
    // il faut pouvoir revenir en arrière (voir `flushed` et le cleanup).
    const refsAtStart = {
      scheduledCount: scheduledCountRef.current,
      streak: streakRef.current,
      prevStreakAttacker: prevStreakAttackerRef.current,
      battleStart: battleStartRef.current,
      playerShieldActive: playerShieldActiveRef.current,
      opponentShieldActive: opponentShieldActiveRef.current,
      playerShieldSeenOpponentTurn: playerShieldSeenOpponentTurnRef.current,
      opponentShieldSeenPlayerTurn: opponentShieldSeenPlayerTurnRef.current,
      playerReleasing: playerReleasingRef.current,
      opponentReleasing: opponentReleasingRef.current,
    }
    // Passe à vrai dès que la boucle d'évènements a pu tourner, donc dès que ce
    // lot de tours a commencé à s'animer pour de bon. StrictMode (dev) exécute
    // l'effet, le nettoie SYNCHRONEMENT puis le ré-exécute : dans ce cas
    // `flushed` est encore faux au nettoyage.
    let flushed = false
    timers.push(window.setTimeout(() => { flushed = true }, 0))
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
    // PROCHAIN TOUR de son propriétaire (avant que sa capacité ne soit
    // résolue), pas "au coup adverse suivant" : il bloque donc TOUTE la
    // prochaine rafale adverse s'il y en a une (voir autobattle_resolve_
    // battle/autobattle_resolve_manual_round, v_round_no) — même règle
    // appliquée ici côté client, sans dépendre d'un champ serveur dédié.
    let playerShieldActive = playerShieldActiveRef.current
    let opponentShieldActive = opponentShieldActiveRef.current
    let playerShieldSeenOpponentTurn = playerShieldSeenOpponentTurnRef.current
    let opponentShieldSeenPlayerTurn = opponentShieldSeenPlayerTurnRef.current
    let playerReleasing = playerReleasingRef.current
    let opponentReleasing = opponentReleasingRef.current
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

    // `content` : soit une phrase simple, soit un découpage autour d'une mention
    // à mettre en valeur — un STATUT (coloré), un nom de TALENT ou un nom de
    // MÉTÉO (gras). `neutral` retire l'icône et le nom du pokémon : la météo qui
    // se lève n'appartient à aucun camp.
    const pushHistory = (
      side: Side,
      content:
        | string
        | { before: string; status: AutoBattleStatusEffect; after: string }
        | { before: string; talent: string; after: string }
        | { before: string; weather: string; after: string },
      extra?: { damage?: number; heal?: number; superEffective?: boolean; precisionFormula?: string; damageFormula?: string; healFormula?: string; neutral?: boolean }
    ) => {
      const info = sideInfo(side)
      historyIdRef.current += 1
      const isStatus = typeof content !== 'string' && 'status' in content
      const isTalent = typeof content !== 'string' && 'talent' in content
      const isWeather = typeof content !== 'string' && 'weather' in content
      const entry: AutoBattleHistoryEntryData = {
        id: historyIdRef.current, elapsedMs: Date.now() - battleStart, side, pokemonName: info.name, iconSrc: info.iconSrc,
        text: typeof content === 'string' ? content : undefined,
        statusText: !isStatus ? undefined : (() => {
          const display = getStatusEffectDisplay(content.status)
          return { before: content.before, statusLabel: display.label, statusColor: display.color, after: content.after }
        })(),
        talentText: !isTalent ? undefined : { before: content.before, talentLabel: content.talent, after: content.after },
        weatherText: !isWeather ? undefined : { before: content.before, weatherLabel: content.weather, after: content.after },
        neutral: extra?.neutral,
        damage: extra?.damage && extra.damage > 0 ? extra.damage : undefined,
        heal: extra?.heal && extra.heal > 0 ? extra.heal : undefined,
        superEffective: extra?.superEffective,
        debugPrecisionFormula: extra?.precisionFormula,
        debugDamageFormula: extra?.damageFormula,
        debugHealFormula: extra?.healFormula,
      }
      setHistoryEntries((prev) => [entry, ...prev])
    }

    // Animation à jouer pour un coup donné : celle choisie sur la capacité
    // dans le CSV des attaques (colonne "Animation", ou "Animation 2" sur le
    // tour de libération d'une capacité en deux temps). Le CSV est l'unique
    // source de vérité — colonne vide ou libellé non reconnu = 'Jump Attack',
    // le bond historique.
    const animationFor = (abilityNom: string, second: boolean): BattleAnimationId => {
      const ability = attacksByName?.get(abilityNom)
      const chosen = second ? ability?.animation_2 ?? ability?.animation : ability?.animation
      return chosen ?? 'jump_attack'
    }

    // Programme le déplacement du sprite attaquant (phases 'anticipation' →
    // 'strike-land') et, le cas échéant, l'effet projeté vers la cible. La
    // phase 'return' n'est PAS programmée ici pour un vrai coup : elle part du
    // callback d'impact plus bas, en même temps que les dégâts.
    const scheduleAttackAnimation = (opts: {
      side: Side; animation: BattleAnimationId; abilityNom: string
      durations: PhaseDurations; turnStart: number; full: boolean; damage: number
    }) => {
      const { side, animation, abilityNom, durations, turnStart, full, damage } = opts
      timers.push(window.setTimeout(() => setAttackState({ side, phase: 'anticipation', durations, animation }), turnStart))
      if (!full) return
      const lungeAt = turnStart + durations.anticipation
      const riseAt = lungeAt + durations.lunge
      const landAt = riseAt + durations.strikeRise
      timers.push(window.setTimeout(() => setAttackState({ side, phase: 'lunge', durations, animation }), lungeAt))
      timers.push(window.setTimeout(() => setAttackState({ side, phase: 'strike-rise', durations, animation }), riseAt))
      timers.push(window.setTimeout(() => setAttackState({ side, phase: 'strike-land', durations, animation }), landAt))

      // Le projectile/rayon part avec la phase 'strike-rise' et met
      // exactement le reste du tour à parcourir la distance : il touche la
      // cible pile quand les dégâts sont appliqués, y compris sur les tours
      // accélérés (voir speedMultiplierForRepeat).
      const kind = getBattleAnimationVfx(animation)
      if (!kind) return
      const travelMs = durations.strikeRise + durations.strikeLand
      const color = TYPE_COLORS[attacksByName?.get(abilityNom)?.type ?? ''] ?? '#f0c419'
      timers.push(window.setTimeout(() => {
        setAttackVfx({ side, kind, color, travelMs, damage })
        setVfxKey((k) => k + 1)
      }, riseAt))
      timers.push(window.setTimeout(() => setAttackVfx(null), riseAt + travelMs + FLASH_MS))
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
      // ATTENTION : ce tick n'est PAS forcément turns[i-1]. Le serveur glisse
      // entre lui et l'attaque des tours qui ne sont l'action de personne : le
      // tick de soin passif du camp concerné (heal_dot_tick, émis juste après
      // le tick de statut) et les déclenchements de talents (talent_tick, émis
      // avant l'entrée d'attaque — « à chaque tour », guérison automatique
      // côté cible…). Sans remonter au-dessus de ces tours-là, le badge
      // Peur/Confusion n'était jamais effacé dès qu'un soin passif ou un
      // talent s'intercalait, et le détail de précision en admin perdait la
      // ligne du malus.
      // Un statut REPOSÉ entre-temps par une tentative persistante (voir
      // status_dot_tick) doit couper court à l'effacement du badge plus bas :
      // le tick de Peur guérit la peur, mais la tentative qui suit dans le même
      // tour peut avoir immédiatement infligé autre chose, et ce badge-là doit
      // rester allumé.
      let statusReapplied = false
      let precedingTick: AutoBattleTurn | undefined
      for (let j = i - 1; j >= 0; j--) {
        if (turns[j].status_dot_tick) { statusReapplied = true; continue }
        if (turns[j].talent_tick || turns[j].heal_dot_tick || turns[j].damage_dot_tick || turns[j].leech_dot_tick) continue
        precedingTick = turns[j]
        break
      }
      const attackerPrecisionStatus: AutoBattleStatusEffect | null =
        precedingTick?.status_tick && precedingTick.attacker === attackerSide
        && (precedingTick.status === 'confusion' || precedingTick.status === 'fear')
          ? precedingTick.status
          : null

      // Le bouclier d'invulnérabilité expire au tout DÉBUT du prochain tour
      // de son propriétaire, avant que sa capacité ne soit résolue — pas "1
      // coup adverse" : tant que l'adversaire n'a pas encore joué depuis
      // l'octroi (playerShieldSeenOpponentTurn / opponentShieldSeenPlayerTurn
      // encore faux), le bouclier reste actif MÊME si CE tour-ci appartient
      // déjà au propriétaire (rafale de sa propre capacité qui vient
      // d'accorder le bouclier) — il ne s'éteint que la fois SUIVANTE où
      // c'est son tour, une fois l'adversaire effectivement passé entretemps
      // (voir autobattle_resolve_battle/autobattle_resolve_manual_round,
      // v_round_no : un bouclier accordé au tour N reste actif tout le tour
      // adverse N+1 — rafale comprise — et ne s'éteint qu'au tour N+2).
      if (playerShieldActive && playerShieldSeenOpponentTurn && attackerSide === 'player') {
        playerShieldActive = false
        playerShieldSeenOpponentTurn = false
        timers.push(window.setTimeout(() => setPlayerInvulnerable(false), turnStart))
      }
      if (opponentShieldActive && opponentShieldSeenPlayerTurn && attackerSide === 'opponent') {
        opponentShieldActive = false
        opponentShieldSeenPlayerTurn = false
        timers.push(window.setTimeout(() => setOpponentInvulnerable(false), turnStart))
      }
      if (playerShieldActive && attackerSide === 'opponent') playerShieldSeenOpponentTurn = true
      if (opponentShieldActive && attackerSide === 'player') opponentShieldSeenPlayerTurn = true
      // Le suivi local (synchrone, pendant la programmation des timers) doit
      // être mis à jour ICI plutôt que dans les callbacks différés
      // (setTimeout) ci-dessous : ce .forEach programme TOUS les tours d'un
      // coup avant qu'aucune animation ne joue réellement, donc une
      // affectation faite dans un callback différé ne serait jamais visible
      // par les itérations suivantes de cette même boucle synchrone.
      if (turn.invulnerable_granted) {
        if (attackerSide === 'player') { playerShieldActive = true; playerShieldSeenOpponentTurn = false }
        else { opponentShieldActive = true; opponentShieldSeenPlayerTurn = false }
      }

      // Position (1-based) de ce tour dans son bloc d'attaques consécutives
      // du même camp — voir speedMultiplierForRepeat ci-dessus. 'skipped',
      // 'status_tick' et 'heal_dot_tick' n'appartiennent jamais à un tel
      // bloc, cassent toujours la série (un tick n'est pas "réutiliser la
      // capacité").
      const isTickTurn = turn.status_tick || turn.heal_dot_tick || turn.damage_dot_tick
        || turn.leech_dot_tick || turn.status_dot_tick || turn.talent_tick || turn.weather_tick
      if (turn.skipped || isTickTurn) {
        streak = 0
        prevStreakAttacker = null
      } else {
        streak = attackerSide === prevStreakAttacker ? streak + 1 : 1
        prevStreakAttacker = attackerSide
      }
      const multiplier = (turn.skipped || isTickTurn) ? 1 : speedMultiplierForRepeat(streak)
      const durations = computeDurations(multiplier * speedMultiplier)
      const impactOffset = durations.anticipation + durations.lunge + durations.strikeRise + durations.strikeLand
      const turnDuration = impactOffset + durations.return + durations.gap

      // Événement de MÉTÉO (voir autobattle_weathers). Deux formes, distinguées
      // par weather_set :
      //   • la météo SE LÈVE : annonce de terrain, neutre (aucun camp), qui
      //     remplace le bandeau ; l'animation est jouée sur le pokémon qui l'a
      //     déclenchée, d'où un `attacker` quand même renseigné.
      //   • TICK de début de tour : dégâts et/ou statut sur CE pokémon-là.
      // Comme pour un talent, `attacker` désigne le camp CONCERNÉ et jamais un
      // attaquant, et les PV font foi sur attacker_hp_after.
      if (turn.weather_tick) {
        const animation = turn.weather_animation ?? 'idle'
        const label = turn.weather_nom ?? 'Météo'
        scheduleAttackAnimation({
          side: attackerSide, animation, abilityNom: '', durations, turnStart, full: true, damage: 0,
        })
        timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'return', durations, animation }), turnStart + impactOffset))
        timers.push(window.setTimeout(() => setAttackState(null), turnStart + impactOffset + durations.return))

        timers.push(window.setTimeout(() => {
          setShownTurnIndex(i)
          setTalentSide(attackerSide)
          setTalentLabel(label)
          setTalentKey((k) => k + 1)
          if (turn.weather_set) {
            setActiveWeather({ nom: label, icon: turn.weather_icon ?? null, details: turn.weather_details ?? [] })
            pushHistory(
              attackerSide,
              { before: '', weather: label, after: turn.weather_replaced ? ' remplace la météo en cours !' : ' se lève !' },
              { neutral: true },
            )
            return
          }
          // Météo DISSIPÉE par une capacité (voir clear_weather) : le tour
          // décrit la météo qui disparaît, le bandeau est simplement retiré.
          if (turn.weather_cleared) {
            setActiveWeather(null)
            pushHistory(attackerSide, { before: '', weather: label, after: ' se dissipe !' }, { neutral: true })
            return
          }
          // Tick : les PV annoncés sont ceux d'AVANT le soin de seuil éventuel
          // (voir autobattle_weather_tick) — le tour de talent qui suit remonte
          // la barre, exactement comme pour un tick de brûlure.
          if (turn.attacker_hp_after != null) {
            if (attackerSide === 'player') setPlayerHp(Math.min(playerMaxHp, turn.attacker_hp_after))
            else setOpponentHp(Math.min(opponentMaxHp, turn.attacker_hp_after))
          }
          // Statut de terrain : il vise le pokémon CONCERNÉ lui-même, pas son
          // adversaire (contrairement au talent 'inflict_status').
          if (turn.weather_inflicted_status) {
            if (attackerSide === 'player') setPlayerStatus(turn.weather_inflicted_status)
            else setOpponentStatus(turn.weather_inflicted_status)
          }
          pushHistory(
            attackerSide,
            turn.weather_inflicted_status
              ? { before: 'subit ', weather: label, after: '' }
              : { before: 'est frappé par ', weather: label, after: '' },
            { damage: turn.weather_damage },
          )
        }, turnStart + durations.anticipation))
        timers.push(window.setTimeout(() => setTalentSide(null), turnStart + durations.anticipation + FLYING_TEXT_MS))
        cursor += turnDuration
        continue
      }

      // Déclenchement d'un TALENT d'espèce (voir autobattle_talents) : jamais
      // l'usage d'une capacité, donc jamais sideInfo(...).ability — en Combat
      // Manuel/PvP, turn.ability_nom porte la capacité choisie ce tour-là, qui
      // n'a aucun rapport avec le talent (même piège que heal_dot_tick).
      // L'animation est auto-ciblée (celle configurée en admin, 'idle' par
      // défaut) et le serveur fournit déjà la phrase d'historique.
      if (turn.talent_tick) {
        const animation = turn.talent_animation ?? 'idle'
        scheduleAttackAnimation({
          side: attackerSide, animation, abilityNom: '', durations, turnStart, full: true, damage: 0,
        })
        timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'return', durations, animation }), turnStart + impactOffset))
        timers.push(window.setTimeout(() => setAttackState(null), turnStart + impactOffset + durations.return))

        timers.push(window.setTimeout(() => {
          setShownTurnIndex(i)
          const label = turn.talent_nom ?? 'Talent'
          setTalentSide(attackerSide)
          setTalentLabel(label)
          setTalentKey((k) => k + 1)
          // 'endure_ko' remonte les PV à 1 et 'heal_below_hp' soigne : c'est
          // attacker_hp_after (le propriétaire du talent) qui fait foi ici,
          // jamais defender_hp_after. Borné aux PV max : 'type_damage_to_heal'
          // annonce PV + soin sans connaître le maximum côté serveur (voir
          // autobattle_talent_defend), le surplus de soin doit être rogné ici.
          if (turn.attacker_hp_after != null) {
            if (attackerSide === 'player') setPlayerHp(Math.min(playerMaxHp, turn.attacker_hp_after))
            else setOpponentHp(Math.min(opponentMaxHp, turn.attacker_hp_after))
          }
          if (turn.heal != null && turn.heal > 0) {
            setHealSide(attackerSide)
            setLastHeal({ side: attackerSide, amount: turn.heal })
            setHealKey((k) => k + 1)
            // N'importe quel soin guérit le poison (voir status_effect 'poison').
            if (attackerSide === 'player') setPlayerStatus((s) => (s === 'poison' ? null : s))
            else setOpponentStatus((s) => (s === 'poison' ? null : s))
          }
          // Statut infligé par ce talent : il vise l'ADVERSAIRE du porteur (un
          // tour de talent n'est pas un tour d'attaque, d'où le champ dédié).
          if (turn.talent_inflicted_status) {
            if (attackerSide === 'player') setOpponentStatus(turn.talent_inflicted_status)
            else setPlayerStatus(turn.talent_inflicted_status)
          }
          // 'auto_cure_first_status' : `attacker` est ici la CIBLE du statut
          // (le porteur du talent, voir autobattle_talent_status_guard), et le
          // statut ne s'applique pas du tout côté serveur. Le tour de talent
          // qui l'a infligé le porte quand même (talent_inflicted_status est
          // émis avant que la garde ne se prononce) : sans cet effacement, le
          // badge s'allumait pour un statut inexistant et n'était plus jamais
          // retiré, faute de tick de statut pour le guérir.
          if (turn.talent_kind === 'auto_cure_first_status') {
            if (attackerSide === 'player') setPlayerStatus(null)
            else setOpponentStatus(null)
          }
          pushHistory(
            attackerSide,
            { before: 'déclenche son talent ', talent: label, after: turn.talent_detail ? ` : ${turn.talent_detail}` : '' },
            { heal: turn.heal }
          )
        }, turnStart + durations.anticipation))
        timers.push(window.setTimeout(() => setTalentSide(null), turnStart + durations.anticipation + FLYING_TEXT_MS))
        cursor += turnDuration
        continue
      }

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

      // Tick de soin passif (heal_dot, voir AutoBattleTurn.heal_dot_tick) :
      // comme status_tick ci-dessus, ce n'est jamais l'usage d'une capacité
      // (en Combat Manuel, turn.ability_nom porte le nom de la capacité
      // choisie CE tour-ci, qui n'a souvent aucun rapport avec celle qui a
      // accordé le soin passif à l'origine — le tour générique plus bas
      // afficherait donc "a utilisé <mauvaise capacité>" et donnerait
      // l'impression que cette capacité a soigné deux fois). Pas d'animation
      // d'attaque : juste le HP qui remonte et une ligne d'historique dédiée.
      // Tentative de statut persistante QUI A ABOUTI (voir AutoBattleTurn.
      // status_dot_tick — les jets ratés n'émettent rien) : `attacker` est la
      // victime, qui gagne le statut. Pas d'animation d'attaque, juste le
      // badge et une ligne d'historique, comme un statut infligé par un coup.
      if (turn.status_dot_tick) {
        timers.push(window.setTimeout(() => {
          setShownTurnIndex(i)
          if (turn.status_dot_applied) {
            if (attackerSide === 'player') setPlayerStatus(turn.status_dot_applied)
            else setOpponentStatus(turn.status_dot_applied)
            pushHistory(attackerSide, { before: 'est affecté par ', status: turn.status_dot_applied, after: '' })
          }
        }, turnStart + durations.anticipation))
        cursor += turnDuration
        continue
      }

      // Ticks des effets persistants OFFENSIFS (voir AutoBattleTurn.
      // damage_dot_tick / leech_dot_tick) : miroirs du tick de soin passif
      // ci-dessous — jamais l'usage d'une capacité, donc pas d'animation
      // d'attaque. `attacker` désigne ici la VICTIME (le camp dont c'est le
      // tour, comme un tick de brûlure) : c'est elle qui encaisse, et pour le
      // vol de vie c'est l'AUTRE camp (defender_hp_after) qui récupère.
      if (turn.damage_dot_tick || turn.leech_dot_tick) {
        const victimSide = attackerSide
        const thiefSide: Side = victimSide === 'player' ? 'opponent' : 'player'
        timers.push(window.setTimeout(() => {
          setShownTurnIndex(i)
          if (turn.attacker_hp_after != null) {
            if (victimSide === 'player') setPlayerHp(turn.attacker_hp_after)
            else setOpponentHp(turn.attacker_hp_after)
          }
          if (turn.damage > 0) {
            setShakeSide(victimSide)
            setFlashSide(victimSide)
            setLastDamage({ side: victimSide, damage: turn.damage, superEffective: false })
            setHitKey((k) => k + 1)
            window.setTimeout(() => setShakeSide(null), SHAKE_MS)
            window.setTimeout(() => setFlashSide(null), FLASH_MS)
          }
          // Vol de vie : les PV rendus au voleur (0 si son soin est bloqué par
          // un Anti-Soin) remontent sa barre et jouent son effet de soin.
          if (turn.leech_dot_tick && turn.heal != null && turn.heal > 0) {
            if (turn.defender_hp_after != null) {
              if (thiefSide === 'player') setPlayerHp(turn.defender_hp_after)
              else setOpponentHp(turn.defender_hp_after)
            }
            setHealSide(thiefSide)
            setLastHeal({ side: thiefSide, amount: turn.heal })
            setHealKey((k) => k + 1)
            // N'importe quel soin guérit le poison, celui-ci compris.
            if (thiefSide === 'player') setPlayerStatus((s) => (s === 'poison' ? null : s))
            else setOpponentStatus((s) => (s === 'poison' ? null : s))
          }
          pushHistory(
            victimSide,
            turn.leech_dot_tick ? 'se fait drainer des PV' : 'subit des dégâts persistants',
            { damage: turn.damage },
          )
        }, turnStart + durations.anticipation))
        cursor += turnDuration
        continue
      }

      if (turn.heal_dot_tick) {
        timers.push(window.setTimeout(() => {
          setShownTurnIndex(i)
          if (turn.heal != null && turn.attacker_hp_after != null) {
            const healAmount = turn.heal
            const attackerHpAfter = turn.attacker_hp_after
            if (attackerSide === 'player') setPlayerHp(attackerHpAfter)
            else setOpponentHp(attackerHpAfter)
            setHealSide(attackerSide)
            setLastHeal({ side: attackerSide, amount: healAmount })
            setHealKey((k) => k + 1)
            // N'importe quel soin guérit le poison, le soin passif compris.
            if (attackerSide === 'player') setPlayerStatus((s) => (s === 'poison' ? null : s))
            else setOpponentStatus((s) => (s === 'poison' ? null : s))
          }
          pushHistory(attackerSide, 'récupère des PV grâce à son soin passif', { heal: turn.heal })
        }, turnStart + durations.anticipation))
        cursor += turnDuration
        continue
      }

      if (turn.skipped) {
        // 1er tour d'une capacité en deux temps : il joue bel et bien son
        // animation ("Animation", typiquement "Idle" quand la capacité se
        // contente de se charger) — c'est le tour de libération qui suit qui
        // jouera "Animation 2". Un tour simplement passé (effet 'skip',
        // statut) reste sans aucune animation, comme avant.
        if (turn.preparing || turn.charging) {
          const prepareAbilityNom = turn.ability_nom ?? (attackerSide === 'player' ? playerAbilityNom : opponentAbilityNom)
          const prepareAnimation = animationFor(prepareAbilityNom, false)
          // Un tour de préparation n'inflige jamais rien : son rayon reste
          // donc au plus fin (voir beamScaleForDamage), le coup qui compte
          // étant celui de la libération au tour suivant.
          scheduleAttackAnimation({ side: attackerSide, animation: prepareAnimation, abilityNom: prepareAbilityNom, durations, turnStart, full: true, damage: 0 })
          timers.push(window.setTimeout(() => setAttackState({ side: attackerSide, phase: 'return', durations, animation: prepareAnimation }), turnStart + impactOffset))
          timers.push(window.setTimeout(() => setAttackState(null), turnStart + impactOffset + durations.return))
          // "Animation 2" n'existe que pour les capacités en deux temps
          // (prepare_release) — un tour de charge ('charge_double_next')
          // n'enchaîne pas sur une libération, il rejoue l'animation normale.
          if (turn.preparing) {
            if (attackerSide === 'player') playerReleasing = true
            else opponentReleasing = true
          }
        }
        timers.push(window.setTimeout(() => {
          setShownTurnIndex(i)
          setSkipSide(attackerSide)
          setSkipLabel(turn.charging ? 'Charge !' : turn.preparing ? 'Préparation' : 'Tour passé !')
          setSkipKey((k) => k + 1)
          pushHistory(attackerSide,
            turn.charging ? 'se concentre : il jouera deux fois au prochain tour'
            : turn.preparing ? `se prépare à attaquer avec ${sideInfo(attackerSide, turn).ability}`
            : 'passe son tour')
          // Invulnérabilité accordée dès la préparation (prepare_release +
          // invulnerable_next_turn combinés, voir autobattle_resolve_battle) —
          // protège le tour adverse qui suit immédiatement, pas celui après
          // la libération.
          if (turn.invulnerable_granted) {
            if (attackerSide === 'player') setPlayerInvulnerable(true)
            else setOpponentInvulnerable(true)
          }
          // Peur/confusion : le tour qui suit le tick n'est pas toujours une
          // attaque — une capacité à effet ('prepare_release', 'charge_double
          // _next', 'skip', rafale tirée à 0) produit ici un tour passé. C'est
          // alors CE tour-ci qui consomme le tick, et le badge doit disparaître
          // comme il le fait sur une attaque (voir les deux branches plus bas),
          // sinon il reste affiché jusqu'à la fin du combat.
          if (attackerPrecisionStatus && precedingTick?.status_cured && !statusReapplied) {
            if (attackerSide === 'player') setPlayerStatus(null)
            else setOpponentStatus(null)
          }
        }, turnStart + durations.anticipation))
        timers.push(window.setTimeout(() => setSkipSide(null), turnStart + durations.anticipation + FLYING_TEXT_MS))
        cursor += turnDuration
        continue
      }

      // Animation de ce coup (colonne "Animation" du CSV des attaques, ou
      // "Animation 2" si ce tour libère une capacité en deux temps préparée au
      // tour précédent) — purement visuel, voir animationFor plus haut.
      // N'affecte que le déplacement de l'ATTAQUANT et l'effet projeté :
      // dégâts/tremblement/flash sur la cible inchangés (à l'exception de
      // 'Stomp', qui écrase la cible au lieu de la secouer).
      const attackAbilityNom = turn.ability_nom ?? (attackerSide === 'player' ? playerAbilityNom : opponentAbilityNom)
      const isRelease = attackerSide === 'player' ? playerReleasing : opponentReleasing
      if (isRelease) {
        if (attackerSide === 'player') playerReleasing = false
        else opponentReleasing = false
      }
      const attackAnimation = animationFor(attackAbilityNom, isRelease)

      // Un tour raté ne joue que le petit mouvement d'anticipation puis le
      // retour : ni élan, ni coup, ni projectile (full: false).
      scheduleAttackAnimation({
        side: attackerSide, animation: attackAnimation, abilityNom: attackAbilityNom,
        durations, turnStart, full: !turn.missed, damage: turn.damage,
      })

      const isSuperEffective = attackerSide === 'player' ? playerTypeBonus : opponentTypeBonus
      timers.push(window.setTimeout(() => {
        setShownTurnIndex(i)
        setAttackState({ side: attackerSide, phase: 'return', durations, animation: attackAnimation })

        if (turn.missed) {
          // Immunité de type (turn.no_effect) : le texte s'affiche sur la
          // CIBLE, comme pour l'invulnérabilité — c'est son type qui annule le
          // coup, pas l'attaquant qui a mal visé.
          // Statut exigé sur la cible et absent (voir requires_status_failed) :
          // la capacité ne pouvait pas fonctionner, le texte s'affiche donc
          // aussi sur la CIBLE — c'est son état qui décide, pas la visée.
          setMissSide(turn.invulnerable_miss || turn.no_effect || turn.requires_status_failed ? hitSide : attackerSide)
          setMissLabel(turn.requires_status_failed ? 'Échec !' : turn.no_effect ? 'Aucun effet !' : turn.invulnerable_miss ? 'Invulnérable !' : 'MANQUÉ')
          setMissKey((k) => k + 1)
          // Le pokémon protégé reste estompé — le bouclier peut encore
          // bloquer d'autres coups si l'adversaire enchaîne une rafale (voir
          // playerShieldSeenOpponentTurn/opponentShieldSeenPlayerTurn plus
          // haut) ; il ne s'efface qu'au début du PROCHAIN tour de son
          // propriétaire, jamais ici.

          const abilityNom = turn.ability_nom ?? (attackerSide === 'player' ? playerAbilityNom : opponentAbilityNom)
          const ability = attacksByName?.get(abilityNom)

          pushHistory(
            attackerSide,
            turn.requires_status_failed
              ? { before: `a utilisé ${sideInfo(attackerSide, turn).ability} — sans effet hors `, status: turn.requires_status!, after: '' }
              : turn.no_effect
              ? `a utilisé ${sideInfo(attackerSide, turn).ability} — aucun effet sur ce type`
              : `a manqué son attaque ${sideInfo(attackerSide, turn).ability}`,
            {
              // Un coup arrêté par l'invulnérabilité adverse, une immunité de
              // type ou un statut exigé absent n'a rien à voir avec la
              // précision (le serveur court-circuite le jet) : pas de détail à
              // afficher dans ce cas.
              precisionFormula: isAdmin && !turn.invulnerable_miss && !turn.no_effect && !turn.requires_status_failed
                ? buildPrecisionDebug(ability?.precision, attackerPrecisionStatus, turn.precision_mod_amount ?? 0)
                : undefined,
            }
          )
          // Peur/confusion : cette attaque ratée (ou non) est précisément
          // celle sous l'effet révélé par le tick précédent (turns[i-1]) —
          // le badge a été délibérément laissé affiché jusqu'ici (voir le
          // bloc status_tick plus haut). Il ne disparaît que si CE tick a
          // effectivement guéri le statut (precedingTick.status_cured) : la
          // peur guérit toujours en un coup, mais la confusion peut persister
          // (comme le sommeil) et le badge doit alors rester affiché pour les
          // tours suivants.
          if (attackerPrecisionStatus && precedingTick?.status_cured && !statusReapplied) {
            if (attackerSide === 'player') setPlayerStatus(null)
            else setOpponentStatus(null)
          }
          window.setTimeout(() => setMissSide(null), FLYING_TEXT_MS)
          return
        }

        if (hitSide === 'player') setPlayerHp(turn.defender_hp_after)
        else setOpponentHp(turn.defender_hp_after)
        // 'Stomp' écrase la cible (compression sur l'axe Y) au lieu de la
        // secouer — les deux passent par la même propriété CSS `animation`
        // sur le conteneur du sprite, donc jamais les deux à la fois (voir
        // spriteContainerStyle).
        if (battleAnimationSquashesTarget(attackAnimation)) {
          setSquashSide(hitSide)
          window.setTimeout(() => setSquashSide(null), SQUASH_MS)
        } else {
          setShakeSide(hitSide)
          window.setTimeout(() => setShakeSide(null), SHAKE_MS)
        }
        // Pas de flash rouge pour un coup à 0 dégât (capacité non-offensive,
        // voir attacks.deals_damage) — rien n'a été touché, l'effet visuel
        // d'impact n'a pas de sens.
        if (turn.damage > 0) setFlashSide(hitSide)
        setLastDamage({ side: hitSide, damage: turn.damage, superEffective: isSuperEffective })
        setHitKey((k) => k + 1)
        if (turn.damage > 0) window.setTimeout(() => setFlashSide(null), FLASH_MS)

        const abilityNom = turn.ability_nom ?? (attackerSide === 'player' ? playerAbilityNom : opponentAbilityNom)
        const ability = attacksByName?.get(abilityNom)
        const precisionFormula = isAdmin
          ? buildPrecisionDebug(ability?.precision, attackerPrecisionStatus, turn.precision_mod_amount ?? 0)
          : undefined

        // Détail complet du calcul de dégâts/soin en admin — voir
        // AutoBattleTurn.damage_species_xp/damage_dice (fournis PAR TOUR par
        // le serveur, mêmes composantes que v_player_damage/v_opponent_damage
        // — voir autobattle_resolve_battle/autobattle_resolve_manual_round).
        // "additionnel" regroupe TOUT ce qui n'est ni la base ni le dé
        // (modificateur de stat, dégâts additionnels conditionnels...) —
        // volontairement pas détaillé, juste le delta constaté.
        const rule = abilityRulesByName?.get(abilityNom)
        let damageFormula: string | undefined
        if (isAdmin && ability?.deals_damage !== false) {
          if (turn.percent_hp_damage) {
            const percent = rule?.percent_hp_damage_percent
            if (percent != null) {
              // Base du calcul : les PV RESTANTS avant le coup (reconstruits
              // depuis defender_hp_after + damage) ou les PV MAX de la cible,
              // selon percent_hp_damage_basis — voir describeAbilityRule.
              const onMaxHp = rule?.percent_hp_damage_basis === 'max'
              const hpBefore = onMaxHp
                ? (hitSide === 'player' ? playerMaxHp : opponentMaxHp)
                : turn.defender_hp_after + turn.damage
              const computed = Math.floor(hpBefore * percent / 100)
              const extra = turn.damage - computed
              damageFormula = `${percent}% des PV ${onMaxHp ? 'max' : 'restants'} de la cible (${hpBefore})`
              if (extra !== 0) damageFormula += ` ${extra > 0 ? '+' : '-'} ${Math.abs(extra)} (additionnel)`
              damageFormula += ` = ${turn.damage}`
            }
          } else if (turn.damage_species_xp != null && turn.damage_dice != null) {
            const speciesXp = turn.damage_species_xp
            const abilityBase = ability?.degats_base ?? 0
            const dice = turn.damage_dice
            const typeMult = isSuperEffective ? 2 : 1
            const extra = turn.damage - (speciesXp * typeMult + abilityBase + dice)
            damageFormula = `${speciesXp} (dégâts de base)`
            if (typeMult > 1) damageFormula += ` x${typeMult} (super efficace)`
            damageFormula += ` + ${abilityBase} (dégâts de la capacité)`
            if (dice > 0) damageFormula += ` + ${dice} (dé)`
            if (extra !== 0) damageFormula += ` ${extra > 0 ? '+' : '-'} ${Math.abs(extra)} (additionnel)`
            damageFormula += ` = ${turn.damage}`
          }
        }

        let healFormula: string | undefined
        if (isAdmin && turn.heal != null && turn.heal > 0) {
          if (rule?.heal_type === 'static') {
            healFormula = `${rule.heal_amount ?? turn.heal} (montant fixe) = ${turn.heal}`
          } else if (rule?.heal_type === 'percent_damage' && rule.heal_percent != null) {
            healFormula = `${rule.heal_percent}% des dégâts infligés (${turn.damage}) = ${turn.heal}`
          } else if (rule?.heal_type === 'use_stats' && turn.damage_species_xp != null) {
            // Contrairement aux dégâts, un soin basé sur les stats n'est
            // JAMAIS doublé par l'efficacité de type (voir supabase/schema.sql
            // autobattle_combatant_ability.type_bonus) — pas de typeMult ici.
            const speciesXp = turn.damage_species_xp
            const abilityBase = ability?.degats_base ?? 0
            const healDice = turn.heal - speciesXp - abilityBase
            healFormula = `${speciesXp} (dégâts de base) + ${abilityBase} (dégâts de la capacité)`
            if (healDice > 0) healFormula += ` + ${healDice} (dé)`
            healFormula += ` = ${turn.heal}`
          }
        }

        pushHistory(attackerSide, `a utilisé ${sideInfo(attackerSide, turn).ability}`, {
          damage: turn.damage,
          heal: turn.heal,
          superEffective: isSuperEffective,
          precisionFormula,
          damageFormula,
          healFormula,
        })

        // Peur/confusion : même principe que côté raté ci-dessus — cette
        // attaque réussie était celle sous l'effet révélé par le tick
        // précédent (turns[i-1]), le badge ne disparaît que si ce tick a
        // effectivement guéri le statut (avant un éventuel NOUVEAU statut
        // appliqué par ce même coup plus bas, qui écrasera cet effacement le
        // cas échéant).
        if (attackerPrecisionStatus && precedingTick?.status_cured && !statusReapplied) {
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

        // Bouclier Prévention de la cible : ce coup a bien touché, mais sans
        // son bonus de dégâts "super efficace" (voir autobattle_ability_
        // rules.prevention_duration_turns).
        if (turn.prevention_blocked) {
          pushHistory(hitSide, 'sa Prévention annule les dégâts supplémentaires du coup super efficace')
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

        // Purges jouées par ce coup sur son AUTEUR (voir
        // autobattle_ability_rules.clear_damage_dot / cure_status) : le badge
        // de statut s'éteint ici, les dégâts sur la durée n'ont pas de badge
        // et ne laissent qu'une ligne d'historique. La météo dissipée, elle,
        // arrive dans un tour weather_tick séparé (voir plus haut).
        if (turn.cleanse_dot) {
          pushHistory(attackerSide, 'dissipe les effets persistants qui le rongeaient')
        }
        if (turn.cleanse_status) {
          if (attackerSide === 'player') setPlayerStatus(null)
          else setOpponentStatus(null)
          pushHistory(attackerSide, { before: 'se soigne de ', status: turn.cleanse_status, after: '' })
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
    playerShieldSeenOpponentTurnRef.current = playerShieldSeenOpponentTurn
    opponentShieldSeenPlayerTurnRef.current = opponentShieldSeenPlayerTurn
    playerReleasingRef.current = playerReleasing
    opponentReleasingRef.current = opponentReleasing

    timers.push(window.setTimeout(() => {
      setBattleDone(true)
      // Combat Manuel (hideContinueButton) : pas de bouton "Continuer" à
      // cliquer, on signale nous-mêmes la fin d'animation de ce tour dès
      // qu'elle arrive, pour que ManualBattleScreen redonne la main au
      // joueur (ou transitionne vers récompense/défaite si l'issue est
      // connue) — voir onContinue.
      if (hideContinueButton) onContinue()
    }, cursor + 200))
    return () => {
      timers.forEach(clearTimeout)
      // Nettoyage AVANT toute animation : ce lot de tours n'a rien montré et
      // ses timers viennent d'être annulés. Il faut donc le rendre "non
      // programmé", sinon la garde en tête d'effet le croit déjà joué et plus
      // rien ne se passe — combat figé, grille de capacités verrouillée.
      // Se produit systématiquement en dev (StrictMode ré-exécute l'effet), et
      // uniquement quand `turns` est déjà non vide au montage : c'est le cas
      // depuis que les tours de talent d'ouverture amorcent le journal.
      if (flushed) return
      scheduledCountRef.current = refsAtStart.scheduledCount
      streakRef.current = refsAtStart.streak
      prevStreakAttackerRef.current = refsAtStart.prevStreakAttacker
      battleStartRef.current = refsAtStart.battleStart
      playerShieldActiveRef.current = refsAtStart.playerShieldActive
      opponentShieldActiveRef.current = refsAtStart.opponentShieldActive
      playerShieldSeenOpponentTurnRef.current = refsAtStart.playerShieldSeenOpponentTurn
      opponentShieldSeenPlayerTurnRef.current = refsAtStart.opponentShieldSeenPlayerTurn
      playerReleasingRef.current = refsAtStart.playerReleasing
      opponentReleasingRef.current = refsAtStart.opponentReleasing
    }
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

  const playerAttackStyle = attackState?.side === 'player' ? attackTransform(attackState.phase, 1, attackState.durations, attackState.animation, reachPx) : undefined
  const opponentAttackStyle = attackState?.side === 'opponent' ? attackTransform(attackState.phase, -1, attackState.durations, attackState.animation, reachPx) : undefined

  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-4 relative">
        {/* Le camp qui attaque passe au-dessus de l'autre colonne : sans ça,
            un sprite qui bondit sur l'adversaire (ou un rayon/projectile qui
            le traverse) passerait derrière lui, le joueur étant le premier des
            deux dans le DOM. */}
        <div ref={playerColRef} className={`flex flex-col items-center gap-2 relative ${attackState?.side === 'player' ? 'z-10' : ''}`}>
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
            style={spriteContainerStyle(playerAttackStyle, shakeSide === 'player', squashSide === 'player')}
          >
            {playerSpriteSrc ? (
              <img
                src={playerSpriteSrc}
                alt=""
                // Cas Métamorph (sprite copié de l'adversaire, voir
                // playerImageOverride) : retourné en miroir sur l'axe X pour
                // rester visuellement distinguable du vrai pokémon adverse,
                // même sprite affiché des deux côtés du terrain.
                style={playerImageOverride ? { transform: 'scaleX(-1)' } : undefined}
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
            {lastDamage?.side === 'player' && lastDamage.damage > 0 && (
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
            {talentSide === 'player' && (
              <AutoBattleFloatingText text={talentLabel} animKey={talentKey} className="text-[#f0c419]" />
            )}
            {healSide === 'player' && lastHeal?.side === 'player' && (
              <AutoBattleHealEffect amount={lastHeal.amount} animKey={healKey} />
            )}
            {diceRoll?.side === 'player' && (
              <AutoBattleDiceRoll value={diceRoll.value} animKey={diceKey} />
            )}
            {/* Rayon/projectile lancé par ce camp — monté dans le conteneur du
                sprite attaquant, dont le centre sert d'origine (voir
                AutoBattleAttackVfx). La clé le remonte à chaque coup pour
                relancer l'animation CSS depuis le début. */}
            {attackVfx?.side === 'player' && (
              <AutoBattleAttackVfx key={vfxKey} kind={attackVfx.kind} color={attackVfx.color} sign={1} reachPx={reachPx} travelMs={attackVfx.travelMs} damage={attackVfx.damage} />
            )}
          </div>
        </div>

        <div ref={opponentColRef} className={`flex flex-col items-center gap-2 relative ${attackState?.side === 'opponent' ? 'z-10' : ''}`}>
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
            style={spriteContainerStyle(opponentAttackStyle, shakeSide === 'opponent', squashSide === 'opponent')}
          >
            {opponentSpriteSrc ? (
              <img
                src={opponentSpriteSrc}
                alt=""
                style={opponentImageOverride ? { transform: 'scaleX(-1)' } : undefined}
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
            {lastDamage?.side === 'opponent' && lastDamage.damage > 0 && (
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
            {talentSide === 'opponent' && (
              <AutoBattleFloatingText text={talentLabel} animKey={talentKey} className="text-[#f0c419]" />
            )}
            {healSide === 'opponent' && lastHeal?.side === 'opponent' && (
              <AutoBattleHealEffect amount={lastHeal.amount} animKey={healKey} />
            )}
            {diceRoll?.side === 'opponent' && (
              <AutoBattleDiceRoll value={diceRoll.value} animKey={diceKey} />
            )}
            {attackVfx?.side === 'opponent' && (
              <AutoBattleAttackVfx key={vfxKey} kind={attackVfx.kind} color={attackVfx.color} sign={-1} reachPx={reachPx} travelMs={attackVfx.travelMs} damage={attackVfx.damage} />
            )}
          </div>
        </div>
      </div>

      {/* Jauges de PV des DEUX camps sur une seule rangée, séparées par une
          colonne centrale étroite réservée à la pastille de météo. Elles
          étaient auparavant dans leur colonne respective, la pastille venant
          se poser en absolu par-dessus : sur mobile elle chevauchait les deux
          jauges. Ici le chevauchement est impossible par construction, quelle
          que soit la largeur d'écran, et chaque jauge prend tout le reste de la
          place (flex-1). La colonne centrale garde sa largeur même sans météo :
          la mise en page ne bouge pas quand une météo se lève en cours de
          combat. Sortir les jauges de la grille des sprites les aligne au
          passage à la même hauteur, même quand un nom de pokémon se replie sur
          deux lignes d'un seul côté.
          -mt-2 : rattrape le gap-4 du conteneur pour retrouver l'écart d'origine
          entre le bas des sprites et les jauges (gap-2). */}
      <div className="flex items-end gap-1 -mt-2">
        <div className="flex-1 min-w-0">
          <HpGauge current={Math.max(0, playerHp)} max={playerMaxHp} valueAlign="left" />
        </div>
        {/* Largeur figée à celle de la pastille (w-8) : le strict minimum
            réservé au centre, tout le reste va aux deux jauges. */}
        <div className="relative w-8 shrink-0 flex justify-center">
          {/* Fond transparent : seule l'icône se voit, mais le bouton garde sa
              surface cliquable. Un clic ouvre la description, générée côté
              serveur (voir autobattle_weather_details). */}
          {activeWeather && (
            <>
              <button
                type="button"
                // Pas de bascule on/off au reclic : le pointerdown de fermeture
                // (capture, voir l'effet plus haut) part AVANT le click, un
                // toggle rouvrirait donc systématiquement. Recliquer ré-affiche
                // simplement la bulle — comportement identique aux talents.
                onClick={() => setWeatherTipOpen(true)}
                title={activeWeather.nom}
                aria-label={`Météo : ${activeWeather.nom}`}
                className="w-8 h-8 rounded-full flex items-center justify-center text-xl leading-none bg-transparent animate-[celebrate-pop_0.52s_ease-out]"
              >
                {activeWeather.icon || '🌦️'}
              </button>
              {weatherTipOpen && (
                <div
                  role="tooltip"
                  // Hors du flux : la bulle ne doit jamais pousser ce qui suit
                  // vers le bas quand elle s'ouvre.
                  className={`absolute z-20 top-full left-1/2 -translate-x-1/2 mt-1 w-56 max-w-[80vw] p-2 rounded bg-white text-ink text-xs leading-snug flex flex-col gap-1 ${PIXEL_BORDER_SM} shadow-[var(--shadow-pixel)]`}
                >
                  <span className="font-bold">{activeWeather.nom}</span>
                  {activeWeather.details.length === 0 ? (
                    <span className="text-ink-muted-2">Aucun effet direct.</span>
                  ) : (
                    activeWeather.details.map((line, i) => <span key={i}>{line}</span>)
                  )}
                </div>
              )}
            </>
          )}
        </div>
        <div className="flex-1 min-w-0">
          <HpGauge current={Math.max(0, opponentHp)} max={opponentMaxHp} />
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
        </div>
      )}

      {midSlot}

      {fighting && (
        <AutoBattleHistoryLog
          entries={historyEntries}
          isAdmin={isAdmin}
        />
      )}
    </div>
  )
}
