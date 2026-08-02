import { useState } from 'react'
import type { DisplayAsset, DisplayState, Player } from '../../types'
import type { ReferenceEntry } from '../../hooks/useReferenceIndex'
import {
  canAddToDisplay,
  layerIdsForReference,
  layerForReferenceType,
  resolveDisplayAssetCandidates,
  addReferenceToDisplay,
  clearLayer,
  clearAllLayers,
  type UpdateDisplayState,
} from '../../lib/displayActions'
import { moveInArray } from '../../lib/displayLayers'
import { useToast } from '../../context/ToastContext'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { PixelIcon } from '../icons/PixelIcon'
import { DISPLAY_ICON } from '../../lib/icons'
import { DisplayAssetCandidatePicker } from './DisplayAssetCandidatePicker'

interface Props {
  entry: ReferenceEntry
  displayState: DisplayState
  displayAssets: DisplayAsset[]
  updateDisplayState: UpdateDisplayState
  players?: Player[]
}

// Barre des boutons "affichage" placée en haut des popups de référence (Pokémon/PNJ/Lieu/Objet)
// — n'affiche rien si aucune image projetable n'est résolue (ex : PNJ/Lieu sans display_assets
// dont la Reference correspond, ni image plein pied de profil). PNJ/Lieu peuvent avoir plusieurs
// images partageant la même Reference : un picker cherchable remplace alors le bouton simple.
export function DisplayControlBar({ entry, displayState, displayAssets, updateDisplayState, players = [] }: Props) {
  const { showToast } = useToast()
  const [selectedId, setSelectedId] = useState<number | null>(null)

  const isPickerType = entry.type === 'player' || entry.type === 'location'
  const candidates = isPickerType ? resolveDisplayAssetCandidates(entry, displayAssets, players) : []

  if (!canAddToDisplay(entry, displayAssets, players)) return null

  const layer = layerForReferenceType(entry.type)
  if (!layer) return null

  const effectiveSelectedId = isPickerType
    ? (selectedId !== null && candidates.some((c) => c.id === selectedId) ? selectedId : candidates[0]?.id ?? null)
    : entry.id

  const ids = layerIdsForReference(entry, displayState)
  const indexInLayer = ids && effectiveSelectedId !== null ? ids.indexOf(effectiveSelectedId) : -1
  const showReorder = !!ids && indexInLayer !== -1 && ids.length > 1

  const handleAdd = () => {
    const ok = addReferenceToDisplay(entry, displayState, displayAssets, updateDisplayState, players, effectiveSelectedId ?? undefined)
    if (!ok) showToast(`Aucune image d'affichage trouvée pour ${entry.name}`)
  }

  const handleMove = (direction: -1 | 1) => {
    if (!ids || indexInLayer === -1) return
    const next = moveInArray(ids, indexInLayer, direction)
    if (layer === 'npc') updateDisplayState({ npc_ids: next })
    else if (layer === 'pokemon') updateDisplayState({ pokemon_ids: next })
    else if (layer === 'item') updateDisplayState({ item_ids: next })
  }

  const reorderButtons = (
    <div className="flex items-center gap-1">
      <button
        onClick={() => handleMove(-1)}
        disabled={indexInLayer === 0}
        className={`text-xs px-2 py-1 rounded shrink-0 disabled:opacity-30 ${BUTTON_STYLE.gray}`}
      >
        ◀
      </button>
      <button
        onClick={() => handleMove(1)}
        disabled={indexInLayer === (ids?.length ?? 1) - 1}
        className={`text-xs px-2 py-1 rounded shrink-0 disabled:opacity-30 ${BUTTON_STYLE.gray}`}
      >
        ▶
      </button>
    </div>
  )

  return (
    <div className="flex flex-wrap items-center gap-1.5 mb-3">
      <span className="shrink-0 text-ink" title="Affichage"><PixelIcon src={DISPLAY_ICON} size={16} colored /></span>
      {isPickerType ? (
        <>
          <DisplayAssetCandidatePicker candidates={candidates} selectedId={effectiveSelectedId} onSelect={setSelectedId} />
          <button onClick={handleAdd} className={`text-xs px-2 py-1 rounded font-bold shrink-0 ${BUTTON_STYLE.blue}`} title="Ajouter à l'affichage">
            ➕
          </button>
          {showReorder && reorderButtons}
        </>
      ) : showReorder ? (
        reorderButtons
      ) : (
        <button onClick={handleAdd} className={`text-xs px-2 py-1 rounded font-bold ${BUTTON_STYLE.blue}`}>
          ➕ Ajouter à l'affichage
        </button>
      )}
      <button onClick={() => clearLayer(layer, updateDisplayState)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
        Vider le calque
      </button>
      <button onClick={() => clearAllLayers(updateDisplayState)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
        Tout effacer
      </button>
    </div>
  )
}
