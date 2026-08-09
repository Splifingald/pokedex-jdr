// Netlify Function invoquée à la demande (pas de cron) depuis TradePopup.handleAccept :
// notifie instantanément le PROPOSEUR d'un échange que son offre vient d'être
// acceptée (l'acceptant, lui, est déjà présent dans l'app au moment de l'action
// et voit l'animation directement — c'est le proposeur, potentiellement absent,
// qui a besoin d'être prévenu). Même mécanisme que send-chat-notification.js.
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

  let tradeId
  try {
    const body = JSON.parse(event.body || '{}')
    tradeId = body.tradeId
  } catch {
    return { statusCode: 400, body: 'Corps de requête invalide' }
  }
  if (!tradeId) {
    return { statusCode: 400, body: 'tradeId manquant' }
  }

  const siteUrl = (process.env.URL || process.env.DEPLOY_PRIME_URL || '').replace(/\/$/, '')
  webpush.setVapidDetails(
    process.env.VAPID_SUBJECT || 'mailto:contact@example.com',
    process.env.VAPID_PUBLIC_KEY,
    process.env.VAPID_PRIVATE_KEY
  )

  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)

  const { data: trade, error: tradeError } = await supabase
    .from('trades').select('proposer_id, accepted_by, status').eq('id', tradeId).single()
  if (tradeError || !trade || !trade.accepted_by || trade.status !== 'completed') {
    console.error('Échange introuvable ou non conclu :', tradeError?.message)
    return { statusCode: 404, body: 'Échange introuvable ou non conclu' }
  }

  const { data: accepter, error: accepterError } = await supabase
    .from('players').select('id, name, image_url').eq('id', trade.accepted_by).single()
  if (accepterError || !accepter) {
    console.error('Erreur lecture joueur acceptant :', accepterError?.message)
    return { statusCode: 404, body: 'Joueur acceptant introuvable' }
  }

  const { data: subs } = await supabase.from('push_subscriptions').select('*').eq('player_id', trade.proposer_id)

  const payload = JSON.stringify({
    title: 'Pokémon JDR : Échange',
    body: `${accepter.name} a accepté ton échange !`,
    icon: absoluteUrl(siteUrl, accepter.image_url),
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
        console.error("Erreur envoi push d'échange :", err.message)
      }
    }
  }

  return { statusCode: 200, body: JSON.stringify({ sent }) }
}
