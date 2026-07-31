import { Extension, type Editor } from '@tiptap/core'
import { Plugin, PluginKey } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'
import type { Node as PMNode } from '@tiptap/pm/model'
import type { DisplayAsset } from '../types'
import type { ReferenceIndex } from '../hooks/useReferenceIndex'
import { scanDisplayCommands, parseDisplayCommandMatch, resolveBackgroundAsset, type DisplayCommand } from './displayCommand'

export interface DisplayCommandOptions {
  getIndex: () => ReferenceIndex
  getDisplayAssets: () => DisplayAsset[]
  onCommand: (cmd: DisplayCommand) => void
  // Si défini, une commande "Reference : Fond-X" résolue se rend comme une bannière image
  // pleine largeur (à cette hauteur) plutôt que comme du texte — utilisé uniquement par les
  // éditeurs de chapitre, pas par les notes/la vue de session qui gardent le rendu texte.
  bannerHeightClass?: string
}

const displayCommandPluginKey = new PluginKey<DecorationSet>('display-command-highlight')

function buildBannerWidget(url: string, commandText: string, heightClass: string): HTMLElement {
  const wrapper = document.createElement('div')
  wrapper.className = `relative w-full ${heightClass} rounded-lg my-3 border-2 border-ink overflow-hidden cursor-pointer`
  wrapper.setAttribute('data-display-cmd', commandText)
  wrapper.contentEditable = 'false'

  const img = document.createElement('img')
  img.src = url
  img.alt = ''
  img.className = 'w-full h-full object-cover pointer-events-none'
  wrapper.appendChild(img)

  const badge = document.createElement('span')
  badge.className = 'pointer-events-none absolute bottom-1.5 right-1.5 w-7 h-7 rounded-md flex items-center justify-center text-sm bg-black/50 text-white'
  badge.textContent = '📺'
  wrapper.appendChild(badge)

  return wrapper
}

function buildDecorations(doc: PMNode, index: ReferenceIndex, displayAssets: DisplayAsset[], bannerHeightClass?: string): DecorationSet {
  const decorations: Decoration[] = []
  doc.descendants((node, pos) => {
    if (!node.isText || !node.text) return
    for (const match of scanDisplayCommands(node.text, index, displayAssets)) {
      const from = pos + match.from
      const to = pos + match.to

      if (bannerHeightClass) {
        const cmd = parseDisplayCommandMatch(match.text)
        const asset = cmd?.kind === 'add' && cmd.refType === 'background' ? resolveBackgroundAsset(cmd.name, displayAssets) : null
        if (asset) {
          decorations.push(Decoration.inline(from, to, { style: 'display:none' }))
          decorations.push(
            Decoration.widget(from, () => buildBannerWidget(asset.image_url, match.text, bannerHeightClass), { side: 0 })
          )
          continue
        }
      }

      decorations.push(
        Decoration.inline(from, to, {
          class: 'display-cmd',
          'data-display-cmd': match.text,
        })
      )
    }
  })
  return DecorationSet.create(doc, decorations)
}

// Commandes texte "Reference : Pokémon-Pikachu" / "Reference : Effacer PNJ" / "Reference : Tout
// Effacer" — extension parallèle à ReferenceHighlight, mais qui déclenche une action sur le mode
// Affichage au clic plutôt que d'ouvrir un popup d'info.
export const DisplayCommandHighlight = Extension.create<DisplayCommandOptions>({
  name: 'displayCommandHighlight',

  addOptions() {
    return {
      getIndex: () => ({ entries: [], matcher: /(?!)/g, lookup: new Map() }),
      getDisplayAssets: () => [],
      onCommand: () => {},
    }
  },

  addProseMirrorPlugins() {
    const { getIndex, getDisplayAssets, onCommand, bannerHeightClass } = this.options

    return [
      new Plugin({
        key: displayCommandPluginKey,
        state: {
          init: (_, { doc }) => buildDecorations(doc, getIndex(), getDisplayAssets(), bannerHeightClass),
          apply(tr, old) {
            if (!tr.docChanged && !tr.getMeta(displayCommandPluginKey)) return old
            return buildDecorations(tr.doc, getIndex(), getDisplayAssets(), bannerHeightClass)
          },
        },
        props: {
          decorations(state) {
            return displayCommandPluginKey.getState(state)
          },
          handleClickOn(_view, _pos, _node, _nodePos, event) {
            const target = event.target as HTMLElement | null
            const span = target?.closest('[data-display-cmd]') as HTMLElement | null
            if (!span) return false
            const raw = span.getAttribute('data-display-cmd')
            if (!raw) return false
            const cmd = parseDisplayCommandMatch(raw)
            if (!cmd) return false
            event.preventDefault()
            onCommand(cmd)
            return true
          },
        },
      }),
    ]
  },
})

export function forceDisplayCommandRecompute(editor: Editor) {
  editor.view.dispatch(editor.state.tr.setMeta(displayCommandPluginKey, true))
}
