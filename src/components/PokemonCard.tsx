import { useState } from 'react'
import type { Pokemon, Attack } from '../types'
import { TypeBadge } from './TypeBadge'
import { ImageLightbox } from './ImageLightbox'
import { StatRow } from './StatRow'
import { AudioDescriptionPlayer } from './AudioDescriptionPlayer'
import { EyeOffIcon } from './icons/EyeOffIcon'
import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  pokemon: Pokemon
  isAdmin: boolean
  isDiscovered: boolean
  attacksByName: Map<string, Attack>
  onBack: () => void
  onUndiscover: () => void
  onAddToRoster?: () => void
  teamFull?: boolean
  ownedCount?: number
}

const TRANSPORT_ICONS: Record<string, string> = {
  Vol: '🕊️',
  Nage: '🏊',
  Sol: '🐾',
}

export function PokemonCard({ pokemon, isAdmin, isDiscovered, attacksByName, onBack, onUndiscover, onAddToRoster, teamFull = false, ownedCount = 0 }: Props) {
  const [lightboxOpen, setLightboxOpen] = useState(false)

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

        {/* Image miniature — cliquable pour agrandir */}
        <div className="bg-gray-800 flex items-center justify-center p-4 shrink-0 relative group" style={{ minHeight: '200px' }}>
          {pokemon.image_miniature ? (
            <>
              <img
                src={pokemon.image_miniature}
                alt={pokemon.nom}
                className="pixelated max-h-64 w-full object-contain cursor-zoom-in transition-opacity group-hover:opacity-80"
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
        {pokemon.audio_url && <AudioDescriptionPlayer key={pokemon.id} audioUrl={pokemon.audio_url} />}

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
              label="Capacités"
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

          {/* Actions */}
          {isDiscovered && (onAddToRoster || !isAdmin) && (
            <div className="mt-6 mb-4 pt-4 border-t border-gray-800 grid grid-cols-1 sm:grid-cols-2 gap-3">
              {onAddToRoster && (
                <button
                  onClick={onAddToRoster}
                  className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.blue}`}
                >
                  + {teamFull ? 'Ajouter à mon PC' : 'Ajouter à mon équipe'}{ownedCount > 0 ? ` (${ownedCount})` : ''}
                </button>
              )}
              {!isAdmin && (
                <button
                  onClick={onUndiscover}
                  className={`flex items-center justify-center gap-1.5 py-2 rounded text-xs ${BUTTON_STYLE.gray}`}
                >
                  <EyeOffIcon className="w-3.5 h-3.5" />
                  Marquer comme non découvert
                </button>
              )}
            </div>
          )}
        </div>
      </div>

      {lightboxOpen && pokemon.image_miniature && (
        <ImageLightbox
          src={pokemon.image_miniature}
          alt={pokemon.nom}
          onClose={() => setLightboxOpen(false)}
        />
      )}
    </>
  )
}
