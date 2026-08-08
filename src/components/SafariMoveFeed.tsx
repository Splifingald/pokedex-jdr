import { useState } from 'react'
import type { SafariMove, SafariSessionPokemon, SafariGaugeArea, Player } from '../types'
import { resolveGaugeArea } from '../lib/safari'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  moves: SafariMove[]
  playersById: Map<number, Player>
  sessionPokemonById: Map<number, SafariSessionPokemon>
  areasByGroup: Map<number, SafariGaugeArea[]>
}

function MoveAvatar({ player }: { player?: Player }) {
  return (
    <div className="w-6 h-6 rounded-full overflow-hidden shrink-0 border-2" style={{ borderColor: player?.color ?? '#a3841a' }}>
      {player?.image_url ? (
        <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
      ) : (
        <div className="w-full h-full" style={{ backgroundColor: player?.color ?? '#a3841a' }} />
      )}
    </div>
  )
}

const VISIBLE_COUNT = 10

// Flux des actions de la session Safari en cours, distinct de l'historique
// global (Admin → Historique) — même rôle que MiningMoveFeed.
export function SafariMoveFeed({ moves, playersById, sessionPokemonById, areasByGroup }: Props) {
  const [showAll, setShowAll] = useState(false)

  if (moves.length === 0) {
    return <p className="text-ink-muted-2 text-xs italic text-center py-3">Aucune action pour l'instant.</p>
  }

  const visible = showAll ? moves : moves.slice(0, VISIBLE_COUNT)

  return (
    <div className="flex flex-col gap-1.5 max-h-64 overflow-y-auto">
      {visible.map((move) => {
        const player = playersById.get(move.player_id)
        const sp = move.session_pokemon_id ? sessionPokemonById.get(move.session_pokemon_id) : undefined
        const pokemonNom = sp?.pokemon_nom ?? 'un pokémon'
        const areas = sp ? areasByGroup.get(sp.group_id) ?? [] : []
        const currentRate = move.action === 'berry' && move.gauge_after != null ? resolveGaugeArea(areas, move.gauge_after)?.catch_rate_pct : undefined

        return (
          <div key={move.id} className="flex items-center gap-2 text-xs">
            <MoveAvatar player={player} />
            <span className="text-ink flex-1 min-w-0">
              <strong>{player?.name ?? 'Joueur inconnu'}</strong>
              {move.action === 'berry' && (
                <>
                  {' '}a lancé une Baie sur <strong>{pokemonNom}</strong> (+{(move.gauge_after ?? 0) - (move.gauge_before ?? 0)}
                  {currentRate != null ? `, maintenant à ${currentRate}% de capture` : ''})
                </>
              )}
              {move.action === 'ball_success' && <> a capturé <strong>{pokemonNom}</strong> !</>}
              {move.action === 'ball_fail' && <> a raté sa capture, <strong>{pokemonNom}</strong> a fui</>}
            </span>
          </div>
        )
      })}
      {!showAll && moves.length > VISIBLE_COUNT && (
        <button
          onClick={() => setShowAll(true)}
          className={`self-center mt-1 px-3 py-1 rounded text-[11px] font-bold ${BUTTON_STYLE.gray}`}
        >
          Charger plus
        </button>
      )}
    </div>
  )
}
