import { NAV_ICON } from '../lib/icons'
import { PixelIcon } from './icons/PixelIcon'

export type TabId = 'accueil' | 'pokedex' | 'equipe' | 'sac' | 'carte' | 'attaques' | 'rencontres' | 'campagne' | 'admin'

interface Tab {
  id: TabId
  /** Emoji de secours, utilisé si aucune icône custom n'existe pour cet onglet (ex : Rencontres) */
  icon: string
  label: string
  visible: boolean
}

// Icône custom (public/website_icons/) si elle existe pour cet onglet, sinon emoji de secours
function TabIcon({ tab }: { tab: Tab }) {
  const src = NAV_ICON[tab.id]
  return src ? (
    <PixelIcon src={src} size={28} alt={tab.label} colored />
  ) : (
    <span className="text-2xl leading-none">{tab.icon}</span>
  )
}

interface Props {
  activeTab: TabId
  onTabChange: (tab: TabId) => void
  showPokedexTab: boolean
  showTeamTab: boolean
  showSacTab: boolean
  showCarteTab: boolean
  showAttacksTab: boolean
  showRencontresTab: boolean
  showCampagneTab: boolean
  showAdminTab: boolean
  /** 'bottom' = barre d'icônes mobile, 'side' = barre latérale desktop */
  variant: 'bottom' | 'side'
}

export function TabBar({ activeTab, onTabChange, showPokedexTab, showTeamTab, showSacTab, showCarteTab, showAttacksTab, showRencontresTab, showCampagneTab, showAdminTab, variant }: Props) {
  const tabs: Tab[] = [
    { id: 'pokedex', icon: '📖', label: 'Pokédex', visible: showPokedexTab },
    { id: 'equipe', icon: '🐾', label: 'Pokémon', visible: showTeamTab },
    { id: 'accueil', icon: '🏠', label: 'Accueil', visible: true },
    { id: 'sac', icon: '🎒', label: 'Sac', visible: showSacTab },
    { id: 'carte', icon: '🗺️', label: 'Carte', visible: showCarteTab },
    { id: 'attaques', icon: '💥', label: 'Capacités', visible: showAttacksTab },
    { id: 'rencontres', icon: '🎲', label: 'Rencontres', visible: showRencontresTab },
    { id: 'campagne', icon: '📓', label: 'Journal', visible: showCampagneTab },
    { id: 'admin', icon: '🛠️', label: 'Admin', visible: showAdminTab },
  ]

  const visibleTabs = tabs.filter((t) => t.visible)
  // 5 tabs ou moins (mode non-admin) : tout doit tenir sans scroll.
  // Au-delà (mode admin), le scroll horizontal redevient nécessaire.
  const scrollable = visibleTabs.length > 5

  if (variant === 'side') {
    return (
      <nav className="shrink-0 hidden md:flex flex-col w-24 bg-tabbar-bg border-r-4 border-ink py-2 overflow-y-auto">
        {visibleTabs.map((tab) => {
          const active = activeTab === tab.id
          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              className={`shrink-0 flex flex-col items-center gap-0.5 py-3 border-l-[3px] transition-colors ${
                active
                  ? 'border-shell bg-white/5 text-cream'
                  : 'border-transparent text-tabbar-inactive hover:text-cream'
              }`}
            >
              <TabIcon tab={tab} />
              <span className="text-xs">{tab.label}</span>
            </button>
          )
        })}
      </nav>
    )
  }

  return (
    <nav className={`shrink-0 flex md:hidden bg-tabbar-bg border-t-4 border-ink pb-safe ${scrollable ? 'overflow-x-auto' : 'overflow-hidden'}`}>
      {visibleTabs.map((tab) => {
        const active = activeTab === tab.id
        return (
          <button
            key={tab.id}
            onClick={() => onTabChange(tab.id)}
            aria-label={tab.label}
            className={`flex-1 ${scrollable ? 'min-w-16' : 'min-w-0'} flex items-center justify-center py-3 border-t-[3px] transition-colors ${
              active
                ? 'border-shell bg-white/5 text-cream'
                : 'border-transparent text-tabbar-inactive'
            }`}
          >
            <TabIcon tab={tab} />
          </button>
        )
      })}
    </nav>
  )
}
