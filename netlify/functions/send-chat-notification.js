// Netlify Function invoquée à la demande (pas de cron) depuis Admin → Chat :
// envoie une notification Web Push instantanée quand un message PNJ est
// envoyé avec "Notifier les joueurs" coché. Contrairement à send-notifications.js
// (@hourly), ce endpoint est appelé de façon synchrone juste après l'insertion
// du message, pour un push immédiat plutôt qu'un délai potentiel d'une heure.
const { createClient } = require('@supabase/supabase-js')
const webpush = require('web-push')

const DEFAULT_ICON_PATH = '/website_icons/icon_pokedollar.png'

function absoluteUrl(siteUrl, path) {
  if (!path) return `${siteUrl}${DEFAULT_ICON_PATH}`
  return path.startsWith('http') ? path : `${siteUrl}${path}`
}

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' }
  }
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    console.error('Configuration serveur manquante (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)')
    return { statusCode: 500, body: 'Configuration serveur manquante' }
  }
  if (!process.env.VAPID_PUBLIC_KEY || !process.env.VAPID_PRIVATE_KEY) {
    console.error('Clés VAPID manquantes (VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY)')
    return { statusCode: 500, body: 'Clés VAPID manquantes' }
  }

  let senderPlayerId
  try {
    const body = JSON.parse(event.body || '{}')
    senderPlayerId = body.senderPlayerId
  } catch {
    return { statusCode: 400, body: 'Corps de requête invalide' }
  }
  if (!senderPlayerId) {
    return { statusCode: 400, body: 'senderPlayerId manquant' }
  }

  const siteUrl = (process.env.URL || process.env.DEPLOY_PRIME_URL || '').replace(/\/$/, '')
  webpush.setVapidDetails(
    process.env.VAPID_SUBJECT || 'mailto:contact@example.com',
    process.env.VAPID_PUBLIC_KEY,
    process.env.VAPID_PRIVATE_KEY
  )

  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)

  const { data: sender, error: senderError } = await supabase
    .from('players').select('id, name, image_url').eq('id', senderPlayerId).single()
  if (senderError || !sender) {
    console.error('Erreur lecture joueur émetteur :', senderError?.message)
    return { statusCode: 404, body: 'Joueur émetteur introuvable' }
  }

  // Diffusion à tous les joueurs non-PNJ, sauf l'émetteur lui-même.
  const { data: recipients, error: recipientsError } = await supabase
    .from('players').select('id').eq('is_npc', false).neq('id', senderPlayerId)
  if (recipientsError) {
    console.error('Erreur lecture joueurs :', recipientsError.message)
    return { statusCode: 500, body: 'Erreur lecture joueurs' }
  }

  const recipientIds = (recipients || []).map((p) => p.id)
  if (recipientIds.length === 0) {
    return { statusCode: 200, body: JSON.stringify({ sent: 0 }) }
  }

  const { data: subs } = await supabase.from('push_subscriptions').select('*').in('player_id', recipientIds)

  const payload = JSON.stringify({
    title: 'Pokémon JDR : Chat',
    body: `Vous avez reçu un message de ${sender.name}`,
    icon: absoluteUrl(siteUrl, sender.image_url),
    url: siteUrl || '/',
  })

  let sent = 0
  for (const sub of subs || []) {
    try {
      await webpush.sendNotification({ endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } }, payload)
      sent += 1
    } catch (err) {
      if (err.statusCode === 404 || err.statusCode === 410) {
        await supabase.from('push_subscriptions').delete().eq('id', sub.id)
      } else {
        console.error('Erreur envoi push chat :', err.message)
      }
    }
  }

  return { statusCode: 200, body: JSON.stringify({ sent }) }
}
