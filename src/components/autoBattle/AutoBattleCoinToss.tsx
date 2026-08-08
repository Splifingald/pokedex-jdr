import { useEffect, useState } from 'react'
import type { Player } from '../../types'

interface Props {
  player: Player
  firstAttacker: 'player' | 'opponent'
  onDone: () => void
}

// Tirage au sort visuel — le résultat est déjà décidé côté serveur
// (autobattle_resolve_battle), ce composant se contente de l'animer puis
// d'annoncer le vainqueur (jamais de tirage côté client, voir requirement #12).
export function AutoBattleCoinToss({ player, firstAttacker, onDone }: Props) {
  const [revealed, setRevealed] = useState(false)

  useEffect(() => {
    const revealTimer = window.setTimeout(() => setRevealed(true), 900)
    const doneTimer = window.setTimeout(onDone, 2200)
    return () => { clearTimeout(revealTimer); clearTimeout(doneTimer) }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- ne doit s'exécuter qu'au montage
  }, [])

  return (
    <div className="flex flex-col items-center justify-center gap-4 py-10">
      <div
        className="relative w-24 h-24 rounded-full border-[3px] border-ink shadow-[var(--shadow-pixel)] overflow-hidden flex items-center justify-center"
        style={{ backgroundColor: player.color, animation: revealed ? undefined : 'dice-shake 0.15s linear infinite' }}
      >
        {!revealed ? (
          <span className="text-white text-lg font-bold">VS</span>
        ) : player.image_url ? (
          <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
        ) : (
          <span className="text-white text-2xl">?</span>
        )}
      </div>
      <p className="text-ink text-sm font-bold animate-[celebrate-pop_0.4s_ease-out]">
        {!revealed
          ? 'Qui attaque en premier ?'
          : firstAttacker === 'player'
            ? `${player.name} attaque en premier !`
            : "L'adversaire attaque en premier !"}
      </p>
    </div>
  )
}
