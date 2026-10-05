import React from 'react';
import ReactDOM from 'react-dom/client';
import 'pretendard/dist/web/variable/pretendardvariable-dynamic-subset.css';
import '@fontsource-variable/archivo';
import './index.css';
import App from './App';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);

/** 지금까지 받은 폰트 파일 주소 */
function loadedFontUrls(): string[] {
  return performance
    .getEntriesByType('resource')
    .map((e) => e.name)
    .filter((href) => /\.woff2?$/.test(new URL(href).pathname));
}

// 오프라인 지원 (public/sw.js) — 개발 서버에서는 등록하지 않는다
if (import.meta.env.PROD && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker
      .register(`${import.meta.env.BASE_URL}sw.js`)
      .then(() => Promise.all([navigator.serviceWorker.ready, document.fonts.ready]))
      .then(([registration]) => {
        // 첫 방문의 폰트는 서비스 워커가 페이지를 맡기 전에 받아 폰트 캐시를 거치지 않았다 — 오프라인에서도 쓰도록 담게 한다
        const urls = loadedFontUrls();
        if (urls.length > 0) registration.active?.postMessage({ type: 'cache-fonts', urls });
      })
      .catch(() => undefined);
  });
}
