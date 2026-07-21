import { useEffect } from 'react'

interface Props {
  imageUrl: string
  onClose: () => void
}

export function CarteImageViewer({ imageUrl, onClose }: Props) {
  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onClose])

  return (
    <div
      className="fixed inset-0 z-50 bg-black/90 flex items-start md:items-center justify-center p-0 md:p-8 cursor-pointer"
      onClick={onClose}
    >
      <img src={imageUrl} alt="" className="max-w-full max-h-full object-contain" />
    </div>
  )
}
