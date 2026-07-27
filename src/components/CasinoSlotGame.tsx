import { useState, useRef, useEffect } from 'react'
import type { CasinoConfig, SlotSymbol } from '../types'
import { rollSlotSymbols, computeSlotResult, type SlotResult } from '../lib/casino'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { CASINO_ICON } from '../lib/icons'
import { useCountUp } from '../hooks/useCountUp'

interface Props {
  config: CasinoConfig
  pokedollarImageUrl?: string | null
  onWin: (amount: number) => void
}

const PLACEHOLDER_REELS: [SlotSymbol, SlotSymbol, SlotSymbol] = ['pokeball', 'superball', 'hyperball']
const ALL_SYMBOLS: SlotSymbol[] = ['pokeball', 'superball', 'hyperball', 'masterball']

const FIRST_STOP_MS = 500
const STOP_STEP_MS = 450
const RESULT_DELAY_MS = 300
const CYCLE_MS = 90

function randomSymbol(): SlotSymbol {
  return ALL_SYMBOLS[Math.floor(Math.random() * ALL_SYMBOLS.length)]
}

function PokedollarIcon({ imageUrl }: { imageUrl?: string | null }) {
  return imageUrl ? (
    <img src={imageUrl} alt="" className="inline w-[18px] h-[18px] object-contain align-[-4px]" />
  ) : (
    <span className="text-lg">💰</span>
  )
}

export function CasinoSlotGame({ config, pokedollarImageUrl, onWin }: Props) {
  const [reels, setReels] = useState<[SlotSymbol, SlotSymbol, SlotSymbol]>(PLACEHOLDER_REELS)
  const [revealedCount, setRevealedCount] = useState(3)
  const [spinning, setSpinning] = useState(false)
  const [result, setResult] = useState<SlotResult | null>(null)
  const timeoutsRef = useRef<number[]>([])
  const cycleIntervalRef = useRef<number | null>(null)
  const stoppedRef = useRef<boolean[]>([true, true, true])
  const displayedTotal = useCountUp(result?.total ?? 0)

  useEffect(() => () => {
    timeoutsRef.current.forEach(clearTimeout)
    if (cycleIntervalRef.current) window.clearInterval(cycleIntervalRef.current)
  }, [])

  const handleSpin = () => {
    if (spinning) return
    setSpinning(true)
    setResult(null)
    setRevealedCount(0)
    stoppedRef.current = [false, false, false]
    timeoutsRef.current.forEach(clearTimeout)
    timeoutsRef.current = []
    if (cycleIntervalRef.current) window.clearInterval(cycleIntervalRef.current)

    const finalSymbols = rollSlotSymbols(config)

    // Fait défiler des symboles aléatoires sur les rouleaux encore en mouvement,
    // pour un vrai effet de rotation (pas juste un flou sur le symbole final statique).
    cycleIntervalRef.current = window.setInterval(() => {
      setReels((prev) => prev.map((s, i) => (stoppedRef.current[i] ? s : randomSymbol())) as [SlotSymbol, SlotSymbol, SlotSymbol])
    }, CYCLE_MS)

    finalSymbols.forEach((symbol, i) => {
      const id = window.setTimeout(() => {
        stoppedRef.current[i] = true
        setReels((prev) => {
          const next = [...prev] as [SlotSymbol, SlotSymbol, SlotSymbol]
          next[i] = symbol
          return next
        })
        setRevealedCount((c) => c + 1)
      }, FIRST_STOP_MS + i * STOP_STEP_MS)
      timeoutsRef.current.push(id)
    })

    const finalId = window.setTimeout(() => {
      if (cycleIntervalRef.current) window.clearInterval(cycleIntervalRef.current)
      setResult(computeSlotResult(finalSymbols, config))
      setSpinning(false)
    }, FIRST_STOP_MS + 2 * STOP_STEP_MS + RESULT_DELAY_MS)
    timeoutsRef.current.push(finalId)
  }

  return (
    <div className="flex flex-col items-center">
      <div className="flex gap-3 p-4 rounded mb-4 border-4 border-dotted border-orange-500 bg-red-700">
        {reels.map((symbol, i) => {
          const stillSpinning = i >= revealedCount
          const isMatched = result?.matchedIndices.includes(i) ?? false
          return (
            <div key={i} className="flex flex-col items-center gap-1">
              <div
                className="w-16 h-16 bg-white rounded border-2 border-ink flex items-center justify-center overflow-hidden"
                style={isMatched ? { animation: 'slot-glow 0.6s ease-in-out 3' } : undefined}
              >
                <img
                  src={CASINO_ICON[symbol]}
                  alt={symbol}
                  className="w-12 h-12 object-contain pixelated"
                  style={stillSpinning ? { animation: `reel-spin 0.3s ease-in-out infinite`, animationDelay: `${i * 0.1}s` } : undefined}
                />
              </div>
              {result && !stillSpinning && (
                <span className="text-white text-xs font-bold">+{result.perSymbolValue[i]}</span>
              )}
            </div>
          )
        })}
      </div>

      {result !== null ? (
        <div className="flex flex-col items-center gap-3 mb-2">
          {result.multiplier > 1 && (
            <p className={`text-sm font-bold animate-[celebrate-pop_0.4s_ease-out] ${result.matchTier === 'three' ? 'text-hp-red' : 'text-hp-orange'}`}>
              {result.matchTier === 'three' ? '3 identiques' : '2 identiques'} — multiplicateur ×{result.multiplier}
              {result.matchTier === 'three' ? ' — JACKPOT !' : ' !'}
            </p>
          )}
          <p className="text-ink text-base font-bold animate-[celebrate-pop_0.4s_ease-out]">
            +{displayedTotal} <PokedollarIcon imageUrl={pokedollarImageUrl} />
          </p>
          <button onClick={() => onWin(result.total)} className={`px-5 py-2 rounded font-bold text-sm ${BUTTON_STYLE.yellow}`}>
            Continuer
          </button>
        </div>
      ) : (
        <button
          onClick={handleSpin}
          disabled={spinning}
          className={`px-6 py-2.5 rounded font-bold text-sm disabled:opacity-50 ${BUTTON_STYLE.green}`}
        >
          {spinning ? 'Ça tourne…' : 'Lancer'}
        </button>
      )}
    </div>
  )
}
