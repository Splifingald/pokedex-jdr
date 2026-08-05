import type { Pokemon, PlayerPokemon, PensionConfig, PensionXpGroup } from '../types'
import { ownedPokemonName } from '../types'
import { getMaxXp } from '../lib/xpBonuses'
import { resolveApplicableXpGroup, formatXpCapTimeframe, canPair } from '../lib/pension'
import { PANEL } from '../lib/panelStyles'
import { PensionXpBar } from './PensionXpBar'

interface Props {
  pcRoster: PlayerPokemon[]
  daycareRoster: PlayerPokemon[]
  pokemonByName: Map<string, Pokemon>
  pensionConfig: PensionConfig
  xpGroupByPokemonNom: Map<string, PensionXpGroup>
  eggGroupsByPokemonNom: Map<string, string[]>
  daycareFull: boolean
  onPlace: (id: number) => void
}

export function PensionPlacementList({
  pcRoster, daycareRoster, pokemonByName, pensionConfig, xpGroupByPokemonNom, eggGroupsByPokemonNom, daycareFull, onPlace,
}: Props) {
  if (pcRoster.length === 0) {
    return <p className="text-ink-muted-2 text-sm text-center py-6">Aucun Pokémon disponible dans votre PC pour la pension.</p>
  }

  return (
    <div className="flex flex-col gap-3">
      <p className="text-ink text-base font-bold text-center">
        Sélectionne le Pokémon à déposer à la pension depuis ton PC
      </p>

      {daycareFull && (
        <p className="text-hp-orange text-sm font-bold text-center bg-hp-orange/10 border-2 border-hp-orange rounded-lg py-2 px-3">
          Pension complète — réessayez plus tard.
        </p>
      )}

      <div className="flex flex-col gap-2">
        {pcRoster.map((pp) => {
          const species = pokemonByName.get(pp.pokemon_nom)
          const maxXp = getMaxXp(species)
          const groups = eggGroupsByPokemonNom.get(pp.pokemon_nom) ?? []
          const applicable = resolveApplicableXpGroup(pp.pokemon_nom, xpGroupByPokemonNom, pensionConfig)
          const remaining = Math.max(0, Math.min(
            applicable.lifetimeXpCap - pp.daycare_lifetime_xp,
            maxXp != null ? maxXp - pp.xp : Infinity
          ))
          const hasCompatibleMate = daycareRoster.some((d) => canPair(groups, eggGroupsByPokemonNom.get(d.pokemon_nom) ?? []))

          return (
            <button
              key={pp.id}
              onClick={() => onPlace(pp.id)}
              disabled={daycareFull || remaining <= 0}
              className={`${PANEL} relative flex items-center gap-3 p-2.5 text-left disabled:opacity-50 disabled:cursor-not-allowed`}
            >
              <div className="relative w-16 h-16 shrink-0 rounded-md border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
                {species?.image_miniature ? (
                  <img src={species.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
                ) : (
                  <span className="text-ink-muted-2 text-2xl">?</span>
                )}
                {hasCompatibleMate && (
                  <span className="absolute -top-1.5 -right-1.5 text-lg [filter:drop-shadow(1px_1px_0_rgba(0,0,0,0.4))]" title="Compatible avec un pokémon déjà en pension">
                    ❤️
                  </span>
                )}
              </div>

              <div className="flex-1 min-w-0">
                <span className="text-ink text-base font-bold truncate block mb-1">{ownedPokemonName(pp)}</span>
                <PensionXpBar xp={pp.xp} remainingCap={remaining} maxXp={maxXp} compact />
                <span className={`text-sm font-bold block mt-0.5 ${remaining > 0 ? 'text-[#2f6b3f]' : 'text-ink-muted-2'}`}>
                  {remaining > 0
                    ? formatXpCapTimeframe(remaining, pensionConfig.tick_xp_amount, applicable.tickIntervalMs)
                    : 'Plafond de la pension déjà atteint pour ce pokémon'}
                </span>
              </div>
            </button>
          )
        })}
      </div>
    </div>
  )
}
