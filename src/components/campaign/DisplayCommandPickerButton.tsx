import { useMemo, useState, type ReactNode } from 'react'
import type { Editor } from '@tiptap/core'
import type { DisplayAsset } from '../../types'
import type { ReferenceIndex } from '../../hooks/useReferenceIndex'
import { normalizeSearch } from '../../lib/normalizeSearch'
import {
  buildAddCommandText,
  buildClearLayerCommandText,
  CLEAR_ALL_COMMAND_TEXT,
  CLEAR_ALL_LABEL,
  ADD_TYPE_LABEL,
  CLEAR_LAYER_LABEL,
  type DisplayCommandRefType,
} from '../../lib/displayCommand'
import type { DisplayLayer } from '../../lib/displayActions'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'

interface Props {
  editor: Editor | null
  referenceIndex: ReferenceIndex
  displayAssets: DisplayAsset[]
}

interface PickerItem {
  key: string
  name: string
  icon?: string | null
}

const TABS: DisplayCommandRefType[] = ['pokemon', 'player', 'background', 'item']
const CLEAR_LAYERS: DisplayLayer[] = ['npc', 'pokemon', 'item', 'background']

const TAB_FALLBACK_GLYPH: Record<DisplayCommandRefType, string> = {
  pokemon: '❓',
  player: '🧑',
  background: '🖼️',
  item: '🎒',
}

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

// Variante de la liste "recherche + miniatures" de EmojiPickerButton qui NE filtre PAS
// les entrées sans image — affiche un glyphe de repli à la place.
function EntrySearchTab({ items, fallbackGlyph, onPick }: { items: PickerItem[]; fallbackGlyph: string; onPick: (item: PickerItem) => void }) {
  const [query, setQuery] = useState('')

  const filtered = useMemo(() => {
    const q = normalizeSearch(query.trim())
    const list = q ? items.filter((i) => normalizeSearch(i.name).includes(q)) : items
    return list.slice(0, 50)
  }, [query, items])

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
          filtered.map((item) => (
            <button
              key={item.key}
              type="button"
              onClick={() => onPick(item)}
              className="w-full flex items-center gap-2 px-3 py-2 border-b border-[#cfc7a8] last:border-b-0 hover:bg-cream-secondary transition-colors text-left"
            >
              {item.icon ? (
                <img src={item.icon} alt="" className="w-6 h-6 shrink-0 object-contain" />
              ) : (
                <span className="w-6 h-6 shrink-0 flex items-center justify-center text-base">{fallbackGlyph}</span>
              )}
              <span className="flex-1 text-ink text-sm truncate">{item.name}</span>
            </button>
          ))
        )}
      </div>
    </div>
  )
}

// Bouton toolbar : insère "Reference : Type-Nom" (choisi parmi Pokémon/PNJ/Fond/Objet, triés
// par onglet) ou une des commandes fixes "Reference : Effacer …" / "Reference : Tout Effacer".
// Le Fond liste les display_assets de type Background (pas les lieux de la carte : c'est
// l'image réellement projetable qui compte) ; le PNJ combine les Joueurs/PNJ référencés et les
// figures display_assets de type NPC qui n'ont pas de Joueur correspondant.
export function DisplayCommandPickerButton({ editor, referenceIndex, displayAssets }: Props) {
  const [open, setOpen] = useState(false)
  const [tab, setTab] = useState<DisplayCommandRefType>('pokemon')

  const itemsByTab = useMemo(() => {
    const pokemon: PickerItem[] = referenceIndex.entries
      .filter((e) => e.type === 'pokemon')
      .map((e) => ({ key: `pokemon-${e.id}`, name: e.name, icon: e.icon }))

    const item: PickerItem[] = referenceIndex.entries
      .filter((e) => e.type === 'item')
      .map((e) => ({ key: `item-${e.id}`, name: e.name, icon: e.icon }))

    const background: PickerItem[] = displayAssets
      .filter((a) => a.type === 'Background')
      .map((a) => ({ key: `bg-${a.id}`, name: a.nom, icon: a.image_url }))

    const playerEntries = referenceIndex.entries.filter((e) => e.type === 'player')
    const playerNames = new Set(playerEntries.map((e) => e.name.toLowerCase()))
    const player: PickerItem[] = [
      ...playerEntries.map((e) => ({ key: `player-${e.id}`, name: e.name, icon: e.icon })),
      ...displayAssets
        .filter((a) => a.type === 'NPC' && !playerNames.has(a.nom.toLowerCase()))
        .map((a) => ({ key: `npc-${a.id}`, name: a.nom, icon: a.image_url })),
    ]

    return { pokemon, player, background, item } satisfies Record<DisplayCommandRefType, PickerItem[]>
  }, [referenceIndex, displayAssets])

  if (!editor) return null

  const insertText = (text: string) => {
    editor.chain().focus().insertContent(`${text} `).run()
    setOpen(false)
  }

  return (
    <>
      <button
        type="button"
        title="Insérer une référence ou une commande d'affichage"
        onClick={() => setOpen(true)}
        className={`w-8 h-8 rounded text-sm flex items-center justify-center shrink-0 ${BUTTON_STYLE.gray}`}
      >
        🖥️
      </button>
      {open && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
          onClick={(e) => { if (e.target === e.currentTarget) setOpen(false) }}
        >
          <div className="flex flex-col items-center gap-2">
            <div className={`flex items-center gap-1 bg-cream rounded-lg p-1 ${PIXEL_BORDER_SM}`}>
              {TABS.map((t) => (
                <TabButton key={t} active={tab === t} onClick={() => setTab(t)}>
                  {ADD_TYPE_LABEL[t]}
                </TabButton>
              ))}
            </div>

            <EntrySearchTab
              items={itemsByTab[tab]}
              fallbackGlyph={TAB_FALLBACK_GLYPH[tab]}
              onPick={(item) => insertText(buildAddCommandText(tab, item.name))}
            />

            <div className={`flex flex-wrap gap-1.5 bg-cream rounded-lg p-2 ${PIXEL_BORDER_SM} w-72 max-w-[80vw]`}>
              {CLEAR_LAYERS.map((layer) => (
                <button
                  key={layer}
                  type="button"
                  onClick={() => insertText(buildClearLayerCommandText(layer))}
                  className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}
                >
                  Effacer {CLEAR_LAYER_LABEL[layer]}
                </button>
              ))}
              <button
                type="button"
                onClick={() => insertText(CLEAR_ALL_COMMAND_TEXT)}
                className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.red}`}
              >
                {CLEAR_ALL_LABEL}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
