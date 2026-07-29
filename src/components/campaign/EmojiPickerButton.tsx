import { useEffect, useMemo, useState, type ReactNode } from 'react'
import EmojiPicker, { type EmojiClickData, Theme } from 'emoji-picker-react'
import type { Item, Pokemon, Player } from '../../types'
import { encodeIcon } from '../../lib/campaignIcon'
import { normalizeSearch } from '../../lib/normalizeSearch'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'

interface Props {
  onSelect: (icon: string) => void
  trigger: ReactNode
  triggerClassName?: string
  title?: string
  /** Si fourni (avec au moins une des 3 maps), ajoute des onglets pour choisir une image
   * d'objet / Pokémon / joueur comme icône, en plus des emoji. */
  itemsByName?: Map<string, Item>
  pokemonByName?: Map<string, Pokemon>
  playersByName?: Map<string, Player>
}

type Tab = 'emoji' | 'item' | 'pokemon' | 'player'

function TabButton({ active, onClick, children }: { active: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`px-2.5 py-1 rounded text-xs font-bold whitespace-nowrap ${active ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
    >
      {children}
    </button>
  )
}

function IconSearchTab<T>({
  options,
  getName,
  getImage,
  getKey,
  onPick,
  round,
}: {
  options: T[]
  getName: (t: T) => string
  getImage: (t: T) => string | null | undefined
  getKey: (t: T) => string | number
  onPick: (t: T) => void
  round?: boolean
}) {
  const [query, setQuery] = useState('')

  const filtered = useMemo(() => {
    const withImage = options.filter((o) => getImage(o))
    const q = normalizeSearch(query.trim())
    if (!q) return withImage.slice(0, 50)
    return withImage.filter((o) => normalizeSearch(getName(o)).includes(q)).slice(0, 50)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query, options])

  return (
    <div className="w-72 max-w-[80vw]">
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Rechercher…"
        className={`w-full px-3 py-2 rounded-lg ${PIXEL_BORDER_SM} bg-cream text-ink text-sm placeholder-ink-muted-2 outline-none mb-2`}
      />
      <div className={`max-h-72 overflow-y-auto rounded-lg bg-cream ${PIXEL_BORDER_SM}`}>
        {filtered.length === 0 ? (
          <p className="text-ink-muted-2 text-sm px-3 py-2">Aucun résultat</p>
        ) : (
          filtered.map((o) => (
            <button
              key={getKey(o)}
              type="button"
              onClick={() => onPick(o)}
              className="w-full flex items-center gap-2 px-3 py-2 border-b border-[#cfc7a8] last:border-b-0 hover:bg-cream-secondary transition-colors text-left"
            >
              <img
                src={getImage(o)!}
                alt=""
                className={`w-6 h-6 shrink-0 object-contain ${round ? 'rounded-full object-cover' : ''}`}
              />
              <span className="flex-1 text-ink text-sm truncate">{getName(o)}</span>
            </button>
          ))
        )}
      </div>
    </div>
  )
}

export function EmojiPickerButton({ onSelect, trigger, triggerClassName, title, itemsByName, pokemonByName, playersByName }: Props) {
  const [open, setOpen] = useState(false)
  const [tab, setTab] = useState<Tab>('emoji')

  const hasExtraTabs = !!(itemsByName || pokemonByName || playersByName)
  const items = useMemo(() => (itemsByName ? Array.from(itemsByName.values()) : []), [itemsByName])
  const pokemonList = useMemo(() => (pokemonByName ? Array.from(pokemonByName.values()) : []), [pokemonByName])
  const players = useMemo(() => (playersByName ? Array.from(playersByName.values()) : []), [playersByName])

  useEffect(() => {
    if (!open) return
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false) }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [open])

  const handleEmojiPick = (data: EmojiClickData) => {
    onSelect(data.emoji)
    setOpen(false)
  }

  const handleOpen = () => {
    setTab('emoji')
    setOpen(true)
  }

  return (
    <>
      <button type="button" title={title} onClick={handleOpen} className={triggerClassName}>
        {trigger}
      </button>
      {open && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
          onClick={(e) => { if (e.target === e.currentTarget) setOpen(false) }}
        >
          <div className="flex flex-col items-center gap-2">
            {hasExtraTabs && (
              <div className={`flex items-center gap-1 bg-cream rounded-lg p-1 ${PIXEL_BORDER_SM}`}>
                <TabButton active={tab === 'emoji'} onClick={() => setTab('emoji')}>😀 Emoji</TabButton>
                {itemsByName && <TabButton active={tab === 'item'} onClick={() => setTab('item')}>🎒 Objets</TabButton>}
                {pokemonByName && <TabButton active={tab === 'pokemon'} onClick={() => setTab('pokemon')}>Pokémon</TabButton>}
                {playersByName && <TabButton active={tab === 'player'} onClick={() => setTab('player')}>Joueurs</TabButton>}
              </div>
            )}

            {tab === 'emoji' && <EmojiPicker onEmojiClick={handleEmojiPick} theme={Theme.AUTO} />}

            {tab === 'item' && (
              <IconSearchTab
                options={items}
                getName={(i) => i.nom}
                getImage={(i) => i.image_url}
                getKey={(i) => i.id}
                onPick={(i) => { onSelect(encodeIcon('item', i.image_url!)); setOpen(false) }}
              />
            )}

            {tab === 'pokemon' && (
              <IconSearchTab
                options={pokemonList}
                getName={(p) => p.nom}
                getImage={(p) => p.image_miniature}
                getKey={(p) => p.id}
                onPick={(p) => { onSelect(encodeIcon('pokemon', p.image_miniature)); setOpen(false) }}
              />
            )}

            {tab === 'player' && (
              <IconSearchTab
                options={players}
                getName={(p) => p.name}
                getImage={(p) => p.image_url}
                getKey={(p) => p.id}
                onPick={(p) => { onSelect(encodeIcon('player', p.image_url)); setOpen(false) }}
                round
              />
            )}
          </div>
        </div>
      )}
    </>
  )
}
