import { useState } from 'react'
import { useOnlineState } from '../hooks/useOnlineState'
import { AdminDisplayPanel } from './AdminDisplayPanel'
import { AdminOnlineSessionPanel } from './online/AdminOnlineSessionPanel'
import { AdminOnlineBattlePanel } from './online/AdminOnlineBattlePanel'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PANEL } from '../lib/panelStyles'

type Section = 'session' | 'affichage' | 'bataille'

const SECTIONS: { id: Section; label: string }[] = [
  { id: 'session', label: '📅 Session' },
  { id: 'affichage', label: '🖼️ Affichage' },
  { id: 'bataille', label: '⚔️ Bataille' },
]

// Onglet Admin « En ligne » : l'ancien onglet Affichage y est absorbé tel quel,
// parce que le choix du mode (affichage classique ou plateau de bataille) et
// les réglages de séance se pilotent au même moment, en début de partie.
export function AdminOnlinePanel() {
  const [section, setSection] = useState<Section>('session')
  const online = useOnlineState()

  return (
    <div className="flex flex-col gap-4">
      <div className={`${PANEL} p-4`}>
        <p className="text-ink-muted-2 text-sm mb-2">Mode de l'écran partagé (/display et appareils des joueurs)</p>
        <div className="grid grid-cols-2 gap-2 max-w-md">
          <button
            onClick={() => void online.updateOnlineState({ mode: 'display' })}
            className={`py-2 rounded text-sm font-bold ${online.state.mode === 'display' ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
          >
            🖼️ Affichage
          </button>
          <button
            onClick={() => void online.updateOnlineState({ mode: 'battle', battle_generation: online.state.battle_generation + 1 })}
            className={`py-2 rounded text-sm font-bold ${online.state.mode === 'battle' ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
          >
            ⚔️ Bataille
          </button>
        </div>
        {online.state.mode === 'battle' && (
          <p className="text-ink-muted-2 text-xs mt-2">
            Le plateau s'ouvre automatiquement chez tous les joueurs connectés.
          </p>
        )}
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
        {SECTIONS.map((s) => (
          <button
            key={s.id}
            onClick={() => setSection(s.id)}
            className={`px-3 py-1.5 rounded text-sm font-bold ${section === s.id ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
          >
            {s.label}
          </button>
        ))}
      </div>

      {section === 'session' && <AdminOnlineSessionPanel online={online} />}
      {section === 'affichage' && <AdminDisplayPanel />}
      {section === 'bataille' && <AdminOnlineBattlePanel online={online} />}
    </div>
  )
}
