import { parseIcon } from '../../lib/campaignIcon'

interface Props {
  icon: string
  /** Taille en px de l'image (item/pokémon/joueur) */
  size?: number
  /** Classe de taille de police pour le repli emoji, ex: 'text-2xl' */
  emojiClassName?: string
  className?: string
}

// Icône de chapitre/session : emoji brut, ou image d'objet/Pokémon/joueur choisie via
// l'EmojiPickerButton étendu (voir lib/campaignIcon.ts pour l'encodage).
export function CampaignIcon({ icon, size = 24, emojiClassName = 'text-2xl', className = '' }: Props) {
  const parsed = parseIcon(icon)
  if (parsed) {
    return (
      <img
        src={parsed.url}
        alt=""
        style={{ width: size, height: size }}
        className={`shrink-0 inline-block ${
          parsed.type === 'player' ? 'rounded-full object-cover' : 'object-contain'
        } ${className}`}
      />
    )
  }
  return <span className={`shrink-0 ${emojiClassName} ${className}`}>{icon}</span>
}
