import { useState, useMemo } from 'react'
import type { Player, Pokemon, Attack, PlayerPokemon } from '../types'
import { usePlayerPokemon } from '../hooks/usePlayerPokemon'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { useToast } from '../context/ToastContext'
import { restoreLocalHp } from '../hooks/useLocalHp'
import { getMaxHp } from '../lib/maxHp'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PokemonOwnedCard } from './PokemonOwnedCard'
import { PokemonSearchInput } from './PokemonSearchInput'
import { PokemonDetailView } from './PokemonDetailView'
import { MovesTab } from './MovesTab'

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

  const addableOptions = useMemo(
    () => pokemonList.filter((p) => isAdmin || discovered.has(p.nom)),
    [pokemonList, isAdmin, discovered]
  )

  const team = roster.filter((r) => r.in_team)
  const box = player.is_npc ? [] : roster.filter((r) => !r.in_team)
  const teamFull = player.is_npc ? false : team.length >= parameters.max_team_size

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

  const handleRestoreAll = (list: PlayerPokemon[]) => {
    list.forEach((pp) => {
      restoreLocalHp(pp.id, getMaxHp(pp, pokemonByName.get(pp.pokemon_nom)))
    })
    showToast('Pokémon soignés !')
  }

  if (selected) {
    const pokemon = pokemonByName.get(selected.pokemon_nom)

    if (managingMoves) {
      return (
        <MovesTab
          playerPokemon={selected}
          pokemon={pokemon}
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
      <PokemonDetailView
        playerPokemon={selected}
        pokemon={pokemon}
        teamFull={teamFull}
        isNpc={player.is_npc}
        maxMoves={parameters.max_moves}
        attacksByName={attacksByName}
        onUpdateXp={updateXp}
        onToggleInTeam={handleToggleInTeam}
        onManageMoves={() => setManagingMoves(true)}
        onDelete={handleDeleteOwned}
        onBack={() => setSelectedId(null)}
      />
    )
  }

  return (
    <div className="flex-1 overflow-y-auto p-4">
      <div className="mb-6">
        <label className="text-gray-400 text-sm mb-2 block">Ajouter un pokémon à mon équipe</label>
        <PokemonSearchInput
          options={addableOptions}
          onSelect={handleAddOwned}
        />
      </div>

      <div className="flex items-center justify-between mb-3">
        <h2 className="text-white text-lg">
          Équipe ({player.is_npc ? team.length : `${team.length} / ${parameters.max_team_size}`})
        </h2>
        {team.length > 0 && (
          <button
            onClick={() => handleRestoreAll(team)}
            className={`text-xs px-2.5 py-1 rounded font-bold ${BUTTON_STYLE.green}`}
          >
            ❤️ Tout soigner
          </button>
        )}
      </div>
      {loading ? (
        <p className="text-gray-500 text-sm">Chargement…</p>
      ) : team.length === 0 ? (
        <p className="text-gray-500 text-sm mb-6">Aucun pokémon dans l'équipe.</p>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 mb-8">
          {team.map((pp) => (
            <PokemonOwnedCard
              key={pp.id}
              playerPokemon={pp}
              pokemon={pokemonByName.get(pp.pokemon_nom)}
              showHp
              onClick={() => setSelectedId(pp.id)}
            />
          ))}
        </div>
      )}

      {!player.is_npc && (
        <>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-white text-lg">💻 PC ({box.length})</h2>
            {box.length > 0 && (
              <button
                onClick={() => handleRestoreAll(box)}
                className={`text-xs px-2.5 py-1 rounded font-bold ${BUTTON_STYLE.green}`}
              >
                ❤️ Tout soigner
              </button>
            )}
          </div>
          {box.length === 0 ? (
            <p className="text-gray-500 text-sm">Aucun pokémon dans le PC.</p>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
              {box.map((pp) => (
                <PokemonOwnedCard
                  key={pp.id}
                  playerPokemon={pp}
                  pokemon={pokemonByName.get(pp.pokemon_nom)}
                  showHp={false}
                  onClick={() => setSelectedId(pp.id)}
                />
              ))}
            </div>
          )}
        </>
      )}
    </div>
  )
}
