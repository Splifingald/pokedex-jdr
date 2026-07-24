export type TabId = 'pokedex' | 'equipe' | 'sac' | 'carte' | 'admin'

interface Tab {
  id: TabId
  label: string
  visible: boolean
}

interface Props {
  activeTab: TabId
  onTabChange: (tab: TabId) => void
  showTeamTab: boolean
  showSacTab: boolean
  showCarteTab: boolean
  showAdminTab: boolean
}

export function TabBar({ activeTab, onTabChange, showTeamTab, showSacTab, showCarteTab, showAdminTab }: Props) {
  const tabs: Tab[] = [
    { id: 'pokedex', label: 'Pokédex', visible: true },
    { id: 'equipe', label: 'Mon Équipe', visible: showTeamTab },
    { id: 'sac', label: 'Sac', visible: showSacTab },
    { id: 'carte', label: 'Carte', visible: showCarteTab },
    { id: 'admin', label: 'Admin', visible: showAdminTab },
  ]

  const visibleTabs = tabs.filter((t) => t.visible)
  if (visibleTabs.length <= 1) return null

  return (
    <div className="shrink-0 flex bg-gray-800 border-b border-gray-700">
      {visibleTabs.map((tab) => (
        <button
          key={tab.id}
          onClick={() => onTabChange(tab.id)}
          className={`px-4 py-2 text-sm font-bold tracking-wide border-b-2 transition-colors ${
            activeTab === tab.id
              ? 'text-white border-red-500'
              : 'text-gray-400 border-transparent hover:text-gray-200'
          }`}
        >
          {tab.label}
        </button>
      ))}
    </div>
  )
}
