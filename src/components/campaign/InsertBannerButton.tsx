import type { Editor } from '@tiptap/core'
import type { DisplayAsset } from '../../types'
import { BannerPickerButton } from './BannerPickerButton'

interface Props {
  editor: Editor | null
  displayAssets: DisplayAsset[]
}

// Bouton toolbar : insère une bannière pleine largeur au fil du texte, soit en choisissant un
// Fond existant (display_assets de type Background), soit en collant une image quelconque —
// même logique de saisie que la bannière d'en-tête de session (BannerPickerButton).
export function InsertBannerButton({ editor, displayAssets }: Props) {
  if (!editor) return null

  const insertBanner = (src: string) => {
    // Insère aussi un paragraphe vide juste après : sans lui, le curseur reste en
    // sélection sur le noeud atomique inséré (NodeSelection), et la prochaine insertion
    // (texte tapé, autre bannière, référence…) remplacerait la bannière au lieu de
    // s'ajouter après.
    editor.chain().focus().insertContent([
      { type: 'banner', attrs: { src, position: 50 } },
      { type: 'paragraph' },
    ]).run()
  }

  return (
    <BannerPickerButton
      displayAssets={displayAssets}
      onSelect={insertBanner}
      variant="icon"
      label="Insérer une bannière"
      confirmLabel="Insérer"
    />
  )
}
