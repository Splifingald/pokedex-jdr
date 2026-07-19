import { useState, useRef, useEffect } from 'react'
import { BUTTON_STYLE } from '../lib/buttonStyles'

const ADMIN_PASSWORD = 'Rioluxray171216'

interface Props {
  onSuccess: () => void
  onCancel: () => void
}

export function PasswordModal({ onSuccess, onCancel }: Props) {
  const [value, setValue] = useState('')
  const [error, setError] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (value === ADMIN_PASSWORD) {
      sessionStorage.setItem('adminMode', 'true')
      onSuccess()
    } else {
      setError(true)
      setValue('')
      setTimeout(() => setError(false), 1500)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="bg-gray-900 border-2 border-gray-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-xs w-full p-6">
        <div className="text-center mb-5">
          <div className="text-4xl mb-2">🔒</div>
          <h3 className="text-white text-lg">Mode Admin</h3>
        </div>
        <form onSubmit={handleSubmit} className="flex flex-col gap-3">
          <input
            ref={inputRef}
            type="password"
            value={value}
            onChange={(e) => setValue(e.target.value)}
            placeholder="Mot de passe"
            className={`w-full bg-gray-800 border-2 ${error ? 'border-red-500' : 'border-gray-600'} rounded px-3 py-2 text-white outline-none focus:border-red-400 transition-colors`}
          />
          {error && <p className="text-red-400 text-xs text-center">Mot de passe incorrect</p>}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-1">
            <button
              type="button"
              onClick={onCancel}
              className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.gray}`}
            >
              Annuler
            </button>
            <button
              type="submit"
              className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.yellow}`}
            >
              Entrer
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
