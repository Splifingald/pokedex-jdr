import { useState } from 'react'
import { AdminPanel } from './AdminPanel'
import { AdminPlayersPanel } from './AdminPlayersPanel'
import { AdminParametersPanel } from './AdminParametersPanel'
import { AdminGiftingPanel } from './AdminGiftingPanel'
import { AdminCasinoPanel } from './AdminCasinoPanel'
import { AdminDisplayPanel } from './AdminDisplayPanel'
import { BUTTON_STYLE } from '../lib/buttonStyles'

type Section = 'import' | 'joueurs' | 'parametres' | 'cadeaux' | 'casino' | 'display'

interface Props {
  onImportSuccess: () => void
}

export function AdminTab({ onImportSuccess }: Props) {
  const [section, setSection] = useState<Section>('import')

  const sections: { id: Section; label: string }[] = [
    { id: 'import', label: 'Import CSV' },
    { id: 'joueurs', label: 'Joueurs' },
    { id: 'parametres', label: 'Paramètres' },
    { id: 'cadeaux', label: 'Cadeaux Pokémon' },
    { id: 'casino', label: 'Casino' },
    { id: 'display', label: 'Affichage' },
  ]

  return (
    <div className="flex-1 overflow-y-auto p-4">
      <div className="grid grid-cols-1 sm:grid-cols-6 gap-2 mb-4 max-w-xl">
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
      {section === 'cadeaux' && <AdminGiftingPanel />}
      {section === 'casino' && <AdminCasinoPanel />}
      {section === 'display' && <AdminDisplayPanel />}
    </div>
  )
}
