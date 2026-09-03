import { supabase } from './supabase'
import type { EndgameItemReward, EndgameRewards, EndgameXpReward, OnlineBattleLogRow, OnlineToken, PlayerPokemon, Pokemon } from '../types'
import { getMaxHp } from './maxHp'
import { getVitals, mergeVitals, resolveHp, vitalsFromRow } from './pokemonVitals'

// Bilan de fin de partie : croisement du journal de bataille avec l'état
// courant du plateau.
//
// Le journal retient tous les Pokémon ayant participé, y compris ceux qui ont
// quitté le plateau. Pour ceux qui y sont encore, on lit leurs PV en direct ;
// pour les autres, ceux enregistrés à leur départ.

export interface EndgameEntry {
  key: string
  nom: string
  /** Surnom ou libellé libre, s'il diffère du nom d'espèce. */
  displayName: string
  species: Pokemon | undefined
  ownerPlayerId: number | null
  playerPokemonId: number | null
  owned: PlayerPokemon | undefined
  hp: number
  maxHp: number
  isKo: boolean
  isAlly: boolean
  stillOnBoard: boolean
}

interface Context {
  log: OnlineBattleLogRow[]
  tokens: OnlineToken[]
  ownedById: Map<number, PlayerPokemon>
  pokemonByName: Map<string, Pokemon>
}

export function buildEndgameEntries({ log, tokens, ownedById, pokemonByName }: Context): EndgameEntry[] {
  const tokenByPp = new Map<number, OnlineToken>()
  const tokenById = new Map<number, OnlineToken>()
  for (const t of tokens) {
    tokenById.set(t.id, t)
    if (t.player_pokemon_id != null) tokenByPp.set(t.player_pokemon_id, t)
  }

  return log.map((row) => {
    const species = pokemonByName.get(row.pokemon_nom)
    const owned = row.player_pokemon_id != null ? ownedById.get(row.player_pokemon_id) : undefined
    const onBoard = row.player_pokemon_id != null
      ? tokenByPp.get(row.player_pokemon_id)
      : (row.token_id != null ? tokenById.get(row.token_id) : undefined)

    let maxHp = row.max_hp
    let hp: number
    if (owned) {
      maxHp = getMaxHp(owned, species) || row.max_hp
      // Encore en jeu : ses PV du moment. Parti : ceux notés à son départ.
      hp = onBoard || row.last_hp == null
        ? resolveHp(mergeVitals(getVitals(owned.id), vitalsFromRow(owned)), maxHp)
        : row.last_hp
    } else if (onBoard) {
      hp = onBoard.free_current_hp ?? onBoard.free_max_hp ?? row.max_hp
      maxHp = onBoard.free_max_hp ?? row.max_hp
    } else {
      hp = row.last_hp ?? row.max_hp
    }

    return {
      key: row.entity_key,
      nom: row.pokemon_nom,
      displayName: owned?.nickname?.trim() || row.label.trim() || row.pokemon_nom,
      species,
      ownerPlayerId: row.owner_player_id,
      playerPokemonId: row.player_pokemon_id,
      owned,
      hp: Math.max(0, hp),
      maxHp,
      isKo: hp <= 0,
      isAlly: row.is_ally,
      stillOnBoard: !!onBoard,
    }
  })
}

/** Somme des PV max des ennemis mis K.O. — la base de calcul de l'XP à donner. */
export function totalKoEnemyHp(entries: EndgameEntry[]): number {
  return entries.filter((e) => !e.isAlly && e.isKo).reduce((sum, e) => sum + e.maxHp, 0)
}

export interface ItemGrant {
  item_nom: string
  quantity: number
  /** null = tous les participants alliés. */
  playerId: number | null
}

/** Applique réellement les gains : XP sur les Pokémon, objets dans les sacs.
 *  Renvoie le récapitulatif à montrer aux joueurs — les gains sont déjà en base
 *  quand il est renvoyé, ce n'est pas une file d'attente. */
export async function applyEndgameRewards(
  xpByPokemon: Map<number, number>,
  entries: EndgameEntry[],
  grants: ItemGrant[],
  participantIds: number[]
): Promise<EndgameRewards> {
  const rewards: EndgameRewards = {}
  const ensure = (playerId: number) => {
    const k = String(playerId)
    if (!rewards[k]) rewards[k] = { xp: [], items: [] }
    return rewards[k]
  }

  // ── XP ──
  for (const entry of entries) {
    if (entry.playerPokemonId == null || !entry.owned || entry.ownerPlayerId == null) continue
    const next = xpByPokemon.get(entry.playerPokemonId)
    if (next === undefined || next === entry.owned.xp) continue
    const { error } = await supabase.from('player_pokemon').update({ xp: next }).eq('id', entry.playerPokemonId)
    if (error) {
      console.error("Erreur lors de l'attribution d'XP :", error)
      continue
    }
    const reward: EndgameXpReward = {
      player_pokemon_id: entry.playerPokemonId,
      nom: entry.displayName,
      gained: next - entry.owned.xp,
      total: next,
    }
    ensure(entry.ownerPlayerId).xp.push(reward)
  }

  // ── Objets ──
  for (const grant of grants) {
    if (!grant.item_nom || grant.quantity <= 0) continue
    const targets = grant.playerId != null ? [grant.playerId] : participantIds
    for (const playerId of targets) {
      const { data: existing } = await supabase
        .from('player_items').select('id, quantity').eq('player_id', playerId).eq('item_nom', grant.item_nom).maybeSingle()
      const { error } = existing
        ? await supabase.from('player_items').update({ quantity: existing.quantity + grant.quantity }).eq('id', existing.id)
        : await supabase.from('player_items').insert({ player_id: playerId, item_nom: grant.item_nom, quantity: grant.quantity })
      if (error) {
        console.error("Erreur lors de la remise d'un objet :", error)
        continue
      }
      const item: EndgameItemReward = { item_nom: grant.item_nom, quantity: grant.quantity }
      ensure(playerId).items.push(item)
    }
  }

  return rewards
}
