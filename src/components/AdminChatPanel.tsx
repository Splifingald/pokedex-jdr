import { useEffect, useMemo, useRef, useState } from 'react'
import { usePlayers } from '../hooks/usePlayers'
import { useChatMessages } from '../hooks/useChatMessages'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { usePokemon } from '../hooks/usePokemon'
import { useAttacks } from '../hooks/useAttacks'
import { useItems } from '../hooks/useItems'
import { usePlayerItems } from '../hooks/usePlayerItems'
import { usePlayerPokemon } from '../hooks/usePlayerPokemon'
import { useTrades } from '../hooks/useTrades'
import type { Player, Trade } from '../types'
import { tradeFallbackText, tradeStatusLabel } from '../lib/trade'
import { findMentionedPlayers, computeMentionSuggestion } from '../lib/chatMentions'
import { PlayerSearchInput } from './PlayerSearchInput'
import { ConfirmPopup } from './ConfirmPopup'
import { TradePopup } from './chat/TradePopup'
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
  const trades = useTrades()
  const { parameters, updateParameters } = useAdminParameters()
  const { pokemon } = usePokemon()
  const { byName: attacksByName } = useAttacks()
  const { byName: itemsByName } = useItems()
  const [confirmClear, setConfirmClear] = useState(false)
  const [npc, setNpc] = useState<Player | null>(null)
  const [text, setText] = useState('')
  const [notify, setNotify] = useState(true)
  const [sending, setSending] = useState(false)
  const [actingPlayer, setActingPlayer] = useState<Player | null>(null)
  const [tradeSimPopup, setTradeSimPopup] = useState<{ trade?: Trade } | null>(null)

  // Auto-complétion "@Nom" du message PNJ : sélection à appliquer après le prochain
  // rendu (le textarea étant contrôlé, on ne peut positionner le curseur qu'une fois
  // la nouvelle valeur reflétée dans le DOM).
  const npcTextareaRef = useRef<HTMLTextAreaElement>(null)
  const pendingMentionSelectionRef = useRef<[number, number] | null>(null)
  const npcTextLastCaretRef = useRef(0)

  useEffect(() => {
    const selection = pendingMentionSelectionRef.current
    if (!selection) return
    npcTextareaRef.current?.setSelectionRange(selection[0], selection[1])
    pendingMentionSelectionRef.current = null
  }, [text])

  const playersById = new Map(players.map((p) => [p.id, p]))
  const npcOptions = players.filter((p) => p.is_npc)
  const overLimit = text.length > parameters.chat_max_message_length
  const pokemonByName = useMemo(() => new Map(pokemon.map((p) => [p.nom, p])), [pokemon])
  const pendingTrades = useMemo(() => trades.trades.filter((t) => t.status === 'pending').sort((a, b) => b.created_at.localeCompare(a.created_at)), [trades.trades])

  const actingPlayerItems = usePlayerItems(actingPlayer?.id ?? null)
  const actingRoster = usePlayerPokemon(actingPlayer?.id ?? null)

  const handleNpcTextChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const value = e.target.value
    const caret = e.target.selectionStart ?? value.length
    const prevCaret = npcTextLastCaretRef.current
    npcTextLastCaretRef.current = caret

    // Ne suggérer qu'en frappe vers l'avant : un retour arrière/coller ne doit pas
    // faire réapparaître une suggestion qu'on vient d'effacer.
    if (caret > prevCaret) {
      const suggestion = computeMentionSuggestion(value.slice(0, caret), players)
      if (suggestion) {
        setText(value.slice(0, caret) + suggestion.suffix + value.slice(caret))
        pendingMentionSelectionRef.current = [caret, caret + suggestion.suffix.length]
        npcTextLastCaretRef.current = caret
        return
      }
    }
    setText(value)
  }

  // Tab valide la suggestion en cours (le suffixe auto-complété est sélectionné
  // juste après insertion) en repliant le curseur à sa fin, sans sortir du champ.
  const handleNpcTextKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key !== 'Tab') return
    const textarea = e.currentTarget
    if (textarea.selectionStart === textarea.selectionEnd) return
    e.preventDefault()
    const end = textarea.selectionEnd
    textarea.setSelectionRange(end, end)
    npcTextLastCaretRef.current = end
  }

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
      if (message) {
        const mentioned = findMentionedPlayers(trimmed, players)
        if (mentioned.length > 0) {
          await fetch('/.netlify/functions/send-mention-notification', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ senderPlayerId: npc.id, mentionedPlayerIds: mentioned.map((p) => p.id) }),
          }).catch((err) => console.error("Erreur lors de l'envoi de la notification de mention :", err))
        }
      }
      setText('')
      setNpc(null)
      npcTextLastCaretRef.current = 0
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
            ref={npcTextareaRef}
            value={text}
            onChange={handleNpcTextChange}
            onKeyDown={handleNpcTextKeyDown}
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
        <h3 className="text-ink font-bold mb-3">Simuler un échange</h3>
        <div className="space-y-2">
          {actingPlayer ? (
            <div className="flex items-center gap-2 bg-white border-2 border-ink rounded-lg px-3 py-2">
              <Avatar player={actingPlayer} />
              <span className="text-ink text-sm font-bold flex-1">{actingPlayer.name}</span>
              <button onClick={() => setActingPlayer(null)} className={`px-2 py-1 rounded text-xs ${BUTTON_STYLE.gray}`}>Changer</button>
            </div>
          ) : (
            <PlayerSearchInput options={players} onSelect={setActingPlayer} placeholder="Agir en tant que…" />
          )}

          {actingPlayer && (
            <>
              <button
                onClick={() => setTradeSimPopup({})}
                className={`px-4 py-2 rounded-lg text-sm font-bold ${BUTTON_STYLE.blue}`}
              >
                🔄 Nouvel échange
              </button>

              <div>
                <p className="text-ink-muted text-xs font-bold mt-2 mb-1">Échanges en attente ({pendingTrades.length})</p>
                {pendingTrades.length === 0 ? (
                  <p className="text-ink-muted-2 text-xs italic">Aucun échange en attente</p>
                ) : (
                  <div className="space-y-1.5 max-h-48 overflow-y-auto">
                    {pendingTrades.map((t) => (
                      <button
                        key={t.id}
                        onClick={() => setTradeSimPopup({ trade: t })}
                        className="w-full flex items-center gap-2 bg-white border-2 border-ink rounded-lg px-3 py-2 text-left hover:bg-cream-secondary transition-colors"
                      >
                        <Avatar player={playersById.get(t.proposer_id)} />
                        <span className="flex-1 min-w-0 text-ink text-xs truncate">
                          {tradeFallbackText(t.kind, t.offer, t.request, itemsByName)}
                        </span>
                        <span className="text-[10px] font-bold text-[#a3841a] shrink-0">{tradeStatusLabel(t.status)}</span>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </>
          )}
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

      {tradeSimPopup && actingPlayer && (
        <TradePopup
          player={actingPlayer}
          players={players}
          inventory={actingPlayerItems.inventory}
          roster={actingRoster.roster}
          itemsByName={itemsByName}
          pokemonByName={pokemonByName}
          attacksByName={attacksByName}
          trades={trades}
          chat={chat}
          existingTrade={tradeSimPopup.trade}
          onClose={() => setTradeSimPopup(null)}
        />
      )}
    </div>
  )
}
