import type { Item } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  itemNom: string
  itemsByName: Map<string, Item>
  onConfirm: () => void
}

// Confirm-only, comme GiftPopup/EvolutionPopup : pas de onClick sur l'overlay,
// aucun autre moyen de fermer que le bouton. Pas d'étape "cliquer pour révéler"
// (contrairement à GiftPopup) — l'objet est déjà connu de façon synchrone via
// le résultat de digCell(), il n'y a pas de tirage aléatoire à suspendre.
export function MiningItemFoundPopup({ itemNom, itemsByName, onConfirm }: Props) {
  const item = itemsByName.get(itemNom)

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="relative bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-xs w-full p-6">
        <div className="flex flex-col items-center text-center">
          <p className="text-ink text-base mb-3">Objet déterré !</p>
          <div className="w-20 h-20 flex items-center justify-center mb-3 animate-[celebrate-pop_0.4s_ease-out]">
            {item?.image_url ? (
              <img src={item.image_url} alt={itemNom} className="w-full h-full object-contain" />
            ) : (
              <span className="text-5xl">⛏️</span>
            )}
          </div>
          <h3 className="text-ink text-lg mb-1">{itemNom}</h3>
          {item?.description && <p className="text-ink-muted text-sm mb-1">{item.description}</p>}
          <button
            onClick={onConfirm}
            className={`mt-4 px-5 py-2 rounded font-bold text-sm ${BUTTON_STYLE.yellow}`}
          >
            Continuer
          </button>
        </div>
      </div>
    </div>
  )
}
