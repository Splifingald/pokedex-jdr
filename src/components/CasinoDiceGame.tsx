import { useState, useEffect, useRef } from 'react'
import type { CasinoConfig, Player } from '../types'
import { rollDicePair, pickAiTarget, simulateAiTurn } from '../lib/casino'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { DICE_ICON } from '../lib/icons'
import { useCountUp } from '../hooks/useCountUp'

interface Props {
  config: CasinoConfig
  player: Player
  pokedollarImageUrl?: string | null
  onWin: (amount: number) => void
}

type Phase = 'player-turn' | 'ai-turn' | 'round-result' | 'choice'

const ROLL_CYCLE_MS = 80
const ROLL_SETTLE_MS = 500

function Die({ value, shaking }: { value: number; shaking?: boolean }) {
  return (
    <img
      src={DICE_ICON[value]}
      alt={String(value)}
      className="w-9 h-9 object-contain pixelated"
      style={shaking ? { animation: 'dice-shake 0.3s ease-in-out infinite' } : undefined}
    />
  )
}

function Avatar({ imageUrl, color, fallback, size = 28 }: { imageUrl?: string | null; color?: string; fallback: string; size?: number }) {
  return (
    <div
      className="rounded-full overflow-hidden shrink-0 border-2 border-ink flex items-center justify-center bg-cream-secondary"
      style={{ width: size, height: size, borderColor: color }}
    >
      {imageUrl ? (
        <img src={imageUrl} alt="" className="w-full h-full object-cover" />
      ) : color ? (
        <div className="w-full h-full" style={{ backgroundColor: color }} />
      ) : (
        <span style={{ fontSize: size * 0.55 }}>{fallback}</span>
      )}
    </div>
  )
}

function PokedollarIcon({ imageUrl }: { imageUrl?: string | null }) {
  return imageUrl ? (
    <img src={imageUrl} alt="" className="inline w-[18px] h-[18px] object-contain align-[-4px]" />
  ) : (
    <span className="text-lg">💰</span>
  )
}

export function CasinoDiceGame({ config, player, pokedollarImageUrl, onWin }: Props) {
  const [round, setRound] = useState(1)
  const [playerTotal, setPlayerTotal] = useState(0)
  const [aiTotal, setAiTotal] = useState(0)
  const [aiTarget, setAiTarget] = useState(() => pickAiTarget(config))
  const [phase, setPhase] = useState<Phase>('player-turn')
  const [roundOutcome, setRoundOutcome] = useState<'win' | 'lose' | null>(null)
  const [bankedGain, setBankedGain] = useState(0)
  const [lastPlayerRoll, setLastPlayerRoll] = useState<[number, number] | null>(null)
  const [lastAiRoll, setLastAiRoll] = useState<[number, number] | null>(null)
  const [aiRolling, setAiRolling] = useState(false)
  const [playerRolling, setPlayerRolling] = useState(false)
  const [displayRoll, setDisplayRoll] = useState<[number, number] | null>(null)
  const displayedGain = useCountUp(bankedGain)
  const cycleIntervalRef = useRef<number | null>(null)
  const settleTimeoutRef = useRef<number | null>(null)

  useEffect(() => () => {
    if (cycleIntervalRef.current) window.clearInterval(cycleIntervalRef.current)
    if (settleTimeoutRef.current) window.clearTimeout(settleTimeoutRef.current)
  }, [])

  useEffect(() => {
    if (phase !== 'ai-turn') return
    setAiRolling(true)
    const { steps, outcome } = simulateAiTurn(aiTotal, aiTarget, playerTotal)
    let cancelled = false
    let i = 0
    const advance = () => {
      if (cancelled) return
      if (i >= steps.length) {
        setAiRolling(false)
        setRoundOutcome(outcome)
        setPhase('round-result')
        return
      }
      setAiTotal(steps[i].totalAfter)
      setLastAiRoll(steps[i].dice)
      i += 1
      window.setTimeout(advance, 700)
    }
    const startTimer = window.setTimeout(advance, 500)
    return () => { cancelled = true; window.clearTimeout(startTimer) }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- runs once per entry into 'ai-turn'
  }, [phase])

  // Un peu de suspense : les dés du joueur tremblent et affichent des valeurs
  // aléatoires pendant un court instant avant de se figer sur le vrai résultat.
  const handlePlayerRoll = () => {
    if (playerRolling) return
    setPlayerRolling(true)
    cycleIntervalRef.current = window.setInterval(() => {
      setDisplayRoll([1 + Math.floor(Math.random() * 6), 1 + Math.floor(Math.random() * 6)])
    }, ROLL_CYCLE_MS)

    settleTimeoutRef.current = window.setTimeout(() => {
      if (cycleIntervalRef.current) window.clearInterval(cycleIntervalRef.current)
      const dice = rollDicePair()
      setDisplayRoll(null)
      setLastPlayerRoll(dice)
      setPlayerRolling(false)
      const newTotal = playerTotal + dice[0] + dice[1]
      setPlayerTotal(newTotal)
      if (newTotal > 21) {
        setRoundOutcome('lose')
        setPhase('round-result')
      }
    }, ROLL_SETTLE_MS)
  }

  const handleStand = () => setPhase('ai-turn')

  const handleDismissResult = () => {
    if (roundOutcome === 'lose') {
      onWin(0)
      return
    }
    const newGain = round === 1 ? config.dice_initial_gain : bankedGain * 2
    if (round >= config.dice_max_rounds) {
      onWin(newGain)
      return
    }
    setBankedGain(newGain)
    setPhase('choice')
  }

  const handleCashOut = () => onWin(bankedGain)

  const handleContinue = () => {
    setRound((r) => r + 1)
    setPlayerTotal(0)
    setAiTotal(0)
    setAiTarget(pickAiTarget(config))
    setRoundOutcome(null)
    setLastPlayerRoll(null)
    setLastAiRoll(null)
    setPhase('player-turn')
  }

  const shownPlayerRoll = playerRolling ? displayRoll : lastPlayerRoll

  return (
    <div className="flex flex-col items-center">
      <p className="text-ink-muted-2 text-xs mb-3">
        Manche {round} / {config.dice_max_rounds} — objectif : s'approcher de 21 sans le dépasser
      </p>

      <div className="w-full flex gap-3 mb-4">
        <div className={`flex-1 p-3 rounded text-center ${PIXEL_BORDER_SM} bg-cream-secondary`}>
          <div className="flex items-center justify-center gap-1.5 mb-1">
            <Avatar imageUrl={player.image_url} color={player.color} fallback="🧑" />
            <span className="text-ink-muted-2 text-xs font-bold truncate">{player.name}</span>
          </div>
          <p className={`text-2xl font-bold ${playerTotal > 21 ? 'text-red-700' : 'text-ink'}`}>{playerTotal}</p>
          {shownPlayerRoll && (
            <div className="flex justify-center gap-1 mt-1">
              <Die value={shownPlayerRoll[0]} shaking={playerRolling} />
              <Die value={shownPlayerRoll[1]} shaking={playerRolling} />
            </div>
          )}
        </div>
        <div className={`flex-1 p-3 rounded text-center ${PIXEL_BORDER_SM} bg-cream-secondary`}>
          <div className="flex items-center justify-center gap-1.5 mb-1">
            <Avatar imageUrl={config.dice_opponent_image_url} fallback="🎩" />
            <span className="text-ink-muted-2 text-xs font-bold truncate">{config.dice_opponent_name}</span>
          </div>
          <p
            className={`text-2xl font-bold ${aiTotal > 21 ? 'text-red-700' : 'text-ink'}`}
            style={aiRolling ? { animation: 'dice-shake 0.3s ease-in-out infinite' } : undefined}
          >
            {phase === 'player-turn' ? '?' : aiTotal}
          </p>
          {lastAiRoll && phase !== 'player-turn' && (
            <div className="flex justify-center gap-1 mt-1">
              <Die value={lastAiRoll[0]} />
              <Die value={lastAiRoll[1]} />
            </div>
          )}
        </div>
      </div>

      {phase === 'player-turn' && (
        <div className="flex gap-3">
          <button
            onClick={handlePlayerRoll}
            disabled={playerRolling}
            className={`px-5 py-2 rounded font-bold text-sm disabled:opacity-50 ${BUTTON_STYLE.green}`}
          >
            Lancer
          </button>
          <button
            onClick={handleStand}
            disabled={!lastPlayerRoll || playerRolling}
            className={`px-5 py-2 rounded font-bold text-sm disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.blue}`}
          >
            Rester
          </button>
        </div>
      )}

      {phase === 'ai-turn' && (
        <p className="text-ink-muted-2 text-sm italic">{config.dice_opponent_name} lance les dés…</p>
      )}

      {phase === 'round-result' && (
        <div className="flex flex-col items-center gap-3 animate-[celebrate-pop_0.4s_ease-out]">
          <p className="text-ink text-base font-bold">
            {roundOutcome === 'win' ? '🎉 Manche gagnée !' : '💥 Manche perdue — tout est perdu.'}
          </p>
          <button onClick={handleDismissResult} className={`px-5 py-2 rounded font-bold text-sm ${BUTTON_STYLE.yellow}`}>
            Continuer
          </button>
        </div>
      )}

      {phase === 'choice' && (
        <div className="flex flex-col items-center gap-3">
          <p className="text-ink text-sm flex items-center gap-2">
            Gains actuels : <span className="font-bold">{displayedGain} <PokedollarIcon imageUrl={pokedollarImageUrl} /></span>
            {round > 1 && (
              <span className="text-hp-orange font-bold text-xs animate-[celebrate-pop_0.4s_ease-out]">×2 !</span>
            )}
          </p>
          <div className="flex gap-3">
            <button onClick={handleCashOut} className={`px-4 py-2 rounded font-bold text-sm ${BUTTON_STYLE.green}`}>
              Encaisser ({bankedGain} <PokedollarIcon imageUrl={pokedollarImageUrl} />)
            </button>
            <button onClick={handleContinue} className={`px-4 py-2 rounded font-bold text-sm ${BUTTON_STYLE.red}`}>
              Continuer (doubler ou tout perdre)
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
