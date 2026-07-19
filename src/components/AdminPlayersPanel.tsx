import { useState, useEffect } from 'react'
import { usePlayers } from '../hooks/usePlayers'
import { PLAYER_COLORS } from '../types'
import type { Player } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'

const emptyForm = { name: '', color: PLAYER_COLORS[0], image_url: '' }

export function AdminPlayersPanel() {
  const { players, loading, createPlayer, updatePlayer, deletePlayer } = usePlayers()
  const [editing, setEditing] = useState<Player | null>(null)
  const [form, setForm] = useState(emptyForm)
  const [saving, setSaving] = useState(false)
  const [confirmingDeleteId, setConfirmingDeleteId] = useState<number | null>(null)

  useEffect(() => {
    setForm(editing ? { name: editing.name, color: editing.color, image_url: editing.image_url } : emptyForm)
  }, [editing])

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
    <div className="bg-gray-900 border-2 border-yellow-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-sm w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">🧑‍🤝‍🧑</span>
        <h3 className="text-yellow-400 text-lg">Joueurs</h3>
      </div>

      {loading ? (
        <p className="text-gray-500 text-sm mb-4">Chargement…</p>
      ) : players.length === 0 ? (
        <p className="text-gray-500 text-sm mb-4">Aucun joueur pour l'instant.</p>
      ) : (
        <div className="flex flex-col gap-2 mb-5">
          {players.map((p) => (
            <div key={p.id} className="flex items-center gap-2 bg-gray-800 border border-gray-700 rounded px-2 py-1.5">
              <div className="w-8 h-8 rounded-full overflow-hidden shrink-0 border-2" style={{ borderColor: p.color }}>
                {p.image_url ? (
                  <img src={p.image_url} alt={p.name} className="w-full h-full object-cover" />
                ) : (
                  <div className="w-full h-full" style={{ backgroundColor: p.color }} />
                )}
              </div>
              <span className="text-white text-sm flex-1 truncate">{p.name}</span>
              {confirmingDeleteId === p.id ? (
                <>
                  <span className="text-red-400 text-xs">Supprimer {p.name} et son roster ?</span>
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

      <form onSubmit={handleSubmit} className="border-t border-gray-700 pt-4">
        <p className="text-gray-400 text-xs mb-3">{editing ? `Modifier ${editing.name}` : 'Nouveau joueur'}</p>

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
            className="flex-1 bg-gray-800 border border-gray-600 rounded px-3 py-2 text-white text-sm outline-none focus:border-red-400"
          />
        </div>

        <input
          type="text"
          value={form.image_url}
          onChange={(e) => setForm((f) => ({ ...f, image_url: e.target.value }))}
          placeholder="Lien de l'image de profil"
          className="w-full bg-gray-800 border border-gray-600 rounded px-3 py-2 text-white text-sm outline-none focus:border-red-400 mb-3"
        />

        <div className="flex gap-2 mb-4">
          {PLAYER_COLORS.map((c) => (
            <button
              key={c}
              type="button"
              onClick={() => setForm((f) => ({ ...f, color: c }))}
              className={`w-6 h-6 rounded-full ${form.color === c ? 'ring-2 ring-offset-2 ring-offset-gray-900 ring-white' : ''}`}
              style={{ backgroundColor: c }}
            />
          ))}
        </div>

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
    </div>
  )
}
