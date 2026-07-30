interface DisplayFigure {
  id: number
  nom: string
  image_url: string
}

interface Props {
  backgroundUrl?: string | null
  npcs: DisplayFigure[]
  pokemons: DisplayFigure[]
  items: DisplayFigure[]
  className?: string
}

// Rendu en couches du mode Affichage : fond → PNJ → Pokémon → objet.
// L'ordre gauche→droite des tableaux npcs/pokemons est aussi l'ordre du DOM,
// donc l'élément le plus à droite se dessine naturellement au-dessus des autres.
// container-type:size rend les unités cq*() relatives à CE conteneur plutôt
// qu'à la fenêtre du navigateur — indispensable pour que la taille des
// PNJ/Pokémon/objet soit identique dans l'aperçu admin (petite boîte) et sur
// l'écran d'affichage réel (plein écran) : des unités vw/vh se seraient
// calculées sur la fenêtre entière, donnant un rendu bien plus petit en
// aperçu qu'en plein écran pour la même classe CSS.
export function DisplayCanvas({ backgroundUrl, npcs, pokemons, items, className = '' }: Props) {
  return (
    <div className={`relative overflow-hidden bg-black [container-type:size] ${className}`}>
      {backgroundUrl && (
        <img
          src={backgroundUrl}
          alt=""
          className="absolute inset-0 w-full h-full object-cover"
        />
      )}

      {npcs.length > 0 && (
        <div className="absolute inset-0 flex items-end justify-center gap-2 px-4 pb-0">
          {npcs.map((npc) => (
            <img
              key={npc.id}
              src={npc.image_url}
              alt={npc.nom}
              className="h-1/2 w-auto object-contain [filter:drop-shadow(2px_4px_2px_rgba(0,0,0,0.4))]"
            />
          ))}
        </div>
      )}

      {pokemons.length > 0 && (
        <div className="absolute inset-0 flex items-center justify-center gap-2 px-4">
          {pokemons.map((p) => (
            <div
              key={p.id}
              className="relative min-w-0 shrink h-[60cqh] w-[60cqh] max-w-[38cqw] flex items-center justify-center"
            >
              <img
                src={p.image_url}
                alt={p.nom}
                className="pixelated w-full h-full object-contain [filter:drop-shadow(2px_4px_2px_rgba(0,0,0,0.3))]"
              />
            </div>
          ))}
        </div>
      )}

      {items.length > 0 && (
        <div className="absolute inset-0 flex items-center justify-center gap-2 px-4">
          {items.map((item) => (
            <img
              key={item.id}
              src={item.image_url}
              alt={item.nom}
              className="max-w-[25cqw] max-h-[25cqh] object-contain [filter:drop-shadow(2px_4px_2px_rgba(0,0,0,0.4))]"
            />
          ))}
        </div>
      )}
    </div>
  )
}
