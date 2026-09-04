import { Fragment, useMemo, useState } from 'react'
import type { ResolvedToken } from '../../lib/onlineTokens'
import { turnOrderLabels } from '../../lib/onlineTokens'

interface Props {
  /** Déjà classés — voir resolveTurnOrder. */
  ordered: ResolvedToken[]
  activeTokenId: number | null
  isAdmin: boolean
  /** Variante deux fois plus petite : l'initiale du Pokémon sur un fond à la
   *  couleur de son type, à la place du sprite. */
  compact: boolean
  onReorder: (tokenIds: number[]) => void
  onToggleActive: (tokenId: number) => void
}

// Chevron blanc entre deux Pokémon : indique le sens de lecture de l'ordre.
function Chevron({ compact }: { compact: boolean }) {
  const h = compact ? 11 : 18
  return (
    <svg viewBox="0 0 8 14" width={h * 11 / 18} height={h} className="relative z-10 shrink-0" aria-hidden="true">
      <path d="M1,1 L6,7 L1,13" fill="none" stroke="#fff" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

// Ordre du tour : tous les Pokémon posés, de gauche à droite, enfilés sur une
// ligne noire arrondie. Le MJ réordonne au glissé et met un Pokémon en avant
// d'un clic (« c'est son tour ») ; tout le monde le voit.
//
// La ligne est opaque : le décor du plateau passe dessous quelle que soit
// l'image, sans jamais rendre les pastilles illisibles.
//
// Aucun conteneur à débordement ici : l'étiquette du dresseur sort de la barre
// par le bas, et un `overflow-x` la ferait clipper (en CSS, borner un axe borne
// aussi l'autre) — c'était le symptôme de la barre de défilement parasite.
//
// Glissé-déposé HTML5 plutôt que Pointer Events, contrairement au plateau :
// c'est le patron déjà utilisé ailleurs dans le projet pour réordonner une
// liste (voir campaign/CampagneTab), et seul le MJ s'en sert.
export function TurnOrderBar({ ordered, activeTokenId, isAdmin, compact, onReorder, onToggleActive }: Props) {
  const [dragId, setDragId] = useState<number | null>(null)
  const [hoveredId, setHoveredId] = useState<number | null>(null)
  const labels = useMemo(() => (compact ? turnOrderLabels(ordered) : new Map<number, string>()), [compact, ordered])

  if (ordered.length === 0) return null

  const move = (fromId: number, toId: number) => {
    if (fromId === toId) return
    const ids = ordered.map((t) => t.token.id)
    const from = ids.indexOf(fromId)
    const to = ids.indexOf(toId)
    if (from < 0 || to < 0) return
    ids.splice(to, 0, ids.splice(from, 1)[0])
    onReorder(ids)
  }

  const tile = compact ? 'w-8 h-8' : 'w-16 h-16'
  const line = compact ? 'h-[18px]' : 'h-[30px]'
  const ring = compact ? 'shadow-[0_0_0_2px_var(--color-select)]' : 'shadow-[0_0_0_4px_var(--color-select)]'

  return (
    <div className={`relative flex items-center ${compact ? 'gap-1 px-2' : 'gap-2 px-3'}`}>
      {/* La ligne, derrière les pastilles */}
      <div className={`absolute inset-x-0 top-1/2 -translate-y-1/2 ${line} rounded-full bg-black`} />

      {ordered.map((t, i) => {
        const id = t.token.id
        const active = activeTokenId === id
        const label = labels.get(id) ?? ''
        return (
          <Fragment key={id}>
            {i > 0 && <Chevron compact={compact} />}
            <div className="relative z-10 flex flex-col items-center">
              <button
                draggable={isAdmin}
                onDragStart={() => setDragId(id)}
                onDragOver={(e) => { if (dragId !== null) e.preventDefault() }}
                onDrop={() => { if (dragId !== null) move(dragId, id); setDragId(null) }}
                onDragEnd={() => setDragId(null)}
                onClick={() => { if (isAdmin) onToggleActive(id) }}
                onMouseEnter={() => setHoveredId(id)}
                onMouseLeave={() => setHoveredId((prev) => (prev === id ? null : prev))}
                title={t.displayName}
                className={`${tile} rounded-full border-2 border-ink flex items-center justify-center shrink-0 transition-all
                  ${compact ? '' : 'bg-white'}
                  ${active ? ring : ''}
                  ${isAdmin ? 'cursor-grab active:cursor-grabbing' : 'cursor-default'}
                  ${dragId === id ? 'opacity-50' : ''}`}
                style={compact ? { backgroundColor: t.typeColor } : undefined}
              >
                {compact ? (
                  <span
                    className={`text-white font-bold leading-none drop-shadow-[1px_1px_0_rgba(0,0,0,0.6)] ${label.length > 1 ? 'text-[0.6rem]' : 'text-sm'} ${t.isKo ? 'opacity-50' : ''}`}
                  >
                    {label}
                  </span>
                ) : t.species?.image_miniature ? (
                  <img
                    src={t.species.image_miniature}
                    alt=""
                    draggable={false}
                    className={`pixelated w-[112%] h-[112%] object-contain ${t.isKo ? 'grayscale opacity-60' : ''}`}
                  />
                ) : (
                  <span className="text-ink text-base font-bold">?</span>
                )}
              </button>

              {/* Flèche pointant vers le haut, sous le Pokémon dont c'est le tour */}
              {active && (
                <span
                  className={`absolute left-1/2 -translate-x-1/2 w-0 h-0 border-l-transparent border-r-transparent border-b-select
                    ${compact
                      ? '-bottom-1.5 border-l-[5px] border-r-[5px] border-b-[6px]'
                      : '-bottom-3 border-l-[8px] border-r-[8px] border-b-[10px]'}`}
                />
              )}

              {hoveredId === id && t.owner && (
                <div className={`absolute top-full left-1/2 -translate-x-1/2 z-10 pointer-events-none ${compact ? 'mt-2' : 'mt-4'}`}>
                  <div className="flex items-center gap-1 bg-cream/90 border-2 border-ink rounded-[var(--radius-pixel-sm)] pl-0.5 pr-1.5 py-0.5">
                    <span
                      className="w-4 h-4 shrink-0 rounded-full overflow-hidden border border-ink"
                      style={{ backgroundColor: t.owner.color }}
                    >
                      {t.owner.image_url && (
                        <img src={t.owner.image_url} alt="" draggable={false} className="w-full h-full object-cover" />
                      )}
                    </span>
                    <span className="text-ink text-[0.6rem] leading-none font-bold whitespace-nowrap">{t.ownerName}</span>
                  </div>
                </div>
              )}
            </div>
          </Fragment>
        )
      })}
    </div>
  )
}
