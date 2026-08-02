import type { HistoryEvent, HistoryActionType, HistoryPayload, HistoryInventoryPayload } from '../types'

export interface DisplayHistoryEntry {
  key: string
  player_id: number
  category: HistoryEvent['category']
  action_type: HistoryActionType
  payload: HistoryPayload
  created_at: string
}

const MERGE_WINDOW_MS = 10_000

function isInventoryEvent(e: HistoryEvent): e is HistoryEvent & { payload: HistoryInventoryPayload } {
  return e.category === 'inventory'
}

// Signe de l'événement pour le calcul du delta net d'un groupe fusionné.
function signedDelta(actionType: HistoryActionType, delta: number): number {
  return actionType === 'item_remove' || actionType === 'item_casino_spend' ? -delta : delta
}

interface OpenGroup {
  firstId: number
  playerId: number
  itemNom: string
  source: string
  netDelta: number
  lastTotal: number
  lastCreatedAt: string
  actionTypes: Set<HistoryActionType>
}

function closeGroup(group: OpenGroup): DisplayHistoryEntry | null {
  if (group.netDelta === 0) return null
  const actionType: HistoryActionType =
    group.actionTypes.size === 1
      ? [...group.actionTypes][0]
      : group.netDelta > 0
        ? 'item_add'
        : 'item_remove'
  return {
    key: `group-${group.firstId}`,
    player_id: group.playerId,
    category: 'inventory',
    action_type: actionType,
    payload: {
      item_nom: group.itemNom,
      delta: Math.abs(group.netDelta),
      total: group.lastTotal,
      source: group.source,
    },
    created_at: group.lastCreatedAt,
  }
}

// Regroupe les événements d'inventaire proches dans le temps (même joueur,
// même objet, même source) en une seule ligne d'affichage, à la lecture —
// voir la règle des 10s dans PLAYER_HISTORY_LOGGING.md. Les autres catégories
// passent telles quelles, un événement brut = une ligne.
export function groupHistoryEvents(events: HistoryEvent[]): DisplayHistoryEntry[] {
  const sorted = [...events].sort((a, b) => a.created_at.localeCompare(b.created_at))

  const result: DisplayHistoryEntry[] = []
  const openGroups = new Map<string, OpenGroup>()

  for (const event of sorted) {
    if (!isInventoryEvent(event)) {
      result.push({
        key: `id-${event.id}`,
        player_id: event.player_id,
        category: event.category,
        action_type: event.action_type,
        payload: event.payload,
        created_at: event.created_at,
      })
      continue
    }

    const groupKey = `${event.player_id}|${event.payload.item_nom}|${event.payload.source}`
    const existing = openGroups.get(groupKey)
    const eventTime = new Date(event.created_at).getTime()

    if (existing && eventTime - new Date(existing.lastCreatedAt).getTime() <= MERGE_WINDOW_MS) {
      existing.netDelta += signedDelta(event.action_type, event.payload.delta)
      existing.lastTotal = event.payload.total
      existing.lastCreatedAt = event.created_at
      existing.actionTypes.add(event.action_type)
    } else {
      if (existing) {
        const closed = closeGroup(existing)
        if (closed) result.push(closed)
      }
      openGroups.set(groupKey, {
        firstId: event.id,
        playerId: event.player_id,
        itemNom: event.payload.item_nom,
        source: event.payload.source,
        netDelta: signedDelta(event.action_type, event.payload.delta),
        lastTotal: event.payload.total,
        lastCreatedAt: event.created_at,
        actionTypes: new Set([event.action_type]),
      })
    }
  }

  for (const group of openGroups.values()) {
    const closed = closeGroup(group)
    if (closed) result.push(closed)
  }

  return result.sort((a, b) => b.created_at.localeCompare(a.created_at))
}
