export type TabId = 'accueil' | 'pokedex' | 'equipe' | 'sac' | 'carte' | 'attaques' | 'rencontres' | 'admin'

interface Tab {
  id: TabId
  icon: string
  label: string
  visible: boolean
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
  showAdminTab: boolean
  /** 'bottom' = barre d'icônes mobile, 'side' = barre latérale desktop */
  variant: 'bottom' | 'side'
}

export function TabBar({ activeTab, onTabChange, showPokedexTab, showTeamTab, showSacTab, showCarteTab, showAttacksTab, showRencontresTab, showAdminTab, variant }: Props) {
  const tabs: Tab[] = [
    { id: 'pokedex', icon: '📖', label: 'Pokédex', visible: showPokedexTab },
    { id: 'equipe', icon: '🐾', label: 'Pokémon', visible: showTeamTab },
    { id: 'accueil', icon: '🏠', label: 'Accueil', visible: true },
    { id: 'sac', icon: '🎒', label: 'Sac', visible: showSacTab },
    { id: 'carte', icon: '🗺️', label: 'Carte', visible: showCarteTab },
    { id: 'attaques', icon: '💥', label: 'Capacités', visible: showAttacksTab },
    { id: 'rencontres', icon: '🎲', label: 'Rencontres', visible: showRencontresTab },
    { id: 'admin', icon: '🛠️', label: 'Admin', visible: showAdminTab },
  ]

  const visibleTabs = tabs.filter((t) => t.visible)

  if (variant === 'side') {
    return (
      <nav className="shrink-0 hidden md:flex flex-col w-24 bg-tabbar-bg border-r-4 border-ink py-2">
        {visibleTabs.map((tab) => {
          const active = activeTab === tab.id
          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              className={`flex flex-col items-center gap-0.5 py-3 border-l-[3px] transition-colors ${
                active
                  ? 'border-shell bg-white/5 text-cream'
                  : 'border-transparent text-tabbar-inactive hover:text-cream'
              }`}
            >
              <span className="text-2xl leading-none">{tab.icon}</span>
              <span className="text-xs">{tab.label}</span>
            </button>
          )
        })}
      </nav>
    )
  }

  return (
    <nav className="shrink-0 flex md:hidden bg-tabbar-bg border-t-4 border-ink">
      {visibleTabs.map((tab) => {
        const active = activeTab === tab.id
        return (
          <button
            key={tab.id}
            onClick={() => onTabChange(tab.id)}
            aria-label={tab.label}
            className={`flex-1 flex items-center justify-center py-3 border-t-[3px] transition-colors ${
              active
                ? 'border-shell bg-white/5 text-cream'
                : 'border-transparent text-tabbar-inactive'
            }`}
          >
            <span className="text-2xl leading-none">{tab.icon}</span>
          </button>
        )
      })}
    </nav>
  )
}
