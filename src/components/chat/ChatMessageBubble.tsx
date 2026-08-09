import { Fragment } from 'react'
import type { Player, ChatMessage } from '../../types'
import type { ReferenceEntry, ReferenceIndex } from '../../hooks/useReferenceIndex'

interface Props {
  message: ChatMessage
  sender: Player | undefined
  mine: boolean
  referenceIndex: ReferenceIndex
  onReferenceClick: (entry: ReferenceEntry) => void
}

// Découpe le texte du message sur les correspondances de l'index de référence
// (objet/pokémon/lieu déjà filtré en amont) et rend chaque match comme un span
// cliquable — équivalent en lecture seule du surlignage Tiptap de l'éditeur.
function renderContent(content: string, index: ReferenceIndex, onReferenceClick: (entry: ReferenceEntry) => void) {
  const { matcher, lookup } = index
  matcher.lastIndex = 0
  const parts: React.ReactNode[] = []
  let lastIndex = 0
  let m: RegExpExecArray | null
  let key = 0

  while ((m = matcher.exec(content))) {
    const entry = lookup.get(m[0].toLowerCase())
    if (entry) {
      if (m.index > lastIndex) parts.push(<Fragment key={key++}>{content.slice(lastIndex, m.index)}</Fragment>)
      parts.push(
        <button
          key={key++}
          onClick={() => onReferenceClick(entry)}
          className="inline font-bold underline decoration-dotted underline-offset-2"
          style={entry.color ? { color: entry.color } : undefined}
        >
          {entry.icon && (entry.type === 'pokemon' || entry.type === 'item') && (
            <img src={entry.icon} alt="" className="inline w-4 h-4 align-text-bottom mr-0.5 pixelated" />
          )}
          {entry.type === 'location' && <span className="mr-0.5">📍</span>}
          {m[0]}
        </button>
      )
      lastIndex = m.index + m[0].length
    }
    if (m.index === matcher.lastIndex) matcher.lastIndex++
  }
  if (lastIndex < content.length) parts.push(<Fragment key={key}>{content.slice(lastIndex)}</Fragment>)
  return parts
}

export function ChatMessageBubble({ message, sender, mine, referenceIndex, onReferenceClick }: Props) {
  const color = sender?.color ?? '#a3841a'
  const name = sender?.name ?? (message.is_npc ? 'PNJ' : 'Joueur inconnu')

  return (
    <div className={`flex flex-col ${mine ? 'items-end' : 'items-start'}`}>
      <div className={`flex items-center gap-1.5 mb-1 ${mine ? 'flex-row-reverse' : ''}`}>
        <div className="w-6 h-6 rounded-full overflow-hidden shrink-0 border-2" style={{ borderColor: color }}>
          {sender?.image_url ? (
            <img src={sender.image_url} alt={name} className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full" style={{ backgroundColor: color }} />
          )}
        </div>
        <span className="text-xs font-bold text-ink-muted">{name}</span>
      </div>
      <div
        className="max-w-[80%] rounded-lg px-3 py-2 text-sm text-ink bg-cream break-words whitespace-pre-wrap border-2"
        style={{ borderColor: color }}
      >
        {renderContent(message.content, referenceIndex, onReferenceClick)}
      </div>
    </div>
  )
}
