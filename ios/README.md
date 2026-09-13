# Doughmetry iOS (SwiftUI 네이티브)

웹앱(Doughmetry, 저장소 `doughmetry`)의 iPhone 네이티브 버전. 계산 로직·JSON 스키마는 웹과 완전 호환.

## 구조

- `LevainCore/` — 순수 계산 코어 (SwiftPM 패키지, 플랫폼 무관)
  - `Sources/LevainCore/Dough.swift` — src/lib/dough.ts 이식. **UI에서 직접 수식 계산 금지, 반드시 이 모듈을 거칠 것.**
  - `Sources/LevainCore/Codec.swift` — 레시피 JSON 검증·가져오기·내보내기 (웹 스키마 v2 호환, v1 자동 마이그레이션)
  - `Tests/LevainCoreTests/` — 웹 스펙 케이스 1~5 전체 이식 (Swift Testing, Xcode 필요)
  - `Sources/levain-core-check/` — Xcode 없이 도는 스모크 체크: `swift run levain-core-check`
- `LevainCalc/` — SwiftUI 앱 (iOS 17+, 세로 모드, iPhone 전용)
- `LevainCalc.xcodeproj` — Xcode 16 형식 (파일시스템 동기화 그룹 — 파일 추가 시 프로젝트 수정 불필요)

## 빌드

Xcode 16+ 필요:

```bash
open ios/LevainCalc.xcodeproj   # 또는 xcodebuild -project ios/LevainCalc.xcodeproj -scheme LevainCalc
```

코어 테스트:

```bash
cd ios/LevainCore && swift test          # 전체 스펙 테스트 (Xcode 필요)
cd ios/LevainCore && swift run levain-core-check  # 스모크 체크 (CLT만으로 가능)
```

## 저장 · iCloud 동기화

- 로컬: Application Support/levain-calc/`library.json` — `LibraryDocument`(레시피 + 베이킹 로그 + 삭제 묘비). 옛 `recipes.json`(레시피 배열)은 최초 실행 시 자동 이전.
- iCloud: 같은 문서를 iCloud Documents 컨테이너(`Documents/library.json`)에 두고 [CloudSync.swift](LevainCalc/CloudSync.swift)가 NSFileCoordinator/NSMetadataQuery로 읽고 쓴다. 병합 규칙은 코어 [LibrarySync.swift](LevainCore/Sources/LevainCore/LibrarySync.swift) — `updatedAt` 최신 우선, 묘비로 삭제 전파, 삭제 뒤 편집은 되살림 (테스트 `LibrarySyncTests`).
- entitlement가 없거나 iCloud 미로그인이면 컨테이너 URL이 nil → 자동으로 로컬 전용 동작.
- **iCloud (설정 완료)**: Signing & Capabilities에 iCloud Documents가 켜져 있고(2026-09-06, 팀 G46DT9WHWV), 컨테이너는 개명에 맞춰 `iCloud.com.narudoc.doughmetry`로 바뀌었다. 새 App ID·컨테이너 모두 포털 등록 완료 — 2026-09-11 08:28 발급된 Xcode 관리 프로파일 `iOS Team Provisioning Profile: com.narudoc.doughmetry`의 엔타이틀먼트에 이 컨테이너가 들어 있다. 다른 Mac에서 열 때: 같은 팀(G46DT9WHWV)이면 컨테이너가 이미 포털에 있으므로 `Signing & Capabilities > iCloud > Containers`의 새로고침(원형 화살표)으로 목록을 다시 읽으면 된다. 프로젝트가 열려 있고 자동 서명이 켜져 있으면 번들 ID·[LevainCalc.entitlements](LevainCalc/LevainCalc.entitlements) 변경만으로도 Xcode가 App ID와 컨테이너를 포털에 만들고 프로파일을 발급한다(2026-09-11 08:28이 그 경우 — 빌드 없이, `+` 없이; DerivedData의 `Logs/Update Signing` 로그에 `POST /v1/cloudContainers`가 남아 있다). iCloud 컨테이너는 포털에서 지울 수 없으므로 같은 팀에서 `+`를 쓸 일은 없다 — 목록이 비거나 빨간색이면 새로고침, 그래도 남으면 `Automatically manage signing`을 껐다 켠다. **다른 팀**에서는 이 프로젝트를 그대로 서명할 수 없다: App ID `com.narudoc.doughmetry`와 컨테이너 ID `iCloud.com.narudoc.doughmetry`는 Apple 전체에서 유일하고 이미 G46DT9WHWV 소유라 거부된다 — 번들 ID와 entitlements의 컨테이너 ID를 둘 다 그 팀 것으로 바꿔야 한다. 시뮬레이터 빌드는 프로비저닝 프로파일이 필요 없고 ad-hoc(`-`) 서명만 하므로 등록을 트리거하지 않는다.

## 도구 탭 (Phase 2)

- **르방 빌드** — `solveLevainBuild` ([Tools.swift](LevainCore/Sources/LevainCore/Tools.swift)): 목표 르방 L·수분율 h와 종 C·수분율 hc로 첨가 밀가루·물 역산. 종이 과다하면 최대 허용량 제시.
- **물 온도(DDT)** — `solveWaterTemperature`: 물 = DDT × N − (밀가루 + 실온 + [르방] + 마찰계수), N = 3 또는 4.
- **타임라인** — `scheduleTimeline` ([Timeline.swift](LevainCore/Sources/LevainCore/Timeline.swift)): 시작/완성 시각 기준 단계별 시각. 앱은 [TimelineView.swift](LevainCalc/TimelineView.swift)에서 단계 편집·로컬 알림(UNUserNotificationCenter) 예약. 계획은 UserDefaults(로컬)에 저장.
- 세 도구 모두 iOS 전용 (웹 미포팅) — 웹에 옮길 때는 Tools.swift/Timeline.swift 규칙을 그대로 이식할 것.

## 웹앱과의 호환

- 레시피 JSON: 레시피 탭 → 내보내기/가져오기가 웹의 내보내기 파일과 양방향 호환
- 저장 위치: Application Support/levain-calc/ — `library.json`(레시피 + 베이킹 로그 + 삭제 묘비)과 `draft.json`(계산기 작성 중 상태). 옛 `recipes.json`은 최초 실행 시 `library.json`으로 이전된 뒤 쓰이지 않는다. (폴더 이름 `levain-calc`는 호환성 때문에 그대로)
- 색 토큰·용어·계산 규칙은 루트 CLAUDE.md의 원칙을 그대로 따른다
