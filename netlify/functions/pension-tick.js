// Netlify Scheduled Function (@hourly, voir netlify.toml) — fait avancer la
// Pension Pokémon : crédite l'XP gagnée depuis le dernier tick de chaque
// pokémon placé (même compteur player_pokemon.xp que partout ailleurs),
// notifie le propriétaire quand le plafond XP à vie est atteint, et fait
// "éclore" les paires (pension_pairs) dont la durée cible est écoulée. Tourne
// côté serveur : la clé service_role et les clés VAPID privées ne quittent
// jamais le serveur. Séparée de send-notifications.js (logique et forme de
// travail différentes — calculs en masse + production d'œufs plutôt qu'un
// simple lire/comparer/pousser), pour un rayon d'impact réduit si l'une des
// deux doit être débogée/désactivée indépendamment.
const { createClient } = require('@supabase/supabase-js')
const webpush = require('web-push')

const FALLBACK_ICON_PATH = '/website_icons/icon_daycare_game.png'
const UNIT_MS = { hours: 3_600_000, minutes: 60_000 }
// Même sentinelle que src/lib/pension.ts::DEFAULT_EGG_POOL_GROUP
const DEFAULT_EGG_POOL_GROUP = '__default__'

function absoluteUrl(siteUrl, path) {
  if (!path) return `${siteUrl}${FALLBACK_ICON_PATH}`
  return path.startsWith('http') ? path : `${siteUrl}${path}`
}

// Même logique que src/lib/pension.ts::resolveApplicableXpGroup, dupliquée ici
// faute de chemin d'import partagé entre le client TS et les fonctions Netlify
// JS (convention déjà en usage dans ce projet, voir pickWeightedEggSpecies).
// Les groupes XP sont entièrement séparés des groupes d'œufs — simple lookup
// direct (une espèce appartient à au plus un groupe XP), repli sur pension_config.
function resolveApplicable(pokemonNom, xpGroupByPokemonNom, pensionConfig) {
  const group = xpGroupByPokemonNom.get(pokemonNom)
  return {
    tickIntervalMs: group
      ? group.tick_interval_amount * UNIT_MS[group.tick_interval_unit]
      : pensionConfig.tick_interval_amount * UNIT_MS[pensionConfig.tick_interval_unit],
    lifetimeXpCap: group ? group.lifetime_xp_cap : pensionConfig.default_lifetime_xp_cap,
  }
}

const XP_LEVELS = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]

// Même logique que src/lib/xpBonuses.ts::getMaxXp (dupliquée ici) : XP du
// dernier palier non-vide des colonnes xp_10..xp_100, ou null si l'espèce n'a
// aucun palier défini (pas de plafond naturel dans ce cas).
function getMaxXpForSpecies(pokemonRow) {
  let max = null
  for (const level of XP_LEVELS) {
    const cell = pokemonRow[`xp_${level}`]
    if (cell && String(cell).trim()) max = level
  }
  return max
}

function rollHatchSeconds(groupe, groupConfigByGroup, pensionConfig) {
  const cfg = groupConfigByGroup.get(groupe)
  const min = cfg?.hatch_timer_min ?? pensionConfig.default_hatch_timer_min
  const max = cfg?.hatch_timer_max ?? pensionConfig.default_hatch_timer_max
  const unit = cfg?.hatch_timer_unit ?? pensionConfig.default_hatch_timer_unit
  const hours = min + Math.random() * Math.max(0, max - min)
  return Math.max(1, Math.round(hours * (unit === 'minutes' ? 60 : 3600)))
}

// Même précédence que src/lib/pension.ts::resolveEggPool (dupliquée ici comme
// le reste de la logique de ce fichier).
function resolveEggPool(groupe, groupConfigByGroup, eggPoolByGroup) {
  const mode = groupConfigByGroup.get(groupe)?.egg_pool_mode ?? 'default'
  if (mode === 'none') return []
  if (mode === 'custom') return eggPoolByGroup.get(groupe) || []
  return eggPoolByGroup.get(DEFAULT_EGG_POOL_GROUP) || []
}

function pickWeightedEggSpecies(pool) {
  const total = pool.reduce((sum, p) => sum + Math.max(0, p.weight), 0)
  if (total <= 0) return null
  let roll = Math.random() * total
  for (const entry of pool) {
    roll -= Math.max(0, entry.weight)
    if (roll < 0) return entry.pokemon_nom
  }
  return pool[pool.length - 1]?.pokemon_nom ?? null
}

exports.handler = async () => {
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    console.error('Configuration serveur manquante (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)')
    return { statusCode: 500, body: 'Configuration serveur manquante' }
  }
  if (!process.env.VAPID_PUBLIC_KEY || !process.env.VAPID_PRIVATE_KEY) {
    console.error('Clés VAPID manquantes (VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY)')
    return { statusCode: 500, body: 'Clés VAPID manquantes' }
  }

  const siteUrl = (process.env.URL || process.env.DEPLOY_PRIME_URL || '').replace(/\/$/, '')
  webpush.setVapidDetails(
    process.env.VAPID_SUBJECT || 'mailto:contact@example.com',
    process.env.VAPID_PUBLIC_KEY,
    process.env.VAPID_PRIVATE_KEY
  )

  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)
  const now = new Date()

  const { data: pensionConfig, error: configError } = await supabase.from('pension_config').select('*').eq('id', 1).single()
  if (configError || !pensionConfig) {
    console.error('Erreur lecture pension_config :', configError?.message)
    return { statusCode: 500, body: 'Erreur lecture pension_config' }
  }

  const [{ data: groupConfigRows }, { data: eggPoolRows }, { data: xpGroupRows }, { data: xpGroupSpeciesRows }] = await Promise.all([
    supabase.from('pension_group_config').select('*'),
    supabase.from('pension_egg_pool').select('*'),
    supabase.from('pension_xp_groups').select('*'),
    supabase.from('pension_xp_group_species').select('*'),
  ])

  const groupConfigByGroup = new Map((groupConfigRows || []).map((g) => [g.groupe, g]))
  const eggPoolByGroup = new Map()
  for (const row of eggPoolRows || []) {
    const list = eggPoolByGroup.get(row.groupe)
    if (list) list.push(row)
    else eggPoolByGroup.set(row.groupe, [row])
  }

  const xpGroupsById = new Map((xpGroupRows || []).map((g) => [g.id, g]))
  const xpGroupByPokemonNom = new Map()
  for (const row of xpGroupSpeciesRows || []) {
    const group = xpGroupsById.get(row.xp_group_id)
    if (group) xpGroupByPokemonNom.set(row.pokemon_nom, group)
  }

  // notifications à envoyer : { playerId, title, body, icon }
  const notifications = []

  // ── Accrue l'XP de chaque pokémon en pension ────────────────────────────
  const { data: daycareRows, error: daycareError } = await supabase
    .from('player_pokemon')
    .select('id, player_id, pokemon_nom, xp, daycare_placed_at, daycare_last_tick_at, daycare_lifetime_xp, daycare_capped, daycare_capped_notified')
    .eq('in_daycare', true)
    .eq('daycare_capped', false)

  if (daycareError) {
    console.error('Erreur lecture player_pokemon (pension) :', daycareError.message)
  } else if ((daycareRows || []).length > 0) {
    const pokemonNoms = [...new Set(daycareRows.map((r) => r.pokemon_nom))]
    const { data: pokemonRows } = await supabase
      .from('pokemon')
      .select('nom, image_miniature, xp_10, xp_20, xp_30, xp_40, xp_50, xp_60, xp_70, xp_80, xp_90, xp_100')
      .in('nom', pokemonNoms)
    const imageByNom = new Map((pokemonRows || []).map((p) => [p.nom, p.image_miniature]))
    const speciesMaxXpByNom = new Map((pokemonRows || []).map((p) => [p.nom, getMaxXpForSpecies(p)]))

    for (const row of daycareRows) {
      const applicable = resolveApplicable(row.pokemon_nom, xpGroupByPokemonNom, pensionConfig)
      const lastTickAt = row.daycare_last_tick_at || row.daycare_placed_at
      if (!lastTickAt) continue

      const elapsedMs = now.getTime() - new Date(lastTickAt).getTime()
      const ticks = Math.floor(elapsedMs / applicable.tickIntervalMs)
      if (ticks <= 0) continue

      // L'XP de pension ne doit jamais faire dépasser le max naturel de la
      // jauge de l'espèce (dernier palier xp_10..xp_100), en plus du plafond à
      // vie propre à la pension — les deux limites s'appliquent, la plus stricte gagne.
      const speciesMaxXp = speciesMaxXpByNom.get(row.pokemon_nom) ?? null
      const remainingCap = Math.max(0, applicable.lifetimeXpCap - row.daycare_lifetime_xp)
      const remainingToSpeciesMax = speciesMaxXp != null ? Math.max(0, speciesMaxXp - row.xp) : Infinity
      const cap = Math.min(remainingCap, remainingToSpeciesMax)
      const xpGain = Math.min(ticks * pensionConfig.tick_xp_amount, cap)
      const newLastTickAt = new Date(new Date(lastTickAt).getTime() + ticks * applicable.tickIntervalMs)
      const newDaycareLifetimeXp = row.daycare_lifetime_xp + xpGain
      const newXp = row.xp + xpGain
      const newlyCapped = newDaycareLifetimeXp >= applicable.lifetimeXpCap || (speciesMaxXp != null && newXp >= speciesMaxXp)

      await supabase.from('player_pokemon').update({
        xp: newXp,
        daycare_lifetime_xp: newDaycareLifetimeXp,
        daycare_last_tick_at: newLastTickAt.toISOString(),
        daycare_capped: newlyCapped,
        daycare_capped_notified: newlyCapped ? true : row.daycare_capped_notified,
      }).eq('id', row.id)

      if (newlyCapped && !row.daycare_capped_notified) {
        notifications.push({
          playerId: row.player_id,
          title: 'Pokémon JDR : Pension',
          body: `${row.pokemon_nom} a terminé son séjour à la Pension Pokémon, venez le récupérer`,
          icon: absoluteUrl(siteUrl, imageByNom.get(row.pokemon_nom)),
        })
      }
    }
  }

  // ── Fait éclore les paires dont la durée cible est écoulée ──────────────
  const { data: pairRows, error: pairsError } = await supabase.from('pension_pairs').select('*')
  if (pairsError) {
    console.error('Erreur lecture pension_pairs :', pairsError.message)
  } else if ((pairRows || []).length > 0) {
    const readyPairs = pairRows.filter((p) => now.getTime() - new Date(p.paired_since).getTime() >= p.target_duration_seconds * 1000)

    if (readyPairs.length > 0) {
      const pokemonIds = [...new Set(readyPairs.flatMap((p) => [p.pokemon_a_id, p.pokemon_b_id]))]
      const { data: pokemonRowsById } = await supabase
        .from('player_pokemon')
        .select('id, player_id, pokemon_nom, in_daycare')
        .in('id', pokemonIds)
      const byId = new Map((pokemonRowsById || []).map((r) => [r.id, r]))

      for (const pair of readyPairs) {
        const a = byId.get(pair.pokemon_a_id)
        const b = byId.get(pair.pokemon_b_id)

        // Défensif : un retrait concurrent (client) a pu passer entre le dernier
        // pension_recompute_pairs et ce tick — on ignore la paire plutôt que de
        // produire un œuf pour un pokémon qui n'est plus en pension. La paire
        // orpheline sera nettoyée par le prochain place/retrait de n'importe qui.
        if (!a || !b || !a.in_daycare || !b.in_daycare) continue

        const pool = resolveEggPool(pair.groupe, groupConfigByGroup, eggPoolByGroup)
        const eggSpeciesNom = pickWeightedEggSpecies(pool)

        if (eggSpeciesNom) {
          const recipientPlayerId = pair.fixed_recipient_pokemon_id != null
            ? (byId.get(pair.fixed_recipient_pokemon_id)?.player_id ?? (Math.random() < 0.5 ? a.player_id : b.player_id))
            : (Math.random() < 0.5 ? a.player_id : b.player_id)

          const { data: eggPokemonRow } = await supabase.from('pokemon').select('numero, image_miniature').eq('nom', eggSpeciesNom).maybeSingle()

          const { data: newRow, error: insertError } = await supabase
            .from('player_pokemon')
            .insert({ player_id: recipientPlayerId, pokemon_nom: eggSpeciesNom, pokemon_numero: eggPokemonRow?.numero ?? null, in_team: false, xp: 0 })
            .select()
            .single()

          if (!insertError && newRow) {
            await supabase.from('history_events').insert({
              player_id: recipientPlayerId,
              category: 'daycare',
              action_type: 'daycare_egg_received',
              payload: { pokemon_nom: eggSpeciesNom, player_pokemon_id: newRow.id, nickname: null, parent_a_nom: a.pokemon_nom, parent_b_nom: b.pokemon_nom },
            })

            notifications.push({
              playerId: recipientPlayerId,
              title: 'Pokémon JDR : Pension',
              body: `${a.pokemon_nom} et ${b.pokemon_nom} ont donné un œuf à la Pension Pokémon !`,
              icon: absoluteUrl(siteUrl, eggPokemonRow?.image_miniature),
            })
          }
        }
        // eggSpeciesNom === null (réserve du groupe vide) : pas de production,
        // mais la paire est quand même recyclée ci-dessous plutôt que de rester
        // bloquée à se déclencher en boucle à chaque passage du cron sans effet visible.

        await supabase.from('pension_pairs').delete().eq('id', pair.id)
        await supabase.from('pension_pairs').insert({
          pokemon_a_id: pair.pokemon_a_id,
          pokemon_b_id: pair.pokemon_b_id,
          groupe: pair.groupe,
          fixed_recipient_pokemon_id: pair.fixed_recipient_pokemon_id,
          paired_since: now.toISOString(),
          target_duration_seconds: rollHatchSeconds(pair.groupe, groupConfigByGroup, pensionConfig),
        })
      }
    }
  }

  if (notifications.length === 0) {
    return { statusCode: 200, body: JSON.stringify({ notifications: 0, sent: 0 }) }
  }

  // ── Envoi des push ────────────────────────────────────────────────────────
  const playerIds = [...new Set(notifications.map((n) => n.playerId))]
  const { data: subs } = await supabase.from('push_subscriptions').select('*').in('player_id', playerIds)

  const subsByPlayer = new Map()
  for (const sub of subs || []) {
    if (!subsByPlayer.has(sub.player_id)) subsByPlayer.set(sub.player_id, [])
    subsByPlayer.get(sub.player_id).push(sub)
  }

  let sent = 0
  for (const notif of notifications) {
    for (const sub of subsByPlayer.get(notif.playerId) || []) {
      try {
        await webpush.sendNotification(
          { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
          JSON.stringify({ title: notif.title, body: notif.body, icon: notif.icon, url: siteUrl || '/' })
        )
        sent += 1
      } catch (err) {
        if (err.statusCode === 404 || err.statusCode === 410) {
          await supabase.from('push_subscriptions').delete().eq('id', sub.id)
        } else {
          console.error('Erreur envoi push :', err.message)
        }
      }
    }
  }

  return { statusCode: 200, body: JSON.stringify({ notifications: notifications.length, sent }) }
}
