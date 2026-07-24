import { useState, useEffect, useRef } from 'react'
import type { Player, Pokemon, Attack } from '../types'
import { DEFAULT_ACCUEIL_IMAGE_URL } from '../types'
import { usePlayerPokemon } from '../hooks/usePlayerPokemon'
import { useAdminParameters } from '../hooks/useAdminParameters'
import { useToast } from '../context/ToastContext'
import { RoamingPokemonSprite } from './RoamingPokemonSprite'
import { PokemonDetailSheet } from './PokemonDetailSheet'
import { MovesTab } from './MovesTab'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'

interface Props {
  player: Player | null
  isAdmin: boolean
  pokemonByName: Map<string, Pokemon>
  attacksByName: Map<string, Attack>
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

export function HomeTab({ player, isAdmin, pokemonByName, attacksByName, onScan, onRequestLogin }: Props) {
  const { roster, updateXp, toggleInTeam, addMove, removeMove, deleteOwnedPokemon } = usePlayerPokemon(player?.id ?? null)
  const { parameters } = useAdminParameters()
  const { showToast } = useToast()

  const [selectedId, setSelectedId] = useState<number | null>(null)
  const [managingMoves, setManagingMoves] = useState(false)
  const [jumpingId, setJumpingId] = useState<number | null>(null)

  const team = roster.filter((r) => r.in_team)
  const teamFull = player?.is_npc ? false : team.length >= parameters.max_team_size
  const selected = roster.find((r) => r.id === selectedId) ?? null

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
    await toggleInTeam(id, inTeam)
    const pp = roster.find((r) => r.id === id)
    showToast(`${pp?.pokemon_nom ?? 'Pokémon'} ${inTeam ? "ajouté à l'équipe" : 'mis au PC'} !`)
  }

  const handleDelete = async (id: number) => {
    const pp = roster.find((r) => r.id === id)
    await deleteOwnedPokemon(id)
    setSelectedId(null)
    showToast(`${pp?.pokemon_nom ?? 'Pokémon'} supprimé.`)
  }

  // Gestion des capacités plein écran (comme depuis l'onglet Pokémon)
  if (selected && managingMoves) {
    return (
      <MovesTab
        playerPokemon={selected}
        pokemon={pokemonByName.get(selected.pokemon_nom)}
        maxMoves={parameters.max_moves}
        attacksByName={attacksByName}
        onUpdateXp={updateXp}
        onAddMove={addMove}
        onRemoveMove={removeMove}
        onGoToInfo={() => setManagingMoves(false)}
        onBack={() => { setManagingMoves(false); setSelectedId(null) }}
      />
    )
  }

  return (
    <div
      className="flex-1 relative overflow-hidden"
      style={homeBgStyle(parameters.accueil_image_url?.trim() || DEFAULT_ACCUEIL_IMAGE_URL)}
    >
      {/* Équipe en déambulation */}
      {team.map((pp, idx) => (
        <RoamingPokemonSprite
          key={pp.id}
          playerPokemon={pp}
          pokemon={pokemonByName.get(pp.pokemon_nom)}
          index={idx}
          isJumping={jumpingId === pp.id}
          onClick={() => setSelectedId(pp.id)}
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

      {/* Bouton scanner épinglé à droite */}
      <button
        onClick={onScan}
        title="Scanner un Pokémon"
        className="absolute right-3 top-1/2 -translate-y-1/2 w-14 h-14 rounded-full border-[3px] border-ink bg-cream text-2xl flex items-center justify-center shadow-[var(--shadow-pixel)] z-[6] active:shadow-none active:translate-x-[2px] active:translate-y-[calc(-50%+2px)] transition-all"
      >
        📷
      </button>

      {selected && !managingMoves && (
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
          onToggleInTeam={handleToggleInTeam}
          onManageMoves={() => setManagingMoves(true)}
          onDelete={handleDelete}
          onClose={() => setSelectedId(null)}
        />
      )}
    </div>
  )
}
