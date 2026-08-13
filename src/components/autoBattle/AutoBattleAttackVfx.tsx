import type { CSSProperties } from 'react'
import type { BattleVfxKind } from '../../lib/battleAnimations'

// Effets projetés vers l'adversaire (rayon, projectile(s), bombe) des
// animations d'attaque du Combat Auto/Manuel — voir src/lib/battleAnimations.ts.
//
// Monté DANS le conteneur du sprite de l'attaquant (voir AutoBattleScreen) :
// tout est donc positionné par rapport au centre de ce sprite, et `reachPx`
// (mesuré à l'écran, pas deviné) est la distance jusqu'au centre du sprite
// adverse — c'est ce qui fait arriver l'effet pile sur la cible quelle que
// soit la largeur du popup.
//
// La durée `travelMs` est celle des phases 'strike-rise' + 'strike-land' du
// tour en cours : l'effet atteint donc la cible exactement au moment où les
// dégâts sont appliqués, y compris sur les tours accélérés (capacité utilisée
// plusieurs fois d'affilée, voir speedMultiplierForRepeat).

interface Props {
  kind: BattleVfxKind
  /** Couleur du type de la capacité (voir TYPE_COLORS). */
  color: string
  /** +1 = l'attaquant est le joueur (tire vers la droite), -1 = l'adversaire. */
  sign: 1 | -1
  /** Distance mesurée jusqu'au centre du sprite adverse. */
  reachPx: number
  travelMs: number
  /** Dégâts infligés par ce coup — seul le rayon s'en sert, pour son épaisseur (voir beamScaleForDamage). */
  damage: number
}

// Le rayon dépasse l'adversaire ("traverse") plutôt que de s'arrêter dessus.
const BEAM_OVERSHOOT_PX = 55
// Épaisseur du rayon pour un coup "moyen" (BEAM_PIVOT_DAMAGE) — les autres
// dégâts la font varier autour de cette valeur, voir beamScaleForDamage.
const BEAM_THICKNESS_PX = 17

// Épaisseur du rayon selon les dégâts du coup : un coup à 25 (le pivot) donne
// l'épaisseur de référence, 50 et plus la doublent, 15 et moins la ramènent à
// 60 %. Entre ces bornes c'est linéaire par morceaux — deux pentes distinctes
// de part et d'autre du pivot, volontairement, pour que le palier "moyen"
// tombe pile sur 25 plutôt que sur le milieu de l'intervalle 15–50.
const BEAM_MIN_DAMAGE = 15
const BEAM_PIVOT_DAMAGE = 25
const BEAM_MAX_DAMAGE = 50
const BEAM_MIN_SCALE = 0.6
const BEAM_MAX_SCALE = 2

function beamScaleForDamage(damage: number): number {
  if (damage <= BEAM_MIN_DAMAGE) return BEAM_MIN_SCALE
  if (damage >= BEAM_MAX_DAMAGE) return BEAM_MAX_SCALE
  if (damage < BEAM_PIVOT_DAMAGE) {
    const ratio = (damage - BEAM_MIN_DAMAGE) / (BEAM_PIVOT_DAMAGE - BEAM_MIN_DAMAGE)
    return BEAM_MIN_SCALE + ratio * (1 - BEAM_MIN_SCALE)
  }
  const ratio = (damage - BEAM_PIVOT_DAMAGE) / (BEAM_MAX_DAMAGE - BEAM_PIVOT_DAMAGE)
  return 1 + ratio * (BEAM_MAX_SCALE - 1)
}

const PROJECTILE_SIZE_PX = 19
const MULTI_PROJECTILE_SIZE_PX = 12
const MULTI_PROJECTILE_COUNT = 5
// Décalage vertical de chacun des 5 petits projectiles à l'arrivée, pour
// qu'ils ne se superposent pas en une seule bille.
const MULTI_PROJECTILE_OFFSETS_PX = [-16, -8, 0, 8, 16]
// Hauteur de la cloche de la bombe (négatif = vers le haut).
const BOMB_ARC_PX = -70

// ── Palette d'un effet ──────────────────────────────────────────────────────
// Même traitement que les bulles de soin (AutoBattleHealEffect, #4ff08a cerné
// de #2fb85e) : un cœur clair entouré d'un contour épais plus sombre, plus une
// lueur de la couleur d'origine. Les deux teintes sont dérivées de la couleur
// du type de la capacité (TYPE_COLORS) plutôt que listées à la main, pour que
// n'importe quel type — y compris un nouveau — reste cohérent.

function parseHex(hex: string): [number, number, number] | null {
  const match = /^#?([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(hex.trim())
  if (!match) return null
  const digits = match[1].length === 3 ? match[1].replace(/./g, (c) => c + c) : match[1]
  return [0, 2, 4].map((i) => parseInt(digits.slice(i, i + 2), 16)) as [number, number, number]
}

/** amount > 0 = éclaircit vers le blanc, < 0 = assombrit vers le noir. */
function shade(hex: string, amount: number): string {
  const rgb = parseHex(hex)
  if (!rgb) return hex
  const apply = (c: number) => Math.round(amount >= 0 ? c + (255 - c) * amount : c * (1 + amount))
  return `rgb(${rgb.map(apply).join(', ')})`
}

// Éclaircissement volontairement modéré : au-delà, les couleurs de type
// (déjà claires pour la plupart) virent au pastel et on ne reconnaît plus le
// type de la capacité. C'est le CONTRASTE avec le contour, nettement assombri,
// qui donne l'effet "bulle", pas la pâleur du cœur.
function vfxPalette(color: string) {
  const rgb = parseHex(color)
  return {
    fill: shade(color, 0.25),
    outline: shade(color, -0.45),
    glow: rgb ? `rgba(${rgb.join(', ')}, 0.75)` : color,
  }
}

// Contour volontairement épais (comme les bulles de soin), proportionnel à la
// taille pour rester lisible aussi bien sur une petite bille que sur un rayon
// épaissi par de gros dégâts — plancher à 2px (en dessous le contour
// disparaît) et plafond à 5px (au delà il mange tout le cœur clair).
function outlineWidth(size: number): number {
  return Math.max(2, Math.min(5, Math.round(size * 0.18)))
}

// Les styles inline ci-dessous portent des variables CSS (--len, --tx, --ty,
// --arc) lues par les keyframes de index.css. CSSProperties ne connaît pas ces
// propriétés custom : on l'étend explicitement plutôt que de caster en
// CSSProperties (cast que TS refuse dès que le littéral vient d'un spread
// conditionnel, cf. le rayon plus bas).
type VfxStyle = CSSProperties & Record<`--${string}`, string>

function ballStyle(size: number, palette: ReturnType<typeof vfxPalette>): CSSProperties {
  return {
    position: 'absolute',
    left: -size / 2,
    top: -size / 2,
    width: size,
    height: size,
    borderRadius: '9999px',
    backgroundColor: palette.fill,
    border: `${outlineWidth(size)}px solid ${palette.outline}`,
    boxShadow: `0 0 ${Math.round(size * 0.7)}px ${Math.round(size * 0.25)}px ${palette.glow}`,
  }
}

export function AutoBattleAttackVfx({ kind, color, sign, reachPx, travelMs, damage }: Props) {
  const travelPx = reachPx * sign
  const palette = vfxPalette(color)

  if (kind === 'beam') {
    const length = reachPx + BEAM_OVERSHOOT_PX
    const thickness = Math.round(BEAM_THICKNESS_PX * beamScaleForDamage(damage))
    return (
      <div
        className="absolute pointer-events-none"
        style={{
          top: `calc(50% - ${thickness / 2}px)`,
          // Le rayon jaillit du centre du sprite : son bord d'origine y est
          // collé (left pour le joueur, right pour l'adversaire) et c'est sa
          // LARGEUR qui grandit vers la cible — pas un scaleX, qui écraserait
          // le contour latéral pendant la croissance.
          ...(sign === 1 ? { left: '50%' } : { right: '50%' }),
          height: thickness,
          borderRadius: '9999px',
          backgroundColor: palette.fill,
          border: `${outlineWidth(thickness)}px solid ${palette.outline}`,
          boxShadow: `0 0 ${Math.round(thickness * 0.8)}px ${Math.round(thickness * 0.25)}px ${palette.glow}`,
          '--len': `${length}px`,
          animation: `battle-beam ${travelMs}ms ease-out forwards`,
        } as VfxStyle}
      />
    )
  }

  // Point d'ancrage de taille nulle au centre du sprite : tous les
  // projectiles animent un translate depuis ce point, sans avoir à composer
  // avec un centrage en pourcentage.
  const anchorProps = { className: 'absolute left-1/2 top-1/2 w-0 h-0 pointer-events-none' as const }

  if (kind === 'projectile') {
    return (
      <div {...anchorProps}>
        <div
          style={{
            ...ballStyle(PROJECTILE_SIZE_PX, palette),
            '--tx': `${travelPx}px`,
            animation: `battle-projectile ${travelMs}ms linear forwards`,
          } as VfxStyle}
        />
      </div>
    )
  }

  if (kind === 'multi_projectile') {
    // Départ échelonné, mais tous arrivés à l'impact : chaque projectile part
    // un peu plus tard et vole d'autant plus vite (durée réduite du retard).
    const stagger = travelMs * 0.09
    return (
      <div {...anchorProps}>
        {MULTI_PROJECTILE_OFFSETS_PX.slice(0, MULTI_PROJECTILE_COUNT).map((offset, i) => (
          <div
            key={i}
            style={{
              ...ballStyle(MULTI_PROJECTILE_SIZE_PX, palette),
              '--tx': `${travelPx}px`,
              '--ty': `${offset}px`,
              animation: `battle-projectile-multi ${travelMs - stagger * (MULTI_PROJECTILE_COUNT - 1)}ms linear ${stagger * i}ms forwards`,
            } as VfxStyle}
          />
        ))}
      </div>
    )
  }

  // Bombe : deux calques imbriqués — l'extérieur avance linéairement sur X,
  // l'intérieur décrit la cloche sur Y. C'est ce découplage qui donne la
  // trajectoire en U inversé (impossible à obtenir avec un seul translate
  // interpolé linéairement).
  return (
    <div {...anchorProps}>
      <div
        className="absolute"
        style={{
          '--tx': `${travelPx}px`,
          animation: `battle-bomb-x ${travelMs}ms linear forwards`,
        } as VfxStyle}
      >
        <div
          className="absolute"
          style={{
            '--arc': `${BOMB_ARC_PX}px`,
            animation: `battle-bomb-y ${travelMs}ms linear forwards`,
          } as VfxStyle}
        >
          <div style={ballStyle(PROJECTILE_SIZE_PX, palette)} />
        </div>
      </div>
    </div>
  )
}
