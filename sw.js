const CACHE_NAME = 'seen-v22';
const ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './icon-192.webp',
  './icon-512.webp',
  './1778995068748.webp',
  './1781878817675.webp',
  './apk.webp',
  './exe.webp',
  './facebook.webp',
  './github.webp',
  './Instagram.webp',
  './tiktok.webp',
  './youtube.webp',
  './FC-Mittraphap.woff2'
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((k) => {
          if (k !== CACHE_NAME) return caches.delete(k);
        })
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  e.respondWith(
    caches.match(e.request).then((res) => res || fetch(e.request))
  );
});
