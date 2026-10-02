self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {}
  const title = data.title || 'Bocato'
  const options = {
    body: data.body || 'Existe uma nova notificação.',
    icon: data.icon || '/bocato-icon-v3-192.png',
    badge: '/bocato-icon-v3-192.png',
    tag: data.tag || 'bocato-notification',
    data: { url: data.url || '/staff/orders' }
  }

  event.waitUntil(self.registration.showNotification(title, options))
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = new URL(event.notification.data?.url || '/staff/orders', self.location.origin).href

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      const existing = windows.find((window) => window.url.startsWith(self.location.origin))
      if (existing) return existing.focus().then(() => existing.navigate(url))
      return clients.openWindow(url)
    })
  )
})
