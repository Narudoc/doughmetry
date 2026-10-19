# Doughmetry (도우메트리) — 사워도우 레시피 계산기 · 르방 변환기

정통 프랑스식 사워도우(팽 오 르방, *pain au levain*) 레시피를 위한 정적 웹 도구입니다.
백엔드 없이 동작하며 모든 데이터는 브라우저 localStorage에 저장됩니다.

## 기능

- **레시피 계산기** — 베이커스 퍼센트 기반. 총 수분율(*hydratation totale*)·소금 비율·PFF(발효종 밀가루 비율)를 실시간 계산. 모든 비율은 **총 밀가루(첨가 밀가루 + 르방 속 밀가루) 기준**입니다.
  - 모드 A: 재료를 g으로 입력
  - 모드 B: 목표 반죽 무게·수분율·PFF에서 역산
- **르방 변환기** — 르방 리퀴드(수분율 100%) ↔ 르방 뒤흐(50%) 상호 변환. 르방 질량을 고정한 채 총 수분율을 보존하도록 첨가 밀가루·물을 재계산하고, 변환 전후를 나란히 대조 표시합니다. 보조 모드로 PFF 고정 변환도 지원합니다.
- **재료** — 여러 밀가루, 바시나주(믹싱 후반에 넣는 물), 우유·계란 같은 액체 재료(수분 함량만큼 총 물에 반영), 이스트(생↔인스턴트), 기타 재료.
- **레시피 가져오기** — 사진(브라우저 안 OCR, 처음 쓸 때 인식 데이터를 내려받음)이나 붙여넣은 텍스트에서 재료를 읽고, 확인 다이얼로그에서 고친 뒤 저장합니다.
- **배율 조정** — 모든 재료를 같은 배율로(×½·×2·원하는 총 무게·개수 × 개당 무게) 늘리거나 줄여 수분율·소금·PFF는 그대로.
- **레시피 저장** — localStorage 저장/불러오기/복제/삭제/검색/태그 필터 + JSON 내보내기·가져오기(백업/기기 이동)
- **오프라인에서도 동작** (사진 인식 제외, 첫 방문 후)

## iPhone·iPad 앱

[ios/](ios/README.md)에 SwiftUI 네이티브 버전이 있습니다. 계산 규칙과 레시피 JSON은 웹과 같아서 내보내기 파일을 양쪽에서 주고받을 수 있고, 베이킹 로그·르방 빌드·물 온도·타임라인 알림·iCloud 동기화는 iOS 전용입니다. App Store 등록 문구와 출시 절차는 [ios/AppStore/](ios/AppStore/submission.md)에 있습니다.

## 로컬 실행

Node.js 20 이상이 필요합니다.

```bash
npm install
npm run dev        # 개발 서버 — http://localhost:5173/doughmetry/
npm test           # 계산 로직 유닛 테스트 (Vitest)
npm run build      # 프로덕션 빌드 → dist/
npm run preview    # 빌드 결과 미리보기
```

> 개발 서버 주소에 `/doughmetry/` 경로가 붙는 것은 GitHub Pages 배포용 `base` 설정 때문입니다.

## GitHub Pages 배포

1. GitHub에 **`doughmetry`** 이름으로 저장소를 만들고 이 프로젝트를 push 합니다.
2. 저장소 **Settings → Pages → Build and deployment → Source**에서 **GitHub Actions**를 선택합니다.
3. `main` 브랜치에 push 하면 `.github/workflows/deploy.yml`이 테스트 → 빌드 → 배포를 자동 실행합니다.
4. 배포 주소: `https://<사용자명>.github.io/doughmetry/`

### 저장소 이름을 바꾸는 경우

GitHub Pages는 `https://<사용자명>.github.io/<저장소명>/` 경로로 서비스되므로,
[vite.config.ts](vite.config.ts)의 `base`를 저장소 이름과 똑같이 맞춰야 합니다.

```ts
export default defineConfig({
  base: '/새-저장소명/',
  // ...
});
```

`base`가 어긋나면 배포된 페이지에서 JS/CSS 로딩이 404로 실패합니다.

[index.html](index.html)의 `og:url`·`og:image`·`canonical`과 iOS [AppLinks.swift](ios/Doughmetry/AppLinks.swift)도
`https://narudoc.github.io/doughmetry/`를 그대로 적고 있으니 `base`와 함께 바꾸세요.

## 기술 스택

Vite · React 18 · TypeScript · Tailwind CSS v3 · Vitest

계산 로직은 [src/lib/dough.ts](src/lib/dough.ts)에 순수 함수로 분리되어 있고,
[src/lib/dough.test.ts](src/lib/dough.test.ts)에서 왕복 변환·불변식 property test를 포함해 검증합니다.
도메인 용어와 계산 규칙은 [CLAUDE.md](CLAUDE.md)를 참고하세요.
