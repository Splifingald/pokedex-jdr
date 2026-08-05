import { BUTTON_STYLE } from '../lib/buttonStyles'
import { CloseIcon } from './icons/CloseIcon'

interface Props {
  onClose: () => void
}

export function PensionInfoPopup({ onClose }: Props) {
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
          <li>Chaque dresseur ne peut avoir qu'un pokémon en pension.</li>
          <li>Il y a des limites d'expérience cumulable en pension.</li>
          <li>Les pokémon de dresseurs différents peuvent produire des œufs s'ils sont compatibles — dans ce cas, l'œuf est donné à l'un des deux dresseurs, au hasard.</li>
          <li>Les œufs reçus peuvent contenir tout type de pokémon, la dame de la pension s'amuse à les mélanger pour faire des surprises aux dresseurs !</li>
        </ul>

        <button onClick={onClose} className={`w-full py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.yellow}`}>
          Compris
        </button>
      </div>
    </div>
  )
}
