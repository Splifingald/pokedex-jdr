interface Props {
  src: string
  size?: number
  alt?: string
  className?: string
  /** Recolore l'icône (blanche/monochrome) avec la couleur de texte courante (currentColor), via un masque CSS. */
  colored?: boolean
}

// Icône pixel-art custom (public/website_icons/) : dimension fixe en px pour
// rester nette (image-rendering: pixelated), indépendante de la taille de police.
export function PixelIcon({ src, size = 20, alt = '', className = '', colored = false }: Props) {
  if (colored) {
    return (
      <span
        role="img"
        aria-label={alt}
        className={`shrink-0 inline-block ${className}`}
        style={{
          width: size,
          height: size,
          backgroundColor: 'currentColor',
          WebkitMaskImage: `url(${src})`,
          maskImage: `url(${src})`,
          WebkitMaskSize: 'contain',
          maskSize: 'contain',
          WebkitMaskRepeat: 'no-repeat',
          maskRepeat: 'no-repeat',
          WebkitMaskPosition: 'center',
          maskPosition: 'center',
        }}
      />
    )
  }
  return (
    <img
      src={src}
      alt={alt}
      style={{ width: size, height: size }}
      className={`pixelated object-contain shrink-0 inline-block ${className}`}
    />
  )
}
