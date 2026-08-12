import { useState } from 'react'
import type { Player, Pokemon, PvpChallenge, PvpChallengeAttempt } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { formatAttemptTimestamp, bestAttemptPerPlayer } from '../lib/pvpAttempts'
import { TrashIcon } from './icons/TrashIcon'

/** size en px — 28 (w-7 h-7) par défaut ; PvpChampionBanner passe une taille plus grande (bannière premium). */
export function PvpAvatar({ player, size = 28 }: { player?: Player; size?: number }) {
  return (
    <div
      className="rounded-full overflow-hidden shrink-0 border-2"
      style={{ width: size, height: size, borderColor: player?.color ?? '#a3841a' }}
    >
      {player?.image_url ? (
        <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
      ) : (
        <div className="w-full h-full" style={{ backgroundColor: player?.color ?? '#a3841a' }} />
      )}
    </div>
  )
}

interface Props {
  challenge: PvpChallenge
  defenderPlayer: Player | undefined
  pokemonByName: Map<string, Pokemon>
  attempts: PvpChallengeAttempt[]
  playersById: Map<number, Player>
  isOwn: boolean
  onPlay: () => void
  onWithdraw: () => void
  /** Défi retiré (voir "Voir les défis passés") : masque Jouer/Retirer, affiche juste la date de retrait — lecture seule. */
  readOnly?: boolean
  /** Vue admin (voir AdminPvpPanel) : remplace Jouer/Retirer/le badge lecture-seule par un bouton de suppression DÉFINITIVE du défi (cascade sur son tableau des scores, contrairement à onWithdraw qui ne fait que le désactiver), et ajoute un bouton de suppression par ligne du tableau des scores. */
  isAdmin?: boolean
  onDeleteChallenge?: () => void
  onDeleteAttempt?: (attemptId: number) => void
  /** Vue admin uniquement : nomme directement ce défi Champion (voir pvp_promote_to_champion) — affiché en plus du bouton Supprimer, jamais à la place. */
  onPromoteChampion?: () => void
}

// Une bannière par défi actif — pas de GameCard (voir CasinoGameCard) : ce
// mode n'a ni ticket ni milestones, mais a besoin d'un tableau des scores
// intégré, absent du composant générique. Le pokémon défenseur est rendu
// SANS filtre drop-shadow (contrairement aux sprites en combat/déambulation,
// voir AutoBattleScreen/RoamingPokemonSprite) — même traitement "carte plate"
// qu'AutoBattlePokemonPicker.
export function PvpChallengeBanner({ challenge, defenderPlayer, pokemonByName, attempts, playersById, isOwn, onPlay, onWithdraw, readOnly, isAdmin, onDeleteChallenge, onDeleteAttempt, onPromoteChampion }: Props) {
  // false = meilleure tentative de chaque joueur (voir bestAttemptPerPlayer) ;
  // true = historique complet, du plus récent au plus ancien (voir "Voir
  // tout" — attempts arrive déjà trié ainsi par usePvpChallengeAttempts).
  const [showAll, setShowAll] = useState(false)
  const species = pokemonByName.get(challenge.pokemon_nom)
  const bestList = bestAttemptPerPlayer(attempts)
  const visible = showAll ? attempts : bestList
  const hasMore = attempts.length > bestList.length

  return (
    <div className={`p-3 rounded ${PIXEL_BORDER_SM} ${readOnly ? 'bg-cream-secondary opacity-70' : 'bg-cream-secondary'} flex flex-col gap-2`}>
      <div className="flex items-center gap-2">
        <PvpAvatar player={defenderPlayer} />
        <span className="flex-1 min-w-0 text-ink text-sm font-bold truncate">
          Challenge de {defenderPlayer?.name ?? 'Joueur inconnu'}
        </span>
      </div>

      <div className="flex items-center gap-3">
        <div className="w-16 h-16 shrink-0 rounded-md border-2 border-ink bg-cream flex items-center justify-center overflow-hidden">
          {species?.image_miniature ? (
            <img src={species.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
          ) : (
            <span className="text-ink-muted-2 text-2xl">?</span>
          )}
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-ink text-sm font-bold truncate">{challenge.nickname?.trim() || challenge.pokemon_nom}</p>
          <p className="text-ink-muted-2 text-xs">{challenge.max_hp} PV</p>
        </div>
        {isAdmin ? (
          <div className="flex items-center gap-1.5 shrink-0">
            {onPromoteChampion && (
              <button onClick={onPromoteChampion} className={`px-3 py-1.5 rounded text-xs font-bold ${BUTTON_STYLE.yellow}`}>
                👑 Nommer Champion
              </button>
            )}
            <button onClick={onDeleteChallenge} className={`px-3 py-1.5 rounded text-xs font-bold flex items-center gap-1.5 ${BUTTON_STYLE.red}`}>
              <TrashIcon className="w-3.5 h-3.5" />
              Supprimer
            </button>
          </div>
        ) : readOnly ? (
          <span className="text-ink-muted-2 text-xs shrink-0">
            Retiré{challenge.withdrawn_at ? ` le ${new Date(challenge.withdrawn_at).toLocaleDateString()}` : ''}
          </span>
        ) : isOwn ? (
          <button onClick={onWithdraw} className={`px-3 py-1.5 rounded text-xs font-bold shrink-0 ${BUTTON_STYLE.red}`}>
            Retirer
          </button>
        ) : (
          <button onClick={onPlay} className={`px-3 py-1.5 rounded text-xs font-bold shrink-0 ${BUTTON_STYLE.yellow}`}>
            Jouer
          </button>
        )}
      </div>

      <div className="flex flex-col gap-1">
        {attempts.length === 0 ? (
          <p className="text-ink-muted-2 text-xs italic text-center py-1">Aucune tentative pour le moment.</p>
        ) : (
          visible.map((a) => {
            const attackerPlayer = playersById.get(a.attacker_player_id)
            const attackerSpecies = pokemonByName.get(a.attacker_pokemon_nom)
            const won = a.outcome === 'win'
            return (
              <div key={a.id} className="flex items-stretch gap-1.5 text-xs">
                <span className="shrink-0 self-center text-sm leading-none">{won ? '🏆' : '❌'}</span>
                <span className="shrink-0 self-center"><PvpAvatar player={attackerPlayer} /></span>
                <div className="flex-1 min-w-0 flex flex-col justify-center">
                  <span className="text-ink font-bold truncate">{attackerPlayer?.name ?? 'Joueur inconnu'}</span>
                  <span className="text-ink-muted-2 text-[10px]">{formatAttemptTimestamp(a.created_at)}</span>
                </div>
                {attackerSpecies?.image_miniature && (
                  <img src={attackerSpecies.image_miniature} alt="" className="pixelated w-9 h-9 shrink-0 self-center object-contain" />
                )}
                <span className={`shrink-0 self-center font-bold ${won ? 'text-[#2f8f4e]' : 'text-hp-red'}`}>
                  {won ? `${a.duration_turns} tour${a.duration_turns === 1 ? '' : 's'}` : `${a.defender_hp_remaining}PV`}
                </span>
                {isAdmin && (
                  <button
                    onClick={() => onDeleteAttempt?.(a.id)}
                    className={`shrink-0 self-center p-1 rounded ${BUTTON_STYLE.gray}`}
                  >
                    <TrashIcon className="w-3 h-3" />
                  </button>
                )}
              </div>
            )
          })
        )}
        {!showAll && hasMore && (
          <button
            onClick={() => setShowAll(true)}
            className={`self-center mt-1 px-3 py-1 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}
          >
            Voir tout
          </button>
        )}
        {showAll && (
          <button
            onClick={() => setShowAll(false)}
            className={`self-center mt-1 px-3 py-1 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}
          >
            Réduire
          </button>
        )}
      </div>
    </div>
  )
}
