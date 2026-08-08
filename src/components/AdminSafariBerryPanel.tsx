import { useSafariConfig } from '../hooks/useSafariConfig'
import { NumberInput } from './NumberInput'

export function AdminSafariBerryPanel() {
  const { config, loading, updateConfig } = useSafariConfig()

  if (loading) return null

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">🍇</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Baie Framby — effet sur la jauge</h3>
      </div>
      <div className="flex gap-3">
        <div className="flex-1">
          <label className="text-ink-muted-2 text-sm block mb-1">Augmentation minimum</label>
          <NumberInput
            min={0}
            fallback={config.berry_min_increase}
            value={config.berry_min_increase}
            onCommit={(v) => updateConfig({ berry_min_increase: Math.min(Math.max(0, v), config.berry_max_increase) })}
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
        </div>
        <div className="flex-1">
          <label className="text-ink-muted-2 text-sm block mb-1">Augmentation maximum</label>
          <NumberInput
            min={0}
            fallback={config.berry_max_increase}
            value={config.berry_max_increase}
            onCommit={(v) => updateConfig({ berry_max_increase: Math.max(config.berry_min_increase, v) })}
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
        </div>
      </div>
    </div>
  )
}
