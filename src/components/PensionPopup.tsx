import { useState, useEffect } from 'react'
import type { Player, Pokemon, Item, PlayerPokemon, PokemonEvolution } from '../types'
import { ownedPokemonName } from '../types'
import { usePensionConfig } from '../hooks/usePensionConfig'
import { usePensionGroups } from '../hooks/usePensionGroups'
import { usePensionXpGroups } from '../hooks/usePensionXpGroups'
import { usePensionDaycare } from '../hooks/usePensionDaycare'
import { useToast } from '../context/ToastContext'
import { GameBanner } from './CasinoGameCard'
import { PensionSelectionPopup } from './PensionSelectionPopup'
import { PensionDaycareGrid } from './PensionDaycareGrid'
import { PensionDaycareInfoPopup } from './PensionDaycareInfoPopup'
import { PensionInfoPopup } from './PensionInfoPopup'
import { PensionRetrievedPopup } from './PensionRetrievedPopup'
import { PensionEggRevealPopup } from './PensionEggRevealPopup'
import { PensionHistoryFeed } from './PensionHistoryFeed'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { PENSION_ICON } from '../lib/icons'
import { logHistoryEvent } from '../lib/historyLog'
import { getEvolutionOptions, isRandomEvolutionReady } from '../lib/evolution'
import { resolveApplicableXpGroup } from '../lib/pension'
import type { PensionActionStatus } from '../hooks/usePensionDaycare'

interface Props {
  player: Player
  roster: PlayerPokemon[]
  pokemonByName: Map<string, Pokemon>
  itemsByName: Map<string, Item>
  evolutionsByPokemonNom: Map<string, PokemonEvolution[]>
  onRequestPokemonDetail: (id: number) => void
  onMarkEggSeen: (id: number) => Promise<void>
  onClose: () => void
}

interface RetrievedInfo {
  id: number
  pokemonName: string
  xpGained: number | null
  canEvolve: boolean
}

const PLACE_ERROR_MESSAGES: Partial<Record<PensionActionStatus, string>> = {
  daycare_full: 'Pension complète — réessaie plus tard.',
  player_slot_taken: 'Tu as déjà un pokémon en pension.',
  permanently_capped: 'Ce pokémon a déjà atteint son plafond, il ne peut plus retourner en pension.',
  must_be_in_pc: 'Ce pokémon doit être au PC pour aller en pension.',
  already_placed: 'Ce pokémon est déjà en pension.',
}

export function PensionPopup({
  player, roster, pokemonByName, itemsByName, evolutionsByPokemonNom, onRequestPokemonDetail, onMarkEggSeen, onClose,
}: Props) {
  const { config, loading: configLoading } = usePensionConfig()
  const { eggGroupsByPokemonNom, loading: groupsLoading } = usePensionGroups()
  const { xpGroupByPokemonNom, loading: xpGroupsLoading } = usePensionXpGroups()
  const { daycareRoster, pairsByPokemonId, placeInDaycare, retrieveFromDaycare } = usePensionDaycare(player.id)
  const { showToast } = useToast()
  const [now, setNow] = useState(() => Date.now())
  const [selectedDaycareId, setSelectedDaycareId] = useState<number | null>(null)
  const [showInfo, setShowInfo] = useState(false)
  const [showSelection, setShowSelection] = useState(false)
  const [retrievedInfo, setRetrievedInfo] = useState<RetrievedInfo | null>(null)

  useEffect(() => {
    const interval = window.setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(interval)
  }, [])

  const pcRoster = roster.filter((r) => !r.in_team && !r.in_daycare && !r.daycare_capped)
  const daycareFull = daycareRoster.length >= config.capacity_total
  const selectedDaycarePokemon = daycareRoster.find((r) => r.id === selectedDaycareId) ?? null
  // Un seul à la fois : une fois marqué vu, le suivant (s'il y en a un) prend
  // sa place automatiquement au prochain rendu (roster mis à jour en temps réel).
  const unseenEgg = roster.find((r) => !r.egg_reveal_seen) ?? null

  const handlePlace = async (id: number): Promise<boolean> => {
    const pp = pcRoster.find((r) => r.id === id)
    const result = await placeInDaycare(id)
    if (result.status === 'ok') {
      if (pp) {
        void logHistoryEvent('daycare', 'daycare_drop_off', player.id, {
          pokemon_nom: pp.pokemon_nom, player_pokemon_id: pp.id, nickname: pp.nickname,
        })
        for (const formed of result.formedPairs) {
          void logHistoryEvent('daycare', 'daycare_pair_formed', player.id, {
            pokemon_nom: pp.pokemon_nom, player_pokemon_id: pp.id, nickname: pp.nickname,
            partner_pokemon_nom: formed.partnerPokemonNom,
          })
        }
      }
      return true
    }
    showToast(PLACE_ERROR_MESSAGES[result.status] ?? "Impossible de placer ce pokémon en pension pour l'instant.")
    return false
  }

  // Ferme le popup de sélection uniquement si le placement a réussi — sinon
  // le joueur reste dessus pour voir le toast d'erreur et réessayer.
  const handlePlaceFromSelection = async (id: number) => {
    if (await handlePlace(id)) setShowSelection(false)
  }

  const handleRetrieve = async (id: number) => {
    const pp = daycareRoster.find((r) => r.id === id)
    const status = await retrieveFromDaycare(id)
    setSelectedDaycareId(null)
    if (status === 'ok') {
      if (!pp) return
      void logHistoryEvent('daycare', 'daycare_pickup', player.id, {
        pokemon_nom: pp.pokemon_nom, player_pokemon_id: pp.id, nickname: pp.nickname,
      })
      const species = pokemonByName.get(pp.pokemon_nom)
      const canEvolve =
        getEvolutionOptions(pp, species, evolutionsByPokemonNom, pokemonByName, itemsByName, []).length > 0 ||
        isRandomEvolutionReady(pp, species)
      // null = pas d'instantané de départ (pokémon placé avant l'ajout de ce
      // suivi) — plutôt que d'afficher à tort "0 xp gagné".
      const xpGained = pp.daycare_xp_at_placement != null ? Math.max(0, pp.xp - pp.daycare_xp_at_placement) : null
      setRetrievedInfo({ id, pokemonName: ownedPokemonName(pp), xpGained, canEvolve })
    } else {
      showToast('Impossible de récupérer ce pokémon pour le moment.')
    }
  }

  // On ne rebascule vers la fiche complète (avec animation d'évolution) que si
  // le séjour en pension a effectivement fait franchir un palier d'évolution —
  // sinon on reste simplement sur ce popup.
  const handleContinueAfterRetrieve = () => {
    if (!retrievedInfo) return
    const { id, canEvolve } = retrievedInfo
    setRetrievedInfo(null)
    if (canEvolve) onRequestPokemonDetail(id)
  }

  const loading = configLoading || groupsLoading || xpGroupsLoading

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 sm:p-4 safe-overlay"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div
        className="relative bg-cream w-full h-full overflow-hidden flex flex-col
          sm:h-auto sm:max-w-2xl sm:max-h-[85vh] sm:rounded-[var(--radius-pixel)] sm:border-[3px] sm:border-ink sm:shadow-[var(--shadow-pixel-lg)]"
      >
        <button
          onClick={onClose}
          className="absolute right-3 top-3 z-10 w-8 h-8 rounded-full border-2 border-ink bg-cream shadow-[var(--shadow-pixel)] flex items-center justify-center text-ink hover:bg-black/10 active:shadow-none active:translate-x-[1px] active:translate-y-[1px] transition-all"
        >
          <CloseIcon className="w-4 h-4" />
        </button>

        <GameBanner bannerUrl={config.banner_url} fallbackEmoji="🏡" className="aspect-[21/4.5] shrink-0" />

        <div className="flex items-start justify-between gap-3 px-4 pt-3 sm:px-5">
          <div className="flex items-center gap-2 min-w-0">
            <PixelIcon src={PENSION_ICON} size={24} colored className="text-ink shrink-0" />
            <h3 className="text-ink text-lg font-bold truncate">{config.nom}</h3>
          </div>
          <button
            onClick={() => setShowInfo(true)}
            title="Comment ça marche ?"
            className="w-8 h-8 rounded-full flex items-center justify-center text-ink hover:bg-black/10 shrink-0 text-lg"
          >
            ℹ️
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-4 sm:p-5">
          {loading ? (
            <p className="text-ink-muted-2 text-sm">Chargement…</p>
          ) : (
            <div className="flex flex-col gap-4">
              <div>
                <p className="text-ink text-sm font-bold mb-1.5">En pension actuellement</p>
                <PensionDaycareGrid
                  daycareRoster={daycareRoster}
                  pokemonByName={pokemonByName}
                  pensionConfig={config}
                  xpGroupByPokemonNom={xpGroupByPokemonNom}
                  pairsByPokemonId={pairsByPokemonId}
                  currentPlayerId={player.id}
                  now={now}
                  onSelectCard={setSelectedDaycareId}
                  onRetrieve={handleRetrieve}
                  onOpenSelection={() => setShowSelection(true)}
                />
              </div>

              <div>
                <p className="text-ink text-sm font-bold mb-1.5">Activité récente</p>
                <PensionHistoryFeed pokemonByName={pokemonByName} itemsByName={itemsByName} />
              </div>
            </div>
          )}
        </div>
      </div>

      {selectedDaycarePokemon && (
        <PensionDaycareInfoPopup
          playerPokemon={selectedDaycarePokemon}
          pokemon={pokemonByName.get(selectedDaycarePokemon.pokemon_nom)}
          isMine={selectedDaycarePokemon.player_id === player.id}
          pensionConfig={config}
          applicable={resolveApplicableXpGroup(selectedDaycarePokemon.pokemon_nom, xpGroupByPokemonNom, config)}
          eggGroups={eggGroupsByPokemonNom.get(selectedDaycarePokemon.pokemon_nom) ?? []}
          now={now}
          onRetrieve={selectedDaycarePokemon.player_id === player.id ? () => handleRetrieve(selectedDaycarePokemon.id) : undefined}
          onClose={() => setSelectedDaycareId(null)}
        />
      )}

      {retrievedInfo && (
        <PensionRetrievedPopup
          pokemonName={retrievedInfo.pokemonName}
          xpGained={retrievedInfo.xpGained}
          canEvolve={retrievedInfo.canEvolve}
          onContinue={handleContinueAfterRetrieve}
        />
      )}

      {showInfo && <PensionInfoPopup infoText={config.info_text} onClose={() => setShowInfo(false)} />}

      {showSelection && (
        <PensionSelectionPopup
          pcRoster={pcRoster}
          daycareRoster={daycareRoster}
          pokemonByName={pokemonByName}
          pensionConfig={config}
          xpGroupByPokemonNom={xpGroupByPokemonNom}
          eggGroupsByPokemonNom={eggGroupsByPokemonNom}
          daycareFull={daycareFull}
          onPlace={handlePlaceFromSelection}
          onClose={() => setShowSelection(false)}
        />
      )}

      {!loading && unseenEgg && (
        <PensionEggRevealPopup
          pokemonName={ownedPokemonName(unseenEgg)}
          imageUrl={pokemonByName.get(unseenEgg.pokemon_nom)?.image_miniature}
          onContinue={() => onMarkEggSeen(unseenEgg.id)}
        />
      )}
    </div>
  )
}
