import { useMemo, useState } from 'react'
import type { Pokemon, PlayerPokemon, PensionConfig, PensionXpGroup } from '../types'
import { ownedPokemonName } from '../types'
import { getMaxXp } from '../lib/xpBonuses'
import { resolveApplicableXpGroup, canPair } from '../lib/pension'
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
  remaining: number
  hasCompatibleMate: boolean
  ratioPerHour: number
}

// Grille compacte affichée dans PensionSelectionPopup (ouverte depuis le
// bouton "Ajouter un pokémon" d'un emplacement vide de la grille de
// pension) — chaque carte a son propre bouton "Ajouter", contrairement à
// l'ancienne liste où toute la ligne était cliquable.
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
    return { pp, species, maxXp, remaining, hasCompatibleMate, ratioPerHour }
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

      <div className="grid grid-cols-4 sm:grid-cols-5 gap-1.5">
        {sorted.map(({ pp, species, maxXp, remaining, hasCompatibleMate }) => {
          const disabled = daycareFull || remaining <= 0
          return (
            <div key={pp.id} className={`${PANEL} relative flex flex-col items-center gap-1 p-1.5`}>
              {hasCompatibleMate && (
                <span
                  className="absolute top-0.5 right-0.5 text-sm [filter:drop-shadow(1px_1px_0_rgba(0,0,0,0.4))]"
                  title="Compatible avec un pokémon déjà en pension"
                >
                  ❤️
                </span>
              )}
              <div className="w-10 h-10 shrink-0 rounded-md border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
                {species?.image_miniature ? (
                  <img src={species.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
                ) : (
                  <span className="text-ink-muted-2 text-base">?</span>
                )}
              </div>
              <span className="text-ink text-xs font-bold truncate w-full text-center">{ownedPokemonName(pp)}</span>
              <PensionXpBar xp={pp.xp} remainingCap={remaining} maxXp={maxXp} compact hideText />
              <button
                onClick={() => onPlace(pp.id)}
                disabled={disabled}
                className={`w-full py-1 rounded text-xs font-bold ${BUTTON_STYLE.yellow} disabled:opacity-50 disabled:cursor-not-allowed`}
              >
                {remaining > 0 ? 'Ajouter' : 'Plafond'}
              </button>
            </div>
          )
        })}
      </div>
    </div>
  )
}
