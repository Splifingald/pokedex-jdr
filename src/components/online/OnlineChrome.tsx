import type { Player } from '../../types'
import { PixelIcon } from '../icons/PixelIcon'
import { SETTINGS_ICON } from '../../lib/icons'
import { DiceRoller } from './DiceRoller'

interface Props {
  player: Player | null
  isAdmin: boolean
  onOpenSettings: () => void
  onToggleFullscreen: () => void
  /** En mode bataille, la pastille de profil vit en tête de la barre latérale :
   *  on ne la répète pas ici. */
  showProfileButton: boolean
  onOpenProfile: () => void
  onRoll: (sides: number, value: number) => void
}

// Habillage commun aux deux modes de l'écran partagé : profil, dés, réglages
// du MJ et plein écran. Dés et profil restent accessibles en mode affichage —
// on lance des jets et on consulte ses stats aussi pendant une scène de rôle.
export function OnlineChrome({ player, isAdmin, onOpenSettings, onToggleFullscreen, showProfileButton, onOpenProfile, onRoll }: Props) {

  return (
    <>
      {showProfileButton && player && (
        <button
          onClick={onOpenProfile}
          title={player.name}
          aria-label={`Profil de ${player.name}`}
          className="absolute left-2 top-2 z-40 w-11 h-11 rounded-full overflow-hidden border-[3px] border-ink shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
          style={{ backgroundColor: player.color }}
        >
          {player.image_url && (
            <img src={player.image_url} alt="" className="w-full h-full object-cover" />
          )}
        </button>
      )}

      <div className="absolute right-2 top-2 z-40 flex items-center gap-2">
        {isAdmin && (
          <button
            onClick={onOpenSettings}
            aria-label="Réglages"
            title="Réglages"
            className="w-9 h-9 rounded-full border-2 border-ink bg-cream shadow-[var(--shadow-pixel)] flex items-center justify-center active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
          >
            <PixelIcon src={SETTINGS_ICON} size={18} />
          </button>
        )}
        <button
          onClick={onToggleFullscreen}
          aria-label="Basculer le plein écran"
          title="Plein écran"
          className="w-9 h-9 rounded-full border-2 border-ink bg-cream text-ink text-sm shadow-[var(--shadow-pixel)] flex items-center justify-center active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
        >
          ⤢
        </button>
      </div>

      <DiceRoller onRoll={onRoll} />
    </>
  )
}
