import { BUTTON_STYLE } from '../lib/buttonStyles'
import { CloseIcon } from './icons/CloseIcon'

interface Props {
  onClose: () => void
}

// Règles du Safari, ouvertes depuis le ℹ️ à côté du titre du SafariPopup.
const INFO_STEPS = [
  'Utilise des baies Framby pour monter la jauge de capture des Pokémon',
  'Tente la capture avec une Safari Ball',
  'Attention à ne pas aller trop loin sur la jauge, ou tu pourrais réduire grandement tes chances',
]

export function SafariInfoPopup({ onClose }: Props) {
  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4" onClick={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className="relative bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-sm w-full p-6">
        <button
          onClick={onClose}
          className="absolute right-3 top-3 w-8 h-8 rounded-full flex items-center justify-center text-ink hover:bg-black/10"
        >
          <CloseIcon className="w-4 h-4" />
        </button>

        <h3 className="text-ink text-lg font-bold mb-4">Comment fonctionne le Safari ?</h3>

        <ol className="flex flex-col gap-3 text-ink text-sm mb-4 list-decimal pl-5">
          {INFO_STEPS.map((line, i) => <li key={i}>{line}</li>)}
        </ol>

        <p className="text-ink text-sm font-bold mb-5">
          Une seule ball peut être lancée par pokémon
        </p>

        <button onClick={onClose} className={`w-full py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.yellow}`}>
          Compris
        </button>
      </div>
    </div>
  )
}
