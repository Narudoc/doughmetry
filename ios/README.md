# Doughmetry iOS (SwiftUI 네이티브)

웹앱(Doughmetry, 저장소 `doughmetry`)의 iPhone·iPad 네이티브 버전. 계산 로직·JSON 스키마는 웹과 완전 호환.

## 구조

- `DoughmetryCore/` — 순수 계산 코어 (SwiftPM 패키지, 플랫폼 무관)
  - `Sources/DoughmetryCore/Dough.swift` — src/lib/dough.ts 이식. **UI에서 직접 수식 계산 금지, 반드시 이 모듈을 거칠 것.**
  - `Sources/DoughmetryCore/Codec.swift` — 레시피 JSON 검증·가져오기·내보내기 (웹 스키마 v2 호환, v1 자동 마이그레이션)
  - `Tests/DoughmetryCoreTests/` — 웹 스펙 케이스 1~5 전체 이식 (Swift Testing, Xcode 필요)
  - `Sources/doughmetry-core-check/` — Xcode 없이 도는 스모크 체크: `swift run doughmetry-core-check`
- `Doughmetry/` — SwiftUI 앱 (iOS 17+, iPhone은 세로 고정 / iPad는 네 방향·Split View, 창은 하나 — [Doughmetry-Info.plist](Doughmetry-Info.plist)의 `UIApplicationSupportsMultipleScenes` false). 최소 iOS 17.0은 iOS 17.5·18.2·27 시뮬레이터(iPhone·iPad) 점검 뒤 그대로 두기로 했다(2026-10) — 옛 OS에서만 나는 증상은 `#unavailable(iOS 26)`/`#available` 가지로 고치고 iOS 26+ 동작은 바꾸지 않는다. 하드웨어 키보드: ⌘1–4 탭 · ⌘F 레시피 검색([DoughmetryApp.swift](Doughmetry/DoughmetryApp.swift) — 26 미만은 메뉴 명령이 받지 못해 뷰 단축키로도 단다), ⌘N·⌘S는 계산기 탭, ⌘S는 변환 탭에서도
- `DoughmetryUITests/` — UI 스모크 테스트 4개(두 언어로 네 탭 · 계산기 입력 → 요약 바 · 저장 → 불러오기 · 텍스트 가져오기는 확인 시트를 거침)와 하드웨어 키보드 숫자 입력 회귀 테스트(`NumberFieldKeyboardUITests`, iPad). DEBUG 빌드 전용 실행 인자 `-uiTestDataDir <경로>`로 빈 저장 폴더에서 시작하고 iCloud와 합치지 않는다. 화면 요소는 접근성 식별자로 찾는다(라벨은 `-appLanguage`에 따라 바뀜)
- `AppStore/` — 스토어 문구 원본([listing.md](AppStore/listing.md)), 출시 절차([submission.md](AppStore/submission.md)), 스크린샷 캡처 스크립트([capture-screenshots.sh](AppStore/capture-screenshots.sh) — 전용 시뮬레이터·언어별 예시 데이터·9:41 상태 바, iPhone 6.9형·iPad 13형 JPEG)
- `Doughmetry.xcodeproj` — Xcode 16 형식 (파일시스템 동기화 그룹 — 파일 추가 시 프로젝트 수정 불필요). Info.plist는 빌드 설정(`INFOPLIST_KEY_*`)으로 생성하고, 빌드 설정으로 못 넣는 키만 동기화 폴더 밖의 `Doughmetry-Info.plist`에 둔다 (폴더 안에 두면 리소스로도 복사돼 빌드가 깨진다)

## 빌드

Xcode 16+ 필요 (현재 Xcode 27.0으로 빌드·검증):

```bash
open ios/Doughmetry.xcodeproj   # 또는 xcodebuild -project ios/Doughmetry.xcodeproj -scheme Doughmetry
```

코어 테스트:

```bash
cd ios/DoughmetryCore && swift test          # 전체 스펙 테스트 (Xcode 필요)
cd ios/DoughmetryCore && swift run doughmetry-core-check  # 스모크 체크 (CLT만으로 가능)
```

`swift test`는 Mac의 Foundation으로 돈다 — 정규식 단어 경계·ISO 8601 파싱처럼 iOS 버전마다 달라지는 동작은 옛 iOS 시뮬레이터에서 확인한다. 패키지의 자동 스킴 중 테스트 동작이 있는 것은 `DoughmetryCore-Package`뿐이다(`DoughmetryCore`는 라이브러리만):

```bash
cd ios/DoughmetryCore && xcodebuild test -scheme DoughmetryCore-Package \
  -destination 'platform=iOS Simulator,OS=17.5,name=iPhone 15'   # 런타임이 없으면: xcodebuild -downloadPlatform iOS -buildVersion 17.5
```

CI([ios.yml](../.github/workflows/ios.yml))의 `oldest-ios`가 ios/ 변경마다 iOS 17.5·18.2 시뮬레이터에서 이 테스트를 돌리고, 수동 실행(workflow_dispatch)에선 UI 스모크 테스트도 같은 런타임에서 돌린다. GitHub 러너 이미지(macos-26)에는 iOS 26.x 런타임뿐이라 실행마다 내려받는다 — 받지 못하면 경고를 남기고 설치된 가장 오래된 런타임으로 돈다(작업 요약에 실제 런타임이 남는다).

UI 스모크 테스트 (공유 스킴 `Doughmetry`):

```bash
xcodebuild test -project ios/Doughmetry.xcodeproj -scheme Doughmetry \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DoughmetryUITests
```

첫 업로드 전에는 iOS 17·18 시뮬레이터와 iPad에서도 돌린다 — 런타임 내려받기와 확인 항목은 [submission.md](AppStore/submission.md) 0-9.

## 저장 · iCloud 동기화

- 로컬: Application Support/levain-calc/`library.json` — `LibraryDocument`(레시피 + 베이킹 로그 + 삭제 묘비). 옛 `recipes.json`(레시피 배열)은 최초 실행 시 자동 이전.
- iCloud: 같은 문서를 iCloud Documents 컨테이너(`Documents/library.json`)에 두고 [CloudSync.swift](Doughmetry/CloudSync.swift)가 NSFileCoordinator/NSMetadataQuery로 읽고 쓴다. 병합 규칙은 코어 [LibrarySync.swift](DoughmetryCore/Sources/DoughmetryCore/LibrarySync.swift) — `updatedAt` 최신 우선, 묘비로 삭제 전파, 삭제 뒤 편집은 되살림 (테스트 `LibrarySyncTests`).
  - 두 기기가 따로 쓴 판(NSFileVersion 충돌)은 문서와 한 번의 조정 읽기로 함께 읽어(`LibrarySync.conflictDocuments`) 로컬·현재 판과 **`LibrarySync.merge(_:)` 한 번으로** 합친다 — 둘씩 차례로 합치면 중간에 지워졌다 되살아난 레시피의 로그를 잃는다. 병합 결과를 원격에 쓴 **뒤에만** 읽을 때 들고 온 판 객체를 정리한다(URL은 식별자로 쓰지 않는다). 읽을 수 없는 판·새 버전 판·항목이나 묘비가 버려지는 판은 정리하지 않는다.
  - 메타데이터에는 있는데 아직 내려오지 않은 문서는 "원격 없음"이 아니다 — `readRemote`는 nil 대신 `notDownloaded`를 던져 동기화를 미룬다 (nil로 보면 로컬 문서로 iCloud의 유일한 사본을 덮어쓴다).
  - 원격 변경 감지(NSMetadataQuery 갱신)는 원격 문서의 내용 변경 시각·내려받기 상태·충돌 여부가 바뀔 때만 동기화를 일으킨다 — 업로드 진행률마다 전체 동기화를 다시 돌리지 않도록. 충돌 판이 남아 있는 동안과 동기화가 실패한 뒤에는 거르지 않는다.
  - 조정 읽기·쓰기는 비동기(`coordinate(with:queue:)`)로 하고 제한 시간(읽기 60초·쓰기 30초)이 지나면 조정자를 취소한다 — 오프라인에서 내려받기를 끝없이 기다리며 '동기화 중'에 멈추지 않도록. 상태는 원인별로 알린다: 내려받는 중 / 내려받기 실패(메타데이터의 DownloadingError) / 연결 안 됨(제한 시간). 정리하지 못하고 보관 중인 충돌 판 수는 설정의 iCloud 항목에 보인다.
- entitlement가 없거나 iCloud 미로그인이면 컨테이너 URL이 nil → 자동으로 로컬 전용 동작.
- 진단 로그: 동기화·저장 실패와 AI 가져오기 결과는 통합 로그에 남는다([Diagnostics.swift](Doughmetry/Diagnostics.swift)의 `Log`). 기기를 Mac에 연결하고 Console.app에서 `subsystem:com.narudoc.doughmetry`로 거르면 `sync`·`storage`·`import`(AI 초안 시간 초과·기각 사유) 카테고리가 보인다(사용자에게서 받을 때는 sysdiagnose). 개수와 오류 도메인·코드만 남고 레시피 내용은 남지 않는다.
- **iCloud (설정 완료)**: Signing & Capabilities에 iCloud Documents가 켜져 있고(2026-09-06, 팀 G46DT9WHWV), 컨테이너는 개명에 맞춰 `iCloud.com.narudoc.doughmetry`로 바뀌었다. 새 App ID·컨테이너 모두 포털 등록 완료 — 2026-09-11 08:28 발급된 Xcode 관리 프로파일 `iOS Team Provisioning Profile: com.narudoc.doughmetry`의 엔타이틀먼트에 이 컨테이너가 들어 있다. 다른 Mac에서 열 때: 같은 팀(G46DT9WHWV)이면 컨테이너가 이미 포털에 있으므로 `Signing & Capabilities > iCloud > Containers`의 새로고침(원형 화살표)으로 목록을 다시 읽으면 된다. 프로젝트가 열려 있고 자동 서명이 켜져 있으면 번들 ID·[Doughmetry.entitlements](Doughmetry/Doughmetry.entitlements) 변경만으로도 Xcode가 App ID와 컨테이너를 포털에 만들고 프로파일을 발급한다(2026-09-11 08:28이 그 경우 — 빌드 없이, `+` 없이; DerivedData의 `Logs/Update Signing` 로그에 `POST /v1/cloudContainers`가 남아 있다). iCloud 컨테이너는 포털에서 지울 수 없으므로 같은 팀에서 `+`를 쓸 일은 없다 — 목록이 비거나 빨간색이면 새로고침, 그래도 남으면 `Automatically manage signing`을 껐다 켠다. **다른 팀**에서는 이 프로젝트를 그대로 서명할 수 없다: App ID `com.narudoc.doughmetry`와 컨테이너 ID `iCloud.com.narudoc.doughmetry`는 Apple 전체에서 유일하고 이미 G46DT9WHWV 소유라 거부된다 — 번들 ID와 entitlements의 컨테이너 ID를 둘 다 그 팀 것으로 바꿔야 한다. 시뮬레이터 빌드는 프로비저닝 프로파일이 필요 없고 ad-hoc(`-`) 서명만 하므로 등록을 트리거하지 않는다.

## 도구 탭 (Phase 2)

- **르방 빌드** — `solveLevainBuild` ([Tools.swift](DoughmetryCore/Sources/DoughmetryCore/Tools.swift)): 목표 르방 L·수분율 h와 종 C·수분율 hc로 첨가 밀가루·물 역산. 종이 과다하면 최대 허용량 제시.
- **물 온도(DDT)** — `solveWaterTemperature`: 물 = DDT × N − (밀가루 + 실온 + [르방] + 마찰계수), N = 3 또는 4. °F는 화면의 입력·표시만 바꾸고 계산·저장은 °C.
- **타임라인** — `scheduleTimeline` ([Timeline.swift](DoughmetryCore/Sources/DoughmetryCore/Timeline.swift)): 시작/완성 시각 기준 단계별 시각. 앱은 [TimelineView.swift](Doughmetry/TimelineView.swift)에서 단계 편집·로컬 알림(UNUserNotificationCenter) 예약. 계획은 UserDefaults(로컬)에 저장.
- 세 도구 모두 iOS 전용 (웹 미포팅) — 웹에 옮길 때는 Tools.swift/Timeline.swift 규칙을 그대로 이식할 것.

## 웹앱과의 호환

- 레시피 JSON: 레시피 탭 → 내보내기/가져오기가 웹의 내보내기 파일과 양방향 호환
- 저장 위치: Application Support/levain-calc/ — `library.json`(레시피 + 베이킹 로그 + 삭제 묘비)과 `draft.json`(계산기 작성 중 상태). 옛 `recipes.json`은 최초 실행 시 `library.json`으로 이전된 뒤 쓰이지 않는다. (폴더 이름 `levain-calc`는 호환성 때문에 그대로)
- 색 토큰·용어·계산 규칙은 루트 CLAUDE.md의 원칙을 그대로 따른다
