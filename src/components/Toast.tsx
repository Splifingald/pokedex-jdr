interface Props {
  message: string
}

export function Toast({ message }: Props) {
  return (
    <div className="bg-cream border-2 border-ink rounded-lg shadow-[var(--shadow-pixel)] px-4 py-2 text-ink text-sm font-bold">
      {message}
    </div>
  )
}
