import { useMemo, useRef, useLayoutEffect, type RefObject } from 'react'
import type { Pokemon, PlayerPokemon } from '../types'
import { useRoamPosition } from '../hooks/useRoamPosition'
import { useLocalHp } from '../hooks/useLocalHp'
import { getMaxHp } from '../lib/maxHp'

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

export function RoamingPokemonSprite({ playerPokemon, pokemon, index, isJumping, hasGift = false, containerRef, onClick }: Props) {
  const speed = useMemo(() => speedBucket(playerPokemon.pokemon_nom), [playerPokemon.pokemon_nom])
  const { pos, duration } = useRoamPosition(playerPokemon.id, speed, containerRef)
  const maxHp = getMaxHp(playerPokemon, pokemon)
  const [hp] = useLocalHp(playerPokemon.id, maxHp)
  const isKo = hp <= 0

  const bobDuration = 2.2 + index * 0.35
  const bobDelay = index * 0.5

  const buttonRef = useRef<HTMLButtonElement>(null)
  const prevRectRef = useRef<DOMRect | null>(null)

  // Le déplacement était animé via une transition CSS sur left/bottom : des
  // propriétés de layout, qui forcent un reflow à chaque frame et saccadent
  // le mouvement (surtout avec de grands sprites + drop-shadow). On anime
  // désormais via `transform` (accéléré GPU, pas de reflow) avec la technique
  // FLIP : on mesure le déplacement de layout, on l'annule instantanément par
  // un transform inverse, puis on relance une transition vers l'identité.
  useLayoutEffect(() => {
    const el = buttonRef.current
    if (!el) return
    const newRect = el.getBoundingClientRect()
    const prevRect = prevRectRef.current
    prevRectRef.current = newRect

    if (!prevRect) {
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

  return (
    <button
      ref={buttonRef}
      onClick={onClick}
      className="absolute flex flex-col items-center"
      style={{
        left: `${pos.left}%`,
        bottom: `${pos.bottom}%`,
        // Perspective : plus le Pokémon est bas dans la scène, plus il passe devant
        // (plage 10–32, sous le bouton scanner (35) et les overlays (40+)).
        // Le pied de croix "bottom" du bouton doit correspondre au pied du sprite —
        // la pastille PV est donc positionnée en absolu plus bas (voir ci-dessous)
        // pour ne pas décaler cette ancre vers le bas quand elle est affichée.
        zIndex: Math.round(40 - pos.bottom),
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
              className="absolute top-2 right-6 text-4xl z-10 [filter:drop-shadow(1px_2px_1px_rgba(0,0,0,0.4))]"
              style={{ animation: 'gift-wiggle 0.6s ease-in-out infinite' }}
            >
              🎁
            </span>
          )}
          {pokemon?.image_miniature ? (
            // w-full h-full (et pas max-w/max-h) : l'image est agrandie pour remplir
            // la boîte même si son fichier source est plus petit
            <img
              src={pokemon.image_miniature}
              alt={playerPokemon.pokemon_nom}
              className={`pixelated w-full h-full object-contain [filter:drop-shadow(2px_4px_2px_rgba(0,0,0,0.3))] ${isKo ? 'grayscale opacity-50' : ''}`}
            />
          ) : (
            <span className="text-[#14320f] text-4xl">?</span>
          )}
        </div>
      </div>

      {/* PV affichés seulement si le Pokémon n'est pas au max — positionné en
          absolu (hors flux) pour ne pas déplacer le bas réel du bouton, qui
          doit rester aligné sur les pieds du sprite pour le calcul du zIndex */}
      {hp < maxHp && (
        <span className="absolute top-full left-1/2 -translate-x-1/2 mt-1 px-1.5 py-0.5 rounded text-xs text-[#14320f] bg-cream/90 whitespace-nowrap">
          {hp}/{maxHp} PV
        </span>
      )}
    </button>
  )
}
