import { useEffect, useState } from 'react'
import type { Player, Pokemon, PvpChallenge, PvpChallengeAttempt } from '../types'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { formatAttemptTimestamp, bestAttemptPerPlayer } from '../lib/pvpAttempts'
import { formatChampionSince } from '../lib/pvpChampion'
import { TrashIcon } from './icons/TrashIcon'
import { PvpAvatar } from './PvpChallengeBanner'

interface Props {
  champion: PvpChallenge | null
  championPlayer: Player | undefined
  pokemonByName: Map<string, Pokemon>
  attempts: PvpChallengeAttempt[]
  playersById: Map<number, Player>
  /** Le joueur qui regarde EST le Champion — masque "Défier", affiche un badge à la place. */
  isOwnChampion: boolean
  /** Le joueur qui regarde a déjà son propre pokémon posté en défi (voir usePvpChallenges) — condition pour pouvoir défier le Champion (c'est ce pokémon qui prendra sa place en cas de victoire). */
  viewerHasOwnChallenge: boolean
  onPlay: () => void
  isAdmin?: boolean
  onDethrone?: () => void
  onDeleteAttempt?: (attemptId: number) => void
}

export function PvpChampionBanner({
  champion, championPlayer, pokemonByName, attempts, playersById, isOwnChampion, viewerHasOwnChallenge, onPlay, isAdmin, onDethrone, onDeleteAttempt,
}: Props) {
  const [now, setNow] = useState(() => new Date())
  const hasChampion = !!champion
  useEffect(() => {
    if (!hasChampion) return
    const interval = window.setInterval(() => setNow(new Date()), 1000)
    return () => clearInterval(interval)
  }, [hasChampion])

  const species = champion ? pokemonByName.get(champion.pokemon_nom) : undefined
  const bestList = bestAttemptPerPlayer(attempts)

  return (
    <div
      className="p-1 rounded-[var(--radius-pixel)] shadow-[0_4px_0_0_#5c4713,0_8px_18px_rgba(0,0,0,0.4)]"
      style={{ background: 'linear-gradient(135deg, #fff3c4 0%, #e8c15a 22%, #b8860b 48%, #f5df9c 65%, #96700f 85%, #f0d478 100%)' }}
    >
      {/* Liseré interne clair — même idée que la bordure externe mais plus fin, pour un effet "double filet" métallique plutôt qu'un simple aplat. */}
      <div className="rounded-[calc(var(--radius-pixel)-2px)] p-[2px]" style={{ background: 'linear-gradient(135deg, rgba(255,255,255,0.85), rgba(255,255,255,0))' }}>
        <div className="rounded-[calc(var(--radius-pixel)-3px)] bg-cream-secondary p-4 flex flex-col gap-3">
          {!champion ? (
            <div className="flex flex-col items-center text-center gap-1 py-4">
              <span className="text-3xl">🏆</span>
              <p className="text-ink-muted-2 text-sm font-bold">Aucun Champion pour le moment.</p>
              {isAdmin && <p className="text-ink-muted-2 text-xs">Nommez-en un depuis les défis actifs ci-dessous.</p>}
            </div>
          ) : (
            <>
              <div className="flex items-center gap-3">
                <span className="text-[26px] shrink-0 drop-shadow-[0_0_5px_rgba(184,134,11,0.65)]">🏆</span>
                <PvpAvatar player={championPlayer} size={36} />
                <span className="flex-1 min-w-0 text-ink text-[18px] font-extrabold tracking-wide truncate">
                  {championPlayer?.name ?? 'Joueur inconnu'}
                </span>
                <span className="shrink-0 text-[14px] font-bold text-[#7a5c0a] bg-[#f5df9c] border border-[#b8860b]/40 rounded-full px-2.5 py-0.5">
                  {formatChampionSince(champion.created_at, now)}
                </span>
              </div>

              <div className="flex items-center gap-4">
                <div
                  className="w-[83px] h-[83px] shrink-0 rounded-md border-2 border-ink bg-cream flex items-center justify-center overflow-hidden"
                  style={{ boxShadow: '0 0 0 3px #f5df9c, 0 0 16px rgba(184,134,11,0.55)' }}
                >
                  {species?.image_miniature ? (
                    <img src={species.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
                  ) : (
                    <span className="text-ink-muted-2 text-3xl">?</span>
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-ink text-[18px] font-extrabold truncate">{champion.nickname?.trim() || champion.pokemon_nom}</p>
                  <p className="text-ink-muted-2 text-[16px] font-bold">{champion.max_hp} PV</p>
                </div>
                {isAdmin ? (
                  <button onClick={onDethrone} className={`px-3 py-2 rounded text-sm font-bold shrink-0 flex items-center gap-1.5 ${BUTTON_STYLE.red}`}>
                    <TrashIcon className="w-3.5 h-3.5" />
                    Dépossession
                  </button>
                ) : isOwnChampion ? (
                  <span className="px-4 py-2 rounded text-sm font-bold shrink-0 bg-[#f5df9c] border-2 border-ink text-ink">
                    👑 C'est vous !
                  </span>
                ) : (
                  <button
                    onClick={onPlay}
                    disabled={!viewerHasOwnChallenge}
                    className="px-5 py-2.5 rounded-lg text-base font-extrabold shrink-0 border-2 border-ink text-[#4a3708] shadow-[var(--shadow-pixel-sm)] hover:brightness-105 active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:brightness-100"
                    style={{ background: 'linear-gradient(160deg, #fff3c4, #f0d478 45%, #d4a72c 100%)' }}
                  >
                    ⚔️ Défier
                  </button>
                )}
              </div>

              {!isAdmin && !isOwnChampion && !viewerHasOwnChallenge && (
                <p className="text-hp-red text-[16px] font-bold text-center">
                  ⚠ Postez d'abord votre pokémon en défi (voir "Challengers" ci-dessous) pour pouvoir affronter le Champion.
                </p>
              )}

              <div className="flex flex-col gap-1.5">
                {attempts.length === 0 ? (
                  <p className="text-ink-muted-2 text-xs italic text-center py-1">Personne n'a encore tenté de détrôner le Champion.</p>
                ) : (
                  bestList.map((a) => {
                    const attackerPlayer = playersById.get(a.attacker_player_id)
                    const attackerSpecies = pokemonByName.get(a.attacker_pokemon_nom)
                    return (
                      <div key={a.id} className="flex items-stretch gap-2 text-[16px]">
                        <span className="shrink-0 self-center text-[18px] leading-none">❌</span>
                        <span className="shrink-0 self-center"><PvpAvatar player={attackerPlayer} /></span>
                        <div className="flex-1 min-w-0 flex flex-col justify-center">
                          <span className="text-ink font-bold truncate">{attackerPlayer?.name ?? 'Joueur inconnu'}</span>
                          <span className="text-ink-muted-2 text-[13px]">{formatAttemptTimestamp(a.created_at)}</span>
                        </div>
                        {attackerSpecies?.image_miniature && (
                          <img src={attackerSpecies.image_miniature} alt="" className="pixelated w-9 h-9 shrink-0 self-center object-contain" />
                        )}
                        <span className="shrink-0 self-center font-bold text-hp-red">{a.defender_hp_remaining}PV</span>
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
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
