import { useState, useRef, useEffect, useMemo, type ReactNode } from 'react'
import type { Pokemon, PlayerPokemon, Attack, Item, PokemonEvolution } from '../types'
import { ownedPokemonName } from '../types'
import type { usePlayerItems } from '../hooks/usePlayerItems'
import { SheetShell } from './SheetShell'
import { EditableName } from './EditableName'
import { TypeBadge } from './TypeBadge'
import { StatRow } from './StatRow'
import { StatGrid } from './StatGrid'
import { StatCell } from './StatCell'
import { AbilityCard } from './AbilityCard'
import { MoveSearchInput } from './MoveSearchInput'
import { HpGauge } from './HpGauge'
import { XpGauge } from './XpGauge'
import { NumberInput } from './NumberInput'
import { ImageLightbox } from './ImageLightbox'
import { AudioDescriptionPlayer } from './AudioDescriptionPlayer'
import { ConfirmPopup } from './ConfirmPopup'
import { AbilityReferencePopup } from './campaign/AbilityReferencePopup'
import { EyeOffIcon } from './icons/EyeOffIcon'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { TrashIcon } from './icons/TrashIcon'
import { STAT_ICON, PC_ICON, GIFT_ICON } from '../lib/icons'
import { useLocalHp, restoreLocalHp } from '../hooks/useLocalHp'
import { useLocalStatus } from '../hooks/useLocalStatus'
import { useHoldRepeat } from '../hooks/useHoldRepeat'
import { getMaxHp } from '../lib/maxHp'
import { getHpBreakdown, getDamageBreakdown, getMilestones, getMaxXp } from '../lib/xpBonuses'
import { getEvolutionOptions, type EvolutionOption } from '../lib/evolution'
import { getStatusInfo } from '../lib/status'
import { StatusSelect } from './StatusSelect'
import { getSuperEfficace, getLocalisations, getAttaques } from '../lib/pokemonFacts'
import { toDatetimeLocalInput, fromDatetimeLocalInput } from '../lib/gifting'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { logHistoryEvent } from '../lib/historyLog'
import { EvolutionPopup } from './EvolutionPopup'
import { useToast } from '../context/ToastContext'
import type { StatusId } from '../lib/status'

export type DetailContext = 'home' | 'pokemon' | 'pokedex'

interface Props {
  context: DetailContext
  pokemon: Pokemon | undefined
  playerPokemon?: PlayerPokemon
  attacksByName: Map<string, Attack>
  isAdmin?: boolean
  onClose: () => void
  /** Passe au-dessus des popups z-50 (ex : ouvert depuis une table de rencontres déjà en popup) */
  elevated?: boolean
  /** Boutons "affichage" (DisplayControlBar), fournis uniquement depuis ReferenceDispatcher */
  displayBar?: ReactNode

  // Instance possédée (contexts home / pokemon)
  teamFull?: boolean
  isNpc?: boolean
  maxMoves?: number
  onUpdateXp?: (id: number, xp: number) => void
  onRename?: (id: number, nickname: string | null) => void
  onToggleInTeam?: (id: number, inTeam: boolean) => void
  onAddMove?: (id: number, moveName: string) => void
  onRemoveMove?: (id: number, moveName: string) => void
  onDelete?: (id: number) => void
  onSetNextGiftAt?: (id: number, nextGiftAt: string | null) => void

  // Évolution (contexts home / pokemon)
  pokemonByName?: Map<string, Pokemon>
  itemsByName?: Map<string, Item>
  evolutionsByPokemonNom?: Map<string, PokemonEvolution[]>
  playerItems?: ReturnType<typeof usePlayerItems>
  onEvolve?: (id: number, newPokemonNom: string, newPokemonNumero: string | null) => Promise<void>

  // Context pokédex
  isDiscovered?: boolean
  ownedCount?: number
  onAddToRoster?: () => void
  onUndiscover?: () => void
  onDiscover?: () => void
}

// Bloc PV / Statut / XP d'une instance possédée — composant séparé pour isoler
// les hooks liés à l'instance (useLocalHp exige un id).
function OwnedVitals({
  playerPokemon,
  pokemon,
  onUpdateXp,
  pokemonByName,
  itemsByName,
  evolutionsByPokemonNom,
  playerItems,
  onEvolve,
}: {
  playerPokemon: PlayerPokemon
  pokemon: Pokemon | undefined
  onUpdateXp?: (id: number, xp: number) => void
  pokemonByName?: Map<string, Pokemon>
  itemsByName?: Map<string, Item>
  evolutionsByPokemonNom?: Map<string, PokemonEvolution[]>
  playerItems?: ReturnType<typeof usePlayerItems>
  onEvolve?: (id: number, newPokemonNom: string, newPokemonNumero: string | null) => Promise<void>
}) {
  const maxHp = getMaxHp(playerPokemon, pokemon)
  const [hp, setHp] = useLocalHp(playerPokemon.id, maxHp)
  const [status, setStatus] = useLocalStatus(playerPokemon.id)
  const hpRef = useRef(hp)
  useEffect(() => { hpRef.current = hp }, [hp])
  const { showToast } = useToast()
  const [evolving, setEvolving] = useState<{
    fromSpecies: Pokemon | undefined
    toSpecies: Pokemon | undefined
    fromDisplayName: string
    toDisplayName: string
  } | null>(null)

  const combatBase = {
    pokemon_nom: playerPokemon.pokemon_nom,
    player_pokemon_id: playerPokemon.id,
    nickname: playerPokemon.nickname,
  }

  const handleSetHp = (value: number) => {
    const wasKo = hpRef.current <= 0
    setHp(value)
    const willBeKo = Math.max(0, Math.min(maxHp, value)) <= 0
    if (wasKo !== willBeKo) {
      void logHistoryEvent('combat', 'ko', playerPokemon.player_id, { ...combatBase, ko: willBeKo })
    }
  }

  const handleSetStatus = (value: StatusId) => {
    const prev = status
    setStatus(value)
    if (prev === value) return
    if (prev !== 'aucun') {
      void logHistoryEvent('combat', 'status_change', playerPokemon.player_id, { ...combatBase, status_id: prev, status_gained: false })
    }
    if (value !== 'aucun') {
      void logHistoryEvent('combat', 'status_change', playerPokemon.player_id, { ...combatBase, status_id: value, status_gained: true })
    }
  }

  const decrementHold = useHoldRepeat(() => handleSetHp(hpRef.current - 1))
  const incrementHold = useHoldRepeat(() => handleSetHp(hpRef.current + 1))
  const milestones = useMemo(() => getMilestones(pokemon), [pokemon])
  const maxXp = useMemo(() => getMaxXp(pokemon), [pokemon])
  const handleXpChange = (xp: number) => onUpdateXp?.(playerPokemon.id, xp)

  const evolutionOptions = useMemo(() => {
    if (!pokemonByName || !itemsByName || !evolutionsByPokemonNom) return []
    return getEvolutionOptions(playerPokemon, pokemon, evolutionsByPokemonNom, pokemonByName, itemsByName, playerItems?.inventory ?? [])
  }, [playerPokemon, pokemon, evolutionsByPokemonNom, pokemonByName, itemsByName, playerItems?.inventory])

  // Objet de la première évolution avec condition (indépendant de la disponibilité
  // actuelle) — sert à remplacer le token "[objet]" dans les libellés de la jauge XP,
  // ex : "Évo. possible [objet]" -> texte + icône de l'objet requis.
  const evolutionConditionItem = useMemo(() => {
    if (!pokemon || !evolutionsByPokemonNom || !itemsByName) return null
    const rows = evolutionsByPokemonNom.get(pokemon.nom) ?? []
    const itemNom = rows.find((r) => r.condition_item_nom)?.condition_item_nom
    return itemNom ? itemsByName.get(itemNom) ?? null : null
  }, [pokemon, evolutionsByPokemonNom, itemsByName])

  const handleEvolveClick = (opt: EvolutionOption) => {
    if (evolving != null || !onEvolve) return

    if (!opt.clickable) {
      const itemName = opt.conditionItem?.nom ?? opt.evolution.condition_item_nom
      showToast(`Il vous faut ${itemName} pour faire évoluer ce Pokémon`)
      return
    }

    const fromDisplayName = ownedPokemonName(playerPokemon)
    const toDisplayName = opt.evolution.evolution_nom
    const fromSpecies = pokemon
    const toSpecies = opt.targetSpecies

    setEvolving({ fromSpecies, toSpecies, fromDisplayName, toDisplayName })

    void (async () => {
      await onEvolve(playerPokemon.id, opt.evolution.evolution_nom, toSpecies?.numero ?? null)

      if (opt.evolution.condition_item_nom && playerItems) {
        const row = playerItems.inventory.find((r) => r.item_nom === opt.evolution.condition_item_nom)
        if (row && row.quantity > 0) {
          const total = row.quantity - 1
          await playerItems.setQuantity(row, total)
          void logHistoryEvent('inventory', 'item_remove', playerPokemon.player_id, {
            item_nom: opt.evolution.condition_item_nom,
            delta: 1,
            total,
            source: `l'évolution de ${fromDisplayName}`,
          })
        }
      }

      // evolvePokemon remet toujours l'XP à 0 côté serveur — on calcule les PV max
      // sur cette base plutôt que sur playerPokemon.xp, qui est figé (fermeture) sur
      // l'XP d'avant évolution tant que ce composant n'a pas re-rendu avec les nouvelles props.
      if (toSpecies) restoreLocalHp(playerPokemon.id, getMaxHp({ ...playerPokemon, xp: 0 }, toSpecies))
      setStatus('aucun')

      void logHistoryEvent('team', 'pokemon_evolve', playerPokemon.player_id, {
        pokemon_nom: playerPokemon.pokemon_nom,
        player_pokemon_id: playerPokemon.id,
        nickname: playerPokemon.nickname,
        to_pokemon_nom: opt.evolution.evolution_nom,
      })
    })()
  }

  return (
    <div className="mb-3">
      <div className="flex items-center gap-3 mb-2">
        <div className="flex items-center gap-2 shrink-0">
          <span className="text-ink-muted-2 text-xs">PV</span>
          <button
            {...decrementHold}
            className={`w-6 h-6 rounded ${PIXEL_BORDER_SM} bg-cream-button text-ink hover:brightness-105`}
          >
            −
          </button>
          <NumberInput
            value={hp}
            onCommit={handleSetHp}
            className="w-14 bg-white border-2 border-ink rounded px-1 py-0.5 text-ink text-sm text-center outline-none"
          />
          <button
            {...incrementHold}
            className={`w-6 h-6 rounded ${PIXEL_BORDER_SM} bg-cream-button text-ink hover:brightness-105`}
          >
            +
          </button>
        </div>

        <StatusSelect value={status} onChange={handleSetStatus} />
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

      <div className="flex flex-col">
        <HpGauge current={hp} max={maxHp} onChange={handleSetHp} />
        {maxXp != null ? (
          <div className="mt-3">
            <XpGauge
              xp={playerPokemon.xp}
              max={maxXp}
              milestones={milestones}
              onXpChange={handleXpChange}
              evolutionItemIconUrl={evolutionConditionItem?.image_url ?? null}
              evolutionItemName={evolutionConditionItem?.nom ?? null}
            />
          </div>
        ) : (
          <div className="flex items-center gap-2 mt-3">
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

        {evolutionOptions.length > 0 && (
          <div className="flex flex-col gap-2 mt-1">
            {evolutionOptions.map((opt) => (
              <button
                key={opt.evolution.id}
                disabled={evolving != null}
                onClick={() => handleEvolveClick(opt)}
                className={`py-3 rounded-lg text-sm font-bold inline-flex items-center justify-center gap-2 ${
                  opt.clickable
                    ? BUTTON_STYLE.yellow
                    : 'bg-[#3a3c58] text-[#7a7c9a] border-2 border-[#6a6a6a] cursor-not-allowed'
                }`}
              >
                {opt.conditionItem?.image_url ? (
                  <img
                    src={opt.conditionItem.image_url}
                    alt=""
                    className={`w-6 h-6 object-contain ${opt.clickable ? '' : 'grayscale opacity-60'}`}
                  />
                ) : opt.targetSpecies?.image_miniature ? (
                  // Pas d'objet requis : plusieurs évolutions peuvent être proposées au choix du
                  // joueur (ex : Évoli) — l'icône de l'espèce cible permet de les distinguer.
                  <img
                    src={opt.targetSpecies.image_miniature}
                    alt=""
                    className={`pixelated w-6 h-6 object-contain ${opt.clickable ? '' : 'grayscale opacity-60'}`}
                  />
                ) : null}
                ✨ ÉVOLUTION !
              </button>
            ))}
          </div>
        )}
      </div>

      {evolving && (
        <EvolutionPopup
          fromSpecies={evolving.fromSpecies}
          toSpecies={evolving.toSpecies}
          fromDisplayName={evolving.fromDisplayName}
          toDisplayName={evolving.toDisplayName}
          onDone={() => setEvolving(null)}
        />
      )}
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
  elevated = false,
  displayBar,
  teamFull = false,
  isNpc = false,
  maxMoves,
  onUpdateXp,
  onRename,
  onToggleInTeam,
  onAddMove,
  onRemoveMove,
  onDelete,
  onSetNextGiftAt,
  pokemonByName,
  itemsByName,
  evolutionsByPokemonNom,
  playerItems,
  onEvolve,
  isDiscovered = true,
  ownedCount = 0,
  onAddToRoster,
  onUndiscover,
  onDiscover,
}: Props) {
  const [lightboxOpen, setLightboxOpen] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [abilitiesOpen, setAbilitiesOpen] = useState(context === 'home')
  const [viewingAbility, setViewingAbility] = useState<Attack | null>(null)
  const nextGiftInputRef = useRef<HTMLInputElement>(null)

  const isOwnedContext = context !== 'pokedex' && playerPokemon != null

  const nom = (playerPokemon ? ownedPokemonName(playerPokemon) : pokemon?.nom) ?? '???'
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
  const addableMoves = useMemo(
    () => [...attacksByName.values()].filter((a) => !(playerPokemon?.moves ?? []).includes(a.nom)),
    [attacksByName, playerPokemon?.moves]
  )
  const atMoveCap = maxMoves != null && knownMoves.length >= maxMoves

  return (
    <SheetShell onClose={onClose} elevated={elevated}>
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
            {isOwnedContext && playerPokemon && onRename ? (
              <EditableName
                value={nom}
                onCommit={(v) => onRename(playerPokemon.id, v || null)}
                className="text-[22px] leading-tight text-ink"
              />
            ) : (
              <h2 className="text-[22px] leading-tight text-ink truncate">{nom}</h2>
            )}
            {pokemon && <TypeBadge type={pokemon.type} small />}
          </div>

          <button
            onClick={onClose}
            className={`w-8 h-8 shrink-0 rounded-md ${PIXEL_BORDER_SM} bg-cream-button text-ink text-sm`}
          >
            <CloseIcon className="w-4 h-4 mx-auto" />
          </button>
        </div>

        {displayBar}

        {pokemon?.audio_url && <AudioDescriptionPlayer key={pokemon.id} audioUrl={pokemon.audio_url} />}

        {/* PV / Statut / XP (instance possédée uniquement) */}
        {isOwnedContext && playerPokemon && (
          <OwnedVitals
            playerPokemon={playerPokemon}
            pokemon={pokemon}
            onUpdateXp={onUpdateXp}
            pokemonByName={pokemonByName}
            itemsByName={itemsByName}
            evolutionsByPokemonNom={evolutionsByPokemonNom}
            playerItems={playerItems}
            onEvolve={onEvolve}
          />
        )}

        {/* Grille de stats numériques : icône + valeur uniquement */}
        <div className="mb-3">
          <StatGrid>
            <StatCell icon={<PixelIcon src={STAT_ICON.hp} size={22} />} title="PV de base" value={pvValue} />
            <StatCell icon={<PixelIcon src={STAT_ICON.damage} size={22} />} title="Dégâts de base" value={degValue} />
            {pokemon && (
              <StatCell icon={<PixelIcon src={STAT_ICON.distance} size={22} />} title="Distance de déplacement" value={`${pokemon.distance_deplacement} cases`} />
            )}
            {isAdmin && pokemon?.chances_capture && (
              <StatCell icon={<PixelIcon src={STAT_ICON.catchrate} size={22} />} title="Chances de capture (info admin)" value={pokemon.chances_capture} adminOnly />
            )}
          </StatGrid>
        </div>

        {pokemon && (
          <>
            {pokemon.transport && (
              <StatRow
                icon={<PixelIcon src={STAT_ICON.transport} size={22} />}
                title={`Transport : ${pokemon.transport}`}
                value={`${pokemon.transport}${pokemon.transport_value != null ? ` (${pokemon.transport_value})` : ''}`}
              />
            )}

            <StatRow
              icon={<PixelIcon src={STAT_ICON.supereffective} size={22} />}
              title="Super efficace contre"
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
                <span className="w-7 shrink-0 flex items-center justify-center">
                  <PixelIcon src={STAT_ICON.talent} size={22} />
                </span>
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

            {localisations.length > 0 && (
              <StatRow
                icon={<PixelIcon src={STAT_ICON.location} size={22} />}
                title="Localisation"
                value={
                  <div className="flex flex-col gap-0.5">
                    {localisations.map((l) => (
                      <span key={l}>{l}</span>
                    ))}
                  </div>
                }
              />
            )}
          </>
        )}

        {/* Capacités */}
        {isOwnedContext && playerPokemon ? (
          <div className="mt-3">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-ink font-bold inline-flex items-center gap-1.5">
                <PixelIcon src={STAT_ICON.abilities} size={22} />
                Capacités{maxMoves != null ? ` (${knownMoves.length}/${maxMoves})` : ''}
              </span>
              <button
                onClick={() => setAbilitiesOpen((o) => !o)}
                className={`text-xs px-2.5 py-1 rounded-md ${BUTTON_STYLE.gray}`}
              >
                {abilitiesOpen ? 'Masquer' : 'Afficher'}
              </button>
            </div>
            {abilitiesOpen && (
              <>
                {knownMoves.length === 0 ? (
                  <p className="text-ink-muted-2 text-sm mb-2">Aucune capacité apprise.</p>
                ) : (
                  <div className="flex flex-col gap-2 mb-2">
                    {knownMoves.map((moveName) => {
                      const atk = attacksByName.get(moveName)
                      return atk ? (
                        <AbilityCard
                          key={moveName}
                          attack={atk}
                          onRemove={onRemoveMove ? () => onRemoveMove(playerPokemon.id, moveName) : undefined}
                          onClick={() => setViewingAbility(atk)}
                        />
                      ) : (
                        <span key={moveName} className="text-xs text-ink-muted-2 border border-ink/30 rounded px-1.5 py-0.5 self-start">
                          {moveName}
                        </span>
                      )
                    })}
                  </div>
                )}
                {onAddMove && !atMoveCap && (
                  <MoveSearchInput
                    options={addableMoves}
                    disabled={false}
                    onSelect={(a) => onAddMove(playerPokemon.id, a.nom)}
                  />
                )}
              </>
            )}
          </div>
        ) : (
          canShowAttaques && learnableAttaques.length > 0 && (
            <div className="mt-3">
              <span className="text-sm text-ink font-bold inline-flex items-center gap-1.5 mb-2">
              <PixelIcon src={STAT_ICON.abilities} size={22} />
              Capacités apprenables
            </span>
              <div className="flex flex-wrap gap-1.5">
                {learnableAttaques.map((moveName) => {
                  const atk = attacksByName.get(moveName)
                  return atk ? (
                    <button key={moveName} type="button" onClick={() => setViewingAbility(atk)} className="cursor-pointer">
                      <TypeBadge type={atk.type} label={atk.nom} small />
                    </button>
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
                    className={`flex-1 py-2.5 rounded-lg text-sm font-bold inline-flex items-center justify-center gap-1.5 ${BUTTON_STYLE.blue}`}
                  >
                    <PixelIcon src={PC_ICON} size={16} colored /> Mettre au PC
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
                  <TrashIcon className="w-4 h-4" />
                </button>
              )}
            </div>
          )}

          {isAdmin && isOwnedContext && playerPokemon && playerPokemon.in_team && !isNpc && onSetNextGiftAt && (
            <div className={`mt-3 p-3 rounded-lg ${PIXEL_BORDER_SM} bg-cream-secondary`}>
              <p className="text-ink-muted-2 text-xs font-bold mb-2 inline-flex items-center gap-1.5"><PixelIcon src={GIFT_ICON} size={14} colored /> Prochain cadeau (admin)</p>
              <div className="flex gap-2">
                <input
                  key={`${playerPokemon.id}-${playerPokemon.next_gift_at}`}
                  ref={nextGiftInputRef}
                  type="datetime-local"
                  defaultValue={toDatetimeLocalInput(playerPokemon.next_gift_at)}
                  className="flex-1 min-w-0 bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none"
                />
                <button
                  onClick={() => {
                    const v = nextGiftInputRef.current?.value ?? ''
                    onSetNextGiftAt(playerPokemon.id, v ? fromDatetimeLocalInput(v) : null)
                  }}
                  className={`px-3 py-1.5 rounded text-sm font-bold ${BUTTON_STYLE.yellow}`}
                >
                  Enregistrer
                </button>
              </div>
              <button
                onClick={() => onSetNextGiftAt(playerPokemon.id, new Date().toISOString())}
                className={`mt-2 w-full py-1.5 rounded text-xs font-bold ${BUTTON_STYLE.green}`}
              >
                ⚡ Disponible maintenant
              </button>
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

        {isAdmin && pokemon?.cache && pokemon?.code && (
          <p className="mt-3 text-center text-xs text-purple-900 bg-purple-100 border border-purple-700 rounded px-2 py-1.5">
            Code secret (admin) : <span className="font-bold tracking-widest">{pokemon.code}</span>
          </p>
        )}
      </div>

      {viewingAbility && (
        <AbilityReferencePopup attack={viewingAbility} elevated={elevated} onClose={() => setViewingAbility(null)} />
      )}

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
