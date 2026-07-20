export type StatusId =
  | 'aucun'
  | 'paralysie'
  | 'apeure'
  | 'confusion'
  | 'endormi'
  | 'brule'
  | 'empoisonne'
  | 'gele'

export interface StatusInfo {
  id: StatusId
  label: string
  color: string
  description: string
}

export const STATUS_LIST: StatusInfo[] = [
  { id: 'aucun', label: 'Aucun Statut', color: '#9CA3AF', description: '' },
  { id: 'paralysie', label: 'Paralysé', color: '#EAB308', description: "Empêche les mouvements et empêche de lancer des attaques pendant 1 tour." },
  { id: 'apeure', label: 'Appeuré', color: '#6B7280', description: "Empêche les mouvements et réduit la précision de 3 pendant 1 tour." },
  { id: 'confusion', label: 'Confus', color: '#EC4899', description: "Réduit la précision de 5 pendant 1 tour." },
  { id: 'endormi', label: 'Endormi', color: '#3B82F6', description: "Empêche les mouvements et les attaques : Au début de son tour, la cible lance un D6 pour se réveiller (4, 5, 6 = réveil)." },
  { id: 'brule', label: 'Brûlé', color: '#EF4444', description: "Inflige 5 de dégâts par tour à la cible, au début de son tour la cible lance un D6 pour ne plus être brûlée (4, 5, 6 = soin)." },
  { id: 'empoisonne', label: 'Empoisonné', color: '#A855F7', description: "Inflige 3 de dégâts par tour à la cible (s'arrête si la cible soigne ses PV ou son statut)." },
  { id: 'gele', label: 'Gelé', color: '#7DD3FC', description: "Empêche les mouvements et empêche de lancer des attaques pendant 1 tour." },
]

export const STATUS_BY_ID: Map<StatusId, StatusInfo> = new Map(STATUS_LIST.map((s) => [s.id, s]))

export const DEFAULT_STATUS: StatusId = 'aucun'

export function getStatusInfo(id: StatusId): StatusInfo {
  return STATUS_BY_ID.get(id) ?? STATUS_BY_ID.get('aucun')!
}
