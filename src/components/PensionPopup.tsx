import { useState, useEffect } from 'react'
import type { Player, Pokemon, Item, PlayerPokemon, PokemonEvolution } from '../types'
import { usePensionConfig } from '../hooks/usePensionConfig'
import { usePensionGroups } from '../hooks/usePensionGroups'
import { usePensionXpGroups } from '../hooks/usePensionXpGroups'
import { usePensionDaycare } from '../hooks/usePensionDaycare'
import { useToast } from '../context/ToastContext'
import { GameBanner } from './CasinoGameCard'
import { PensionPlacementList } from './PensionPlacementList'
import { PensionDaycareGrid } from './PensionDaycareGrid'
import { PensionDaycareInfoPopup } from './PensionDaycareInfoPopup'
import { PensionInfoPopup } from './PensionInfoPopup'
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
  onClose: () => void
}

const PLACE_ERROR_MESSAGES: Partial<Record<PensionActionStatus, string>> = {
  daycare_full: 'Pension complète — réessayez plus tard.',
  player_slot_taken: 'Vous avez déjà un pokémon en pension.',
  permanently_capped: 'Ce pokémon a déjà atteint son plafond, il ne peut plus retourner en pension.',
  must_be_in_pc: 'Ce pokémon doit être au PC pour aller en pension.',
  already_placed: 'Ce pokémon est déjà en pension.',
}

export function PensionPopup({
  player, roster, pokemonByName, itemsByName, evolutionsByPokemonNom, onRequestPokemonDetail, onClose,
}: Props) {
  const { config, loading: configLoading } = usePensionConfig()
  const { eggGroupsByPokemonNom, loading: groupsLoading } = usePensionGroups()
  const { xpGroupByPokemonNom, loading: xpGroupsLoading } = usePensionXpGroups()
  const { daycareRoster, pairsByPokemonId, myDaycarePokemon, placeInDaycare, retrieveFromDaycare } = usePensionDaycare(player.id)
  const { showToast } = useToast()
  const [now, setNow] = useState(() => Date.now())
  const [selectedDaycareId, setSelectedDaycareId] = useState<number | null>(null)
  const [showInfo, setShowInfo] = useState(false)

  useEffect(() => {
    const interval = window.setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(interval)
  }, [])

  const pcRoster = roster.filter((r) => !r.in_team && !r.in_daycare && !r.daycare_capped)
  const daycareFull = daycareRoster.length >= config.capacity_total
  const selectedDaycarePokemon = daycareRoster.find((r) => r.id === selectedDaycareId) ?? null

  const handlePlace = async (id: number) => {
    const pp = pcRoster.find((r) => r.id === id)
    const status = await placeInDaycare(id)
    if (status === 'ok') {
      if (pp) {
        void logHistoryEvent('daycare', 'daycare_drop_off', player.id, {
          pokemon_nom: pp.pokemon_nom, player_pokemon_id: pp.id, nickname: pp.nickname,
        })
      }
    } else {
      showToast(PLACE_ERROR_MESSAGES[status] ?? "Impossible de placer ce pokémon en pension pour l'instant.")
    }
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
      // On ne rebascule vers la fiche complète (avec animation d'évolution) que
      // si le séjour en pension a effectivement fait franchir un palier
      // d'évolution — sinon on reste simplement sur ce popup, qui affichera à
      // nouveau la liste de placement (myDaycarePokemon redevient null).
      const species = pokemonByName.get(pp.pokemon_nom)
      const canEvolve =
        getEvolutionOptions(pp, species, evolutionsByPokemonNom, pokemonByName, itemsByName, []).length > 0 ||
        isRandomEvolutionReady(pp, species)
      if (canEvolve) onRequestPokemonDetail(id)
    } else {
      showToast('Impossible de récupérer ce pokémon pour le moment.')
    }
  }

  const loading = configLoading || groupsLoading || xpGroupsLoading

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-0 sm:p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div
        className="relative bg-cream w-full h-full overflow-hidden flex flex-col
          sm:h-auto sm:max-w-2xl sm:max-h-[85vh] sm:rounded-[var(--radius-pixel)] sm:border-[3px] sm:border-ink sm:shadow-[var(--shadow-pixel-lg)]"
      >
        <button
          onClick={onClose}
          className="absolute right-3 top-3 z-10 w-8 h-8 rounded-full flex items-center justify-center text-ink hover:bg-black/10"
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
          ) : myDaycarePokemon ? (
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
            />
          ) : (
            <PensionPlacementList
              pcRoster={pcRoster}
              daycareRoster={daycareRoster}
              pokemonByName={pokemonByName}
              pensionConfig={config}
              xpGroupByPokemonNom={xpGroupByPokemonNom}
              eggGroupsByPokemonNom={eggGroupsByPokemonNom}
              daycareFull={daycareFull}
              onPlace={handlePlace}
            />
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
          now={now}
          onRetrieve={selectedDaycarePokemon.player_id === player.id ? () => handleRetrieve(selectedDaycarePokemon.id) : undefined}
          onClose={() => setSelectedDaycareId(null)}
        />
      )}

      {showInfo && <PensionInfoPopup onClose={() => setShowInfo(false)} />}
    </div>
  )
}
