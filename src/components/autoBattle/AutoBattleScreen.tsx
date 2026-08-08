import { useEffect, useState } from 'react'
import type { Pokemon, PlayerPokemon } from '../../types'
import { ownedPokemonName } from '../../types'
import { HpGauge } from '../HpGauge'
import { AutoBattleDamageNumber } from './AutoBattleDamageNumber'
import type { AutoBattleTurn } from '../../types'

interface Props {
  playerPokemon: PlayerPokemon
  playerSpecies: Pokemon | undefined
  playerMaxHp: number
  opponentSpecies: Pokemon | undefined
  opponentMaxHp: number
  opponentNom: string
  turns: AutoBattleTurn[]
  onFinished: () => void
}

const TURN_MS = 1000

// Rejoue le journal de tours renvoyé par le RPC autobattle_resolve_battle
// (jamais recalculé côté client, voir requirement #37) : joueur à gauche,
// adversaire à droite, ~1s/tour (requirement #14), secousse + nombre de
// dégâts flottant à chaque coup, K.O. dès qu'un camp atteint 0 PV.
export function AutoBattleScreen({
  playerPokemon, playerSpecies, playerMaxHp, opponentSpecies, opponentMaxHp, opponentNom, turns, onFinished,
}: Props) {
  const [playerHp, setPlayerHp] = useState(playerMaxHp)
  const [opponentHp, setOpponentHp] = useState(opponentMaxHp)
  const [shownTurnIndex, setShownTurnIndex] = useState(-1)
  const [shakeSide, setShakeSide] = useState<'player' | 'opponent' | null>(null)
  const [hitKey, setHitKey] = useState(0)
  const [lastDamage, setLastDamage] = useState<{ side: 'player' | 'opponent'; damage: number } | null>(null)

  useEffect(() => {
    const timers: number[] = []
    turns.forEach((turn, i) => {
      timers.push(window.setTimeout(() => {
        setShownTurnIndex(i)
        const hitSide = turn.attacker === 'player' ? 'opponent' : 'player'
        if (hitSide === 'player') setPlayerHp(turn.defender_hp_after)
        else setOpponentHp(turn.defender_hp_after)
        setShakeSide(hitSide)
        setLastDamage({ side: hitSide, damage: turn.damage })
        setHitKey((k) => k + 1)
        window.setTimeout(() => setShakeSide(null), 300)
      }, i * TURN_MS))
    })
    timers.push(window.setTimeout(onFinished, turns.length * TURN_MS + 900))
    return () => timers.forEach(clearTimeout)
    // eslint-disable-next-line react-hooks/exhaustive-deps -- ne doit s'exécuter qu'au montage (turns figé pour ce combat)
  }, [])

  const playerKo = shownTurnIndex >= 0 && playerHp <= 0
  const opponentKo = shownTurnIndex >= 0 && opponentHp <= 0

  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col items-center gap-2">
          <p className="text-ink text-sm font-bold truncate max-w-full">{ownedPokemonName(playerPokemon)}</p>
          <div
            className="relative w-24 h-24 flex items-center justify-center"
            style={{ animation: shakeSide === 'player' ? 'hit-shake 0.3s ease-in-out' : undefined }}
          >
            {playerSpecies?.image_illustree || playerSpecies?.image_miniature ? (
              <img
                src={playerSpecies.image_illustree || playerSpecies.image_miniature}
                alt=""
                className={`pixelated w-full h-full object-contain ${playerKo ? 'grayscale opacity-40' : ''}`}
              />
            ) : (
              <span className="text-4xl">?</span>
            )}
            {lastDamage?.side === 'player' && (
              <AutoBattleDamageNumber damage={lastDamage.damage} animKey={hitKey} />
            )}
          </div>
          <div className="w-full max-w-[160px]">
            <HpGauge current={Math.max(0, playerHp)} max={playerMaxHp} />
          </div>
        </div>

        <div className="flex flex-col items-center gap-2">
          <p className="text-ink text-sm font-bold truncate max-w-full">{opponentNom}</p>
          <div
            className="relative w-24 h-24 flex items-center justify-center"
            style={{ animation: shakeSide === 'opponent' ? 'hit-shake 0.3s ease-in-out' : undefined }}
          >
            {opponentSpecies?.image_illustree || opponentSpecies?.image_miniature ? (
              <img
                src={opponentSpecies.image_illustree || opponentSpecies.image_miniature}
                alt=""
                className={`pixelated w-full h-full object-contain ${opponentKo ? 'grayscale opacity-40' : ''}`}
              />
            ) : (
              <span className="text-4xl">?</span>
            )}
            {lastDamage?.side === 'opponent' && (
              <AutoBattleDamageNumber damage={lastDamage.damage} animKey={hitKey} />
            )}
          </div>
          <div className="w-full max-w-[160px]">
            <HpGauge current={Math.max(0, opponentHp)} max={opponentMaxHp} />
          </div>
        </div>
      </div>

      {(playerKo || opponentKo) && (
        <p className="text-center text-hp-red text-lg font-bold animate-[celebrate-pop_0.4s_ease-out]">K.O. !</p>
      )}
    </div>
  )
}
