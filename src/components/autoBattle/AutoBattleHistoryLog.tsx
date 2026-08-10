import { PIXEL_BORDER_SM } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

export interface AutoBattleHistoryEntryData {
  id: number
  /** Temps écoulé depuis le début du combat (ms), pas une heure murale — voir AutoBattleScreen. */
  elapsedMs: number
  side: 'player' | 'opponent'
  pokemonName: string
  iconSrc?: string
  /** Texte simple (pas de mention de statut à mettre en couleur) */
  text?: string
  /** Texte découpé autour d'une mention de statut, affichée en gras dans sa couleur (voir getStatusEffectDisplay) */
  statusText?: { before: string; statusLabel: string; statusColor: string; after: string }
  damage?: number
  heal?: number
  superEffective?: boolean
  /** Debug info: base precision (1-10) before status effects, used in admin mode */
  debugBasePrecision?: number
  /** Debug info: effective precision (1-10) after status effects, used in admin mode */
  debugEffectivePrecision?: number
  /** Debug info: dice roll value (0-max), used in admin mode */
  debugDiceRoll?: number
  /** Debug info: status effect affecting precision if any, used in admin mode */
  debugPrecisionStatus?: string
}

function formatElapsed(ms: number): string {
  const totalSeconds = Math.max(0, Math.floor(ms / 1000))
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60
  return `${minutes}:${String(seconds).padStart(2, '0')}`
}

interface Props {
  entries: AutoBattleHistoryEntryData[]
  onHide?: () => void
  className?: string
  isAdmin?: boolean
}

// Historique local du combat (jamais persisté en base, voir AutoBattleScreen)
// — construit en direct pendant la relecture des tours, entrées les plus
// récentes en tête, toujours affiché sous l'arène (mobile ET desktop).
export function AutoBattleHistoryLog({ entries, onHide, className = '', isAdmin = false }: Props) {
  return (
    <div className={`flex flex-col gap-2 min-h-0 ${className}`}>
      <div className="flex items-center justify-between shrink-0">
        <p className="text-ink-muted-2 text-xs font-bold">Historique du combat</p>
        {onHide && (
          <button onClick={onHide} className={`text-xs px-2 py-0.5 rounded ${BUTTON_STYLE.gray}`}>Masquer</button>
        )}
      </div>
      <div className="flex flex-col gap-1.5 overflow-y-auto min-h-0 max-h-48">
        {entries.length === 0 ? (
          <p className="text-ink-muted-2 text-xs italic">Le combat commence…</p>
        ) : (
          entries.map((e) => (
            <div
              key={e.id}
              className={`flex items-start gap-2 p-1.5 rounded ${PIXEL_BORDER_SM} bg-white shrink-0 border-l-4 ${e.side === 'opponent' ? 'border-l-hp-red' : 'border-l-xp-blue'}`}
            >
              <div className="w-5 h-5 shrink-0 flex items-center justify-center mt-0.5">
                {e.iconSrc ? (
                  <img src={e.iconSrc} alt="" className="pixelated w-full h-full object-contain" />
                ) : (
                  <span className="text-ink-muted-2 text-sm">?</span>
                )}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-ink text-xs leading-snug">
                  <span className="font-bold">{e.pokemonName}</span>{' '}
                  {e.statusText ? (
                    <>
                      {e.statusText.before}
                      <span className="font-bold" style={{ color: e.statusText.statusColor }}>{e.statusText.statusLabel}</span>
                      {e.statusText.after}
                    </>
                  ) : e.text}
                  {e.damage != null && (
                    <span className="text-hp-red font-bold"> -{e.damage} PV{e.superEffective ? ' (Super Efficace)' : ''}</span>
                  )}
                  {e.heal != null && <span className="text-hp-green font-bold"> +{e.heal} PV</span>}
                </p>
                {isAdmin && (e.debugEffectivePrecision != null || e.debugDiceRoll != null) && (
                  <div className="text-ink-muted text-xs leading-snug mt-0.5">
                    {e.debugEffectivePrecision != null && (
                      <>
                        🎯 Précision: {e.debugBasePrecision}/10{e.debugPrecisionStatus ? ` (${e.debugPrecisionStatus})` : ''} → {e.debugEffectivePrecision}/10
                        {e.debugDiceRoll != null && ' | '}
                      </>
                    )}
                    {e.debugDiceRoll != null && `🎲 Dé: ${e.debugDiceRoll}`}
                  </div>
                )}
                <p className="text-ink-muted-2 text-[10px]">{formatElapsed(e.elapsedMs)}</p>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
