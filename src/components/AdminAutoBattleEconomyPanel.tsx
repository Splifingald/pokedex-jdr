import type { GiftTimerUnit } from '../types'
import { useAutoBattleConfig } from '../hooks/useAutoBattleConfig'
import { NumberInput } from './NumberInput'

export function AdminAutoBattleEconomyPanel() {
  const { config, loading, updateConfig } = useAutoBattleConfig()

  if (loading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">⚔️</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Combat Auto — Général</h3>
      </div>

      <div className="flex flex-col gap-3">
        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Nom affiché</label>
          <input
            type="text"
            value={config.nom}
            onChange={(e) => updateConfig({ nom: e.target.value })}
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
        </div>
        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Icône (URL)</label>
          <input
            type="text"
            value={config.icon_url}
            onChange={(e) => updateConfig({ icon_url: e.target.value })}
            placeholder="/website_icons/icon_battle_game.png"
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
        </div>

        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Icône du mode Auto (URL)</label>
          <input
            type="text"
            value={config.mode_icon_auto_url}
            onChange={(e) => updateConfig({ mode_icon_auto_url: e.target.value })}
            placeholder="/website_icons/icon_battle_auto.png"
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
        </div>
        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Icône du mode Manuel (URL)</label>
          <input
            type="text"
            value={config.mode_icon_manual_url}
            onChange={(e) => updateConfig({ mode_icon_manual_url: e.target.value })}
            placeholder="/website_icons/icon_battle_manual.png"
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
          <p className="text-ink-muted-2 text-xs mt-1">
            Affichées en haut à droite de la bannière de chaque parcours, selon son mode de jeu.
            Laissées vides, les icônes par défaut ci-dessus sont utilisées.
          </p>
        </div>

        <div className="border-t-2 border-[#cfc7a8] pt-3">
          <p className="text-ink-muted-2 text-sm font-bold mb-2">Ticket Combat (partagé entre toutes les variantes)</p>
        </div>

        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Tickets max en inventaire</label>
          <NumberInput
            min={1}
            fallback={config.ticket_max}
            value={config.ticket_max}
            onCommit={(v) => updateConfig({ ticket_max: Math.max(1, v) })}
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
        </div>
        <div className="flex gap-3">
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Temps entre 2 tickets gratuits</label>
            <NumberInput
              min={0}
              fallback={config.ticket_regen_amount}
              value={config.ticket_regen_amount}
              onCommit={(v) => updateConfig({ ticket_regen_amount: Math.max(0, v) })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Unité</label>
            <select
              value={config.ticket_regen_unit}
              onChange={(e) => updateConfig({ ticket_regen_unit: e.target.value as GiftTimerUnit })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            >
              <option value="hours">Heures</option>
              <option value="minutes">Minutes</option>
            </select>
          </div>
        </div>
        <div className="flex gap-3">
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Coût d'achat d'un ticket (₽)</label>
            <NumberInput
              min={0}
              fallback={config.ticket_buy_cost}
              value={config.ticket_buy_cost}
              onCommit={(v) => updateConfig({ ticket_buy_cost: Math.max(0, v) })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
            <p className="text-ink-muted-2 text-xs mt-1">À 0, l'achat de tickets est masqué côté joueur.</p>
          </div>
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Achats max / jour</label>
            <NumberInput
              min={0}
              fallback={config.ticket_daily_buy_cap}
              value={config.ticket_daily_buy_cap}
              onCommit={(v) => updateConfig({ ticket_daily_buy_cap: Math.max(0, v) })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
        </div>
        <label className="flex items-center gap-2 text-sm text-ink-muted">
          <input
            type="checkbox"
            checked={config.ticket_full_notify_enabled}
            onChange={(e) => updateConfig({ ticket_full_notify_enabled: e.target.checked })}
            className="w-4 h-4"
          />
          <span>Notifier les joueurs quand leurs tickets sont pleins</span>
        </label>

        <div className="border-t-2 border-[#cfc7a8] pt-3">
          <label className="flex items-center gap-2 text-sm text-ink-muted">
            <input
              type="checkbox"
              checked={config.precision_enabled}
              onChange={(e) => updateConfig({ precision_enabled: e.target.checked })}
              className="w-4 h-4"
            />
            <span>Activer le système de précision (désactivé, toute capacité touche à coup sûr)</span>
          </label>
          <label className="flex items-center gap-2 text-sm text-ink-muted mt-2">
            <input
              type="checkbox"
              checked={config.talents_enabled}
              onChange={(e) => updateConfig({ talents_enabled: e.target.checked })}
              className="w-4 h-4"
            />
            <span>Activer les talents d'espèce (désactivés, aucun talent ne se déclenche)</span>
          </label>
        </div>
      </div>
    </div>
  )
}
