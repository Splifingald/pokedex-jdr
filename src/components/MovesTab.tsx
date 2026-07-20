import { useMemo } from 'react'
import type { PlayerPokemon, Pokemon, Attack } from '../types'
import { OwnedPokemonHeader } from './OwnedPokemonHeader'
import { MoveSearchInput } from './MoveSearchInput'
import { TypeBadge } from './TypeBadge'
import { useLocalHp } from '../hooks/useLocalHp'
import { useLocalStatus } from '../hooks/useLocalStatus'
import { getMaxHp } from '../lib/maxHp'
import { getPrecisionColor } from '../lib/precisionColor'

interface Props {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  maxMoves: number
  attacksByName: Map<string, Attack>
  onUpdateXp: (id: number, xp: number) => void
  onAddMove: (id: number, moveName: string) => void
  onRemoveMove: (id: number, moveName: string) => void
  onGoToInfo: () => void
  onBack: () => void
}

function MoveStatIcon({ icon, value, style }: { icon: string; value: React.ReactNode; style?: React.CSSProperties }) {
  return (
    <div className="flex items-center gap-1.5 text-xs">
      <span className="shrink-0">{icon}</span>
      <span className="text-gray-200" style={style}>{value ?? '—'}</span>
    </div>
  )
}

export function MovesTab({ playerPokemon, pokemon, maxMoves, attacksByName, onUpdateXp, onAddMove, onRemoveMove, onGoToInfo, onBack }: Props) {
  const maxHp = getMaxHp(playerPokemon, pokemon)
  const [hp, setHp] = useLocalHp(playerPokemon.id, maxHp)
  const [status, setStatus] = useLocalStatus(playerPokemon.id)

  const searchOptions = useMemo(
    () => [...attacksByName.values()].filter((a) => !playerPokemon.moves.includes(a.nom)),
    [attacksByName, playerPokemon.moves]
  )

  const atCap = playerPokemon.moves.length >= maxMoves

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
        onGoToInfo={onGoToInfo}
      />

      <div className="px-4 py-4">
        <h3 className="text-white text-sm mb-2">
          Capacités ({playerPokemon.moves.length} / {maxMoves})
        </h3>

        <div className="mb-4">
          <MoveSearchInput
            options={searchOptions}
            disabled={atCap}
            onSelect={(a) => onAddMove(playerPokemon.id, a.nom)}
          />
        </div>

        {playerPokemon.moves.length === 0 ? (
          <p className="text-gray-500 text-sm">Aucune capacité apprise.</p>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {playerPokemon.moves.map((moveName) => {
              const atk = attacksByName.get(moveName)
              return (
                <div key={moveName} className="bg-gray-800 border border-gray-700 rounded-lg p-3">
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2 min-w-0">
                      {atk && <TypeBadge type={atk.type} small />}
                      <span className="text-white text-sm font-bold truncate">{moveName}</span>
                    </div>
                    <button
                      onClick={() => onRemoveMove(playerPokemon.id, moveName)}
                      className="text-gray-500 hover:text-red-400 text-sm leading-none shrink-0 ml-2"
                      title="Retirer la capacité"
                    >
                      ✕
                    </button>
                  </div>

                  {atk ? (
                    <div className="flex flex-col gap-1.5">
                      {atk.effet && (
                        <p className="text-gray-300 text-xs italic border-b border-gray-700 pb-1.5">{atk.effet}</p>
                      )}
                      <div className="grid grid-cols-2 gap-x-3 gap-y-1">
                        <div className="flex flex-col gap-1">
                          <MoveStatIcon icon="↔️" value={atk.distance} />
                          <MoveStatIcon icon="👊" value={atk.degats_base} />
                          <MoveStatIcon icon="🎲" value={atk.degats_de} />
                        </div>
                        <div className="flex flex-col gap-1">
                          <MoveStatIcon icon="👤" value={atk.cible} />
                          <MoveStatIcon
                            icon="🎯"
                            value={atk.precision}
                            style={{ color: getPrecisionColor(atk.precision), fontWeight: 'bold' }}
                          />
                        </div>
                      </div>
                    </div>
                  ) : (
                    <p className="text-gray-500 text-xs">Capacité introuvable dans la table attacks.</p>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
