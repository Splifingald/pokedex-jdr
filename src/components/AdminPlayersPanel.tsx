import { useState, useEffect, useMemo } from 'react'
import { usePlayers } from '../hooks/usePlayers'
import { usePokemon } from '../hooks/usePokemon'
import { useAttacks } from '../hooks/useAttacks'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { PLAYER_COLORS } from '../types'
import type { Player } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { TeamTab } from './TeamTab'
import { PlayerProfilePopup } from './PlayerProfilePopup'
import { PixelIcon } from './icons/PixelIcon'
import { NAV_ICON } from '../lib/icons'

const emptyForm = { name: '', color: PLAYER_COLORS[0], image_url: '', is_npc: false }

export function AdminPlayersPanel() {
  const { players, loading, createPlayer, updatePlayer, deletePlayer } = usePlayers()
  const { pokemon, discovered } = usePokemon()
  const { byName: attacksByName } = useAttacks()
  const { parameters } = useAdminParameters()
  const pokemonByName = useMemo(() => new Map(pokemon.map((p) => [p.nom, p])), [pokemon])
  const [editing, setEditing] = useState<Player | null>(null)
  const [profileEditingId, setProfileEditingId] = useState<number | null>(null)
  const profileEditing = players.find((p) => p.id === profileEditingId) ?? null
  const [form, setForm] = useState(emptyForm)
  const [saving, setSaving] = useState(false)
  const [confirmingDeleteId, setConfirmingDeleteId] = useState<number | null>(null)
  const [viewingTeamPlayer, setViewingTeamPlayer] = useState<Player | null>(null)

  const regularPlayers = players.filter((p) => !p.is_npc)
  const npcs = players.filter((p) => p.is_npc)

  useEffect(() => {
    setForm(editing ? { name: editing.name, color: editing.color, image_url: editing.image_url, is_npc: editing.is_npc } : emptyForm)
  }, [editing])

  if (viewingTeamPlayer) {
    return (
      <div className="w-full">
        <button
          onClick={() => setViewingTeamPlayer(null)}
          className={`mb-3 text-sm rounded px-3 py-1.5 ${BUTTON_STYLE.gray}`}
        >
          ← Retour aux joueurs
        </button>
        <p className="text-[#a3841a] text-lg font-bold mb-2">Équipe de {viewingTeamPlayer.name}</p>
        <TeamTab
          player={viewingTeamPlayer}
          pokemonList={pokemon}
          discovered={discovered}
          isAdmin={true}
          pokemonByName={pokemonByName}
          attacksByName={attacksByName}
        />
      </div>
    )
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.name.trim()) return
    setSaving(true)
    if (editing) {
      await updatePlayer(editing.id, form)
    } else {
      await createPlayer(form)
    }
    setSaving(false)
    setEditing(null)
    setForm(emptyForm)
  }

  const handleDelete = async (p: Player) => {
    await deletePlayer(p.id)
    setConfirmingDeleteId(null)
    if (editing?.id === p.id) setEditing(null)
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] max-w-sm w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">🧑‍🤝‍🧑</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Joueurs</h3>
      </div>

      {loading ? (
        <p className="text-ink-muted-2 text-sm mb-4">Chargement…</p>
      ) : players.length === 0 ? (
        <p className="text-ink-muted-2 text-sm mb-4">Aucun joueur pour l'instant.</p>
      ) : (
        <div className="mb-5">
          {regularPlayers.length > 0 && (
            <div className="flex flex-col gap-2 mb-3">
              {regularPlayers.map((p) => (
                <div key={p.id} className="flex items-center gap-2 bg-cream-secondary border-2 border-ink rounded px-2 py-1.5">
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
                      <button
                        onClick={() => handleDelete(p)}
                        className={`text-xs rounded px-2 py-1 font-bold ${BUTTON_STYLE.red}`}
                      >
                        Confirmer
                      </button>
                      <button
                        onClick={() => setConfirmingDeleteId(null)}
                        className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}
                      >
                        Annuler
                      </button>
                    </>
                  ) : (
                    <>
                      <button
                        onClick={() => setViewingTeamPlayer(p)}
                        className={`text-xs rounded px-2 py-1 inline-flex items-center gap-1 ${BUTTON_STYLE.gray}`}
                      >
                        <PixelIcon src={NAV_ICON.equipe!} size={12} colored /> Équipe
                      </button>
                      <button
                        onClick={() => setEditing(p)}
                        className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}
                      >
                        Éditer
                      </button>
                      <button
                        onClick={() => setConfirmingDeleteId(p.id)}
                        className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}
                      >
                        Suppr.
                      </button>
                    </>
                  )}
                </div>
              ))}
            </div>
          )}

          {npcs.length > 0 && (
            <>
              <p className="text-purple-800 text-xs font-bold mb-2 mt-1">PNJ</p>
              <div className="flex flex-col gap-2">
                {npcs.map((p) => (
                  <div key={p.id} className="flex items-center gap-2 bg-cream-secondary border-2 border-purple-700 rounded px-2 py-1.5">
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
                        <button
                          onClick={() => handleDelete(p)}
                          className={`text-xs rounded px-2 py-1 font-bold ${BUTTON_STYLE.red}`}
                        >
                          Confirmer
                        </button>
                        <button
                          onClick={() => setConfirmingDeleteId(null)}
                          className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}
                        >
                          Annuler
                        </button>
                      </>
                    ) : (
                      <>
                        <button
                          onClick={() => setViewingTeamPlayer(p)}
                          className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}
                        >
                          🐾 Équipe
                        </button>
                        <button
                          onClick={() => setProfileEditingId(p.id)}
                          className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}
                        >
                          Profil
                        </button>
                        <button
                          onClick={() => setEditing(p)}
                          className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}
                        >
                          Éditer
                        </button>
                        <button
                          onClick={() => setConfirmingDeleteId(p.id)}
                          className={`text-xs rounded px-2 py-1 ${BUTTON_STYLE.gray}`}
                        >
                          Suppr.
                        </button>
                      </>
                    )}
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      )}

      <form onSubmit={handleSubmit} className="border-t-2 border-[#cfc7a8] pt-4">
        <p className="text-ink-muted-2 text-xs mb-3">{editing ? `Modifier ${editing.name}` : 'Nouveau joueur'}</p>

        <div className="flex items-center gap-3 mb-3">
          <div className="w-14 h-14 rounded-full overflow-hidden shrink-0 border-2" style={{ borderColor: form.color }}>
            {form.image_url ? (
              <img src={form.image_url} alt="Aperçu" className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full" style={{ backgroundColor: form.color }} />
            )}
          </div>
          <input
            type="text"
            value={form.name}
            onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
            placeholder="Nom du joueur"
            className="flex-1 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
        </div>

        <input
          type="text"
          value={form.image_url}
          onChange={(e) => setForm((f) => ({ ...f, image_url: e.target.value }))}
          placeholder="Lien de l'image de profil"
          className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none mb-3"
        />

        <div className="flex gap-2 mb-4">
          {PLAYER_COLORS.map((c) => (
            <button
              key={c}
              type="button"
              onClick={() => setForm((f) => ({ ...f, color: c }))}
              className={`w-6 h-6 rounded-full ${form.color === c ? 'ring-2 ring-offset-2 ring-offset-cream ring-ink' : ''}`}
              style={{ backgroundColor: c }}
            />
          ))}
        </div>

        <label className="flex items-center gap-2 mb-4 text-sm text-ink-muted">
          <input
            type="checkbox"
            checked={form.is_npc}
            onChange={(e) => setForm((f) => ({ ...f, is_npc: e.target.checked }))}
            className="w-4 h-4"
          />
          Est un PNJ
        </label>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {editing && (
            <button
              type="button"
              onClick={() => setEditing(null)}
              className={`py-2 rounded text-sm ${BUTTON_STYLE.gray}`}
            >
              Annuler
            </button>
          )}
          <button
            type="submit"
            disabled={saving || !form.name.trim()}
            className={`py-2 rounded text-sm font-bold disabled:opacity-50 ${BUTTON_STYLE.yellow}`}
          >
            {editing ? 'Enregistrer' : 'Créer'}
          </button>
        </div>
      </form>

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
