import type { Pokemon } from '../types'
import { TypeBadge } from './TypeBadge'

interface Props {
  pokemon: Pokemon
  isAdmin: boolean
  onBack: () => void
}

function StatRow({ icon, label, value }: { icon: string; label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-start gap-3 py-2 border-b border-gray-700">
      <span className="text-xl w-7 shrink-0 text-center">{icon}</span>
      <span className="text-gray-400 text-sm w-32 shrink-0">{label}</span>
      <span className="text-white text-sm flex-1">{value}</span>
    </div>
  )
}

export function PokemonCard({ pokemon, isAdmin, onBack }: Props) {
  const superEfficace = [
    pokemon.super_efficace_1,
    pokemon.super_efficace_2,
    pokemon.super_efficace_3,
    pokemon.super_efficace_4,
  ].filter(Boolean) as string[]

  const localisations = [
    pokemon.localisation_1,
    pokemon.localisation_2,
    pokemon.localisation_3,
  ].filter(Boolean) as string[]

  return (
    <div className="flex flex-col h-full bg-gray-900 overflow-y-auto">
      {/* Header mobile retour */}
      <button
        onClick={onBack}
        className="md:hidden flex items-center gap-2 px-4 py-3 text-red-400 hover:text-red-300 border-b border-gray-700 shrink-0"
      >
        <span className="text-lg">◀</span>
        <span className="text-sm">Retour</span>
      </button>

      {/* Nom + type */}
      <div className="flex items-center justify-between px-6 py-4 border-b border-gray-700 shrink-0">
        <div>
          <p className="text-gray-400 text-sm">#{pokemon.numero}</p>
          <h2 className="text-white text-2xl">{pokemon.nom}</h2>
        </div>
        <TypeBadge type={pokemon.type} />
      </div>

      {/* Image illustrée */}
      <div className="bg-gray-800 flex items-center justify-center p-4 shrink-0" style={{ minHeight: '200px' }}>
        {pokemon.image_illustree ? (
          <img
            src={pokemon.image_illustree}
            alt={pokemon.nom}
            className="max-h-64 w-full object-contain"
          />
        ) : (
          <div className="text-gray-600 text-center">
            <span className="text-6xl block">?</span>
            <span className="text-sm">Pas d'image</span>
          </div>
        )}
      </div>

      {/* Stats */}
      <div className="px-4 py-2 flex-1">
        <StatRow icon="❤️" label="PV de base" value={pokemon.pv_base} />
        <StatRow icon="⚔️" label="Dégâts de base" value={pokemon.degats_base} />
        <StatRow icon="👟" label="Distance" value={`${pokemon.distance_deplacement} cases`} />

        <StatRow
          icon="✨"
          label="Super Efficace"
          value={
            superEfficace.length > 0 ? (
              <div className="flex flex-wrap gap-1">
                {superEfficace.map((t) => (
                  <TypeBadge key={t} type={t} small />
                ))}
              </div>
            ) : (
              <span className="text-gray-500">—</span>
            )
          }
        />

        {(pokemon.nom_talent || pokemon.description_talent) && (
          <div className="flex items-start gap-3 py-2 border-b border-gray-700">
            <span className="text-xl w-7 shrink-0 text-center">⭐</span>
            <div className="flex-1">
              {pokemon.nom_talent && (
                <p className="text-yellow-400 text-sm font-bold">{pokemon.nom_talent}</p>
              )}
              {pokemon.description_talent && (
                <p className="text-gray-300 text-sm mt-0.5">{pokemon.description_talent}</p>
              )}
            </div>
          </div>
        )}

        <StatRow
          icon="📍"
          label="Localisation"
          value={
            localisations.length > 0 ? (
              <div className="flex flex-col gap-0.5">
                {localisations.map((l) => (
                  <span key={l}>{l}</span>
                ))}
              </div>
            ) : (
              <span className="text-gray-500">—</span>
            )
          }
        />

        {isAdmin && pokemon.chances_capture && (
          <div className="flex items-start gap-3 py-2 border-b border-gray-700 bg-yellow-900/20 -mx-4 px-4 mt-1">
            <span className="text-xl w-7 shrink-0 text-center">🎯</span>
            <span className="text-gray-400 text-sm w-32 shrink-0">Capture</span>
            <span className="text-yellow-300 text-sm">{pokemon.chances_capture}</span>
          </div>
        )}
      </div>
    </div>
  )
}
