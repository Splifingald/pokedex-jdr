import { useState } from 'react'
import { AdminPanel } from './AdminPanel'
import { AdminPlayersPanel } from './AdminPlayersPanel'
import { AdminParametersPanel } from './AdminParametersPanel'

type Section = 'import' | 'joueurs' | 'parametres'

interface Props {
  onImportSuccess: () => void
  onLogout: () => void
}

export function AdminTab({ onImportSuccess, onLogout }: Props) {
  const [section, setSection] = useState<Section>('import')

  const sections: { id: Section; label: string }[] = [
    { id: 'import', label: 'Import CSV' },
    { id: 'joueurs', label: 'Joueurs' },
    { id: 'parametres', label: 'Paramètres' },
  ]

  return (
    <div className="flex-1 overflow-y-auto p-4">
      <div className="flex gap-2 mb-4 max-w-sm">
        {sections.map((s) => (
          <button
            key={s.id}
            onClick={() => setSection(s.id)}
            className={`px-3 py-1.5 text-sm rounded border transition-colors ${
              section === s.id
                ? 'bg-yellow-900/40 border-yellow-600 text-yellow-300'
                : 'border-gray-700 text-gray-400 hover:text-gray-200'
            }`}
          >
            {s.label}
          </button>
        ))}
      </div>

      {section === 'import' && <AdminPanel onImportSuccess={onImportSuccess} onLogout={onLogout} />}
      {section === 'joueurs' && <AdminPlayersPanel />}
      {section === 'parametres' && <AdminParametersPanel />}
    </div>
  )
}
