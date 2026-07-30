import type { ReactNode } from 'react'
import type { Editor } from '@tiptap/core'
import type { DisplayAsset } from '../../types'
import type { ReferenceIndex } from '../../hooks/useReferenceIndex'
import { EmojiPickerButton } from './EmojiPickerButton'
import { DisplayCommandPickerButton } from './DisplayCommandPickerButton'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  editor: Editor | null
  referenceIndex: ReferenceIndex
  displayAssets: DisplayAsset[]
}

const TEXT_COLORS = ['#201c14', '#dc0a2d', '#e8933d', '#a3841a', '#4caf6b', '#4a7fd6', '#a040a0']

function ToolbarButton({ active, onClick, children, title }: { active?: boolean; onClick: () => void; children: ReactNode; title?: string }) {
  return (
    <button
      type="button"
      title={title}
      onClick={onClick}
      className={`w-8 h-8 rounded text-sm font-bold flex items-center justify-center shrink-0 ${active ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
    >
      {children}
    </button>
  )
}

export function EditorToolbar({ editor, referenceIndex, displayAssets }: Props) {
  if (!editor) return null

  return (
    <div className="flex flex-wrap items-center gap-1.5 p-2 border-b-2 border-[#cfc7a8] bg-cream-secondary">
      <ToolbarButton title="Gras" active={editor.isActive('bold')} onClick={() => editor.chain().focus().toggleBold().run()}>
        <b>G</b>
      </ToolbarButton>
      <ToolbarButton title="Italique" active={editor.isActive('italic')} onClick={() => editor.chain().focus().toggleItalic().run()}>
        <i>I</i>
      </ToolbarButton>
      <ToolbarButton title="Souligné" active={editor.isActive('underline')} onClick={() => editor.chain().focus().toggleUnderline().run()}>
        <span className="underline">S</span>
      </ToolbarButton>
      <ToolbarButton title="Barré" active={editor.isActive('strike')} onClick={() => editor.chain().focus().toggleStrike().run()}>
        <span className="line-through">B</span>
      </ToolbarButton>

      <span className="w-px h-5 bg-ink/20 mx-1 shrink-0" />

      <ToolbarButton title="Titre 1" active={editor.isActive('heading', { level: 1 })} onClick={() => editor.chain().focus().toggleHeading({ level: 1 }).run()}>
        H1
      </ToolbarButton>
      <ToolbarButton title="Titre 2" active={editor.isActive('heading', { level: 2 })} onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}>
        H2
      </ToolbarButton>
      <ToolbarButton title="Titre 3" active={editor.isActive('heading', { level: 3 })} onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()}>
        H3
      </ToolbarButton>
      <ToolbarButton title="Paragraphe" active={editor.isActive('paragraph')} onClick={() => editor.chain().focus().setParagraph().run()}>
        ¶
      </ToolbarButton>

      <span className="w-px h-5 bg-ink/20 mx-1 shrink-0" />

      <ToolbarButton title="Citation" active={editor.isActive('blockquote')} onClick={() => editor.chain().focus().toggleBlockquote().run()}>
        ❝
      </ToolbarButton>
      <ToolbarButton title="Liste à puces" active={editor.isActive('bulletList')} onClick={() => editor.chain().focus().toggleBulletList().run()}>
        •≡
      </ToolbarButton>
      <ToolbarButton title="Liste numérotée" active={editor.isActive('orderedList')} onClick={() => editor.chain().focus().toggleOrderedList().run()}>
        1≡
      </ToolbarButton>

      <span className="w-px h-5 bg-ink/20 mx-1 shrink-0" />

      <div className="flex items-center gap-1 shrink-0">
        <button
          type="button"
          title="Couleur par défaut"
          onClick={() => editor.chain().focus().unsetColor().run()}
          className="w-5 h-5 rounded-full border-2 border-ink bg-white flex items-center justify-center text-[8px] text-ink-muted-2"
        >
          ✕
        </button>
        {TEXT_COLORS.map((c) => (
          <button
            key={c}
            type="button"
            title={c}
            onClick={() => editor.chain().focus().setColor(c).run()}
            className="w-5 h-5 rounded-full border-2 border-ink"
            style={{ backgroundColor: c }}
          />
        ))}
      </div>

      <span className="w-px h-5 bg-ink/20 mx-1 shrink-0" />

      <EmojiPickerButton
        title="Insérer un emoji"
        trigger="😀"
        triggerClassName={`w-8 h-8 rounded text-sm flex items-center justify-center shrink-0 ${BUTTON_STYLE.gray}`}
        onSelect={(emoji) => editor.chain().focus().insertContent(emoji).run()}
      />

      <DisplayCommandPickerButton editor={editor} referenceIndex={referenceIndex} displayAssets={displayAssets} />
    </div>
  )
}
