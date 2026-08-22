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

## 웹앱과의 호환

- 레시피 JSON: 레시피 탭 → 내보내기/가져오기가 웹의 내보내기 파일과 양방향 호환
- 저장 위치: Application Support/levain-calc/*.json (recipes / draft)
- 색 토큰·용어·계산 규칙은 루트 CLAUDE.md의 원칙을 그대로 따른다
