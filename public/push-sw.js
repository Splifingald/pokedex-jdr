// Gestion des notifications Web Push (tickets casino pleins, cadeau pokémon prêt).
// Importé dans le service worker généré par Workbox via workbox.importScripts
// (voir vite.config.ts) — reste un fichier séparé pour ne pas migrer vers
// injectManifest et risquer de casser le précache existant.

self.addEventListener('push', (event) => {
  let payload = {}
  try {
    payload = event.data ? event.data.json() : {}
  } catch {
    payload = {}
  }
  const { title, body, icon, image, url } = payload

  event.waitUntil(
    self.registration.showNotification(title || 'Pokédex', {
      body,
      icon: icon || '/pwa-icons/pwa-192x192.png',
      image,
      data: { url: url || '/' },
    })
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = (event.notification.data && event.notification.data.url) || '/'

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) return client.focus()
      }
      if (self.clients.openWindow) return self.clients.openWindow(url)
    })
  )
})
