import { setBackgroundUrl, type UpdateDisplayState } from '../../lib/displayActions'
import { useToast } from '../../context/ToastContext'

interface Props {
  imageUrl: string
  updateDisplayState: UpdateDisplayState
}

// Petit bouton flottant en bas à droite d'une bannière (chapitre/session) qui pousse
// directement cette image comme fond d'affichage, sans passer par les display_assets.
export function SetBannerBackgroundButton({ imageUrl, updateDisplayState }: Props) {
  const { showToast } = useToast()

  return (
    <button
      type="button"
      title="Utiliser cette image comme fond d'affichage"
      onClick={(e) => {
        e.stopPropagation()
        setBackgroundUrl(imageUrl, updateDisplayState)
        showToast("Fond d'écran mis à jour")
      }}
      className="absolute bottom-1.5 right-1.5 w-7 h-7 rounded-md flex items-center justify-center text-sm bg-black/50 text-white hover:bg-black/70 transition-colors"
    >
      🖼️
    </button>
  )
}
