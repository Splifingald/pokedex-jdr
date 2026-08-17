import { supabase } from './supabase'

// Conversion standard clé VAPID base64url → Uint8Array attendu par PushManager.subscribe
function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const rawData = window.atob(base64)
  const outputArray = new Uint8Array(rawData.length)
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i)
  }
  return outputArray
}

export function isPushSupported(): boolean {
  return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window
}

// iOS/iPadOS Safari n'autorise les notifications que si la PWA est installée
// sur l'écran d'accueil — pas de beforeinstallprompt sur iOS, donc détection
// par user agent + touch points (iPadOS 13+ se fait passer pour macOS).
export function isIOS(): boolean {
  return /iphone|ipad|ipod/i.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
}

// Les notifications push n'ont d'intérêt que sur mobile (l'app y vit en PWA) :
// on ne sollicite pas l'utilisateur à l'ouverture sur un ordinateur.
export function isMobileDevice(): boolean {
  if (isIOS()) return true
  if (/android|iphone|ipad|ipod|mobile/i.test(navigator.userAgent)) return true
  return window.matchMedia('(pointer: coarse)').matches && navigator.maxTouchPoints > 0
}

export function isStandalone(): boolean {
  return window.matchMedia('(display-mode: standalone)').matches ||
    (navigator as Navigator & { standalone?: boolean }).standalone === true
}

// Demande la permission puis crée/réutilise l'abonnement push, et l'enregistre
// dans Supabase pour que la fonction planifiée puisse envoyer des notifications
// à ce joueur. Retourne false si la permission est refusée ou en cas d'erreur.
export async function subscribeToPush(playerId: number): Promise<boolean> {
  const permission = await Notification.requestPermission()
  if (permission !== 'granted') return false

  const registration = await navigator.serviceWorker.ready
  let subscription = await registration.pushManager.getSubscription()
  if (!subscription) {
    const vapidPublicKey = import.meta.env.VITE_VAPID_PUBLIC_KEY as string
    if (!vapidPublicKey) {
      console.error('VITE_VAPID_PUBLIC_KEY manquante')
      return false
    }
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(vapidPublicKey) as BufferSource,
    })
  }

  const json = subscription.toJSON()
  if (!json.endpoint || !json.keys?.p256dh || !json.keys?.auth) return false

  const { error } = await supabase
    .from('push_subscriptions')
    .upsert(
      { player_id: playerId, endpoint: json.endpoint, p256dh: json.keys.p256dh, auth: json.keys.auth },
      { onConflict: 'endpoint' }
    )
  if (error) {
    console.error("Erreur lors de l'enregistrement de l'abonnement push :", error)
    return false
  }
  return true
}

export async function unsubscribeFromPush(): Promise<void> {
  if (!('serviceWorker' in navigator)) return
  const registration = await navigator.serviceWorker.ready
  const subscription = await registration.pushManager.getSubscription()
  if (!subscription) return
  const endpoint = subscription.endpoint
  await subscription.unsubscribe()
  await supabase.from('push_subscriptions').delete().eq('endpoint', endpoint)
}
