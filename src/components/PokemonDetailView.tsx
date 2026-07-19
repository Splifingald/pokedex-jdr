import { useState } from 'react'
import type { PlayerPokemon, Pokemon } from '../types'
import { PokemonDetailHeader } from './PokemonDetailHeader'
import { StatRow } from './StatRow'
import { TypeBadge } from './TypeBadge'
import { AudioDescriptionPlayer } from './AudioDescriptionPlayer'
import { ConfirmPopup } from './ConfirmPopup'
import { useLocalHp } from '../hooks/useLocalHp'
import { getMaxHp } from '../lib/maxHp'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  teamFull: boolean
  maxMoves: number
  onUpdateXp: (id: number, xp: number) => void
  onToggleInTeam: (id: number, inTeam: boolean) => void
  onUpdateMaxHpOverride: (id: number, maxHp: number) => void
  onManageMoves: () => void
  onDelete: (id: number) => void
  onBack: () => void
}

const TRANSPORT_ICONS: Record<string, string> = {
  Vol: '🕊️',
  Nage: '🏊',
  Sol: '🐾',
}

export function PokemonDetailView({ playerPokemon, pokemon, teamFull, maxMoves, onUpdateXp, onToggleInTeam, onUpdateMaxHpOverride, onManageMoves, onDelete, onBack }: Props) {
  const maxHp = getMaxHp(playerPokemon, pokemon)
  const [hp, setHp] = useLocalHp(playerPokemon.id, maxHp)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)

  const superEfficace = pokemon
    ? [pokemon.super_efficace_1, pokemon.super_efficace_2, pokemon.super_efficace_3, pokemon.super_efficace_4].filter(Boolean) as string[]
    : []

  const localisations = pokemon
    ? [pokemon.localisation_1, pokemon.localisation_2, pokemon.localisation_3].filter(Boolean) as string[]
    : []

  return (
    <div className="flex flex-col h-full bg-gray-900 overflow-y-auto">
      <PokemonDetailHeader
        pokemonNom={playerPokemon.pokemon_nom}
        pokemon={pokemon}
        hp={hp}
        maxHp={maxHp}
        onHpChange={setHp}
        onMaxHpChange={(value) => onUpdateMaxHpOverride(playerPokemon.id, value)}
        xp={playerPokemon.xp}
        onXpChange={(xp) => onUpdateXp(playerPokemon.id, xp)}
        onBack={onBack}
        onManageMoves={onManageMoves}
        movesCount={playerPokemon.moves.length}
        maxMoves={maxMoves}
      />

      {pokemon?.audio_url && <AudioDescriptionPlayer key={pokemon.id} audioUrl={pokemon.audio_url} />}

      <div className="px-4 py-2 flex flex-col gap-3">
        {pokemon && (
          <>
            <div className="flex items-center gap-2 py-1">
              <span className="text-gray-400 text-sm">Type</span>
              <TypeBadge type={pokemon.type} />
            </div>

            <StatRow icon="❤️" label="PV de base" value={pokemon.pv_base} />
            <StatRow icon="⚔️" label="Dégâts de base" value={pokemon.degats_base} />
            <StatRow icon="👟" label="Distance" value={`${pokemon.distance_deplacement} cases`} />

            {pokemon.transport && (
              <StatRow
                icon={TRANSPORT_ICONS[pokemon.transport] ?? '🚚'}
                label="Transport"
                value={`${pokemon.transport}${pokemon.transport_value != null ? ` (${pokemon.transport_value})` : ''}`}
              />
            )}

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
          </>
        )}

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-4 mb-4">
          {playerPokemon.in_team ? (
            <button
              onClick={() => onToggleInTeam(playerPokemon.id, false)}
              className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.blue}`}
            >
              📦 Ajouter au PC
            </button>
          ) : !teamFull ? (
            <button
              onClick={() => onToggleInTeam(playerPokemon.id, true)}
              className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.blue}`}
            >
              + Ajouter à l'équipe
            </button>
          ) : (
            <div title="Équipe complète">
              <button
                disabled
                className={`w-full py-2.5 rounded text-sm font-bold disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.blue}`}
              >
                + Ajouter à l'équipe
              </button>
            </div>
          )}

          <button
            onClick={() => setShowDeleteConfirm(true)}
            className={`py-2.5 rounded text-sm ${BUTTON_STYLE.gray}`}
          >
            🗑 Supprimer ce pokémon
          </button>
        </div>
      </div>

      {showDeleteConfirm && (
        <ConfirmPopup
          title="Supprimer ce pokémon ?"
          message={`${playerPokemon.pokemon_nom} sera définitivement retiré de votre roster.`}
          confirmLabel="Supprimer"
          danger
          onConfirm={() => { onDelete(playerPokemon.id); setShowDeleteConfirm(false) }}
          onCancel={() => setShowDeleteConfirm(false)}
        />
      )}
    </div>
  )
}
