import { useState, useEffect, useCallback } from 'react'

export const isFullscreenSupported =
  typeof document !== 'undefined' &&
  typeof document.documentElement.requestFullscreen === 'function'

export function useFullscreen() {
  const [isFullscreen, setIsFullscreen] = useState(() => !!document.fullscreenElement)

  useEffect(() => {
    const handler = () => setIsFullscreen(!!document.fullscreenElement)
    document.addEventListener('fullscreenchange', handler)
    return () => document.removeEventListener('fullscreenchange', handler)
  }, [])

  const enter = useCallback(() => {
    document.documentElement.requestFullscreen().catch(() => {})
  }, [])

  const exit = useCallback(() => {
    document.exitFullscreen().catch(() => {})
  }, [])

  const toggle = useCallback(() => {
    if (document.fullscreenElement) {
      exit()
    } else {
      enter()
    }
  }, [enter, exit])

  return { isFullscreen, enter, exit, toggle }
}
