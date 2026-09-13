# Doughmetry (도우메트리)

사워도우(팽 오 르방) 레시피 계산기 + 르방 변환기. 브랜드명 Doughmetry / 도우메트리 (2026-09-11 개명; 저장소 `doughmetry`, iOS 번들 ID `com.narudoc.doughmetry`). **호환성 때문에 바꾸지 않은 내부 식별자**: localStorage 키·내보내기 JSON의 `app: "levain-calc"`·iOS Application Support/levain-calc 폴더·Xcode 타깃 `LevainCalc`·패키지 `LevainCore` — 이름을 새로 붙이지 말 것. Vite + React 18 + TypeScript + Tailwind v3 + Vitest, GitHub Pages 정적 배포 (백엔드 없음).

## 명령어

```bash
npm run dev      # 개발 서버 (base 때문에 /doughmetry/ 경로)
npm test         # Vitest 유닛 테스트
npm run build    # tsc --noEmit && vite build
```

## 도메인 용어

| 용어 | 기호 | 뜻 |
|---|---|---|
| 르방 리퀴드 (levain liquide) | — | 수분율 100% 르방 (밀가루 1 : 물 1) |
| 르방 뒤흐 (levain dur) | — | 수분율 50% 르방 (밀가루 1 : 물 0.5) |
| 르방 질량 | `L` | 완성된 르방의 총 무게(g) |
| 르방 수분율 | `h` | 소수 (1.0 = 100%). 사용자가 직접 수정 가능 |
| 총 밀가루 | `F_total` | 첨가 밀가루 + 르방 속 밀가루 |
| 총 물 | `W_total` | 첨가 물 + 르방 속 물 |
| 총 수분율 | `H` | W_total / F_total (hydratation totale) |
| PFF | — | prefermented flour, 르방 속 밀가루 / 총 밀가루 |

## 계산 규칙 (절대 원칙)

- **수분율·소금·PFF·이스트%는 전부 총 밀가루(`F_total`) 기준.** 첨가 밀가루 기준으로 계산하지 말 것 — 프랑스식 표기법의 기본이며 르방 변환 결과가 달라진다.
- 르방 분해: `F_lev = L / (1 + h)`, `W_lev = L − F_lev`
- **총 물 `W_total` = 본반죽 물(water) + 바시나주(bassinage) + `W_lev` + 액체 수분(Σ grams × waterRatio).**
- 액체 재료(liquids)는 `waterRatio`(소수)만큼 수분으로 계산. 프리셋: 우유 0.88, 계란(전란) 0.76 — USDA FoodData Central per 100g 기준 (`LIQUID_PRESETS`). 지방 함량은 반영하지 않음.
- 이스트: `IDY = 생이스트 × 0.4` (`IDY_FACTOR`, 사용자 지정 비율). `yeast.grams`는 선택한 타입 기준 실제 투입량. 무게·%에만 반영, 수분율에는 미반영.
- 내부 계산은 full precision, 반올림은 표시 계층([src/lib/format.ts](src/lib/format.ts))에서만 한다 (0.1g/1g 설정).
- 르방 변환(질량 고정): `ΔF = L/(1+h_new) − L/(1+h_old)`를 첨가 밀가루에서 빼고 **본반죽 물**에 더한다. 바시나주·액체·이스트는 고정. → 총 밀가루·총 물·총 수분율·총 반죽 무게 보존, PFF는 변함. 물 쪽 변환 한도는 조정 가능 풀(본반죽 물 + `W_lev`) 기준.
- 르방 변환(PFF 고정): `F_lev` 고정, `L_new = F_lev × (1+h_new)`, 본반죽 물이 보정. → 르방 질량과 본반죽 물만 변하고 나머지 지표는 보존.
- 기타 재료(extras)는 무게에만 합산하고 수분 계산에서 제외 — 수분이 있는 재료는 liquids로.
- 르방에 쓴 밀가루 종류(`levain.flourName`)는 표시용.
- 모드 B(목표 역산)는 밀가루·물·소금·르방만 역산한다. 바시나주·액체·이스트는 모드 A 전용.

## 구조

- [src/lib/dough.ts](src/lib/dough.ts) — 순수 계산 함수 전부. UI에서 직접 수식 계산 금지, 반드시 이 모듈을 거칠 것.
- [src/lib/dough.test.ts](src/lib/dough.test.ts) — 스펙 케이스 1~5 (기본 계산·변환·왕복·property·경계). 계산 로직 수정 시 반드시 통과 확인.
- [src/lib/storage.ts](src/lib/storage.ts) — localStorage CRUD + JSON 스키마 검증. 키: `levain-calc:recipes:v1`, `levain-calc:draft:v1`, `levain-calc:settings:v1` (키 이름은 그대로 유지). 현재 `schemaVersion: 2` — v1 레시피는 로드/가져오기 시 자동 마이그레이션(bassinage 0, liquids [], yeast 0). 스키마가 바뀌면 버전을 올리고 마이그레이션을 추가할 것.
- [src/state.ts](src/state.ts) — 계산기 상태(CalcState)와 레시피 ↔ 배합 변환 헬퍼.
- [src/lib/recipeParser.ts](src/lib/recipeParser.ts) — 레시피 텍스트 → 배합 규칙 기반 파서. **iOS [RecipeTextParser.swift](ios/LevainCore/Sources/LevainCore/RecipeTextParser.swift)의 이식본 — 파서 규칙이 바뀌면 두 곳을 함께 고치고 양쪽 테스트([recipeParser.test.ts](src/lib/recipeParser.test.ts) ↔ RecipeTextParserTests.swift)를 동일하게 유지할 것.**
- [src/lib/ocr.ts](src/lib/ocr.ts) — 사진 OCR. tesseract.js를 **사용 시점에만 동적 import** (초기 번들에 포함 금지). 언어 데이터(kor+eng+fra, iOS Vision과 동일)는 CDN에서 지연 로드. iOS는 Vision + Apple Intelligence를 쓰지만 웹은 OCR + 규칙 파서만. 파서의 정규식은 Swift(ICU) 의미에 맞춰 유니코드 단어 경계(lookaround + u 플래그)를 쓴다 — JS `\b`(ASCII)를 쓰지 말 것.
- AI 가져오기 흐름(저장된 레시피 탭): 사진/텍스트 → `cleanForParsing` → `parseRecipeText` → 확인 다이얼로그([ImportReviewDialog](src/components/recipes/ImportReviewDialog.tsx), 수정 가능) → 저장. 확인 없이 바로 저장하지 말 것.
- 탭 전환은 hash 기반 (`#calc` / `#convert` / `#recipes`), 라우팅 라이브러리 없음.

## 컨벤션

- 한국어 UI + 프랑스어 원어 병기 (이탤릭): 르방 리퀴드 *levain liquide*, 총 수분율 *hydratation totale*.
- 숫자 표시는 `tabular-nums`, 입력은 `inputMode="decimal"`. 터치 타겟 최소 44px(작은 버튼 36px).
- 색 토큰(tailwind.config.ts): `paper #F5F2EA` 배경 / `ink #22271F` 본문 / `bottle #1E4034` 구조색 / `brass #9A6B32` **계산 결과값 전용** / `line #D9D3C4` 괘선 / `danger #9E3B2F` 오류.
- 폰트: 본문·숫자 Pretendard Variable, 디스플레이 Archivo Variable (제목·표 캡션에만).
- 인쇄는 `.print-only` / `.no-print` 클래스로 제어 — 계산기 탭에서 A4 한 장 fiche technique 출력.
- **% 표기 기준 설정(`Settings.pctBasis`)은 표시 전용** — `uiPct`/`rebasePct`([src/lib/format.ts](src/lib/format.ts))로 분모만 바꾼다. 계산 코어와 총 수분율·PFF는 항상 총 밀가루 기준 (iOS의 PctBasis와 동일 규칙).
- GitHub Pages `base: '/doughmetry/'` — 저장소명 변경 시 vite.config.ts 수정 (README 참고).

## iOS 네이티브 앱 (ios/)

- SwiftUI 네이티브 버전 — [ios/README.md](ios/README.md) 참고. iOS 17+, iPhone 전용.
- 계산 코어는 [ios/LevainCore/Sources/LevainCore/Dough.swift](ios/LevainCore/Sources/LevainCore/Dough.swift) — dough.ts의 이식본. **웹 계산 규칙이 바뀌면 두 곳을 함께 고치고 양쪽 테스트를 통과시킬 것.**
- 레시피 JSON 스키마는 웹과 완전 호환 (내보내기/가져오기 양방향). 스키마 변경 시 Codec.swift의 검증·마이그레이션도 함께.
- 코어 검증: `cd ios/LevainCore && swift test` (Xcode 필요) 또는 `swift run levain-core-check` (CLT만으로 가능).
- 저장소는 단일 `library.json`(`LibraryDocument`: recipes + logs(베이킹 로그) + deleted(묘비)). iCloud 동기화 병합은 [LibrarySync.swift](ios/LevainCore/Sources/LevainCore/LibrarySync.swift) — **모든 변이는 `updatedAt`을 갱신하고 삭제는 묘비를 남길 것** (안 그러면 다른 기기에서 되살아나거나 편집이 밀린다). 베이킹 로그는 iOS 전용 기능 (웹 미포팅).

## iOS 전용 기능 (웹 미포팅 — 웹에 옮길 때 iOS 코어 규칙을 그대로 이식)

- **베이킹 로그** (`BakeLog`, library.json의 `logs`) — 레시피별 날짜·별점·메모
- **르방 빌드 계산기** — [Tools.swift](ios/LevainCore/Sources/LevainCore/Tools.swift) `solveLevainBuild`: 종 20g + 밀가루 90g + 물 90g → 르방 200g(100%)
- **물 온도 계산기** — `solveWaterTemperature`: 물 = DDT × N − (밀가루 + 실온 + [르방] + 마찰계수)
- **타임라인 스케줄러** — [Timeline.swift](ios/LevainCore/Sources/LevainCore/Timeline.swift) + 로컬 알림
- **iCloud 동기화** — library.json 병합 (LibrarySync)

## 나중에 붙일 기능

- 모드 B 역산에 바시나주·액체·이스트 반영
- 베이킹 로그 사진 첨부, 타임라인 Live Activity/위젯
