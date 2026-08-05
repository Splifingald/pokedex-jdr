import { useState, useMemo, useRef } from 'react'
import { usePlayers } from '../hooks/usePlayers'
import { usePokemon } from '../hooks/usePokemon'
import { useAttacks } from '../hooks/useAttacks'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { useItems } from '../hooks/useItems'
import { usePlayerItems } from '../hooks/usePlayerItems'
import { usePokemonEvolutions } from '../hooks/usePokemonEvolutions'
import type { Player } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { TeamTab } from './TeamTab'
import { PlayerProfilePopup } from './PlayerProfilePopup'
import { AddEditPlayerPopup } from './AddEditPlayerPopup'
import { PlayerSearchInput } from './PlayerSearchInput'
import { PixelIcon } from './icons/PixelIcon'
import { NAV_ICON } from '../lib/icons'

export function AdminPlayersPanel() {
  const { players, loading, createPlayer, updatePlayer, deletePlayer } = usePlayers()
  const { pokemon, discovered } = usePokemon()
  const { byName: attacksByName } = useAttacks()
  const { parameters } = useAdminParameters()
  const { byName: itemsByName } = useItems()
  const { byPokemonNom: evolutionsByPokemonNom } = usePokemonEvolutions()
  const pokemonByName = useMemo(() => new Map(pokemon.map((p) => [p.nom, p])), [pokemon])
  const [profileEditingId, setProfileEditingId] = useState<number | null>(null)
  const profileEditing = players.find((p) => p.id === profileEditingId) ?? null
  const [addEditTarget, setAddEditTarget] = useState<Player | 'new' | null>(null)
  const [confirmingDeleteId, setConfirmingDeleteId] = useState<number | null>(null)
  const [viewingTeamPlayer, setViewingTeamPlayer] = useState<Player | null>(null)
  const [highlightedId, setHighlightedId] = useState<number | null>(null)
  const viewingTeamPlayerItems = usePlayerItems(viewingTeamPlayer?.id ?? null)
  const rowRefs = useRef(new Map<number, HTMLDivElement>())

  const regularPlayers = players.filter((p) => !p.is_npc)
  const npcs = players.filter((p) => p.is_npc)

  const handleSearchSelect = (p: Player) => {
    setHighlightedId(p.id)
    rowRefs.current.get(p.id)?.scrollIntoView({ behavior: 'smooth', block: 'center' })
  }

  const handleSave = async (data: { name: string; color: string; image_url: string; is_npc: boolean }) => {
    if (addEditTarget && addEditTarget !== 'new') {
      await updatePlayer(addEditTarget.id, data)
    } else {
      await createPlayer(data)
    }
  }

  const handleDelete = async (p: Player) => {
    await deletePlayer(p.id)
    setConfirmingDeleteId(null)
  }

  const renderRow = (p: Player, npc: boolean) => (
    <div
      key={p.id}
      ref={(el) => { if (el) rowRefs.current.set(p.id, el); else rowRefs.current.delete(p.id) }}
      className={`flex items-center gap-2 bg-cream-secondary border-2 rounded px-2 py-1.5 ${
        viewingTeamPlayer?.id === p.id || highlightedId === p.id
          ? 'border-[#a3841a] ring-2 ring-[#a3841a]'
          : npc ? 'border-purple-700' : 'border-ink'
      }`}
    >
      <div className="w-8 h-8 rounded-full overflow-hidden shrink-0 border-2" style={{ borderColor: p.color }}>
        {p.image_url ? (
          <img src={p.image_url} alt={p.name} className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full" style={{ backgroundColor: p.color }} />
        )}
      </div>
      <span className="text-ink text-sm flex-1 truncate">{p.name}</span>
      {confirmingDeleteId === p.id ? (
        <>
          <span className="text-red-700 text-xs">Supprimer {p.name} et son roster ?</span>
          <button onClick={() => handleDelete(p)} className={`text-xs rounded px-2 py-1 font-bold ${BUTTON_STYLE.red}`}>
            Confirmer
          </button>
          <button onClick={() => setConfirmingDeleteId(null)} className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}>
            Annuler
          </button>
        </>
      ) : (
        <>
          <button
            onClick={() => setViewingTeamPlayer(viewingTeamPlayer?.id === p.id ? null : p)}
            className={`text-xs rounded px-2 py-1 inline-flex items-center gap-1 ${viewingTeamPlayer?.id === p.id ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
          >
            <PixelIcon src={NAV_ICON.equipe!} size={12} colored /> Équipe
          </button>
          {npc && (
            <button onClick={() => setProfileEditingId(p.id)} className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}>
              Profil
            </button>
          )}
          <button onClick={() => setAddEditTarget(p)} className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}>
            Éditer
          </button>
          <button onClick={() => setConfirmingDeleteId(p.id)} className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}>
            Suppr.
          </button>
        </>
      )}
    </div>
  )

  return (
    <div className="flex flex-col md:flex-row gap-4 w-full items-start">
      <div className={`bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6 ${viewingTeamPlayer ? 'md:w-96 shrink-0' : ''}`}>
        <div className="flex items-center justify-between gap-2 mb-4">
          <div className="flex items-center gap-2">
            <span className="text-2xl">🧑‍🤝‍🧑</span>
            <h3 className="text-[#a3841a] text-lg font-bold">Joueurs</h3>
          </div>
          <button
            onClick={() => setAddEditTarget('new')}
            className={`text-sm rounded px-3 py-1.5 font-bold ${BUTTON_STYLE.yellow}`}
          >
            + Nouveau Joueur
          </button>
        </div>

        <div className="mb-4">
          <PlayerSearchInput options={players} onSelect={handleSearchSelect} />
        </div>

        {loading ? (
          <p className="text-ink-muted-2 text-sm mb-4">Chargement…</p>
        ) : players.length === 0 ? (
          <p className="text-ink-muted-2 text-sm mb-4">Aucun joueur pour l'instant.</p>
        ) : (
          <div>
            {regularPlayers.length > 0 && (
              <div className="flex flex-col gap-2 mb-3">
                {regularPlayers.map((p) => renderRow(p, false))}
              </div>
            )}

            {npcs.length > 0 && (
              <>
                <p className="text-purple-800 text-xs font-bold mb-2 mt-1">PNJ</p>
                <div className="flex flex-col gap-2">
                  {npcs.map((p) => renderRow(p, true))}
                </div>
              </>
            )}
          </div>
        )}
      </div>

      {viewingTeamPlayer && (
        <div className="flex-1 min-w-0 bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
          <div className="flex items-center justify-between mb-3">
            <p className="text-[#a3841a] text-lg font-bold">Équipe de {viewingTeamPlayer.name}</p>
            <button
              onClick={() => setViewingTeamPlayer(null)}
              className={`text-sm rounded px-3 py-1.5 ${BUTTON_STYLE.gray}`}
            >
              ✕ Fermer
            </button>
          </div>
          <TeamTab
            player={viewingTeamPlayer}
            pokemonList={pokemon}
            discovered={discovered}
            isAdmin={true}
            pokemonByName={pokemonByName}
            attacksByName={attacksByName}
            itemsByName={itemsByName}
            playerItems={viewingTeamPlayerItems}
            evolutionsByPokemonNom={evolutionsByPokemonNom}
          />
        </div>
      )}

      {addEditTarget && (
        <AddEditPlayerPopup
          editingPlayer={addEditTarget === 'new' ? null : addEditTarget}
          onSave={handleSave}
          onClose={() => setAddEditTarget(null)}
        />
      )}

      {profileEditing && (
        <PlayerProfilePopup
          player={profileEditing}
          canEdit={true}
          parameters={parameters}
          onUpdate={updatePlayer}
          onClose={() => setProfileEditingId(null)}
        />
      )}
    </div>
  )
}
