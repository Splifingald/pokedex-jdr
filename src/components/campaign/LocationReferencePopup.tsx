import { useState } from 'react'
import type { CarteLocation } from '../../types'
import { ReferencePopupShell } from './ReferencePopupShell'
import { ImageLightbox } from '../ImageLightbox'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  location: CarteLocation
  onClose: () => void
}

export function LocationReferencePopup({ location, onClose }: Props) {
  const [viewerOpen, setViewerOpen] = useState(false)

  return (
    <ReferencePopupShell icon="📍" title={location.titre} onClose={onClose}>
      {location.type && (
        <span className="inline-block mb-2 text-xs bg-cream-secondary border-2 border-ink rounded px-1.5 py-0.5 text-ink-muted uppercase">
          {location.type}
        </span>
      )}
      {location.image_url && (
        <button
          onClick={() => setViewerOpen(true)}
          className={`block mb-2 px-3 py-1.5 rounded-md text-xs font-bold ${BUTTON_STYLE.blue}`}
        >
          🖼 Voir l'image
        </button>
      )}
      {location.description && (
        <p className="text-ink-muted text-sm whitespace-pre-wrap">{location.description}</p>
      )}
      {location.admin_description && (
        <div className="mt-3 pt-3 border-t-2 border-[#cfc7a8]">
          <p className="text-[#a3841a] text-xs font-bold mb-1">🛠 Description admin</p>
          <p className="text-ink-muted text-sm whitespace-pre-wrap">{location.admin_description}</p>
        </div>
      )}

      {viewerOpen && location.image_url && (
        <ImageLightbox src={location.image_url} alt={location.titre} onClose={() => setViewerOpen(false)} />
      )}
    </ReferencePopupShell>
  )
}
