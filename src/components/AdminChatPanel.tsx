import { useState } from 'react'
import { usePlayers } from '../hooks/usePlayers'
import { useChatMessages } from '../hooks/useChatMessages'
import { useAdminParameters } from '../hooks/useAdminParameters'
import type { Player } from '../types'
import { PlayerSearchInput } from './PlayerSearchInput'
import { ConfirmPopup } from './ConfirmPopup'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { TrashIcon } from './icons/TrashIcon'

function Avatar({ player }: { player?: Player }) {
  return (
    <div className="w-8 h-8 rounded-full overflow-hidden shrink-0 border-2" style={{ borderColor: player?.color ?? '#a3841a' }}>
      {player?.image_url ? (
        <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
      ) : (
        <div className="w-full h-full" style={{ backgroundColor: player?.color ?? '#a3841a' }} />
      )}
    </div>
  )
}

export function AdminChatPanel() {
  const { players } = usePlayers()
  const chat = useChatMessages()
  const { parameters, updateParameters } = useAdminParameters()
  const [confirmClear, setConfirmClear] = useState(false)
  const [npc, setNpc] = useState<Player | null>(null)
  const [text, setText] = useState('')
  const [notify, setNotify] = useState(true)
  const [sending, setSending] = useState(false)

  const playersById = new Map(players.map((p) => [p.id, p]))
  const npcOptions = players.filter((p) => p.is_npc)
  const overLimit = text.length > parameters.chat_max_message_length

  const handleSend = async () => {
    const trimmed = text.trim()
    if (!npc || !trimmed || overLimit || sending) return
    setSending(true)
    try {
      const message = await chat.sendMessage(npc.id, trimmed, true)
      if (message && notify) {
        await fetch('/.netlify/functions/send-chat-notification', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ messageId: message.id, senderPlayerId: npc.id }),
        }).catch((err) => console.error("Erreur lors de l'envoi de la notification :", err))
      }
      setText('')
      setNpc(null)
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="space-y-6 max-w-2xl">
      <div className={`p-4 rounded-lg ${PIXEL_BORDER_SM} bg-cream-secondary`}>
        <h3 className="text-ink font-bold mb-3">Paramètres</h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <label className="text-sm text-ink-muted">
            Longueur max. d'un message
            <input
              type="number"
              min={1}
              value={parameters.chat_max_message_length}
              onChange={(e) => updateParameters({ chat_max_message_length: Math.max(1, parseInt(e.target.value, 10) || 1) })}
              className="mt-1 w-full bg-white border-2 border-ink rounded-lg px-3 py-1.5 text-ink text-sm outline-none"
            />
          </label>
          <label className="text-sm text-ink-muted">
            Limite anti-spam (messages / minute)
            <input
              type="number"
              min={1}
              value={parameters.chat_spam_limit_per_minute}
              onChange={(e) => updateParameters({ chat_spam_limit_per_minute: Math.max(1, parseInt(e.target.value, 10) || 1) })}
              className="mt-1 w-full bg-white border-2 border-ink rounded-lg px-3 py-1.5 text-ink text-sm outline-none"
            />
          </label>
        </div>
        <p className="text-ink-muted-2 text-xs mt-2">
          L'activation/désactivation du chat se fait dans Admin → Paramètres → Fonctionnalités.
        </p>
      </div>

      <div className={`p-4 rounded-lg ${PIXEL_BORDER_SM} bg-cream-secondary`}>
        <h3 className="text-ink font-bold mb-3">Envoyer un message en tant que PNJ</h3>
        <div className="space-y-2">
          {npc ? (
            <div className="flex items-center gap-2 bg-white border-2 border-ink rounded-lg px-3 py-2">
              <Avatar player={npc} />
              <span className="text-ink text-sm font-bold flex-1">{npc.name}</span>
              <button onClick={() => setNpc(null)} className={`px-2 py-1 rounded text-xs ${BUTTON_STYLE.gray}`}>Changer</button>
            </div>
          ) : (
            <PlayerSearchInput options={npcOptions} onSelect={setNpc} placeholder="Choisir un PNJ…" />
          )}
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Message…"
            rows={3}
            className="w-full bg-white border-2 border-ink rounded-lg px-3 py-2 text-ink text-sm outline-none resize-none"
          />
          <p className={`text-[10px] text-right ${overLimit ? 'text-hp-red font-bold' : 'text-ink-muted-2'}`}>
            {text.length} / {parameters.chat_max_message_length}
          </p>
          <label className="flex items-center gap-2 text-sm text-ink-muted">
            <input type="checkbox" checked={notify} onChange={(e) => setNotify(e.target.checked)} className="w-4 h-4" />
            Notifier les joueurs (push instantané)
          </label>
          <button
            onClick={handleSend}
            disabled={!npc || !text.trim() || overLimit || sending}
            className={`px-4 py-2 rounded-lg text-sm font-bold ${npc && text.trim() && !overLimit && !sending ? BUTTON_STYLE.blue : 'bg-[#3a3c58] text-[#7a7c9a] border-2 border-[#6a6a6a] cursor-not-allowed'}`}
          >
            Envoyer
          </button>
        </div>
      </div>

      <div className={`p-4 rounded-lg ${PIXEL_BORDER_SM} bg-cream-secondary`}>
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-ink font-bold">Messages ({chat.messages.length})</h3>
          <button onClick={() => setConfirmClear(true)} className={`px-3 py-1.5 rounded text-xs font-bold ${BUTTON_STYLE.red}`}>
            Tout effacer
          </button>
        </div>
        <div className="space-y-2 max-h-96 overflow-y-auto">
          {[...chat.messages].reverse().map((m) => {
            const sender = playersById.get(m.player_id)
            return (
              <div key={m.id} className="flex items-start gap-2 bg-white border-2 border-ink rounded-lg px-3 py-2">
                <Avatar player={sender} />
                <div className="flex-1 min-w-0">
                  <p className="text-ink text-xs font-bold">
                    {sender?.name ?? 'Joueur inconnu'} {m.is_npc && <span className="text-purple-800">(PNJ)</span>}
                  </p>
                  <p className="text-ink-muted text-sm whitespace-pre-wrap break-words">{m.content}</p>
                </div>
                <button onClick={() => chat.deleteMessage(m.id)} className={`p-1.5 rounded shrink-0 ${BUTTON_STYLE.gray}`}>
                  <TrashIcon className="w-4 h-4" />
                </button>
              </div>
            )
          })}
        </div>
      </div>

      {confirmClear && (
        <ConfirmPopup
          title="Vider le chat ?"
          message="Tous les messages seront définitivement supprimés."
          confirmLabel="Tout effacer"
          danger
          onConfirm={() => { setConfirmClear(false); chat.clearAll() }}
          onCancel={() => setConfirmClear(false)}
        />
      )}
    </div>
  )
}
