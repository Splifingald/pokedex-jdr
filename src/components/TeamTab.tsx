import { useState, useMemo } from 'react'
import type { Player, Pokemon, Attack } from '../types'
import { usePlayerPokemon } from '../hooks/usePlayerPokemon'
import { useAdminParameters } from '../hooks/useAdminParameters'
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
  const { roster, loading, addOwnedPokemon, updateXp, toggleInTeam, addMove, removeMove } = usePlayerPokemon(player.id)
  const { parameters } = useAdminParameters()

  const [selectedId, setSelectedId] = useState<number | null>(null)
  const [managingMoves, setManagingMoves] = useState(false)

  const addableOptions = useMemo(
    () => pokemonList.filter((p) => isAdmin || discovered.has(p.nom)),
    [pokemonList, isAdmin, discovered]
  )

  const team = roster.filter((r) => r.in_team)
  const box = roster.filter((r) => !r.in_team)
  const teamFull = team.length >= parameters.max_team_size

  const selected = roster.find((r) => r.id === selectedId) ?? null

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
          onBack={() => setManagingMoves(false)}
        />
      )
    }

    return (
      <PokemonDetailView
        playerPokemon={selected}
        pokemon={pokemon}
        teamFull={teamFull}
        onUpdateXp={updateXp}
        onToggleInTeam={toggleInTeam}
        onManageMoves={() => setManagingMoves(true)}
        onBack={() => setSelectedId(null)}
      />
    )
  }

  return (
    <div className="flex-1 overflow-y-auto p-4">
      <div className="mb-6">
        <label className="text-gray-400 text-sm mb-2 block">Ajouter un pokémon à mon roster</label>
        <PokemonSearchInput
          options={addableOptions}
          onSelect={(p) => addOwnedPokemon(p.nom, p.numero)}
        />
      </div>

      <h2 className="text-white text-lg mb-3">
        Équipe ({team.length} / {parameters.max_team_size})
      </h2>
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

      <h2 className="text-white text-lg mb-3">PC ({box.length})</h2>
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
    </div>
  )
}
