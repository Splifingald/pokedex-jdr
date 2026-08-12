import { useState, useMemo, useRef, useEffect } from 'react'
import type { Pokemon, Attack, PlayerPokemon, PokemonEvolution } from '../types'
import { Chip } from './Chip'
import { TypeBadge } from './TypeBadge'
import { DiscoveryModal } from './DiscoveryModal'
import { PokemonDetailSheet } from './PokemonDetailSheet'
import { normalizeSearch } from '../lib/normalizeSearch'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PANEL, PIXEL_BORDER_SM } from '../lib/panelStyles'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { NAV_ICON, PHOTO_ICON } from '../lib/icons'

type SortKey = 'numero' | 'type' | 'alpha'
type LayoutKey = 'grid' | 'list'

// Colonnes fluides : taille mini fixe, et jusqu'à 8 colonnes sur grand écran
export const POKEDEX_GRID_COLS = 'repeat(auto-fill, minmax(max(96px, 11.5%), 1fr))'

interface Props {
  pokemon: Pokemon[]
  discovered: Set<string>
  isAdmin: boolean
  attacksByName: Map<string, Attack>
  pokemonByName: Map<string, Pokemon>
  evolutionsByPokemonNom: Map<string, PokemonEvolution[]>
  roster: PlayerPokemon[]
  teamFull: boolean
  canAddToRoster: boolean
  onAddToRoster: (p: Pokemon) => void
  onDiscover: (p: Pokemon) => Promise<void> | void
  onUndiscover: (p: Pokemon) => void
  canScan: boolean
  onScan: () => void
  onManualDiscover: () => void
  /** Numéro à ouvrir/centrer automatiquement (après un scan réussi) */
  autoOpenNumero?: string | null
  onAutoOpenHandled?: () => void
}

const SORT_LABELS: Record<SortKey, string> = { numero: '#', type: 'Type', alpha: 'A-Z' }

export function PokedexTab({
  pokemon,
  discovered,
  isAdmin,
  attacksByName,
  pokemonByName,
  evolutionsByPokemonNom,
  roster,
  teamFull,
  canAddToRoster,
  onAddToRoster,
  onDiscover,
  onUndiscover,
  canScan,
  onScan,
  onManualDiscover,
  autoOpenNumero,
  onAutoOpenHandled,
}: Props) {
  const [search, setSearch] = useState('')
  const [typeFilter, setTypeFilter] = useState('')
  const [sortKey, setSortKey] = useState<SortKey>('numero')
  const [layout, setLayout] = useState<LayoutKey>('grid')
  const [selected, setSelected] = useState<Pokemon | null>(null)
  const [pendingDiscovery, setPendingDiscovery] = useState<Pokemon | null>(null)

  const cellRefs = useRef(new Map<string, HTMLButtonElement>())

  const availableTypes = useMemo(() => {
    const visible = isAdmin ? pokemon : pokemon.filter((p) => !p.cache)
    return [...new Set(visible.map((p) => p.type))].sort()
  }, [pokemon, isAdmin])

  const filteredPokemon = useMemo(() => {
    const hasFilter = search !== '' || typeFilter !== ''
    const list = pokemon.filter((p) => {
      // Hors admin : caché non découvert → toujours invisible
      // Hors admin + filtre actif : non découvert → invisible (recherche sur découverts seulement)
      if (!isAdmin && !discovered.has(p.nom) && (p.cache || hasFilter)) return false
      const q = normalizeSearch(search)
      if (q && !normalizeSearch(p.nom).includes(q) && !p.numero.includes(q)) return false
      if (typeFilter && p.type !== typeFilter) return false
      return true
    })
    const byNumero = (a: Pokemon, b: Pokemon) => a.numero.localeCompare(b.numero, undefined, { numeric: true })
    const sorted = [...list]
    if (sortKey === 'type') {
      sorted.sort((a, b) => a.type.localeCompare(b.type) || byNumero(a, b))
    } else if (sortKey === 'alpha') {
      // Les non-découverts (nom inconnu hors admin) partent en fin de liste
      sorted.sort((a, b) => {
        const aKnown = isAdmin || discovered.has(a.nom)
        const bKnown = isAdmin || discovered.has(b.nom)
        if (aKnown !== bKnown) return aKnown ? -1 : 1
        if (!aKnown) return byNumero(a, b)
        return a.nom.localeCompare(b.nom, 'fr')
      })
    } else {
      sorted.sort(byNumero)
    }
    return sorted
  }, [pokemon, search, typeFilter, sortKey, isAdmin, discovered])

  const visibleCount = pokemon.filter((p) => !p.cache || isAdmin || discovered.has(p.nom)).length

  // Ouverture automatique après un scan réussi : sélectionne la fiche et centre la grille dessus
  useEffect(() => {
    if (!autoOpenNumero) return
    const raf = requestAnimationFrame(() => {
      const target = pokemon.find((p) => p.numero === autoOpenNumero)
      if (target) {
        setSearch('')
        setTypeFilter('')
        setSelected(target)
        requestAnimationFrame(() => {
          cellRefs.current.get(autoOpenNumero)?.scrollIntoView({ block: 'center', behavior: 'smooth' })
        })
      }
      onAutoOpenHandled?.()
    })
    return () => cancelAnimationFrame(raf)
  }, [autoOpenNumero]) // eslint-disable-line react-hooks/exhaustive-deps

  // Garde la fiche sélectionnée synchronisée si les données rechargent
  const syncedSelected = useMemo(
    () => (selected ? pokemon.find((p) => p.id === selected.id) ?? selected : null),
    [selected, pokemon]
  )

  const ownedCount = syncedSelected ? roster.filter((r) => r.pokemon_nom === syncedSelected.nom).length : 0

  const handleDiscoveryConfirm = async () => {
    if (!pendingDiscovery) return
    await onDiscover(pendingDiscovery)
    setSelected(pendingDiscovery)
    setPendingDiscovery(null)
  }

  return (
    <div className="flex-1 flex flex-col overflow-hidden relative">
      {/* En-tête fixe */}
      <div className="shrink-0 px-4 pt-3 pb-2">
        <div className="flex justify-end mb-2">
          <span className="text-xs text-[#9a9cba]">{discovered.size} / {visibleCount} découverts</span>
        </div>

        <div className="flex gap-2 mb-2.5">
          <div className="relative flex-1">
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Rechercher un Pokémon…"
              className={`w-full px-3 py-2 rounded-lg ${PIXEL_BORDER_SM} bg-cream text-ink text-sm placeholder-ink-muted-2 outline-none`}
            />
            {search && (
              <button
                onClick={() => setSearch('')}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-ink-muted-2 hover:text-ink"
              >
                <CloseIcon className="w-4 h-4" />
              </button>
            )}
          </div>
          {availableTypes.length > 0 && (
            <select
              value={typeFilter}
              onChange={(e) => setTypeFilter(e.target.value)}
              className={`shrink-0 max-w-[7.5rem] px-2 py-2 rounded-lg ${PIXEL_BORDER_SM} bg-cream text-ink text-sm outline-none`}
            >
              <option value="">Tous types</option>
              {availableTypes.map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
          )}
        </div>

        <div className="flex gap-1.5 flex-wrap items-center">
          {(Object.keys(SORT_LABELS) as SortKey[]).map((k) => (
            <Chip key={k} label={SORT_LABELS[k]} active={sortKey === k} onClick={() => setSortKey(k)} />
          ))}
          <button
            onClick={() => setLayout((l) => (l === 'grid' ? 'list' : 'grid'))}
            title={layout === 'grid' ? 'Vue liste' : 'Vue grille'}
            className={`px-2.5 py-1 rounded-md text-sm ${BUTTON_STYLE.gray}`}
          >
            {layout === 'grid' ? '☰' : '▦'}
          </button>
        </div>
      </div>

      {/* Grille défilante */}
      <div className="flex-1 overflow-y-auto px-4 pt-1 pb-24">
        {filteredPokemon.length === 0 ? (
          <p className="text-[#7a7c9a] text-sm text-center mt-8">Aucun Pokémon trouvé.</p>
        ) : layout === 'grid' ? (
          <div className="grid gap-2.5" style={{ gridTemplateColumns: POKEDEX_GRID_COLS }}>
            {filteredPokemon.map((p) => {
              const isDiscovered = discovered.has(p.nom)
              const revealed = isAdmin || isDiscovered
              const owned = roster.some((r) => r.pokemon_nom === p.nom)
              return (
                <button
                  key={p.id}
                  ref={(el) => {
                    if (el) cellRefs.current.set(p.numero, el)
                    else cellRefs.current.delete(p.numero)
                  }}
                  onClick={() => (revealed ? setSelected(p) : setPendingDiscovery(p))}
                  className="flex flex-col items-center gap-1"
                >
                  {revealed ? (
                    <div className={`relative w-full aspect-square rounded-md ${PIXEL_BORDER_SM} bg-cream flex items-center justify-center overflow-hidden shadow-[var(--shadow-pixel-sm)]`}>
                      {p.image_miniature ? (
                        <img
                          src={p.image_miniature}
                          alt={p.nom}
                          className={`pixelated w-full h-full object-contain ${isAdmin && !isDiscovered ? 'grayscale opacity-60' : ''}`}
                        />
                      ) : (
                        <span className="text-ink-muted-2 text-2xl">?</span>
                      )}
                      {owned && (
                        <span className="absolute top-1 right-1 text-hp-red" title="Dans votre roster">
                          <PixelIcon src={NAV_ICON.equipe!} size={16} colored />
                        </span>
                      )}
                      {isAdmin && p.cache && (
                        <span className="absolute top-1 left-1 text-[9px] bg-purple-200 text-purple-900 border border-purple-700 rounded px-1">C</span>
                      )}
                    </div>
                  ) : (
                    <div className={`w-full aspect-square rounded-md ${PIXEL_BORDER_SM} bg-[#2a2c48] flex items-center justify-center opacity-75`}>
                      <span className="text-[#5a5c78] text-2xl">?</span>
                    </div>
                  )}
                  <span className="text-[11px] text-[#9a9cba]">#{p.numero}</span>
                </button>
              )
            })}
          </div>
        ) : (
          <div className="flex flex-col gap-2">
            {filteredPokemon.map((p) => {
              const isDiscovered = discovered.has(p.nom)
              const revealed = isAdmin || isDiscovered
              const owned = roster.some((r) => r.pokemon_nom === p.nom)
              return (
                <button
                  key={p.id}
                  ref={(el) => {
                    if (el) cellRefs.current.set(p.numero, el)
                    else cellRefs.current.delete(p.numero)
                  }}
                  onClick={() => (revealed ? setSelected(p) : setPendingDiscovery(p))}
                  className={`${PANEL} flex items-center gap-2.5 p-2 text-left w-full ${!isDiscovered && !isAdmin ? 'opacity-75' : ''}`}
                >
                  <div className={`w-11 h-11 shrink-0 rounded-md border-2 border-ink flex items-center justify-center overflow-hidden ${revealed ? 'bg-cream-secondary' : 'bg-[#2a2c48]'}`}>
                    {revealed && p.image_miniature ? (
                      <img
                        src={p.image_miniature}
                        alt={p.nom}
                        className={`pixelated w-full h-full object-contain ${isAdmin && !isDiscovered ? 'grayscale opacity-60' : ''}`}
                      />
                    ) : (
                      <span className={`text-xl ${revealed ? 'text-ink-muted-2' : 'text-[#5a5c78]'}`}>?</span>
                    )}
                  </div>
                  <span className="text-xs text-ink-muted-2 shrink-0">#{p.numero}</span>
                  <span className="flex-1 text-ink text-sm font-bold truncate">
                    {revealed ? p.nom : '???'}
                    {isAdmin && p.cache && (
                      <span className="ml-2 text-[9px] bg-purple-200 text-purple-900 border border-purple-700 rounded px-1 align-middle">C</span>
                    )}
                  </span>
                  {owned && (
                    <span className="shrink-0 text-hp-red" title="Dans votre roster">
                      <PixelIcon src={NAV_ICON.equipe!} size={18} colored />
                    </span>
                  )}
                  {revealed && <TypeBadge type={p.type} small />}
                </button>
              )
            })}
          </div>
        )}
      </div>

      {/* Boutons flottants : scanner + découverte manuelle */}
      <div className="absolute left-4 right-4 bottom-4 flex gap-2">
        {canScan && (
          <button
            onClick={onScan}
            className="flex-1 py-3 rounded-lg border-2 border-ink bg-shell text-white font-bold text-sm shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all flex items-center justify-center gap-2"
          >
            <PixelIcon src={PHOTO_ICON} size={22} alt="" colored />
            Ajouter un Pokémon
          </button>
        )}
        <button
          onClick={onManualDiscover}
          title="Ajouter un pokémon manuellement"
          className={`shrink-0 w-12 rounded-lg text-xl font-bold ${BUTTON_STYLE.gray}`}
        >
          +
        </button>
      </div>

      {pendingDiscovery && (
        <DiscoveryModal
          numero={pendingDiscovery.numero}
          onConfirm={handleDiscoveryConfirm}
          onCancel={() => setPendingDiscovery(null)}
        />
      )}

      {syncedSelected && (
        <PokemonDetailSheet
          context="pokedex"
          pokemon={syncedSelected}
          attacksByName={attacksByName}
          pokemonByName={pokemonByName}
          evolutionsByPokemonNom={evolutionsByPokemonNom}
          isAdmin={isAdmin}
          isDiscovered={discovered.has(syncedSelected.nom)}
          teamFull={teamFull}
          ownedCount={ownedCount}
          onAddToRoster={canAddToRoster ? () => onAddToRoster(syncedSelected) : undefined}
          onUndiscover={() => { onUndiscover(syncedSelected); setSelected(null) }}
          onDiscover={() => onDiscover(syncedSelected)}
          onClose={() => setSelected(null)}
        />
      )}
    </div>
  )
}
