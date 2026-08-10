import { useEffect, useMemo, useRef, useState } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import { Extension } from '@tiptap/core'
import type { Player, Pokemon, Attack, Item, PlayerItem, PlayerPokemon, Trade } from '../../types'
import type { useChatMessages } from '../../hooks/useChatMessages'
import { useCarteLocations } from '../../hooks/useCarteLocations'
import { useVisualViewportHeight } from '../../hooks/useVisualViewportHeight'
import { useTrades } from '../../hooks/useTrades'
import { useReferenceIndex, type ReferenceEntry } from '../../hooks/useReferenceIndex'
import { ReferenceHighlight, forceReferenceRecompute } from '../../lib/referenceExtension'
import { chatCooldownSeconds } from '../../lib/chatSpam'
import { ChatMessageBubble } from './ChatMessageBubble'
import { ChatReferenceDispatcher } from './ChatReferenceDispatcher'
import { TradePopup } from './TradePopup'
import { TradeSwapAnimation } from './TradeSwapAnimation'
import { ChatEmojiButton } from './ChatEmojiButton'
import { buildSwapAnimProps } from '../../lib/trade'
import { CloseIcon } from '../icons/CloseIcon'
import { PixelIcon } from '../icons/PixelIcon'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { CHAT_ICON } from '../../lib/icons'

interface Props {
  player: Player
  players: Player[]
  chat: ReturnType<typeof useChatMessages>
  inventory: PlayerItem[]
  roster: PlayerPokemon[]
  pokemonByName: Map<string, Pokemon>
  discoveredPokemon: Set<string>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  maxMessageLength: number
  spamLimitPerMinute: number
  onClose: () => void
}

// Extension minimale liant Entrée à l'envoi (comportement de chat classique,
// pas de saut de ligne) — le callback est lu via une ref pour toujours appeler
// la dernière version de handleSend sans reconfigurer l'éditeur à chaque frappe.
const SubmitOnEnter = Extension.create<{ getOnSubmit: () => () => void }>({
  name: 'submitOnEnter',
  addKeyboardShortcuts() {
    return {
      Enter: () => { this.options.getOnSubmit()(); return true },
      'Shift-Enter': () => true,
    }
  },
})

export function ChatPopup({ player, players, chat, inventory, roster, pokemonByName, discoveredPokemon, attacksByName, itemsByName, maxMessageLength, spamLimitPerMinute, onClose }: Props) {
  const { locations } = useCarteLocations()
  const viewport = useVisualViewportHeight()
  const trades = useTrades()
  const [activeReference, setActiveReference] = useState<ReferenceEntry | null>(null)
  const [tradePopup, setTradePopup] = useState<{ trade?: Trade } | null>(null)
  const [replayTrade, setReplayTrade] = useState<Trade | null>(null)
  const [now, setNow] = useState(() => Date.now())
  const listRef = useRef<HTMLDivElement>(null)

  const playersById = useMemo(() => new Map(players.map((p) => [p.id, p])), [players])
  const locationsByName = useMemo(() => new Map(locations.map((l) => [l.titre, l])), [locations])

  const discoveredPokemonList = useMemo(
    () => [...pokemonByName.values()].filter((p) => discoveredPokemon.has(p.nom)),
    [pokemonByName, discoveredPokemon]
  )
  const itemsList = useMemo(() => [...itemsByName.values()], [itemsByName])

  // Pas de joueurs/capacités/chapitres référençables dans le chat (voir ChatReferenceDispatcher)
  const referenceIndex = useReferenceIndex(discoveredPokemonList, [], locations, [], itemsList, [])
  const indexRef = useRef(referenceIndex)
  useEffect(() => { indexRef.current = referenceIndex }, [referenceIndex])

  useEffect(() => {
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight })
  }, [chat.messages.length])

  const cooldown = chatCooldownSeconds(chat.messages, player.id, spamLimitPerMinute, now)
  useEffect(() => {
    if (cooldown <= 0) return
    const interval = window.setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(interval)
  }, [cooldown])

  const handleSendRef = useRef<() => void>(() => {})
  // Suivi explicite du texte via onUpdate plutôt que editor.getText() lu en direct
  // au rendu : le rerender automatique de useEditor sur transaction peut accuser
  // un léger retard aux tout premiers caractères tapés, ce qui laissait le bouton
  // "Envoyer" désactivé un instant après le début de la frappe.
  const [text, setText] = useState('')

  const editor = useEditor({
    content: '',
    extensions: [
      StarterKit.configure({
        heading: false, bulletList: false, orderedList: false, listItem: false,
        blockquote: false, codeBlock: false, horizontalRule: false,
        bold: false, italic: false, strike: false, code: false,
      }),
      // eslint-disable-next-line react-hooks/refs
      ReferenceHighlight.configure({
        getIndex: () => indexRef.current,
        onReferenceClick: (entry) => setActiveReference(entry),
      }),
      // eslint-disable-next-line react-hooks/refs
      SubmitOnEnter.configure({ getOnSubmit: () => handleSendRef.current }),
    ],
    onUpdate: ({ editor }) => setText(editor.getText()),
  })

  useEffect(() => {
    if (editor) forceReferenceRecompute(editor)
  }, [editor, referenceIndex])

  const trimmed = text.trim()
  const overLimit = text.length > maxMessageLength
  const canSend = trimmed.length > 0 && !overLimit && cooldown <= 0

  const handleSend = () => {
    if (!canSend || !editor) return
    void chat.sendMessage(player.id, trimmed, false)
    editor.commands.clearContent()
    setText('')
    setNow(Date.now())
  }
  useEffect(() => { handleSendRef.current = handleSend })

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-0 sm:p-4"
      style={viewport ? { height: viewport.height, top: viewport.offsetTop } : undefined}
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className="relative bg-cream w-full h-full overflow-hidden flex flex-col
        sm:h-auto sm:max-w-md sm:max-h-[85vh] sm:rounded-[var(--radius-pixel)] sm:border-[3px] sm:border-ink sm:shadow-[var(--shadow-pixel-lg)]"
      >
        <div className="flex items-center gap-2 p-3 border-b-2 border-[#cfc7a8] shrink-0">
          <PixelIcon src={CHAT_ICON} size={24} colored className="text-ink" />
          <h3 className="text-ink font-bold flex-1">Chat</h3>
          <button onClick={onClose} className={`w-8 h-8 rounded-md text-sm font-bold ${BUTTON_STYLE.gray}`}>
            <CloseIcon className="w-4 h-4 mx-auto" />
          </button>
        </div>

        <div ref={listRef} className="flex-1 overflow-y-auto p-3 flex flex-col gap-3">
          {chat.messages.length === 0 && (
            <p className="text-ink-muted-2 text-sm text-center mt-4">Aucun message pour le moment.</p>
          )}
          {chat.messages.map((message) => (
            <ChatMessageBubble
              key={message.id}
              message={message}
              sender={playersById.get(message.player_id)}
              mine={message.player_id === player.id && !message.is_npc}
              referenceIndex={referenceIndex}
              onReferenceClick={setActiveReference}
              trades={trades.trades}
              players={players}
              itemsByName={itemsByName}
              pokemonByName={pokemonByName}
              onOpenTrade={(trade) => setTradePopup({ trade })}
              onReplayTrade={(trade) => setReplayTrade(trade)}
            />
          ))}
        </div>

        <div className="p-3 border-t-2 border-[#cfc7a8] shrink-0">
          {cooldown > 0 && (
            <p className="text-hp-red text-xs font-bold mb-1.5">
              Trop de messages envoyés — attends {cooldown}s avant de renvoyer.
            </p>
          )}
          <div className="flex items-end gap-2">
            <div className="flex-1 bg-white border-2 border-ink rounded-lg px-3 py-2 max-h-24 overflow-y-auto">
              <EditorContent editor={editor} className="chat-input text-ink text-sm outline-none" />
            </div>
            <ChatEmojiButton onSelect={(emoji) => editor?.chain().focus().insertContent(emoji).run()} />
            <button
              onClick={handleSend}
              disabled={!canSend}
              className={`px-4 py-2 rounded-lg text-sm font-bold shrink-0 ${canSend ? BUTTON_STYLE.blue : 'bg-[#3a3c58] text-[#7a7c9a] border-2 border-[#6a6a6a] cursor-not-allowed'}`}
            >
              Envoyer
            </button>
          </div>
          <p className={`text-[10px] mt-1 text-right ${overLimit ? 'text-hp-red font-bold' : 'text-ink-muted-2'}`}>
            {text.length} / {maxMessageLength}
          </p>
          <button
            onClick={() => setTradePopup({})}
            className={`w-full mt-2 px-3 py-1.5 rounded-lg text-xs font-bold ${BUTTON_STYLE.yellow}`}
          >
            🔄 Proposer un échange
          </button>
        </div>
      </div>

      {tradePopup && (
        <TradePopup
          player={player}
          players={players}
          inventory={inventory}
          roster={roster}
          itemsByName={itemsByName}
          pokemonByName={pokemonByName}
          attacksByName={attacksByName}
          trades={trades}
          chat={chat}
          existingTrade={tradePopup.trade}
          onClose={() => setTradePopup(null)}
        />
      )}

      <ChatReferenceDispatcher
        activeReference={activeReference}
        pokemonByName={pokemonByName}
        attacksByName={attacksByName}
        itemsByName={itemsByName}
        locationsByName={locationsByName}
        onClose={() => setActiveReference(null)}
      />

      {replayTrade && (() => {
        const anim = buildSwapAnimProps(replayTrade, players, pokemonByName)
        return anim ? <TradeSwapAnimation {...anim} onDone={() => setReplayTrade(null)} /> : null
      })()}
    </div>
  )
}
