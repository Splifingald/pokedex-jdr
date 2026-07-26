import { useEffect, useRef, useState } from 'react'
import type { StatusId } from '../lib/status'
import { STATUS_LIST, getStatusInfo } from '../lib/status'
import { PixelIcon } from './icons/PixelIcon'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'

interface Props {
  value: StatusId
  onChange: (id: StatusId) => void
}

// Sélecteur de statut custom (le <select> natif ne peut pas afficher d'icônes
// ni de couleurs dans ses <option>) : bouton + liste déroulante colorée par statut.
export function StatusSelect({ value, onChange }: Props) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  const current = getStatusInfo(value)

  useEffect(() => {
    if (!open) return
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [open])

  return (
    <div className="relative min-w-0 shrink-0" ref={ref}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="min-w-0 max-w-[150px] flex items-center gap-1 rounded px-1.5 py-0.5 text-sm font-bold border-2 outline-none truncate"
        style={{
          borderColor: current.color,
          backgroundColor: value === 'aucun' ? '#fff' : `${current.color}22`,
          color: value === 'aucun' ? '#201c14' : current.color,
        }}
      >
        {current.iconSrc && <PixelIcon src={current.iconSrc} size={14} />}
        <span className="truncate">{current.label}</span>
        <span className={`shrink-0 text-[10px] transition-transform ${open ? 'rotate-180' : ''}`}>▼</span>
      </button>

      {open && (
        <div className={`absolute z-30 top-full left-0 mt-1 w-[150px] rounded-lg ${PIXEL_BORDER_SM} bg-cream shadow-[var(--shadow-pixel)] max-h-56 overflow-y-auto`}>
          {STATUS_LIST.map((s) => (
            <button
              key={s.id}
              type="button"
              onClick={() => {
                onChange(s.id)
                setOpen(false)
              }}
              className="w-full flex items-center gap-1.5 px-2 py-1 border-b border-[#cfc7a8] last:border-b-0 hover:bg-cream-secondary transition-colors text-left"
            >
              <span className="w-3.5 h-3.5 shrink-0 flex items-center justify-center">
                {s.iconSrc && <PixelIcon src={s.iconSrc} size={14} />}
              </span>
              <span className="text-xs font-bold truncate" style={{ color: s.id === 'aucun' ? '#201c14' : s.color }}>
                {s.label}
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
