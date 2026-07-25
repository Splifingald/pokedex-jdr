import { useState, useEffect } from 'react'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { NumberInput } from './NumberInput'

export function AdminParametersPanel() {
  const { parameters, loading, updateParameters } = useAdminParameters()
  const [maxMoves, setMaxMoves] = useState(parameters.max_moves)
  const [maxTeamSize, setMaxTeamSize] = useState(parameters.max_team_size)
  const [carteImageUrl, setCarteImageUrl] = useState(parameters.carte_image_url)
  const [carteCouleursImageUrl, setCarteCouleursImageUrl] = useState(parameters.carte_couleurs_image_url)
  const [accueilImageUrl, setAccueilImageUrl] = useState(parameters.accueil_image_url)

  useEffect(() => {
    setMaxMoves(parameters.max_moves)
    setMaxTeamSize(parameters.max_team_size)
    setCarteImageUrl(parameters.carte_image_url)
    setCarteCouleursImageUrl(parameters.carte_couleurs_image_url)
    setAccueilImageUrl(parameters.accueil_image_url)
  }, [parameters])

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

  const saveCarte = () => {
    updateParameters({ carte_image_url: carteImageUrl, carte_couleurs_image_url: carteCouleursImageUrl })
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] max-w-sm w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">⚙️</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Paramètres</h3>
      </div>

      {loading ? (
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      ) : (
        <div className="flex flex-col gap-4">
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

          <div className="border-t-2 border-[#cfc7a8] pt-4">
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

          <div className="border-t-2 border-[#cfc7a8] pt-4">
            <label className="text-ink-muted-2 text-sm block mb-1">Lien du fond d'écran de l'accueil</label>
            <input
              type="text"
              value={accueilImageUrl}
              onChange={(e) => setAccueilImageUrl(e.target.value)}
              onBlur={() => updateParameters({ accueil_image_url: accueilImageUrl })}
              placeholder="https://… (vide = fond par défaut)"
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>

          <div className="border-t-2 border-[#cfc7a8] pt-4">
            <p className="text-ink-muted-2 text-sm mb-2">Fonctionnalités</p>
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
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
