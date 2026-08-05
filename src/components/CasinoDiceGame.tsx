import { useState, useEffect, useRef } from 'react'
import type { MouseEvent } from 'react'
import type { CasinoConfig, Player } from '../types'
import { rollDicePair, pickAiTarget, simulateAiTurn, simulateAiSoloTurn } from '../lib/casino'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { DICE_ICON } from '../lib/icons'
import { useCountUp } from '../hooks/useCountUp'
import { flyCoin } from '../lib/flyCoin'
import { PokedollarIcon } from './PokedollarIcon'

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

  // Alternance du premier joueur par manche : manche 1, 3, 5… le joueur commence
  // (comportement historique) ; manche 2, 4, 6… l'IA commence, à l'aveugle, sans
  // connaître le total du joueur — ça évite que l'IA ait toujours l'information complète.
  const aiPlayedFirst = round % 2 === 0

  useEffect(() => () => {
    if (cycleIntervalRef.current) window.clearInterval(cycleIntervalRef.current)
    if (settleTimeoutRef.current) window.clearTimeout(settleTimeoutRef.current)
  }, [])

  useEffect(() => {
    if (phase !== 'ai-turn') return
    setAiRolling(true)

    // Deux cas : l'IA joue en premier (à l'aveugle, cible seule — l'issue de la
    // manche ne se décide qu'après le tour du joueur) ou en second (elle connaît
    // déjà le total du joueur et l'outcome sort directement de la simulation).
    const solo = aiPlayedFirst ? simulateAiSoloTurn(aiTotal, aiTarget) : null
    const dual = solo ? null : simulateAiTurn(aiTotal, aiTarget, playerTotal)
    const steps = solo ? solo.steps : dual!.steps

    let cancelled = false
    let i = 0
    const advance = () => {
      if (cancelled) return
      if (i >= steps.length) {
        setAiRolling(false)
        if (solo) {
          if (solo.busted) {
            setRoundOutcome('win')
            setPhase('round-result')
          } else {
            setPhase('player-turn')
          }
        } else {
          setRoundOutcome(dual!.outcome)
          setPhase('round-result')
        }
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

  const handleStand = () => {
    // Si l'IA a déjà joué en premier, son total est déjà fixé : se figer maintenant
    // détermine directement l'issue de la manche (égalité favorise le joueur).
    if (aiPlayedFirst) {
      setRoundOutcome(playerTotal >= aiTotal ? 'win' : 'lose')
      setPhase('round-result')
      return
    }
    setPhase('ai-turn')
  }

  const nextGain = round === 1 ? config.dice_initial_gain : bankedGain * 2
  const isFinalRound = round >= config.dice_max_rounds

  const handleDismissResult = (e: MouseEvent<HTMLButtonElement>) => {
    if (roundOutcome === 'lose') {
      onWin(0)
      return
    }
    if (isFinalRound) {
      if (nextGain > 0) flyCoin(e.currentTarget.getBoundingClientRect(), nextGain, pokedollarImageUrl)
      onWin(nextGain)
      return
    }
    setBankedGain(nextGain)
    setPhase('choice')
  }

  const handleCashOut = (e: MouseEvent<HTMLButtonElement>) => {
    if (bankedGain > 0) flyCoin(e.currentTarget.getBoundingClientRect(), bankedGain, pokedollarImageUrl)
    onWin(bankedGain)
  }

  const handleContinue = () => {
    const nextRound = round + 1
    setRound(nextRound)
    setPlayerTotal(0)
    setAiTotal(0)
    setAiTarget(pickAiTarget(config))
    setRoundOutcome(null)
    setLastPlayerRoll(null)
    setLastAiRoll(null)
    setPhase(nextRound % 2 === 0 ? 'ai-turn' : 'player-turn')
  }

  const shownPlayerRoll = playerRolling ? displayRoll : lastPlayerRoll
  // Le total de l'IA reste caché seulement quand elle joue en second et n'a pas
  // encore joué (comportement historique) ; dès qu'elle a joué (en premier ou
  // pendant son tour), son total est visible.
  const aiTotalHidden = phase === 'player-turn' && !aiPlayedFirst

  return (
    <div className="flex flex-col items-center">
      <p className="text-ink-muted-2 text-xs mb-3">
        Manche {round} / {config.dice_max_rounds} — objectif : s'approcher de 21 sans le dépasser
        {aiPlayedFirst && ' — ' + config.dice_opponent_name + ' commence cette manche'}
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
            {aiTotalHidden ? '?' : aiTotal}
          </p>
          {lastAiRoll && !aiTotalHidden && (
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
            {roundOutcome === 'lose' ? (
              <>Continuer (0 <PokedollarIcon imageUrl={pokedollarImageUrl} size={18} className="align-[-4px]" />)</>
            ) : isFinalRound ? (
              <>Continuer ({nextGain} <PokedollarIcon imageUrl={pokedollarImageUrl} size={18} className="align-[-4px]" />)</>
            ) : (
              'Continuer'
            )}
          </button>
        </div>
      )}

      {phase === 'choice' && (
        <div className="flex flex-col items-center gap-3">
          <p className="text-ink text-sm flex items-center gap-2">
            Gains actuels : <span className="font-bold">{displayedGain} <PokedollarIcon imageUrl={pokedollarImageUrl} size={18} className="align-[-4px]" /></span>
            {round > 1 && (
              <span className="text-hp-orange font-bold text-xs animate-[celebrate-pop_0.4s_ease-out]">×2 !</span>
            )}
          </p>
          <div className="flex gap-3">
            <button onClick={handleCashOut} className={`px-4 py-2 rounded font-bold text-sm ${BUTTON_STYLE.green}`}>
              Encaisser ({bankedGain} <PokedollarIcon imageUrl={pokedollarImageUrl} size={18} className="align-[-4px]" />)
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
