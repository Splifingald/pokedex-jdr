import { useState } from 'react'
import type { useOnlineState } from '../../hooks/useOnlineState'
import { splitSessionAt, joinSessionAt } from '../../lib/onlineSession'
import { PANEL } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { NumberInput } from '../NumberInput'
import { useToast } from '../../context/ToastContext'

interface Props {
  online: ReturnType<typeof useOnlineState>
}

const INPUT = 'bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none'

// Annonce de la prochaine session : date, heure, message libre, et à partir de
// combien de jours la pop-up commence à s'afficher chez les joueurs.
export function AdminOnlineSessionPanel({ online }: Props) {
  const { state, updateOnlineState } = online
  const { showToast } = useToast()

  const [date, setDate] = useState('')
  const [time, setTime] = useState('')
  const [message, setMessage] = useState('')
  const [daysBefore, setDaysBefore] = useState(5)
  const [notify, setNotify] = useState(false)
  const [saving, setSaving] = useState(false)

  // Resynchronisation du formulaire quand l'annonce arrive du serveur
  // (chargement initial, ou modification depuis un autre appareil). Fait au
  // rendu plutôt que dans un effet — le patron « ajuster l'état quand les props
  // changent » recommandé par React : pas de rendu intermédiaire avec les
  // anciennes valeurs, et on ne touche à rien tant que l'annonce elle-même n'a
  // pas bougé, donc une saisie en cours n'est jamais écrasée.
  const serverKey = `${state.session_at}|${state.session_message}|${state.session_visible_days_before}`
  const [syncedKey, setSyncedKey] = useState<string | null>(null)
  if (syncedKey !== serverKey) {
    const next = splitSessionAt(state.session_at)
    setSyncedKey(serverKey)
    setDate(next.dateInput)
    setTime(next.timeInput)
    setMessage(state.session_message)
    setDaysBefore(state.session_visible_days_before)
  }

  const save = async () => {
    setSaving(true)
    try {
      await updateOnlineState({
        session_at: joinSessionAt(date, time),
        session_message: message,
        session_visible_days_before: daysBefore,
      })
      if (!notify) {
        showToast('Annonce enregistrée.')
        return
      }
      const res = await fetch('/.netlify/functions/send-session-notification', { method: 'POST' })
        .catch((err) => { console.error('Erreur de notification :', err); return null })
      showToast(res && res.ok ? 'Annonce enregistrée et joueurs notifiés.' : 'Annonce enregistrée (notification échouée).')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className={`${PANEL} p-6 flex flex-col gap-4 max-w-2xl`}>
      <label className="flex items-center gap-2 cursor-pointer">
        <input
          type="checkbox"
          checked={state.session_announce_enabled}
          onChange={(e) => void updateOnlineState({ session_announce_enabled: e.target.checked })}
          className="w-4 h-4"
        />
        <span className="text-ink text-sm font-bold">Afficher l'annonce sur l'accueil des joueurs</span>
      </label>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Date</label>
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} className={`w-full ${INPUT}`} />
        </div>
        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Heure</label>
          <input type="time" value={time} onChange={(e) => setTime(e.target.value)} className={`w-full ${INPUT}`} />
        </div>
      </div>

      <div>
        <label className="text-ink-muted-2 text-sm block mb-1">Message (facultatif)</label>
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          rows={3}
          placeholder="Lieu, rappel, consignes…"
          className={`w-full resize-y ${INPUT}`}
        />
      </div>

      <div className="flex items-center gap-2 flex-wrap">
        <label className="text-ink-muted-2 text-sm">Visible à partir de</label>
        <NumberInput value={daysBefore} onCommit={setDaysBefore} min={0} className={`w-16 text-center ${INPUT}`} />
        <span className="text-ink-muted-2 text-sm">jours avant la session</span>
      </div>

      <label className="flex items-center gap-2 cursor-pointer">
        <input type="checkbox" checked={notify} onChange={(e) => setNotify(e.target.checked)} className="w-4 h-4" />
        <span className="text-ink text-sm">Notifier les joueurs à l'enregistrement</span>
      </label>

      <button
        onClick={() => void save()}
        disabled={saving}
        className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.green} disabled:opacity-60`}
      >
        {saving ? 'Enregistrement…' : 'Enregistrer'}
      </button>
    </div>
  )
}
