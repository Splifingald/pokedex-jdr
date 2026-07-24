export type ButtonColor = 'blue' | 'orange' | 'yellow' | 'gray' | 'green' | 'red'

// Look pixel-art : bordure noire épaisse, ombre dure, fond pastel + texte encre.
// Même clé de couleur qu'avant pour ne pas casser les appels existants.
export const BUTTON_STYLE: Record<ButtonColor, string> = {
  blue: 'bg-[#8fc5f0] border-2 border-ink text-ink shadow-[var(--shadow-pixel-sm)] hover:bg-[#a6d2f4] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all',
  orange: 'bg-[#f0c48f] border-2 border-ink text-ink shadow-[var(--shadow-pixel-sm)] hover:bg-[#f4d3a6] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all',
  yellow: 'bg-[#f0e08f] border-2 border-ink text-ink shadow-[var(--shadow-pixel-sm)] hover:bg-[#f4e8a6] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all',
  gray: 'bg-cream-button border-2 border-ink text-ink shadow-[var(--shadow-pixel-sm)] hover:brightness-105 active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all',
  green: 'bg-[#bfe8cc] border-2 border-ink text-ink shadow-[var(--shadow-pixel-sm)] hover:bg-[#cdeed8] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all',
  red: 'bg-[#e8b8b8] border-2 border-ink text-ink shadow-[var(--shadow-pixel-sm)] hover:bg-[#eec7c7] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all',
}
