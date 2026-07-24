import { useState, useEffect, useMemo, useRef } from 'react'
import { usePokemon } from './hooks/usePokemon'
import { useAttacks } from './hooks/useAttacks'
import { usePlayerContext } from './context/PlayerContext'
import { usePlayerPokemon } from './hooks/usePlayerPokemon'
import { useItems } from './hooks/useItems'
import { usePlayerItems } from './hooks/usePlayerItems'
import { useAdminParameters } from './hooks/useAdminParameters'
import { useToast } from './context/ToastContext'
import type { Pokemon } from './types'
import { POKEDOLLAR_ITEM_NAME } from './types'
import { AdminTab } from './components/AdminTab'
import { ManualDiscoveryModal } from './components/ManualDiscoveryModal'
import { ScannerModal } from './components/ScannerModal'
import { TabBar, type TabId } from './components/TabBar'
import { LoginModal } from './components/LoginModal'
import { HomeTab } from './components/HomeTab'
import { PokedexTab } from './components/PokedexTab'
import { TeamTab } from './components/TeamTab'
import { SacTab } from './components/SacTab'
import { CarteTab } from './components/CarteTab'
import { PokedollarChip } from './components/PokedollarChip'
import { SettingsPopup } from './components/SettingsPopup'
import { FullscreenPromptModal } from './components/FullscreenPromptModal'
import { useFullscreen } from './hooks/useFullscreen'
import { PANEL_LG, PIXEL_BORDER_SM } from './lib/panelStyles'

const TAB_TITLES: Record<TabId, string> = {
  accueil: 'ACCUEIL',
  pokedex: 'POKÉDEX',
  equipe: 'MES POKÉMON',
  sac: 'SAC',
  carte: 'CARTE',
  admin: 'ADMIN',
}

export default function App() {
  const { pokemon, discovered, discoverPokemon, undiscoverPokemon, refetch } = usePokemon()
  const { byName: attacksByName, refetch: refetchAttacks } = useAttacks()
  const { player, players, playersLoading, login, logout } = usePlayerContext()
  const { roster, addOwnedPokemon } = usePlayerPokemon(player?.id ?? null)
  const { items, byName: itemsByName, refetch: refetchItems } = useItems()
  const playerItems = usePlayerItems(player?.id ?? null)
  const { parameters } = useAdminParameters()
  const { showToast } = useToast()
  const { enter: enterFullscreen } = useFullscreen()

  const [showFullscreenPrompt, setShowFullscreenPrompt] = useState(true)
  const [isAdmin, setIsAdmin] = useState(() => sessionStorage.getItem('adminMode') === 'true')
  const [showSettings, setShowSettings] = useState(false)
  const [showManualModal, setShowManualModal] = useState(false)
  const [showScannerModal, setShowScannerModal] = useState(false)
  const [showLoginModal, setShowLoginModal] = useState(false)
  const [activeTab, setActiveTab] = useState<TabId>('accueil')

  // Chorégraphie post-découverte : célébration puis ouverture auto dans le Pokédex
  const [celebration, setCelebration] = useState<Pokemon | null>(null)
  const [autoOpenNumero, setAutoOpenNumero] = useState<string | null>(null)
  const celebrationTimer = useRef<number | undefined>(undefined)
  useEffect(() => () => clearTimeout(celebrationTimer.current), [])

  // Si l'onglet actif devient invisible (déconnexion, sortie du mode admin), on revient à l'accueil
  useEffect(() => {
    if ((activeTab === 'equipe' || activeTab === 'sac') && !player) setActiveTab('accueil')
    if (activeTab === 'admin' && !isAdmin) setActiveTab('accueil')
  }, [activeTab, player, isAdmin])

  const pokemonByName = useMemo(() => new Map(pokemon.map((p) => [p.nom, p])), [pokemon])
  const teamFull = player?.is_npc ? false : roster.filter((r) => r.in_team).length >= parameters.max_team_size

  const handleAddToRoster = async (p: Pokemon) => {
    const inTeam = !teamFull
    await addOwnedPokemon(p.nom, p.numero, inTeam)
    showToast(`${p.nom} ajouté ${inTeam ? "à l'équipe" : 'au PC'} !`)
  }

  const handleDiscoverWithCelebration = async (p: Pokemon) => {
    await discoverPokemon(p.nom)
    setCelebration(p)
    clearTimeout(celebrationTimer.current)
    celebrationTimer.current = window.setTimeout(() => {
      setCelebration(null)
      setActiveTab('pokedex')
      setAutoOpenNumero(p.numero)
    }, 1300)
  }

  const handleAdminLogout = () => {
    sessionStorage.removeItem('adminMode')
    setIsAdmin(false)
  }

  const tabBarProps = {
    activeTab,
    onTabChange: setActiveTab,
    showTeamTab: !!player,
    showSacTab: !!player,
    showCarteTab: true,
    showAdminTab: isAdmin,
  }

  return (
    <div className="flex flex-col h-full bg-app-bg">
      {/* En-tête persistant */}
      <header className="shrink-0 flex items-center gap-2.5 px-3.5 py-2.5 bg-shell border-b-4 border-ink shadow-[0_4px_0_rgba(0,0,0,0.35)]">
        <div className="w-5 h-5 rounded-full bg-[#7fd6ff] border-[3px] border-cream shadow-[0_0_6px_#7fd6ff] shrink-0" />
        <h1 className="flex-1 min-w-0 text-lg text-cream tracking-wide [text-shadow:2px_2px_0_rgba(0,0,0,0.35)] truncate">
          {TAB_TITLES[activeTab]}
        </h1>
        {player && (
          <PokedollarChip
            amount={playerItems.pokedollars}
            imageUrl={itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url}
          />
        )}
        <button
          onClick={() => setShowSettings(true)}
          title="Paramètres"
          className={`w-8 h-8 shrink-0 rounded-lg ${PIXEL_BORDER_SM} bg-black/20 text-cream text-sm flex items-center justify-center`}
        >
          ⚙️
        </button>
      </header>

      {/* Corps : barre latérale (desktop) + contenu */}
      <div className="flex flex-1 overflow-hidden">
        <TabBar {...tabBarProps} variant="side" />

        <main className="flex-1 flex flex-col overflow-hidden">
          {activeTab === 'accueil' && (
            <HomeTab
              player={player}
              isAdmin={isAdmin}
              pokemonByName={pokemonByName}
              attacksByName={attacksByName}
              onScan={() => setShowScannerModal(true)}
              onRequestLogin={() => setShowLoginModal(true)}
            />
          )}

          {activeTab === 'pokedex' && (
            <PokedexTab
              pokemon={pokemon}
              discovered={discovered}
              isAdmin={isAdmin}
              attacksByName={attacksByName}
              roster={roster}
              teamFull={teamFull}
              canAddToRoster={!!player}
              onAddToRoster={handleAddToRoster}
              onDiscover={(p) => discoverPokemon(p.nom)}
              onUndiscover={(p) => undiscoverPokemon(p.nom)}
              onScan={() => setShowScannerModal(true)}
              onManualDiscover={() => setShowManualModal(true)}
              autoOpenNumero={autoOpenNumero}
              onAutoOpenHandled={() => setAutoOpenNumero(null)}
            />
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

          {activeTab === 'sac' && player && (
            <SacTab player={player} items={items} itemsByName={itemsByName} playerItems={playerItems} />
          )}

          {activeTab === 'carte' && <CarteTab parameters={parameters} isAdmin={isAdmin} />}

          {activeTab === 'admin' && isAdmin && (
            <AdminTab
              onImportSuccess={() => { refetch(); refetchAttacks(); refetchItems() }}
            />
          )}
        </main>
      </div>

      {/* Barre d'onglets basse (mobile) */}
      <TabBar {...tabBarProps} variant="bottom" />

      {/* Modals */}
      {showSettings && (
        <SettingsPopup
          player={player}
          isAdmin={isAdmin}
          onRequestLogin={() => { setShowSettings(false); setShowLoginModal(true) }}
          onLogout={logout}
          onAdminSuccess={() => { setIsAdmin(true); setShowSettings(false); setActiveTab('admin') }}
          onAdminLogout={handleAdminLogout}
          onClose={() => setShowSettings(false)}
        />
      )}

      {showLoginModal && (
        <LoginModal
          players={players}
          loading={playersLoading}
          isAdmin={isAdmin}
          onSelect={(p) => { login(p); setShowLoginModal(false) }}
          onClose={() => setShowLoginModal(false)}
        />
      )}

      {showManualModal && (
        <ManualDiscoveryModal
          pokemon={pokemon}
          discovered={discovered}
          onDiscover={handleDiscoverWithCelebration}
          onClose={() => setShowManualModal(false)}
        />
      )}

      {showScannerModal && (
        <ScannerModal
          pokemon={pokemon}
          discovered={discovered}
          onDiscover={handleDiscoverWithCelebration}
          onClose={() => setShowScannerModal(false)}
        />
      )}

      {showFullscreenPrompt && (
        <FullscreenPromptModal
          onEnable={() => { enterFullscreen(); setShowFullscreenPrompt(false) }}
          onClose={() => setShowFullscreenPrompt(false)}
        />
      )}

      {/* Célébration de découverte */}
      {celebration && (
        <div className="fixed inset-0 z-[60] bg-[rgba(255,215,94,0.25)] flex items-center justify-center">
          <div className={`${PANEL_LG} px-6 py-4 text-center animate-[celebrate-pop_0.4s_ease-out]`}>
            <div className="text-2xl mb-1">✨</div>
            {celebration.image_miniature && (
              <img
                src={celebration.image_miniature}
                alt={celebration.nom}
                className="pixelated h-16 mx-auto mb-1 object-contain"
              />
            )}
            <div className="text-sm text-ink">Nouveau Pokémon découvert !</div>
            <div className="text-xl text-ink">{celebration.nom}</div>
          </div>
        </div>
      )}
    </div>
  )
}
