import { useState } from 'react'
import type { CarteLocation, Encounter, Pokemon } from '../../types'
import { ReferencePopupShell } from './ReferencePopupShell'
import { ImageLightbox } from '../ImageLightbox'
import { EncounterRow } from '../EncounterRow'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  location: CarteLocation
  encounters: Encounter[]
  pokemonByName: Map<string, Pokemon>
  onClose: () => void
}

export function LocationReferencePopup({ location, encounters, pokemonByName, onClose }: Props) {
  const [viewerOpen, setViewerOpen] = useState(false)
  const [expandedCommentId, setExpandedCommentId] = useState<number | null>(null)
  const sortedEncounters = [...encounters].sort((a, b) => (a.de ?? Infinity) - (b.de ?? Infinity))

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

      {sortedEncounters.length > 0 && (
        <div className="mt-3 pt-3 border-t-2 border-[#cfc7a8]">
          <p className="text-[#7a7c9a] text-xs font-bold mb-1.5">🎯 Rencontres possibles</p>
          <div className="flex flex-col gap-1">
            {sortedEncounters.map((row) => (
              <div key={row.id}>
                <EncounterRow
                  row={row}
                  pokemon={pokemonByName.get(row.pokemon_nom)}
                  onOpenComment={(r) => setExpandedCommentId((id) => (id === r.id ? null : r.id))}
                />
                {expandedCommentId === row.id && row.commentaire && (
                  <p className="text-ink-muted text-xs whitespace-pre-wrap pl-8 pb-1">{row.commentaire}</p>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {viewerOpen && location.image_url && (
        <ImageLightbox src={location.image_url} alt={location.titre} onClose={() => setViewerOpen(false)} />
      )}
    </ReferencePopupShell>
  )
}
