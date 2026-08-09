import { useEffect, useState } from 'react'
import type { Player, Pokemon } from '../../types'
import { ConfettiBurst } from '../ConfettiEffects'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  leftPlayer: Player
  rightPlayer: Player
  leftPokemon: Pokemon | undefined
  leftNickname?: string | null
  rightPokemon: Pokemon | undefined
  rightNickname?: string | null
  onDone: () => void
}

type Phase = 'swapping' | 'confetti' | 'done'

const SWAP_DURATION_MS = 2200

function PlayerTag({ player, side }: { player: Player; side: 'left' | 'right' }) {
  return (
    <div className={`absolute bottom-[16%] ${side === 'left' ? 'left-[22%]' : 'left-[78%]'} -translate-x-1/2 flex flex-col items-center gap-2`}>
      <div className="w-14 h-14 rounded-full overflow-hidden border-[3px] shrink-0" style={{ borderColor: player.color }}>
        {player.image_url ? (
          <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full" style={{ backgroundColor: player.color }} />
        )}
      </div>
      <span className="text-cream text-sm font-bold">{player.name}</span>
    </div>
  )
}

// Animation plein écran jouée à la conclusion d'un échange de Pokémon (pas pour
// les objets) : chaque sprite rétrécit en silhouette blanche, traverse l'écran
// vers le côté opposé, puis regrandit et reprend ses couleurs à l'arrivée —
// les dresseurs (avatar + nom) restent ancrés de leur côté d'origine.
export function TradeSwapAnimation({ leftPlayer, rightPlayer, leftPokemon, leftNickname, rightPokemon, rightNickname, onDone }: Props) {
  const [phase, setPhase] = useState<Phase>('swapping')

  useEffect(() => {
    const timers = [
      window.setTimeout(() => setPhase('confetti'), SWAP_DURATION_MS * 0.45),
      window.setTimeout(() => setPhase('done'), SWAP_DURATION_MS + 200),
    ]
    return () => timers.forEach((t) => clearTimeout(t))
  }, [])

  const leftLabel = leftNickname?.trim() || leftPokemon?.nom || '???'
  const rightLabel = rightNickname?.trim() || rightPokemon?.nom || '???'

  return (
    <div className="fixed inset-0 z-[95] bg-black/90 overflow-hidden">
      {phase !== 'swapping' && <ConfettiBurst />}

      <div
        className="absolute top-[38%] w-28 h-28 sm:w-40 sm:h-40 pointer-events-none"
        style={{ animation: `trade-swap-a ${SWAP_DURATION_MS}ms ease-in-out forwards` }}
      >
        {leftPokemon?.image_miniature ? (
          <img src={leftPokemon.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
        ) : (
          <span className="text-cream text-4xl">?</span>
        )}
      </div>

      <div
        className="absolute top-[38%] w-28 h-28 sm:w-40 sm:h-40 pointer-events-none"
        style={{ animation: `trade-swap-b ${SWAP_DURATION_MS}ms ease-in-out forwards` }}
      >
        {rightPokemon?.image_miniature ? (
          <img src={rightPokemon.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
        ) : (
          <span className="text-cream text-4xl">?</span>
        )}
      </div>

      <PlayerTag player={leftPlayer} side="left" />
      <PlayerTag player={rightPlayer} side="right" />

      {phase === 'done' && (
        <div className="absolute inset-x-0 bottom-6 flex flex-col items-center gap-3 px-6 animate-[celebrate-pop_0.4s_ease-out]">
          <p className="text-cream text-base sm:text-lg font-bold text-center">
            {leftLabel} et {rightLabel} ont changé de dresseur !
          </p>
          <button onClick={onDone} className={`px-6 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.yellow}`}>
            Continuer
          </button>
        </div>
      )}
    </div>
  )
}
