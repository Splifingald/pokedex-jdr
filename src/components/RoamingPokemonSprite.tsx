import { useMemo, useRef, useLayoutEffect, useEffect, type RefObject } from 'react'
import type { Pokemon, PlayerPokemon } from '../types'
import { useRoamPosition, setGlobalDragActive, subscribeGlobalDrag } from '../hooks/useRoamPosition'
import { useLocalHp } from '../hooks/useLocalHp'
import { getMaxHp } from '../lib/maxHp'
import { warmSpriteAlpha, isOpaqueAt } from '../lib/spriteAlpha'
import { PixelIcon } from './icons/PixelIcon'
import { GIFT_ICON } from '../lib/icons'
import { HpGauge } from './HpGauge'

interface Props {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  index: number
  isJumping: boolean
  hasGift?: boolean
  containerRef: RefObject<HTMLElement | null>
  onClick: () => void
}

// Pseudo-vitesse stable (1–5) dérivée du nom : le modèle de données n'a pas
// de stat de vitesse, mais on veut des allures de déambulation variées.
function speedBucket(nom: string): number {
  let h = 0
  for (let i = 0; i < nom.length; i++) h = (h * 31 + nom.charCodeAt(i)) | 0
  return (Math.abs(h) % 5) + 1
}

const CENTER = 'translateX(-50%)'

const DRAG_THRESHOLD_PX = 5

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), Math.max(min, max))
}

function pointInRect(clientX: number, clientY: number, rect: DOMRect): boolean {
  return clientX >= rect.left && clientX <= rect.right && clientY >= rect.top && clientY <= rect.bottom
}

export function RoamingPokemonSprite({ playerPokemon, pokemon, index, isJumping, hasGift = false, containerRef, onClick }: Props) {
  const speed = useMemo(() => speedBucket(playerPokemon.pokemon_nom), [playerPokemon.pokemon_nom])
  const { pos, duration, setPos } = useRoamPosition(playerPokemon.id, speed, containerRef)
  const maxHp = getMaxHp(playerPokemon, pokemon)
  const [hp] = useLocalHp(playerPokemon.id, maxHp)
  const isKo = hp <= 0

  const bobDuration = 2.2 + index * 0.35
  const bobDelay = index * 0.5

  const buttonRef = useRef<HTMLButtonElement>(null)
  const imgRef = useRef<HTMLImageElement>(null)
  const giftRef = useRef<HTMLSpanElement>(null)
  const hpGaugeRef = useRef<HTMLDivElement>(null)
  const prevRectRef = useRef<DOMRect | null>(null)
  // Un pointerdown sur un pixel transparent a soit été transmis au sprite
  // derrière, soit n'a rien trouvé — dans les deux cas le clic qui suit (sur
  // CE bouton, une fois `pointer-events` restauré) ne doit rien déclencher.
  const suppressClickRef = useRef(false)

  const imageSrc = pokemon?.image_miniature
  useEffect(() => {
    if (imageSrc) warmSpriteAlpha(imageSrc)
  }, [imageSrc])

  // État de drag — en refs pour ne pas re-render à chaque pointermove et
  // rester lisible immédiatement par les handlers/effets suivants.
  // `draggingRef` : le pointeur est actuellement capturé (entre pointerdown et pointerup).
  const draggingRef = useRef(false)
  // `dragMoveRef` : le tout dernier changement de `pos` vient d'un drag — lu
  // puis consommé (remis à false) par l'effet ci-dessous. Distinct de
  // `draggingRef` : ce dernier peut déjà repasser à false (pointerup) avant
  // que React n'ait eu le temps de rendre et exécuter l'effet pour le tout
  // dernier `setPos` du drag, ce qui ferait à tort relancer l'animation de
  // glissement au lieu de figer instantanément la position déposée.
  const dragMoveRef = useRef(false)
  // Distinct des deux précédents : ne devient vrai qu'après un vrai
  // déplacement (seuil dépassé), pour ne pas confondre un simple tap avec un drag.
  const movedRef = useRef(false)
  const dragStartRef = useRef<{ x: number; y: number; left: number; bottom: number; halfWPct: number; heightPct: number } | null>(null)

  // Le déplacement était animé via une transition CSS sur left/bottom : des
  // propriétés de layout, qui forcent un reflow à chaque frame et saccadent
  // le mouvement (surtout avec de grands sprites + drop-shadow). On anime
  // désormais via `transform` (accéléré GPU, pas de reflow) avec la technique
  // FLIP : on mesure le déplacement de layout, on l'annule instantanément par
  // un transform inverse, puis on relance une transition vers l'identité.
  // Pendant un drag manuel, on veut au contraire suivre le curseur au pixel
  // près sans lissage : on saute directement à l'identité, sans transition.
  useLayoutEffect(() => {
    const el = buttonRef.current
    if (!el) return
    const newRect = el.getBoundingClientRect()
    const prevRect = prevRectRef.current
    prevRectRef.current = newRect

    const wasDragMove = dragMoveRef.current
    dragMoveRef.current = false

    if (wasDragMove || !prevRect) {
      el.style.transition = 'none'
      el.style.transform = CENTER
      return
    }

    const dx = prevRect.left - newRect.left
    const dy = prevRect.top - newRect.top
    if (Math.abs(dx) < 0.5 && Math.abs(dy) < 0.5) return

    el.style.transition = 'none'
    el.style.transform = `${CENTER} translate(${dx}px, ${dy}px)`
    void el.offsetHeight // force le reflow avant de relancer la transition
    el.style.transition = `transform ${duration}s linear`
    el.style.transform = CENTER
  }, [pos.left, pos.bottom, duration])

  // Dès qu'un drag (ou un redimensionnement en cours de stabilisation)
  // démarre n'importe où sur la scène, on fige ce sprite à sa position
  // visuelle RÉELLE (comme la saisie manuelle ci-dessous) — et surtout pas en
  // sautant à `CENTER` (qui correspond à la position CIBLE `pos`, pas à
  // l'endroit où il est actuellement affiché en plein milieu d'un
  // glissement) : ça téléporterait instantanément le sprite jusqu'à sa
  // prochaine destination au lieu de simplement l'arrêter sur place.
  useEffect(() => {
    return subscribeGlobalDrag((active) => {
      if (!active || draggingRef.current) return
      const el = buttonRef.current
      const container = containerRef.current
      if (!el || !container) return
      const containerRect = container.getBoundingClientRect()
      const elRect = el.getBoundingClientRect()
      const visualLeft = ((elRect.left + elRect.width / 2 - containerRect.left) / containerRect.width) * 100
      const visualBottom = ((containerRect.bottom - elRect.bottom) / containerRect.height) * 100
      dragMoveRef.current = true
      setPos({ left: visualLeft, bottom: visualBottom })
    })
  }, [containerRef, setPos])

  // Le PNG a un fond transparent, mais le bouton occupe tout son rectangle :
  // sans ce test, cliquer/glisser sur une zone transparente « attraperait »
  // ce sprite même si un autre Pokémon est visible juste derrière. On exclut
  // d'abord les superpositions toujours cliquables (cadeau, jauge PV) qui
  // peuvent se trouver au-dessus d'une zone transparente de l'image.
  const hitsPokemonPixel = (clientX: number, clientY: number): boolean => {
    if (giftRef.current && pointInRect(clientX, clientY, giftRef.current.getBoundingClientRect())) return true
    if (hpGaugeRef.current && pointInRect(clientX, clientY, hpGaugeRef.current.getBoundingClientRect())) return true
    const img = imgRef.current
    if (!img || !imageSrc) return true
    return isOpaqueAt(imageSrc, img.getBoundingClientRect(), img.naturalWidth, img.naturalHeight, clientX, clientY)
  }

  const handlePointerDown = (e: React.PointerEvent<HTMLButtonElement>) => {
    const container = containerRef.current
    const el = buttonRef.current
    if (!container || !el) return

    if (!hitsPokemonPixel(e.clientX, e.clientY)) {
      // Pixel transparent : on s'efface temporairement pour voir ce qu'il y a
      // dessous, et on lui transmet le pointerdown — s'il capture le
      // pointeur (cas normal), tous les événements suivants (move/up/click)
      // lui sont automatiquement redirigés par le navigateur, sans rien de
      // plus à faire ici. S'il est lui-même transparent à cet endroit, son
      // propre handler refera la même transmission plus bas, en chaîne.
      el.style.pointerEvents = 'none'
      const below = document.elementFromPoint(e.clientX, e.clientY)?.closest<HTMLElement>('[data-roam-id]')
      el.style.pointerEvents = ''
      if (below && below !== el) {
        below.dispatchEvent(new PointerEvent('pointerdown', {
          bubbles: true,
          cancelable: true,
          clientX: e.clientX,
          clientY: e.clientY,
          pointerId: e.pointerId,
          pointerType: e.pointerType,
          isPrimary: e.isPrimary,
          button: e.button,
          buttons: e.buttons,
        }))
      }
      suppressClickRef.current = true
      return
    }

    const containerRect = container.getBoundingClientRect()
    const elRect = el.getBoundingClientRect()
    // Position visuelle RÉELLE au moment du contact — pas `pos` (l'état),
    // qui peut représenter la cible d'une déambulation encore en cours de
    // glissement : partir de `pos` ferait sauter le sprite sous le curseur
    // au lieu de le saisir là où il est vraiment affiché.
    const visualLeft = ((elRect.left + elRect.width / 2 - containerRect.left) / containerRect.width) * 100
    const visualBottom = ((containerRect.bottom - elRect.bottom) / containerRect.height) * 100

    // Fige immédiatement la position courante (annule toute déambulation en
    // cours) pour que la suite du drag reparte d'une base fiable, cohérente
    // avec ce qui est réellement affiché.
    draggingRef.current = true
    movedRef.current = false
    setGlobalDragActive(true)
    dragStartRef.current = {
      x: e.clientX,
      y: e.clientY,
      left: visualLeft,
      bottom: visualBottom,
      halfWPct: (elRect.width / 2 / containerRect.width) * 100,
      heightPct: (elRect.height / containerRect.height) * 100,
    }
    dragMoveRef.current = true
    setPos({ left: visualLeft, bottom: visualBottom })
    e.currentTarget.setPointerCapture(e.pointerId)
  }

  const handlePointerMove = (e: React.PointerEvent<HTMLButtonElement>) => {
    const start = dragStartRef.current
    const container = containerRef.current
    if (!start || !container || !draggingRef.current) return
    const dx = e.clientX - start.x
    const dy = e.clientY - start.y

    if (!movedRef.current && Math.hypot(dx, dy) >= DRAG_THRESHOLD_PX) {
      movedRef.current = true
    }

    const containerRect = container.getBoundingClientRect()
    const deltaLeftPct = (dx / containerRect.width) * 100
    const deltaBottomPct = -(dy / containerRect.height) * 100
    // `left` ancre le centre du sprite, `bottom` ancre son pied — les bornes
    // de la zone sûre diffèrent donc sur chaque axe (demi-largeur vs hauteur pleine).
    const nextLeft = clamp(start.left + deltaLeftPct, start.halfWPct, 100 - start.halfWPct)
    const nextBottom = clamp(start.bottom + deltaBottomPct, 0, 100 - start.heightPct)
    dragMoveRef.current = true
    setPos({ left: nextLeft, bottom: nextBottom })
  }

  const handlePointerUp = () => {
    draggingRef.current = false
    dragStartRef.current = null
    setGlobalDragActive(false)
  }

  const handleClick = () => {
    // Le pointerdown correspondant est tombé sur un pixel transparent (déjà
    // transmis au sprite derrière, ou sur rien) : ce clic-ci ne doit rien faire.
    if (suppressClickRef.current) {
      suppressClickRef.current = false
      return
    }
    // Un drag vient de se terminer sur ce même pointerup/click : on absorbe
    // le clic pour ne pas ouvrir la fiche du Pokémon par erreur.
    if (movedRef.current) {
      movedRef.current = false
      return
    }
    onClick()
  }

  return (
    <button
      ref={buttonRef}
      data-roam-id={playerPokemon.id}
      onClick={handleClick}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerUp}
      className="absolute flex flex-col items-center touch-none"
      style={{
        left: `${pos.left}%`,
        bottom: `${pos.bottom}%`,
        // Perspective : plus le Pokémon est bas dans la scène, plus il passe devant
        // (plage normale 10–32, sous le bouton scanner (35) et les overlays (40+)).
        // Borné à 1 : la scène ne crée pas son propre contexte d'empilement, donc
        // un z-index ≤ 0 ferait passer le sprite derrière le fond de son propre
        // conteneur (invisible) — ça n'arrivait jamais en déambulation naturelle
        // (bottom ≤ 30) mais un drag manuel peut monter bien plus haut.
        zIndex: Math.max(1, Math.round(40 - pos.bottom)),
      }}
    >
      {/* Couche saut : boucle continue (toutes les ~2s) tant qu'un cadeau est
          prêt, sinon saut ponctuel piloté par HomeTab */}
      <div
        style={
          hasGift
            ? { animation: 'jump-pop 2s ease-out infinite' }
            : isJumping
              ? { animation: 'jump-pop 0.55s ease-out 1' }
              : undefined
        }
      >
        {/* Couche flottement continu — conteneur transparent : simple zone cliquable,
            le Pokémon semble se déplacer librement dans la prairie */}
        <div
          className="relative w-[304px] h-[304px] max-w-[80vw] max-h-[45vh] flex items-center justify-center"
          style={{ animation: `idle-bob ${bobDuration}s ease-in-out ${bobDelay}s infinite` }}
        >
          {hasGift && (
            <span
              ref={giftRef}
              className="absolute top-[33%] left-[67%] -translate-x-1/2 -translate-y-1/2 z-10 [filter:drop-shadow(1px_2px_1px_rgba(0,0,0,0.4))]"
              style={{ animation: 'gift-wiggle 0.6s ease-in-out infinite' }}
            >
              <PixelIcon src={GIFT_ICON} size={64} />
            </span>
          )}
          {pokemon?.image_miniature ? (
            // w-full h-full (et pas max-w/max-h) : l'image est agrandie pour remplir
            // la boîte même si son fichier source est plus petit
            <img
              ref={imgRef}
              src={pokemon.image_miniature}
              alt={playerPokemon.pokemon_nom}
              draggable={false}
              onLoad={() => warmSpriteAlpha(pokemon.image_miniature)}
              className={`pixelated w-full h-full object-contain [filter:drop-shadow(2px_4px_2px_rgba(0,0,0,0.3))] ${isKo ? 'grayscale opacity-50' : ''}`}
            />
          ) : (
            <span className="text-[#14320f] text-4xl">?</span>
          )}

          {/* Jauge PV affichée seulement si le Pokémon n'est pas au max — à
              mi-chemin entre le centre et le bas de l'image */}
          {hp < maxHp && (
            <div ref={hpGaugeRef} className="absolute top-[75%] left-1/2 -translate-x-1/2 -translate-y-1/2 w-16 z-10">
              <HpGauge current={hp} max={maxHp} showValue={false} barBorderClassName="border-2 border-black" />
            </div>
          )}
        </div>
      </div>
    </button>
  )
}
