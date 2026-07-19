import { useRef, useCallback } from 'react'

const INITIAL_DELAY = 400
const REPEAT_INTERVAL = 80

export function useHoldRepeat(callback: () => void) {
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const stop = useCallback(() => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current)
      timeoutRef.current = null
    }
    if (intervalRef.current) {
      clearInterval(intervalRef.current)
      intervalRef.current = null
    }
  }, [])

  const start = useCallback(() => {
    callback()
    timeoutRef.current = setTimeout(() => {
      intervalRef.current = setInterval(callback, REPEAT_INTERVAL)
    }, INITIAL_DELAY)
  }, [callback])

  return {
    onMouseDown: start,
    onMouseUp: stop,
    onMouseLeave: stop,
    onTouchStart: (e: React.TouchEvent) => { e.preventDefault(); start() },
    onTouchEnd: stop,
  }
}
