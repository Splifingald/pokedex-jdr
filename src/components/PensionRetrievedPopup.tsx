import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  pokemonName: string
  // null = pas d'instantané de départ connu (pokémon placé avant l'ajout de ce
  // suivi) — on ne peut pas honnêtement annoncer un delta, plutôt que d'afficher
  // à tort "0 xp".
  xpGained: number | null
  canEvolve: boolean
  onContinue: () => void
}

// Affiché juste après une récupération réussie — avant de rebasculer vers la
// fiche complète (si évolution possible) ou de revenir simplement au popup
// Pension (sinon), voir PensionPopup::handleContinueAfterRetrieve.
export function PensionRetrievedPopup({ pokemonName, xpGained, canEvolve, onContinue }: Props) {
  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4">
      <div className="relative bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-xs w-full p-6 text-center">
        <p className="text-ink text-base font-bold">
          {xpGained != null ? `${pokemonName} a gagné ${xpGained} xp` : `Tu as récupéré ${pokemonName} !`}
        </p>
        {canEvolve && (
          <p className="text-[#a3841a] text-sm font-bold mt-2">✨ Il peut désormais évoluer !</p>
        )}
        <button onClick={onContinue} className={`w-full py-2.5 rounded-lg text-base font-bold mt-4 ${BUTTON_STYLE.yellow}`}>
          Continuer
        </button>
      </div>
    </div>
  )
}
