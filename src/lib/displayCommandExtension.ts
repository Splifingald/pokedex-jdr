import { Extension, type Editor } from '@tiptap/core'
import { Plugin, PluginKey } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'
import type { Node as PMNode } from '@tiptap/pm/model'
import type { DisplayAsset } from '../types'
import type { ReferenceIndex } from '../hooks/useReferenceIndex'
import { scanDisplayCommands, parseDisplayCommandMatch, type DisplayCommand } from './displayCommand'

export interface DisplayCommandOptions {
  getIndex: () => ReferenceIndex
  getDisplayAssets: () => DisplayAsset[]
  onCommand: (cmd: DisplayCommand) => void
}

const displayCommandPluginKey = new PluginKey<DecorationSet>('display-command-highlight')

function buildDecorations(doc: PMNode, index: ReferenceIndex, displayAssets: DisplayAsset[]): DecorationSet {
  const decorations: Decoration[] = []
  doc.descendants((node, pos) => {
    if (!node.isText || !node.text) return
    for (const match of scanDisplayCommands(node.text, index, displayAssets)) {
      decorations.push(
        Decoration.inline(pos + match.from, pos + match.to, {
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
    const { getIndex, getDisplayAssets, onCommand } = this.options

    return [
      new Plugin({
        key: displayCommandPluginKey,
        state: {
          init: (_, { doc }) => buildDecorations(doc, getIndex(), getDisplayAssets()),
          apply(tr, old) {
            if (!tr.docChanged && !tr.getMeta(displayCommandPluginKey)) return old
            return buildDecorations(tr.doc, getIndex(), getDisplayAssets())
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
