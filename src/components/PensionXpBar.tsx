import type { Milestone } from '../lib/xpBonuses'

interface Props {
  /** XP "en direct" à afficher (committed + estimation depuis le dernier tick serveur) */
  xp: number
  /** XP supplémentaire que la pension pourrait encore apporter à partir de maintenant */
  remainingCap: number
  maxXp: number | null
  milestones?: Milestone[]
  /** Grille de pension (cartes compactes) : masque les drapeaux de palier, garde juste la barre */
  compact?: boolean
}

// Variante en lecture seule de XpGauge (pas de drag/clic) : la barre affiche,
// dans une même piste, la position XP en direct (bleu, plein) puis un second
// segment (orange, translucide) montrant jusqu'où la pension pourrait encore
// faire progresser ce pokémon à partir d'ici.
export function PensionXpBar({ xp, remainingCap, maxXp, milestones = [], compact = false }: Props) {
  const trackMax = maxXp ?? xp + remainingCap
  const pct = (v: number) => (trackMax > 0 ? Math.max(0, Math.min(100, (v / trackMax) * 100)) : 0)
  const livePct = pct(xp)
  const capEnd = maxXp != null ? Math.min(maxXp, xp + remainingCap) : xp + remainingCap
  const capPct = pct(capEnd)

  return (
    <div>
      {!compact && milestones.length > 0 && (
        <div className="relative h-3 mb-1">
          {milestones.map((m) => (
            <div
              key={m.xp}
              className="absolute bottom-0 z-10"
              style={{ left: `${pct(m.xp)}%`, transform: 'translateX(-50%)' }}
              title={m.label}
            >
              <div className="w-0 h-0 border-l-[4px] border-l-transparent border-r-[4px] border-r-transparent border-t-[4px] border-t-xp-blue" />
            </div>
          ))}
        </div>
      )}

      <div className="h-3.5 rounded-full bg-[#cfc7a8] border border-ink overflow-hidden relative">
        <div className="absolute inset-y-0 left-0 bg-xp-blue transition-all" style={{ width: `${livePct}%` }} />
        <div
          className="absolute inset-y-0 bg-green-500/70 transition-all"
          style={{ left: `${livePct}%`, width: `${Math.max(0, capPct - livePct)}%` }}
        />
      </div>

      <div className="flex items-center justify-between mt-1 text-sm">
        <span className="text-ink-muted-2">XP</span>
        <span className="text-xp-blue font-bold">{xp}{maxXp != null ? ` / ${maxXp}` : ''}</span>
      </div>
    </div>
  )
}
