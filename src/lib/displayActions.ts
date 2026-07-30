import type { DisplayAsset, DisplayState } from '../types'
import type { ReferenceEntry, ReferenceType } from '../hooks/useReferenceIndex'
import { addToLayer } from './displayLayers'

export type UpdateDisplayState = (data: Partial<Omit<DisplayState, 'id' | 'updated_at'>>) => void

/** Calque affecté par un type de référence, pour "Vider le calque"/"Ajouter à l'affichage". */
export type DisplayLayer = 'npc' | 'pokemon' | 'item' | 'background'

export const normalizeName = (s: string) => s.trim().toLowerCase()
const normalize = normalizeName

/** Un PNJ/Lieu ne pousse pas sa propre image (portrait/icône) sur l'affichage : on cherche
 * une entrée display_assets du bon type dont le nom correspond, pensée pour la projection
 * plein écran. Pokémon/Objet utilisent directement leur propre id (déjà la bonne table). */
export function resolveDisplayAssetForReference(entry: ReferenceEntry, assets: DisplayAsset[]): DisplayAsset | null {
  if (entry.type === 'player') {
    return assets.find((a) => a.type === 'NPC' && normalize(a.nom) === normalize(entry.name)) ?? null
  }
  if (entry.type === 'location') {
    return assets.find((a) => a.type === 'Background' && normalize(a.nom) === normalize(entry.name)) ?? null
  }
  return null
}

export function canAddToDisplay(entry: ReferenceEntry, assets: DisplayAsset[]): boolean {
  if (entry.type === 'pokemon' || entry.type === 'item') return true
  if (entry.type === 'player' || entry.type === 'location') return resolveDisplayAssetForReference(entry, assets) !== null
  return false
}

export function layerForReferenceType(type: ReferenceType): DisplayLayer | null {
  if (type === 'pokemon') return 'pokemon'
  if (type === 'player') return 'npc'
  if (type === 'item') return 'item'
  if (type === 'location') return 'background'
  return null
}

/** background_id (fond curé) et background_url (URL libre, ex : bannière de chapitre) sont
 * mutuellement exclusifs : ces deux fonctions annulent toujours l'autre champ pour que le
 * dernier choix fasse foi (voir resolveDisplayState, qui priorise background_url). */
export function setBackgroundAsset(assetId: number, updateDisplayState: UpdateDisplayState): void {
  updateDisplayState({ background_id: assetId, background_url: null })
}

export function setBackgroundUrl(url: string, updateDisplayState: UpdateDisplayState): void {
  updateDisplayState({ background_url: url, background_id: null })
}

/** Tableau d'ids du calque concerné par cette référence (null pour le fond, calque à une seule valeur). */
export function layerIdsForReference(entry: ReferenceEntry, state: DisplayState): number[] | null {
  const layer = layerForReferenceType(entry.type)
  if (layer === 'npc') return state.npc_ids
  if (layer === 'pokemon') return state.pokemon_ids
  if (layer === 'item') return state.item_ids
  return null
}

/** Ajoute la référence à l'affichage. Renvoie false si aucune image n'a pu être résolue
 * (l'appelant doit alors avertir l'utilisateur, ex. via un toast). */
export function addReferenceToDisplay(
  entry: ReferenceEntry,
  state: DisplayState,
  assets: DisplayAsset[],
  updateDisplayState: UpdateDisplayState
): boolean {
  if (entry.type === 'pokemon') {
    updateDisplayState({ pokemon_ids: addToLayer(state.pokemon_ids, entry.id) })
    return true
  }
  if (entry.type === 'item') {
    updateDisplayState({ item_ids: addToLayer(state.item_ids, entry.id) })
    return true
  }
  if (entry.type === 'player') {
    const asset = resolveDisplayAssetForReference(entry, assets)
    if (!asset) return false
    updateDisplayState({ npc_ids: addToLayer(state.npc_ids, asset.id) })
    return true
  }
  if (entry.type === 'location') {
    const asset = resolveDisplayAssetForReference(entry, assets)
    if (!asset) return false
    setBackgroundAsset(asset.id, updateDisplayState)
    return true
  }
  return false
}

export function clearLayer(layer: DisplayLayer, updateDisplayState: UpdateDisplayState): void {
  if (layer === 'npc') updateDisplayState({ npc_ids: [] })
  else if (layer === 'pokemon') updateDisplayState({ pokemon_ids: [] })
  else if (layer === 'item') updateDisplayState({ item_ids: [] })
  else if (layer === 'background') updateDisplayState({ background_id: null, background_url: null })
}

/** Réinitialise PNJ/Pokémon/Objets. Laisse volontairement le fond en place. */
export function clearAllLayers(updateDisplayState: UpdateDisplayState): void {
  updateDisplayState({ npc_ids: [], pokemon_ids: [], item_ids: [] })
}
