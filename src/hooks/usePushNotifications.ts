import { useState, useEffect, useCallback } from 'react'
import { isPushSupported, isIOS, isStandalone, subscribeToPush, unsubscribeFromPush } from '../lib/pushNotifications'

export function usePushNotifications(playerId: number | null) {
  const supported = isPushSupported()
  const needsInstall = isIOS() && !isStandalone()

  const [permission, setPermission] = useState<NotificationPermission>(() => (supported ? Notification.permission : 'denied'))
  const [subscribed, setSubscribed] = useState(false)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (!supported) return
    navigator.serviceWorker.ready
      .then((registration) => registration.pushManager.getSubscription())
      .then((sub) => setSubscribed(!!sub))
      .catch(() => {})
  }, [supported])

  const enable = useCallback(async () => {
    if (!playerId || !supported || needsInstall) return false
    setLoading(true)
    try {
      const ok = await subscribeToPush(playerId)
      setPermission(Notification.permission)
      setSubscribed(ok)
      return ok
    } finally {
      setLoading(false)
    }
  }, [playerId, supported, needsInstall])

  const disable = useCallback(async () => {
    setLoading(true)
    try {
      await unsubscribeFromPush()
      setSubscribed(false)
    } finally {
      setLoading(false)
    }
  }, [])

  return { supported, needsInstall, permission, subscribed, loading, enable, disable }
}
