/*
 * 도우메트리 서비스 워커 — 빌드 도구·의존성 없이 손으로 쓴 오프라인 지원.
 * - 앱 셸(index.html과 그것이 참조하는 자산·아이콘·매니페스트)만 받아 둔다. 목록을 index.html에서 읽으므로
 *   사진 인식(tesseract.js)처럼 동적으로 불러오는 청크는 저절로 빠진다.
 * - 화면 이동은 네트워크 우선, 실패하면 받아 둔 셸. 셸 주소(범위 루트·index.html)에만 적용해
 *   privacy.html·support.html 같은 정적 페이지가 앱 화면으로 바뀌지 않게 한다.
 * - 폰트는 쓰일 때 받아 둔다. 서비스 워커가 페이지를 맡기 전(첫 방문)에 받은 폰트는 페이지가 주소를 보내 주면 담는다.
 *   다른 출처(jsDelivr의 인식 엔진·언어 데이터)는 건드리지 않는다.
 * 동작을 바꾸면 캐시 이름의 버전을 올릴 것.
 */
const SHELL_CACHE = 'doughmetry-shell-v4';
const FONT_CACHE = 'doughmetry-fonts-v2';
const FONT_LIMIT = 150;

const SCOPE = new URL(self.registration.scope);
const SHELL_URL = SCOPE.href;
const EXTRAS = [
  'manifest.webmanifest',
  'favicon-32.png',
  'apple-touch-icon.png',
  'icon-192.png',
  'icon-512.png',
].map((p) => new URL(p, SCOPE).href);

const inScope = (url) => url.origin === SCOPE.origin && url.pathname.startsWith(SCOPE.pathname);
const isFont = (url) => /\.woff2?$/.test(url.pathname);
const isShellPage = (url) =>
  url.pathname === SCOPE.pathname || url.pathname === `${SCOPE.pathname}index.html`;

/** index.html이 참조하는 같은 범위의 자산 (스크립트·스타일·modulepreload·아이콘) */
function referencedAssets(html) {
  const urls = new Set();
  for (const [, ref] of html.matchAll(/\s(?:src|href)="([^"]+)"/g)) {
    const url = new URL(ref, SCOPE);
    url.hash = '';
    if (inScope(url) && !isShellPage(url) && !url.pathname.endsWith('.html')) urls.add(url.href);
  }
  return [...urls];
}

/**
 * 셸을 새 index.html로 바꾼다. 참조하는 자산을 모두 받은 뒤에만 바꾸므로, 도중에 실패하면
 * 앞의 셸과 그 자산이 그대로 남아 오프라인에서도 짝이 맞는다
 */
async function storeShell(response) {
  const html = await response.clone().text();
  const cache = await caches.open(SHELL_CACHE);
  const required = referencedAssets(html);
  const fetchInto = async (url) => {
    // assets/만 이름에 해시가 있다 — 아이콘·매니페스트는 이름이 그대로라 셸을 바꿀 때마다 다시 확인한다
    const hashed = url.startsWith(`${SCOPE.href}assets/`);
    if (hashed && (await cache.match(url))) return;
    const res = await fetch(url, hashed ? undefined : { cache: 'no-cache' });
    if (!res.ok) throw new Error(`${res.status} ${url}`);
    await cache.put(url, res);
  };
  await Promise.all(required.map(fetchInto));
  await Promise.all(
    EXTRAS.filter((url) => !required.includes(url)).map((url) => fetchInto(url).catch(() => undefined)),
  );
  await cache.put(SHELL_URL, response);
  const keep = new Set([SHELL_URL, ...required, ...EXTRAS]);
  for (const req of await cache.keys()) {
    if (!keep.has(req.url)) await cache.delete(req);
  }
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const res = await fetch(SHELL_URL, { cache: 'no-cache' });
      if (!res.ok) throw new Error(`${res.status} ${SHELL_URL}`);
      await storeShell(res);
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) {
        if (key.startsWith('doughmetry-') && key !== SHELL_CACHE && key !== FONT_CACHE) {
          await caches.delete(key);
        }
      }
      await self.clients.claim();
    })(),
  );
});

async function navigate(event) {
  try {
    const res = await fetch(event.request);
    const html = (res.headers.get('content-type') || '').includes('text/html');
    // 리다이렉트된 응답을 화면 이동에 다시 내주면 Safari가 거부한다
    if (res.ok && html && !res.redirected) {
      event.waitUntil(storeShell(res.clone()).catch(() => undefined));
    }
    return res;
  } catch (err) {
    const cached = await caches.match(SHELL_URL, { cacheName: SHELL_CACHE });
    if (cached) return cached;
    throw err;
  }
}

async function shellFirst(request) {
  const cached = await caches.match(request, { cacheName: SHELL_CACHE });
  return cached || fetch(request);
}

async function trimFonts(cache) {
  const keys = await cache.keys();
  for (const old of keys.slice(0, Math.max(0, keys.length - FONT_LIMIT))) await cache.delete(old);
}

async function fontFirst(request) {
  const cache = await caches.open(FONT_CACHE);
  const cached = await cache.match(request);
  if (cached) return cached;
  const res = await fetch(request);
  if (res.ok) {
    await cache.put(request, res.clone());
    await trimFonts(cache);
  }
  return res;
}

/** 페이지가 이미 받은 폰트 주소 — 대개 브라우저 HTTP 캐시에서 바로 나온다 */
async function storeFonts(hrefs) {
  const cache = await caches.open(FONT_CACHE);
  for (const href of hrefs.slice(0, FONT_LIMIT)) {
    let url;
    try {
      url = new URL(href);
    } catch {
      continue;
    }
    url.hash = '';
    if (!inScope(url) || !isFont(url) || (await cache.match(url.href))) continue;
    try {
      const res = await fetch(url.href);
      if (res.ok) await cache.put(url.href, res);
    } catch {
      // 오프라인 등 — 다음 방문에 다시 보낸다
    }
  }
  await trimFonts(cache);
}

self.addEventListener('message', (event) => {
  const { data } = event;
  if (data?.type !== 'cache-fonts' || !Array.isArray(data.urls)) return;
  event.waitUntil(storeFonts(data.urls.filter((u) => typeof u === 'string')));
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (!inScope(url)) return;
  if (request.mode === 'navigate') {
    if (isShellPage(url)) event.respondWith(navigate(event));
    return;
  }
  if (isFont(url)) {
    event.respondWith(fontFirst(request));
    return;
  }
  event.respondWith(shellFirst(request));
});
