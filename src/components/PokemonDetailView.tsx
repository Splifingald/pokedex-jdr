import { useState } from 'react'
import type { PlayerPokemon, Pokemon, Attack } from '../types'
import { OwnedPokemonHeader } from './OwnedPokemonHeader'
import { StatRow } from './StatRow'
import { TypeBadge } from './TypeBadge'
import { AudioDescriptionPlayer } from './AudioDescriptionPlayer'
import { ConfirmPopup } from './ConfirmPopup'
import { useLocalHp } from '../hooks/useLocalHp'
import { useLocalStatus } from '../hooks/useLocalStatus'
import { getMaxHp } from '../lib/maxHp'
import { getHpBreakdown, getDamageBreakdown } from '../lib/xpBonuses'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  teamFull: boolean
  isNpc: boolean
  maxMoves: number
  attacksByName: Map<string, Attack>
  onUpdateXp: (id: number, xp: number) => void
  onToggleInTeam: (id: number, inTeam: boolean) => void
  onManageMoves: () => void
  onDelete: (id: number) => void
  onBack: () => void
}

const TRANSPORT_ICONS: Record<string, string> = {
  Vol: '🕊️',
  Nage: '🏊',
  Sol: '🐾',
}

export function PokemonDetailView({ playerPokemon, pokemon, teamFull, isNpc, maxMoves, attacksByName, onUpdateXp, onToggleInTeam, onManageMoves, onDelete, onBack }: Props) {
  const maxHp = getMaxHp(playerPokemon, pokemon)
  const [hp, setHp] = useLocalHp(playerPokemon.id, maxHp)
  const [status, setStatus] = useLocalStatus(playerPokemon.id)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const hpBreakdown = getHpBreakdown(pokemon, playerPokemon.xp)
  const dmgBreakdown = getDamageBreakdown(pokemon, playerPokemon.xp)

  const superEfficace = pokemon
    ? [pokemon.super_efficace_1, pokemon.super_efficace_2, pokemon.super_efficace_3, pokemon.super_efficace_4].filter(Boolean) as string[]
    : []

  const localisations = pokemon
    ? [pokemon.localisation_1, pokemon.localisation_2, pokemon.localisation_3].filter(Boolean) as string[]
    : []

  const attaques = pokemon
    ? [
        pokemon.attaque_1, pokemon.attaque_2, pokemon.attaque_3, pokemon.attaque_4, pokemon.attaque_5,
        pokemon.attaque_6, pokemon.attaque_7, pokemon.attaque_8, pokemon.attaque_9, pokemon.attaque_10,
      ].filter(Boolean) as string[]
    : []

  return (
    <div className="flex flex-col h-full bg-gray-900 overflow-y-auto">
      <OwnedPokemonHeader
        pokemonNom={playerPokemon.pokemon_nom}
        pokemon={pokemon}
        hp={hp}
        maxHp={maxHp}
        onHpChange={setHp}
        xp={playerPokemon.xp}
        onXpChange={(xp) => onUpdateXp(playerPokemon.id, xp)}
        status={status}
        onStatusChange={setStatus}
        onBack={onBack}
        actionLabel="💥 Capacités"
        actionTitle={`Gérer les capacités (${playerPokemon.moves.length}/${maxMoves})`}
        actionColor="orange"
        onAction={onManageMoves}
      />

      {pokemon?.audio_url && <AudioDescriptionPlayer key={pokemon.id} audioUrl={pokemon.audio_url} />}

      <div className="px-4 py-2 flex flex-col gap-3">
        {pokemon && (
          <>
            <StatRow
              icon="❤️" label="PV de base"
              value={hpBreakdown.bonus > 0 ? `${hpBreakdown.total} (${hpBreakdown.base} + ${hpBreakdown.bonus})` : hpBreakdown.total}
            />
            <StatRow
              icon="⚔️" label="Dégâts de base"
              value={dmgBreakdown.bonus > 0 ? `${dmgBreakdown.total} (${dmgBreakdown.base} + ${dmgBreakdown.bonus})` : dmgBreakdown.total}
            />
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

            {attaques.length > 0 && (
              <StatRow
                icon="🥊"
                label="Capacités"
                value={
                  <div className="flex flex-wrap gap-1">
                    {attaques.map((nom) => {
                      const atk = attacksByName.get(nom)
                      return atk ? (
                        <TypeBadge key={nom} type={atk.type} label={atk.nom} small />
                      ) : (
                        <span
                          key={nom}
                          className="text-xs text-gray-500 border border-gray-700 rounded px-1.5 py-0.5"
                        >
                          {nom}
                        </span>
                      )
                    })}
                  </div>
                }
              />
            )}

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

        <div className={`grid grid-cols-1 ${isNpc ? '' : 'sm:grid-cols-2'} gap-3 mt-4 mb-4`}>
          {isNpc ? null : playerPokemon.in_team ? (
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
