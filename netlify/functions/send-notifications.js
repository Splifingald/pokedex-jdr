// Netlify Scheduled Function (@hourly, voir netlify.toml) — détecte les tickets
// casino pleins et les cadeaux pokémon prêts, et envoie les notifications Web
// Push correspondantes. Tourne côté serveur : la clé service_role et les clés
// VAPID privées ne quittent jamais le serveur.
const { createClient } = require('@supabase/supabase-js')
const webpush = require('web-push')

const TICKET_CASINO_ITEM_NAME = 'Ticket Casino'
const POKEDOLLAR_ICON_PATH = '/website_icons/icon_pokedollar.png'

function absoluteUrl(siteUrl, path) {
  if (!path) return `${siteUrl}${POKEDOLLAR_ICON_PATH}`
  return path.startsWith('http') ? path : `${siteUrl}${path}`
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

  // notifications à envoyer : { playerId, title, body, icon }
  const notifications = []

  // ── Casino : tickets pleins ──────────────────────────────────────────────
  const { data: casinoConfig, error: casinoConfigError } = await supabase
    .from('casino_config').select('*').eq('id', 1).single()
  if (casinoConfigError) {
    console.error('Erreur lecture casino_config :', casinoConfigError.message)
  } else if (casinoConfig.ticket_full_notify_enabled) {
    const [{ data: states }, { data: ticketItems }] = await Promise.all([
      supabase.from('casino_player_state').select('*'),
      supabase.from('player_items').select('player_id, quantity').eq('item_nom', TICKET_CASINO_ITEM_NAME),
    ])

    const ticketByPlayer = new Map((ticketItems || []).map((r) => [r.player_id, r.quantity]))

    for (const state of states || []) {
      const ticketCount = ticketByPlayer.get(state.player_id) ?? 0
      const isFull = ticketCount >= casinoConfig.ticket_max

      if (isFull && !state.ticket_full_notified) {
        notifications.push({
          playerId: state.player_id,
          title: 'Pokémon JDR : Casino',
          body: 'Tes tickets de casinos sont pleins, viens vite gagner un max de Pokédollars!',
          icon: absoluteUrl(siteUrl, POKEDOLLAR_ICON_PATH),
        })
        await supabase.from('casino_player_state').update({ ticket_full_notified: true }).eq('player_id', state.player_id)
      } else if (!isFull && state.ticket_full_notified) {
        // Réarme le flag dès qu'un ticket est dépensé, pour re-notifier au prochain plafond
        await supabase.from('casino_player_state').update({ ticket_full_notified: false }).eq('player_id', state.player_id)
      }
    }
  }

  // ── Cadeaux pokémon prêts ────────────────────────────────────────────────
  const { data: giftReady, error: giftReadyError } = await supabase
    .from('player_pokemon')
    .select('id, player_id, pokemon_nom')
    .eq('in_team', true)
    .eq('gift_notified', false)
    .not('next_gift_at', 'is', null)
    .lte('next_gift_at', new Date().toISOString())

  if (giftReadyError) {
    console.error('Erreur lecture player_pokemon :', giftReadyError.message)
  } else if (giftReady && giftReady.length > 0) {
    const { data: npcPlayers } = await supabase.from('players').select('id').eq('is_npc', true)
    const npcPlayerIds = new Set((npcPlayers || []).map((p) => p.id))

    const pokemonNoms = [...new Set(giftReady.map((pp) => pp.pokemon_nom))]
    const { data: pokemonRows } = await supabase.from('pokemon').select('nom, image_miniature').in('nom', pokemonNoms)
    const imageByNom = new Map((pokemonRows || []).map((p) => [p.nom, p.image_miniature]))

    for (const pp of giftReady) {
      if (npcPlayerIds.has(pp.player_id)) continue
      const icon = absoluteUrl(siteUrl, imageByNom.get(pp.pokemon_nom))
      notifications.push({
        playerId: pp.player_id,
        title: 'Pokémon JDR : Cadeau',
        body: `${pp.pokemon_nom} à une surprise pour toi, viens la découvrir`,
        icon,
      })
      await supabase.from('player_pokemon').update({ gift_notified: true }).eq('id', pp.id)
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
          JSON.stringify({
            title: notif.title,
            body: notif.body,
            icon: notif.icon,
            url: siteUrl || '/',
          })
        )
        sent += 1
      } catch (err) {
        if (err.statusCode === 404 || err.statusCode === 410) {
          // Abonnement expiré/révoqué côté navigateur — on le retire
          await supabase.from('push_subscriptions').delete().eq('id', sub.id)
        } else {
          console.error('Erreur envoi push :', err.message)
        }
      }
    }
  }

  return { statusCode: 200, body: JSON.stringify({ notifications: notifications.length, sent }) }
}
