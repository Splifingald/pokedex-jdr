import type { ReactNode } from 'react'

interface Props {
  onClose: () => void
  children: ReactNode
  /** Passe au-dessus des popups z-50 (ex : ouvert depuis une table de rencontres déjà en popup) */
  elevated?: boolean
}

// Enveloppe responsive des fiches détail :
// - mobile (< md) : bottom sheet glissant depuis le bas, poignée de drag
// - tablette (md–lg) : modale centrée
// - desktop (≥ lg) : panneau latéral ancré à droite, pleine hauteur
export function SheetShell({ onClose, children, elevated = false }: Props) {
  return (
    <div
      className={`fixed inset-0 ${elevated ? 'z-[70]' : 'z-40'} bg-black/55 flex items-end md:items-center md:justify-center lg:items-stretch lg:justify-end`}
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div
        className="bg-cream text-ink w-full max-h-[85%] overflow-y-auto rounded-t-2xl border-t-4 border-ink shadow-[0_-6px_0_rgba(0,0,0,0.3)] animate-[sheet-pop_0.25s_ease-out]
          md:max-w-lg md:max-h-[85%] md:rounded-xl md:border-[3px] md:shadow-[var(--shadow-pixel-lg)]
          lg:max-w-none lg:w-[546px] lg:h-full lg:max-h-full lg:rounded-none lg:rounded-l-xl lg:border-y-0 lg:border-r-0 lg:border-l-4"
      >
        {/* Poignée de drag (mobile uniquement) */}
        <div className="flex justify-center pt-2.5 md:hidden">
          <div className="w-10 h-1.5 rounded-full bg-[#cfc7a8]" />
        </div>
        {children}
      </div>
    </div>
  )
}
