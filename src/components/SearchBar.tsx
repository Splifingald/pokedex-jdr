interface Props {
  search: string
  onSearchChange: (v: string) => void
  typeFilter: string
  onTypeFilterChange: (t: string) => void
  availableTypes: string[]
  onManualDiscover: () => void
}

export function SearchBar({
  search,
  onSearchChange,
  typeFilter,
  onTypeFilterChange,
  availableTypes,
  onManualDiscover,
}: Props) {
  return (
    <div className="px-3 py-2 bg-gray-800 border-b border-gray-700 flex flex-col gap-2 shrink-0">
      {/* Ligne 1 : input + bouton + */}
      <div className="flex gap-2">
        <div className="relative flex-1">
          <span className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-500 text-sm">🔍</span>
          <input
            type="text"
            value={search}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder="Rechercher..."
            className="w-full bg-gray-900 border border-gray-700 rounded pl-8 pr-3 py-1.5 text-white text-sm placeholder-gray-500 outline-none focus:border-red-500 transition-colors"
          />
          {search && (
            <button
              onClick={() => onSearchChange('')}
              className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-500 hover:text-white"
            >
              ✕
            </button>
          )}
        </div>

        {/* Bouton + pour découverte manuelle */}
        <button
          onClick={onManualDiscover}
          title="Ajouter un pokémon manuellement"
          className="w-9 h-9 bg-red-700 border border-red-500 text-white rounded flex items-center justify-center text-lg hover:bg-red-600 transition-colors shrink-0"
        >
          +
        </button>
      </div>

      {/* Ligne 2 : filtre par type */}
      {availableTypes.length > 0 && (
        <select
          value={typeFilter}
          onChange={(e) => onTypeFilterChange(e.target.value)}
          className="w-full bg-gray-900 border border-gray-700 rounded px-3 py-1.5 text-sm text-white outline-none focus:border-red-500 transition-colors"
        >
          <option value="">Tous les types</option>
          {availableTypes.map((t) => (
            <option key={t} value={t}>{t}</option>
          ))}
        </select>
      )}
    </div>
  )
}
