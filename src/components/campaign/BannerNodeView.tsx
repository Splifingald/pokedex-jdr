import { NodeViewWrapper, type NodeViewProps } from '@tiptap/react'
import { EditableHeaderImage } from './EditableHeaderImage'
import { SetBannerBackgroundButton } from './SetBannerBackgroundButton'
import { TrashIcon } from '../icons/TrashIcon'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'
import type { BannerOptions } from '../../lib/bannerExtension'

// Bannière insérable au fil du texte du chapitre — même traitement visuel que la bannière
// d'en-tête (image_url/image_position du chapitre), mais encapsulée comme un noeud de bloc
// atomique dans le document Tiptap plutôt qu'un champ séparé.
export function BannerNodeView({ node, updateAttributes, deleteNode, editor, extension }: NodeViewProps) {
  const src = (node.attrs.src as string) ?? ''
  const position = (node.attrs.position as number) ?? 50

  if (!editor.isEditable) {
    if (!src) return null
    const updateDisplayState = (extension.options as BannerOptions).getUpdateDisplayState()
    return (
      <NodeViewWrapper>
        <div className="relative w-full h-32 rounded-lg my-4 border-2 border-ink overflow-hidden">
          <img
            src={src}
            alt="Bannière"
            className="w-full h-full object-cover"
            style={{ objectPosition: `50% ${position}%` }}
          />
          <SetBannerBackgroundButton imageUrl={src} updateDisplayState={updateDisplayState} />
        </div>
      </NodeViewWrapper>
    )
  }

  return (
    <NodeViewWrapper>
      <div className="my-3" contentEditable={false}>
        {src && (
          <div className="relative w-full h-36 rounded-lg mb-2 border-2 border-ink overflow-hidden">
            <EditableHeaderImage
              src={src}
              alt="Bannière"
              position={position}
              onPositionChange={(p) => updateAttributes({ position: p })}
              className="w-full h-full"
            />
          </div>
        )}
        <div className="flex items-center gap-2">
          <input
            type="text"
            value={src}
            onChange={(e) => updateAttributes({ src: e.target.value })}
            placeholder="Lien de l'image de la bannière"
            className={`flex-1 px-3 py-2 rounded-lg ${PIXEL_BORDER_SM} bg-cream text-ink text-sm outline-none`}
          />
          <button
            type="button"
            title="Supprimer la bannière"
            onClick={() => deleteNode()}
            className={`w-9 h-9 shrink-0 rounded-lg flex items-center justify-center text-red-700 ${PIXEL_BORDER_SM} bg-cream`}
          >
            <TrashIcon className="w-4 h-4" />
          </button>
        </div>
      </div>
    </NodeViewWrapper>
  )
}
