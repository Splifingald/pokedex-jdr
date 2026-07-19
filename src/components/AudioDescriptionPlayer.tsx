import { useState, useRef, useEffect } from 'react'

interface Props {
  audioUrl: string
}

// Remonter ce composant (via une prop `key` côté appelant, ex: key={pokemon.id})
// réinitialise naturellement le lecteur quand on change de pokémon.
export function AudioDescriptionPlayer({ audioUrl }: Props) {
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const [audioState, setAudioState] = useState<'idle' | 'playing' | 'paused'>('idle')
  const [progress, setProgress] = useState(0) // 0–1
  const [duration, setDuration] = useState(0)

  useEffect(() => {
    return () => { audioRef.current?.pause() }
  }, [])

  function fmt(sec: number) {
    const m = Math.floor(sec / 60)
    const s = Math.floor(sec % 60)
    return `${m}:${s.toString().padStart(2, '0')}`
  }

  function toggleAudio() {
    const a = audioRef.current
    if (!a) return
    if (audioState === 'playing') {
      a.pause()
      setAudioState('paused')
    } else {
      a.play()
      setAudioState('playing')
    }
  }

  return (
    <>
      <audio
        ref={audioRef}
        src={audioUrl}
        onLoadedMetadata={(e) => setDuration(e.currentTarget.duration)}
        onTimeUpdate={(e) => {
          const a = e.currentTarget
          setProgress(a.duration ? a.currentTime / a.duration : 0)
        }}
        onEnded={() => { setAudioState('idle'); setProgress(0) }}
      />
      <div className="mx-4 my-3 px-3 py-2 bg-gray-800/60 border border-gray-700 rounded-lg flex items-center gap-3">
        <span className="text-lg shrink-0">🔊</span>
        <span className="text-gray-300 text-xs shrink-0">Description</span>

        <div
          className="flex-1 h-1.5 bg-gray-700 rounded-full overflow-hidden cursor-pointer"
          onClick={(e) => {
            const a = audioRef.current
            if (!a || !a.duration) return
            const rect = e.currentTarget.getBoundingClientRect()
            a.currentTime = ((e.clientX - rect.left) / rect.width) * a.duration
          }}
        >
          <div
            className="h-full bg-gray-400 rounded-full transition-all duration-100"
            style={{ width: `${progress * 100}%` }}
          />
        </div>

        <span className="text-gray-500 text-xs shrink-0 w-8 text-right">
          {audioState === 'idle' ? fmt(duration) : fmt((audioRef.current?.currentTime ?? 0))}
        </span>

        <button
          onClick={toggleAudio}
          className="w-8 h-8 rounded-full bg-gray-700 hover:bg-gray-600 flex items-center justify-center shrink-0 transition-colors"
        >
          {audioState === 'playing' ? '⏸' : '▶'}
        </button>
      </div>
    </>
  )
}
