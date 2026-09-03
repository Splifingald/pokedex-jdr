import type { EndgameOutcome } from '../../types'
import { ConfettiRain, ConfettiBurst } from '../ConfettiEffects'

interface Props {
  outcome: EndgameOutcome | null
}

// Ce que voient les joueurs pendant que le MJ prépare le bilan : une pluie de
// confettis en cas de victoire, et l'attente annoncée en bas d'écran.
// Ne capte aucun clic : le plateau reste consultable derrière.
export function EndgameOverlay({ outcome }: Props) {
  return (
    <div className="fixed inset-0 z-[55] pointer-events-none">
      {outcome === 'win' && (
        <>
          <ConfettiBurst />
          <ConfettiRain />
        </>
      )}

      <div className="absolute inset-x-0 bottom-10 flex flex-col items-center gap-2 px-4">
        {outcome && (
          <span className="text-cream text-4xl font-bold drop-shadow-[3px_3px_0_rgba(0,0,0,0.8)]">
            {outcome === 'win' ? 'Victoire !' : 'Défaite…'}
          </span>
        )}
        <span className="px-4 py-2 rounded-[var(--radius-pixel)] border-2 border-ink bg-cream text-ink text-lg font-bold shadow-[var(--shadow-pixel)]">
          Chargement des résultats…
        </span>
      </div>
    </div>
  )
}
