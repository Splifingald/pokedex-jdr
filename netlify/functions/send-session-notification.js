// Netlify Function invoquée à la demande (pas de cron) depuis Admin → En ligne :
// prévient tous les joueurs qu'une date de session vient d'être publiée ou
// modifiée, quand « Notifier les joueurs » est coché à l'enregistrement.
// Même forme que send-chat-notification.js — appel synchrone juste après
// l'écriture, pour un push immédiat.
const { createClient } = require('@supabase/supabase-js')
const webpush = require('web-push')

const DEFAULT_ICON_PATH = '/website_icons/icon_navbar_journal.png'

function formatWhen(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n) => String(n).padStart(2, '0')
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} à ${pad(d.getHours())}:${pad(d.getMinutes())}`
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

  const siteUrl = (process.env.URL || process.env.DEPLOY_PRIME_URL || '').replace(/\/$/, '')
  webpush.setVapidDetails(
    process.env.VAPID_SUBJECT || 'mailto:contact@example.com',
    process.env.VAPID_PUBLIC_KEY,
    process.env.VAPID_PRIVATE_KEY
  )

  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)

  // L'annonce est lue en base plutôt que reçue dans le corps de la requête :
  // le push dit forcément la même chose que la pop-up d'accueil.
  const { data: online, error: onlineError } = await supabase
    .from('online_state').select('session_at, session_message').eq('id', 1).single()
  if (onlineError || !online) {
    console.error('Erreur lecture online_state :', onlineError && onlineError.message)
    return { statusCode: 500, body: 'Erreur lecture de l\u2019annonce' }
  }
  const when = formatWhen(online.session_at)
  if (!when) {
    return { statusCode: 400, body: 'Aucune date de session enregistrée' }
  }

  const { data: recipients, error: recipientsError } = await supabase
    .from('players').select('id').eq('is_npc', false)
  if (recipientsError) {
    console.error('Erreur lecture joueurs :', recipientsError.message)
    return { statusCode: 500, body: 'Erreur lecture joueurs' }
  }

  const recipientIds = (recipients || []).map((p) => p.id)
  if (recipientIds.length === 0) {
    return { statusCode: 200, body: JSON.stringify({ sent: 0 }) }
  }

  const { data: subs } = await supabase.from('push_subscriptions').select('*').in('player_id', recipientIds)

  const message = (online.session_message || '').trim()
  const payload = JSON.stringify({
    title: 'Pokémon JDR : prochaine session',
    body: message ? `${when} — ${message}` : `Rendez-vous le ${when}`,
    icon: `${siteUrl}${DEFAULT_ICON_PATH}`,
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
        console.error('Erreur envoi push session :', err.message)
      }
    }
  }

  await supabase.from('online_state').update({ session_notified_at: new Date().toISOString() }).eq('id', 1)

  return { statusCode: 200, body: JSON.stringify({ sent }) }
}
