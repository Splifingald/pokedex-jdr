import { useState, useMemo } from 'react'
import type { Player, Pokemon, Attack, PlayerPokemon } from '../types'
import { ownedPokemonName } from '../types'
import { usePlayerPokemon } from '../hooks/usePlayerPokemon'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { useGiftLootboxes } from '../hooks/useGiftLootboxes'
import { useToast } from '../context/ToastContext'
import { restoreLocalHp } from '../hooks/useLocalHp'
import { getMaxHp } from '../lib/maxHp'
import { maybeResetGiftTimerOnEntry } from '../lib/gifting'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { Chip } from './Chip'
import { PokemonOwnedCard } from './PokemonOwnedCard'
import { PokemonSearchInput } from './PokemonSearchInput'
import { PokemonDetailSheet } from './PokemonDetailSheet'

type SortKey = 'numero' | 'type' | 'alpha' | 'equipe'

const SORT_LABELS: Record<SortKey, string> = { numero: '#', type: 'Type', alpha: 'A-Z', equipe: 'Équipe' }

interface Props {
  player: Player
  pokemonList: Pokemon[]
  discovered: Set<string>
  isAdmin: boolean
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
}

export function TeamTab({ player, pokemonList, discovered, isAdmin, pokemonByName, attacksByName }: Props) {
  const { roster, loading, addOwnedPokemon, updateXp, updateNickname, toggleInTeam, setNextGiftAt, addMove, removeMove, deleteOwnedPokemon } = usePlayerPokemon(player.id)
  const { parameters } = useAdminParameters()
  const { lootboxes, speciesAssignments } = useGiftLootboxes()
  const { showToast } = useToast()

  const [selectedId, setSelectedId] = useState<number | null>(null)
  const [sortKey, setSortKey] = useState<SortKey>('numero')

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
      list.sort((a, b) => ownedPokemonName(a).localeCompare(ownedPokemonName(b), 'fr'))
    } else if (sortKey === 'equipe') {
      list.sort((a, b) => (b.in_team ? 1 : 0) - (a.in_team ? 1 : 0) || byNumero(a, b))
    } else {
      list.sort(byNumero)
    }
    return list
  }, [roster, sortKey, player.is_npc, pokemonByName])

  const selected = roster.find((r) => r.id === selectedId) ?? null

  const handleAddOwned = async (p: Pokemon) => {
    const inTeam = !teamFull
    const created = await addOwnedPokemon(p.nom, p.numero, inTeam)
    if (created) {
      await maybeResetGiftTimerOnEntry({
        giftingEnabled: parameters.feature_gifting_enabled,
        isNpc: player.is_npc,
        wasInTeam: false,
        willBeInTeam: inTeam,
        pokemonNom: p.nom,
        playerPokemonId: created.id,
        lootboxes,
        speciesAssignments,
        setNextGiftAt,
      })
    }
    showToast(`${p.nom} ajouté ${inTeam ? "à l'équipe" : 'au PC'} !`)
  }

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
    showToast(`${pp ? ownedPokemonName(pp) : 'Pokémon'} ${inTeam ? "ajouté à l'équipe" : 'mis au PC'} !`)
  }

  const handleDeleteOwned = async (id: number) => {
    const pp = roster.find((r) => r.id === id)
    await deleteOwnedPokemon(id)
    setSelectedId(null)
    showToast(`${pp ? ownedPokemonName(pp) : 'Pokémon'} supprimé.`)
  }

  const handleRestoreAll = () => {
    sortedRoster.forEach((pp) => {
      restoreLocalHp(pp.id, getMaxHp(pp, pokemonByName.get(pp.pokemon_nom)))
    })
    showToast('Pokémon soignés !')
  }

  return (
    <div className="flex-1 overflow-y-auto p-4">
      <div className="mb-4">
        <PokemonSearchInput
          options={addableOptions}
          onSelect={handleAddOwned}
          placeholder="Ajouter un pokémon…"
        />
      </div>

      {/* Tri + disposition + soin */}
      <div className="flex items-center gap-1.5 flex-wrap mb-3.5">
        {(Object.keys(SORT_LABELS) as SortKey[]).map((k) => (
          <Chip key={k} label={SORT_LABELS[k]} active={sortKey === k} onClick={() => setSortKey(k)} />
        ))}
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
      ) : (
        <div className="grid gap-2.5" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(max(150px, 11.5%), 1fr))' }}>
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
      )}

      {selected && (
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
          onRename={updateNickname}
          onToggleInTeam={handleToggleInTeam}
          onAddMove={addMove}
          onRemoveMove={removeMove}
          onDelete={handleDeleteOwned}
          onSetNextGiftAt={setNextGiftAt}
          onClose={() => setSelectedId(null)}
        />
      )}
    </div>
  )
}
