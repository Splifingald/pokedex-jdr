import { useState, useEffect, useRef } from 'react'
import type { Player, Pokemon, Attack, Item, PlayerPokemon } from '../types'
import { DEFAULT_ACCUEIL_IMAGE_URL, ownedPokemonName, POKEDOLLAR_ITEM_NAME } from '../types'
import { usePlayerPokemon } from '../hooks/usePlayerPokemon'
import { usePlayerItems } from '../hooks/usePlayerItems'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { useBackgrounds } from '../hooks/useBackgrounds'
import { useGiftLootboxes } from '../hooks/useGiftLootboxes'
import { useToast } from '../context/ToastContext'
import { RoamingPokemonSprite } from './RoamingPokemonSprite'
import { PokemonDetailSheet } from './PokemonDetailSheet'
import { GiftPopup, type GiftReward } from './GiftPopup'
import { CasinoPopup } from './CasinoPopup'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { PixelIcon } from './icons/PixelIcon'
import { PHOTO_ICON, CASINO_MASCOT_ICON } from '../lib/icons'
import { isGiftReady, resolveLootboxForSpecies, drawLootboxReward, randomNextGiftAt, maybeResetGiftTimerOnEntry } from '../lib/gifting'

interface Props {
  player: Player | null
  isAdmin: boolean
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
  itemsByName: Map<string, Item>
  playerItems: ReturnType<typeof usePlayerItems>
  canScan: boolean
  onScan: () => void
  onRequestLogin: () => void
}

// Fond d'accueil : image configurable dans Admin → Paramètres.
// L'image occupe toujours toute la hauteur (auto 100%) et reste centrée
// quand l'écran est plus étroit qu'elle.
const homeBgStyle = (url: string): React.CSSProperties => ({
  backgroundColor: '#4f9a41',
  backgroundImage: `url(${url})`,
  backgroundSize: 'auto 100%',
  backgroundPosition: 'center',
  backgroundRepeat: 'no-repeat',
})

export function HomeTab({ player, isAdmin, pokemonByName, attacksByName, itemsByName, playerItems, canScan, onScan, onRequestLogin }: Props) {
  const { roster, updateXp, updateNickname, toggleInTeam, setNextGiftAt, addMove, removeMove, deleteOwnedPokemon } = usePlayerPokemon(player?.id ?? null)
  const { pokedollars, addItems, setPokedollars } = playerItems
  const { parameters } = useAdminParameters()
  const { backgrounds } = useBackgrounds()
  const { lootboxes, lootboxItems, speciesAssignments } = useGiftLootboxes()
  const { showToast } = useToast()

  const sceneRef = useRef<HTMLDivElement>(null)
  const [selectedId, setSelectedId] = useState<number | null>(null)
  const [jumpingId, setJumpingId] = useState<number | null>(null)
  const [giftPokemonId, setGiftPokemonId] = useState<number | null>(null)
  const [giftReward, setGiftReward] = useState<GiftReward | null>(null)
  const [showCasino, setShowCasino] = useState(false)

  // Recalcul périodique de "maintenant" pour détecter les cadeaux devenus prêts
  // pendant que l'app reste ouverte — pas de compte à rebours affiché, juste
  // une réévaluation silencieuse toutes les 30s.
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const interval = window.setInterval(() => setNow(Date.now()), 30_000)
    return () => clearInterval(interval)
  }, [])

  const team = roster.filter((r) => r.in_team)
  const teamFull = player?.is_npc ? false : team.length >= parameters.max_team_size
  const selected = roster.find((r) => r.id === selectedId) ?? null
  const giftPokemon = roster.find((r) => r.id === giftPokemonId) ?? null

  const hasGift = (pp: PlayerPokemon) =>
    parameters.feature_gifting_enabled && isGiftReady(pp, player?.is_npc ?? false, new Date(now))

  // Saut aléatoire : un seul membre de l'équipe à la fois, toutes les 5–10 s
  const teamRef = useRef(team)
  useEffect(() => { teamRef.current = team }, [team])

  useEffect(() => {
    let cancelled = false
    let loopTimer: number
    let endTimer: number

    const loop = () => {
      loopTimer = window.setTimeout(() => {
        if (cancelled) return
        const current = teamRef.current
        if (current.length > 0) {
          const pick = current[Math.floor(Math.random() * current.length)]
          setJumpingId(pick.id)
          endTimer = window.setTimeout(() => { if (!cancelled) setJumpingId(null) }, 600)
        }
        loop()
      }, 5000 + Math.random() * 5000)
    }
    loop()

    return () => {
      cancelled = true
      clearTimeout(loopTimer)
      clearTimeout(endTimer)
    }
  }, [])

  const handleToggleInTeam = async (id: number, inTeam: boolean) => {
    const pp = roster.find((r) => r.id === id)
    await toggleInTeam(id, inTeam)
    if (pp) {
      await maybeResetGiftTimerOnEntry({
        giftingEnabled: parameters.feature_gifting_enabled,
        isNpc: player?.is_npc ?? false,
        wasInTeam: pp.in_team,
        willBeInTeam: inTeam,
        pokemonNom: pp.pokemon_nom,
        playerPokemonId: id,
        lootboxes,
        speciesAssignments,
        setNextGiftAt,
      })
    }
    showToast(`${pp ? ownedPokemonName(pp) : 'Pokémon'} ${inTeam ? "ajouté à l'équipe" : 'mis au PC'} !`)
  }

  const openGift = (pp: PlayerPokemon) => {
    const lootbox = resolveLootboxForSpecies(pp.pokemon_nom, lootboxes, speciesAssignments)
    const drawn = lootbox ? drawLootboxReward(lootbox.id, lootboxItems) : null
    setGiftReward(drawn ? { itemNom: drawn.item_nom, quantity: drawn.quantity } : null)
    setGiftPokemonId(pp.id)
  }

  const handleClaimGift = async () => {
    if (giftPokemon && giftReward) {
      if (giftReward.itemNom === POKEDOLLAR_ITEM_NAME) {
        await setPokedollars(pokedollars + giftReward.quantity)
      } else {
        await addItems(giftReward.itemNom, giftReward.quantity)
      }
      const lootbox = resolveLootboxForSpecies(giftPokemon.pokemon_nom, lootboxes, speciesAssignments)
      if (lootbox) await setNextGiftAt(giftPokemon.id, randomNextGiftAt(lootbox))
    }
    setGiftPokemonId(null)
    setGiftReward(null)
  }

  const handleDelete = async (id: number) => {
    const pp = roster.find((r) => r.id === id)
    await deleteOwnedPokemon(id)
    setSelectedId(null)
    showToast(`${pp ? ownedPokemonName(pp) : 'Pokémon'} supprimé.`)
  }

  return (
    <div
      ref={sceneRef}
      className="flex-1 relative overflow-hidden"
      style={homeBgStyle(parameters.accueil_image_url?.trim() || backgrounds[0]?.image_url || DEFAULT_ACCUEIL_IMAGE_URL)}
    >
      {/* Équipe en déambulation */}
      {team.map((pp, idx) => (
        <RoamingPokemonSprite
          key={pp.id}
          playerPokemon={pp}
          pokemon={pokemonByName.get(pp.pokemon_nom)}
          index={idx}
          isJumping={jumpingId === pp.id}
          hasGift={hasGift(pp)}
          containerRef={sceneRef}
          onClick={() => (hasGift(pp) ? openGift(pp) : setSelectedId(pp.id))}
        />
      ))}

      {/* États vides */}
      {!player ? (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-3">
          <p className={`text-[#14320f] text-sm bg-cream/90 px-4 py-2.5 rounded-lg ${PIXEL_BORDER_SM}`}>
            Connectez-vous pour voir votre équipe.
          </p>
          <button
            onClick={onRequestLogin}
            className={`px-4 py-2 rounded-lg text-sm font-bold ${BUTTON_STYLE.green}`}
          >
            👤 Se connecter
          </button>
        </div>
      ) : team.length === 0 ? (
        <div className="absolute inset-0 flex items-center justify-center">
          <p className={`text-[#14320f] text-sm bg-cream/90 px-4 py-2.5 rounded-lg ${PIXEL_BORDER_SM}`}>
            Aucun Pokémon dans l'équipe.
          </p>
        </div>
      ) : null}

      {/* Bouton casino épinglé à droite, au-dessus du scanner */}
      {player && parameters.feature_casino_enabled && (
        <button
          onClick={() => setShowCasino(true)}
          title="Casino"
          className="absolute right-3 top-1/2 -translate-y-[calc(50%+96px)] w-14 h-14 rounded-full border-[3px] border-ink bg-gradient-to-br from-[#e0293f] to-[#7a0f1f] flex items-center justify-center shadow-[var(--shadow-pixel)] z-[35] active:shadow-none active:translate-x-[2px] active:translate-y-[calc(-50%-94px)] transition-all"
        >
          <img src={CASINO_MASCOT_ICON} alt="Casino" className="pixelated w-9 h-9 object-contain" />
        </button>
      )}

      {/* Bouton scanner épinglé à droite */}
      {canScan && (
        <button
          onClick={onScan}
          title="Scanner un Pokémon"
          className="absolute right-3 top-1/2 -translate-y-1/2 w-14 h-14 rounded-full border-[3px] border-ink bg-gradient-to-br from-hp-orange to-hp-red text-white flex items-center justify-center shadow-[var(--shadow-pixel)] z-[35] active:shadow-none active:translate-x-[2px] active:translate-y-[calc(-50%+2px)] transition-all"
        >
          <PixelIcon src={PHOTO_ICON} size={34} alt="Scanner un Pokémon" colored />
        </button>
      )}

      {selected && (
        <PokemonDetailSheet
          context="home"
          pokemon={pokemonByName.get(selected.pokemon_nom)}
          playerPokemon={selected}
          attacksByName={attacksByName}
          isAdmin={isAdmin}
          teamFull={teamFull}
          isNpc={player?.is_npc ?? false}
          maxMoves={parameters.max_moves}
          onUpdateXp={updateXp}
          onRename={updateNickname}
          onToggleInTeam={handleToggleInTeam}
          onAddMove={addMove}
          onRemoveMove={removeMove}
          onDelete={handleDelete}
          onClose={() => setSelectedId(null)}
        />
      )}

      {giftPokemon && (
        <GiftPopup
          pokemonDisplayName={ownedPokemonName(giftPokemon)}
          reward={giftReward}
          itemsByName={itemsByName}
          pokedollarImageUrl={itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url}
          onConfirm={handleClaimGift}
        />
      )}

      {showCasino && player && (
        <CasinoPopup
          player={player}
          playerItems={playerItems}
          pokedollarImageUrl={itemsByName.get(POKEDOLLAR_ITEM_NAME)?.image_url}
          onClose={() => setShowCasino(false)}
        />
      )}
    </div>
  )
}
