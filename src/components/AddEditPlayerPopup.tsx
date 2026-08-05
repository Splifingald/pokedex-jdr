import { useState } from 'react'
import { PLAYER_COLORS } from '../types'
import type { Player } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'

const emptyForm = { name: '', color: PLAYER_COLORS[0], image_url: '', is_npc: false }

interface Props {
  editingPlayer: Player | null
  onSave: (data: typeof emptyForm) => Promise<void> | void
  onClose: () => void
}

export function AddEditPlayerPopup({ editingPlayer, onSave, onClose }: Props) {
  const [form, setForm] = useState(
    editingPlayer
      ? { name: editingPlayer.name, color: editingPlayer.color, image_url: editingPlayer.image_url, is_npc: editingPlayer.is_npc }
      : emptyForm
  )
  const [saving, setSaving] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.name.trim()) return
    setSaving(true)
    await onSave(form)
    setSaving(false)
    onClose()
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <form
        onSubmit={handleSubmit}
        className="bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-sm w-full p-6"
      >
        <p className="text-[#a3841a] text-lg font-bold mb-4">{editingPlayer ? `Modifier ${editingPlayer.name}` : 'Nouveau joueur'}</p>

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

        <label className="flex items-center gap-2 mb-5 text-sm text-ink-muted">
          <input
            type="checkbox"
            checked={form.is_npc}
            onChange={(e) => setForm((f) => ({ ...f, is_npc: e.target.checked }))}
            className="w-4 h-4"
          />
          Est un PNJ
        </label>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <button
            type="button"
            onClick={onClose}
            className={`py-2 rounded text-sm ${BUTTON_STYLE.gray}`}
          >
            Annuler
          </button>
          <button
            type="submit"
            disabled={saving || !form.name.trim()}
            className={`py-2 rounded text-sm font-bold disabled:opacity-50 ${BUTTON_STYLE.yellow}`}
          >
            {editingPlayer ? 'Enregistrer' : 'Créer'}
          </button>
        </div>
      </form>
    </div>
  )
}
