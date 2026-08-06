// 醒刻 — 离线缓存 Service Worker
// 页面请求走「网络优先」：在线刷新永远拿到最新 index.html，改代码不用手动清缓存；
// 只有断网时才回落到缓存副本。其余静态资源（图标等）缓存优先。
// 若改了 manifest/icons，仍记得把下方 CACHE 版本号 +1 强制整体换新。
var CACHE = 'wake-clock-v2';
var ASSETS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

self.addEventListener('install', function (e) {
  e.waitUntil(
    caches.open(CACHE).then(function (c) {
      return c.addAll(ASSETS);
    }).then(function () {
      return self.skipWaiting();
    })
  );
});

self.addEventListener('activate', function (e) {
  e.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.filter(function (k) { return k !== CACHE; }).map(function (k) {
        return caches.delete(k);
      }));
    }).then(function () {
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', function (e) {
  if (e.request.method !== 'GET') return;
  if (e.request.mode === 'navigate') {
    // 页面：网络优先，失败回缓存
    e.respondWith(
      fetch(e.request).then(function (resp) {
        if (resp && resp.status === 200) {
          var copy = resp.clone();
          caches.open(CACHE).then(function (c) { c.put(e.request, copy); });
        }
        return resp;
      }).catch(function () {
        return caches.match(e.request).then(function (m) { return m || caches.match('./index.html'); });
      })
    );
    return;
  }
  // 其余资源：缓存优先
  e.respondWith(
    caches.match(e.request).then(function (res) {
      if (res) return res;
      return fetch(e.request).then(function (resp) {
        if (resp && resp.status === 200) {
          var copy = resp.clone();
          caches.open(CACHE).then(function (c) { c.put(e.request, copy); });
        }
        return resp;
      });
    }).catch(function () {
      return caches.match('./index.html');
    })
  );
});
