import { useMemo, useState } from 'react'
import type { Pokemon, Attack, Encounter } from '../../types'
import { usePlayers } from '../../hooks/usePlayers'
import { useCarteLocations } from '../../hooks/useCarteLocations'
import { useItems } from '../../hooks/useItems'
import { useEncounters } from '../../hooks/useEncounters'
import { useCampaignSessions } from '../../hooks/useCampaignSessions'
import { useReferenceIndex } from '../../hooks/useReferenceIndex'
import { useDisplayState } from '../../hooks/useDisplayState'
import { useDisplayAssets } from '../../hooks/useDisplayAssets'
import { SessionCard } from './SessionCard'
import { SessionDetailView } from './SessionDetailView'
import { EmojiPickerButton } from './EmojiPickerButton'
import { BannerPickerButton } from './BannerPickerButton'
import { CampaignIcon } from './CampaignIcon'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'

interface Props {
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
}

const emptySessionForm = { title: '', icon: '📓', session_date: '', image_url: '' }

export function CampagneTab({ pokemonByName, attacksByName }: Props) {
  const { players } = usePlayers()
  const { locations } = useCarteLocations()
  const { items, byName: itemsByName } = useItems()
  const { encounters } = useEncounters()
  const { sessions, loading, createSession, updateSession, deleteSession, reorderSessions } = useCampaignSessions()
  const { state: displayState, updateDisplayState } = useDisplayState()
  const { assets: displayAssets } = useDisplayAssets()

  const [selectedSessionId, setSelectedSessionId] = useState<number | null>(null)
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState(emptySessionForm)
  const [creating, setCreating] = useState(false)
  const [draggedSessionId, setDraggedSessionId] = useState<number | null>(null)

  const pokemonList = useMemo(() => [...pokemonByName.values()], [pokemonByName])
  const attacksList = useMemo(() => [...attacksByName.values()], [attacksByName])
  const playersByName = useMemo(() => new Map(players.map((p) => [p.name, p])), [players])
  const locationsByName = useMemo(() => new Map(locations.map((l) => [l.titre, l])), [locations])
  const encountersByLieu = useMemo(() => {
    const map = new Map<string, Encounter[]>()
    for (const enc of encounters) {
      const list = map.get(enc.lieu) ?? []
      list.push(enc)
      map.set(enc.lieu, list)
    }
    return map
  }, [encounters])

  const referenceIndex = useReferenceIndex(pokemonList, players, locations, attacksList, items)

  const selectedSession = sessions.find((s) => s.id === selectedSessionId) ?? null

  if (selectedSession) {
    return (
      <SessionDetailView
        session={selectedSession}
        onUpdateSession={(id, data) => updateSession(id, data)}
        onDeleteSession={(id) => { deleteSession(id); setSelectedSessionId(null) }}
        onBack={() => setSelectedSessionId(null)}
        referenceIndex={referenceIndex}
        pokemonByName={pokemonByName}
        attacksByName={attacksByName}
        itemsByName={itemsByName}
        playersByName={playersByName}
        locationsByName={locationsByName}
        encountersByLieu={encountersByLieu}
        displayState={displayState}
        displayAssets={displayAssets}
        updateDisplayState={updateDisplayState}
      />
    )
  }

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.title.trim()) return
    setCreating(true)
    const created = await createSession({
      title: form.title,
      icon: form.icon,
      session_date: form.session_date || null,
      image_url: form.image_url.trim() || null,
    })
    setCreating(false)
    setForm(emptySessionForm)
    setShowForm(false)
    if (created) setSelectedSessionId(created.id)
  }

  const handleDrop = (targetId: number) => {
    if (draggedSessionId == null || draggedSessionId === targetId) {
      setDraggedSessionId(null)
      return
    }
    const ids = sessions.map((s) => s.id)
    const from = ids.indexOf(draggedSessionId)
    const to = ids.indexOf(targetId)
    ids.splice(to, 0, ids.splice(from, 1)[0])
    reorderSessions(ids)
    setDraggedSessionId(null)
  }

  return (
    <div className="flex-1 overflow-y-auto p-4">
      <div className="flex items-center justify-between mb-3">
        <h2 className="text-cream text-lg font-bold">📓 Journal de campagne</h2>
        <button onClick={() => setShowForm((s) => !s)} className={`text-sm rounded px-3 py-1.5 font-bold ${BUTTON_STYLE.yellow}`}>
          + Nouvelle session
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleCreate} className="mb-4 p-3 rounded-lg bg-cream-secondary border-2 border-ink max-w-sm">
          <div className="flex items-center gap-2 mb-2">
            <EmojiPickerButton
              trigger={<CampaignIcon icon={form.icon} size={24} emojiClassName="text-xl" />}
              triggerClassName={`w-10 h-10 rounded-lg text-xl flex items-center justify-center shrink-0 ${PIXEL_BORDER_SM} bg-cream`}
              onSelect={(icon) => setForm((f) => ({ ...f, icon }))}
              itemsByName={itemsByName}
              pokemonByName={pokemonByName}
              playersByName={playersByName}
            />
            <input
              type="text"
              value={form.title}
              onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
              placeholder="Titre de la session"
              className="flex-1 bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
          <input
            type="date"
            value={form.session_date}
            onChange={(e) => setForm((f) => ({ ...f, session_date: e.target.value }))}
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none mb-2"
          />
          <div className="flex items-center gap-2 mb-3">
            <BannerPickerButton
              displayAssets={displayAssets}
              onSelect={(url) => setForm((f) => ({ ...f, image_url: url }))}
              variant="button"
              label={form.image_url ? "Changer l'image" : 'Choisir une image'}
            />
            {form.image_url && (
              <button
                type="button"
                onClick={() => setForm((f) => ({ ...f, image_url: '' }))}
                className={`text-xs px-2 py-2 rounded ${BUTTON_STYLE.gray}`}
              >
                Retirer
              </button>
            )}
          </div>
          <button
            type="submit"
            disabled={creating || !form.title.trim()}
            className={`w-full py-2 rounded text-sm font-bold disabled:opacity-50 ${BUTTON_STYLE.yellow}`}
          >
            Créer
          </button>
        </form>
      )}

      {loading ? (
        <p className="text-[#7a7c9a] text-sm">Chargement…</p>
      ) : sessions.length === 0 ? (
        <p className="text-[#7a7c9a] text-sm">Aucune session pour l'instant.</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {sessions.map((session) => (
            <div
              key={session.id}
              draggable
              onDragStart={() => setDraggedSessionId(session.id)}
              onDragOver={(e) => e.preventDefault()}
              onDrop={() => handleDrop(session.id)}
              onDragEnd={() => setDraggedSessionId(null)}
              className={draggedSessionId === session.id ? 'opacity-40' : ''}
            >
              <SessionCard session={session} onClick={() => setSelectedSessionId(session.id)} />
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
