import { useState, useEffect, useMemo } from 'react'
import { usePokemon } from './hooks/usePokemon'
import { useAttacks } from './hooks/useAttacks'
import { usePlayerContext } from './context/PlayerContext'
import { usePlayerPokemon } from './hooks/usePlayerPokemon'
import type { Pokemon } from './types'
import { PokemonList } from './components/PokemonList'
import { PokemonCard } from './components/PokemonCard'
import { DiscoveryModal } from './components/DiscoveryModal'
import { PasswordModal } from './components/PasswordModal'
import { AdminTab } from './components/AdminTab'
import { SearchBar } from './components/SearchBar'
import { ManualDiscoveryModal } from './components/ManualDiscoveryModal'
import { ScannerModal } from './components/ScannerModal'
import { TabBar, type TabId } from './components/TabBar'
import { LoginModal } from './components/LoginModal'
import { PlayerBadge } from './components/PlayerBadge'
import { TeamTab } from './components/TeamTab'

export default function App() {
  const { pokemon, discovered, loading, error, discoverPokemon, undiscoverPokemon, refetch } = usePokemon()
  const { byName: attacksByName, refetch: refetchAttacks } = useAttacks()
  const { player, players, playersLoading, login, logout } = usePlayerContext()
  const { addOwnedPokemon } = usePlayerPokemon(player?.id ?? null)

  const [selected, setSelected] = useState<Pokemon | null>(null)
  const [pendingDiscovery, setPendingDiscovery] = useState<Pokemon | null>(null)
  const [isAdmin, setIsAdmin] = useState(() => sessionStorage.getItem('adminMode') === 'true')
  const [showPasswordModal, setShowPasswordModal] = useState(false)
  const [showManualModal, setShowManualModal] = useState(false)
  const [showScannerModal, setShowScannerModal] = useState(false)
  const [showLoginModal, setShowLoginModal] = useState(false)
  const [activeTab, setActiveTab] = useState<TabId>('pokedex')

  // Si l'onglet actif devient invisible (déconnexion, sortie du mode admin), on revient au Pokédex
  useEffect(() => {
    if (activeTab === 'equipe' && !player) setActiveTab('pokedex')
    if (activeTab === 'admin' && !isAdmin) setActiveTab('pokedex')
  }, [activeTab, player, isAdmin])

  // Filtres de recherche
  const [search, setSearch] = useState('')
  const [typeFilter, setTypeFilter] = useState('')

  // Types uniques disponibles dans le pokédex
  const availableTypes = useMemo(() => {
    const visible = isAdmin ? pokemon : pokemon.filter((p) => !p.cache)
    const types = [...new Set(visible.map((p) => p.type))].sort()
    return types
  }, [pokemon, isAdmin])

  // Liste filtrée
  const filteredPokemon = useMemo(() => {
    const hasFilter = search !== '' || typeFilter !== ''
    return pokemon.filter((p) => {
      // Hors admin : caché non découvert → toujours invisible
      // Hors admin + filtre actif : non découvert → invisible (recherche sur découverts seulement)
      if (!isAdmin && !discovered.has(p.nom) && (p.cache || hasFilter)) return false
      const q = search.toLowerCase()
      if (q && !p.nom.toLowerCase().includes(q) && !p.numero.includes(q)) return false
      if (typeFilter && p.type !== typeFilter) return false
      return true
    })
  }, [pokemon, search, typeFilter, isAdmin, discovered])

  // Sync la fiche sélectionnée si les données rechargent
  useEffect(() => {
    if (selected) {
      const updated = pokemon.find((p) => p.id === selected.id)
      if (updated) setSelected(updated)
    }
  }, [pokemon])

  const handleAdminTriggerClick = () => {
    if (isAdmin) {
      setActiveTab('admin')
    } else {
      setShowPasswordModal(true)
    }
  }

  const handlePasswordSuccess = () => {
    setIsAdmin(true)
    setShowPasswordModal(false)
    setActiveTab('admin')
  }

  const handleAdminLogout = () => {
    sessionStorage.removeItem('adminMode')
    setIsAdmin(false)
    setActiveTab('pokedex')
  }

  const handlePlayerLogin = (p: (typeof players)[number]) => {
    login(p)
    setShowLoginModal(false)
  }

  const handleDiscoveryConfirm = async () => {
    if (!pendingDiscovery) return
    await discoverPokemon(pendingDiscovery.nom)
    setSelected(pendingDiscovery)
    setPendingDiscovery(null)
  }

  const handleManualDiscover = async (p: Pokemon) => {
    await discoverPokemon(p.nom)
    setSelected(p)
  }

  const handleUndiscover = async () => {
    if (!selected) return
    await undiscoverPokemon(selected.nom)
    // On ferme la fiche sur mobile, on reste sur desktop
    if (window.innerWidth < 768) setSelected(null)
  }

  // Pokémon "visibles" : non-cachés + admin voit tout + cachés découverts
  const visibleCount = pokemon.filter((p) => !p.cache || isAdmin || discovered.has(p.nom)).length

  const pokemonByName = useMemo(() => new Map(pokemon.map((p) => [p.nom, p])), [pokemon])

  return (
    <div className="flex flex-col h-full bg-gray-900">
      {/* Header Pokédex */}
      <header className="shrink-0 flex items-center px-4 py-2 bg-red-700 border-b-4 border-red-900 shadow-lg relative">
        <button
          onClick={handleAdminTriggerClick}
          className="absolute top-0 left-0 w-12 h-12 z-50 opacity-0 cursor-default"
          aria-hidden="true"
          tabIndex={-1}
        />

        <div className="flex items-center gap-2 mr-4 shrink-0">
          <div className="w-8 h-8 rounded-full bg-blue-400 border-2 border-white shadow-[0_0_8px_#60a5fa]" />
          <div className="w-3 h-3 rounded-full bg-red-300 border border-white" />
          <div className="w-3 h-3 rounded-full bg-yellow-300 border border-white" />
          <div className="w-3 h-3 rounded-full bg-green-400 border border-white" />
        </div>

        <h1 className="text-white text-2xl tracking-widest">POKÉDEX</h1>

        <div className="ml-auto flex items-center gap-2">
          {player ? (
            <PlayerBadge player={player} onLogout={logout} />
          ) : (
            <button
              onClick={() => setShowLoginModal(true)}
              className="text-white text-sm border border-white/40 rounded px-2 py-1 hover:bg-white/10 transition-colors"
            >
              👤 Connexion
            </button>
          )}

          {isAdmin && (
            <button
              onClick={() => setActiveTab('admin')}
              className="text-yellow-300 text-sm border border-yellow-600 rounded px-2 py-1 hover:bg-yellow-900/30 transition-colors"
            >
              🛠 Admin
            </button>
          )}
        </div>
      </header>

      <TabBar
        activeTab={activeTab}
        onTabChange={setActiveTab}
        showTeamTab={!!player}
        showAdminTab={isAdmin}
      />

      {/* Corps principal */}
      {activeTab === 'pokedex' && (
        <div className="flex flex-1 overflow-hidden">
          {/* Panneau liste */}
          <div
            className={`bg-gray-900 border-r border-gray-700 flex flex-col
              ${selected ? 'hidden md:flex' : 'flex'}
              w-full md:w-80 lg:w-96 shrink-0
            `}
          >
            {/* Barre de statut */}
            <div className="px-4 py-1.5 bg-gray-800 border-b border-gray-700 flex items-center justify-between shrink-0">
              <span className="text-gray-400 text-xs">
                {loading ? 'Chargement…' : `${filteredPokemon.length} / ${visibleCount} Pokémon`}
              </span>
              <span className="text-gray-500 text-xs">{discovered.size} découverts</span>
            </div>

            {/* Barre de recherche */}
            <SearchBar
              search={search}
              onSearchChange={setSearch}
              typeFilter={typeFilter}
              onTypeFilterChange={setTypeFilter}
              availableTypes={availableTypes}
              onManualDiscover={() => setShowManualModal(true)}
              onScanDiscover={() => setShowScannerModal(true)}
            />

            {loading ? (
              <div className="flex-1 flex items-center justify-center">
                <div className="text-gray-500 text-center">
                  <div className="text-4xl mb-3 animate-spin">⊙</div>
                  <p className="text-sm">Chargement…</p>
                </div>
              </div>
            ) : error ? (
              <div className="flex-1 flex items-center justify-center p-6">
                <div className="text-red-400 text-center text-sm">
                  <div className="text-3xl mb-2">⚠️</div>
                  <p>{error}</p>
                </div>
              </div>
            ) : (
              <PokemonList
                pokemon={filteredPokemon}
                discovered={discovered}
                isAdmin={isAdmin}
                selectedId={selected?.id ?? null}
                onSelectDiscovered={setSelected}
                onSelectUndiscovered={setPendingDiscovery}
                totalCount={visibleCount}
              />
            )}
          </div>

          {/* Panneau détail */}
          <div className="flex-1 overflow-hidden">
            {selected ? (
              <PokemonCard
                pokemon={selected}
                isAdmin={isAdmin}
                isDiscovered={discovered.has(selected.nom)}
                attacksByName={attacksByName}
                onBack={() => setSelected(null)}
                onUndiscover={handleUndiscover}
                onAddToRoster={player ? () => addOwnedPokemon(selected.nom, selected.numero) : undefined}
              />
            ) : (
              <div className="hidden md:flex h-full items-center justify-center text-gray-700 flex-col gap-4 select-none">
                <div className="text-8xl opacity-20">⊙</div>
                <p className="text-lg opacity-30">Sélectionnez un Pokémon</p>
              </div>
            )}
          </div>
        </div>
      )}

      {activeTab === 'equipe' && player && (
        <TeamTab
          player={player}
          pokemonList={pokemon}
          discovered={discovered}
          isAdmin={isAdmin}
          pokemonByName={pokemonByName}
          attacksByName={attacksByName}
        />
      )}

      {activeTab === 'admin' && isAdmin && (
        <AdminTab
          onImportSuccess={() => { refetch(); refetchAttacks() }}
          onLogout={handleAdminLogout}
        />
      )}

      {/* Modals */}
      {pendingDiscovery && (
        <DiscoveryModal
          numero={pendingDiscovery.numero}
          onConfirm={handleDiscoveryConfirm}
          onCancel={() => setPendingDiscovery(null)}
        />
      )}

      {showPasswordModal && (
        <PasswordModal
          onSuccess={handlePasswordSuccess}
          onCancel={() => setShowPasswordModal(false)}
        />
      )}

      {showLoginModal && (
        <LoginModal
          players={players}
          loading={playersLoading}
          onSelect={handlePlayerLogin}
          onClose={() => setShowLoginModal(false)}
        />
      )}

      {showManualModal && (
        <ManualDiscoveryModal
          pokemon={pokemon}
          discovered={discovered}
          onDiscover={handleManualDiscover}
          onClose={() => setShowManualModal(false)}
        />
      )}

      {showScannerModal && (
        <ScannerModal
          pokemon={pokemon}
          discovered={discovered}
          onDiscover={handleManualDiscover}
          onClose={() => setShowScannerModal(false)}
        />
      )}
    </div>
  )
}
