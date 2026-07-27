import { useEffect, useMemo, useState } from 'react'
import type { Attack, CarteLocation, Encounter, Pokemon } from '../../types'
import { ReferencePopupShell } from './ReferencePopupShell'
import { ImageLightbox } from '../ImageLightbox'
import { EncounterRow } from '../EncounterRow'
import { EncounterQuickPickBar } from '../EncounterQuickPickBar'
import { PokemonDetailSheet } from '../PokemonDetailSheet'
import { PixelIcon } from '../icons/PixelIcon'
import { NAV_ICON } from '../../lib/icons'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { rollQuickPick, getQuickPickTopDe, getQuickPickHighlight, scrollToEncounterRow } from '../../lib/encounterQuickPick'

interface Props {
  location: CarteLocation
  encounters: Encounter[]
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  onClose: () => void
}

export function LocationReferencePopup({ location, encounters, pokemonByName, attacksByName, onClose }: Props) {
  const [viewerOpen, setViewerOpen] = useState(false)
  const [quickPick, setQuickPick] = useState<number | null>(null)
  const [selectedPokemon, setSelectedPokemon] = useState<Pokemon | null>(null)
  const sortedEncounters = useMemo(
    () => [...encounters].sort((a, b) => (a.de ?? Infinity) - (b.de ?? Infinity)),
    [encounters]
  )

  const topDe = useMemo(
    () => (quickPick != null ? getQuickPickTopDe(sortedEncounters, quickPick) : null),
    [sortedEncounters, quickPick]
  )

  useEffect(() => {
    if (topDe == null) return
    const topRow = sortedEncounters.find((r) => r.de === topDe)
    if (topRow) scrollToEncounterRow(topRow.id)
  }, [sortedEncounters, topDe])

  return (
    <>
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
            <div className="flex items-center gap-1.5 mb-1.5">
              <PixelIcon src={NAV_ICON.rencontres!} size={14} colored className="text-[#7a7c9a]" alt="" />
              <p className="text-[#7a7c9a] text-xs font-bold">Rencontres possibles</p>
            </div>
            <EncounterQuickPickBar
              pick={quickPick}
              onToggle={() => setQuickPick((p) => (p == null ? rollQuickPick() : null))}
            />
            <table className="w-full border-collapse">
              <tbody>
                {sortedEncounters.map((row) => (
                  <EncounterRow
                    key={row.id}
                    row={row}
                    pokemon={pokemonByName.get(row.pokemon_nom)}
                    highlight={getQuickPickHighlight(row, quickPick, topDe)}
                    onSelect={setSelectedPokemon}
                  />
                ))}
              </tbody>
            </table>
          </div>
        )}

        {viewerOpen && location.image_url && (
          <ImageLightbox src={location.image_url} alt={location.titre} onClose={() => setViewerOpen(false)} />
        )}
      </ReferencePopupShell>

      {selectedPokemon && (
        <PokemonDetailSheet
          context="pokedex"
          pokemon={selectedPokemon}
          attacksByName={attacksByName}
          isAdmin={true}
          isDiscovered={true}
          elevated
          onClose={() => setSelectedPokemon(null)}
        />
      )}
    </>
  )
}
