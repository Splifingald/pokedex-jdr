import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  pokemonName: string
  imageUrl: string | undefined
  onContinue: () => void
}

// Affiché uniquement au joueur qui vient de réussir sa capture — le résultat
// est déjà connu de façon synchrone via la réponse de safari_throw_ball, pas
// besoin d'un flag "non vu" en base (contrairement à PensionEggRevealPopup).
export function SafariCaughtPopup({ pokemonName, imageUrl, onContinue }: Props) {
  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4">
      <div className="relative bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-xs w-full p-6 text-center">
        <p className="text-ink text-base font-bold mb-2">🎉 Capturé !</p>
        <div className="w-20 h-20 mx-auto flex items-center justify-center mb-2 animate-[celebrate-pop_0.4s_ease-out]">
          {imageUrl ? (
            <img src={imageUrl} alt="" className="pixelated w-full h-full object-contain" />
          ) : (
            <span className="text-5xl">🦁</span>
          )}
        </div>
        <p className="text-ink text-lg font-bold mb-4">{pokemonName}</p>
        <button onClick={onContinue} className={`w-full py-2.5 rounded-lg text-base font-bold ${BUTTON_STYLE.yellow}`}>
          Continuer
        </button>
      </div>
    </div>
  )
}
