import type { Pokemon, PlayerPokemon, PensionConfig } from '../types'
import { ownedPokemonName } from '../types'
import { getMilestones, getMaxXp } from '../lib/xpBonuses'
import { computeProjectedDaycareXp, formatPensionCountdown, type ApplicablePensionSettings } from '../lib/pension'
import { PensionXpBar } from './PensionXpBar'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { CloseIcon } from './icons/CloseIcon'

interface Props {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  isMine: boolean
  pensionConfig: PensionConfig
  applicable: ApplicablePensionSettings
  eggGroups: string[]
  now: number
  onRetrieve?: () => void
  onClose: () => void
}

// Révélé au clic sur un pokémon de la grille de pension (PensionDaycareCard) —
// vue dédiée et volontairement plus légère que la fiche générique
// PokemonDetailSheet, centrée sur ce qui compte ici : XP en cours, potentiel
// restant, minuteur, et récupérer.
export function PensionDaycareInfoPopup({ playerPokemon, pokemon, isMine, pensionConfig, applicable, eggGroups, now, onRetrieve, onClose }: Props) {
  const milestones = getMilestones(pokemon)
  const maxXp = getMaxXp(pokemon)
  const { committedXp, projectedExtraXp, nextTickInMs } = computeProjectedDaycareXp(playerPokemon, applicable, pensionConfig.tick_xp_amount, new Date(now), maxXp)
  const liveXp = committedXp + projectedExtraXp
  const remainingCap = Math.max(0, Math.min(
    applicable.lifetimeXpCap - playerPokemon.daycare_lifetime_xp - projectedExtraXp,
    maxXp != null ? maxXp - liveXp : Infinity
  ))

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4" onClick={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className="relative bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-xs w-full p-6">
        <button
          onClick={onClose}
          className="absolute right-3 top-3 w-8 h-8 rounded-full flex items-center justify-center text-ink hover:bg-black/10"
        >
          <CloseIcon className="w-4 h-4" />
        </button>

        <div className="flex flex-col items-center text-center mb-4">
          <div className="w-16 h-16 flex items-center justify-center mb-2">
            {pokemon?.image_miniature ? (
              <img src={pokemon.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
            ) : (
              <span className="text-ink-muted-2 text-3xl">?</span>
            )}
          </div>
          <h3 className="text-ink text-xl font-bold">{ownedPokemonName(playerPokemon)}</h3>
          <p className="text-ink-muted-2 text-sm mt-0.5">
            {eggGroups.length > 0 ? `Groupe(s) : ${eggGroups.join(', ')}` : "Aucun groupe d'œufs"}
          </p>
        </div>

        <PensionXpBar xp={liveXp} remainingCap={remainingCap} maxXp={maxXp} milestones={milestones} />

        <p className="text-ink-muted-2 text-sm text-center mt-2 mb-4">
          {playerPokemon.daycare_capped
            ? 'Plafond atteint'
            : nextTickInMs != null
              ? `+${pensionConfig.tick_xp_amount} XP dans ${formatPensionCountdown(nextTickInMs)}`
              : ''}
        </p>

        {isMine && onRetrieve ? (
          <button onClick={onRetrieve} className={`w-full py-2.5 rounded-lg text-base font-bold ${BUTTON_STYLE.blue}`}>
            Récupérer
          </button>
        ) : (
          <button onClick={onClose} className={`w-full py-2.5 rounded-lg text-base font-bold ${BUTTON_STYLE.gray}`}>
            Fermer
          </button>
        )}
      </div>
    </div>
  )
}
