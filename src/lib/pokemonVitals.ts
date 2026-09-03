import { supabase } from './supabase'
import type { PlayerPokemon } from '../types'
import { DEFAULT_STATUS, type StatusId } from './status'

// PV courants et statut d'un Pokémon possédé.
//
// Historique : ces deux valeurs vivaient uniquement dans le localStorage de
// chaque navigateur (anciens hooks useLocalHp / useLocalStatus). Elles sont
// passées en base avec le mode En ligne (player_pokemon.current_hp /
// hp_ref_max / status) pour que le joueur, le MJ et le plateau de bataille
// voient exactement le même état — et pour qu'un changement d'appareil ne
// remette plus tout à zéro.
//
// Ce module tient un petit store en mémoire par-dessus les lignes chargées par
// les hooks, pour deux raisons :
//  - l'affichage doit rester instantané : les boutons +/- de PV passent par
//    useHoldRepeat et tirent une dizaine de fois par seconde ;
//  - les écritures doivent être groupées, sinon chaque tick partirait en UPDATE.

export interface Vitals {
  /** null = jamais renseigné ⇒ le Pokémon est à ses PV max. */
  hp: number | null
  /** PV max au moment où `hp` a été écrit. */
  refMax: number | null
  status: StatusId | null
}

function clamp(value: number, max: number): number {
  return Math.max(0, Math.min(max, value))
}

export function vitalsFromRow(pp: PlayerPokemon): Vitals {
  return { hp: pp.current_hp, refMax: pp.hp_ref_max, status: pp.status }
}

/** PV effectifs. Quand un palier d'XP a fait grandir les PV max depuis la
 *  dernière écriture, on reporte le même gain sur les PV courants — À LA
 *  LECTURE. C'est ce que faisait l'effet de l'ancien useLocalHp, mais sans
 *  écriture : trois composants montés sur le même Pokémon auraient sinon
 *  déclenché trois UPDATE à chaque franchissement de palier. */
export function resolveHp(vitals: Vitals | undefined, maxHp: number): number {
  if (!vitals || vitals.hp == null) return maxHp
  const ref = vitals.refMax ?? maxHp
  const adjusted = maxHp > ref ? vitals.hp + (maxHp - ref) : vitals.hp
  return clamp(adjusted, maxHp)
}

export function resolveStatus(vitals: Vitals | undefined): StatusId {
  return vitals?.status ?? DEFAULT_STATUS
}

/** Fusionne l'état du store par-dessus la ligne de base.
 *
 *  Indispensable parce que les setters ne connaissent qu'un champ à la fois :
 *  régler les PV d'un Pokémon dont le store n'a pas encore été alimenté créerait
 *  une entrée sans statut, et le statut disparaîtrait de l'écran alors qu'il est
 *  toujours en base. Un champ absent du store (null) retombe donc sur la ligne —
 *  'aucun' étant une vraie valeur, effacer volontairement un statut fonctionne. */
export function mergeVitals(stored: Vitals | undefined, row: Vitals): Vitals {
  if (!stored) return row
  return {
    hp: stored.hp ?? row.hp,
    refMax: stored.refMax ?? row.refMax,
    status: stored.status ?? row.status,
  }
}

// ── Store ────────────────────────────────────────────────────
const store = new Map<number, Vitals>()
const listeners = new Map<number, Set<() => void>>()

type VitalsPatch = { current_hp?: number; hp_ref_max?: number; status?: StatusId }
const pending = new Map<number, VitalsPatch>()
/** Horodatage jusqu'auquel la valeur locale l'emporte sur ce qui arrive du
 *  serveur : sans ça, un écho Realtime en retard (ou le refetch d'un autre
 *  hook) ferait clignoter les PU juste après une édition. */
const localUntil = new Map<number, number>()
const LOCAL_PRIORITY_MS = 1500
const FLUSH_DELAY_MS = 250
let flushTimer: ReturnType<typeof setTimeout> | null = null

// Abonnement global : le plateau de bataille affiche les PV de plusieurs
// Pokémon à la fois, il lui faut un signal unique plutôt qu'un abonnement par
// jeton. `version` sert de snapshot à useSyncExternalStore.
const globalListeners = new Set<() => void>()
let version = 0

function emit(id: number): void {
  version += 1
  listeners.get(id)?.forEach((cb) => cb())
  globalListeners.forEach((cb) => cb())
}

export function subscribeAllVitals(cb: () => void): () => void {
  globalListeners.add(cb)
  return () => { globalListeners.delete(cb) }
}

export function getVitalsVersion(): number {
  return version
}

export function subscribeVitals(id: number, cb: () => void): () => void {
  let set = listeners.get(id)
  if (!set) {
    set = new Set()
    listeners.set(id, set)
  }
  set.add(cb)
  return () => {
    set.delete(cb)
    if (set.size === 0) listeners.delete(id)
  }
}

export function getVitals(id: number): Vitals | undefined {
  return store.get(id)
}

/** PV effectifs hors cycle de vie d'un composant (ex : repérer les K.O. avant
 *  un « tout soigner » groupé). Retombe sur la ligne si le store n'a pas
 *  encore été alimenté. */
export function peekHp(pp: PlayerPokemon, maxHp: number): number {
  return resolveHp(mergeVitals(store.get(pp.id), vitalsFromRow(pp)), maxHp)
}

/** Alimente le store depuis des lignes fraîchement lues (fetch ou Realtime).
 *  Appelé par usePlayerPokemon et useBoardPokemon — jamais pendant un rendu. */
export function primeVitals(rows: PlayerPokemon[]): void {
  const now = Date.now()
  for (const row of rows) {
    if (pending.has(row.id)) continue
    if ((localUntil.get(row.id) ?? 0) > now) continue
    const next = vitalsFromRow(row)
    const prev = store.get(row.id)
    if (prev && prev.hp === next.hp && prev.refMax === next.refMax && prev.status === next.status) continue
    store.set(row.id, next)
    emit(row.id)
  }
}

function queue(id: number, patch: VitalsPatch): void {
  pending.set(id, { ...pending.get(id), ...patch })
  localUntil.set(id, Date.now() + LOCAL_PRIORITY_MS)
  if (flushTimer) return
  flushTimer = setTimeout(() => {
    flushTimer = null
    void flushVitals()
  }, FLUSH_DELAY_MS)
}

export function setVitalsHp(id: number, hp: number, maxHp: number): void {
  const value = clamp(hp, maxHp)
  const prev = store.get(id)
  store.set(id, { hp: value, refMax: maxHp, status: prev?.status ?? null })
  emit(id)
  queue(id, { current_hp: value, hp_ref_max: maxHp })
}

export function setVitalsStatus(id: number, status: StatusId): void {
  const prev = store.get(id)
  store.set(id, { hp: prev?.hp ?? null, refMax: prev?.refMax ?? null, status })
  emit(id)
  queue(id, { status })
}

/** Remise à PV max + statut « aucun » pour un lot de Pokémon (« Tout soigner »). */
export function restoreVitals(entries: { id: number; maxHp: number }[]): void {
  for (const { id, maxHp } of entries) {
    store.set(id, { hp: maxHp, refMax: maxHp, status: DEFAULT_STATUS })
    emit(id)
    queue(id, { current_hp: maxHp, hp_ref_max: maxHp, status: DEFAULT_STATUS })
  }
}

export async function flushVitals(): Promise<void> {
  if (flushTimer) {
    clearTimeout(flushTimer)
    flushTimer = null
  }
  if (pending.size === 0) return
  const batch = [...pending.entries()]
  pending.clear()
  await Promise.all(
    batch.map(async ([id, patch]) => {
      const { error } = await supabase.from('player_pokemon').update(patch).eq('id', id)
      if (error) console.error('Erreur lors de la sauvegarde des PV/statut :', error)
      localUntil.set(id, Date.now() + LOCAL_PRIORITY_MS)
    })
  )
}

// Fermeture d'onglet / passage en arrière-plan : on ne laisse pas une édition
// en attente dans le timer de groupage.
if (typeof window !== 'undefined') {
  window.addEventListener('pagehide', () => { void flushVitals() })
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) void flushVitals()
  })
}
