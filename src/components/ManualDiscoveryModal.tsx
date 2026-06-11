import { useState, useRef, useEffect } from 'react'
import type { Pokemon } from '../types'

interface Props {
  pokemon: Pokemon[]
  discovered: Set<string>
  onDiscover: (p: Pokemon) => void
  onClose: () => void
}

export function ManualDiscoveryModal({ pokemon, discovered, onDiscover, onClose }: Props) {
  const [query, setQuery] = useState('')
  const [result, setResult] = useState<'idle' | 'found' | 'already' | 'notfound'>('idle')
  const [foundPokemon, setFoundPokemon] = useState<Pokemon | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  // Fermeture avec Echap
  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onClose])

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault()
    const q = query.trim().toLowerCase()
    if (!q) return

    // Recherche par code en premier (trouve aussi les cachés)
    let match = pokemon.find((p) => p.code?.toLowerCase() === q)

    // Puis par numéro ou nom, uniquement sur les non-cachés
    if (!match) {
      match = pokemon.find(
        (p) => !p.cache && (p.numero.toLowerCase() === q || p.nom.toLowerCase() === q)
      )
    }

    if (!match) {
      setResult('notfound')
      setFoundPokemon(null)
      return
    }

    if (discovered.has(match.nom)) {
      setResult('already')
      setFoundPokemon(match)
      return
    }

    setResult('found')
    setFoundPokemon(match)
  }

  const handleConfirm = () => {
    if (foundPokemon) {
      onDiscover(foundPokemon)
      onClose()
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className="bg-gray-900 border-2 border-gray-600 rounded-lg shadow-[4px_4px_0px_#000] max-w-sm w-full p-6">
        <div className="flex items-center justify-between mb-5">
          <h3 className="text-white text-lg">Découvrir un Pokémon</h3>
          <button onClick={onClose} className="text-gray-500 hover:text-white text-xl leading-none">✕</button>
        </div>

        <form onSubmit={handleSearch} className="flex gap-2 mb-4">
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => { setQuery(e.target.value); setResult('idle') }}
            placeholder="Numéro, nom ou code secret"
            className="flex-1 bg-gray-800 border-2 border-gray-600 rounded px-3 py-2 text-white text-sm outline-none focus:border-red-400 transition-colors"
          />
          <button
            type="submit"
            className="px-4 py-2 bg-red-700 border-2 border-red-500 text-white rounded hover:bg-red-600 transition-colors text-sm font-bold"
          >
            OK
          </button>
        </form>

        {/* Résultat */}
        {result === 'notfound' && (
          <p className="text-red-400 text-sm text-center py-2">❌ Aucun Pokémon trouvé.</p>
        )}

        {result === 'already' && foundPokemon && (
          <div className="text-center py-2">
            <p className="text-yellow-400 text-sm mb-1">⚠ Déjà dans le Pokédex !</p>
            <p className="text-gray-400 text-xs">#{foundPokemon.numero} {foundPokemon.nom}</p>
          </div>
        )}

        {result === 'found' && foundPokemon && (
          <div className="bg-gray-800 border border-gray-600 rounded-lg p-4 text-center">
            {foundPokemon.image_miniature && (
              <img
                src={foundPokemon.image_miniature}
                alt={foundPokemon.nom}
                className="w-16 h-16 object-contain mx-auto mb-2 pixelated"
              />
            )}
            <p className="text-gray-400 text-xs mb-0.5">#{foundPokemon.numero}</p>
            <p className="text-white font-bold">{foundPokemon.nom}</p>
            <p className="text-gray-400 text-xs mb-4">{foundPokemon.type}</p>
            <div className="flex gap-3">
              <button
                onClick={onClose}
                className="flex-1 py-2 border-2 border-gray-600 text-gray-300 rounded hover:bg-gray-700 transition-colors text-sm"
              >
                Annuler
              </button>
              <button
                onClick={handleConfirm}
                className="flex-1 py-2 bg-red-600 border-2 border-red-400 text-white rounded hover:bg-red-500 transition-colors text-sm font-bold"
              >
                Découvrir !
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
