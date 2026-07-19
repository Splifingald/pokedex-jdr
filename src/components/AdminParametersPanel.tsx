import { useState, useEffect } from 'react'
import { useAdminParameters } from '../hooks/useAdminParameters'

export function AdminParametersPanel() {
  const { parameters, loading, updateParameters } = useAdminParameters()
  const [maxMoves, setMaxMoves] = useState(parameters.max_moves)
  const [maxTeamSize, setMaxTeamSize] = useState(parameters.max_team_size)

  useEffect(() => {
    setMaxMoves(parameters.max_moves)
    setMaxTeamSize(parameters.max_team_size)
  }, [parameters])

  const save = () => {
    updateParameters({ max_moves: maxMoves, max_team_size: maxTeamSize })
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
            <input
              type="number"
              min={1}
              value={maxMoves}
              onChange={(e) => setMaxMoves(parseInt(e.target.value) || 1)}
              onBlur={save}
              className="w-full bg-gray-800 border border-gray-600 rounded px-3 py-2 text-white text-sm outline-none focus:border-red-400"
            />
          </div>

          <div>
            <label className="text-gray-400 text-sm block mb-1">Taille max de l'équipe</label>
            <input
              type="number"
              min={1}
              value={maxTeamSize}
              onChange={(e) => setMaxTeamSize(parseInt(e.target.value) || 1)}
              onBlur={save}
              className="w-full bg-gray-800 border border-gray-600 rounded px-3 py-2 text-white text-sm outline-none focus:border-red-400"
            />
          </div>
        </div>
      )}
    </div>
  )
}
