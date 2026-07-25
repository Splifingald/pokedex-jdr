import { useMemo } from 'react'
import type { PlayerPokemon, Pokemon, Attack } from '../types'
import { ownedPokemonName } from '../types'
import { OwnedPokemonHeader } from './OwnedPokemonHeader'
import { MoveSearchInput } from './MoveSearchInput'
import { AbilityCard } from './AbilityCard'
import { useLocalHp } from '../hooks/useLocalHp'
import { useLocalStatus } from '../hooks/useLocalStatus'
import { getMaxHp } from '../lib/maxHp'

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
    <div className="flex-1 flex flex-col overflow-y-auto">
      <OwnedPokemonHeader
        pokemonNom={ownedPokemonName(playerPokemon)}
        pokemon={pokemon}
        hp={hp}
        maxHp={maxHp}
        onHpChange={setHp}
        xp={playerPokemon.xp}
        onXpChange={(xp) => onUpdateXp(playerPokemon.id, xp)}
        status={status}
        onStatusChange={setStatus}
        onBack={onBack}
        actionLabel="Info"
        onAction={onGoToInfo}
      />

      <div className="px-4 py-4">
        <h3 className="text-cream text-sm mb-2">
          🥊 Capacités ({playerPokemon.moves.length} / {maxMoves})
        </h3>

        <div className="mb-4">
          <MoveSearchInput
            options={searchOptions}
            disabled={atCap}
            onSelect={(a) => onAddMove(playerPokemon.id, a.nom)}
          />
        </div>

        {playerPokemon.moves.length === 0 ? (
          <p className="text-[#7a7c9a] text-sm">Aucune capacité apprise.</p>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {playerPokemon.moves.map((moveName) => {
              const atk = attacksByName.get(moveName)
              return atk ? (
                <AbilityCard
                  key={moveName}
                  attack={atk}
                  onRemove={() => onRemoveMove(playerPokemon.id, moveName)}
                />
              ) : (
                <div key={moveName} className="bg-cream-secondary border-2 border-ink rounded-lg p-3 flex items-center justify-between gap-2">
                  <div>
                    <p className="text-ink text-sm font-bold">{moveName}</p>
                    <p className="text-ink-muted-2 text-xs">Capacité introuvable dans la table attacks.</p>
                  </div>
                  <button
                    onClick={() => onRemoveMove(playerPokemon.id, moveName)}
                    className="text-ink-muted-2 hover:text-hp-red text-sm leading-none shrink-0"
                    title="Retirer la capacité"
                  >
                    ✕
                  </button>
                </div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
