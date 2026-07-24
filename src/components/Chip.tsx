interface Props {
  label: string
  active: boolean
  onClick: () => void
}

export function Chip({ label, active, onClick }: Props) {
  return (
    <button
      onClick={onClick}
      className={`px-3 py-1.5 rounded-full border-2 border-ink text-xs font-bold transition-colors ${
        active ? 'bg-shell text-white' : 'bg-[#2a2c48] text-[#c9cbe8]'
      }`}
    >
      {label}
    </button>
  )
}
