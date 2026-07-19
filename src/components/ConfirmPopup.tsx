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
        <div className="flex gap-3">
          <button
            onClick={onCancel}
            className="flex-1 py-2.5 border-2 border-gray-600 text-gray-300 rounded hover:bg-gray-800 transition-colors text-sm"
          >
            {cancelLabel}
          </button>
          <button
            onClick={onConfirm}
            className={`flex-1 py-2.5 border-2 text-white rounded transition-colors text-sm font-bold ${
              danger
                ? 'bg-red-600 border-red-400 hover:bg-red-500'
                : 'bg-gray-700 border-gray-500 hover:bg-gray-600'
            }`}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}
