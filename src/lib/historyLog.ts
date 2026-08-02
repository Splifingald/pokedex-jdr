import { supabase } from './supabase'
import type { HistoryCategory, HistoryActionType, HistoryPayload } from '../types'

// Insertion "fire-and-forget" : le journal est un bonus, pas une donnée
// critique du jeu — un échec d'écriture ne doit jamais bloquer ou casser la
// mutation réelle qu'il accompagne. Toujours appelé avec `void` par les sites
// d'appel plutôt qu'attendu.
export async function logHistoryEvent(
  category: HistoryCategory,
  actionType: HistoryActionType,
  playerId: number,
  payload: HistoryPayload
): Promise<void> {
  const { error } = await supabase
    .from('history_events')
    .insert({ player_id: playerId, category, action_type: actionType, payload })
  if (error) {
    console.error("Erreur lors de l'enregistrement de l'historique :", error)
  }
}
