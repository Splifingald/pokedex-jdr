import type { Pokemon } from '../types'
import { PokemonListItem } from './PokemonListItem'

interface Props {
  pokemon: Pokemon[]
  discovered: Set<string>
  isAdmin: boolean
  selectedId: number | null
  onSelectDiscovered: (p: Pokemon) => void
  onSelectUndiscovered: (p: Pokemon) => void
  totalCount: number // total avant filtres, pour afficher "X / Y"
}

export function PokemonList({
  pokemon,
  discovered,
  isAdmin,
  selectedId,
  onSelectDiscovered,
  onSelectUndiscovered,
  totalCount,
}: Props) {
  if (totalCount === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-gray-500 gap-4 p-8">
        <span className="text-5xl">📋</span>
        <p className="text-center text-sm">
          Aucun pokémon enregistré.<br />
          Connectez-vous en admin pour importer un CSV.
        </p>
      </div>
    )
  }

  if (pokemon.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-gray-500 gap-4 p-8">
        <span className="text-4xl">🔍</span>
        <p className="text-center text-sm">Aucun résultat.</p>
      </div>
    )
  }

  return (
    <div className="overflow-y-auto flex-1">
      {pokemon.map((p) => (
        <PokemonListItem
          key={p.id}
          pokemon={p}
          isDiscovered={discovered.has(p.nom)}
          isAdmin={isAdmin}
          isSelected={p.id === selectedId}
          onClick={() => {
            if (discovered.has(p.nom) || isAdmin) {
              onSelectDiscovered(p)
            } else {
              onSelectUndiscovered(p)
            }
          }}
        />
      ))}
    </div>
  )
}
