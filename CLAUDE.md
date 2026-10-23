# Doughmetry (도우메트리)

사워도우(팽 오 르방) 레시피 계산기 + 르방 변환기. 브랜드명 Doughmetry / 도우메트리 (2026-09-11 개명; 저장소 `doughmetry`, iOS 번들 ID `com.narudoc.doughmetry`). Xcode 프로젝트·타깃·스킴은 `Doughmetry`(UI 테스트 `DoughmetryUITests`), 코어 패키지는 `DoughmetryCore`(2026-10-19 `LevainCalc`·`LevainCore`에서 개명, 출시 전). **사용자 데이터와 이어져 바꾸지 않는 식별자**: localStorage 키(`levain-calc:…`)·내보내기 JSON의 `app: "levain-calc"`·iOS Application Support/levain-calc 폴더·UserDefaults 키 — 이름을 새로 붙이지 말 것. Vite + React 18 + TypeScript + Tailwind v3 + Vitest, GitHub Pages 정적 배포 (백엔드 없음).

## 명령어

```bash
npm run dev      # 개발 서버 (base 때문에 /doughmetry/ 경로)
npm test         # Vitest 유닛 테스트
npm run build    # tsc --noEmit && vite build
```

CI: `.github/workflows/ios.yml`이 ios/ 변경 푸시마다 DoughmetryCore `swift test`·시뮬레이터 앱 빌드·영어 사전(l10n) 검사를 돌리고, `oldest-ios`가 iOS 17.5·18.2 시뮬레이터에서 DoughmetryCore 테스트를 돌린다 (러너 이미지엔 iOS 26 런타임뿐이라 내려받는다 — 실패하면 경고 후 설치된 가장 오래된 런타임으로). UI 스모크 테스트 `DoughmetryUITests`는 workflow_dispatch에서만, 가장 새 런타임과 17.5·18.2에서 (`-collect-test-diagnostics never` — 없으면 실패한 UI 테스트 뒤 진단 수집이 10분 멈춘다). `deploy.yml`은 ios/만 바뀐 푸시를 건너뛴다. 액션은 Node 24 메이저를 쓴다.
영어 사전 검사는 로컬에서도 `python3 ios/scripts/check_l10n.py` (L()/LF() 키, DoughmetryCore가 `localize` 클로저로 받는 예시 레시피·`LiquidPreset` 이름의 en 항목 누락).

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
- 표시 반올림은 JS `toFixed`와 글자 하나까지 같아야 한다 — [Format.swift](ios/DoughmetryCore/Sources/DoughmetryCore/Format.swift)의 `toFixed`가 그 이식본(정확한 .5 동률만 0에서 먼 쪽으로). 한쪽을 바꾸면 FormatTests.swift ↔ format.test.ts를 함께 고칠 것.
- 르방 변환(질량 고정): `ΔF = L/(1+h_new) − L/(1+h_old)`를 첨가 밀가루에서 빼고 **본반죽 물**에 더한다. 바시나주·액체·이스트는 고정. → 총 밀가루·총 물·총 수분율·총 반죽 무게 보존, PFF는 변함. 물 쪽 변환 한도는 조정 가능 풀(본반죽 물 + `W_lev`) 기준.
- 르방 변환(PFF 고정): `F_lev` 고정, `L_new = F_lev × (1+h_new)`, 본반죽 물이 보정. → 르방 질량과 본반죽 물만 변하고 나머지 지표는 보존.
- 기타 재료(extras)는 무게에만 합산하고 수분 계산에서 제외 — 수분이 있는 재료는 liquids로.
- 르방에 쓴 밀가루 종류(`levain.flourName`)는 표시용.
- 모드 B(목표 역산)는 밀가루·물·소금·르방만 역산한다. 바시나주·액체·이스트는 모드 A 전용.
- 배율 조정 `scaleDough`: 모든 그램 필드(밀가루·본반죽 물·바시나주·소금·르방·액체·이스트·기타)를 k배 — 수분율·소금·PFF·이스트 %·모든 재료 %는 보존, 모드 A 전용, k가 유한한 양수가 아니면 그대로 (dough.ts ↔ Dough.swift).

## 구조

- [src/lib/dough.ts](src/lib/dough.ts) — 순수 계산 함수 전부. UI에서 직접 수식 계산 금지, 반드시 이 모듈을 거칠 것.
- [src/lib/dough.test.ts](src/lib/dough.test.ts) — 스펙 케이스 1~5 (기본 계산·변환·왕복·property·경계). 계산 로직 수정 시 반드시 통과 확인.
- [src/lib/storage.ts](src/lib/storage.ts) — localStorage CRUD + JSON 스키마 검증. 키: `levain-calc:recipes:v1`, `levain-calc:draft:v1`, `levain-calc:settings:v1`, `levain-calc:ocr-ready:v1`(사진 인식 데이터를 받아 둔 적 있음 — 첫 내려받기 안내 생략) (키 이름은 그대로 유지). 현재 `schemaVersion: 2` — v1 레시피는 로드/가져오기 시 자동 마이그레이션(bassinage 0, liquids [], yeast 0). 스키마가 바뀌면 버전을 올리고 마이그레이션을 추가할 것.
- [src/state.ts](src/state.ts) — 계산기 상태(CalcState)와 레시피 ↔ 배합 변환 헬퍼.
- [src/lib/recipeParser.ts](src/lib/recipeParser.ts) — 레시피 텍스트 → 배합 규칙 기반 파서. **iOS [RecipeTextParser.swift](ios/DoughmetryCore/Sources/DoughmetryCore/RecipeTextParser.swift)의 이식본 — 파서 규칙이 바뀌면 두 곳을 함께 고치고 양쪽 테스트([recipeParser.test.ts](src/lib/recipeParser.test.ts) ↔ RecipeTextParserTests.swift)를 동일하게 유지할 것.**
- 배합표 공유 텍스트([src/lib/fiche.ts](src/lib/fiche.ts) ↔ [FicheRows.swift](ios/Doughmetry/FicheRows.swift))는 파서가 다시 읽는 형식 — 'fiche technique' 제목 줄 뒤, 첫 물 줄이나 밀가루가 아닌 첫 재료 전의 분류되지 않은 g 줄은 밀가루(이름은 g 앞 두 칸 공백 전까지), 끝에 '· 수분/water NN%'가 붙은 줄은 그 수분 비율의 액체로 읽는다. 형식을 바꾸면 양쪽 왕복 테스트(recipeParser.test.ts ↔ RecipeTextParserTests.swift)를 함께.
- 레시피 불러오기 목록(계산기·변환기 공용, 검색 가능): [src/lib/recipePicker.ts](src/lib/recipePicker.ts) ↔ [RecipePicker.swift](ios/DoughmetryCore/Sources/DoughmetryCore/RecipePicker.swift)가 같은 정렬·검색·묶음 — 검색어(앞뒤 공백 제거)가 비면 `recentCount`(5)개 이하는 '저장된 레시피'(최근 수정순) 하나, 넘으면 '최근' 5개 + '전체'(이름순, 최근 것도 다시), 검색 중엔 이름이나 태그에 든 것만 '검색 결과'(이름순, 비면 빈 상태). 최근 수정순은 updatedAt → createdAt 내림차순(밀리초 기준, 읽지 못하는 시각은 뒤 — iOS `syncInstant`·웹 `Date.parse`) → id 오름차순, 이름순은 한국어 정렬(한글 다음 로마자)·숫자는 값으로(캉파뉴 2 < 캉파뉴 10)·같으면 최근 수정순, 검색은 대소문자·악센트·전각 무시. 같은 테스트 벡터(RecipePickerTests.swift ↔ recipePicker.test.ts) — 한쪽을 바꾸면 함께 (Foundation 정렬·검색은 OS마다 다를 수 있어 iOS 17.5에서도 돌린다). 계산기는 저장하지 않은 입력이 있으면 고른 뒤 확인을 묻고, 변환기는 맨 위에 '계산기 배합 가져오기'를 둔다 (iOS 변환기는 오른쪽 위 더 보기 메뉴에도 — '계산기로 보내기'·'배합표 공유'와 함께, 화면 본문에는 두지 않는다).
- 변환기 → 계산기·저장 (iOS·웹 같음): 변환기로 보낼 때 분할 개수·태그를 함께 넘기고(메모는 넘기지 않음), 변환 결과 저장 창에 태그·'분할 N개 — 개당 X g'를 미리 채운다. '계산기로 보내기'는 모드 A·제안 이름·원래 레시피와 연결 없이(recipeId 없음 — 저장해도 원본을 덮어쓰지 않게) 넣고, 아직 어디에도 저장되지 않은 입력으로 친다(iOS calcBaseline·웹 savedSnapshot을 옮기지 않음). 계산기 이름 아래 상태 줄(예시 배합 / 새 배합 / 저장된 레시피 · 변경 없음 / 수정됨 — 저장 안 됨)과 저장 창의 '덮어쓰기'·'새 레시피로 저장' 두 버튼은 같은 상태에서 나온다 — 모드 B는 덮어쓰지 않는다.
- [src/lib/ocr.ts](src/lib/ocr.ts) — 사진 OCR. tesseract.js를 **사용 시점에만 동적 import** (초기 번들에 포함 금지). 언어 데이터(kor+eng+fra, iOS Vision과 동일)는 CDN에서 지연 로드. iOS는 Vision + Apple Intelligence를 쓰지만 웹은 OCR + 규칙 파서만. 파서의 정규식은 Swift(ICU) 의미에 맞춰 유니코드 단어 경계(lookaround + u 플래그)를 쓴다 — JS `\b`(ASCII)를 쓰지 말 것.
- AI 가져오기 흐름(저장된 레시피 탭): 사진/텍스트 → `cleanForParsing` → `parseRecipeText` → 확인 다이얼로그([ImportReviewDialog](src/components/recipes/ImportReviewDialog.tsx), 수정 가능) → 저장. 확인 없이 바로 저장하지 말 것. iOS는 Apple Intelligence 초안을 규칙 결과와 교차 검증해([ImportReconcile.swift](ios/DoughmetryCore/Sources/DoughmetryCore/ImportReconcile.swift)) 어긋나면 규칙 결과를 쓴다.
- 탭 전환은 hash 기반 (`#calc` / `#convert` / `#recipes`), 라우팅 라이브러리 없음.

## 컨벤션

- 한국어 UI + 프랑스어 원어 병기 (이탤릭): 르방 리퀴드 *levain liquide*, 총 수분율 *hydratation totale*.
- 숫자 표시는 `tabular-nums`, 입력은 `inputMode="decimal"`. 터치 타겟 최소 44px(작은 버튼 36px).
- 색 토큰(tailwind.config.ts): `paper #F5F2EA` 배경 / `ink #22271F` 본문 / `bottle #1E4034` 구조색 / `brass #8A5C26` **계산 결과값 전용** / `line #D9D3C4` 괘선 / `danger #9E3B2F` 오류.
- 폰트: 본문·숫자 Pretendard Variable, 디스플레이 Archivo Variable (제목·표 캡션에만).
- 인쇄는 `.print-only` / `.no-print` 클래스로 제어 — 계산기 탭에서 A4 한 장 fiche technique 출력.
- 보조 글자는 ink/70·bottle/80 이상 — ink/40~60은 비활성(disabled:)·장식(aria-hidden)에만 ([src/contrast.test.ts](src/contrast.test.ts)가 검사).
- **% 표기 기준 설정(`Settings.pctBasis`)은 표시 전용** — `uiPct`/`rebasePct`([src/lib/format.ts](src/lib/format.ts))로 분모만 바꾼다. 계산 코어와 총 수분율·PFF는 항상 총 밀가루 기준 (iOS는 DoughmetryCore [Format.swift](ios/DoughmetryCore/Sources/DoughmetryCore/Format.swift)의 `PctBasis`·`uiPct`·`rebasePct`·`uiLevainPct` — 같은 규칙, 양쪽 테스트 벡터도 같다).
- GitHub Pages `base: '/doughmetry/'` — 저장소명 변경 시 vite.config.ts 수정 (README 참고).
- 오프라인(PWA): 손으로 쓴 [public/sw.js](public/sw.js) — 동작을 바꾸면 캐시 이름의 버전을 올릴 것. tesseract·jsDelivr는 캐시하지 않고, 내비게이션 대체는 앱 셸에만 (privacy.html·support.html은 대체하지 않는다).
- [public/privacy.html](public/privacy.html)은 [ios/AppStore/privacy-policy.md](ios/AppStore/privacy-policy.md)와 같은 문구 — 함께 고칠 것.

## iOS 네이티브 앱 (ios/)

- SwiftUI 네이티브 버전 — [ios/README.md](ios/README.md) 참고. iOS 17+, iPhone(세로 고정)·iPad(네 방향) 네이티브. iPad도 창은 하나 — `AppModel`(선택 탭·검색 요청)이 앱에 하나라서 [ios/Doughmetry-Info.plist](ios/Doughmetry-Info.plist)의 `UIApplicationSupportsMultipleScenes`를 false로 둔다 (빌드 설정 `INFOPLIST_KEY_UIApplicationSupportsMultipleScenes=NO`만으로는 생성기가 true를 쓴다. 장면 매니페스트 생성 끄기(`INFOPLIST_KEY_UIApplicationSceneManifest_Generation = NO`)는 기본값과 같아 Xcode 27이 저장할 때 지운다 — 빌드된 Info.plist의 false는 CI(`ios.yml`)가 검사한다). 여러 창을 켜려면 그 상태를 장면별로 옮길 것. 최소 iOS 17.0은 iOS 17.5·18.2·27 시뮬레이터 점검(2026-10) 뒤 유지 — 18로 올리지 않는다.
- 옛 OS 대응: iOS 26 미만에서만 나는 증상은 `#unavailable(iOS 26)`/`#available` 가지로 고치고 iOS 26+ 동작은 그대로 둔다. 새 API는 iOS 17.0에서 쓸 수 있거나 가지 안에 있을 것. Foundation(정규식·날짜 파싱 등) 동작은 OS 버전마다 다르므로 코어 규칙을 바꾸면 옛 런타임에서도 테스트한다: `cd ios/DoughmetryCore && xcodebuild test -scheme DoughmetryCore-Package -destination 'platform=iOS Simulator,OS=17.5,name=iPhone 15'` (자동 스킴 `DoughmetryCore`에는 테스트 동작이 없다).
- iOS UI 규칙 (17·18에서 확인된 차이):
  - 머리글이 있는 Form/List 섹션은 `Section { … } header: { … }.textCase(nil)` — 17·18은 머리글을 대문자로 바꾼다('(g)' → '(G)', 'iCloud' → 'ICLOUD'). 루트·Form이나 머리글의 맨 Text 하나에 단 `.textCase(nil)`은 17.5에서 듣지 않는다.
  - 시트 높이는 `.presentationDetents` 대신 `.adaptiveDetents(…)`([DesignSystem.swift](ios/Doughmetry/DesignSystem.swift)) — 넓은 창(iPad)에선 늘 `.large`. 시트 안의 크기 등급은 iPad에서도 compact라, 띄운 창의 폭은 RootView가 넣는 `\.windowIsRegular`로 판단한다. 긴 내용 시트(가져오기 확인·배합표)는 iPad에서 작은 폼 시트에 갇히지 않게 `.pageSizedSheet()`(18+ `.presentationSizing(.page)`, 17은 `.large` 폼 시트) + `.readableSheetWidth()`(700pt) — iPhone 시트는 그대로. Form/List 시트에 `.presentationSizing(.form.fitted…)`는 쓰지 않는다 (목록은 이상적 높이가 없어 내비게이션 바만 남은 띠가 된다, iOS 27 확인).
  - 날짜·시각 행은 `AXDatePicker`, Form 속 세그먼트 피커는 `.adaptiveSegmented()`([Components.swift](ios/Doughmetry/Components.swift)) — 접근성 글자 크기에서 라벨이 쪼개지거나 13pt로 남지 않게.
  - 화면 켜두기는 `.keepsScreenAwake(while:)`([ResultViews.swift](ios/Doughmetry/ResultViews.swift))로만 — 설정 `keepScreenAwake`·화면에 보임·장면 활성일 때만 켜고, 화면마다 소유권을 세어 한 화면이 다른 화면의 잠금 해제를 끄지 않는다. `isIdleTimerDisabled`를 직접 만지지 말 것(앱 전체 설정). 웹은 `useWakeLock`(계산기 탭에서만, 같은 설정).
  - 앱 전역 설치(DoughmetryApp.init, 26 미만만): `KeyboardAvoidance`(회전 뒤 포커스 칸을 키보드 위로), 확인창(UIAlertController) 색 bottle.
  - 하드웨어 키보드: ⌘1–4 탭·⌘F 레시피 검색은 메뉴 명령([DoughmetryApp.swift](ios/Doughmetry/DoughmetryApp.swift)) — 26 미만은 메뉴 명령이 받지 못해(iPhone 전부, iPad의 ⌘F) 같은 단축키를 뷰에도 단다. ⌘N·⌘S처럼 보이는 탭에만 해당하는 단축키는 그 탭의 뷰에 단다. UI 테스트에서 실행 뒤 첫 ⌘F는 앱에 오지 않는다 — XCUITest의 가상 키보드가 키마다 붙었다 떨어지고 앱은 키보드가 붙을 때 단축키를 등록하므로, 첫 키는 ⌘F를 등록해 둔 SpringBoard가 가져간다(실제 키보드에선 생기지 않음). ⌘F를 검사하는 테스트는 Esc 같은 키를 먼저 보낸다.
- 계산 코어는 [ios/DoughmetryCore/Sources/DoughmetryCore/Dough.swift](ios/DoughmetryCore/Sources/DoughmetryCore/Dough.swift) — dough.ts의 이식본. **웹 계산 규칙이 바뀌면 두 곳을 함께 고치고 양쪽 테스트를 통과시킬 것.**
- 레시피 JSON 스키마는 웹과 완전 호환 (내보내기/가져오기 양방향). 스키마 변경 시 Codec.swift의 검증·마이그레이션도 함께.
- JSON 가져오기 병합 규칙은 웹 `mergeImported`([storage.ts](src/lib/storage.ts)) ↔ iOS `LibrarySync.importable`이 같다: 없는 id는 추가, 같은 id는 가져온 `updatedAt`이 더 새롭고 내용이 다를 때만 교체(로컬 `createdAt` 유지) — 같은 시각이면 로컬 유지, 파일 안에서 겹친 id는 처음 것만 본다. 시각 비교는 웹의 ISO 문법·밀리초 기준 — 한쪽을 바꾸면 양쪽 테스트를 함께.
- 사진 OCR 조각 → 줄 재조립은 [OCRLayout.swift](ios/DoughmetryCore/Sources/DoughmetryCore/OCRLayout.swift) (재료 | 만드는 법 두 단 카드 분리 포함, iOS 전용).
- 앱 안 한/영 언어 선택은 사용자 요구라 유지한다 (iOS 앱별 언어 설정으로 대체하지 말 것). 고른 언어는 루트의 `.environment(\.locale, …)`로 날짜·시간 표시까지 따른다. 사용자에게 보이는 문자열은 전부 `L()`/`LF()`로 쓰고 [Localization.swift](ios/Doughmetry/Localization.swift) 영어 사전에 넣을 것.
- 코어 검증: `cd ios/DoughmetryCore && swift test` (Xcode 필요) 또는 `swift run doughmetry-core-check` (CLT만으로 가능).
- UI 테스트·스크린샷은 DEBUG 전용 실행 인자 `-uiTestDataDir <경로>`로 저장 위치를 격리한다 (iCloud는 켜지 않음).
- 진단 로그는 [Diagnostics.swift](ios/Doughmetry/Diagnostics.swift)의 `Log`(subsystem `com.narudoc.doughmetry`, 카테고리 `sync`·`storage`·`import`)에만 — 파일마다 Logger를 따로 만들지 말 것. 요약은 .notice·실패는 .error, 레시피 이름·메모·JSON은 남기지 않는다(개수·오류 도메인·코드만). 카테고리를 바꾸면 ios/README.md·submission.md의 Console.app 안내도 함께.
- 저장소는 단일 `library.json`(`LibraryDocument`: recipes + logs(베이킹 로그) + deleted(묘비)). iCloud 동기화 병합은 [LibrarySync.swift](ios/DoughmetryCore/Sources/DoughmetryCore/LibrarySync.swift) — **모든 변이는 `updatedAt`을 갱신하고 삭제는 묘비를 남길 것** (안 그러면 다른 기기에서 되살아나거나 편집이 밀린다). 예외는 '예시 레시피 추가' 하나 — 고정 id 예시는 지금 시각이 아니라 옛 기준 시각으로 넣는다(지금 시각이면 다른 기기의 예시 편집·삭제를 병합이 되돌린다). 베이킹 로그는 iOS 전용 기능 (웹 미포팅). Recipe·BakeLog·Tombstone 또는 LibraryDocument(새 최상위 키)에 필드를 추가하면 `LibraryDocument.currentSchemaVersion`을 반드시 올릴 것 — 옛 버전 앱은 자기보다 큰 버전(또는 레시피 schemaVersion)의 iCloud 문서를 보면 합치지도 쓰지도 않는다 (`LibrarySync.decodeReport`). 안 올리면 옛 앱이 모르는 필드를 버린 채 덮어쓴다.

## iOS 전용 기능 (웹 미포팅 — 웹에 옮길 때 iOS 코어 규칙을 그대로 이식)

- **베이킹 로그** (`BakeLog`, library.json의 `logs`) — 레시피별 날짜·별점·메모
- **르방 빌드 계산기** — [Tools.swift](ios/DoughmetryCore/Sources/DoughmetryCore/Tools.swift) `solveLevainBuild`: 종 20g + 밀가루 90g + 물 90g → 르방 200g(100%)
- **물 온도 계산기** — `solveWaterTemperature`: 물 = DDT × N − (밀가루 + 실온 + [르방] + 마찰계수). 마찰계수는 반죽이 실제로 오르는 온도가 아니라 이 ×N 공식에 넣는 값(실제 상승 × N) — 프리셋 손반죽 2·믹서 12 °C(스탠드·버티컬·스파이럴은 출처들이 같은 값으로 다룬다, 2026-10 조사), 옛 '스탠드 믹서 8'은 앱 시작 때 한 번 12로 옮긴다(`ddt.frictionPresets`). '직접'은 `ddt.frictionCustom`으로 기억하고 누르면 입력 칸에 포커스
- **타임라인 스케줄러** — [Timeline.swift](ios/DoughmetryCore/Sources/DoughmetryCore/Timeline.swift) + 로컬 알림. '단계 추가'는 `TimelinePlan.addStage`로 자연 순서(르방 빌드 < 오토리즈 < 믹싱 < 벌크 < 분할 < 벤치 < 성형 < 냉장 발효 < 최종 발효 < 굽기, 사용자 단계는 첫 굽기 바로 앞)에 끼운다 — 있던 단계는 옮기지 않고 굽기 뒤에는 넣지 않는다
- **iCloud 동기화** — library.json 병합 (LibrarySync)

## 나중에 붙일 기능

- 모드 B 역산에 바시나주·액체·이스트 반영
- 베이킹 로그 사진 첨부, 타임라인 Live Activity/위젯
- 르방(스타터) 먹이 주기 단독 트래커 — 지금은 타임라인의 르방 빌드 단계 알림으로만
