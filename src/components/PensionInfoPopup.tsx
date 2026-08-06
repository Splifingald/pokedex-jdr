import { BUTTON_STYLE } from '../lib/buttonStyles'
import { CloseIcon } from './icons/CloseIcon'

interface Props {
  infoText: string
  onClose: () => void
}

export function PensionInfoPopup({ infoText, onClose }: Props) {
  const lines = infoText.split('\n').map((l) => l.trim()).filter(Boolean)

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4" onClick={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className="relative bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-sm w-full p-6">
        <button
          onClick={onClose}
          className="absolute right-3 top-3 w-8 h-8 rounded-full flex items-center justify-center text-ink hover:bg-black/10"
        >
          <CloseIcon className="w-4 h-4" />
        </button>

        <h3 className="text-ink text-lg font-bold mb-4">Comment fonctionne la Pension ?</h3>

        <ul className="flex flex-col gap-3 text-ink text-sm mb-5 list-disc pl-5">
          {lines.map((line, i) => <li key={i}>{line}</li>)}
        </ul>

        <button onClick={onClose} className={`w-full py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.yellow}`}>
          Compris
        </button>
      </div>
    </div>
  )
}
