self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {}
  const title = data.title || 'Mesa'
  const options = {
    body: data.body || 'Existe uma nova notificação.',
    icon: data.icon || '/icon.svg',
    badge: '/icon.svg',
    tag: data.tag || 'mesa-notification',
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
