import { useState, useEffect } from 'react'
import { useMinigamesConfig } from '../hooks/useMinigamesConfig'
import { NumberInput } from './NumberInput'

const STAR_TIERS = [
  { key: 'star1', label: '1 étoile' },
  { key: 'star2', label: '2 étoiles' },
  { key: 'star3', label: '3 étoiles' },
] as const

export function AdminMagikarpPanel() {
  const { config, loading, updateConfig } = useMinigamesConfig()

  const [nom, setNom] = useState(config.magikarp_nom)
  const [iconUrl, setIconUrl] = useState(config.magikarp_icon_url)
  const [bannerUrl, setBannerUrl] = useState(config.magikarp_banner_url)
  const [numero, setNumero] = useState(config.magikarp_numero)

  useEffect(() => {
    setNom(config.magikarp_nom)
    setIconUrl(config.magikarp_icon_url)
    setBannerUrl(config.magikarp_banner_url)
    setNumero(config.magikarp_numero)
  }, [config])

  if (loading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
      <label className="flex items-center gap-2 text-sm text-ink-muted mb-4">
        <input
          type="checkbox"
          checked={config.magikarp_enabled}
          onChange={(e) => updateConfig({ magikarp_enabled: e.target.checked })}
          className="w-4 h-4"
        />
        <span className="font-bold text-base">🐟 Magikarp (tap game)</span>
      </label>

      <div className="flex flex-col gap-3">
        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Nom affiché</label>
          <input
            type="text"
            value={nom}
            onChange={(e) => setNom(e.target.value)}
            onBlur={() => updateConfig({ magikarp_nom: nom })}
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          />
        </div>
        <div className="flex gap-3">
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Icône (URL)</label>
            <input
              type="text"
              value={iconUrl}
              onChange={(e) => setIconUrl(e.target.value)}
              onBlur={() => updateConfig({ magikarp_icon_url: iconUrl })}
              placeholder="https://…"
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Bannière (URL)</label>
            <input
              type="text"
              value={bannerUrl}
              onChange={(e) => setBannerUrl(e.target.value)}
              onBlur={() => updateConfig({ magikarp_banner_url: bannerUrl })}
              placeholder="https://…"
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
        </div>

        <div className="flex gap-3">
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Numéro Pokédex ciblé (Magicarpe)</label>
            <input
              type="text"
              value={numero}
              onChange={(e) => setNumero(e.target.value)}
              onBlur={() => updateConfig({ magikarp_numero: numero })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
          <div className="flex-1">
            <label className="text-ink-muted-2 text-sm block mb-1">Durée de la partie (s)</label>
            <NumberInput
              min={1}
              fallback={config.magikarp_duration_seconds}
              value={config.magikarp_duration_seconds}
              onCommit={(v) => updateConfig({ magikarp_duration_seconds: Math.max(1, v) })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
        </div>

        <div>
          <p className="text-ink-muted-2 text-sm mb-2 font-bold">Paliers d'étoiles</p>
          <div className="flex flex-col gap-2">
            {STAR_TIERS.map(({ key, label }, i) => {
              const tapsKey = `magikarp_${key}_taps` as const
              const xpKey = `magikarp_${key}_xp` as const
              const prevTapsKey = i > 0 ? (`magikarp_${STAR_TIERS[i - 1].key}_taps` as const) : null
              return (
                <div key={key} className="flex gap-3 items-end">
                  <span className="text-ink-muted-2 text-sm w-16 shrink-0 pb-2.5">{'⭐'.repeat(i + 1)}</span>
                  <div className="flex-1">
                    <label className="text-ink-muted-2 text-xs block mb-1">Taps requis ({label})</label>
                    <NumberInput
                      min={1}
                      fallback={config[tapsKey]}
                      value={config[tapsKey]}
                      onCommit={(v) => {
                        const min = prevTapsKey ? config[prevTapsKey] : 1
                        updateConfig({ [tapsKey]: Math.max(min, v) })
                      }}
                      className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                    />
                  </div>
                  <div className="flex-1">
                    <label className="text-ink-muted-2 text-xs block mb-1">XP accordé</label>
                    <NumberInput
                      min={0}
                      fallback={config[xpKey]}
                      value={config[xpKey]}
                      onCommit={(v) => updateConfig({ [xpKey]: Math.max(0, v) })}
                      className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
                    />
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}
