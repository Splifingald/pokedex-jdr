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
  const { title, body, icon, url } = payload

  // Pas de champ "image" : sur Android, sa présence bascule Chrome en style
  // BigPicture et remplace l'icône de gauche par l'icône générique du navigateur.
  // Avec seulement "icon", l'image custom (avatar joueur/PNJ, sprite pokémon...)
  // s'affiche bien en grande icône à gauche. "badge" est la petite icône
  // (monochrome sur Android, dans la barre de statut) : toujours l'icône de
  // l'app, pour que ce soit bien l'icône contextuelle qui prime à gauche.
  event.waitUntil(
    self.registration.showNotification(title || 'Pokémon JDR', {
      body,
      icon: icon || '/pwa-icons/pwa-192x192.png',
      badge: '/pwa-icons/pwa-192x192.png',
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
