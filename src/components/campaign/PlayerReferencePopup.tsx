import { useState } from 'react'
import type { Player, Pokemon, Attack, Item, PlayerPokemon } from '../../types'
import { POKEDOLLAR_ITEM_NAME } from '../../types'
import { ReferencePopupShell } from './ReferencePopupShell'
import { PokemonOwnedCard } from '../PokemonOwnedCard'
import { PokemonDetailSheet } from '../PokemonDetailSheet'
import { usePlayerPokemon } from '../../hooks/usePlayerPokemon'
import { usePlayerItems } from '../../hooks/usePlayerItems'
import { useAdminParameters } from '../../hooks/useAdminParameters'
import { useGiftLootboxes } from '../../hooks/useGiftLootboxes'
import { maybeResetGiftTimerOnEntry } from '../../lib/gifting'
import { PixelIcon } from '../icons/PixelIcon'
import { NAV_ICON } from '../../lib/icons'
import { PokedollarIcon } from '../PokedollarIcon'

interface Props {
  player: Player
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  onClose: () => void
}

export function PlayerReferencePopup({ player, pokemonByName, attacksByName, itemsByName, onClose }: Props) {
  const { roster, updateXp, updateNickname, toggleInTeam, setNextGiftAt, deleteOwnedPokemon } = usePlayerPokemon(player.id)
  const { pokedollars } = usePlayerItems(player.id)
  const { parameters } = useAdminParameters()
  const { lootboxes, speciesAssignments } = useGiftLootboxes()
  const [selectedId, setSelectedId] = useState<number | null>(null)

  const handleToggleInTeam = async (id: number, inTeam: boolean) => {
    const pp = roster.find((r) => r.id === id)
    await toggleInTeam(id, inTeam)
    if (pp) {
      await maybeResetGiftTimerOnEntry({
        giftingEnabled: parameters.feature_gifting_enabled,
        isNpc: player.is_npc,
        wasInTeam: pp.in_team,
        willBeInTeam: inTeam,
        pokemonNom: pp.pokemon_nom,
        playerPokemonId: id,
        lootboxes,
        speciesAssignments,
        setNextGiftAt,
      })
    }
  }

  const team = roster.filter((r) => r.in_team)
  const teamFull = player.is_npc ? false : team.length >= parameters.max_team_size
  const selected: PlayerPokemon | null = roster.find((r) => r.id === selectedId) ?? null

  return (
    <ReferencePopupShell onClose={onClose}>
      <div className="flex items-center gap-3 mb-4">
        <div className="w-14 h-14 rounded-full overflow-hidden shrink-0 border-2" style={{ borderColor: player.color }}>
          {player.image_url ? (
            <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full" style={{ backgroundColor: player.color }} />
          )}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="text-ink font-bold truncate">{player.name}</span>
            {player.is_npc && (
              <span className="text-[10px] bg-purple-200 text-purple-900 border border-purple-700 rounded px-1.5 py-0.5">PNJ</span>
            )}
          </div>
          <div className="flex items-center gap-1 text-[#ffd75e] bg-black/70 border-2 border-ink rounded-full px-2.5 py-0.5 text-sm font-bold w-fit mt-1">
            <PokedollarIcon imageUrl={itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url} className="w-4 h-4" fallbackClassName="" />
            <span>{pokedollars}</span>
          </div>
        </div>
      </div>

      <p className="text-ink-muted-2 text-xs font-bold mb-2 flex items-center gap-1">
        <PixelIcon src={NAV_ICON.equipe!} size={14} colored />
        Équipe {player.is_npc ? `(${team.length})` : `(${team.length} / ${parameters.max_team_size})`}
      </p>
      {team.length === 0 ? (
        <p className="text-ink-muted-2 text-sm">Aucun Pokémon dans l'équipe.</p>
      ) : (
        <div className="flex flex-col gap-2">
          {team.map((pp) => (
            <PokemonOwnedCard
              key={pp.id}
              playerPokemon={pp}
              pokemon={pokemonByName.get(pp.pokemon_nom)}
              variant="list"
              onClick={() => setSelectedId(pp.id)}
            />
          ))}
        </div>
      )}

      {selected && (
        <PokemonDetailSheet
          context="pokemon"
          pokemon={pokemonByName.get(selected.pokemon_nom)}
          playerPokemon={selected}
          attacksByName={attacksByName}
          isAdmin={true}
          teamFull={teamFull}
          isNpc={player.is_npc}
          maxMoves={parameters.max_moves}
          onUpdateXp={updateXp}
          onRename={updateNickname}
          onToggleInTeam={handleToggleInTeam}
          onDelete={deleteOwnedPokemon}
          onClose={() => setSelectedId(null)}
        />
      )}
    </ReferencePopupShell>
  )
}
