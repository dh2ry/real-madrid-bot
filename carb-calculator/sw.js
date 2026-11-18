// Service Worker — يتيح العمل بدون إنترنت. غيّر VERSION عند تحديث الملفات.
const VERSION = 'carb-calc-v3';
const ASSETS = [
  './', './index.html', './manifest.webmanifest', './css/styles.css',
  './js/app.js', './js/ui.js', './js/calc.js', './js/log.js', './js/db.js', './js/categories.js', './data/foods.js',
  './icons/icon.svg', './icons/icon-192.png', './icons/icon-512.png', './icons/apple-touch-icon.png',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

// الشبكة أولاً (لتصل التحديثات)، ثم النسخة المخزنة عند انقطاع الإنترنت
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET' || new URL(e.request.url).origin !== location.origin) return;
  e.respondWith(
    fetch(e.request)
      .then((res) => {
        if (res.ok) {
          const copy = res.clone();
          caches.open(VERSION).then((c) => c.put(e.request, copy));
        }
        return res;
      })
      .catch(() => caches.match(e.request, { ignoreSearch: true }).then((r) => r || caches.match('./index.html'))),
  );
});
