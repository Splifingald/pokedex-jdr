import { useCallback, useSyncExternalStore } from 'react'
import type { PlayerPokemon } from '../types'
import type { StatusId } from '../lib/status'
import {
  getVitals,
  mergeVitals,
  resolveHp,
  resolveStatus,
  setVitalsHp,
  setVitalsStatus,
  subscribeVitals,
  vitalsFromRow,
} from '../lib/pokemonVitals'

// Remplacent les anciens useLocalHp / useLocalStatus, qui lisaient et
// écrivaient le localStorage de l'appareil. Les PV et le statut vivent
// désormais en base (voir lib/pokemonVitals.ts) : mêmes valeurs sur l'accueil,
// dans l'équipe, sur le plateau de bataille et côté MJ.
//
// La ligne est passée en argument (et pas seulement son id) pour couvrir le
// tout premier rendu, avant que le store n'ait été alimenté : on retombe alors
// directement sur les colonnes de la ligne, sans afficher brièvement les PV max.

export function usePokemonHp(playerPokemon: PlayerPokemon, maxHp: number) {
  const id = playerPokemon.id
  const subscribe = useCallback((cb: () => void) => subscribeVitals(id, cb), [id])
  const stored = useSyncExternalStore(subscribe, () => getVitals(id))
  const hp = resolveHp(mergeVitals(stored, vitalsFromRow(playerPokemon)), maxHp)
  const setHp = useCallback((value: number) => setVitalsHp(id, value, maxHp), [id, maxHp])
  return [hp, setHp] as const
}

export function usePokemonStatus(playerPokemon: PlayerPokemon) {
  const id = playerPokemon.id
  const subscribe = useCallback((cb: () => void) => subscribeVitals(id, cb), [id])
  const stored = useSyncExternalStore(subscribe, () => getVitals(id))
  const status = resolveStatus(mergeVitals(stored, vitalsFromRow(playerPokemon)))
  const setStatus = useCallback((value: StatusId) => setVitalsStatus(id, value), [id])
  return [status, setStatus] as const
}
