import type { GiftTimerUnit } from '../types'
import { useSafariConfig } from '../hooks/useSafariConfig'
import { NumberInput } from './NumberInput'

export function AdminSafariGeneralPanel() {
  const { config, loading, updateConfig } = useSafariConfig()

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
        <span className="text-2xl">🦁</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Safari — Général</h3>
      </div>

      <div className="flex flex-col gap-3">
        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Nom affiché</label>
          <input
            type="text"
            defaultValue={config.nom}
            onBlur={(e) => updateConfig({ nom: e.target.value })}
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
        </div>
        <div className="flex gap-3">
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Icône (URL)</label>
            <input
              type="text"
              defaultValue={config.icon_url}
              onBlur={(e) => updateConfig({ icon_url: e.target.value })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Bannière (URL)</label>
            <input
              type="text"
              defaultValue={config.banner_url}
              onBlur={(e) => updateConfig({ banner_url: e.target.value })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
        </div>

        <div className="flex gap-3">
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Durée d'une session</label>
            <NumberInput
              min={1}
              fallback={config.session_duration_amount}
              value={config.session_duration_amount}
              onCommit={(v) => updateConfig({ session_duration_amount: Math.max(1, v) })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Unité</label>
            <select
              value={config.session_duration_unit}
              onChange={(e) => updateConfig({ session_duration_unit: e.target.value as GiftTimerUnit })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            >
              <option value="hours">Heures</option>
              <option value="minutes">Minutes</option>
            </select>
          </div>
        </div>

        <div className="border-t-2 border-[#cfc7a8] pt-3">
          <p className="text-ink-muted-2 text-sm mb-2">Baie Framby — récompense automatique</p>
          <div className="flex gap-3">
            <div className="flex-1">
              <label className="text-ink-muted-2 text-sm block mb-1">Intervalle (0 = désactivé)</label>
              <NumberInput
                min={0}
                fallback={config.berry_reward_interval_amount}
                value={config.berry_reward_interval_amount}
                onCommit={(v) => updateConfig({ berry_reward_interval_amount: Math.max(0, v) })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
            <div className="flex-1">
              <label className="text-ink-muted-2 text-sm block mb-1">Unité</label>
              <select
                value={config.berry_reward_interval_unit}
                onChange={(e) => updateConfig({ berry_reward_interval_unit: e.target.value as GiftTimerUnit })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              >
                <option value="hours">Heures</option>
                <option value="minutes">Minutes</option>
              </select>
            </div>
            <div className="flex-1">
              <label className="text-ink-muted-2 text-sm block mb-1">Plafond en inventaire</label>
              <NumberInput
                min={1}
                fallback={config.berry_reward_max}
                value={config.berry_reward_max}
                onCommit={(v) => updateConfig({ berry_reward_max: Math.max(1, v) })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
          </div>
        </div>

        <div className="border-t-2 border-[#cfc7a8] pt-3">
          <p className="text-ink-muted-2 text-sm mb-2">Safari Ball — récompense automatique</p>
          <div className="flex gap-3">
            <div className="flex-1">
              <label className="text-ink-muted-2 text-sm block mb-1">Intervalle (0 = désactivé)</label>
              <NumberInput
                min={0}
                fallback={config.ball_reward_interval_amount}
                value={config.ball_reward_interval_amount}
                onCommit={(v) => updateConfig({ ball_reward_interval_amount: Math.max(0, v) })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
            <div className="flex-1">
              <label className="text-ink-muted-2 text-sm block mb-1">Unité</label>
              <select
                value={config.ball_reward_interval_unit}
                onChange={(e) => updateConfig({ ball_reward_interval_unit: e.target.value as GiftTimerUnit })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              >
                <option value="hours">Heures</option>
                <option value="minutes">Minutes</option>
              </select>
            </div>
            <div className="flex-1">
              <label className="text-ink-muted-2 text-sm block mb-1">Plafond en inventaire</label>
              <NumberInput
                min={1}
                fallback={config.ball_reward_max}
                value={config.ball_reward_max}
                onCommit={(v) => updateConfig({ ball_reward_max: Math.max(1, v) })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
