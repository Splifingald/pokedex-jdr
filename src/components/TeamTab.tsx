import { useState, useMemo } from 'react'
import type { Player, Pokemon, Attack, PlayerPokemon } from '../types'
import { usePlayerPokemon } from '../hooks/usePlayerPokemon'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { useToast } from '../context/ToastContext'
import { restoreLocalHp } from '../hooks/useLocalHp'
import { getMaxHp } from '../lib/maxHp'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { Chip } from './Chip'
import { PokemonOwnedCard } from './PokemonOwnedCard'
import { PokemonSearchInput } from './PokemonSearchInput'
import { PokemonDetailSheet } from './PokemonDetailSheet'
import { MovesTab } from './MovesTab'

type SortKey = 'numero' | 'type' | 'alpha'
type LayoutKey = 'grid' | 'list'

const SORT_LABELS: Record<SortKey, string> = { numero: '#', type: 'Type', alpha: 'A-Z' }

interface Props {
  player: Player
  pokemonList: Pokemon[]
  discovered: Set<string>
  isAdmin: boolean
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
}

export function TeamTab({ player, pokemonList, discovered, isAdmin, pokemonByName, attacksByName }: Props) {
  const { roster, loading, addOwnedPokemon, updateXp, toggleInTeam, addMove, removeMove, deleteOwnedPokemon } = usePlayerPokemon(player.id)
  const { parameters } = useAdminParameters()
  const { showToast } = useToast()

  const [selectedId, setSelectedId] = useState<number | null>(null)
  const [managingMoves, setManagingMoves] = useState(false)
  const [sortKey, setSortKey] = useState<SortKey>('numero')
  const [layout, setLayout] = useState<LayoutKey>('grid')

  const addableOptions = useMemo(
    () => pokemonList.filter((p) => isAdmin || discovered.has(p.nom)),
    [pokemonList, isAdmin, discovered]
  )

  const team = roster.filter((r) => r.in_team)
  const teamFull = player.is_npc ? false : team.length >= parameters.max_team_size

  // Roster unifié (équipe + PC) trié — les PNJ n'ont pas de PC
  const sortedRoster = useMemo(() => {
    const list = player.is_npc ? roster.filter((r) => r.in_team) : [...roster]
    const numeroOf = (pp: PlayerPokemon) => pp.pokemon_numero ?? pokemonByName.get(pp.pokemon_nom)?.numero ?? ''
    const byNumero = (a: PlayerPokemon, b: PlayerPokemon) =>
      numeroOf(a).localeCompare(numeroOf(b), undefined, { numeric: true })
    if (sortKey === 'type') {
      list.sort((a, b) => {
        const ta = pokemonByName.get(a.pokemon_nom)?.type ?? ''
        const tb = pokemonByName.get(b.pokemon_nom)?.type ?? ''
        return ta.localeCompare(tb) || byNumero(a, b)
      })
    } else if (sortKey === 'alpha') {
      list.sort((a, b) => a.pokemon_nom.localeCompare(b.pokemon_nom, 'fr'))
    } else {
      list.sort(byNumero)
    }
    return list
  }, [roster, sortKey, player.is_npc, pokemonByName])

  const selected = roster.find((r) => r.id === selectedId) ?? null

  const handleAddOwned = async (p: Pokemon) => {
    const inTeam = !teamFull
    await addOwnedPokemon(p.nom, p.numero, inTeam)
    showToast(`${p.nom} ajouté ${inTeam ? "à l'équipe" : 'au PC'} !`)
  }

  const handleToggleInTeam = async (id: number, inTeam: boolean) => {
    await toggleInTeam(id, inTeam)
    const pp = roster.find((r) => r.id === id)
    showToast(`${pp?.pokemon_nom ?? 'Pokémon'} ${inTeam ? "ajouté à l'équipe" : 'mis au PC'} !`)
  }

  const handleDeleteOwned = async (id: number) => {
    const pp = roster.find((r) => r.id === id)
    await deleteOwnedPokemon(id)
    setSelectedId(null)
    showToast(`${pp?.pokemon_nom ?? 'Pokémon'} supprimé.`)
  }

  const handleRestoreAll = () => {
    sortedRoster.forEach((pp) => {
      restoreLocalHp(pp.id, getMaxHp(pp, pokemonByName.get(pp.pokemon_nom)))
    })
    showToast('Pokémon soignés !')
  }

  if (selected && managingMoves) {
    return (
      <MovesTab
        playerPokemon={selected}
        pokemon={pokemonByName.get(selected.pokemon_nom)}
        maxMoves={parameters.max_moves}
        attacksByName={attacksByName}
        onUpdateXp={updateXp}
        onAddMove={addMove}
        onRemoveMove={removeMove}
        onGoToInfo={() => setManagingMoves(false)}
        onBack={() => { setManagingMoves(false); setSelectedId(null) }}
      />
    )
  }

  return (
    <div className="flex-1 overflow-y-auto p-4">
      <div className="mb-4">
        <label className="text-[#9a9cba] text-sm mb-2 block">Ajouter un pokémon à mon équipe</label>
        <PokemonSearchInput options={addableOptions} onSelect={handleAddOwned} />
      </div>

      {/* Tri + disposition + soin */}
      <div className="flex items-center gap-1.5 flex-wrap mb-3.5">
        {(Object.keys(SORT_LABELS) as SortKey[]).map((k) => (
          <Chip key={k} label={SORT_LABELS[k]} active={sortKey === k} onClick={() => setSortKey(k)} />
        ))}
        <button
          onClick={() => setLayout((l) => (l === 'grid' ? 'list' : 'grid'))}
          title={layout === 'grid' ? 'Vue liste' : 'Vue grille'}
          className={`px-2.5 py-1 rounded-md text-sm ${BUTTON_STYLE.gray}`}
        >
          {layout === 'grid' ? '☰' : '▦'}
        </button>
        <span className="flex-1" />
        <span className="text-[#9a9cba] text-xs">
          Équipe : {player.is_npc ? team.length : `${team.length} / ${parameters.max_team_size}`}
        </span>
        {sortedRoster.length > 0 && (
          <button
            onClick={handleRestoreAll}
            className={`text-xs px-2.5 py-1 rounded-md font-bold ${BUTTON_STYLE.green}`}
          >
            ❤️ Tout soigner
          </button>
        )}
      </div>

      {loading ? (
        <p className="text-[#7a7c9a] text-sm">Chargement…</p>
      ) : sortedRoster.length === 0 ? (
        <p className="text-[#7a7c9a] text-sm">Aucun Pokémon possédé.</p>
      ) : layout === 'grid' ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-2.5">
          {sortedRoster.map((pp) => (
            <PokemonOwnedCard
              key={pp.id}
              playerPokemon={pp}
              pokemon={pokemonByName.get(pp.pokemon_nom)}
              variant="grid"
              showPcBadge={!player.is_npc && !pp.in_team}
              onClick={() => setSelectedId(pp.id)}
            />
          ))}
        </div>
      ) : (
        <div className="flex flex-col gap-2">
          {sortedRoster.map((pp) => (
            <PokemonOwnedCard
              key={pp.id}
              playerPokemon={pp}
              pokemon={pokemonByName.get(pp.pokemon_nom)}
              variant="list"
              showPcBadge={!player.is_npc && !pp.in_team}
              onClick={() => setSelectedId(pp.id)}
            />
          ))}
        </div>
      )}

      {selected && !managingMoves && (
        <PokemonDetailSheet
          context="pokemon"
          pokemon={pokemonByName.get(selected.pokemon_nom)}
          playerPokemon={selected}
          attacksByName={attacksByName}
          isAdmin={isAdmin}
          teamFull={teamFull}
          isNpc={player.is_npc}
          maxMoves={parameters.max_moves}
          onUpdateXp={updateXp}
          onToggleInTeam={handleToggleInTeam}
          onManageMoves={() => setManagingMoves(true)}
          onDelete={handleDeleteOwned}
          onClose={() => setSelectedId(null)}
        />
      )}
    </div>
  )
}
