import type { GiftTimerUnit } from '../types'
import { usePensionConfig } from '../hooks/usePensionConfig'
import { NumberInput } from './NumberInput'

export function AdminPensionConfigPanel() {
  const { config, loading, updateConfig } = usePensionConfig()

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
        <span className="text-2xl">🏡</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Pension Pokémon — Réglages généraux</h3>
      </div>

      <div className="flex flex-col gap-3">
        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Nom affiché</label>
          <input
            type="text"
            defaultValue={config.nom}
            onBlur={(e) => { const v = e.target.value.trim(); if (v && v !== config.nom) updateConfig({ nom: v }) }}
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
        </div>

        <div className="flex gap-3">
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Lien de la bannière</label>
            <input
              type="text"
              defaultValue={config.banner_url}
              onBlur={(e) => updateConfig({ banner_url: e.target.value.trim() })}
              placeholder="https://…"
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
          <div className="w-40 shrink-0">
            <label className="text-ink-muted-2 text-sm block mb-1">Places totales</label>
            <NumberInput
              min={1}
              fallback={config.capacity_total}
              value={config.capacity_total}
              onCommit={(v) => updateConfig({ capacity_total: Math.max(1, v) })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
        </div>

        <div className="border-t-2 border-[#cfc7a8] pt-3">
          <p className="text-ink-muted-2 text-xs mb-2">XP (fixe pour tous — l'intervalle est surchargeable par groupe)</p>
          <div className="flex gap-3">
            <div className="flex-1">
              <label className="text-ink-muted-2 text-sm block mb-1">XP gagnée par tick</label>
              <NumberInput
                min={0}
                fallback={config.tick_xp_amount}
                value={config.tick_xp_amount}
                onCommit={(v) => updateConfig({ tick_xp_amount: Math.max(0, v) })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
            <div className="flex-1">
              <label className="text-ink-muted-2 text-sm block mb-1">Intervalle par défaut</label>
              <NumberInput
                min={0}
                fallback={config.tick_interval_amount}
                value={config.tick_interval_amount}
                onCommit={(v) => updateConfig({ tick_interval_amount: Math.max(0, v) })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
            <div className="flex-1">
              <label className="text-ink-muted-2 text-sm block mb-1">Unité</label>
              <select
                value={config.tick_interval_unit}
                onChange={(e) => updateConfig({ tick_interval_unit: e.target.value as GiftTimerUnit })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              >
                <option value="hours">Heures</option>
                <option value="minutes">Minutes</option>
              </select>
            </div>
          </div>
          <div className="mt-2">
            <label className="text-ink-muted-2 text-sm block mb-1">Plafond XP à vie par défaut</label>
            <NumberInput
              min={0}
              fallback={config.default_lifetime_xp_cap}
              value={config.default_lifetime_xp_cap}
              onCommit={(v) => updateConfig({ default_lifetime_xp_cap: Math.max(0, v) })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
            <p className="text-ink-muted-2 text-xs mt-1">Une fois atteint (cumulé sur toute la vie du pokémon), il ne peut plus jamais retourner en pension.</p>
          </div>
        </div>

        <div className="border-t-2 border-[#cfc7a8] pt-3">
          <p className="text-ink-muted-2 text-xs mb-2">Éclosion — fourchette par défaut (repli si un groupe n'a pas de réglage propre)</p>
          <div className="flex gap-3">
            <div className="flex-1">
              <label className="text-ink-muted-2 text-sm block mb-1">Minimum</label>
              <NumberInput
                min={0}
                fallback={config.default_hatch_timer_min}
                value={config.default_hatch_timer_min}
                onCommit={(v) => updateConfig({ default_hatch_timer_min: Math.max(0, v) })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
            <div className="flex-1">
              <label className="text-ink-muted-2 text-sm block mb-1">Maximum</label>
              <NumberInput
                min={0}
                fallback={config.default_hatch_timer_max}
                value={config.default_hatch_timer_max}
                onCommit={(v) => updateConfig({ default_hatch_timer_max: Math.max(0, v) })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
            <div className="flex-1">
              <label className="text-ink-muted-2 text-sm block mb-1">Unité</label>
              <select
                value={config.default_hatch_timer_unit}
                onChange={(e) => updateConfig({ default_hatch_timer_unit: e.target.value as GiftTimerUnit })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              >
                <option value="hours">Heures</option>
                <option value="minutes">Minutes</option>
              </select>
            </div>
          </div>
        </div>

        <div className="border-t-2 border-[#cfc7a8] pt-3">
          <label className="text-ink-muted-2 text-sm block mb-1">Texte du popup "Comment fonctionne la Pension ?" (une ligne = une puce)</label>
          <textarea
            defaultValue={config.info_text}
            onBlur={(e) => { const v = e.target.value; if (v.trim() && v !== config.info_text) updateConfig({ info_text: v }) }}
            rows={5}
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none resize-y"
          />
        </div>
      </div>
    </div>
  )
}
