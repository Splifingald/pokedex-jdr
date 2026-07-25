import { useState } from 'react'
import { AdminPanel } from './AdminPanel'
import { AdminPlayersPanel } from './AdminPlayersPanel'
import { AdminParametersPanel } from './AdminParametersPanel'
import { BUTTON_STYLE } from '../lib/buttonStyles'

type Section = 'import' | 'joueurs' | 'parametres'

interface Props {
  onImportSuccess: () => void
}

export function AdminTab({ onImportSuccess }: Props) {
  const [section, setSection] = useState<Section>('import')

  const sections: { id: Section; label: string }[] = [
    { id: 'import', label: 'Import CSV' },
    { id: 'joueurs', label: 'Joueurs' },
    { id: 'parametres', label: 'Paramètres' },
  ]

  return (
    <div className="flex-1 overflow-y-auto p-4">
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-2 mb-4 max-w-md">
        {sections.map((s) => (
          <button
            key={s.id}
            onClick={() => setSection(s.id)}
            className={`px-3 py-1.5 rounded text-sm font-bold ${section === s.id ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
          >
            {s.label}
          </button>
        ))}
      </div>

      {section === 'import' && <AdminPanel onImportSuccess={onImportSuccess} />}
      {section === 'joueurs' && <AdminPlayersPanel />}
      {section === 'parametres' && <AdminParametersPanel />}
    </div>
  )
}
