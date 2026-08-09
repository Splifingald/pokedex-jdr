import { useEffect, useState } from 'react'
import type { Player } from '../../types'

interface Props {
  player: Player
  firstAttacker: 'player' | 'opponent'
  onDone: () => void
}

const SPIN_MS = 1800
const HOLD_MS = 1400

// Tirage au sort visuel — le résultat est déjà décidé côté serveur
// (autobattle_resolve_battle), ce composant se contente de l'animer puis
// d'annoncer le vainqueur (jamais de tirage côté client, voir requirement #12).
// La pièce a deux faces empilées en 3D (VS / avatar du joueur) et pivote
// réellement sur l'axe X (rotateX) via une transition CSS, plutôt qu'un
// simple tremblement — elle s'arrête sur la face du résultat.
export function AutoBattleCoinToss({ player, firstAttacker, onDone }: Props) {
  const [spinning, setSpinning] = useState(false)
  const [revealed, setRevealed] = useState(false)

  useEffect(() => {
    const startTimer = window.setTimeout(() => setSpinning(true), 30)
    const revealTimer = window.setTimeout(() => setRevealed(true), SPIN_MS)
    const doneTimer = window.setTimeout(onDone, SPIN_MS + HOLD_MS)
    return () => { clearTimeout(startTimer); clearTimeout(revealTimer); clearTimeout(doneTimer) }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- ne doit s'exécuter qu'au montage
  }, [])

  // La pièce atterrit sur la face avatar si le joueur attaque en premier,
  // sur la face VS sinon (nombre de tours entiers arbitraire pour l'effet visuel).
  const targetDeg = 360 * 4 + (firstAttacker === 'player' ? 180 : 0)

  return (
    <div className="flex flex-col items-center justify-center gap-5 py-10">
      <div style={{ perspective: 800 }}>
        <div
          className="relative w-28 h-28"
          style={{
            transformStyle: 'preserve-3d',
            transition: `transform ${SPIN_MS}ms cubic-bezier(0.2, 0.75, 0.25, 1)`,
            transform: spinning ? `rotateX(${targetDeg}deg)` : 'rotateX(0deg)',
          }}
        >
          <div
            className="absolute inset-0 rounded-full border-[3px] border-ink shadow-[var(--shadow-pixel)] flex items-center justify-center bg-[#e0293f]"
            style={{ backfaceVisibility: 'hidden' }}
          >
            <span className="text-white text-2xl font-bold">VS</span>
          </div>
          <div
            className="absolute inset-0 rounded-full border-[3px] border-ink shadow-[var(--shadow-pixel)] overflow-hidden flex items-center justify-center"
            style={{ backfaceVisibility: 'hidden', transform: 'rotateX(180deg)', backgroundColor: player.color }}
          >
            {player.image_url ? (
              <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
            ) : (
              <span className="text-white text-3xl">?</span>
            )}
          </div>
        </div>
      </div>
      <p className="text-ink text-base font-bold text-center animate-[celebrate-pop_0.4s_ease-out]">
        {!revealed
          ? 'Qui attaque en premier ?'
          : firstAttacker === 'player'
            ? `${player.name} attaque en premier !`
            : "L'adversaire attaque en premier !"}
      </p>
    </div>
  )
}
