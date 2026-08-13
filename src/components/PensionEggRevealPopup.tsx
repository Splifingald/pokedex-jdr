import { BUTTON_STYLE } from '../lib/buttonStyles'

interface Props {
  pokemonName: string
  imageUrl: string | undefined
  onContinue: () => void
}

// Affiché à l'ouverture de la pension s'il existe un œuf pas encore
// "révélé" au joueur (egg_reveal_seen=false) — l'œuf a déjà atterri dans le
// PC dès sa production côté serveur, ce popup ne fait qu'annoncer sa
// réception ; voir PensionPopup::unseenEgg.
export function PensionEggRevealPopup({ pokemonName, imageUrl, onContinue }: Props) {
  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4">
      <div className="relative bg-cream border-[3px] border-ink rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel-lg)] max-w-xs w-full p-6 text-center">
        <p className="text-ink text-base font-bold mb-2">🥚 Tu as reçu un œuf de la Pension Pokémon !</p>
        <div className="w-20 h-20 mx-auto flex items-center justify-center mb-2">
          {imageUrl ? (
            <img src={imageUrl} alt="" className="pixelated w-full h-full object-contain" />
          ) : (
            <span className="text-5xl">🥚</span>
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
