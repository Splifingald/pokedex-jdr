// Netlify Function — Import Lieux de la carte depuis CSV
// Tourne côté serveur Netlify : la clé service_role ne quitte jamais le serveur
const { createClient } = require('@supabase/supabase-js')

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Content-Type': 'application/json',
}

exports.handler = async (event) => {
  try {
    if (event.httpMethod === 'OPTIONS') {
      return { statusCode: 200, headers: CORS, body: 'ok' }
    }

    if (event.httpMethod !== 'POST') {
      return { statusCode: 405, headers: CORS, body: JSON.stringify({ error: 'Method Not Allowed' }) }
    }

    // Vérification du secret admin
    const authHeader = (event.headers['authorization'] ?? '')
    if (authHeader !== `Bearer ${process.env.ADMIN_SECRET}`) {
      return { statusCode: 401, headers: CORS, body: JSON.stringify({ error: 'Non autorisé' }) }
    }

    let rows
    try {
      const body = JSON.parse(event.body ?? '{}')
      rows = body.rows
      if (!Array.isArray(rows) || rows.length === 0) throw new Error('Aucune donnée')
    } catch {
      return { statusCode: 400, headers: CORS, body: JSON.stringify({ error: 'Corps de requête invalide' }) }
    }

    if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
      return { statusCode: 500, headers: CORS, body: JSON.stringify({ error: 'Configuration serveur manquante (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)' }) }
    }

    const supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY // ← jamais exposé au client
    )

    // Supprimer tous les lieux existants
    const { error: deleteError } = await supabase.from('carte_locations').delete().neq('id', 0)
    if (deleteError) {
      return { statusCode: 500, headers: CORS, body: JSON.stringify({ error: deleteError.message }) }
    }

    // Insérer par chunks de 500
    const CHUNK = 500
    for (let i = 0; i < rows.length; i += CHUNK) {
      const { error } = await supabase.from('carte_locations').insert(rows.slice(i, i + CHUNK))
      if (error) {
        return { statusCode: 500, headers: CORS, body: JSON.stringify({ error: error.message }) }
      }
    }

    return { statusCode: 200, headers: CORS, body: JSON.stringify({ imported: rows.length }) }
  } catch (err) {
    return { statusCode: 500, headers: CORS, body: JSON.stringify({ error: err instanceof Error ? err.message : 'Erreur inattendue' }) }
  }
}
