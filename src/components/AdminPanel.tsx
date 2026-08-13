import { useState, useRef } from 'react'
import Papa from 'papaparse'
import type { CsvRow, AttackCsvRow, CarteCsvRow, ItemCsvRow, EncounterCsvRow, DisplayAssetCsvRow, PokemonEvolutionCsvRow, PokemonEggGroupCsvRow } from '../types'
import { CSV_REQUIRED_HEADERS, ATTACK_CSV_REQUIRED_HEADERS, CARTE_CSV_REQUIRED_HEADERS, ITEM_CSV_REQUIRED_HEADERS, ENCOUNTER_CSV_REQUIRED_HEADERS, DISPLAY_ASSET_CSV_REQUIRED_HEADERS, POKEMON_EVOLUTION_CSV_REQUIRED_HEADERS, POKEMON_EGG_GROUP_CSV_REQUIRED_HEADERS } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { parseStatusEffectCsvLabel } from '../lib/autoBattle'
import { parseBattleAnimationCsvLabel } from '../lib/battleAnimations'

// L'import CSV passe par une Netlify Function côté serveur
// → la clé service_role Supabase n'est jamais exposée dans le bundle JS
const IMPORT_POKEMON_URL = '/.netlify/functions/import-pokemon'
const IMPORT_ATTACKS_URL = '/.netlify/functions/import-attacks'
const IMPORT_CARTE_URL = '/.netlify/functions/import-carte'
const IMPORT_ITEMS_URL = '/.netlify/functions/import-items'
const IMPORT_ENCOUNTERS_URL = '/.netlify/functions/import-encounters'
const IMPORT_DISPLAY_ASSETS_URL = '/.netlify/functions/import-display-assets'
const IMPORT_POKEMON_EVOLUTIONS_URL = '/.netlify/functions/import-pokemon-evolutions'
const IMPORT_POKEMON_EGG_GROUPS_URL = '/.netlify/functions/import-pokemon-egg-groups'
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

// "Inflige dégâts" (vrai/faux, insensible à la casse) — colonne optionnelle :
// absente ou vide = true (comportement historique, la quasi-totalité des
// capacités sont offensives), seule une valeur reconnue comme fausse
// (faux/false) désactive explicitement les dégâts.
function parseDealsDamageCsv(value: string | undefined): boolean {
  const normalized = value?.trim().toLowerCase()
  return normalized !== 'faux' && normalized !== 'false'
}

function mapAttackCsvRow(row: AttackCsvRow) {
  const statusEffect = parseStatusEffectCsvLabel(row['Mini-game status'])
  return {
    nom:           row['Attaque']?.trim() ?? '',
    type:          row['Type']?.trim() ?? '',
    degats_base:   row['Dégâts de base']?.trim() ? parseInt(row['Dégâts de base']) : null,
    degats_de:     row['Dégâts dé']?.trim() ? parseInt(row['Dégâts dé']) : null,
    cible:         row['Cible']?.trim() || null,
    distance:      row['Distance']?.trim() ? parseInt(row['Distance']) : null,
    // Une case "-" (ou tout autre texte non numérique) vaut précision ABSOLUE,
    // au même titre qu'une case vide : la capacité ne peut jamais rater (voir
    // isAbsolutePrecision). Sans le test Number.isFinite, parseInt('-') donne
    // NaN — sérialisé en null par hasard, mais c'était fragile et illisible.
    precision:     Number.isFinite(parseInt(row['Précision'] ?? '')) ? parseInt(row['Précision']) : null,
    degats_moyens: row['Dégâts moyens']?.trim() ? parseFloat(row['Dégâts moyens'].replace(',', '.')) : null,
    effet:         row['Effet']?.trim() || null,
    // Statut "mini-jeu" (Combat Auto) — voir parseStatusEffectCsvLabel.
    // status_chance ignoré si aucun statut valide n'est reconnu.
    status_effect: statusEffect,
    status_chance: statusEffect && row['Status probability']?.trim() ? parseInt(row['Status probability']) : null,
    deals_damage: parseDealsDamageCsv(row['Inflige dégâts']),
    // Animations de combat (purement visuel, voir battleAnimations.ts) —
    // colonnes optionnelles : vide ou libellé inconnu = NULL, la capacité
    // retombe alors sur son animation par défaut.
    animation: parseBattleAnimationCsvLabel(row['Animation']),
    animation_2: parseBattleAnimationCsvLabel(row['Animation 2']),
  }
}

function mapCarteCsvRow(row: CarteCsvRow) {
  return {
    couleur:           row['Couleur']?.trim().toLowerCase().replace(/^#/, '') ?? '',
    titre:             row['Titre']?.trim() ?? '',
    description:       row['Description']?.trim() || null,
    admin_description: row['Admin Description']?.trim() || null,
    type:              row['Type']?.trim() || null,
    image_url:         row['Image']?.trim() || null,
  }
}

function mapItemCsvRow(row: ItemCsvRow) {
  return {
    nom:         row['Nom']?.trim() ?? '',
    type:        row['Type']?.trim() ?? '',
    rarete:      row['Rareté']?.trim() || null,
    achat:       parseInt((row['Achat'] ?? '').replace(/[^\d-]/g, '')) || 0,
    vente:       parseInt((row['Vente'] ?? '').replace(/[^\d-]/g, '')) || 0,
    description: row['Description']?.trim() || null,
    image_url:   row['Image']?.trim() || null,
  }
}

function mapEncounterCsvRow(row: EncounterCsvRow) {
  return {
    lieu:        row['Lieu']?.trim() ?? '',
    pokemon_nom: row['Pokémon']?.trim() ?? '',
    de:          row['Dé']?.trim() ? parseInt(row['Dé']) : null,
    commentaire: row['Commentaire']?.trim() || null,
  }
}

function mapDisplayAssetCsvRow(row: DisplayAssetCsvRow) {
  return {
    nom:       row['Nom']?.trim() ?? '',
    type:      row['Type']?.trim() ?? '',
    image_url: row['Image']?.trim() ?? '',
    reference: row['Reference']?.trim() ?? '',
  }
}

function mapPokemonEvolutionCsvRow(row: PokemonEvolutionCsvRow) {
  return {
    pokemon_nom:        row['Nom']?.trim() ?? '',
    evolution_nom:       row['Évolution']?.trim() ?? '',
    condition_item_nom:  row['Condition']?.trim() || null,
  }
}

// Une ligne CSV (1 espèce, jusqu'à 3 groupes) devient 0 à 3 lignes en base —
// une par colonne Groupe non vide.
function mapPokemonEggGroupCsvRow(row: PokemonEggGroupCsvRow) {
  const pokemon_nom = row['Pokémon']?.trim() ?? ''
  return (['Groupe 1', 'Groupe 2', 'Groupe 3'] as const)
    .map((k) => row[k]?.trim())
    .filter((groupe): groupe is string => !!groupe)
    .map((groupe) => ({ pokemon_nom, groupe }))
}

interface ImportResult {
  name: string
  ok: boolean
  message: string
}

async function postRows(url: string, rows: unknown[]): Promise<number> {
  const res = await fetch(url, {
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
  return data.imported
}

function parseCsv(file: File): Promise<Papa.ParseResult<Record<string, string>>> {
  return new Promise((resolve, reject) => {
    Papa.parse<Record<string, string>>(file, {
      header: true,
      skipEmptyLines: true,
      // Certains exports Excel préfixent le premier en-tête d'un BOM UTF-8 (﻿),
      // ce qui casse la comparaison exacte des noms de colonnes plus bas
      transformHeader: (h) => h.replace(/^﻿/, '').trim(),
      complete: resolve,
      error: reject,
    })
  })
}

// Détecte le type d'un CSV depuis ses en-têtes, valide, transforme les lignes et les envoie
// à la Netlify Function correspondante. Le type de fichier est indépendant d'un fichier à
// l'autre : plusieurs CSV de types différents peuvent être sélectionnés en une seule fois.
async function importOneFile(file: File): Promise<ImportResult> {
  const name = file.name
  const fail = (message: string): ImportResult => ({ name, ok: false, message })

  let results: Papa.ParseResult<Record<string, string>>
  try {
    results = await parseCsv(file)
  } catch (err) {
    return fail(`Erreur de parsing : ${err instanceof Error ? err.message : 'inconnue'}`)
  }

  const fields = results.meta.fields ?? []
  // Une colonne "Couleur" n'existe que dans le CSV de la carte
  const isCarteCsv = fields.includes('Couleur')
  // Une colonne "Attaque" (sans suffixe numérique) n'existe que dans le CSV d'attaques
  const isAttacksCsv = fields.includes('Attaque')
  // Une colonne "Achat" n'existe que dans le CSV d'objets
  const isItemsCsv = fields.includes('Achat')
  // Une colonne "Lieu" n'existe que dans le CSV de rencontres
  const isEncountersCsv = fields.includes('Lieu')
  // Une colonne "Évolution" n'existe que dans le CSV d'évolutions
  const isEvolutionsCsv = fields.includes('Évolution')
  // Une colonne "Groupe 1" n'existe que dans le CSV de groupes d'œufs (Pension Pokémon)
  const isEggGroupsCsv = fields.includes('Groupe 1')
  // Le CSV du mode Affichage contient ces 4 colonnes (Nom + Type + Image + Reference) —
  // couvre aussi les fonds d'écran (Type = "Background") et les calques superposés à la
  // Carte (Type = "Map Add-On"). Reference permet à plusieurs images de partager le même
  // PNJ/lieu (Nom reste unique par image).
  const isDisplayAssetsCsv = fields.length === 4 && fields.includes('Nom') && fields.includes('Type') && fields.includes('Image') && fields.includes('Reference')

  if (isDisplayAssetsCsv) {
    const missing = DISPLAY_ASSET_CSV_REQUIRED_HEADERS.filter((h) => !fields.includes(h))
    if (missing.length > 0) return fail(`Colonnes manquantes : ${missing.join(', ')}`)

    const rows = (results.data as unknown as DisplayAssetCsvRow[]).map(mapDisplayAssetCsvRow).filter((r) => r.nom)
    if (rows.length === 0) return fail('Aucune ligne valide trouvée dans le CSV.')

    try {
      const imported = await postRows(IMPORT_DISPLAY_ASSETS_URL, rows)
      return { name, ok: true, message: `✅ ${imported} images d'affichage importées avec succès !` }
    } catch (err) {
      return fail(err instanceof Error ? err.message : 'Erreur inconnue')
    }
  }

  if (isCarteCsv) {
    const missing = CARTE_CSV_REQUIRED_HEADERS.filter((h) => !fields.includes(h))
    if (missing.length > 0) return fail(`Colonnes manquantes : ${missing.join(', ')}`)

    const rows = (results.data as unknown as CarteCsvRow[]).map(mapCarteCsvRow).filter((r) => r.couleur)
    if (rows.length === 0) return fail('Aucune ligne valide trouvée dans le CSV.')

    try {
      const imported = await postRows(IMPORT_CARTE_URL, rows)
      return { name, ok: true, message: `✅ ${imported} lieux importés avec succès !` }
    } catch (err) {
      return fail(err instanceof Error ? err.message : 'Erreur inconnue')
    }
  }

  if (isAttacksCsv) {
    const missing = ATTACK_CSV_REQUIRED_HEADERS.filter((h) => !fields.includes(h))
    if (missing.length > 0) return fail(`Colonnes manquantes : ${missing.join(', ')}`)

    const rows = (results.data as unknown as AttackCsvRow[]).map(mapAttackCsvRow).filter((r) => r.nom)
    if (rows.length === 0) return fail('Aucune ligne valide trouvée dans le CSV.')

    try {
      const imported = await postRows(IMPORT_ATTACKS_URL, rows)
      return { name, ok: true, message: `✅ ${imported} attaques importées avec succès !` }
    } catch (err) {
      return fail(err instanceof Error ? err.message : 'Erreur inconnue')
    }
  }

  if (isItemsCsv) {
    const missing = ITEM_CSV_REQUIRED_HEADERS.filter((h) => !fields.includes(h))
    if (missing.length > 0) return fail(`Colonnes manquantes : ${missing.join(', ')}`)

    const rows = (results.data as unknown as ItemCsvRow[]).map(mapItemCsvRow).filter((r) => r.nom)
    if (rows.length === 0) return fail('Aucune ligne valide trouvée dans le CSV.')

    try {
      const imported = await postRows(IMPORT_ITEMS_URL, rows)
      return { name, ok: true, message: `✅ ${imported} objets importés avec succès !` }
    } catch (err) {
      return fail(err instanceof Error ? err.message : 'Erreur inconnue')
    }
  }

  if (isEncountersCsv) {
    const missing = ENCOUNTER_CSV_REQUIRED_HEADERS.filter((h) => !fields.includes(h))
    if (missing.length > 0) return fail(`Colonnes manquantes : ${missing.join(', ')}`)

    const rows = (results.data as unknown as EncounterCsvRow[]).map(mapEncounterCsvRow).filter((r) => r.lieu && r.pokemon_nom)
    if (rows.length === 0) return fail('Aucune ligne valide trouvée dans le CSV.')

    try {
      const imported = await postRows(IMPORT_ENCOUNTERS_URL, rows)
      return { name, ok: true, message: `✅ ${imported} rencontres importées avec succès !` }
    } catch (err) {
      return fail(err instanceof Error ? err.message : 'Erreur inconnue')
    }
  }

  if (isEvolutionsCsv) {
    const missing = POKEMON_EVOLUTION_CSV_REQUIRED_HEADERS.filter((h) => !fields.includes(h))
    if (missing.length > 0) return fail(`Colonnes manquantes : ${missing.join(', ')}`)

    const rows = (results.data as unknown as PokemonEvolutionCsvRow[]).map(mapPokemonEvolutionCsvRow).filter((r) => r.pokemon_nom && r.evolution_nom)
    if (rows.length === 0) return fail('Aucune ligne valide trouvée dans le CSV.')

    try {
      const imported = await postRows(IMPORT_POKEMON_EVOLUTIONS_URL, rows)
      return { name, ok: true, message: `✅ ${imported} évolutions importées avec succès !` }
    } catch (err) {
      return fail(err instanceof Error ? err.message : 'Erreur inconnue')
    }
  }

  if (isEggGroupsCsv) {
    const missing = POKEMON_EGG_GROUP_CSV_REQUIRED_HEADERS.filter((h) => !fields.includes(h))
    if (missing.length > 0) return fail(`Colonnes manquantes : ${missing.join(', ')}`)

    const rows = (results.data as unknown as PokemonEggGroupCsvRow[]).flatMap(mapPokemonEggGroupCsvRow).filter((r) => r.pokemon_nom && r.groupe)
    if (rows.length === 0) return fail('Aucune ligne valide trouvée dans le CSV.')

    try {
      const imported = await postRows(IMPORT_POKEMON_EGG_GROUPS_URL, rows)
      return { name, ok: true, message: `✅ ${imported} groupes d'œufs importés avec succès !` }
    } catch (err) {
      return fail(err instanceof Error ? err.message : 'Erreur inconnue')
    }
  }

  // Validation des en-têtes (CSV pokémon)
  const missing = CSV_REQUIRED_HEADERS.filter((h) => !fields.includes(h))
  if (missing.length > 0) return fail(`Colonnes manquantes : ${missing.join(', ')}`)

  const rows = (results.data as unknown as CsvRow[]).map(mapCsvRow).filter((r) => r.nom && r.numero)
  if (rows.length === 0) return fail('Aucune ligne valide trouvée dans le CSV.')

  try {
    const imported = await postRows(IMPORT_POKEMON_URL, rows)
    return { name, ok: true, message: `✅ ${imported} pokémon importés avec succès !` }
  } catch (err) {
    return fail(err instanceof Error ? err.message : 'Erreur inconnue')
  }
}

export function AdminPanel({ onImportSuccess }: Props) {
  const [importing, setImporting] = useState(false)
  const [results, setResults] = useState<ImportResult[]>([])
  const fileRef = useRef<HTMLInputElement>(null)

  const handleFiles = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files ?? [])
    e.target.value = ''
    if (files.length === 0) return

    setImporting(true)
    setResults([])

    const collected: ImportResult[] = []
    // Import séquentiel : chaque fichier remplace toute une table côté serveur, mieux vaut
    // ne pas paralléliser au cas où deux fichiers sélectionnés toucheraient la même table.
    for (const file of files) {
      collected.push(await importOneFile(file))
      setResults([...collected])
    }

    setImporting(false)
    if (collected.some((r) => r.ok)) onImportSuccess()
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <div className="flex items-center justify-between mb-5">
          <div className="flex items-center gap-2">
            <span className="text-2xl">🛠️</span>
            <h3 className="text-[#a3841a] text-lg font-bold">Import CSV</h3>
          </div>
        </div>

        <div className="mb-5">
          <p className="text-ink-muted-2 text-sm mb-3">
            Importer un ou plusieurs CSV Pokémon, Capacités, Carte, Objets, Rencontres, Évolutions, Groupes d'œufs (Pension) ou Fonds d'écran (type détecté automatiquement pour chaque fichier).<br />
            <span className="text-[#a3841a] text-xs">⚠ Remplace toute la liste existante correspondante.</span>
          </p>
          <button
            onClick={() => fileRef.current?.click()}
            disabled={importing}
            className={`w-full py-3 rounded disabled:opacity-50 disabled:cursor-not-allowed font-bold ${BUTTON_STYLE.yellow}`}
          >
            {importing ? '⏳ En cours…' : '📂 Importer CSV'}
          </button>
          <input ref={fileRef} type="file" accept=".csv" multiple onChange={handleFiles} className="hidden" />
        </div>

        {results.length > 0 && (
          <div className="flex flex-col gap-2 mb-4">
            {results.map((r, i) => (
              <div
                key={`${r.name}-${i}`}
                className={`text-sm p-3 rounded border-2 ${r.ok ? 'bg-green-100 text-green-900 border-green-700' : 'bg-red-100 text-red-900 border-red-700'}`}
              >
                <span className="font-bold">{r.name}</span> — {r.message}
              </div>
            ))}
          </div>
        )}
    </div>
  )
}
