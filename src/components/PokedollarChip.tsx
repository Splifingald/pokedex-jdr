import { PokedollarIcon } from './PokedollarIcon'

interface Props {
  amount: number
  imageUrl?: string | null
}

// id ciblé par l'animation flyCoin lors d'une vente dans le Sac
export function PokedollarChip({ amount, imageUrl }: Props) {
  return (
    <div
      id="pokedollar-chip"
      className="flex items-center gap-1 bg-black/25 border-2 border-ink rounded-full px-2.5 py-1 text-[#ffd75e] text-sm font-bold shrink-0"
    >
      <PokedollarIcon imageUrl={imageUrl} className="w-4 h-4" fallbackClassName="" />
      <span>{amount}</span>
    </div>
  )
}
