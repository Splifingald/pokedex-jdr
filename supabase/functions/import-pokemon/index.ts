import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }

  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405, headers: CORS_HEADERS })
  }

  const adminSecret = Deno.env.get('ADMIN_SECRET') ?? ''
  const authHeader = req.headers.get('Authorization') ?? ''

  if (authHeader !== `Bearer ${adminSecret}`) {
    return new Response(JSON.stringify({ error: 'Non autorisé' }), {
      status: 401,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    })
  }

  let rows: Record<string, unknown>[]
  try {
    const body = await req.json()
    rows = body.rows
    if (!Array.isArray(rows) || rows.length === 0) {
      throw new Error('Aucune donnée reçue')
    }
  } catch (e) {
    return new Response(JSON.stringify({ error: 'Corps de requête invalide' }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Supprimer tous les pokémon existants (bypass RLS via service_role)
  const { error: deleteError } = await supabase.from('pokemon').delete().neq('id', 0)
  if (deleteError) {
    return new Response(JSON.stringify({ error: deleteError.message }), {
      status: 500,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    })
  }

  // Insérer par chunks de 500
  const CHUNK = 500
  for (let i = 0; i < rows.length; i += CHUNK) {
    const { error } = await supabase.from('pokemon').insert(rows.slice(i, i + CHUNK))
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
      })
    }
  }

  return new Response(JSON.stringify({ imported: rows.length }), {
    status: 200,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  })
})
