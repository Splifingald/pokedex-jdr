import { useState, useEffect, useMemo } from 'react'
import type { GiftTimerUnit } from '../types'
import { useCasinoConfig } from '../hooks/useCasinoConfig'
import { NumberInput } from './NumberInput'
import { CASINO_ICON } from '../lib/icons'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import {
  computeSlotExpectedValue, computeSlotMaxPayout,
  computeDiceRoundWinProbability, computeDiceExpectedValue, computeDiceMaxPayout,
} from '../lib/casino'

export function AdminCasinoPanel() {
  const { config, loading, updateConfig } = useCasinoConfig()

  const slotStats = useMemo(
    () => ({ ev: computeSlotExpectedValue(config), max: computeSlotMaxPayout(config) }),
    [config]
  )
  const diceStats = useMemo(
    () => ({
      winProb: computeDiceRoundWinProbability(config),
      ev: computeDiceExpectedValue(config),
      max: computeDiceMaxPayout(config),
    }),
    [config]
  )

  const [slotsNom, setSlotsNom] = useState(config.slots_nom)
  const [slotsIconUrl, setSlotsIconUrl] = useState(config.slots_icon_url)
  const [slotsBannerUrl, setSlotsBannerUrl] = useState(config.slots_banner_url)
  const [diceNom, setDiceNom] = useState(config.dice_nom)
  const [diceIconUrl, setDiceIconUrl] = useState(config.dice_icon_url)
  const [diceBannerUrl, setDiceBannerUrl] = useState(config.dice_banner_url)
  const [diceOpponentName, setDiceOpponentName] = useState(config.dice_opponent_name)
  const [diceOpponentImageUrl, setDiceOpponentImageUrl] = useState(config.dice_opponent_image_url)

  useEffect(() => {
    setSlotsNom(config.slots_nom)
    setSlotsIconUrl(config.slots_icon_url)
    setSlotsBannerUrl(config.slots_banner_url)
    setDiceNom(config.dice_nom)
    setDiceIconUrl(config.dice_icon_url)
    setDiceBannerUrl(config.dice_banner_url)
    setDiceOpponentName(config.dice_opponent_name)
    setDiceOpponentImageUrl(config.dice_opponent_image_url)
  }, [config])

  if (loading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] max-w-2xl w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] max-w-2xl w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">🎰</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Casino</h3>
      </div>

      <div className="flex flex-col gap-6">
        {/* ── Économie des tickets ─────────────────────────────── */}
        <div>
          <p className="text-ink-muted-2 text-sm mb-2 font-bold">Économie des tickets</p>
          <div className="flex flex-col gap-3">
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
          </div>
        </div>

        {/* ── Chance de Miaouss ────────────────────────────────── */}
        <div className="border-t-2 border-[#cfc7a8] pt-4">
          <label className="flex items-center gap-2 text-sm text-ink-muted mb-2">
            <input
              type="checkbox"
              checked={config.slots_enabled}
              onChange={(e) => updateConfig({ slots_enabled: e.target.checked })}
              className="w-4 h-4"
            />
            <span className="font-bold">Chance de Miaouss (machine à sous)</span>
          </label>

          <div className="flex flex-col gap-3">
            <div>
              <label className="text-ink-muted-2 text-sm block mb-1">Nom affiché</label>
              <input
                type="text"
                value={slotsNom}
                onChange={(e) => setSlotsNom(e.target.value)}
                onBlur={() => updateConfig({ slots_nom: slotsNom })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
            <div className="flex gap-3">
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Icône (URL)</label>
                <input
                  type="text"
                  value={slotsIconUrl}
                  onChange={(e) => setSlotsIconUrl(e.target.value)}
                  onBlur={() => updateConfig({ slots_icon_url: slotsIconUrl })}
                  placeholder="https://…"
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Bannière (URL)</label>
                <input
                  type="text"
                  value={slotsBannerUrl}
                  onChange={(e) => setSlotsBannerUrl(e.target.value)}
                  onBlur={() => updateConfig({ slots_banner_url: slotsBannerUrl })}
                  placeholder="https://…"
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
            </div>

            <p className="text-ink-muted-2 text-sm mb-1">Valeurs des symboles (₽)</p>
            <div className="flex gap-2">
              {(
                [
                  ['pokeball', 'slots_pokeball_value'],
                  ['superball', 'slots_superball_value'],
                  ['hyperball', 'slots_hyperball_value'],
                  ['masterball', 'slots_masterball_value'],
                ] as const
              ).map(([symbol, key]) => (
                <div key={symbol} className="flex-1 flex flex-col items-center gap-1">
                  <img src={CASINO_ICON[symbol]} alt={symbol} className="w-8 h-8 object-contain pixelated" />
                  <NumberInput
                    min={0}
                    fallback={config[key]}
                    value={config[key]}
                    onCommit={(v) => updateConfig({ [key]: Math.max(0, v) })}
                    className="w-full bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
                  />
                </div>
              ))}
            </div>

            <div>
              <p className="text-ink-muted-2 text-sm mb-1">Probabilité de tirage (poids relatif)</p>
              <div className="flex gap-2">
                {(
                  [
                    ['pokeball', 'slots_pokeball_weight'],
                    ['superball', 'slots_superball_weight'],
                    ['hyperball', 'slots_hyperball_weight'],
                    ['masterball', 'slots_masterball_weight'],
                  ] as const
                ).map(([symbol, key]) => {
                  const weightTotal = config.slots_pokeball_weight + config.slots_superball_weight + config.slots_hyperball_weight + config.slots_masterball_weight
                  const pct = weightTotal > 0 ? Math.round((config[key] / weightTotal) * 100) : 0
                  return (
                    <div key={symbol} className="flex-1 flex flex-col items-center gap-1">
                      <img src={CASINO_ICON[symbol]} alt={symbol} className="w-8 h-8 object-contain pixelated" />
                      <NumberInput
                        min={0}
                        fallback={config[key]}
                        value={config[key]}
                        onCommit={(v) => updateConfig({ [key]: Math.max(0, v) })}
                        className="w-full bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
                      />
                      <span className="text-ink-muted-2 text-xs">{pct}%</span>
                    </div>
                  )
                })}
              </div>
            </div>

            <div className="flex gap-3">
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Multiplicateur 2 identiques</label>
                <NumberInput
                  min={1}
                  fallback={config.slots_match2_multiplier}
                  value={config.slots_match2_multiplier}
                  onCommit={(v) => updateConfig({ slots_match2_multiplier: Math.max(1, v) })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Multiplicateur 3 identiques</label>
                <NumberInput
                  min={1}
                  fallback={config.slots_match3_multiplier}
                  value={config.slots_match3_multiplier}
                  onCommit={(v) => updateConfig({ slots_match3_multiplier: Math.max(1, v) })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
            </div>

            <div className={`p-3 rounded ${PIXEL_BORDER_SM} bg-white/60 text-xs text-ink-muted-2 flex justify-between`}>
              <span>Espérance de gain / partie : <strong className="text-ink">{slotStats.ev.toFixed(1)} ₽</strong></span>
              <span>Gain max possible : <strong className="text-ink">{slotStats.max} ₽</strong></span>
            </div>
          </div>
        </div>

        {/* ── Dé Chance ────────────────────────────────────────── */}
        <div className="border-t-2 border-[#cfc7a8] pt-4">
          <label className="flex items-center gap-2 text-sm text-ink-muted mb-2">
            <input
              type="checkbox"
              checked={config.dice_enabled}
              onChange={(e) => updateConfig({ dice_enabled: e.target.checked })}
              className="w-4 h-4"
            />
            <span className="font-bold">Dé Chance (dés contre l'IA)</span>
          </label>

          <div className="flex flex-col gap-3">
            <div>
              <label className="text-ink-muted-2 text-sm block mb-1">Nom affiché</label>
              <input
                type="text"
                value={diceNom}
                onChange={(e) => setDiceNom(e.target.value)}
                onBlur={() => updateConfig({ dice_nom: diceNom })}
                className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
              />
            </div>
            <div className="flex gap-3">
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Icône (URL)</label>
                <input
                  type="text"
                  value={diceIconUrl}
                  onChange={(e) => setDiceIconUrl(e.target.value)}
                  onBlur={() => updateConfig({ dice_icon_url: diceIconUrl })}
                  placeholder="https://…"
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Bannière (URL)</label>
                <input
                  type="text"
                  value={diceBannerUrl}
                  onChange={(e) => setDiceBannerUrl(e.target.value)}
                  onBlur={() => updateConfig({ dice_banner_url: diceBannerUrl })}
                  placeholder="https://…"
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
            </div>

            <div className="flex gap-3">
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Nom de l'adversaire</label>
                <input
                  type="text"
                  value={diceOpponentName}
                  onChange={(e) => setDiceOpponentName(e.target.value)}
                  onBlur={() => updateConfig({ dice_opponent_name: diceOpponentName })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Image de l'adversaire (URL)</label>
                <input
                  type="text"
                  value={diceOpponentImageUrl}
                  onChange={(e) => setDiceOpponentImageUrl(e.target.value)}
                  onBlur={() => updateConfig({ dice_opponent_image_url: diceOpponentImageUrl })}
                  placeholder="https://…"
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
            </div>

            <div className="flex gap-3">
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Manches max</label>
                <NumberInput
                  min={1}
                  fallback={config.dice_max_rounds}
                  value={config.dice_max_rounds}
                  onCommit={(v) => updateConfig({ dice_max_rounds: Math.max(1, v) })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Gain initial (₽)</label>
                <NumberInput
                  min={0}
                  fallback={config.dice_initial_gain}
                  value={config.dice_initial_gain}
                  onCommit={(v) => updateConfig({ dice_initial_gain: Math.max(0, v) })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
            </div>
            <div className="flex gap-3">
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Cible IA min</label>
                <NumberInput
                  min={2}
                  fallback={config.dice_ai_target_min}
                  value={config.dice_ai_target_min}
                  onCommit={(v) => updateConfig({ dice_ai_target_min: Math.min(v, config.dice_ai_target_max) })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
              <div className="flex-1">
                <label className="text-ink-muted-2 text-sm block mb-1">Cible IA max</label>
                <NumberInput
                  min={2}
                  fallback={config.dice_ai_target_max}
                  value={config.dice_ai_target_max}
                  onCommit={(v) => updateConfig({ dice_ai_target_max: Math.max(v, config.dice_ai_target_min) })}
                  className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                />
              </div>
            </div>

            <div className={`p-3 rounded ${PIXEL_BORDER_SM} bg-white/60 text-xs text-ink-muted-2 flex flex-col gap-1`}>
              <span>Probabilité de gagner une manche (stratégie prudente) : <strong className="text-ink">{Math.round(diceStats.winProb * 100)}%</strong></span>
              <div className="flex justify-between">
                <span>Espérance de gain (en poussant jusqu'au bout) : <strong className="text-ink">{diceStats.ev.toFixed(1)} ₽</strong></span>
                <span>Gain max possible : <strong className="text-ink">{diceStats.max} ₽</strong></span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
