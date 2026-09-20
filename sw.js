const CACHE_NAME = 'seen-v96';
const CACHE_MAX_AGE = 24 * 60 * 60 * 1000;
const CACHE_TIME_HEADER = 'x-seen-cached-at';
const SCOPE_URL = new URL(self.registration.scope);
const SHELL_URL = new URL('index.html', SCOPE_URL).href;
const SHELL_PATH = new URL(SHELL_URL).pathname;
const STATIC_URLS = new Set([
  'manifest.json',
  'icon-192.webp',
  'icon-512.webp',
  '1778995068748.webp',
  '1781878817675.webp',
  'certificate-soft-power.webp',
  'certificate-scratch.webp',
  'apk.webp',
  'exe.webp',
  'paintapp-icon.webp',
  'chattranslate-icon.webp',
  'MyDrawing.svg',
  'facebook.webp',
  'github.webp',
  'Instagram.webp',
  'tiktok.webp',
  'youtube.webp',
  'FC-Mittraphap.woff2'
].map((path) => new URL(path, SCOPE_URL).href));

function isCacheable(response) {
  return response.ok && response.type === 'basic' &&
    !/no-store/i.test(response.headers.get('cache-control') || '');
}

async function saveResponse(url, response) {
  if (!isCacheable(response)) return;
  const headers = new Headers(response.headers);
  headers.set(CACHE_TIME_HEADER, String(Date.now()));
  const stored = new Response(response.clone().body, {
    status: response.status,
    statusText: response.statusText,
    headers
  });
  const cache = await caches.open(CACHE_NAME);
  await cache.put(url, stored);
}

self.addEventListener('install', (event) => {
  // Only the small HTML shell is required offline; assets are fetched as used.
  // A transient network failure must not prevent a fixed worker from installing.
  event.waitUntil(
    fetch(SHELL_URL, {cache: 'no-cache'})
      .then((response) => saveResponse(SHELL_URL, response))
      .catch(() => {})
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys.filter((key) => /^seen-v\d+$/.test(key) && key !== CACHE_NAME)
        .map((key) => caches.delete(key))
    )).then(() => self.clients.claim())
  );
});

function cachedResponse(url) {
  return caches.match(url, {cacheName: CACHE_NAME}).catch(() => undefined);
}

async function navigationResponse(event) {
  try {
    const response = await fetch(event.request);
    if (response.ok) {
      // Cache failures (for example storage pressure) must never break a page.
      event.waitUntil(saveResponse(SHELL_URL, response).catch(() => {}));
      return response;
    }
    const cached = await cachedResponse(SHELL_URL);
    return cached || response;
  } catch (error) {
    const cached = await cachedResponse(SHELL_URL);
    if (cached) return cached;
    throw error;
  }
}

async function staticResponse(event) {
  const request = event.request;
  const cached = await cachedResponse(request.url);
  const cachedAt = cached && Number(cached.headers.get(CACHE_TIME_HEADER));
  const reloading = request.cache === 'reload' || request.cache === 'no-cache';
  if (cached && !reloading && Date.now() - cachedAt < CACHE_MAX_AGE) {
    return cached;
  }
  try {
    // The browser HTTP cache can revalidate expired files without re-downloading.
    const response = await fetch(request);
    if (response.ok) {
      event.waitUntil(saveResponse(request.url, response).catch(() => {}));
      return response;
    }
    return cached || response;
  } catch (error) {
    if (cached) return cached;
    throw error;
  }
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== SCOPE_URL.origin ||
      request.headers.has('range')) return;

  if (request.mode === 'navigate' &&
      (url.pathname === SCOPE_URL.pathname || url.pathname === SHELL_PATH)) {
    event.respondWith(navigationResponse(event));
  } else if (STATIC_URLS.has(url.href)) {
    // Executables, APKs, arbitrary URLs, and cross-origin requests bypass this worker.
    event.respondWith(staticResponse(event));
  }
});
