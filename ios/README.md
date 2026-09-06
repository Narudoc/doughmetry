# levain-calc iOS (SwiftUI 네이티브)

웹앱(levain-calc)의 iPhone 네이티브 버전. 계산 로직·JSON 스키마는 웹과 완전 호환.

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
- **iCloud 켜기 (개발자 프로그램 승인 후 1회)**: Xcode → TARGETS LevainCalc → Signing & Capabilities → + iCloud → iCloud Documents 체크 → 컨테이너 `iCloud.com.narudoc.levaincalc`. 준비된 [LevainCalc.entitlements](LevainCalc/LevainCalc.entitlements)를 그대로 쓰면 된다.

## 도구 탭 (Phase 2)

- **르방 빌드** — `solveLevainBuild` ([Tools.swift](LevainCore/Sources/LevainCore/Tools.swift)): 목표 르방 L·수분율 h와 종 C·수분율 hc로 첨가 밀가루·물 역산. 종이 과다하면 최대 허용량 제시.
- **물 온도(DDT)** — `solveWaterTemperature`: 물 = DDT × N − (밀가루 + 실온 + [르방] + 마찰계수), N = 3 또는 4.
- **타임라인** — `scheduleTimeline` ([Timeline.swift](LevainCore/Sources/LevainCore/Timeline.swift)): 시작/완성 시각 기준 단계별 시각. 앱은 [TimelineView.swift](LevainCalc/TimelineView.swift)에서 단계 편집·로컬 알림(UNUserNotificationCenter) 예약. 계획은 UserDefaults(로컬)에 저장.
- 세 도구 모두 iOS 전용 (웹 미포팅) — 웹에 옮길 때는 Tools.swift/Timeline.swift 규칙을 그대로 이식할 것.

## 웹앱과의 호환

- 레시피 JSON: 레시피 탭 → 내보내기/가져오기가 웹의 내보내기 파일과 양방향 호환
- 저장 위치: Application Support/levain-calc/*.json (recipes / draft)
- 색 토큰·용어·계산 규칙은 루트 CLAUDE.md의 원칙을 그대로 따른다
