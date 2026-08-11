import { useMemo, useState } from 'react'
import type { Pokemon, PlayerPokemon, PensionConfig, PensionXpGroup } from '../types'
import { ownedPokemonName } from '../types'
import { getMaxXp } from '../lib/xpBonuses'
import { resolveApplicableXpGroup, formatXpCapTimeframe, canPair, type ApplicablePensionSettings } from '../lib/pension'
import { PANEL } from '../lib/panelStyles'
import { BUTTON_STYLE } from '../lib/buttonStyles'
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

type SortMode = 'alpha' | 'ratio' | 'potential' | 'compatible'

const SORT_LABELS: Record<SortMode, string> = {
  alpha: 'Alphabétique',
  ratio: 'Meilleur ratio XP',
  potential: "Plus de potentiel d'XP",
  compatible: "Compatibles d'abord",
}

interface Row {
  pp: PlayerPokemon
  species: Pokemon | undefined
  maxXp: number | null
  applicable: ApplicablePensionSettings
  remaining: number
  hasCompatibleMate: boolean
  ratioPerHour: number
}

// Grille affichée dans PensionSelectionPopup (ouverte depuis le bouton
// "Ajouter un pokémon" d'un emplacement vide de la grille de pension) —
// deux colonnes larges pour garder toutes les infos (jauge XP complète,
// délai jusqu'au plafond, compatibilité) plutôt qu'une grille dense de
// petites cartes. Chaque carte a son propre bouton "Ajouter", contrairement
// à l'ancienne liste où toute la ligne était cliquable.
export function PensionPlacementList({
  pcRoster, daycareRoster, pokemonByName, pensionConfig, xpGroupByPokemonNom, eggGroupsByPokemonNom, daycareFull, onPlace,
}: Props) {
  const [sortMode, setSortMode] = useState<SortMode>('alpha')

  const rows = useMemo<Row[]>(() => pcRoster.map((pp) => {
    const species = pokemonByName.get(pp.pokemon_nom)
    const maxXp = getMaxXp(species)
    const groups = eggGroupsByPokemonNom.get(pp.pokemon_nom) ?? []
    const applicable = resolveApplicableXpGroup(pp.pokemon_nom, xpGroupByPokemonNom, pensionConfig)
    const remaining = Math.max(0, Math.min(
      applicable.lifetimeXpCap - pp.daycare_lifetime_xp,
      maxXp != null ? maxXp - pp.xp : Infinity
    ))
    const hasCompatibleMate = daycareRoster.some((d) => canPair(groups, eggGroupsByPokemonNom.get(d.pokemon_nom) ?? []))
    const ratioPerHour = applicable.tickIntervalMs > 0 ? (pensionConfig.tick_xp_amount / applicable.tickIntervalMs) * 3_600_000 : 0
    return { pp, species, maxXp, applicable, remaining, hasCompatibleMate, ratioPerHour }
  }), [pcRoster, pokemonByName, eggGroupsByPokemonNom, xpGroupByPokemonNom, pensionConfig, daycareRoster])

  const sorted = useMemo(() => {
    const comparators: Record<SortMode, (a: Row, b: Row) => number> = {
      alpha: (a, b) => ownedPokemonName(a.pp).localeCompare(ownedPokemonName(b.pp), 'fr'),
      ratio: (a, b) => b.ratioPerHour - a.ratioPerHour,
      potential: (a, b) => b.remaining - a.remaining,
      compatible: (a, b) => Number(b.hasCompatibleMate) - Number(a.hasCompatibleMate),
    }
    // Les pokémon ayant déjà atteint leur plafond de pension restent toujours
    // en bas, quel que soit le mode de tri choisi.
    return [...rows].sort((a, b) => {
      const maxedDiff = Number(a.remaining <= 0) - Number(b.remaining <= 0)
      if (maxedDiff !== 0) return maxedDiff
      return comparators[sortMode](a, b)
    })
  }, [rows, sortMode])

  if (pcRoster.length === 0) {
    return <p className="text-ink-muted-2 text-sm text-center py-6">Aucun Pokémon disponible dans votre PC pour la pension.</p>
  }

  return (
    <div className="flex flex-col gap-3">
      {daycareFull && (
        <p className="text-hp-orange text-sm font-bold text-center bg-hp-orange/10 border-2 border-hp-orange rounded-lg py-2 px-3">
          Pension complète — réessayez plus tard.
        </p>
      )}

      <div className="flex items-center justify-end gap-2">
        <label className="text-ink-muted-2 text-sm">Trier par :</label>
        <select
          value={sortMode}
          onChange={(e) => setSortMode(e.target.value as SortMode)}
          className="bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none"
        >
          {(Object.keys(SORT_LABELS) as SortMode[]).map((mode) => (
            <option key={mode} value={mode}>{SORT_LABELS[mode]}</option>
          ))}
        </select>
      </div>

      <div className="grid grid-cols-2 gap-2">
        {sorted.map(({ pp, species, maxXp, applicable, remaining, hasCompatibleMate }) => {
          const disabled = daycareFull || remaining <= 0
          return (
            <div key={pp.id} className={`${PANEL} flex flex-col gap-1.5 p-2.5`}>
              <div className="flex flex-col items-center gap-1.5 text-center sm:flex-row sm:items-center sm:gap-2.5 sm:text-left">
                <div className="w-14 h-14 shrink-0 rounded-md border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
                  {species?.image_miniature ? (
                    <img src={species.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
                  ) : (
                    <span className="text-ink-muted-2 text-2xl">?</span>
                  )}
                </div>
                <div className="flex-1 min-w-0 w-full">
                  <span className="text-ink text-sm font-bold truncate block mb-1">{ownedPokemonName(pp)}</span>
                  <PensionXpBar xp={pp.xp} remainingCap={remaining} maxXp={maxXp} compact />
                </div>
              </div>

              <div className="flex items-center justify-between gap-2">
                <span className={`text-xs font-bold ${remaining > 0 ? 'text-[#2f6b3f]' : 'text-ink-muted-2'}`}>
                  {remaining > 0
                    ? formatXpCapTimeframe(remaining, pensionConfig.tick_xp_amount, applicable.tickIntervalMs)
                    : 'Plafond de la pension déjà atteint'}
                </span>
                {hasCompatibleMate && (
                  <span className="flex items-center gap-1 text-xs font-bold shrink-0" title="Compatible avec un pokémon déjà en pension">
                    ❤️ Compatible
                  </span>
                )}
              </div>

              <button
                onClick={() => onPlace(pp.id)}
                disabled={disabled}
                className={`w-full py-1.5 rounded text-sm font-bold ${BUTTON_STYLE.yellow} disabled:opacity-50 disabled:cursor-not-allowed`}
              >
                Ajouter
              </button>
            </div>
          )
        })}
      </div>
    </div>
  )
}
