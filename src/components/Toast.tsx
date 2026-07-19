interface Props {
  message: string
}

export function Toast({ message }: Props) {
  return (
    <div className="bg-gray-900 border-2 border-gray-600 rounded shadow-[4px_4px_0px_#000] px-4 py-2 text-white text-sm">
      {message}
    </div>
  )
}
