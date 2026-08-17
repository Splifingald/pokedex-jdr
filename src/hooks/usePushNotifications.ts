import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import { isPushSupported, isIOS, isStandalone, subscribeToPush, unsubscribeFromPush } from '../lib/pushNotifications'

export function usePushNotifications(playerId: number | null) {
  const supported = isPushSupported()
  const needsInstall = isIOS() && !isStandalone()

  const [permission, setPermission] = useState<NotificationPermission>(() => (supported ? Notification.permission : 'denied'))
  const [subscribed, setSubscribed] = useState(false)
  const [ready, setReady] = useState(!supported)
  const [loading, setLoading] = useState(false)
  const runIdRef = useRef(0)

  // Relit l'état réel : la permission peut avoir été révoquée depuis les réglages
  // du navigateur, et l'abonnement peut avoir disparu de Supabase ou avoir été
  // rattaché à un autre joueur sur le même appareil.
  const refresh = useCallback(async () => {
    if (!supported) return
    const runId = ++runIdRef.current
    const apply = (perm: NotificationPermission, isSubscribed: boolean) => {
      if (runIdRef.current !== runId) return
      setPermission(perm)
      setSubscribed(isSubscribed)
      setReady(true)
    }

    const perm = Notification.permission
    if (perm !== 'granted' || !playerId) {
      apply(perm, false)
      return
    }
    try {
      const registration = await navigator.serviceWorker.ready
      const sub = await registration.pushManager.getSubscription()
      if (!sub) {
        apply(perm, false)
        return
      }
      const { data, error } = await supabase
        .from('push_subscriptions')
        .select('player_id')
        .eq('endpoint', sub.endpoint)
        .maybeSingle()
      // En cas d'erreur réseau on garde l'abonnement navigateur comme vérité,
      // plutôt que d'afficher à tort « désactivées ».
      apply(perm, error ? true : data?.player_id === playerId)
    } catch {
      apply(perm, false)
    }
  }, [supported, playerId])

  useEffect(() => {
    void refresh()
  }, [refresh])

  // Le navigateur peut changer la permission pendant que l'app est en arrière-plan
  // (réglages système / iOS), on resynchronise au retour sur l'app.
  useEffect(() => {
    if (!supported) return
    const handler = () => {
      if (document.visibilityState === 'visible') void refresh()
    }
    document.addEventListener('visibilitychange', handler)
    window.addEventListener('focus', handler)
    return () => {
      document.removeEventListener('visibilitychange', handler)
      window.removeEventListener('focus', handler)
    }
  }, [supported, refresh])

  const enable = useCallback(async () => {
    if (!playerId || !supported || needsInstall) return false
    setLoading(true)
    try {
      const ok = await subscribeToPush(playerId)
      setPermission(Notification.permission)
      setSubscribed(ok)
      setReady(true)
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
      if (supported) setPermission(Notification.permission)
    } finally {
      setLoading(false)
    }
  }, [supported])

  return { supported, needsInstall, permission, subscribed, ready, loading, enable, disable, refresh }
}
