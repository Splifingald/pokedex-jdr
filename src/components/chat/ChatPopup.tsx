import { useEffect, useMemo, useRef, useState } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import { Extension } from '@tiptap/core'
import type { Player, Pokemon, Attack, Item } from '../../types'
import type { useChatMessages } from '../../hooks/useChatMessages'
import { useCarteLocations } from '../../hooks/useCarteLocations'
import { useReferenceIndex, type ReferenceEntry } from '../../hooks/useReferenceIndex'
import { ReferenceHighlight, forceReferenceRecompute } from '../../lib/referenceExtension'
import { chatCooldownSeconds } from '../../lib/chatSpam'
import { ChatMessageBubble } from './ChatMessageBubble'
import { ChatReferenceDispatcher } from './ChatReferenceDispatcher'
import { CloseIcon } from '../icons/CloseIcon'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  player: Player
  players: Player[]
  chat: ReturnType<typeof useChatMessages>
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

export function ChatPopup({ player, players, chat, pokemonByName, discoveredPokemon, attacksByName, itemsByName, maxMessageLength, spamLimitPerMinute, onClose }: Props) {
  const { locations } = useCarteLocations()
  const [activeReference, setActiveReference] = useState<ReferenceEntry | null>(null)
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
  })

  useEffect(() => {
    if (editor) forceReferenceRecompute(editor)
  }, [editor, referenceIndex])

  const text = editor?.getText() ?? ''
  const trimmed = text.trim()
  const overLimit = text.length > maxMessageLength
  const canSend = trimmed.length > 0 && !overLimit && cooldown <= 0

  const handleSend = () => {
    if (!canSend || !editor) return
    void chat.sendMessage(player.id, trimmed, false)
    editor.commands.clearContent()
    setNow(Date.now())
  }
  useEffect(() => { handleSendRef.current = handleSend })

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-0 sm:p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className="relative bg-cream w-full h-full overflow-hidden flex flex-col
        sm:h-auto sm:max-w-md sm:max-h-[85vh] sm:rounded-[var(--radius-pixel)] sm:border-[3px] sm:border-ink sm:shadow-[var(--shadow-pixel-lg)]"
      >
        <div className="flex items-center gap-2 p-3 border-b-2 border-[#cfc7a8] shrink-0">
          <span className="text-xl">💬</span>
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
        </div>
      </div>

      <ChatReferenceDispatcher
        activeReference={activeReference}
        pokemonByName={pokemonByName}
        attacksByName={attacksByName}
        itemsByName={itemsByName}
        locationsByName={locationsByName}
        onClose={() => setActiveReference(null)}
      />
    </div>
  )
}
