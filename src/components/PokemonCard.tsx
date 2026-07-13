import { useState, useRef, useEffect } from 'react'
import type { Pokemon, Attack } from '../types'
import { TypeBadge } from './TypeBadge'
import { ImageLightbox } from './ImageLightbox'

interface Props {
  pokemon: Pokemon
  isAdmin: boolean
  isDiscovered: boolean
  attacksByName: Map<string, Attack>
  onBack: () => void
  onUndiscover: () => void
}

const TRANSPORT_ICONS: Record<string, string> = {
  Vol: '🕊️',
  Nage: '🏊',
  Sol: '🐾',
}

function StatRow({ icon, label, value }: { icon: string; label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-start gap-3 py-2 border-b border-gray-700">
      <span className="text-xl w-7 shrink-0 text-center">{icon}</span>
      <span className="text-gray-400 text-sm w-32 shrink-0">{label}</span>
      <span className="text-white text-sm flex-1">{value}</span>
    </div>
  )
}

export function PokemonCard({ pokemon, isAdmin, isDiscovered, attacksByName, onBack, onUndiscover }: Props) {
  const [lightboxOpen, setLightboxOpen] = useState(false)

  // ── Lecteur audio ─────────────────────────────────────────────
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const [audioState, setAudioState] = useState<'idle' | 'playing' | 'paused'>('idle')
  const [progress, setProgress] = useState(0)   // 0–1
  const [duration, setDuration] = useState(0)

  // Pause automatique à la fermeture de la fiche
  useEffect(() => {
    return () => { audioRef.current?.pause() }
  }, [])

  // Réinitialise le player si on change de pokémon
  useEffect(() => {
    audioRef.current?.pause()
    setAudioState('idle')
    setProgress(0)
    setDuration(0)
  }, [pokemon.id])

  function fmt(sec: number) {
    const m = Math.floor(sec / 60)
    const s = Math.floor(sec % 60)
    return `${m}:${s.toString().padStart(2, '0')}`
  }

  function toggleAudio() {
    const a = audioRef.current
    if (!a) return
    if (audioState === 'playing') {
      a.pause()
      setAudioState('paused')
    } else {
      a.play()
      setAudioState('playing')
    }
  }

  const superEfficace = [
    pokemon.super_efficace_1,
    pokemon.super_efficace_2,
    pokemon.super_efficace_3,
    pokemon.super_efficace_4,
  ].filter(Boolean) as string[]

  const localisations = [
    pokemon.localisation_1,
    pokemon.localisation_2,
    pokemon.localisation_3,
  ].filter(Boolean) as string[]

  const attaques = [
    pokemon.attaque_1,
    pokemon.attaque_2,
    pokemon.attaque_3,
    pokemon.attaque_4,
    pokemon.attaque_5,
    pokemon.attaque_6,
    pokemon.attaque_7,
    pokemon.attaque_8,
    pokemon.attaque_9,
    pokemon.attaque_10,
  ].filter(Boolean) as string[]

  const canShowAttaques = isAdmin || isDiscovered

  return (
    <>
      <div className="flex flex-col h-full bg-gray-900 overflow-y-auto">
        {/* Header mobile retour */}
        <button
          onClick={onBack}
          className="md:hidden flex items-center gap-2 px-4 py-3 text-red-400 hover:text-red-300 border-b border-gray-700 shrink-0"
        >
          <span className="text-lg">◀</span>
          <span className="text-sm">Retour</span>
        </button>

        {/* Nom + type */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-700 shrink-0">
          <div>
            <p className="text-gray-400 text-sm">
              #{pokemon.numero}
              {isAdmin && pokemon.cache && (
                <span className="ml-2 text-xs bg-purple-900 text-purple-300 border border-purple-700 rounded px-1.5 py-0.5">CACHÉ</span>
              )}
            </p>
            <h2 className="text-white text-2xl">{pokemon.nom}</h2>
          </div>
          <TypeBadge type={pokemon.type} />
        </div>

        {/* Image illustrée — cliquable pour agrandir */}
        <div className="bg-gray-800 flex items-center justify-center p-4 shrink-0 relative group" style={{ minHeight: '200px' }}>
          {pokemon.image_illustree ? (
            <>
              <img
                src={pokemon.image_illustree}
                alt={pokemon.nom}
                className="max-h-64 w-full object-contain cursor-zoom-in transition-opacity group-hover:opacity-80"
                onClick={() => setLightboxOpen(true)}
              />
              <span className="absolute bottom-2 right-2 text-gray-500 text-xs opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
                🔍 Agrandir
              </span>
            </>
          ) : (
            <div className="text-gray-600 text-center">
              <span className="text-6xl block">?</span>
              <span className="text-sm">Pas d'image</span>
            </div>
          )}
        </div>

        {/* ── Lecteur audio ── */}
        {pokemon.audio_url && (
          <>
            <audio
              ref={audioRef}
              src={pokemon.audio_url}
              onLoadedMetadata={(e) => setDuration(e.currentTarget.duration)}
              onTimeUpdate={(e) => {
                const a = e.currentTarget
                setProgress(a.duration ? a.currentTime / a.duration : 0)
              }}
              onEnded={() => { setAudioState('idle'); setProgress(0) }}
            />
            <div className="mx-4 my-3 px-3 py-2 bg-red-950/60 border border-red-900/50 rounded-lg flex items-center gap-3">
              <span className="text-lg shrink-0">🔊</span>
              <span className="text-gray-300 text-xs shrink-0">Description</span>

              {/* Barre de progression cliquable */}
              <div
                className="flex-1 h-1.5 bg-gray-700 rounded-full overflow-hidden cursor-pointer"
                onClick={(e) => {
                  const a = audioRef.current
                  if (!a || !a.duration) return
                  const rect = e.currentTarget.getBoundingClientRect()
                  a.currentTime = ((e.clientX - rect.left) / rect.width) * a.duration
                }}
              >
                <div
                  className="h-full bg-red-500 rounded-full transition-all duration-100"
                  style={{ width: `${progress * 100}%` }}
                />
              </div>

              {/* Durée */}
              <span className="text-gray-500 text-xs shrink-0 w-8 text-right">
                {audioState === 'idle' ? fmt(duration) : fmt((audioRef.current?.currentTime ?? 0))}
              </span>

              {/* Bouton play/pause */}
              <button
                onClick={toggleAudio}
                className="w-8 h-8 rounded-full bg-red-700 hover:bg-red-600 flex items-center justify-center shrink-0 transition-colors"
              >
                {audioState === 'playing' ? '⏸' : '▶'}
              </button>
            </div>
          </>
        )}

        {/* Stats */}
        <div className="px-4 py-2 flex-1">
          <StatRow icon="❤️" label="PV de base" value={pokemon.pv_base} />
          <StatRow icon="⚔️" label="Dégâts de base" value={pokemon.degats_base} />
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
                <span className="text-gray-500">—</span>
              )
            }
          />

          {canShowAttaques && attaques.length > 0 && (
            <StatRow
              icon="🥊"
              label="Attaques"
              value={
                <div className="flex flex-wrap gap-1">
                  {attaques.map((nom) => {
                    const atk = attacksByName.get(nom)
                    return atk ? (
                      <TypeBadge key={nom} type={atk.type} label={atk.nom} small />
                    ) : (
                      <span
                        key={nom}
                        className="text-xs text-gray-500 border border-gray-700 rounded px-1.5 py-0.5"
                      >
                        {nom}
                      </span>
                    )
                  })}
                </div>
              }
            />
          )}

          {(pokemon.nom_talent || pokemon.description_talent) && (
            <div className="flex items-start gap-3 py-2 border-b border-gray-700">
              <span className="text-xl w-7 shrink-0 text-center">⭐</span>
              <div className="flex-1">
                {pokemon.nom_talent && (
                  <p className="text-yellow-400 text-sm font-bold">{pokemon.nom_talent}</p>
                )}
                {pokemon.description_talent && (
                  <p className="text-gray-300 text-sm mt-0.5">{pokemon.description_talent}</p>
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
                <span className="text-gray-500">—</span>
              )
            }
          />

          {isAdmin && pokemon.chances_capture && (
            <div className="flex items-start gap-3 py-2 border-b border-gray-700 bg-yellow-900/20 -mx-4 px-4 mt-1">
              <span className="text-xl w-7 shrink-0 text-center">🎯</span>
              <span className="text-gray-400 text-sm w-32 shrink-0">Capture</span>
              <span className="text-yellow-300 text-sm">{pokemon.chances_capture}</span>
            </div>
          )}

          {/* Annuler découverte — visible uniquement si découvert (et pas en mode admin) */}
          {isDiscovered && !isAdmin && (
            <div className="mt-6 mb-4 pt-4 border-t border-gray-800">
              <button
                onClick={onUndiscover}
                className="w-full py-2 text-xs text-gray-600 border border-gray-800 rounded hover:text-red-400 hover:border-red-900 transition-colors"
              >
                Marquer comme non découvert
              </button>
            </div>
          )}
        </div>
      </div>

      {lightboxOpen && pokemon.image_illustree && (
        <ImageLightbox
          src={pokemon.image_illustree}
          alt={pokemon.nom}
          onClose={() => setLightboxOpen(false)}
        />
      )}
    </>
  )
}
