import { useState, useEffect } from 'react'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { useCasinoConfig } from '../hooks/useCasinoConfig'
import { useDisplayAssets } from '../hooks/useDisplayAssets'
import { NumberInput } from './NumberInput'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { STAT_LABELS, STAT_ICON_URL_KEY, STAT_DESCRIPTION_KEY, type StatKey } from '../lib/statPoints'

const CUSTOM_BACKGROUND = '__custom__'

const CARD = 'bg-cream-secondary border-2 border-ink rounded-[var(--radius-pixel)] p-4 mb-4 break-inside-avoid-column'
const CARD_TITLE = 'text-[#a3841a] text-base font-bold mb-3'

export function AdminParametersPanel() {
  const { parameters, loading, updateParameters } = useAdminParameters()
  const { config: casinoConfig, updateConfig: updateCasinoConfig } = useCasinoConfig()
  const { backgrounds, mapAddOns, loading: backgroundsLoading } = useDisplayAssets()
  const [maxMoves, setMaxMoves] = useState(parameters.max_moves)
  const [maxTeamSize, setMaxTeamSize] = useState(parameters.max_team_size)
  const [statPointsBase, setStatPointsBase] = useState(parameters.stat_points_base)
  const [statMin, setStatMin] = useState(parameters.stat_min)
  const [statMax, setStatMax] = useState(parameters.stat_max)
  const [statPointsPerLevel, setStatPointsPerLevel] = useState(parameters.stat_points_per_level)
  const [carteImageUrl, setCarteImageUrl] = useState(parameters.carte_image_url)
  const [carteCouleursImageUrl, setCarteCouleursImageUrl] = useState(parameters.carte_couleurs_image_url)
  const [accueilMode, setAccueilMode] = useState<'preset' | 'custom'>('preset')
  const [accueilSelectedNom, setAccueilSelectedNom] = useState('')
  const [accueilCustomUrl, setAccueilCustomUrl] = useState('')

  useEffect(() => {
    setMaxMoves(parameters.max_moves)
    setMaxTeamSize(parameters.max_team_size)
    setStatPointsBase(parameters.stat_points_base)
    setStatMin(parameters.stat_min)
    setStatMax(parameters.stat_max)
    setStatPointsPerLevel(parameters.stat_points_per_level)
    setCarteImageUrl(parameters.carte_image_url)
    setCarteCouleursImageUrl(parameters.carte_couleurs_image_url)
  }, [parameters])

  // Fait correspondre l'URL enregistrée à un fond d'écran connu, sinon bascule en mode "Personnalisé"
  useEffect(() => {
    if (backgroundsLoading) return
    const trimmed = parameters.accueil_image_url?.trim() ?? ''
    const matched = backgrounds.find((b) => b.image_url === trimmed)
    if (backgrounds.length > 0 && (trimmed === '' || matched)) {
      setAccueilMode('preset')
      setAccueilSelectedNom(matched?.nom ?? backgrounds[0].nom)
      setAccueilCustomUrl('')
    } else {
      setAccueilMode('custom')
      setAccueilCustomUrl(trimmed)
    }
  }, [parameters, backgrounds, backgroundsLoading])

  const handleBackgroundSelect = (value: string) => {
    if (value === CUSTOM_BACKGROUND) {
      setAccueilMode('custom')
      return
    }
    const bg = backgrounds.find((b) => b.nom === value)
    if (!bg) return
    setAccueilMode('preset')
    setAccueilSelectedNom(bg.nom)
    updateParameters({ accueil_image_url: bg.image_url })
  }

  const accueilPreviewUrl = accueilMode === 'custom'
    ? accueilCustomUrl.trim()
    : backgrounds.find((b) => b.nom === accueilSelectedNom)?.image_url ?? ''

  const commitMaxMoves = (v: number) => {
    const clamped = Math.max(1, v)
    setMaxMoves(clamped)
    updateParameters({ max_moves: clamped, max_team_size: maxTeamSize })
  }

  const commitMaxTeamSize = (v: number) => {
    const clamped = Math.max(1, v)
    setMaxTeamSize(clamped)
    updateParameters({ max_moves: maxMoves, max_team_size: clamped })
  }

  const commitStatPointsBase = (v: number) => {
    const clamped = Math.max(0, v)
    setStatPointsBase(clamped)
    updateParameters({ stat_points_base: clamped })
  }

  const commitStatMin = (v: number) => {
    const clamped = Math.max(0, v)
    setStatMin(clamped)
    updateParameters({ stat_min: clamped })
  }

  const commitStatMax = (v: number) => {
    const clamped = Math.max(0, v)
    setStatMax(clamped)
    updateParameters({ stat_max: clamped })
  }

  const commitStatPointsPerLevel = (v: number) => {
    const clamped = Math.max(0, v)
    setStatPointsPerLevel(clamped)
    updateParameters({ stat_points_per_level: clamped })
  }

  const saveCarte = () => {
    updateParameters({ carte_image_url: carteImageUrl, carte_couleurs_image_url: carteCouleursImageUrl })
  }

  const addMapAddon = (url: string) => {
    updateParameters({ map_addon_image_urls: [...parameters.map_addon_image_urls, url] })
  }

  const removeMapAddon = (index: number) => {
    updateParameters({ map_addon_image_urls: parameters.map_addon_image_urls.filter((_, i) => i !== index) })
  }

  const moveMapAddon = (index: number, direction: -1 | 1) => {
    const arr = [...parameters.map_addon_image_urls]
    const target = index + direction
    if (target < 0 || target >= arr.length) return
    ;[arr[index], arr[target]] = [arr[target], arr[index]]
    updateParameters({ map_addon_image_urls: arr })
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">⚙️</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Paramètres</h3>
      </div>

      {loading ? (
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      ) : (
        <div className="columns-1 md:columns-3 gap-4">
          {/* Pokémon */}
          <div className={CARD}>
            <p className={CARD_TITLE}>Pokémon</p>
            <div className="flex flex-col gap-3">
              <div>
                <label className="text-ink-muted-2 text-sm block mb-1">Nombre max de capacités par pokémon</label>
                <NumberInput
                  min={1}
                  fallback={1}
                  value={maxMoves}
                  onCommit={commitMaxMoves}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>

              <div>
                <label className="text-ink-muted-2 text-sm block mb-1">Taille max de l'équipe</label>
                <NumberInput
                  min={1}
                  fallback={1}
                  value={maxTeamSize}
                  onCommit={commitMaxTeamSize}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
            </div>
          </div>

          {/* Joueurs */}
          <div className={CARD}>
            <p className={CARD_TITLE}>Joueurs</p>
            <div className="flex flex-col gap-3">
              <p className="text-ink-muted-2 text-xs -mt-1">Règles de stats des joueurs</p>
              <div>
                <label className="text-ink-muted-2 text-sm block mb-1">Points de stats de base (niveau 1)</label>
                <NumberInput
                  min={0}
                  fallback={0}
                  value={statPointsBase}
                  onCommit={commitStatPointsBase}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div>
                <label className="text-ink-muted-2 text-sm block mb-1">Stat minimum</label>
                <NumberInput
                  min={0}
                  fallback={0}
                  value={statMin}
                  onCommit={commitStatMin}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div>
                <label className="text-ink-muted-2 text-sm block mb-1">Stat maximum</label>
                <NumberInput
                  min={0}
                  fallback={0}
                  value={statMax}
                  onCommit={commitStatMax}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div>
                <label className="text-ink-muted-2 text-sm block mb-1">Points de stats gagnés par niveau</label>
                <NumberInput
                  min={0}
                  fallback={0}
                  value={statPointsPerLevel}
                  onCommit={commitStatPointsPerLevel}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>

              <div className="border-t-2 border-[#cfc7a8] pt-3 flex flex-col gap-3">
                <p className="text-ink-muted-2 text-xs -mt-1">Icône et description par stat</p>
                {(Object.keys(STAT_LABELS) as StatKey[]).map((key) => (
                  <div key={key} className="flex flex-col gap-1.5">
                    <span className="text-ink text-sm font-bold">{STAT_LABELS[key]}</span>
                    <input
                      type="text"
                      defaultValue={parameters[STAT_ICON_URL_KEY[key]] as string}
                      onBlur={(e) => updateParameters({ [STAT_ICON_URL_KEY[key]]: e.target.value })}
                      placeholder="Lien de l'icône"
                      className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                    />
                    <textarea
                      defaultValue={parameters[STAT_DESCRIPTION_KEY[key]] as string}
                      onBlur={(e) => updateParameters({ [STAT_DESCRIPTION_KEY[key]]: e.target.value })}
                      placeholder="Description"
                      rows={2}
                      className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none resize-y"
                    />
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Carte */}
          <div className={CARD}>
            <p className={CARD_TITLE}>Carte</p>
            <div className="flex flex-col gap-3">
              <div>
                <label className="text-ink-muted-2 text-sm block mb-1">Lien de l'image de la carte</label>
                <input
                  type="text"
                  value={carteImageUrl}
                  onChange={(e) => setCarteImageUrl(e.target.value)}
                  onBlur={saveCarte}
                  placeholder="https://…"
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>

              <div>
                <label className="text-ink-muted-2 text-sm block mb-1">Lien de l'image des couleurs</label>
                <input
                  type="text"
                  value={carteCouleursImageUrl}
                  onChange={(e) => setCarteCouleursImageUrl(e.target.value)}
                  onBlur={saveCarte}
                  placeholder="https://…"
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>

              <div className="border-t-2 border-[#cfc7a8] pt-3">
                <label className="text-ink-muted-2 text-sm block mb-1">Éléments superposés à la carte</label>
                {backgroundsLoading ? (
                  <p className="text-ink-muted-2 text-sm">Chargement…</p>
                ) : (
                  <>
                    {parameters.map_addon_image_urls.length > 0 && (
                      <div className="flex flex-col gap-2 mb-2">
                        {parameters.map_addon_image_urls.map((url, i) => {
                          const asset = mapAddOns.find((a) => a.image_url === url)
                          return (
                            <div key={`${url}-${i}`} className="flex items-center gap-2 bg-white border-2 border-ink rounded px-2 py-1.5">
                              <img src={url} alt="" className="w-10 h-10 object-contain rounded shrink-0 bg-[#00000010]" />
                              <span className="text-ink text-sm flex-1 truncate">{asset?.nom ?? url}</span>
                              <button
                                onClick={() => moveMapAddon(i, -1)}
                                disabled={i === 0}
                                title="Monter"
                                className={`w-6 h-6 shrink-0 rounded text-xs font-bold disabled:opacity-30 ${BUTTON_STYLE.gray}`}
                              >
                                ▲
                              </button>
                              <button
                                onClick={() => moveMapAddon(i, 1)}
                                disabled={i === parameters.map_addon_image_urls.length - 1}
                                title="Descendre"
                                className={`w-6 h-6 shrink-0 rounded text-xs font-bold disabled:opacity-30 ${BUTTON_STYLE.gray}`}
                              >
                                ▼
                              </button>
                              <button
                                onClick={() => removeMapAddon(i)}
                                title="Retirer"
                                className={`w-6 h-6 shrink-0 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}
                              >
                                ✕
                              </button>
                            </div>
                          )
                        })}
                      </div>
                    )}

                    <select
                      value=""
                      onChange={(e) => { if (e.target.value) addMapAddon(e.target.value) }}
                      className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                    >
                      <option value="">+ Ajouter un élément…</option>
                      {mapAddOns
                        .filter((a) => !parameters.map_addon_image_urls.includes(a.image_url))
                        .map((a) => (
                          <option key={a.id} value={a.image_url}>{a.nom}</option>
                        ))}
                    </select>

                    <p className="text-ink-muted-2 text-xs mt-1">
                      Gérés via Import CSV (colonnes « Nom » / « Type » = Map Add-On / « Image »). Le premier élément de la liste est superposé en dessous, le dernier au-dessus.
                    </p>
                  </>
                )}
              </div>
            </div>
          </div>

          {/* Fond d'écran d'accueil */}
          <div className={CARD}>
            <p className={CARD_TITLE}>Fond d'écran d'accueil</p>
            {backgroundsLoading ? (
              <p className="text-ink-muted-2 text-sm">Chargement…</p>
            ) : (
              <>
                {backgrounds.length > 0 && (
                  <select
                    value={accueilMode === 'custom' ? CUSTOM_BACKGROUND : accueilSelectedNom}
                    onChange={(e) => handleBackgroundSelect(e.target.value)}
                    className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none mb-2"
                  >
                    {backgrounds.map((bg) => (
                      <option key={bg.id} value={bg.nom}>{bg.nom}</option>
                    ))}
                    <option value={CUSTOM_BACKGROUND}>Personnalisé…</option>
                  </select>
                )}

                {(accueilMode === 'custom' || backgrounds.length === 0) && (
                  <input
                    type="text"
                    value={accueilCustomUrl}
                    onChange={(e) => setAccueilCustomUrl(e.target.value)}
                    onBlur={() => updateParameters({ accueil_image_url: accueilCustomUrl })}
                    placeholder="https://… (vide = fond par défaut)"
                    className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                  />
                )}

                {accueilPreviewUrl && (
                  <img
                    src={accueilPreviewUrl}
                    alt="Aperçu du fond d'écran"
                    className="w-full h-24 object-cover rounded border-2 border-ink mt-2"
                  />
                )}

                <p className="text-ink-muted-2 text-xs mt-1">
                  Gérés via Import CSV (colonnes « Nom » / « Type » = Fond / « Image »). Le premier de la liste est le fond par défaut.
                </p>
              </>
            )}
          </div>

          {/* Features */}
          <div className={CARD}>
            <p className={CARD_TITLE}>Features</p>
            <div className="flex flex-col gap-2">
              <label className="flex items-center gap-2 text-sm text-ink-muted">
                <input
                  type="checkbox"
                  checked={parameters.feature_pokedex_enabled}
                  onChange={(e) => updateParameters({ feature_pokedex_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                Pokédex
              </label>
              <label className="flex items-center gap-2 text-sm text-ink-muted ml-6">
                <input
                  type="checkbox"
                  checked={parameters.feature_photo_capture_enabled}
                  onChange={(e) => updateParameters({ feature_photo_capture_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                Prise de photo (ajout d'un pokémon)
              </label>
              <label className="flex items-center gap-2 text-sm text-ink-muted">
                <input
                  type="checkbox"
                  checked={parameters.feature_pokemon_enabled}
                  onChange={(e) => updateParameters({ feature_pokemon_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                Pokémon (équipe)
              </label>
              <label className="flex items-center gap-2 text-sm text-ink-muted">
                <input
                  type="checkbox"
                  checked={parameters.feature_inventory_enabled}
                  onChange={(e) => updateParameters({ feature_inventory_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                Sac (inventaire)
              </label>
              <label className="flex items-center gap-2 text-sm text-ink-muted">
                <input
                  type="checkbox"
                  checked={parameters.feature_map_enabled}
                  onChange={(e) => updateParameters({ feature_map_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                Carte
              </label>
              <label className="flex items-center gap-2 text-sm text-ink-muted">
                <input
                  type="checkbox"
                  checked={parameters.feature_gifting_enabled}
                  onChange={(e) => updateParameters({ feature_gifting_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                Cadeaux Pokémon
              </label>
              <label className="flex items-center gap-2 text-sm text-ink-muted">
                <input
                  type="checkbox"
                  checked={casinoConfig.slots_enabled}
                  onChange={(e) => updateCasinoConfig({ slots_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                Casino — {casinoConfig.slots_nom}
              </label>
              <label className="flex items-center gap-2 text-sm text-ink-muted">
                <input
                  type="checkbox"
                  checked={casinoConfig.dice_enabled}
                  onChange={(e) => updateCasinoConfig({ dice_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                Casino — {casinoConfig.dice_nom}
              </label>
              <label className="flex items-center gap-2 text-sm text-ink-muted">
                <input
                  type="checkbox"
                  checked={parameters.feature_minijeux_enabled}
                  onChange={(e) => updateParameters({ feature_minijeux_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                Pêche Magicarpe
              </label>
              <label className="flex items-center gap-2 text-sm text-ink-muted">
                <input
                  type="checkbox"
                  checked={parameters.feature_mining_enabled}
                  onChange={(e) => updateParameters({ feature_mining_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                Fouille
              </label>
              <label className="flex items-center gap-2 text-sm text-ink-muted">
                <input
                  type="checkbox"
                  checked={parameters.feature_pension_enabled}
                  onChange={(e) => updateParameters({ feature_pension_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                Pension Pokémon
              </label>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
