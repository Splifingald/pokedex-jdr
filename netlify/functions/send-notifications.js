// Netlify Scheduled Function (@hourly, voir netlify.toml) — détecte les tickets
// casino pleins et les cadeaux pokémon prêts, et envoie les notifications Web
// Push correspondantes. Tourne côté serveur : la clé service_role et les clés
// VAPID privées ne quittent jamais le serveur.
const { createClient } = require('@supabase/supabase-js')
const webpush = require('web-push')

const TICKET_CASINO_ITEM_NAME = 'Ticket Casino'
const POKEDOLLAR_ICON_PATH = '/website_icons/icon_pokedollar.png'
const GIFT_REMINDER_DELAY_MS = 72 * 60 * 60 * 1000 // relance si le cadeau n'est toujours pas réclamé 72h après le 1er push

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

  // ── Safari : nouvelle session démarrée ───────────────────────────────────
  // Diffusion à tous les joueurs (contrairement aux autres blocs, condition
  // par-joueur) — voir schema.sql::safari_sessions.notified, consommé ici une
  // seule fois par session. Délai potentiel jusqu'à ~1h (fréquence du cron),
  // accepté pour cette fonctionnalité plutôt qu'un endpoint de push instantané.
  const { data: newSafariSession, error: safariSessionError } = await supabase
    .from('safari_sessions').select('id').eq('is_active', true).eq('notified', false).maybeSingle()
  if (safariSessionError) {
    console.error('Erreur lecture safari_sessions :', safariSessionError.message)
  } else if (newSafariSession) {
    const { data: activePlayers } = await supabase.from('players').select('id').eq('is_npc', false)
    for (const p of activePlayers || []) {
      notifications.push({
        playerId: p.id,
        title: 'Pokémon JDR : Safari',
        body: 'Une nouvelle session Safari a démarré, viens tenter ta chance !',
        icon: absoluteUrl(siteUrl, '/website_icons/icon_safari_game.png'),
      })
    }
    await supabase.from('safari_sessions').update({ notified: true }).eq('id', newSafariSession.id)
  }

  // ── Chat : nouveaux messages joueurs (hors PNJ) depuis le dernier passage ──
  // Les messages PNJ envoyés depuis Admin → Chat ont leur propre push instantané
  // (netlify/functions/send-chat-notification.js) et ne repassent pas ici.
  // Diffusion à tous les joueurs (comme Safari ci-dessus), pas de ciblage par
  // destinataire — inutile de savoir qui a déjà lu quoi côté serveur.
  const { data: adminParams, error: adminParamsError } = await supabase
    .from('admin_parameters').select('chat_last_notified_at').eq('id', 1).single()
  if (adminParamsError) {
    console.error('Erreur lecture admin_parameters (chat) :', adminParamsError.message)
  } else {
    let chatQuery = supabase.from('chat_messages').select('id, created_at').eq('is_npc', false).order('created_at', { ascending: false }).limit(1)
    if (adminParams.chat_last_notified_at) chatQuery = chatQuery.gt('created_at', adminParams.chat_last_notified_at)
    const { data: newestChat, error: chatError } = await chatQuery.maybeSingle()
    if (chatError) {
      console.error('Erreur lecture chat_messages :', chatError.message)
    } else if (newestChat) {
      const { data: activePlayers } = await supabase.from('players').select('id').eq('is_npc', false)
      for (const p of activePlayers || []) {
        notifications.push({
          playerId: p.id,
          title: 'Pokémon JDR : Chat',
          body: 'De nouveaux messages sont arrivés dans le chat !',
          icon: absoluteUrl(siteUrl, POKEDOLLAR_ICON_PATH),
        })
      }
      await supabase.from('admin_parameters').update({ chat_last_notified_at: newestChat.created_at }).eq('id', 1)
    }
  }

  // ── Cadeaux pokémon prêts ────────────────────────────────────────────────
  // Prêts, mais pas encore réclamés : soit jamais notifiés, soit notifiés il y
  // a plus de 72h (relance tant que le cadeau n'est pas ouvert).
  const now = new Date()
  const { data: giftCandidates, error: giftReadyError } = await supabase
    .from('player_pokemon')
    .select('id, player_id, pokemon_nom, gift_notified, gift_notified_at')
    .eq('in_team', true)
    .not('next_gift_at', 'is', null)
    .lte('next_gift_at', now.toISOString())

  const giftReady = (giftCandidates || []).filter((pp) => {
    if (!pp.gift_notified) return true
    if (!pp.gift_notified_at) return false
    return now.getTime() - new Date(pp.gift_notified_at).getTime() >= GIFT_REMINDER_DELAY_MS
  })

  if (giftReadyError) {
    console.error('Erreur lecture player_pokemon :', giftReadyError.message)
  } else if (giftReady.length > 0) {
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
      await supabase.from('player_pokemon').update({ gift_notified: true, gift_notified_at: now.toISOString() }).eq('id', pp.id)
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
