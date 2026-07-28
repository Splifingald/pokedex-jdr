import { useRef, useState } from 'react'

interface Props {
  src: string
  alt: string
  position: number
  onPositionChange: (position: number) => void
  className?: string
}

// Image d'en-tête (chapitre/session) qu'on peut glisser verticalement pour choisir
// la partie visible dans le cadre rogné (object-fit: cover).
export function EditableHeaderImage({ src, alt, position, onPositionChange, className = '' }: Props) {
  const containerRef = useRef<HTMLDivElement>(null)
  const imgRef = useRef<HTMLImageElement>(null)
  const dragState = useRef<{ startY: number; startPosition: number; overflow: number } | null>(null)
  const [dragging, setDragging] = useState(false)
  const [canDrag, setCanDrag] = useState(false)

  const computeOverflow = () => {
    const container = containerRef.current
    const img = imgRef.current
    if (!container || !img || !img.naturalWidth || !img.naturalHeight) return 0
    const scale = Math.max(container.clientWidth / img.naturalWidth, container.clientHeight / img.naturalHeight)
    const scaledHeight = img.naturalHeight * scale
    return Math.max(0, scaledHeight - container.clientHeight)
  }

  const handleLoad = () => setCanDrag(computeOverflow() > 0)

  const handlePointerDown = (e: React.PointerEvent<HTMLImageElement>) => {
    const overflow = computeOverflow()
    if (overflow <= 0) return
    e.currentTarget.setPointerCapture(e.pointerId)
    dragState.current = { startY: e.clientY, startPosition: position, overflow }
    setDragging(true)
  }

  const handlePointerMove = (e: React.PointerEvent<HTMLImageElement>) => {
    if (!dragState.current) return
    const { startY, startPosition, overflow } = dragState.current
    const dy = e.clientY - startY
    const deltaPercent = (dy / overflow) * 100
    const next = Math.min(100, Math.max(0, Math.round(startPosition - deltaPercent)))
    onPositionChange(next)
  }

  const endDrag = () => {
    dragState.current = null
    setDragging(false)
  }

  return (
    <div ref={containerRef} className={`relative overflow-hidden select-none ${className}`}>
      <img
        ref={imgRef}
        src={src}
        alt={alt}
        draggable={false}
        onLoad={handleLoad}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
        className={`w-full h-full object-cover touch-none ${canDrag ? (dragging ? 'cursor-grabbing' : 'cursor-grab') : ''}`}
        style={{ objectPosition: `50% ${position}%` }}
      />
      {canDrag && (
        <span className="pointer-events-none absolute bottom-1 right-1 text-[10px] font-bold text-white bg-black/50 rounded px-1.5 py-0.5">
          ↕ glisser
        </span>
      )}
    </div>
  )
}
