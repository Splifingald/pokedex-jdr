import { useState, useRef } from 'react'
import Papa from 'papaparse'
import type { CsvRow, AttackCsvRow } from '../types'
import { CSV_REQUIRED_HEADERS, ATTACK_CSV_REQUIRED_HEADERS } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'

// L'import CSV passe par une Netlify Function côté serveur
// → la clé service_role Supabase n'est jamais exposée dans le bundle JS
const IMPORT_POKEMON_URL = '/.netlify/functions/import-pokemon'
const IMPORT_ATTACKS_URL = '/.netlify/functions/import-attacks'
const ADMIN_SECRET = import.meta.env.VITE_ADMIN_SECRET as string

interface Props {
  onImportSuccess: () => void
}

function mapCsvRow(row: CsvRow) {
  return {
    numero:               row['Numéro']?.trim() ?? '',
    nom:                  row['Nom']?.trim() ?? '',
    type:                 row['Type']?.trim() ?? '',
    degats_base:          parseInt(row['Dégâts de base']) || 0,
    pv_base:              parseInt(row['PV de base']) || 0,
    super_efficace_1:     row['Super Efficace 1']?.trim() || null,
    super_efficace_2:     row['Super Efficace 2']?.trim() || null,
    super_efficace_3:     row['Super Efficace 3']?.trim() || null,
    super_efficace_4:     row['Super Efficace 4']?.trim() || null,
    distance_deplacement: parseInt(row['Distance de déplacement en combat']) || 0,
    image_miniature:      row['Image miniature']?.trim() || '',
    image_illustree:      row['Image illustrée']?.trim() || '',
    nom_talent:           row['Nom du talent']?.trim() || null,
    description_talent:   row['Description du talent']?.trim() || null,
    chances_capture:      row['Chances de capture']?.trim() || null,
    localisation_1:       row['Localisation 1']?.trim() || null,
    localisation_2:       row['Localisation 2']?.trim() || null,
    localisation_3:       row['Localisation 3']?.trim() || null,
    cache:                ['oui', 'true', 'vrai', '1', 'yes'].includes(row['Caché']?.trim().toLowerCase() ?? ''),
    code:                 row['Code']?.trim() || null,
    audio_url:            row['Audio']?.trim() || null,
    transport:            row['Transport']?.trim() || null,
    transport_value:      row['Transport value']?.trim() ? parseInt(row['Transport value']) : null,
    attaque_1:            row['Attaque 1']?.trim() || null,
    attaque_2:            row['Attaque 2']?.trim() || null,
    attaque_3:            row['Attaque 3']?.trim() || null,
    attaque_4:            row['Attaque 4']?.trim() || null,
    attaque_5:            row['Attaque 5']?.trim() || null,
    attaque_6:            row['Attaque 6']?.trim() || null,
    attaque_7:            row['Attaque 7']?.trim() || null,
    attaque_8:            row['Attaque 8']?.trim() || null,
    attaque_9:            row['Attaque 9']?.trim() || null,
    attaque_10:           row['Attaque 10']?.trim() || null,
    xp_10:                row['10 XP']?.trim() || null,
    xp_20:                row['20 XP']?.trim() || null,
    xp_30:                row['30 XP']?.trim() || null,
    xp_40:                row['40 XP']?.trim() || null,
    xp_50:                row['50 XP']?.trim() || null,
    xp_60:                row['60 XP']?.trim() || null,
    xp_70:                row['70 XP']?.trim() || null,
    xp_80:                row['80 XP']?.trim() || null,
    xp_90:                row['90 XP']?.trim() || null,
    xp_100:               row['100 XP']?.trim() || null,
  }
}

function mapAttackCsvRow(row: AttackCsvRow) {
  return {
    nom:           row['Attaque']?.trim() ?? '',
    type:          row['Type']?.trim() ?? '',
    degats_base:   row['Dégâts de base']?.trim() ? parseInt(row['Dégâts de base']) : null,
    degats_de:     row['Dégâts dé']?.trim() ? parseInt(row['Dégâts dé']) : null,
    cible:         row['Cible']?.trim() || null,
    distance:      row['Distance']?.trim() ? parseInt(row['Distance']) : null,
    precision:     row['Précision']?.trim() ? parseInt(row['Précision']) : null,
    degats_moyens: row['Dégâts moyens']?.trim() ? parseFloat(row['Dégâts moyens'].replace(',', '.')) : null,
    effet:         row['Effet']?.trim() || null,
  }
}

export function AdminPanel({ onImportSuccess }: Props) {
  const [status, setStatus] = useState<'idle' | 'parsing' | 'importing' | 'success' | 'error'>('idle')
  const [message, setMessage] = useState('')
  const fileRef = useRef<HTMLInputElement>(null)

  const handleFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    setStatus('parsing')
    setMessage('')

    Papa.parse<Record<string, string>>(file, {
      header: true,
      skipEmptyLines: true,
      // Certains exports Excel préfixent le premier en-tête d'un BOM UTF-8 (﻿),
      // ce qui casse la comparaison exacte des noms de colonnes plus bas
      transformHeader: (h) => h.replace(/^﻿/, '').trim(),
      complete: async (results) => {
        const fields = results.meta.fields ?? []
        // Une colonne "Attaque" (sans suffixe numérique) n'existe que dans le CSV d'attaques
        const isAttacksCsv = fields.includes('Attaque')

        if (isAttacksCsv) {
          const missing = ATTACK_CSV_REQUIRED_HEADERS.filter((h) => !fields.includes(h))
          if (missing.length > 0) {
            setStatus('error')
            setMessage(`Colonnes manquantes : ${missing.join(', ')}`)
            return
          }

          const rows = (results.data as unknown as AttackCsvRow[])
            .map(mapAttackCsvRow)
            .filter((r) => r.nom)

          if (rows.length === 0) {
            setStatus('error')
            setMessage('Aucune ligne valide trouvée dans le CSV.')
            return
          }

          setStatus('importing')
          setMessage(`Import de ${rows.length} attaques…`)

          try {
            const res = await fetch(IMPORT_ATTACKS_URL, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${ADMIN_SECRET}`,
              },
              body: JSON.stringify({ rows }),
            })

            const data = await res.json()

            if (!res.ok) {
              throw new Error(data.error ?? `Erreur serveur ${res.status}`)
            }

            setStatus('success')
            setMessage(`✅ ${data.imported} attaques importées avec succès !`)
            onImportSuccess()
          } catch (err) {
            setStatus('error')
            setMessage(err instanceof Error ? err.message : 'Erreur inconnue')
          }
          return
        }

        // Validation des en-têtes (CSV pokémon)
        const missing = CSV_REQUIRED_HEADERS.filter((h) => !fields.includes(h))
        if (missing.length > 0) {
          setStatus('error')
          setMessage(`Colonnes manquantes : ${missing.join(', ')}`)
          return
        }

        const rows = (results.data as unknown as CsvRow[])
          .map(mapCsvRow)
          .filter((r) => r.nom && r.numero)

        if (rows.length === 0) {
          setStatus('error')
          setMessage('Aucune ligne valide trouvée dans le CSV.')
          return
        }

        setStatus('importing')
        setMessage(`Import de ${rows.length} pokémon…`)

        try {
          const res = await fetch(IMPORT_POKEMON_URL, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${ADMIN_SECRET}`,
            },
            body: JSON.stringify({ rows }),
          })

          const data = await res.json()

          if (!res.ok) {
            throw new Error(data.error ?? `Erreur serveur ${res.status}`)
          }

          setStatus('success')
          setMessage(`✅ ${data.imported} pokémon importés avec succès !`)
          onImportSuccess()
        } catch (err) {
          setStatus('error')
          setMessage(err instanceof Error ? err.message : 'Erreur inconnue')
        }
      },
      error: (err) => {
        setStatus('error')
        setMessage(`Erreur de parsing : ${err.message}`)
      },
    })

    e.target.value = ''
  }

  return (
    <div className="bg-gray-900 border-2 border-yellow-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-sm w-full p-6">
        <div className="flex items-center justify-between mb-5">
          <div className="flex items-center gap-2">
            <span className="text-2xl">🛠️</span>
            <h3 className="text-yellow-400 text-lg">Import CSV</h3>
          </div>
        </div>

        <div className="mb-5">
          <p className="text-gray-400 text-sm mb-3">
            Importer un CSV Pokémon ou un CSV Capacités (détecté automatiquement).<br />
            <span className="text-yellow-600 text-xs">⚠ Remplace toute la liste existante correspondante.</span>
          </p>
          <button
            onClick={() => fileRef.current?.click()}
            disabled={status === 'importing' || status === 'parsing'}
            className={`w-full py-3 rounded disabled:opacity-50 disabled:cursor-not-allowed font-bold ${BUTTON_STYLE.yellow}`}
          >
            {status === 'parsing' || status === 'importing' ? '⏳ En cours…' : '📂 Importer CSV'}
          </button>
          <input ref={fileRef} type="file" accept=".csv" onChange={handleFile} className="hidden" />
        </div>

        {message && (
          <div className={`text-sm p-3 rounded mb-4 ${
            status === 'success' ? 'bg-green-900/50 text-green-300 border border-green-700' :
            status === 'error'   ? 'bg-red-900/50 text-red-300 border border-red-700' :
            'bg-gray-800 text-gray-300'
          }`}>
            {message}
          </div>
        )}
    </div>
  )
}
