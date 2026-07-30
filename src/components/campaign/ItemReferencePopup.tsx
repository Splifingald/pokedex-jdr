import type { ReactNode } from 'react'
import type { Item } from '../../types'
import { ReferencePopupShell } from './ReferencePopupShell'
import { rarityBadgeStyle } from '../../lib/rarityColors'
import { PokedollarIcon } from '../PokedollarIcon'

interface Props {
  item: Item
  pokedollarImageUrl?: string | null
  displayBar?: ReactNode
  onClose: () => void
}

export function ItemReferencePopup({ item, pokedollarImageUrl, displayBar, onClose }: Props) {
  return (
    <ReferencePopupShell icon="🎒" title={item.nom} onClose={onClose}>
      {displayBar}
      <div className="flex flex-col items-center text-center">
        <div className="w-20 h-20 flex items-center justify-center mb-3">
          {item.image_url ? (
            <img src={item.image_url} alt={item.nom} className="w-full h-full object-contain" />
          ) : (
            <span className="text-5xl">🎒</span>
          )}
        </div>
        <div className="flex items-center gap-2 mb-2">
          {item.rarete && (
            <span className={`text-xs rounded-full px-2 py-0.5 border ${rarityBadgeStyle(item.rarete)}`}>
              {item.rarete}
            </span>
          )}
          <span className="text-[#a3841a] text-sm font-bold flex items-center gap-1">
            <PokedollarIcon imageUrl={pokedollarImageUrl} size={16} /> {item.cout}
          </span>
        </div>
        {item.description && (
          <p className="text-ink-muted text-sm">{item.description}</p>
        )}
      </div>
    </ReferencePopupShell>
  )
}
