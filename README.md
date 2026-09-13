# Doughmetry (도우메트리) — 사워도우 레시피 계산기 · 르방 변환기

정통 프랑스식 사워도우(팽 오 르방, *pain au levain*) 레시피를 위한 정적 웹 도구입니다.
백엔드 없이 동작하며 모든 데이터는 브라우저 localStorage에 저장됩니다.

## 기능

- **레시피 계산기** — 베이커스 퍼센트 기반. 총 수분율(*hydratation totale*)·소금 비율·PFF(발효종 밀가루 비율)를 실시간 계산. 모든 비율은 **총 밀가루(첨가 밀가루 + 르방 속 밀가루) 기준**입니다.
  - 모드 A: 재료를 g으로 입력
  - 모드 B: 목표 반죽 무게·수분율·PFF에서 역산
- **르방 변환기** — 르방 리퀴드(수분율 100%) ↔ 르방 뒤흐(50%) 상호 변환. 르방 질량을 고정한 채 총 수분율을 보존하도록 첨가 밀가루·물을 재계산하고, 변환 전후를 나란히 대조 표시합니다. 보조 모드로 PFF 고정 변환도 지원합니다.
- **레시피 저장** — localStorage 저장/불러오기/복제/삭제/검색/태그 필터 + JSON 내보내기·가져오기(백업/기기 이동)

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

## 기술 스택

Vite · React 18 · TypeScript · Tailwind CSS v3 · Vitest

계산 로직은 [src/lib/dough.ts](src/lib/dough.ts)에 순수 함수로 분리되어 있고,
[src/lib/dough.test.ts](src/lib/dough.test.ts)에서 왕복 변환·불변식 property test를 포함해 검증합니다.
도메인 용어와 계산 규칙은 [CLAUDE.md](CLAUDE.md)를 참고하세요.
