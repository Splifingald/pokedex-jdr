import { supabase } from './supabase'
import type { PlayerPokemon } from '../types'
import { DEFAULT_STATUS, type StatusId } from './status'

// Reprise unique du localStorage vers la base.
//
// Avant le mode En ligne, les PV et statuts étaient écrits dans le
// localStorage sous les clés `hp_<id>` et `status_<id>`. La migration ne doit
// rien perdre : au premier lancement suivant la mise à jour, chaque appareil
// pousse ce qu'il a vers les colonnes player_pokemon.current_hp / status —
// mais UNIQUEMENT là où la base est encore vide (garde côté SQL dans
// online_backfill_vitals). Un second appareil au localStorage périmé ne peut
// donc pas écraser une valeur déjà à jour : le premier arrivé fait foi.

const FLAG_KEY = 'vitals_migrated_v1'
const STATUS_VALUES: StatusId[] = [
  'aucun', 'paralysie', 'apeure', 'confusion', 'endormi', 'brule', 'empoisonne', 'gele',
]

let running = false

function readNumber(key: string): number | null {
  const raw = localStorage.getItem(key)
  if (raw === null) return null
  const parsed = parseInt(raw, 10)
  return Number.isFinite(parsed) ? parsed : null
}

function readStatus(key: string): StatusId | null {
  const raw = localStorage.getItem(key) as StatusId | null
  return raw && STATUS_VALUES.includes(raw) ? raw : null
}

export function isVitalsMigrationDone(): boolean {
  try {
    return localStorage.getItem(FLAG_KEY) === '1'
  } catch {
    return true
  }
}

/** À appeler une fois, après le premier chargement du roster du joueur courant.
 *  `maxHpOf` sert à renseigner hp_ref_max : sans lui, un palier d'XP déjà
 *  franchi serait recompté au premier rendu. */
export async function backfillVitalsFromLocalStorage(
  rows: PlayerPokemon[],
  maxHpOf: (pp: PlayerPokemon) => number
): Promise<void> {
  if (running || isVitalsMigrationDone() || rows.length === 0) return
  running = true
  try {
    const payload = rows
      .filter((pp) => pp.current_hp === null)
      .map((pp) => {
        const hp = readNumber(`hp_${pp.id}`)
        const status = readStatus(`status_${pp.id}`)
        if (hp === null && (status === null || status === DEFAULT_STATUS)) return null
        const maxHp = maxHpOf(pp)
        return {
          id: pp.id,
          current_hp: hp === null ? maxHp : Math.max(0, Math.min(maxHp, hp)),
          hp_ref_max: maxHp,
          status: status ?? DEFAULT_STATUS,
        }
      })
      .filter((row): row is NonNullable<typeof row> => row !== null)

    if (payload.length > 0) {
      const { error } = await supabase.rpc('online_backfill_vitals', { p_rows: payload })
      if (error) {
        console.error('Erreur lors de la reprise des PV/statuts locaux :', error)
        return // on ne pose pas le drapeau : on réessaiera au prochain lancement
      }
    }
    // Les anciennes clés hp_* / status_* sont laissées en place : inoffensives,
    // et elles permettent de rejouer la reprise si le drapeau est effacé.
    localStorage.setItem(FLAG_KEY, '1')
  } catch (err) {
    console.error('Erreur lors de la reprise des PV/statuts locaux :', err)
  } finally {
    running = false
  }
}
