import { useMemo, useState } from 'react'
import type { Pokemon, PlayerPokemon, Attack } from '../../types'
import { ownedPokemonName } from '../../types'
import { getEligiblePlayerPokemon } from '../../lib/autoBattle'
import { getSuperEfficace } from '../../lib/pokemonFacts'
import { getHpBreakdown, getDamageBreakdown } from '../../lib/xpBonuses'
import { normalizeSearch } from '../../lib/normalizeSearch'
import { PANEL } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { STAT_ICON } from '../../lib/icons'
import { PixelIcon } from '../icons/PixelIcon'
import { TypeBadge } from '../TypeBadge'
import { Chip } from '../Chip'

interface Props {
  roster: PlayerPokemon[]
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  bannedAttacks: Set<string>
  /** Espèce adverse du niveau en cours — undefined si pas encore résolue (ne devrait pas arriver en pratique, voir AutoBattlePopup). */
  opponentSpecies?: Pokemon
  /** Ce niveau a-t-il déjà été joué au moins une fois (autobattle_player_level_state.discovered) — le badge "Super Efficace" ne doit apparaître qu'une fois l'adversaire réellement découvert, jamais en avant-première sur un niveau jamais tenté. */
  opponentDiscovered: boolean
  onSelect: (pp: PlayerPokemon) => void
  onBack: () => void
}

type SortKey = 'default' | 'type' | 'damage' | 'hp'

const SORT_LABELS: Record<SortKey, string> = {
  default: 'Équipe',
  type: 'Type & efficacité',
  damage: 'Dégâts',
  hp: 'PV',
}

// Sélection du pokémon combattant — liste (une ligne par pokémon, voir
// requirement dédié) sur le roster Équipe + PC (pension exclue), filtrée aux
// pokémon ayant au moins une capacité apprise non-bannie (voir requirement
// #6/#9). Partagée telle quelle entre Combat Auto (auto ET manuel) et PvP
// (AutoBattlePopup / PvpPopup) — aucune différence d'affichage entre modes.
export function AutoBattlePokemonPicker({ roster, pokemonByName, attacksByName, bannedAttacks, opponentSpecies, opponentDiscovered, onSelect, onBack }: Props) {
  const [sortKey, setSortKey] = useState<SortKey>('default')
  const [query, setQuery] = useState('')

  const eligible = useMemo(
    () => getEligiblePlayerPokemon(roster, attacksByName, bannedAttacks),
    [roster, attacksByName, bannedAttacks]
  )

  const isSuperEffective = (pp: PlayerPokemon) => {
    const species = pokemonByName.get(pp.pokemon_nom)
    return opponentDiscovered && opponentSpecies != null && getSuperEfficace(species).includes(opponentSpecies.type)
  }

  const sortedAndFiltered = useMemo(() => {
    const q = normalizeSearch(query.trim())
    const filtered = q ? eligible.filter((pp) => normalizeSearch(ownedPokemonName(pp)).includes(q)) : [...eligible]

    const numeroOf = (pp: PlayerPokemon) => pp.pokemon_numero ?? pokemonByName.get(pp.pokemon_nom)?.numero ?? ''
    const byNumero = (a: PlayerPokemon, b: PlayerPokemon) =>
      numeroOf(a).localeCompare(numeroOf(b), undefined, { numeric: true })

    if (sortKey === 'type') {
      filtered.sort((a, b) => {
        const seA = isSuperEffective(a) ? 0 : 1
        const seB = isSuperEffective(b) ? 0 : 1
        if (seA !== seB) return seA - seB
        const typeA = pokemonByName.get(a.pokemon_nom)?.type ?? ''
        const typeB = pokemonByName.get(b.pokemon_nom)?.type ?? ''
        return typeA.localeCompare(typeB, 'fr') || byNumero(a, b)
      })
    } else if (sortKey === 'damage') {
      filtered.sort((a, b) => {
        const dmgA = getDamageBreakdown(pokemonByName.get(a.pokemon_nom), a.xp).total
        const dmgB = getDamageBreakdown(pokemonByName.get(b.pokemon_nom), b.xp).total
        return dmgB - dmgA || byNumero(a, b)
      })
    } else if (sortKey === 'hp') {
      filtered.sort((a, b) => {
        const hpA = getHpBreakdown(pokemonByName.get(a.pokemon_nom), a.xp).total
        const hpB = getHpBreakdown(pokemonByName.get(b.pokemon_nom), b.xp).total
        return hpB - hpA || byNumero(a, b)
      })
    } else {
      filtered.sort((a, b) => (b.in_team ? 1 : 0) - (a.in_team ? 1 : 0) || byNumero(a, b))
    }
    return filtered
    // eslint-disable-next-line react-hooks/exhaustive-deps -- isSuperEffective ferme sur opponentSpecies/opponentDiscovered/pokemonByName, déjà dans les deps
  }, [eligible, sortKey, query, pokemonByName, opponentSpecies, opponentDiscovered])

  if (eligible.length === 0) {
    return (
      <div className="flex flex-col items-center gap-3 py-6">
        <p className="text-ink-muted-2 text-sm text-center">
          Aucun pokémon avec une capacité apprise (et hors pension) n'est disponible pour combattre.
        </p>
        <button onClick={onBack} className={`text-xs px-3 py-1.5 rounded font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <button onClick={onBack} className={`text-xs px-2 py-1 rounded font-bold ${BUTTON_STYLE.gray}`}>← Retour</button>
        <h4 className="text-ink text-base font-bold">Choisissez votre pokémon</h4>
      </div>

      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Rechercher un pokémon…"
        className="w-full bg-cream border-2 border-ink rounded-lg px-3 py-2 text-ink text-sm placeholder-ink-muted-2 outline-none"
      />

      <div className="flex items-center gap-1.5 flex-wrap">
        {(Object.keys(SORT_LABELS) as SortKey[]).map((k) => (
          <Chip key={k} label={SORT_LABELS[k]} active={sortKey === k} onClick={() => setSortKey(k)} />
        ))}
      </div>

      {sortedAndFiltered.length === 0 ? (
        <p className="text-ink-muted-2 text-sm text-center py-4">Aucun pokémon ne correspond à cette recherche.</p>
      ) : (
        <div className="flex flex-col gap-2">
          {sortedAndFiltered.map((pp) => {
            const species = pokemonByName.get(pp.pokemon_nom)
            const superEffective = isSuperEffective(pp)
            const damage = getDamageBreakdown(species, pp.xp).total
            const hp = getHpBreakdown(species, pp.xp).total
            return (
              <button
                key={pp.id}
                onClick={() => onSelect(pp)}
                className={`${PANEL} flex items-stretch gap-2.5 p-2 text-left ${BUTTON_STYLE.gray}`}
              >
                <div className="aspect-square self-stretch shrink-0 rounded-md border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
                  {species?.image_miniature ? (
                    <img src={species.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
                  ) : (
                    <span className="text-ink-muted-2 text-2xl">?</span>
                  )}
                </div>
                <div className="flex-1 min-w-0 flex flex-col justify-center gap-1">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-ink text-sm font-bold truncate">{ownedPokemonName(pp)}</span>
                    <span className="flex items-center gap-2 shrink-0 text-ink text-xs font-bold">
                      <span className="flex items-center gap-0.5">
                        <PixelIcon src={STAT_ICON.damage} size={14} colored />
                        {damage}
                      </span>
                      <span className="flex items-center gap-0.5">
                        <PixelIcon src={STAT_ICON.hp} size={14} colored />
                        {hp}
                      </span>
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-ink-muted-2 text-xs">🏆 {pp.battles_won ?? 0} combat{(pp.battles_won ?? 0) > 1 ? 's' : ''} gagné{(pp.battles_won ?? 0) > 1 ? 's' : ''}</span>
                    <span className="flex items-center gap-1.5 shrink-0">
                      {superEffective && (
                        <span className="text-xs font-bold px-1.5 py-0.5 rounded-full text-white bg-[#d9761e] whitespace-nowrap">
                          Super Efficace
                        </span>
                      )}
                      {species && <TypeBadge type={species.type} small />}
                    </span>
                  </div>
                </div>
              </button>
            )
          })}
        </div>
      )}
    </div>
  )
}
