import { useEffect, type ReactNode } from 'react'
import { PANEL_LG } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { CloseIcon } from '../icons/CloseIcon'

interface Props {
  icon?: string
  title?: string
  onClose: () => void
  children: ReactNode
  /** Passe au-dessus d'un SheetShell déjà élevé (ex : capacité ouverte depuis un Pokémon déjà en popup) */
  elevated?: boolean
}

export function ReferencePopupShell({ icon, title, onClose, children, elevated = false }: Props) {
  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onClose])

  return (
    <div
      className={`fixed inset-0 ${elevated ? 'z-[80]' : 'z-50'} flex items-center justify-center bg-black/80 p-4`}
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className={`${PANEL_LG} max-w-sm w-full max-h-[80vh] flex flex-col overflow-hidden relative`}>
        {(icon || title) && (
          <div className="flex items-center gap-2 p-4 border-b-2 border-[#cfc7a8] shrink-0">
            {icon && <span className="text-xl">{icon}</span>}
            {title && <h3 className="text-ink font-bold flex-1 truncate">{title}</h3>}
            <button
              onClick={onClose}
              className={`w-7 h-7 shrink-0 rounded-md text-sm font-bold ${BUTTON_STYLE.gray}`}
            >
              <CloseIcon className="w-4 h-4 mx-auto" />
            </button>
          </div>
        )}
        {!icon && !title && (
          <button
            onClick={onClose}
            className={`absolute top-3 right-3 z-10 w-7 h-7 shrink-0 rounded-md text-sm font-bold ${BUTTON_STYLE.gray}`}
          >
            <CloseIcon className="w-4 h-4 mx-auto" />
          </button>
        )}

        <div className="flex-1 overflow-y-auto p-4">
          {children}
        </div>
      </div>
    </div>
  )
}
