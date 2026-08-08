import { useState, useEffect } from 'react'
import type { SafariSessionPokemon, SafariGaugeArea, Pokemon, Player } from '../types'
import { SafariGaugeIndicator } from './SafariGaugeIndicator'
import { resolveGaugeArea } from '../lib/safari'

interface Props {
  sessionPokemon: SafariSessionPokemon
  pokemon: Pokemon | undefined
  areas: SafariGaugeArea[]
  capturedByPlayer: Player | undefined
  /** Mise en avant (bordure/fond jaune) — indique que ce pokémon est le sélectionné, sans changer la taille (utilisé sur la carte de la rangée). */
  active: boolean
  /** Gabarit agrandi (grand sprite, jauge large avec %/seuils, taux de capture) — utilisé uniquement pour la carte du panneau détaillé, sous la rangée. */
  expanded: boolean
  onSelect: () => void
}

// Deux gabarits : compact (rangée du haut, jauge sans texte) et étendu (panneau
// détaillé sous la rangée, plus grand, jauge large avec %/seuils).
export function SafariPokemonCard({ sessionPokemon, pokemon, areas, capturedByPlayer, active, expanded, onSelect }: Props) {
  const resolved = sessionPokemon.status !== 'active'

  const [jumping, setJumping] = useState(false)
  // Durée/délai figés à vie du composant pour que chaque pokémon se balance
  // à son propre rythme — même idiome que PensionDaycareCard/RoamingPokemonSprite.
  const [bobDuration] = useState(() => 2.2 + Math.random() * 1.4)
  const [bobDelay] = useState(() => Math.random() * 1.5)

  useEffect(() => {
    if (resolved) return
    let cancelled = false
    let loopTimer: number
    let endTimer: number
    const loop = () => {
      loopTimer = window.setTimeout(() => {
        if (cancelled) return
        setJumping(true)
        endTimer = window.setTimeout(() => { if (!cancelled) setJumping(false) }, 600)
        loop()
      }, 5000 + Math.random() * 10000)
    }
    loop()
    return () => { cancelled = true; clearTimeout(loopTimer); clearTimeout(endTimer) }
  }, [resolved])

  const currentArea = sessionPokemon.status === 'active' ? resolveGaugeArea(areas, sessionPokemon.position_gauge) : null
  // Base 64px/160px (compact/étendu), agrandies ×1.3 et ×1.7, puis la version
  // étendue est ramenée à 80% (272×0.8 ≈ 218px).
  const spriteSize = expanded ? 'w-[218px] h-[218px]' : 'w-[84px] h-[84px]'
  const gaugeWidth = expanded ? 'w-72' : 'w-24'
  // Largeur de carte fixe (ne dépend jamais du texte affiché, y compris les
  // messages "capturé"/"a fui" qui passent à la ligne plutôt que d'élargir
  // la carte) — dérivée de la largeur de la jauge, l'élément le plus large.
  const cardWidth = expanded ? 'w-80' : 'w-28'

  return (
    <button
      onClick={() => { if (!resolved) onSelect() }}
      disabled={resolved}
      className={`relative flex flex-col items-center gap-1 rounded-[var(--radius-pixel)] border-[3px] transition-all duration-300 ${cardWidth}
        ${active ? 'border-[#a3841a] bg-yellow-100 p-4 z-10' : 'border-ink bg-cream p-2'}
        ${resolved ? 'opacity-80 cursor-default' : 'cursor-pointer'}`}
    >
      {sessionPokemon.status === 'captured' && (
        <span
          className="absolute top-1 right-1 z-10 w-6 h-6 rounded-full border-2 shrink-0 overflow-hidden bg-cream"
          style={{ borderColor: capturedByPlayer?.color ?? '#a3841a' }}
          title={capturedByPlayer?.name ?? 'Joueur inconnu'}
        >
          {capturedByPlayer?.image_url ? (
            <img src={capturedByPlayer.image_url} alt={capturedByPlayer.name} className="w-full h-full object-cover" />
          ) : (
            <span className="w-full h-full block" style={{ backgroundColor: capturedByPlayer?.color ?? '#a3841a' }} />
          )}
        </span>
      )}

      <p className={`text-ink font-bold text-center truncate w-full ${expanded ? 'text-base' : 'text-xs'}`}>{sessionPokemon.pokemon_nom}</p>

      <div className={`${spriteSize} flex items-center justify-center transition-all duration-300`}>
        {sessionPokemon.status === 'fled' ? (
          pokemon?.image_miniature ? (
            <img
              src={pokemon.image_miniature}
              alt=""
              className="pixelated w-full h-full object-contain brightness-0"
            />
          ) : (
            <span className="text-5xl">👤</span>
          )
        ) : pokemon?.image_miniature ? (
          <div className="w-full h-full flex items-center justify-center" style={jumping ? { animation: 'jump-pop 0.6s ease-out 1' } : undefined}>
            <div className="w-full h-full flex items-center justify-center" style={{ animation: `idle-bob ${bobDuration}s ease-in-out ${bobDelay}s infinite` }}>
              <img
                src={pokemon.image_miniature}
                alt={sessionPokemon.pokemon_nom}
                className="pixelated w-full h-full object-contain [filter:drop-shadow(1px_2px_1px_rgba(0,0,0,0.3))]"
              />
            </div>
          </div>
        ) : (
          <span className="text-5xl">❔</span>
        )}
      </div>

      {expanded && sessionPokemon.status === 'active' && currentArea && (
        <p
          className="text-2xl font-black leading-none"
          style={{ color: currentArea.color, textShadow: '0 0 3px rgba(0,0,0,0.85), 0 0 3px rgba(0,0,0,0.85), 1px 1px 1px rgba(0,0,0,0.85)' }}
        >
          {currentArea.catch_rate_pct}%
        </p>
      )}

      {sessionPokemon.status === 'active' && (
        <div className={`${gaugeWidth} transition-all duration-300`}>
          <SafariGaugeIndicator areas={areas} position={sessionPokemon.position_gauge} showLabels={expanded} />
        </div>
      )}
      {sessionPokemon.status === 'fled' && (
        <p className="text-ink-muted-2 text-xs italic text-center">{sessionPokemon.pokemon_nom} a fui</p>
      )}
      {sessionPokemon.status === 'captured' && (
        <p className="text-ink-muted-2 text-xs italic text-center">{sessionPokemon.pokemon_nom} a été capturé</p>
      )}
    </button>
  )
}
