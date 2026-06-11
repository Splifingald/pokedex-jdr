import { useState, useRef } from 'react'
import Papa from 'papaparse'
import type { CsvRow } from '../types'
import { CSV_REQUIRED_HEADERS } from '../types'

// L'import CSV passe par une Netlify Function côté serveur
// → la clé service_role Supabase n'est jamais exposée dans le bundle JS
const IMPORT_URL = '/.netlify/functions/import-pokemon'
const ADMIN_SECRET = import.meta.env.VITE_ADMIN_SECRET as string

interface Props {
  onImportSuccess: () => void
  onClose: () => void
  onLogout: () => void
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
    cache:                row['Caché']?.trim().toLowerCase() === 'oui',
    code:                 row['Code']?.trim() || null,
  }
}

export function AdminPanel({ onImportSuccess, onClose, onLogout }: Props) {
  const [status, setStatus] = useState<'idle' | 'parsing' | 'importing' | 'success' | 'error'>('idle')
  const [message, setMessage] = useState('')
  const fileRef = useRef<HTMLInputElement>(null)

  const handleFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    setStatus('parsing')
    setMessage('')

    Papa.parse<CsvRow>(file, {
      header: true,
      skipEmptyLines: true,
      complete: async (results) => {
        // Validation des en-têtes
        const fields = results.meta.fields ?? []
        const missing = CSV_REQUIRED_HEADERS.filter((h) => !fields.includes(h))
        if (missing.length > 0) {
          setStatus('error')
          setMessage(`Colonnes manquantes : ${missing.join(', ')}`)
          return
        }

        const rows = results.data.map(mapCsvRow).filter((r) => r.nom && r.numero)

        if (rows.length === 0) {
          setStatus('error')
          setMessage('Aucune ligne valide trouvée dans le CSV.')
          return
        }

        setStatus('importing')
        setMessage(`Import de ${rows.length} pokémon…`)

        try {
          const res = await fetch(IMPORT_URL, {
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
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="bg-gray-900 border-2 border-yellow-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-sm w-full p-6">
        <div className="flex items-center justify-between mb-5">
          <div className="flex items-center gap-2">
            <span className="text-2xl">🛠️</span>
            <h3 className="text-yellow-400 text-lg">Mode Admin</h3>
          </div>
          <button onClick={onClose} className="text-gray-500 hover:text-white text-xl leading-none">✕</button>
        </div>

        <div className="mb-5">
          <p className="text-gray-400 text-sm mb-3">
            Importer un fichier CSV pour mettre à jour le Pokédex.<br />
            <span className="text-yellow-600 text-xs">⚠ Remplace toute la liste existante.</span>
          </p>
          <button
            onClick={() => fileRef.current?.click()}
            disabled={status === 'importing' || status === 'parsing'}
            className="w-full py-3 bg-red-700 border-2 border-red-500 text-white rounded hover:bg-red-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed font-bold"
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

        <button
          onClick={onLogout}
          className="w-full py-2 border border-gray-700 text-gray-500 rounded hover:text-gray-300 hover:border-gray-500 transition-colors text-sm"
        >
          Quitter le mode admin
        </button>
      </div>
    </div>
  )
}
