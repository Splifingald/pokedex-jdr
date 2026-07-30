import { Extension, type Editor } from '@tiptap/core'
import { Plugin, PluginKey } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'
import type { Node as PMNode } from '@tiptap/pm/model'
import type { DisplayAsset } from '../types'
import type { ReferenceEntry, ReferenceIndex } from '../hooks/useReferenceIndex'
import { findCommandRanges } from './displayCommand'

export interface ReferenceHighlightOptions {
  getIndex: () => ReferenceIndex
  getDisplayAssets: () => DisplayAsset[]
  onReferenceClick: (entry: ReferenceEntry) => void
}

const referencePluginKey = new PluginKey<DecorationSet>('reference-highlight')

function createReferenceWidget(entry: ReferenceEntry): HTMLElement | null {
  if ((entry.type === 'pokemon' || entry.type === 'item' || entry.type === 'player') && entry.icon) {
    const img = document.createElement('img')
    img.src = entry.icon
    img.alt = ''
    img.className =
      entry.type === 'pokemon' ? 'ref-icon ref-icon-pokemon' :
      entry.type === 'player' ? 'ref-icon ref-icon-player' :
      'ref-icon'
    return img
  }
  if (entry.type === 'location') {
    const span = document.createElement('span')
    span.className = 'ref-icon'
    span.textContent = '📍'
    return span
  }
  if (entry.type === 'ability') {
    const span = document.createElement('span')
    span.className = 'ref-icon'
    span.textContent = '💥'
    return span
  }
  return null
}

function buildDecorations(doc: PMNode, index: ReferenceIndex, displayAssets: DisplayAsset[]): DecorationSet {
  const decorations: Decoration[] = []
  const { matcher, lookup } = index
  doc.descendants((node, pos) => {
    if (!node.isText || !node.text) return
    // Les commandes texte ("Reference : Pokémon-Pikachu") contiennent elles-mêmes un nom
    // de référence valide — on évite de le surligner/rendre cliquable en double.
    const commandRanges = findCommandRanges(node.text, index, displayAssets)
    const insideCommand = (from: number, to: number) =>
      commandRanges.some((r) => from < r.to && to > r.from)
    matcher.lastIndex = 0
    let m: RegExpExecArray | null
    while ((m = matcher.exec(node.text))) {
      const entry = lookup.get(m[0].toLowerCase())
      if (entry && insideCommand(m.index, m.index + m[0].length)) {
        if (m.index === matcher.lastIndex) matcher.lastIndex++
        continue
      }
      if (entry) {
        const from = pos + m.index
        const to = from + m[0].length
        if (entry.icon || entry.type === 'location' || entry.type === 'ability') {
          decorations.push(Decoration.widget(from, () => createReferenceWidget(entry)!, { side: -1 }))
        }
        decorations.push(
          Decoration.inline(from, to, {
            class: 'ref-highlight',
            'data-ref-type': entry.type,
            'data-ref-id': String(entry.id),
            style: entry.color ? `color: ${entry.color}` : '',
          })
        )
      }
      if (m.index === matcher.lastIndex) matcher.lastIndex++
    }
  })
  return DecorationSet.create(doc, decorations)
}

export const ReferenceHighlight = Extension.create<ReferenceHighlightOptions>({
  name: 'referenceHighlight',

  addOptions() {
    return {
      getIndex: () => ({ entries: [], matcher: /(?!)/g, lookup: new Map() }),
      getDisplayAssets: () => [],
      onReferenceClick: () => {},
    }
  },

  addProseMirrorPlugins() {
    const { getIndex, getDisplayAssets, onReferenceClick } = this.options

    return [
      new Plugin({
        key: referencePluginKey,
        state: {
          init: (_, { doc }) => buildDecorations(doc, getIndex(), getDisplayAssets()),
          apply(tr, old) {
            if (!tr.docChanged && !tr.getMeta(referencePluginKey)) return old
            return buildDecorations(tr.doc, getIndex(), getDisplayAssets())
          },
        },
        props: {
          decorations(state) {
            return referencePluginKey.getState(state)
          },
          handleClickOn(_view, _pos, _node, _nodePos, event) {
            const target = event.target as HTMLElement | null
            const span = target?.closest('[data-ref-type]') as HTMLElement | null
            if (!span) return false
            const type = span.getAttribute('data-ref-type')
            const id = span.getAttribute('data-ref-id')
            if (!type || !id) return false
            const entry = getIndex().entries.find((e) => e.type === type && String(e.id) === id)
            if (!entry) return false
            event.preventDefault()
            onReferenceClick(entry)
            return true
          },
        },
      }),
    ]
  },
})

export function forceReferenceRecompute(editor: Editor) {
  editor.view.dispatch(editor.state.tr.setMeta(referencePluginKey, true))
}
