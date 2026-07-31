import { Node, mergeAttributes, type JSONContent } from '@tiptap/core'
import { ReactNodeViewRenderer } from '@tiptap/react'
import { BannerNodeView } from '../components/campaign/BannerNodeView'
import type { UpdateDisplayState } from './displayActions'

// Le "banner" du chapitre est simplement le premier noeud banner trouvé au fil du contenu —
// pas de champ séparé. On ne regarde que les noeuds de premier niveau du doc, là où
// InsertBannerButton les insère.
export function getChapterBanner(content: JSONContent | null | undefined): { src: string; position: number } | null {
  const node = content?.content?.find((n) => n.type === 'banner')
  if (!node?.attrs?.src) return null
  return { src: node.attrs.src as string, position: (node.attrs.position as number) ?? 50 }
}

export interface BannerOptions {
  getUpdateDisplayState: () => UpdateDisplayState
}

export const Banner = Node.create<BannerOptions>({
  name: 'banner',
  group: 'block',
  atom: true,
  draggable: true,

  addOptions() {
    return {
      getUpdateDisplayState: () => () => {},
    }
  },

  addAttributes() {
    return {
      src: { default: '' },
      position: { default: 50 },
    }
  },

  parseHTML() {
    return [{ tag: 'div[data-type="banner"]' }]
  },

  renderHTML({ HTMLAttributes }) {
    return ['div', mergeAttributes(HTMLAttributes, { 'data-type': 'banner' })]
  },

  addNodeView() {
    return ReactNodeViewRenderer(BannerNodeView)
  },
})
