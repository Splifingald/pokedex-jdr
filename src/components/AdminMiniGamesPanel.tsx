import { useState } from 'react'
import { AdminCasinoPanel } from './AdminCasinoPanel'
import { AdminMinigamesEconomyPanel } from './AdminMinigamesEconomyPanel'
import { AdminMagikarpPanel } from './AdminMagikarpPanel'
import { AdminMiningPanel } from './AdminMiningPanel'
import { BUTTON_STYLE } from '../lib/buttonStyles'

type SubSection = 'casino' | 'magikarp' | 'mining'

const SUB_SECTIONS: { id: SubSection; label: string }[] = [
  { id: 'casino', label: '🎰 Casino' },
  { id: 'magikarp', label: '🐟 Magikarp' },
  { id: 'mining', label: '⛏️ Fouille' },
]

export function AdminMiniGamesPanel() {
  const [sub, setSub] = useState<SubSection>('casino')

  return (
    <div className="flex flex-col gap-4 w-full">
      <div className="flex flex-wrap gap-2">
        {SUB_SECTIONS.map((s) => (
          <button
            key={s.id}
            onClick={() => setSub(s.id)}
            className={`px-3 py-1.5 rounded text-sm font-bold ${sub === s.id ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
          >
            {s.label}
          </button>
        ))}
      </div>

      {sub === 'casino' && <AdminCasinoPanel />}

      {sub === 'magikarp' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 items-start">
          <AdminMinigamesEconomyPanel />
          <AdminMagikarpPanel />
        </div>
      )}

      {sub === 'mining' && <AdminMiningPanel />}
    </div>
  )
}
