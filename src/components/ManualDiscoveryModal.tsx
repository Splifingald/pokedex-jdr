import { useState, useRef, useEffect } from 'react'
import type { Pokemon } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { normalizeSearch } from '../lib/normalizeSearch'

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
    const q = normalizeSearch(query.trim())
    if (!q) return

    // Recherche par code en premier (trouve aussi les cachés)
    let match = pokemon.find((p) => p.code && normalizeSearch(p.code) === q)

    // Puis par numéro ou nom, uniquement sur les non-cachés
    if (!match) {
      match = pokemon.find(
        (p) => !p.cache && (p.numero.toLowerCase() === q || normalizeSearch(p.nom) === q)
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
      <div className="bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-sm w-full p-6">
        <div className="flex items-center justify-between mb-5">
          <h3 className="text-ink text-lg">Découvrir un Pokémon</h3>
          <button onClick={onClose} className="text-ink-muted-2 hover:text-ink text-xl leading-none">✕</button>
        </div>

        <form onSubmit={handleSearch} className="flex gap-2 mb-4">
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => { setQuery(e.target.value); setResult('idle') }}
            placeholder="Numéro, nom ou code secret"
            className="flex-1 min-w-0 bg-white border-2 border-ink rounded-md px-3 py-2 text-ink text-sm placeholder-ink-muted-2 outline-none"
          />
          <button
            type="submit"
            className={`px-4 py-2 rounded text-sm font-bold ${BUTTON_STYLE.gray}`}
          >
            OK
          </button>
        </form>

        {/* Résultat */}
        {result === 'notfound' && (
          <p className="text-hp-red text-sm text-center py-2">❌ Aucun Pokémon trouvé.</p>
        )}

        {result === 'already' && foundPokemon && (
          <div className="text-center py-2">
            <p className="text-[#a3841a] text-sm mb-1">⚠ Déjà dans le Pokédex !</p>
            <p className="text-ink-muted-2 text-xs">#{foundPokemon.numero} {foundPokemon.nom}</p>
          </div>
        )}

        {result === 'found' && foundPokemon && (
          <div className="bg-cream-secondary border-2 border-ink rounded-lg p-4 text-center">
            {foundPokemon.image_miniature && (
              <img
                src={foundPokemon.image_miniature}
                alt={foundPokemon.nom}
                className="w-16 h-16 object-contain mx-auto mb-2 pixelated"
              />
            )}
            <p className="text-ink-muted-2 text-xs mb-0.5">#{foundPokemon.numero}</p>
            <p className="text-ink font-bold">{foundPokemon.nom}</p>
            <p className="text-ink-muted-2 text-xs mb-4">{foundPokemon.type}</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <button
                onClick={onClose}
                className={`py-2 rounded text-sm ${BUTTON_STYLE.gray}`}
              >
                Annuler
              </button>
              <button
                onClick={handleConfirm}
                className={`py-2 rounded text-sm font-bold ${BUTTON_STYLE.gray}`}
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
