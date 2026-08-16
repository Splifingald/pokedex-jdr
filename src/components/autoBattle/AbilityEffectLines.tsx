import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'

/** Nombre de lignes VISUELLES (après repli) montrées avant troncature. */
const MAX_LINES = 3

/** Interligne appliqué au bloc (= leading-tight de Tailwind) — sert aussi à calculer la hauteur max en em, donc valable quelle que soit la taille de texte de la carte hôte. */
const LINE_HEIGHT = 1.25

/** Durée d'affichage de la bulle (ms) — plus longue que celle de la météo (3 s) : ce qu'elle déplie fait justement plusieurs lignes à lire. */
const TIP_DURATION = 8000

interface Props {
  /** Lignes d'effet de la capacité (voir describeAbilityRule) — une entrée = une phrase, qui peut elle-même se replier sur plusieurs lignes visuelles. */
  lines: string[]
  /** Taille de texte de la carte hôte : `text-xs` en grille 2 colonnes (Combat Manuel), `text-sm` sur les listes pleine largeur. */
  textClassName?: string
}

// Effet d'une capacité affiché sur les cartes de sélection : certaines
// descriptions font 5-6 lignes sur mobile et noyaient le reste de la carte
// (nom, dégâts, statut). On n'en montre donc que les 3 premières lignes, la
// suite étant repliée derrière un bouton « … » qui ouvre le texte complet dans
// une bulle — même mise en scène que la pastille de météo d'AutoBattleScreen.
export function AbilityEffectLines({ lines, textClassName = 'text-xs' }: Props) {
  const wrapRef = useRef<HTMLDivElement>(null)
  const clampRef = useRef<HTMLDivElement>(null)
  const tipRef = useRef<HTMLDivElement>(null)
  const [truncated, setTruncated] = useState(false)
  const [open, setOpen] = useState(false)
  const [tipShift, setTipShift] = useState(0)
  const [tipAbove, setTipAbove] = useState(false)

  // Troncature détectée sur le rendu réel (scrollHeight vs hauteur visible) et
  // jamais sur `lines.length` : une seule phrase suffit à déborder dans une
  // carte étroite, alors que trois courtes tiennent parfois sans rien couper.
  // ResizeObserver : la largeur des cartes change sans que la fenêtre bouge
  // (rotation, apparition de la grille de capacités en Combat Manuel…).
  useLayoutEffect(() => {
    const el = clampRef.current
    if (!el) return
    const measure = () => setTruncated(el.scrollHeight - el.clientHeight > 1)
    measure()
    const observer = new ResizeObserver(measure)
    observer.observe(el)
    return () => observer.disconnect()
  }, [lines])

  // La bulle est plus large que la carte qui la porte (une capacité tient sur
  // une demi-largeur d'écran en Combat Manuel, la bulle fait ~14rem) : ancrée à
  // droite de la carte, elle sortirait de l'écran par la gauche pour la colonne
  // de gauche. On la recale donc dans la fenêtre APRÈS mesure, avant peinture
  // (useLayoutEffect) pour qu'elle n'apparaisse jamais décalée.
  useLayoutEffect(() => {
    if (!open) return
    const wrap = wrapRef.current
    const tip = tipRef.current
    if (!wrap || !tip) return
    // offsetWidth et pas getBoundingClientRect : insensible au décalage qu'on
    // s'apprête à appliquer, donc stable si l'effet est rejoué.
    const width = tip.offsetWidth
    const rect = wrap.getBoundingClientRect()
    const left = rect.right - width
    const margin = 8
    if (left < margin) setTipShift(margin - left)
    else if (left + width > window.innerWidth - margin) setTipShift(window.innerWidth - margin - left - width)
    else setTipShift(0)
    // Même problème en vertical pour les dernières cartes de la liste : la
    // bulle ouverte sous elles tomberait hors de l'écran, et le scroll qu'il
    // faudrait faire pour la lire la referme (voir l'effet de fermeture).
    // Elle bascule donc au-dessus de la carte quand la place manque en dessous.
    setTipAbove(rect.bottom + tip.offsetHeight + margin > window.innerHeight && rect.top - tip.offsetHeight - margin > 0)
  }, [open])

  // Bulle éphémère : elle se ferme d'elle-même, ou dès que le joueur fait autre
  // chose — décalque de la bulle de météo (AutoBattleScreen). Capture sur
  // `document` et pas `window` : le scroll du corps de la popup de combat ne
  // remonte pas jusqu'à window, même en phase de capture.
  useEffect(() => {
    if (!open) return
    const close = () => setOpen(false)
    const timer = window.setTimeout(close, TIP_DURATION)
    document.addEventListener('pointerdown', close, true)
    document.addEventListener('scroll', close, true)
    window.addEventListener('resize', close)
    return () => {
      window.clearTimeout(timer)
      document.removeEventListener('pointerdown', close, true)
      document.removeEventListener('scroll', close, true)
      window.removeEventListener('resize', close)
    }
  }, [open])

  if (lines.length === 0) return null

  const openTip = (e: { preventDefault: () => void; stopPropagation: () => void }) => {
    // La carte entière est un <button> (sélection de la capacité) : sans ça, un
    // tap sur « … » lancerait aussi la capacité.
    e.preventDefault()
    e.stopPropagation()
    setOpen(true)
  }

  return (
    // bg-inherit sur toute la chaîne : le « … » doit masquer la fin de la
    // dernière ligne visible avec EXACTEMENT le fond de la carte hôte, dont la
    // couleur change (grise, jaune quand sélectionnée, crème…).
    <div ref={wrapRef} className={`relative w-full mt-0.5 bg-inherit ${textClassName}`}>
      <div
        ref={clampRef}
        className="relative overflow-hidden leading-tight text-ink-muted-2 bg-inherit"
        style={{ maxHeight: `${MAX_LINES * LINE_HEIGHT}em` }}
      >
        {lines.map((line, i) => (
          <span key={i} className="block">{line}</span>
        ))}
        {truncated && (
          // Posé EN ABSOLU au bout de la dernière ligne visible plutôt qu'ajouté
          // au fil du texte : il ne prend aucune ligne de plus (ce serait
          // l'inverse du but recherché) et rogne juste la fin de cette ligne,
          // déjà coupée de toute façon.
          // <span role="button"> et pas <button> : on est déjà à l'intérieur du
          // bouton de la carte, un bouton imbriqué serait du HTML invalide.
          <span
            role="button"
            tabIndex={0}
            onClick={openTip}
            onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') openTip(e) }}
            aria-label="Voir l'effet complet"
            title="Voir l'effet complet"
            className="absolute bottom-0 right-0 pl-2 leading-tight bg-inherit text-ink font-bold cursor-pointer"
          >
            …
          </span>
        )}
      </div>
      {open && (
        // Ancrée à droite de la carte puis recalée dans la fenêtre (voir
        // tipShift). Hors du flux : elle ne pousse jamais les cartes suivantes
        // vers le bas quand elle s'ouvre.
        <div
          ref={tipRef}
          role="tooltip"
          style={tipShift ? { transform: `translateX(${tipShift}px)` } : undefined}
          className={`absolute z-30 right-0 ${tipAbove ? 'bottom-full mb-1' : 'top-full mt-1'} w-56 max-w-[92vw] p-2 rounded bg-white text-ink text-xs leading-snug flex flex-col gap-1 ${PIXEL_BORDER_SM} shadow-[var(--shadow-pixel)]`}
        >
          {lines.map((line, i) => <span key={i}>{line}</span>)}
        </div>
      )}
    </div>
  )
}
