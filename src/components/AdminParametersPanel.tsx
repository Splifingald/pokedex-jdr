import { useState, useEffect } from 'react'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { NumberInput } from './NumberInput'

export function AdminParametersPanel() {
  const { parameters, loading, updateParameters } = useAdminParameters()
  const [maxMoves, setMaxMoves] = useState(parameters.max_moves)
  const [maxTeamSize, setMaxTeamSize] = useState(parameters.max_team_size)
  const [carteImageUrl, setCarteImageUrl] = useState(parameters.carte_image_url)
  const [carteCouleursImageUrl, setCarteCouleursImageUrl] = useState(parameters.carte_couleurs_image_url)

  useEffect(() => {
    setMaxMoves(parameters.max_moves)
    setMaxTeamSize(parameters.max_team_size)
    setCarteImageUrl(parameters.carte_image_url)
    setCarteCouleursImageUrl(parameters.carte_couleurs_image_url)
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
    <div className="bg-gray-900 border-2 border-yellow-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-sm w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">⚙️</span>
        <h3 className="text-yellow-400 text-lg">Paramètres</h3>
      </div>

      {loading ? (
        <p className="text-gray-500 text-sm">Chargement…</p>
      ) : (
        <div className="flex flex-col gap-4">
          <div>
            <label className="text-gray-400 text-sm block mb-1">Nombre max de capacités par pokémon</label>
            <NumberInput
              min={1}
              fallback={1}
              value={maxMoves}
              onCommit={commitMaxMoves}
              className="w-full bg-gray-800 border border-gray-600 rounded px-3 py-2 text-white text-sm outline-none focus:border-red-400"
            />
          </div>

          <div>
            <label className="text-gray-400 text-sm block mb-1">Taille max de l'équipe</label>
            <NumberInput
              min={1}
              fallback={1}
              value={maxTeamSize}
              onCommit={commitMaxTeamSize}
              className="w-full bg-gray-800 border border-gray-600 rounded px-3 py-2 text-white text-sm outline-none focus:border-red-400"
            />
          </div>

          <div className="border-t border-gray-700 pt-4">
            <label className="text-gray-400 text-sm block mb-1">Lien de l'image de la carte</label>
            <input
              type="text"
              value={carteImageUrl}
              onChange={(e) => setCarteImageUrl(e.target.value)}
              onBlur={saveCarte}
              placeholder="https://…"
              className="w-full bg-gray-800 border border-gray-600 rounded px-3 py-2 text-white text-sm outline-none focus:border-red-400"
            />
          </div>

          <div>
            <label className="text-gray-400 text-sm block mb-1">Lien de l'image des couleurs</label>
            <input
              type="text"
              value={carteCouleursImageUrl}
              onChange={(e) => setCarteCouleursImageUrl(e.target.value)}
              onBlur={saveCarte}
              placeholder="https://…"
              className="w-full bg-gray-800 border border-gray-600 rounded px-3 py-2 text-white text-sm outline-none focus:border-red-400"
            />
          </div>
        </div>
      )}
    </div>
  )
}
