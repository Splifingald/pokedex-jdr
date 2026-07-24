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
      {imageUrl ? (
        <img src={imageUrl} alt="" className="w-4 h-4 object-contain" />
      ) : (
        <span>💰</span>
      )}
      <span>{amount}</span>
    </div>
  )
}
