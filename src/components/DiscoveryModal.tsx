import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  numero: string
  onConfirm: () => void
  onCancel: () => void
}

export function DiscoveryModal({ numero, onConfirm, onCancel }: Props) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="bg-gray-900 border-2 border-gray-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-sm w-full p-6">
        <div className="text-center mb-6">
          <div className="text-5xl mb-3">❓</div>
          <p className="text-gray-400 text-sm mb-1">Pokémon #{numero}</p>
          <h3 className="text-white text-lg">
            Avez-vous découvert ce Pokémon ?
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
