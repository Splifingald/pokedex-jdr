import { AUTOBATTLE_TICKET_ICON } from '../../lib/icons'
import { BUTTON_STYLE } from '../../lib/buttonStyles'

interface Props {
  /** Résumé de ce qui vient d'être choisi, affiché au-dessus du bouton (nom du pokémon ou de la capacité). */
  label: string
  /** Plus aucun ticket en stock : le bouton reste visible mais désactivé. */
  disabled?: boolean
  onLaunch: () => void
}

// Barre de confirmation collée en bas de la zone défilante des popups Combat
// Auto : c'est LE point où le ticket est débité (le clic sur un parcours puis
// sur un pokémon/une capacité ne coûte rien). Les marges négatives annulent le
// padding du conteneur défilant d'AutoBattlePopup (p-4 sm:p-5) pour que la
// barre aille d'un bord à l'autre.
export function AutoBattleLaunchBar({ label, disabled, onLaunch }: Props) {
  return (
    <div className="sticky bottom-0 z-20 -mx-4 sm:-mx-5 -mb-4 sm:-mb-5 mt-1 px-4 sm:px-5 py-3 bg-cream border-t-2 border-ink flex items-center gap-3">
      <span className="flex-1 min-w-0 text-ink text-sm font-bold truncate">{label}</span>
      <button
        onClick={onLaunch}
        disabled={disabled}
        title={disabled ? 'Aucun ticket disponible.' : undefined}
        className={`flex items-center gap-2 px-5 py-2.5 rounded text-sm font-bold shrink-0 disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.yellow}`}
      >
        <img src={AUTOBATTLE_TICKET_ICON} alt="" className="w-5 h-5 object-contain pixelated" />
        Lancer
      </button>
    </div>
  )
}
