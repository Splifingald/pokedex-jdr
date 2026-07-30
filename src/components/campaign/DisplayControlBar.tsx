import type { DisplayAsset, DisplayState } from '../../types'
import type { ReferenceEntry } from '../../hooks/useReferenceIndex'
import {
  canAddToDisplay,
  layerIdsForReference,
  layerForReferenceType,
  resolveDisplayAssetForReference,
  addReferenceToDisplay,
  clearLayer,
  clearAllLayers,
  type UpdateDisplayState,
} from '../../lib/displayActions'
import { moveInArray } from '../../lib/displayLayers'
import { useToast } from '../../context/ToastContext'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  entry: ReferenceEntry
  displayState: DisplayState
  displayAssets: DisplayAsset[]
  updateDisplayState: UpdateDisplayState
}

// Barre des 3 boutons "affichage" placée en haut des popups de référence
// (Pokémon/PNJ/Lieu/Objet) — n'affiche rien si aucune image projetable n'est
// résolue (ex : PNJ/Lieu sans entrée display_assets du même nom).
export function DisplayControlBar({ entry, displayState, displayAssets, updateDisplayState }: Props) {
  const { showToast } = useToast()

  if (!canAddToDisplay(entry, displayAssets)) return null

  const layer = layerForReferenceType(entry.type)
  if (!layer) return null

  const resolvedId =
    entry.type === 'pokemon' || entry.type === 'item'
      ? entry.id
      : resolveDisplayAssetForReference(entry, displayAssets)?.id ?? null

  const ids = layerIdsForReference(entry, displayState)
  const indexInLayer = ids && resolvedId !== null ? ids.indexOf(resolvedId) : -1
  const showReorder = !!ids && indexInLayer !== -1 && ids.length > 1

  const handleAdd = () => {
    const ok = addReferenceToDisplay(entry, displayState, displayAssets, updateDisplayState)
    if (!ok) showToast(`Aucune image d'affichage trouvée pour ${entry.name}`)
  }

  const handleMove = (direction: -1 | 1) => {
    if (!ids || indexInLayer === -1) return
    const next = moveInArray(ids, indexInLayer, direction)
    if (layer === 'npc') updateDisplayState({ npc_ids: next })
    else if (layer === 'pokemon') updateDisplayState({ pokemon_ids: next })
    else if (layer === 'item') updateDisplayState({ item_ids: next })
  }

  return (
    <div className="flex flex-wrap items-center gap-1.5 mb-3">
      <span className="text-base shrink-0" title="Affichage">🖼️</span>
      {showReorder ? (
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
