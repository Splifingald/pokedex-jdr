const TYPE_COLORS: Record<string, string> = {
  Normal:    '#A8A878',
  Feu:       '#F08030',
  Eau:       '#6890F0',
  Plante:    '#78C850',
  Électrik:  '#F8D030',
  Glace:     '#98D8D8',
  Combat:    '#C03028',
  Poison:    '#A040A0',
  Sol:       '#E0C068',
  Vol:       '#A890F0',
  Psy:       '#F85888',
  Insecte:   '#A8B820',
  Roche:     '#B8A038',
  Fantôme:   '#705898',
  Dragon:    '#7038F8',
  Ténèbres:  '#705848',
  Acier:     '#B8B8D0',
  Fée:       '#EE99AC',
}

interface TypeBadgeProps {
  type: string
  small?: boolean
}

export function TypeBadge({ type, small = false }: TypeBadgeProps) {
  const bg = TYPE_COLORS[type] ?? '#888888'
  return (
    <span
      className={`inline-block rounded font-bold uppercase tracking-wide text-white ${small ? 'px-1.5 py-0.5 text-xs' : 'px-3 py-1 text-sm'}`}
      style={{ backgroundColor: bg, textShadow: '0 1px 2px rgba(0,0,0,0.4)' }}
    >
      {type}
    </span>
  )
}
