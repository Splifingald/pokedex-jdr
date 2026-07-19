import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  title: string
  message?: string
  confirmLabel?: string
  cancelLabel?: string
  danger?: boolean
  onConfirm: () => void
  onCancel: () => void
}

export function ConfirmPopup({
  title,
  message,
  confirmLabel = 'Confirmer',
  cancelLabel = 'Annuler',
  danger = false,
  onConfirm,
  onCancel,
}: Props) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="bg-gray-900 border-2 border-gray-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-xs w-full p-6">
        <div className="text-center mb-5">
          <h3 className="text-white text-lg">{title}</h3>
          {message && <p className="text-gray-400 text-sm mt-2">{message}</p>}
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <button
            onClick={onCancel}
            className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.gray}`}
          >
            {cancelLabel}
          </button>
          <button
            onClick={onConfirm}
            className={`py-2.5 rounded text-sm font-bold ${danger ? BUTTON_STYLE.red : BUTTON_STYLE.gray}`}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}
