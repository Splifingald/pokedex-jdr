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

// Rendu volontairement "en liberté" (pas en grille façon inventaire) : sprite
// bien plus gros que le reste de l'app (repère visuel fort dans le popup) +
// jauge XP en direct en dessous, qui se change en bouton "Récupérer" (le sien)
// ou en badge "Prêt" (celui d'un autre) une fois le pokémon au taquet — plus
// besoin de cliquer pour agir une fois prêt. Le clic sur le sprite (ou la
// jauge tant qu'elle est affichée) ouvre PensionDaycareInfoPopup pour le détail
// complet (nom, palier exact, minuteur, récupération manuelle anticipée).
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
    <div className="flex flex-col items-center gap-2 w-72">
      <button onClick={onSelect} className="relative w-72 h-72 flex items-center justify-center" title={ownedPokemonName(playerPokemon)}>
        {hasPair && (
          <span className="absolute top-2 left-2 text-3xl z-10 [filter:drop-shadow(1px_2px_1px_rgba(0,0,0,0.4))]" title="Appariement en cours pour un œuf">
            ❤️
          </span>
        )}
        <div style={jumping ? { animation: 'jump-pop 0.6s ease-out 1' } : undefined}>
          <div style={{ animation: `idle-bob ${bobDuration}s ease-in-out ${bobDelay}s infinite` }}>
            {pokemon?.image_miniature ? (
              <img
                src={pokemon.image_miniature}
                alt=""
                className="pixelated w-60 h-60 object-contain [filter:drop-shadow(3px_6px_3px_rgba(0,0,0,0.3))]"
              />
            ) : (
              <span className="text-ink-muted-2 text-6xl">?</span>
            )}
          </div>
        </div>
      </button>

      {isMaxed ? (
        isMine ? (
          <button onClick={onRetrieve} className={`w-full py-2.5 rounded-lg text-base font-bold ${BUTTON_STYLE.blue}`}>
            Récupérer
          </button>
        ) : (
          <span className="text-base font-bold text-[#2f6b3f]">✅ Prêt</span>
        )
      ) : (
        <button onClick={onSelect} className="w-full">
          <PensionXpBar xp={liveXp} remainingCap={remainingCap} maxXp={maxXp} compact />
        </button>
      )}

      {owner && (
        <span
          className="w-14 h-14 rounded-full border-2 shrink-0 overflow-hidden"
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
    </div>
  )
}
