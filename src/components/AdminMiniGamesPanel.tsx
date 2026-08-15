import { useState } from 'react'
import { AdminCasinoPanel } from './AdminCasinoPanel'
import { AdminMinigamesEconomyPanel } from './AdminMinigamesEconomyPanel'
import { AdminMagikarpPanel } from './AdminMagikarpPanel'
import { AdminMiningPanel } from './AdminMiningPanel'
import { AdminPensionPanel } from './AdminPensionPanel'
import { AdminSafariPanel } from './AdminSafariPanel'
import { AdminAutoBattlePanel } from './AdminAutoBattlePanel'
import { AdminCombatAbilitiesPanel } from './AdminCombatAbilitiesPanel'
import { AdminAutoBattleTalentsPanel } from './AdminAutoBattleTalentsPanel'
import { AdminAutoBattleWeathersPanel } from './AdminAutoBattleWeathersPanel'
import { AdminPvpPanel } from './AdminPvpPanel'
import { BUTTON_STYLE } from '../lib/buttonStyles'

type SubSection = 'casino' | 'magikarp' | 'mining' | 'pension' | 'safari' | 'combat-abilities' | 'talents' | 'weather' | 'autobattle' | 'pvp'

const SUB_SECTIONS: { id: SubSection; label: string }[] = [
  { id: 'casino', label: '🎰 Casino' },
  { id: 'magikarp', label: '🐟 Magikarp' },
  { id: 'mining', label: '⛏️ Fouille' },
  { id: 'pension', label: '🏡 Pension' },
  { id: 'safari', label: '🦁 Safari' },
  // Capacités de combat en premier des 3 sections Combat : elles s'appliquent
  // aux deux modes (JcE et JcJ), qui suivent.
  { id: 'combat-abilities', label: '✨ Capacités de combat' },
  // Même portée que les capacités de combat (les deux modes), mais par ESPÈCE.
  { id: 'talents', label: '🧬 Talents' },
  // Effets de TERRAIN, déclenchés par un talent ou une capacité — d'où sa place
  // juste après les deux, et avant les réglages propres à chaque mode.
  { id: 'weather', label: '🌦️ Météo' },
  { id: 'autobattle', label: '⚔️ Combat JcE' },
  { id: 'pvp', label: '🛡️ Combat JcJ' },
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

      {sub === 'pension' && <AdminPensionPanel />}

      {sub === 'safari' && <AdminSafariPanel />}

      {sub === 'combat-abilities' && <AdminCombatAbilitiesPanel />}

      {sub === 'talents' && <AdminAutoBattleTalentsPanel />}

      {sub === 'weather' && <AdminAutoBattleWeathersPanel />}

      {sub === 'autobattle' && <AdminAutoBattlePanel />}

      {sub === 'pvp' && <AdminPvpPanel />}
    </div>
  )
}
