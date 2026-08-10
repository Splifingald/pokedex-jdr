import { useState, useEffect, useRef, type PointerEvent as ReactPointerEvent } from 'react'
import type { Player, PlayerPokemon, Pokemon, PokemonEvolution, Item, PlayerItem, MinigamesConfig, MinigamesPlayerState } from '../../types'
import { ownedPokemonName } from '../../types'
import { computeStars, xpForStars, type StarCount } from '../../lib/magikarpGame'
import { getEvolutionOptions } from '../../lib/evolution'
import { getMaxXp, clampXp } from '../../lib/xpBonuses'
import { logHistoryEvent } from '../../lib/historyLog'
import { useCountUp } from '../../hooks/useCountUp'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../../lib/panelStyles'
import { MAGIKARP_JUMP_ICON } from '../../lib/icons'
import { ConfettiBurst, Sparkles } from '../ConfettiEffects'

interface Props {
  config: MinigamesConfig
  player: Player
  magikarp: PlayerPokemon
  pokemon: Pokemon | undefined
  pokemonByName: Map<string, Pokemon>
  evolutionsByPokemonNom: Map<string, PokemonEvolution[]>
  itemsByName: Map<string, Item>
  playerItemsInventory: PlayerItem[]
  updateXp: (id: number, xp: number) => Promise<void>
  priorHighScore: number
  updateMinigamesState: (patch: Partial<Omit<MinigamesPlayerState, 'player_id'>>) => Promise<void>
  onRequestPokemonDetail: (id: number) => void
  onDone: () => void
}

type Phase = 'countdown' | 'playing' | 'result'

const COUNTDOWN_STEPS = ['3', '2', '1', 'TAP !']
const COUNTDOWN_STEP_MS = 600

// Couleur du score en fonction des paliers d'étoiles franchis — lisible sur fond crème.
const SCORE_COLOR: Record<StarCount, string> = {
  0: 'text-ink-muted-2',
  1: 'text-[#a3841a]',
  2: 'text-hp-orange',
  3: 'text-hp-red',
}

// Mer très simple (ciel + horizon + une vague) derrière l'arène, au niveau de Magicarpe.
function SeaBackground() {
  return (
    <svg viewBox="0 0 400 240" preserveAspectRatio="none" className="absolute inset-0 w-full h-full" aria-hidden="true">
      <rect width="400" height="240" fill="#bfe6f7" />
      <path d="M0 150 Q 25 138 50 150 T 100 150 T 150 150 T 200 150 T 250 150 T 300 150 T 350 150 T 400 150 V240 H0 Z" fill="#3f8fd6" />
      <path
        d="M0 155 Q 25 145 50 155 T 100 155 T 150 155 T 200 155 T 250 155 T 300 155 T 350 155 T 400 155"
        stroke="#ffffff" strokeWidth="3" fill="none" opacity="0.35"
      />
    </svg>
  )
}

export function MagikarpGame({
  config, player, magikarp, pokemon, pokemonByName, evolutionsByPokemonNom, itemsByName,
  playerItemsInventory, updateXp, priorHighScore, updateMinigamesState, onRequestPokemonDetail, onDone,
}: Props) {
  const [phase, setPhase] = useState<Phase>('countdown')
  const [countdownStep, setCountdownStep] = useState(0)
  const [taps, setTaps] = useState(0)
  const [jumpKey, setJumpKey] = useState(0)
  const [lastTapFlipped, setLastTapFlipped] = useState(false)
  const [timeLeftMs, setTimeLeftMs] = useState(config.magikarp_duration_seconds * 1000)

  const [isNewHighScore, setIsNewHighScore] = useState(false)
  const [evolutionEligible, setEvolutionEligible] = useState(false)
  const [showEvolvePrompt, setShowEvolvePrompt] = useState(false)
  const hasCommittedRef = useRef(false)
  // Pointeurs actuellement pressés — évite de compter un doigt fantôme (paume, second doigt)
  // ou un pointerdown répété pour le même doigt sans pointerup intermédiaire (glitch tactile mobile).
  const activePointersRef = useRef<Set<number>>(new Set())

  // Dérivés de `taps` (figé dès la fin de la partie) — pas besoin d'état séparé.
  const stars = computeStars(taps, config)
  const xpGain = xpForStars(stars, config)

  // Séquence 3…2…1…TAP ! puis lancement du minuteur de partie.
  useEffect(() => {
    const timers = COUNTDOWN_STEPS.map((_, i) =>
      window.setTimeout(() => setCountdownStep(i), i * COUNTDOWN_STEP_MS)
    )
    timers.push(window.setTimeout(() => setPhase('playing'), COUNTDOWN_STEPS.length * COUNTDOWN_STEP_MS))
    return () => timers.forEach(clearTimeout)
  }, [])

  useEffect(() => {
    if (phase !== 'playing') return
    const durationMs = config.magikarp_duration_seconds * 1000
    const endAt = Date.now() + durationMs
    setTimeLeftMs(durationMs)
    const interval = window.setInterval(() => {
      const remaining = endAt - Date.now()
      if (remaining <= 0) {
        setTimeLeftMs(0)
        clearInterval(interval)
        setPhase('result')
      } else {
        setTimeLeftMs(remaining)
      }
    }, 100)
    return () => clearInterval(interval)
  }, [phase, config.magikarp_duration_seconds])

  // Crédite XP/historique/record une seule fois à l'entrée en phase de résultat.
  useEffect(() => {
    if (phase !== 'result' || hasCommittedRef.current) return
    hasCommittedRef.current = true

    void (async () => {
      let finalXp = magikarp.xp
      if (xpGain > 0) {
        finalXp = clampXp(magikarp.xp + xpGain, getMaxXp(pokemon))
        await updateXp(magikarp.id, finalXp)
      }
      void logHistoryEvent('minigame', 'minigame_xp_gain', player.id, {
        game_nom: config.magikarp_nom,
        pokemon_nom: magikarp.pokemon_nom,
        player_pokemon_id: magikarp.id,
        nickname: magikarp.nickname,
        xp_delta: finalXp - magikarp.xp,
        xp_total: finalXp,
        score: taps,
        stars,
      })

      if (taps > priorHighScore) {
        setIsNewHighScore(true)
        await updateMinigamesState({ magikarp_high_score: taps })
      }

      const options = getEvolutionOptions(
        { ...magikarp, xp: finalXp },
        pokemon,
        evolutionsByPokemonNom,
        pokemonByName,
        itemsByName,
        playerItemsInventory
      )
      if (options.length > 0) setEvolutionEligible(true)
    })()
    // eslint-disable-next-line react-hooks/exhaustive-deps -- ne doit s'exécuter qu'une fois, à l'entrée en phase 'result' (voir hasCommittedRef) ; stars/xpGain dérivent de taps, déjà figé à ce moment
  }, [phase])

  const animatedTaps = useCountUp(phase === 'result' ? taps : 0, 700)

  const handleTap = () => {
    if (phase !== 'playing') return
    setTaps((prev) => {
      const nextTaps = prev + 1
      const crossedThreshold = computeStars(nextTaps, config) > computeStars(prev, config)
      setJumpKey((k) => k + 1)
      setLastTapFlipped(crossedThreshold)
      return nextTaps
    })
  }

  const handlePointerDown = (e: ReactPointerEvent) => {
    if (phase !== 'playing') return
    // Ignore les doigts secondaires (paume, second doigt) et les pointerdown
    // répétés pour un même doigt sans pointerup intermédiaire.
    if (!e.isPrimary || activePointersRef.current.has(e.pointerId)) return
    activePointersRef.current.add(e.pointerId)
    e.preventDefault()
    handleTap()
  }

  const releasePointer = (e: ReactPointerEvent) => {
    activePointersRef.current.delete(e.pointerId)
  }

  const handleContinue = () => {
    if (evolutionEligible && !showEvolvePrompt) {
      setShowEvolvePrompt(true)
      return
    }
    onDone()
  }

  const progressPct = Math.max(0, Math.min(100, (timeLeftMs / (config.magikarp_duration_seconds * 1000)) * 100))
  const spriteAnimation = lastTapFlipped
    ? 'jump-pop 0.35s ease-out 1, sprite-flip 0.3s ease-out 1'
    : 'jump-pop 0.35s ease-out 1'

  return (
    <div className="flex flex-col items-center select-none">
      <div className="w-full flex items-center justify-between mb-3">
        <h3 className="text-ink text-lg font-bold">{config.magikarp_nom}</h3>
        <span className={`text-2xl font-bold tabular-nums transition-colors ${SCORE_COLOR[stars]}`}>{taps}</span>
      </div>

      {(phase === 'countdown' || phase === 'playing') && (
        <div
          className={`relative w-full h-64 rounded overflow-hidden mb-4 ${PIXEL_BORDER_SM} ${phase === 'playing' ? 'cursor-pointer' : ''}`}
          onPointerDown={phase === 'playing' ? handlePointerDown : undefined}
          onPointerUp={phase === 'playing' ? releasePointer : undefined}
          onPointerCancel={phase === 'playing' ? releasePointer : undefined}
          onPointerLeave={phase === 'playing' ? releasePointer : undefined}
          style={{ touchAction: 'none' }}
        >
          <SeaBackground />

          {phase === 'countdown' && (
            <div key={countdownStep} className="absolute inset-0 flex items-center justify-center text-ink text-6xl font-bold animate-[celebrate-pop_0.4s_ease-out]">
              {COUNTDOWN_STEPS[countdownStep]}
            </div>
          )}

          {phase === 'playing' && (
            <>
              <p className="absolute top-2 inset-x-0 text-center text-white text-xs drop-shadow-[0_1px_2px_rgba(0,0,0,0.45)]">
                Tapez ici !
              </p>

              <img
                key={jumpKey}
                src={MAGIKARP_JUMP_ICON}
                alt=""
                className="absolute bottom-9 left-1/2 -translate-x-1/2 pixelated w-28 h-28 object-contain pointer-events-none"
                style={{ animation: spriteAnimation }}
              />

              <div className="absolute bottom-3 left-3 right-3 h-2.5 rounded-full bg-white/30 overflow-hidden">
                <div
                  className="h-full bg-[#ffd85e] transition-[width] duration-100 ease-linear"
                  style={{ width: `${progressPct}%` }}
                />
              </div>
            </>
          )}
        </div>
      )}

      {phase === 'result' && !showEvolvePrompt && (
        <div className="relative flex flex-col items-center text-center">
          {isNewHighScore && (
            <>
              <ConfettiBurst />
              <Sparkles />
            </>
          )}

          <img src={MAGIKARP_JUMP_ICON} alt="" className="pixelated w-24 h-24 object-contain mb-2 animate-[celebrate-pop_0.4s_ease-out]" />

          {isNewHighScore && (
            <p className="text-hp-orange text-lg font-bold mb-1 animate-[celebrate-pop_0.4s_ease-out]">🎉 Nouveau record !</p>
          )}

          <p className="text-ink text-5xl font-bold tabular-nums mb-1">{animatedTaps}</p>
          <p className="text-ink-muted-2 text-sm mb-4">taps</p>

          <div className="flex items-center gap-2 mb-4">
            {[1, 2, 3].map((i) => (
              <span
                key={i}
                className={`text-4xl ${i <= stars ? 'animate-[celebrate-pop_0.4s_ease-out]' : 'opacity-25'}`}
                style={i <= stars ? { animationDelay: `${(i - 1) * 150}ms`, animationFillMode: 'backwards' } : undefined}
              >
                ⭐
              </span>
            ))}
          </div>

          {xpGain > 0 && (
            <p className={`text-ink text-sm mb-2 rounded px-3 py-1.5 ${PIXEL_BORDER_SM} bg-cream-secondary`}>
              {ownedPokemonName(magikarp)} a gagné <span className="font-bold">+{xpGain} XP</span>
            </p>
          )}

          <button
            onClick={handleContinue}
            className={`mt-2 px-6 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.yellow}`}
          >
            Continuer
          </button>
        </div>
      )}

      {phase === 'result' && showEvolvePrompt && (
        <div className="relative flex flex-col items-center text-center animate-[celebrate-pop_0.3s_ease-out]">
          <p className="text-ink text-base mb-4">
            ✨ {ownedPokemonName(magikarp)} peut évoluer ! Voir votre Pokémon ?
          </p>
          <div className="flex gap-3">
            <button
              onClick={() => onRequestPokemonDetail(magikarp.id)}
              className={`px-5 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.yellow}`}
            >
              Oui
            </button>
            <button
              onClick={onDone}
              className={`px-5 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.gray}`}
            >
              Non
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
