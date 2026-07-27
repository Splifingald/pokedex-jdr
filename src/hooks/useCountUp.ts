import { useEffect, useState } from 'react'

// Anime un nombre affiché depuis sa valeur courante vers `target` sur `durationMs`.
export function useCountUp(target: number, durationMs = 500): number {
  const [value, setValue] = useState(target)

  useEffect(() => {
    let raf: number
    const start = performance.now()
    const from = value
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / durationMs)
      setValue(Math.round(from + (target - from) * t))
      if (t < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
    // eslint-disable-next-line react-hooks/exhaustive-deps -- animate from whatever value currently is toward the new target
  }, [target, durationMs])

  return value
}
