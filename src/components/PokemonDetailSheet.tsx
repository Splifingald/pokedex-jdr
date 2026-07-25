import { useState, useRef, useEffect, useMemo } from 'react'
import type { Pokemon, PlayerPokemon, Attack } from '../types'
import { SheetShell } from './SheetShell'
import { TypeBadge } from './TypeBadge'
import { StatRow } from './StatRow'
import { StatGrid } from './StatGrid'
import { StatCell } from './StatCell'
import { AbilityCard } from './AbilityCard'
import { HpGauge } from './HpGauge'
import { XpGauge } from './XpGauge'
import { NumberInput } from './NumberInput'
import { ImageLightbox } from './ImageLightbox'
import { AudioDescriptionPlayer } from './AudioDescriptionPlayer'
import { ConfirmPopup } from './ConfirmPopup'
import { EyeOffIcon } from './icons/EyeOffIcon'
import { useLocalHp } from '../hooks/useLocalHp'
import { useLocalStatus } from '../hooks/useLocalStatus'
import { useHoldRepeat } from '../hooks/useHoldRepeat'
import { getMaxHp } from '../lib/maxHp'
import { getHpBreakdown, getDamageBreakdown, getMilestones, getMaxXp } from '../lib/xpBonuses'
import { STATUS_LIST, getStatusInfo } from '../lib/status'
import { getSuperEfficace, getLocalisations, getAttaques } from '../lib/pokemonFacts'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'

export type DetailContext = 'home' | 'pokemon' | 'pokedex'

interface Props {
  context: DetailContext
  pokemon: Pokemon | undefined
  playerPokemon?: PlayerPokemon
  attacksByName: Map<string, Attack>
  isAdmin?: boolean
  onClose: () => void

  // Instance possédée (contexts home / pokemon)
  teamFull?: boolean
  isNpc?: boolean
  maxMoves?: number
  onUpdateXp?: (id: number, xp: number) => void
  onToggleInTeam?: (id: number, inTeam: boolean) => void
  onManageMoves?: () => void
  onDelete?: (id: number) => void

  // Context pokédex
  isDiscovered?: boolean
  ownedCount?: number
  onAddToRoster?: () => void
  onUndiscover?: () => void
  onDiscover?: () => void
}

const TRANSPORT_ICONS: Record<string, string> = {
  Vol: '🕊️',
  Nage: '🏊',
  Sol: '🐾',
}

// Bloc PV / Statut / XP d'une instance possédée — composant séparé pour isoler
// les hooks liés à l'instance (useLocalHp exige un id).
function OwnedVitals({
  playerPokemon,
  pokemon,
  onUpdateXp,
}: {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  onUpdateXp?: (id: number, xp: number) => void
}) {
  const maxHp = getMaxHp(playerPokemon, pokemon)
  const [hp, setHp] = useLocalHp(playerPokemon.id, maxHp)
  const [status, setStatus] = useLocalStatus(playerPokemon.id)
  const hpRef = useRef(hp)
  useEffect(() => { hpRef.current = hp }, [hp])
  const decrementHold = useHoldRepeat(() => setHp(hpRef.current - 1))
  const incrementHold = useHoldRepeat(() => setHp(hpRef.current + 1))
  const milestones = useMemo(() => getMilestones(pokemon), [pokemon])
  const maxXp = useMemo(() => getMaxXp(pokemon), [pokemon])
  const handleXpChange = (xp: number) => onUpdateXp?.(playerPokemon.id, xp)

  return (
    <div className="mb-3">
      <div className="flex items-center gap-4 flex-wrap mb-2">
        <div className="flex items-center gap-2">
          <span className="text-ink-muted-2 text-xs">PV</span>
          <button
            {...decrementHold}
            className={`w-6 h-6 rounded ${PIXEL_BORDER_SM} bg-cream-button text-ink hover:brightness-105`}
          >
            −
          </button>
          <NumberInput
            value={hp}
            onCommit={setHp}
            className="w-14 bg-white border-2 border-ink rounded px-1 py-0.5 text-ink text-sm text-center outline-none"
          />
          <button
            {...incrementHold}
            className={`w-6 h-6 rounded ${PIXEL_BORDER_SM} bg-cream-button text-ink hover:brightness-105`}
          >
            +
          </button>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-ink-muted-2 text-xs">Statut</span>
          <select
            value={status}
            onChange={(e) => setStatus(e.target.value as typeof status)}
            className="bg-white border-2 border-ink rounded px-2 py-1 text-ink text-sm outline-none"
          >
            {STATUS_LIST.map((s) => (
              <option key={s.id} value={s.id}>{s.label}</option>
            ))}
          </select>
        </div>
      </div>

      {status !== 'aucun' && (
        <div
          className="mb-2 rounded px-3 py-2 text-xs border-2"
          style={{ borderColor: getStatusInfo(status).color, backgroundColor: `${getStatusInfo(status).color}22`, color: '#201c14' }}
        >
          <span className="font-bold" style={{ color: getStatusInfo(status).color }}>{getStatusInfo(status).label}</span>
          {' — '}{getStatusInfo(status).description}
        </div>
      )}

      <div className="flex flex-col gap-2">
        <HpGauge current={hp} max={maxHp} onChange={setHp} />
        {maxXp != null ? (
          <XpGauge xp={playerPokemon.xp} max={maxXp} milestones={milestones} onXpChange={handleXpChange} />
        ) : (
          <div className="flex items-center gap-2">
            <span className="text-ink-muted-2 text-xs">Expérience</span>
            <button
              onClick={() => handleXpChange(Math.max(0, playerPokemon.xp - 1))}
              className={`w-6 h-6 rounded ${PIXEL_BORDER_SM} bg-cream-button text-ink hover:brightness-105`}
            >
              −
            </button>
            <NumberInput
              value={playerPokemon.xp}
              onCommit={(v) => handleXpChange(Math.max(0, v))}
              className="w-16 bg-white border-2 border-ink rounded px-1 py-0.5 text-xp-blue font-bold text-sm text-center outline-none"
            />
            <button
              onClick={() => handleXpChange(playerPokemon.xp + 1)}
              className={`w-6 h-6 rounded ${PIXEL_BORDER_SM} bg-cream-button text-ink hover:brightness-105`}
            >
              +
            </button>
          </div>
        )}
      </div>
    </div>
  )
}

export function PokemonDetailSheet({
  context,
  pokemon,
  playerPokemon,
  attacksByName,
  isAdmin = false,
  onClose,
  teamFull = false,
  isNpc = false,
  maxMoves,
  onUpdateXp,
  onToggleInTeam,
  onManageMoves,
  onDelete,
  isDiscovered = true,
  ownedCount = 0,
  onAddToRoster,
  onUndiscover,
  onDiscover,
}: Props) {
  const [lightboxOpen, setLightboxOpen] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [abilitiesOpen, setAbilitiesOpen] = useState(context === 'home')

  const isOwnedContext = context !== 'pokedex' && playerPokemon != null

  const nom = playerPokemon?.pokemon_nom ?? pokemon?.nom ?? '???'
  const numero = pokemon?.numero ?? playerPokemon?.pokemon_numero ?? '???'

  const superEfficace = getSuperEfficace(pokemon)
  const localisations = getLocalisations(pokemon)
  const learnableAttaques = getAttaques(pokemon)
  const canShowAttaques = isAdmin || isDiscovered

  // Stats : bonus d'XP inclus pour une instance possédée, valeurs brutes sinon
  const hpBreakdown = isOwnedContext ? getHpBreakdown(pokemon, playerPokemon!.xp) : null
  const dmgBreakdown = isOwnedContext ? getDamageBreakdown(pokemon, playerPokemon!.xp) : null
  const pvValue = hpBreakdown
    ? hpBreakdown.bonus > 0 ? `${hpBreakdown.total} (${hpBreakdown.base} + ${hpBreakdown.bonus})` : hpBreakdown.total
    : pokemon?.pv_base ?? '—'
  const degValue = dmgBreakdown
    ? dmgBreakdown.bonus > 0 ? `${dmgBreakdown.total} (${dmgBreakdown.base} + ${dmgBreakdown.bonus})` : dmgBreakdown.total
    : pokemon?.degats_base ?? '—'

  const knownMoves = playerPokemon?.moves ?? []

  return (
    <SheetShell onClose={onClose}>
      <div className="p-4">
        {/* En-tête */}
        <div className="flex items-center gap-3.5 mb-3">
          <button
            onClick={() => pokemon?.image_miniature && setLightboxOpen(true)}
            className={`w-[76px] h-[76px] shrink-0 rounded-lg ${PIXEL_BORDER_SM} bg-cream-secondary flex items-center justify-center overflow-hidden ${pokemon?.image_miniature ? 'cursor-zoom-in' : 'cursor-default'}`}
          >
            {pokemon?.image_miniature ? (
              <img src={pokemon.image_miniature} alt={nom} className="pixelated max-w-full max-h-full object-contain" />
            ) : (
              <span className="text-ink-muted-2 text-3xl">?</span>
            )}
          </button>

          <div className="flex-1 min-w-0">
            <p className="text-xs text-ink-muted-2">
              #{numero}
              {isAdmin && pokemon?.cache && (
                <span className="ml-2 text-[10px] bg-purple-200 text-purple-900 border border-purple-700 rounded px-1.5 py-0.5">CACHÉ</span>
              )}
            </p>
            <h2 className="text-[22px] leading-tight text-ink truncate">{nom}</h2>
            {pokemon && <TypeBadge type={pokemon.type} small />}
          </div>

          <button
            onClick={onClose}
            className={`w-8 h-8 shrink-0 rounded-md ${PIXEL_BORDER_SM} bg-cream-button text-ink text-sm`}
          >
            ✕
          </button>
        </div>

        {pokemon?.audio_url && <AudioDescriptionPlayer key={pokemon.id} audioUrl={pokemon.audio_url} />}

        {/* PV / Statut / XP (instance possédée uniquement) */}
        {isOwnedContext && playerPokemon && (
          <OwnedVitals playerPokemon={playerPokemon} pokemon={pokemon} onUpdateXp={onUpdateXp} />
        )}

        {/* Grille de stats */}
        <div className="mb-3">
          <StatGrid>
            <StatCell label="PV DE BASE" value={pvValue} />
            <StatCell label="DÉGÂTS BASE" value={degValue} />
          </StatGrid>
        </div>

        {pokemon && (
          <>
            <StatRow icon="👟" label="Distance" value={`${pokemon.distance_deplacement} cases`} />

            {pokemon.transport && (
              <StatRow
                icon={TRANSPORT_ICONS[pokemon.transport] ?? '🚚'}
                label="Transport"
                value={`${pokemon.transport}${pokemon.transport_value != null ? ` (${pokemon.transport_value})` : ''}`}
              />
            )}

            <StatRow
              icon="✨"
              label="Super Efficace"
              value={
                superEfficace.length > 0 ? (
                  <div className="flex flex-wrap gap-1">
                    {superEfficace.map((t) => (
                      <TypeBadge key={t} type={t} small />
                    ))}
                  </div>
                ) : (
                  <span className="text-ink-muted-2">—</span>
                )
              }
            />

            {(pokemon.nom_talent || pokemon.description_talent) && (
              <div className="flex items-start gap-3 py-2 border-b border-ink/20">
                <span className="text-xl w-7 shrink-0 text-center">⭐</span>
                <div className="flex-1">
                  {pokemon.nom_talent && (
                    <p className="text-hp-orange text-sm font-bold">{pokemon.nom_talent}</p>
                  )}
                  {pokemon.description_talent && (
                    <p className="text-ink-muted text-sm mt-0.5">{pokemon.description_talent}</p>
                  )}
                </div>
              </div>
            )}

            <StatRow
              icon="📍"
              label="Localisation"
              value={
                localisations.length > 0 ? (
                  <div className="flex flex-col gap-0.5">
                    {localisations.map((l) => (
                      <span key={l}>{l}</span>
                    ))}
                  </div>
                ) : (
                  <span className="text-ink-muted-2">—</span>
                )
              }
            />

            {isAdmin && pokemon.chances_capture && (
              <div className="flex items-start gap-3 py-2 border-b border-ink/20 bg-yellow-100/60 -mx-4 px-4">
                <span className="text-xl w-7 shrink-0 text-center">🎯</span>
                <span className="text-ink-muted-2 text-sm w-32 shrink-0">Capture</span>
                <span className="text-ink text-sm font-bold">{pokemon.chances_capture}</span>
              </div>
            )}
          </>
        )}

        {/* Capacités */}
        {isOwnedContext && playerPokemon ? (
          <div className="mt-3">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-ink font-bold">
                🥊 Capacités{maxMoves != null ? ` (${knownMoves.length}/${maxMoves})` : ''}
              </span>
              <div className="flex items-center gap-1.5">
                {onManageMoves && (
                  <button
                    onClick={onManageMoves}
                    className={`text-xs px-2.5 py-1 rounded-md font-bold ${BUTTON_STYLE.orange}`}
                  >
                    Gérer
                  </button>
                )}
                <button
                  onClick={() => setAbilitiesOpen((o) => !o)}
                  className={`text-xs px-2.5 py-1 rounded-md ${BUTTON_STYLE.gray}`}
                >
                  {abilitiesOpen ? 'Masquer' : 'Afficher'}
                </button>
              </div>
            </div>
            {abilitiesOpen && (
              knownMoves.length === 0 ? (
                <p className="text-ink-muted-2 text-sm">Aucune capacité apprise.</p>
              ) : (
                <div className="flex flex-col gap-2">
                  {knownMoves.map((moveName) => {
                    const atk = attacksByName.get(moveName)
                    return atk ? (
                      <AbilityCard key={moveName} attack={atk} />
                    ) : (
                      <span key={moveName} className="text-xs text-ink-muted-2 border border-ink/30 rounded px-1.5 py-0.5 self-start">
                        {moveName}
                      </span>
                    )
                  })}
                </div>
              )
            )}
          </div>
        ) : (
          canShowAttaques && learnableAttaques.length > 0 && (
            <div className="mt-3">
              <span className="text-sm text-ink font-bold block mb-2">🥊 Capacités apprenables</span>
              <div className="flex flex-wrap gap-1.5">
                {learnableAttaques.map((moveName) => {
                  const atk = attacksByName.get(moveName)
                  return atk ? (
                    <TypeBadge key={moveName} type={atk.type} label={atk.nom} small />
                  ) : (
                    <span key={moveName} className="text-xs text-ink-muted-2 border border-ink/30 rounded px-1.5 py-0.5">
                      {moveName}
                    </span>
                  )
                })}
              </div>
            </div>
          )
        )}

        {/* Pied de fiche — action contextuelle */}
        <div className="mt-4 mb-1">
          {isOwnedContext && playerPokemon && (
            <div className="flex gap-2">
              {!isNpc && (
                playerPokemon.in_team ? (
                  <button
                    onClick={() => onToggleInTeam?.(playerPokemon.id, false)}
                    className={`flex-1 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.blue}`}
                  >
                    📦 Mettre au PC
                  </button>
                ) : !teamFull ? (
                  <button
                    onClick={() => onToggleInTeam?.(playerPokemon.id, true)}
                    className={`flex-1 py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.green}`}
                  >
                    ⚔️ Ajouter à l'équipe
                  </button>
                ) : (
                  <button
                    disabled
                    className="flex-1 py-2.5 rounded-lg text-sm font-bold bg-[#3a3c58] text-[#7a7c9a] border-2 border-[#6a6a6a] cursor-not-allowed"
                  >
                    Équipe pleine
                  </button>
                )
              )}
              {onDelete && (
                <button
                  onClick={() => setShowDeleteConfirm(true)}
                  title="Supprimer ce pokémon"
                  className={`px-3.5 py-2.5 rounded-lg text-sm ${BUTTON_STYLE.gray}`}
                >
                  🗑
                </button>
              )}
            </div>
          )}

          {context === 'pokedex' && (isDiscovered || isAdmin) && (
            <div className="flex flex-col gap-2">
              {isDiscovered && ownedCount > 0 && (
                <p className="text-center text-xs text-[#5c8f6a]">✓ Déjà dans votre roster ({ownedCount})</p>
              )}
              {isDiscovered && onAddToRoster && (
                <button
                  onClick={onAddToRoster}
                  className={`w-full py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.blue}`}
                >
                  + {teamFull ? 'Ajouter à mon PC' : 'Ajouter à mon équipe'}
                </button>
              )}
              {isDiscovered && !isAdmin && onUndiscover && (
                <button
                  onClick={onUndiscover}
                  className={`flex items-center justify-center gap-1.5 py-2 rounded-lg text-xs ${BUTTON_STYLE.gray}`}
                >
                  <EyeOffIcon className="w-3.5 h-3.5" />
                  Marquer comme non découvert
                </button>
              )}
              {isAdmin && !isDiscovered && onDiscover && (
                <button
                  onClick={onDiscover}
                  className={`w-full py-2.5 rounded-lg text-sm font-bold ${BUTTON_STYLE.green}`}
                >
                  ✓ Marquer comme découvert
                </button>
              )}
            </div>
          )}
        </div>
      </div>

      {lightboxOpen && pokemon?.image_miniature && (
        <ImageLightbox
          src={pokemon.image_miniature}
          alt={nom}
          onClose={() => setLightboxOpen(false)}
        />
      )}

      {showDeleteConfirm && playerPokemon && (
        <ConfirmPopup
          title="Supprimer ce pokémon ?"
          message={`${nom} sera définitivement retiré de votre roster.`}
          confirmLabel="Supprimer"
          danger
          onConfirm={() => { onDelete?.(playerPokemon.id); setShowDeleteConfirm(false); onClose() }}
          onCancel={() => setShowDeleteConfirm(false)}
        />
      )}
    </SheetShell>
  )
}
