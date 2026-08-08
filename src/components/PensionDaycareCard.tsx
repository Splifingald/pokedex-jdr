import { useState, useEffect } from 'react'
import type { Pokemon, PlayerPokemon, Player, PensionConfig } from '../types'
import { ownedPokemonName } from '../types'
import { getMaxXp } from '../lib/xpBonuses'
import { computeProjectedDaycareXp, type ApplicablePensionSettings } from '../lib/pension'
import { PensionXpBar } from './PensionXpBar'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  owner: Player | undefined
  isMine: boolean
  pensionConfig: PensionConfig
  applicable: ApplicablePensionSettings
  hasPair: boolean
  now: number
  onSelect: () => void
  onRetrieve: () => void
}

// Case carrée d'un emplacement occupé de la grille de pension (voir
// PensionDaycareGrid, capacity_total colonnes fixes). Le sprite remplit
// (quasiment) toute la case ; propriétaire et cœur d'appariement sont de
// petits badges nichés dans les coins (jamais à cheval sur la bordure) ; nom
// + jauge XP (remplacée par "Récupérer"/"Prêt" une fois au taquet) sont
// superposés en bandeau semi-opaque tout en bas.
export function PensionDaycareCard({
  playerPokemon, pokemon, owner, isMine, pensionConfig, applicable, hasPair, now, onSelect, onRetrieve,
}: Props) {
  const [jumping, setJumping] = useState(false)
  // Durée/délai figés à vie du composant (initialiseur paresseux, calculé une
  // seule fois) pour que chaque pokémon se balance à son propre rythme, comme
  // RoamingPokemonSprite.
  const [bobDuration] = useState(() => 2.2 + Math.random() * 1.4)
  const [bobDelay] = useState(() => Math.random() * 1.5)

  // Saut occasionnel aléatoire (toutes les 5-15s), indépendant par pokémon —
  // contrairement à HomeTab (un seul membre d'équipe saute à la fois), chacun
  // a sa propre boucle ici.
  useEffect(() => {
    let cancelled = false
    let loopTimer: number
    let endTimer: number
    const loop = () => {
      loopTimer = window.setTimeout(() => {
        if (cancelled) return
        setJumping(true)
        endTimer = window.setTimeout(() => { if (!cancelled) setJumping(false) }, 600)
        loop()
      }, 5000 + Math.random() * 10000)
    }
    loop()
    return () => { cancelled = true; clearTimeout(loopTimer); clearTimeout(endTimer) }
  }, [])

  const maxXp = getMaxXp(pokemon)
  // Décision "prêt à récupérer" basée uniquement sur des valeurs déjà committées
  // en base (daycare_capped, xp) — jamais sur l'estimation live ci-dessous :
  // permettre un retrait avant que le prochain tick serveur (horaire) n'ait
  // effectivement crédité l'XP projetée ferait perdre cette XP pour de bon.
  const isMaxed = playerPokemon.daycare_capped || (maxXp != null && playerPokemon.xp >= maxXp)

  const { committedXp, projectedExtraXp } = computeProjectedDaycareXp(playerPokemon, applicable, pensionConfig.tick_xp_amount, new Date(now), maxXp)
  const liveXp = committedXp + projectedExtraXp
  const remainingCap = Math.max(0, Math.min(
    applicable.lifetimeXpCap - playerPokemon.daycare_lifetime_xp - projectedExtraXp,
    maxXp != null ? maxXp - liveXp : Infinity
  ))

  return (
    <div className="relative aspect-[2/3] min-w-0">
      {/* Fond/bordure sur une couche dédiée (plutôt que sur ce conteneur) :
          le sprite agrandi (scale-[1.6] ci-dessous) doit pouvoir déborder de
          sa case sans être rogné par un overflow-hidden porté par ce même
          conteneur. */}
      <div className="absolute inset-0 border-2 border-ink rounded-lg bg-cream-secondary overflow-hidden" />

      {owner && (
        <span
          className="absolute top-1 left-1 z-10 w-6 h-6 rounded-full border-2 shrink-0 overflow-hidden bg-cream"
          style={{ borderColor: owner.color }}
          title={owner.name}
        >
          {owner.image_url ? (
            <img src={owner.image_url} alt={owner.name} className="w-full h-full object-cover" />
          ) : (
            <span className="w-full h-full block" style={{ backgroundColor: owner.color }} />
          )}
        </span>
      )}

      {hasPair && (
        <span className="absolute top-1 right-1 z-10 text-lg [filter:drop-shadow(1px_1px_0_rgba(0,0,0,0.4))]" title="Appariement en cours pour un œuf">
          ❤️
        </span>
      )}

      {/* z-[1] (plutôt que l'empilement par défaut) : sans valeur explicite, le
          débordement du sprite serait comparé à l'échelle de toute la grille
          par ordre du DOM plutôt que par carte — le fond (non positionné) de
          la case suivante repasserait alors par-dessus le débordement de
          celle-ci dès que deux cases voisines sont occupées. */}
      <button onClick={onSelect} className="absolute inset-0 z-[1] flex items-center justify-center p-1" title={ownedPokemonName(playerPokemon)}>
        <div className="w-full h-full flex items-center justify-center" style={jumping ? { animation: 'jump-pop 0.6s ease-out 1' } : undefined}>
          <div className="w-full h-full flex items-center justify-center" style={{ animation: `idle-bob ${bobDuration}s ease-in-out ${bobDelay}s infinite` }}>
            {pokemon?.image_miniature ? (
              <img
                src={pokemon.image_miniature}
                alt=""
                className="pixelated max-w-full max-h-full object-contain scale-[1.6] [filter:drop-shadow(1px_2px_1px_rgba(0,0,0,0.3))]"
              />
            ) : (
              <span className="text-ink-muted-2 text-6xl">?</span>
            )}
          </div>
        </div>
      </button>

      <div className="absolute bottom-0 inset-x-0 z-10 flex flex-col gap-0.5 px-1.5 pt-1 pb-1.5 bg-cream/90 border-t-2 border-ink/20">
        <span className="text-ink text-xs font-bold truncate w-full text-center">{ownedPokemonName(playerPokemon)}</span>

        {isMaxed ? (
          isMine ? (
            <button onClick={onRetrieve} className={`w-full py-1 rounded text-xs font-bold ${BUTTON_STYLE.blue}`}>
              Récupérer
            </button>
          ) : (
            <p className="text-xs font-bold text-center text-[#2f6b3f]">✅ Prêt</p>
          )
        ) : (
          <button onClick={onSelect} className="w-full">
            <PensionXpBar xp={liveXp} remainingCap={remainingCap} maxXp={maxXp} compact />
          </button>
        )}
      </div>
    </div>
  )
}
