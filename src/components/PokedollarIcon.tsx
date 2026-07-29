interface Props {
  imageUrl?: string | null
  /** Taille en px de l'image ; omis pour laisser className contrôler entièrement la taille (ex: w-full h-full) */
  size?: number
  className?: string
  fallbackClassName?: string
}

// Icône Pokédollar unique, réutilisée partout où le montant est affiché : image configurée
// sur l'objet 'Pokédollar' (CSV objets), avec repli sur l'emoji 💰 si jamais non configurée.
export function PokedollarIcon({ imageUrl, size, className = '', fallbackClassName = 'text-lg' }: Props) {
  if (imageUrl) {
    return (
      <img
        src={imageUrl}
        alt=""
        style={size ? { width: size, height: size } : undefined}
        className={`object-contain inline-block shrink-0 ${className}`}
      />
    )
  }
  return <span className={fallbackClassName}>💰</span>
}
