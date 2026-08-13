import type { CSSProperties } from 'react'

// ─────────────────────────────────────────────────────────────────────────────
// Animations d'attaque du Combat Auto/Manuel (AutoBattleScreen)
//
// PUREMENT VISUEL : aucune de ces animations n'a le moindre effet sur la
// résolution du combat (toujours décidée par le serveur, voir
// autobattle_resolve_battle). Elles sont choisies PAR CAPACITÉ depuis le CSV
// des attaques (colonnes "Animation" et "Animation 2"), pas en admin — au même
// titre que les dégâts ou le statut mini-jeu de la capacité.
//
// "Animation 2" ne sert qu'aux capacités en DEUX TOURS (autobattle_ability_
// rules.turn_effect = 'prepare_release') : le 1er tour (préparation) joue
// "Animation", le 2e (libération, celui qui inflige les dégâts) joue
// "Animation 2" — typiquement "Idle" puis "Beam". Toute capacité utilisée
// plusieurs fois dans le même tour (play_twice/play_three/...) rejoue
// simplement son animation à chaque activation : c'est automatique, chaque
// activation étant un tour distinct du journal renvoyé par le serveur.
//
// Toutes les animations tiennent dans la MÊME enveloppe de temps que le bond
// historique ("Jump Attack") : cinq phases dont les durées viennent de
// l'appelant, l'impact (dégâts/secousse/nombre flottant) tombant toujours à la
// fin de 'strike-land'. Aucune animation ne peut donc allonger ou raccourcir
// un tour — le rythme du combat reste identique quel que soit le choix fait
// dans le CSV.
// ─────────────────────────────────────────────────────────────────────────────

export type BattleAnimationId =
  | 'idle'
  | 'jump_attack'
  | 'strike'
  | 'stomp'
  | 'beam'
  | 'projectile'
  | 'multi_projectile'
  | 'bomb'
  | 'round_motion'
  | 'jump'
  | 'fade'

export type BattleAnimationPhase = 'anticipation' | 'lunge' | 'strike-rise' | 'strike-land' | 'return'

/** Durées (ms) des phases du tour en cours — sous-ensemble de PhaseDurations (AutoBattleScreen). */
export interface BattleAnimationDurations {
  anticipation: number
  lunge: number
  strikeRise: number
  strikeLand: number
  return: number
}

/** Effet projeté vers la cible, rendu par AutoBattleAttackVfx. */
export type BattleVfxKind = 'beam' | 'projectile' | 'multi_projectile' | 'bomb'

// Distance (px) entre le centre des deux sprites, utilisée par défaut tant que
// l'écran de combat n'a pas pu la mesurer (voir AutoBattleScreen : elle dépend
// de la largeur réelle du popup, ~175px sur mobile mais plus sur tablette).
// C'est elle qui fait atterrir un bond, un rayon ou un projectile exactement
// sur l'adversaire.
export const BATTLE_DEFAULT_REACH_PX = 175

interface BattleAnimationSpec {
  /** Libellé affiché (et valeur attendue dans la colonne "Animation" du CSV). */
  label: string
  /** Déplacement de l'attaquant phase par phase. Absent si l'animation est jouée par keyframes CSS. `reach` = distance jusqu'au centre du sprite adverse. */
  transform?: (phase: BattleAnimationPhase, sign: 1 | -1, d: BattleAnimationDurations, reach: number) => CSSProperties
  /** Animation CSS (src/index.css) jouée d'un bloc sur toute la durée du tour, pour les mouvements que 5 phases ne suffisent pas à décrire (cercles, fondu). */
  keyframes?: string
  /** Effet envoyé vers la cible (rayon/projectile), coloré du type de la capacité. */
  vfx?: BattleVfxKind
  /** La cible est écrasée (compression sur l'axe Y) à l'impact au lieu d'être secouée. */
  squashTarget?: boolean
}

const move = (transform: string, ms: number, easing: string): CSSProperties => ({
  transform,
  transition: `transform ${ms}ms ${easing}`,
})

// Retour instantané à la position de départ ("téléportation", voir Strike) —
// jamais une transition de 0ms côté React : la propriété doit disparaître pour
// que le navigateur n'interpole rien du tout.
const teleportHome: CSSProperties = { transform: 'translate(0, 0) scale(1)', transition: 'none' }

const BATTLE_ANIMATIONS: Record<BattleAnimationId, BattleAnimationSpec> = {
  // Le pokémon reste sur place, juste un léger grossissement — pour les
  // capacités auto-ciblées (soin, buff…) où bondir n'aurait pas de sens.
  idle: {
    label: 'Idle',
    transform: (phase, _sign, d) => {
      switch (phase) {
        case 'anticipation': return move('scale(0.97)', d.anticipation, 'ease-out')
        case 'lunge': return move('scale(1.05)', d.lunge, 'ease-in')
        case 'strike-rise': return move('scale(1.12)', d.strikeRise, 'ease-out')
        case 'strike-land': return move('scale(1.16)', d.strikeLand, 'ease-in')
        case 'return': return move('scale(1)', d.return, 'ease-out')
      }
    },
  },

  // Animation par défaut (colonne "Animation" vide) : petit recul, bond en
  // avant, grand saut qui retombe sur l'adversaire, puis retour.
  jump_attack: {
    label: 'Jump Attack',
    transform: (phase, sign, d, reach) => {
      switch (phase) {
        case 'anticipation': return move(`translate(${sign * -8}px, 4px) scale(0.95)`, d.anticipation, 'ease-out')
        case 'lunge': return move(`translate(${sign * 20}px, -10px) scale(1.04)`, d.lunge, 'ease-in')
        case 'strike-rise': return move(`translate(${sign * reach * 0.69}px, -55px) scale(1.1)`, d.strikeRise, 'ease-out')
        case 'strike-land': return move(`translate(${sign * reach}px, -6px) scale(1.2)`, d.strikeLand, 'ease-in')
        case 'return': return move('translate(0, 0) scale(1)', d.return, 'ease-out')
      }
    },
  },

  // Recul, charge éclair vers l'adversaire, puis retour INSTANTANÉ à sa place
  // (pas de trajet retour visible) — d'où le teleportHome sur 'return'.
  strike: {
    label: 'Strike',
    transform: (phase, sign, d, reach) => {
      switch (phase) {
        case 'anticipation': return move(`translate(${sign * -22}px, 0) scale(0.96)`, d.anticipation, 'ease-out')
        case 'lunge': return move(`translate(${sign * -32}px, 0) scale(0.94)`, d.lunge, 'ease-out')
        case 'strike-rise': return move(`translate(${sign * reach * 0.55}px, 0) scale(1.1)`, d.strikeRise, 'ease-in')
        case 'strike-land': return move(`translate(${sign * reach}px, 0) scale(1.12)`, d.strikeLand, 'linear')
        case 'return': return teleportHome
      }
    },
  },

  // Grand saut au-dessus de l'adversaire puis écrasement vertical dessus — la
  // cible est compressée sur l'axe Y à l'impact (squashTarget) au lieu de la
  // secousse habituelle.
  stomp: {
    label: 'Stomp',
    squashTarget: true,
    transform: (phase, sign, d, reach) => {
      switch (phase) {
        case 'anticipation': return move('translate(0, 6px) scale(1.08, 0.82)', d.anticipation, 'ease-out')
        case 'lunge': return move(`translate(${sign * reach * 0.23}px, -62px) scale(0.94, 1.1)`, d.lunge, 'ease-out')
        case 'strike-rise': return move(`translate(${sign * reach}px, -96px) scale(1, 1.05)`, d.strikeRise, 'ease-out')
        case 'strike-land': return move(`translate(${sign * reach}px, 8px) scale(1.18, 0.92)`, d.strikeLand, 'ease-in')
        case 'return': return move('translate(0, 0) scale(1)', d.return, 'ease-out')
      }
    },
  },

  // Recul, charge sur place, puis rayon traversant l'adversaire (voir vfx).
  beam: {
    label: 'Beam',
    vfx: 'beam',
    transform: (phase, sign, d) => {
      switch (phase) {
        case 'anticipation': return move(`translate(${sign * -20}px, 0) scale(0.96)`, d.anticipation, 'ease-out')
        case 'lunge': return move(`translate(${sign * -26}px, 0) scale(1.06)`, d.lunge, 'ease-out')
        case 'strike-rise': return move(`translate(${sign * -22}px, 0) scale(1.12)`, d.strikeRise, 'ease-out')
        case 'strike-land': return move(`translate(${sign * -8}px, 0) scale(1.08)`, d.strikeLand, 'ease-out')
        case 'return': return move('translate(0, 0) scale(1)', d.return, 'ease-out')
      }
    },
  },

  projectile: {
    label: 'Projectile',
    vfx: 'projectile',
    transform: throwTransform(),
  },

  multi_projectile: {
    label: 'Multiple projectiles',
    vfx: 'multi_projectile',
    transform: throwTransform(),
  },

  // Même lancer, mais penché en arrière (le projectile part en cloche, voir
  // AutoBattleAttackVfx).
  bomb: {
    label: 'Bomb',
    vfx: 'bomb',
    transform: (phase, sign, d) => {
      switch (phase) {
        case 'anticipation': return move(`translate(${sign * -20}px, 0) rotate(${sign * -14}deg) scale(0.97)`, d.anticipation, 'ease-out')
        case 'lunge': return move(`translate(${sign * -28}px, -4px) rotate(${sign * -20}deg) scale(1.02)`, d.lunge, 'ease-out')
        case 'strike-rise': return move(`translate(${sign * 6}px, 0) rotate(${sign * 10}deg) scale(1.06)`, d.strikeRise, 'ease-in')
        case 'strike-land': return move(`translate(0, 0) rotate(0deg) scale(1.02)`, d.strikeLand, 'ease-out')
        case 'return': return move('translate(0, 0) rotate(0deg) scale(1)', d.return, 'ease-out')
      }
    },
  },

  // Deux petits cercles sur place : impossible à décrire avec 5 points de
  // passage, donc joué en keyframes CSS sur toute la durée du tour.
  round_motion: { label: 'Round motion', keyframes: 'battle-round-motion' },

  // Accroupissement puis saut sur place.
  jump: {
    label: 'Jump',
    transform: (phase, _sign, d) => {
      switch (phase) {
        case 'anticipation': return move('translate(0, 6px) scale(1.1, 0.8)', d.anticipation, 'ease-out')
        case 'lunge': return move('translate(0, -20px) scale(0.95, 1.08)', d.lunge, 'ease-out')
        case 'strike-rise': return move('translate(0, -36px) scale(1)', d.strikeRise, 'ease-out')
        case 'strike-land': return move('translate(0, 4px) scale(1.08, 0.9)', d.strikeLand, 'ease-in')
        case 'return': return move('translate(0, 0) scale(1)', d.return, 'ease-out')
      }
    },
  },

  // Disparition/réapparition — pensé pour les capacités qui rendent
  // invulnérable (autobattle_ability_rules.invulnerable_next_turn), dont le
  // bouclier estompe déjà le sprite ensuite.
  fade: { label: 'Fade', keyframes: 'battle-fade' },
}

// Lancer de projectile : petit recul, puis geste vers l'avant au moment où le
// projectile part (début de 'strike-rise', voir AutoBattleScreen) — partagé
// par Projectile et Multiple projectiles.
function throwTransform(): BattleAnimationSpec['transform'] {
  return (phase, sign, d) => {
    switch (phase) {
      case 'anticipation': return move(`translate(${sign * -20}px, 0) scale(0.96)`, d.anticipation, 'ease-out')
      case 'lunge': return move(`translate(${sign * -28}px, 0) scale(1.02)`, d.lunge, 'ease-out')
      case 'strike-rise': return move(`translate(${sign * 8}px, -4px) scale(1.08)`, d.strikeRise, 'ease-in')
      case 'strike-land': return move('translate(0, 0) scale(1.02)', d.strikeLand, 'ease-out')
      case 'return': return move('translate(0, 0) scale(1)', d.return, 'ease-out')
    }
  }
}

/** Ordre d'affichage (admin/documentation) — l'ordre du tableau fait foi. */
export const BATTLE_ANIMATION_IDS: BattleAnimationId[] = [
  'idle', 'jump_attack', 'strike', 'stomp', 'beam',
  'projectile', 'multi_projectile', 'bomb', 'round_motion', 'jump', 'fade',
]

export function getBattleAnimationLabel(id: BattleAnimationId): string {
  return BATTLE_ANIMATIONS[id].label
}

/** Effet projeté de cette animation (rayon/projectile), s'il y en a un. */
export function getBattleAnimationVfx(id: BattleAnimationId): BattleVfxKind | undefined {
  return BATTLE_ANIMATIONS[id].vfx
}

/** L'impact de cette animation écrase la cible (Stomp) au lieu de la secouer. */
export function battleAnimationSquashesTarget(id: BattleAnimationId): boolean {
  return BATTLE_ANIMATIONS[id].squashTarget === true
}

// Style appliqué au sprite de l'attaquant pour la phase en cours. `sign` vaut
// +1 pour le joueur (l'adversaire est à sa droite) et -1 pour l'adversaire.
// Les animations en keyframes ignorent la phase : elles renvoient toujours la
// même valeur (donc le navigateur ne relance rien à chaque changement de
// phase), l'animation couvrant d'un bloc la durée totale du tour.
export function battleAnimationStyle(
  id: BattleAnimationId,
  phase: BattleAnimationPhase,
  sign: 1 | -1,
  d: BattleAnimationDurations,
  reach: number
): CSSProperties {
  const spec = BATTLE_ANIMATIONS[id]
  if (spec.keyframes) {
    const total = d.anticipation + d.lunge + d.strikeRise + d.strikeLand + d.return
    return { animation: `${spec.keyframes} ${Math.round(total)}ms ease-in-out` }
  }
  return spec.transform!(phase, sign, d, reach)
}

// CSV des attaques (colonnes "Animation" / "Animation 2") → valeur interne.
// Insensible à la casse, aux espaces et aux tirets/underscores pour tolérer
// les saisies manuelles ("Jump attack", "jump_attack", "Multiple Projectiles").
const BATTLE_ANIMATION_BY_CSV_KEY: Record<string, BattleAnimationId> = {
  idle: 'idle',
  jumpattack: 'jump_attack',
  strike: 'strike',
  stomp: 'stomp',
  beam: 'beam',
  projectile: 'projectile',
  multipleprojectiles: 'multi_projectile',
  multipleprojectile: 'multi_projectile',
  multiprojectiles: 'multi_projectile',
  bomb: 'bomb',
  roundmotion: 'round_motion',
  jump: 'jump',
  fade: 'fade',
}

/** Une valeur non reconnue (ou vide) donne null : la capacité retombe alors sur son animation par défaut, voir AutoBattleScreen. */
export function parseBattleAnimationCsvLabel(label: string | undefined | null): BattleAnimationId | null {
  const key = label?.trim().toLowerCase().replace(/[\s_-]/g, '')
  if (!key) return null
  return BATTLE_ANIMATION_BY_CSV_KEY[key] ?? null
}
