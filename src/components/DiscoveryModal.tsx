import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  numero: string
  onConfirm: () => void
  onCancel: () => void
}

export function DiscoveryModal({ numero, onConfirm, onCancel }: Props) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-sm w-full p-6">
        <div className="text-center mb-6">
          <div className="text-5xl mb-3">❓</div>
          <p className="text-ink-muted-2 text-sm mb-1">Pokémon #{numero}</p>
          <h3 className="text-ink text-lg">
            As-tu découvert ce Pokémon ?
          </h3>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <button
            onClick={onCancel}
            className={`py-3 rounded ${BUTTON_STYLE.gray}`}
          >
            Non
          </button>
          <button
            onClick={onConfirm}
            className={`py-3 rounded font-bold ${BUTTON_STYLE.gray}`}
          >
            Oui !
          </button>
        </div>
      </div>
    </div>
  )
}
