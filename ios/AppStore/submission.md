# 도우메트리: 사워도우 계산기 — App Store 첫 출시 가이드 (Xcode 프로젝트 → TestFlight → 심사 제출)

기준: Xcode 27.0 (27A266a) · iOS 27.0 SDK · 2026-10-02 재검토 · 번들 ID `com.narudoc.doughmetry`, iCloud 컨테이너 `iCloud.com.narudoc.doughmetry` · 프로젝트 `ios/Doughmetry.xcodeproj`(타깃·스킴 `Doughmetry`, 코어 패키지 `DoughmetryCore` — 2026-10-19 `LevainCalc`·`LevainCore`에서 개명).

이 문서는 저장소·배포 상태(커밋했는지, 푸시했는지, Pages가 무엇을 내려주는지)를 적어 두지 않는다 — 금방 낡기 때문이다. 그런 상태는 0장 도입부와 3-2의 확인 명령으로 그때그때 본다. 서명·프로비저닝·iCloud 컨테이너 사실은 2026-09-11에 확인한 것이고 본문에 날짜를 붙여 두었다(고정값 표·0-12·1-4·8장·부록 B). 2장의 2026-09-10과 5장 6번의 2026-09-11은 각각 ASC 레코드를 만든 날짜와 번들 ID를 바꾼 날짜다.

이 문서는 키보드 앞에 앉아 **위에서 아래로 그대로 따라 하면 끝나도록** 썼다. Xcode는 영어 UI만 있고, App Store Connect(이하 ASC)는 계정 언어에 따라 한국어/영어로 나오므로 모든 버튼·필드는 `한국어 라벨 (English label)` 형식으로 적었다. 직접 타이핑해야 하는 값은 `코드 스팬`으로 표시했다. 본인만 정할 수 있는 값(전화번호, 공개 문의 이메일, EU DSA 트레이더 여부)은 고정값 표와 1-5에 모아 두었다.

---

## 이 앱의 고정값 (복사용)

| 항목 | 값 |
|---|---|
| 번들 ID | `com.narudoc.doughmetry` (2026-09-11 변경 — ASC 레코드의 번들 ID도 2장에서 바꿔야 함) |
| iCloud 컨테이너 | `iCloud.com.narudoc.doughmetry` (서비스: iCloud Documents만) |
| 개발 팀 | `Kiyoung Ha (G46DT9WHWV)` — Personal Team 아님 |
| Apple 계정 (ASC 로그인·Xcode·TestFlight 초대·심사 연락처) | `juvesoul@icloud.com` — Xcode 관리 프로파일의 팀이 `Kiyoung Ha`("(Personal Team)" 아님)이고 프로파일에 iCloud 컨테이너 엔타이틀먼트가 들어 있으므로(무료 Personal Team은 iCloud 불가) 개발자 프로그램 계정이다. 키체인의 `Apple Development` 인증서도 이 계정으로 발급돼 있다. 빌드 처리 완료·TestFlight 초대·심사 결과 메일이 전부 이 주소로 온다. |
| 버전 / 빌드 | `1.0` / `1` (MARKETING_VERSION / CURRENT_PROJECT_VERSION) |
| 최소 iOS · 기기 | iOS 17.0 — iOS 17.5·18.2·27 시뮬레이터(iPhone·iPad) 점검 뒤 **유지하기로 결정**(2026-10, 0-9 5번). 옛 OS에서만 나는 증상은 `#unavailable(iOS 26)`/`#available` 가지로 고쳤고, CI `oldest-ios`가 17.5·18.2에서 코어 테스트를 돈다. iPhone + iPad 네이티브(`TARGETED_DEVICE_FAMILY = "1,2"`): iPhone은 세로만, iPad는 네 방향 모두(`UISupportedInterfaceOrientations~ipad`). Apple Silicon Mac에서는 iPad 앱으로 실행된다(6-3). **iPad 지원은 한 번 출시하면 이후 업데이트에서 뺄 수 없다.** |
| 스토어 이름 | KR `도우메트리: 사워도우 계산기` (15자) / EN `Doughmetry: Sourdough Calc` (26자) — 2026-09-11 결정. ASC 레코드는 2026-10-28에 이 이름으로 새로 만들었다(2장). App Store 검색·웹에 `Doughmetry`/`도우메트리` 앱·제품 없음 확인(2026-09-11). |
| 홈 화면 이름 (CFBundleDisplayName) | KR `도우메트리` / EN `Doughmetry` — 브랜드명만. 홈 화면 라벨은 한글 약 8자·영문 약 14자를 넘으면 잘리므로(실측) 설명어는 붙이지 않는다. 스토어 제목과 달라도 된다(비슷하면 됨). |
| SKU | `doughmetry` (2026-10-28 레코드를 만들 때 — 바꿀 수 없다) |
| ASC Apple ID | `6827977830` (같은 날 생성 — 출시 뒤 `AppLinks.appStoreID`에 넣는다, 7장) |
| 기본 언어 | 한국어 — 첫 승인 뒤에만 바꿀 수 있다(Apple 'Change the primary language'). 영어 검색은 영어(미국)·영어(영국)·영어(캐나다) 세 현지화로 해결한다([listing.md](listing.md) 현지화 표). |
| 카테고리 | 주 `음식 및 음료 (Food & Drink)` / 부 `유틸리티 (Utilities)` |
| 가격 | 무료 (Tier 0), 전 지역 |
| 연령 등급 | 4+ (설문 전부 "없음") |
| App Privacy | `데이터가 수집되지 않음 (Data Not Collected)` — 6-4에서 "아니요, 이 앱에서는 데이터를 수집하지 않습니다"로 답하고 게시 |
| 개인정보 처리방침 URL | `https://narudoc.github.io/doughmetry/privacy.html` (저장소의 `public/privacy.html` — 3장) |
| 지원 URL | `https://narudoc.github.io/doughmetry/support.html` (저장소의 `public/support.html`, 한/영). 대안 `https://github.com/Narudoc/doughmetry/issues` |
| 마케팅 URL (선택) | 한국어 `https://narudoc.github.io/doughmetry/` (한국어 웹 계산기) / 영어 세 현지화는 `https://narudoc.github.io/doughmetry/support.html`(한/영) 또는 비움 — 웹 계산기는 한국어 화면뿐이다 |
| 공개 문의 이메일 (privacy.html · support.html · 지원 연락처) | 실제로 확인하는 주소 **하나**로 통일. 기본값은 `juvesoul@icloud.com`. 다른 주소(예: `juvesoul@gmail.com`)로 하려면 `cd /Users/narudoc/Claude/Doughmetry && grep -rln 'juvesoul@icloud.com' public ios/AppStore/privacy-policy.md ios/Doughmetry` 로 쓰는 곳을 확인한 뒤 그 파일들만 `sed -i '' 's/juvesoul@icloud.com/새주소/g' <파일들>`로 바꾼다. `submission.md`는 `sed`에 넣지 말 것 — 고정값 표·1장·4~6장의 `juvesoul@icloud.com`은 Apple 계정이라 바뀌면 안 된다. |
| 심사 연락처 (App Review Information) | 이름(First) `Kiyoung` / 성(Last) `Ha` / 전화 `+82 10-____-____` ← **지금 채워 둘 것.** 국제 형식 필수 — `+`와 국가번호 없이 숫자만 넣으면 저장 거부. 이메일은 위 Apple 계정. |
| 저작권 (Copyright) | `2026 Kiyoung Ha` — ASC는 권리 보유자 이름을 요구하므로 개발 팀 이름과 맞춘다. 필명도 쓰려면 `2026 Kiyoung Ha (Narudoc)`. © 기호는 자동. |
| 스크린샷 | iPhone 6.9형 `ios/AppStore/screenshots/{ko,en}/6.9-jpg/01-convert.jpg … 06-fiche.jpg` + 선택 `07-scale.jpg`(있으면 네 폴더 모두에 — 6-5에서 함께 올린다) (1320×2868) + iPad 13형 `ios/AppStore/screenshots/{ko,en}/13-jpg/` 같은 이름 (2064×2752). 0-13의 `capture-screenshots.sh`가 시뮬레이터에서 원본 해상도 JPEG(알파 없음)로 바로 찍는다 — 변환·업스케일 없음. 순서와 화면은 [listing.md](listing.md) 스크린샷 표 |

## 전체 흐름과 예상 소요 시간

| 단계 | 내용 | 소요 |
|---|---|---|
| 0 | 출시 전 확인 (적용된 출시 항목 확인, iOS 17/18·iPad 실행 확인, 스크린샷 캡처) | 2~3시간 |
| 1 | 개발자 계정 점검 (약관·Xcode 계정·EU DSA 트레이더 신고) | 15분 |
| 2 | ASC 앱 레코드 생성 | 10분 |
| 3 | 개인정보 처리방침 페이지 공개 (GitHub Pages) | 20분 + 배포 2분 |
| 4 | Xcode 아카이브 → 업로드 | 10분 + 업로드 1~5분 |
| — | ASC 빌드 처리 (Processing) | 보통 5~30분, 드물게 1~2시간 |
| 5 | TestFlight 설치·실기기 테스트 | 30분~ |
| 6 | 버전 페이지 작성 (스크린샷·설명·연령등급·개인정보) | 40분 |
| 7 | 심사 제출 → 승인 | Apple 공식 "90%가 24시간 내"; 첫 제출은 1~3일 잡을 것 |
| — | 승인 후 "배포용 처리 중" | 최대 24시간 |

---

## 0. 아카이브 전 확인

0-1~0-3과 0-8은 코드에 이미 들어가 있으므로 확인만 한다(아래 "한 번에 확인"). 0-9(iOS 17/18·iPad 실행)와 0-13(스크린샷 — 찍힌 화면이 바뀌었으면 다시 찍기)은 출시마다 직접 한다. 감사에서 반박(불필요로 판정)된 항목(앱 아이콘 알파 채널·iCloud App ID/컨테이너 등록·권한 문구/푸시 엔타이틀먼트)은 0-12에 "조치 불필요"로 적어 두었다.

먼저 저장소 상태를 본다 — 이 문서는 커밋·푸시 상태를 적어 두지 않으므로 이 명령이 기준이다.

```bash
cd /Users/narudoc/Claude/Doughmetry
git status --short                          # 아무것도 없어야 한다 (?? 새 파일 포함)
git fetch -q && git status -sb | head -1    # '## main...origin/main' 뒤에 [ahead …]/[behind …]가 없어야 한다
export PATH="$HOME/.local/node/bin:$PATH" && npx vitest run && npx tsc --noEmit
(cd ios/DoughmetryCore && swift test)               # 코어 테스트 (Xcode 필요)
```

### 0-1. [적용됨 — 확인만] 앱 안 개인정보 처리방침 링크 (심사 지침 5.1.1(i))

설정 화면(도구 탭 → 설정) 맨 아래 섹션에 개인정보 처리방침·지원 링크와 버전이 있다. URL은 `ios/Doughmetry/AppLinks.swift` 한 곳에 모여 있다(`https://narudoc.github.io/doughmetry/privacy.html`, `…/support.html`). 링크 대상 페이지는 3장에서 배포한다 — 5장 TestFlight에서 링크를 눌러 Safari로 열리는지 본다.

### 0-2. [적용됨 — 확인만] PrivacyInfo.xcprivacy

앱이 `UserDefaults`/`@AppStorage`를 쓰므로 Apple의 "required-reason API" 선언이 필요하다(없으면 업로드마다 `ITMS-91053 Missing API declaration`). `ios/Doughmetry/PrivacyInfo.xcprivacy`가 UserDefaults 한 항목(`CA92.1` — 앱 자신만 접근하는 정보를 읽고 쓰기)만 선언한다. 다른 required-reason API(파일 타임스탬프, 부팅 시간, 디스크 용량, 키보드 목록)는 쓰지 않는다. 폴더 동기화 그룹이라 파일만 있으면 .app 루트로 복사된다.

파일이 없다면: Xcode에서 `Doughmetry` 그룹 선택 → `File > New > File from Template…` → `iOS` → `Resource` → `App Privacy` → `Targets: Doughmetry` → `Privacy Accessed API Types`에 `User Defaults` / `CA92.1` 하나, `Privacy Tracking Enabled` = NO.

### 0-3. [적용됨 — 확인만] ITSAppUsesNonExemptEncryption = NO

앱에 네트워킹·자체 암호화 코드가 없고 iCloud Documents는 OS 제공 암호화이므로 `NO`가 맞다. 이 키가 없으면 업로드한 빌드마다 TestFlight에 `규정 준수 누락 (Missing Compliance)`이 떠서 손으로 답해야 한다(4-4). Info.plist는 빌드 때 생성되므로 `project.pbxproj`의 Debug·Release 두 블록에 `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;`로 들어 있다.

### 한 번에 확인 (0-1~0-3, iPad 설정)

```bash
cd /Users/narudoc/Claude/Doughmetry/ios
xcodebuild -project Doughmetry.xcodeproj -scheme Doughmetry -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/check -quiet build
APP=build/check/Build/Products/Release-iphonesimulator/Doughmetry.app
plutil -p "$APP/Info.plist" | grep -E 'ITSAppUsesNonExemptEncryption|MinimumOSVersion'   # false(또는 0) / "17.0"
plutil -extract UIDeviceFamily json -o - "$APP/Info.plist"; echo                         # [1,2]
plutil -extract UISupportedInterfaceOrientations json -o - "$APP/Info.plist"; echo       # 세로 하나
plutil -extract 'UISupportedInterfaceOrientations~ipad' json -o - "$APP/Info.plist"; echo # 네 방향
plutil -extract UIApplicationSceneManifest.UIApplicationSupportsMultipleScenes raw "$APP/Info.plist"   # false
plutil -lint "$APP/PrivacyInfo.xcprivacy"                                                # … OK
grep -rln 'doughmetry/privacy.html' Doughmetry                                           # 파일 하나 이상
```

빌드 경고는 0건이어야 한다(`-quiet` 출력에 `warning:`이 없을 것 — AppIntents 메타데이터 생략 안내는 무해).

### 0-4. [선택] 빌드 번호 전략 하나로 정하기

`project.pbxproj`의 `CURRENT_PROJECT_VERSION = 1`과 `ios/AppStore/archive.sh`의 타임스탬프(`date +%Y%m%d%H%M`, 예 `202609061830`) 두 방식이 공존한다. 둘 다 "빌드 번호 자동 관리"가 켜져 있어 충돌은 자동 보정되지만, 첫 출시는 **GUI(Xcode Organizer)만** 쓰기로 정한다. 규칙:

1. 업로드할 때마다 `TARGETS > Doughmetry > General > Identity > Build` 값을 `1`, `2`, `3`… 으로 손으로 올린다 (`Version`은 `1.0` 유지).
2. Organizer 배포 시 "Manage Version and Build Number"는 절대 끄지 않는다 (기본 흐름에서는 보이지도 않고 자동 적용).
3. 나중에 CLI(`archive.sh`)를 섞어 쓸 때 안전한 순서는 GUI 먼저 → CLI. CLI(타임스탬프) 뒤에 GUI(빌드 1)를 자동 관리 없이 올리면 `ITMS-90061`로 거부된다.

### 0-5. [적용됨] 홈 화면 이름은 브랜드명만

스토어 제목(`도우메트리: 사워도우 계산기` / `Doughmetry: Sourdough Calc`)을 그대로 홈 화면 라벨로 쓰면 잘린다(한글 약 8자·영문 약 14자 한계, 시뮬레이터 실측). 그래서 `ko.lproj/InfoPlist.strings`·`en.lproj/InfoPlist.strings`의 `CFBundleDisplayName`/`CFBundleName`은 `도우메트리` / `Doughmetry`로 두었다. 심사와 무관(스토어 제목과 비슷하면 됨).

### 0-6. [선택] Info.plist에 카테고리 넣기

iOS에서는 카테고리를 ASC에서 고르므로 필수 아님. 넣고 싶으면 `Build Settings` 검색 `Application Category` → `Info.plist Values > Application Category` = `Food & Drink` (pbxproj에 `INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.food-and-drink";`가 Debug/Release 두 블록에 추가됨).

### 0-7. [선택] "Update to recommended settings" 경고 없애기

프로젝트가 `LastUpgradeCheck = 1600`이라 Issue 내비게이터(`⌘5`)에 노란 항목이 뜬다. 아카이브·업로드·심사에 영향 없음. 없애려면 프로젝트 선택 → 메뉴 `Editor > Validate Settings…` → 제안 항목(Enable Recommended Warnings, String Catalog Symbol Generation 등 — Swift 동시성 설정은 건드리지 않음) 확인 → `Perform Changes`. 생기는 pbxproj diff는 따로 커밋.

### 0-8. [적용됨] 스킴 공유

`ios/Doughmetry.xcodeproj/xcshareddata/xcschemes/Doughmetry.xcscheme`이 저장소에 있다 — 스킴 `Doughmetry`가 앱과 UI 스모크 테스트(`DoughmetryUITests`)를 함께 담는다. `xcodebuild -list -project ios/Doughmetry.xcodeproj`의 `Schemes:` 아래에 `Doughmetry`가 보이면 정상. `archive.sh`·Xcode GUI·0-9의 `xcodebuild test`가 이 스킴을 쓴다.

### 0-9. [필수] iOS 17/18·iPad에서 실행 확인 (첫 업로드 전)

최소 iOS 17.0은 iOS 17.5·18.2·27 시뮬레이터 점검(2026-10) 뒤 유지하기로 했다(고정값 표) — 출시마다 이 확인으로 회귀가 없는지 본다. FoundationModels(iOS 26 전용)는 weak link + `#available(iOS 26.0, *)` 가드라 iOS 17/18에서 심볼 오류로 죽지 않게 되어 있다(바인딩 전부 weak-import 확인). 이 Mac에는 iOS 17.5·18.2·26.5·27.0 시뮬레이터 런타임이 있다(2026-10-02, `xcrun simctl list runtimes`).

1. 런타임 내려받기 — 위 런타임이 없을 때만(예: 다른 Mac): `Xcode > Settings… (⌘,) > Components` → `Platform Support` 왼쪽 아래 `+` → `iOS` → `iOS 18.x Simulator`, 이어서 `iOS 17.x Simulator` → `Download`. CLI 대안: `xcodebuild -downloadPlatform iOS -buildVersion 18.2`, `xcodebuild -downloadPlatform iOS -buildVersion 17.5`. Xcode 27이 17.x 런타임을 내려주지 않으면 iOS 17 실기기(5장 TestFlight)로 확인하고, 그것도 없으면 5번대로 최소 버전을 올린다.
2. 시뮬레이터 만들기 — 런타임 ID는 `xcrun simctl list runtimes`로 확인해 맞춘다. 이름에 괄호를 넣지 않는다(`-destination` 이름 매칭).

   ```bash
   xcrun simctl create "iPhone SE iOS17" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation com.apple.CoreSimulator.SimRuntime.iOS-17-5
   xcrun simctl create "iPhone 15 iOS18" com.apple.CoreSimulator.SimDeviceType.iPhone-15 com.apple.CoreSimulator.SimRuntime.iOS-18-2
   xcrun simctl create "iPad Air iOS18" com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M2 com.apple.CoreSimulator.SimRuntime.iOS-18-2
   ```

3. UI 테스트 타깃 전체(2026-10-28 기준 15개)를 기기마다 돌린다 — `DoughmetryUITests` 5(두 언어로 네 탭 / 계산기 입력 → 요약 바 / 저장 → 목록 → 불러오기 / 계산기 불러오기 목록에서 검색해 고르기 / 텍스트 가져오기는 확인 시트를 거침), `CalculatorLinkUITests` 5(계산기 상태 줄과 덮어쓰기·새 레시피 저장 / 모드 B 저장 / 앱 언어를 바꿔도 예시는 저장되지 않은 새 배합 / 변환기 더 보기 메뉴의 계산기 배합 가져오기 / 변환기 → 계산기로 보내기), `ConverterSaveUITests` 1(변환 결과 저장 시 분할·태그 유지), `NumberFieldKeyboardUITests` 4(하드웨어 키보드 숫자·소수점, 칸 위쪽 탭, 쌓인 칸 포커스). 실행마다 빈 임시 저장 폴더(`-uiTestDataDir`)로 시작하고 iCloud와 합치지 않는다.

   ```bash
   cd /Users/narudoc/Claude/Doughmetry
   for d in "iPhone SE iOS17" "iPhone 15 iOS18" "iPad Air iOS18"; do
     xcodebuild test -project ios/Doughmetry.xcodeproj -scheme Doughmetry \
       -destination "platform=iOS Simulator,name=$d" -only-testing:DoughmetryUITests \
       -collect-test-diagnostics never -quiet || echo "실패: $d"
   done
   ```

   `-collect-test-diagnostics never`를 빼면 실패한 실행이 끝난 뒤 진단 수집에서 10분쯤 멈춘다.

   실패 메시지가 `com.narudoc.doughmetry crashed`나 `Lost connection to the application`이면 앱이 아니라 XCTest가 앱 프로세스 안에서 죽은 것일 수 있다 — UI 테스트의 접근성 조회 로그가 너무 많아 logd가 프로세스를 막고(`QUARANTINED DUE TO HIGH LOGGING VOLUME`), 그때 XCTest(`XCTAutomationSupport`)가 스스로 죽는다. 2026-10-28 점검에서 iOS 17.5·18.2의 42번 실행(그때 14개 × 3기기) 중 6번이 이랬고 다시 돌리면 모두 통과했다(iOS 27에선 없음). 아래 명령은 최근 2시간의 크래시 리포트마다 `파일:숫자`를 찍는다 — 파일 이름의 시각(`Doughmetry-2026-10-28-201343.ips` = 20:13:43)으로 실패한 때의 리포트를 찾아, 숫자가 **1 이상**이면 이 경우다: 그 테스트만 `-only-testing:DoughmetryUITests/<클래스>/<테스트>`로 다시 돌린다. 이것을 iOS 17 호환 문제로 보고 5번(최소 버전 올리기)으로 가지 말 것. 숫자가 **0**이면 진짜 앱 크래시다. 실패한 때의 리포트가 없으면 이 경우라고 볼 근거가 없다 — 다시 돌려 또 실패하면 앱 문제로 본다.

   ```bash
   find ~/Library/Logs/DiagnosticReports -name 'Doughmetry-*.ips' -mmin -120 -exec grep -Hc 'QUARANTINED_DUE_TO_HIGH_LOGGING_VOLUME' {} +
   ```

   끝에 찍히는 `.xcresult`를 `open`해 첨부 스크린샷(`ko-tab0` …)에서 탭 바·하단 요약 바가 겹치거나 잘리지 않는지 본다.
4. 손으로 확인 — `iPhone SE iOS17`에서는 전부, `iPhone 15 iOS18`에서는 빠르게: 사진 선택기가 열리고 사진 가져오기가 규칙 파서로 동작해 확인 시트가 뜸 / 숫자 입력 중 키보드 `완료`로 닫힘 / 도구 → 타임라인 알림 권한 요청·예약 / 설정 맨 아래 개인정보 처리방침·지원 링크가 Safari로 열림 / 설정에서 언어 전환.
5. 결정(2026-10): iOS 17.5·18.2 점검에서 나온 문제는 `#unavailable(iOS 26)`/`#available` 가지로 모두 고칠 수 있어 **17.0을 유지한다**. 앞으로 iOS 17에서 고치는 데 품이 드는 문제가 나오면 고치지 말고 최소 버전을 올린다 — `project.pbxproj`의 프로젝트 수준 `IPHONEOS_DEPLOYMENT_TARGET = 17.0;` 두 곳(Debug·Release — 앱과 UI 테스트 타깃이 함께 따른다)을 `18.0`으로 바꾸고, 고정값 표와 [ios/README.md](../README.md)의 "iOS 17"을 함께 고친다. `DoughmetryCore` 패키지의 `.iOS(.v17)`은 그대로 둬도 된다.
6. iPad (iOS 27 시뮬레이터 `iPad Pro 13-inch (M5)`와 `iPad Air 11-inch (M4)`, 15분) — 심사관이 iPad로 열 수 있다:
   - 세로·가로(`⌘←`/`⌘→`)에서 화면이 똑바로 서고 잘리는 곳이 없음. 넓은 화면에서 폼이 읽기 좋은 폭으로 가운데에 모임.
   - 창 크기 조절(창 모드에서 모서리를 최소 크기까지)과 Split View·Slide Over의 좁은 폭(약 320pt)에서 세그먼트·숫자 행이 깨지지 않음.
   - 탭 바·키보드 `완료`·하단 요약 바에 손이 닿음. 하드웨어 키보드(`⌘K`로 화면 키보드 숨김)로 입력해도 요약 바가 맞게 바뀜.
   - 배합표·가져오기 확인·저장 시트를 쓸 수 있고, 새 배합·가져오기·불러오기 확인 대화상자가 누른 버튼에 붙은 팝오버로 뜸.
7. (선택) Apple Silicon Mac: Xcode 실행 대상 `My Mac (Designed for iPad)`로 한 번 실행 — 실행됨 / 설정의 iCloud 상태 / 사진 선택기. 하지 않았으면 6-3 5번에서 Mac 제공을 끌지 정한다.

### 0-10. [적용됨] listing.md 문구 정정 (기록용)

바이너리와 무관한 문서 작업이고 이미 끝나 있다 — 6장에서 `listing.md`를 그대로 붙여 넣으면 된다. 2026-10-02 정정 내용:

1. 확인할 수 없는 표현 삭제 — "다른 앱에는 없는 기능 / No other app does this", "기기 안의 AI가 재료를 인식". 대신 기기 안 글자 인식 + Apple Intelligence 지원 기기(iOS·iPadOS 26 이상)에서 더 정확하다고 쓴다. 앱 안 가져오기 메뉴 이름도 '사진·텍스트에서 가져오기'다.
2. 부제·키워드 — 이름·부제에 이미 있는 낱말과 검색되지 않는 `%`를 빼고, 100바이트 기준으로 다시 썼다. 영어(영국)·영어(캐나다)용 키워드를 따로 둔다(6-1·6-6).
3. 설명 — 첫머리에 무료(구독·광고·계정 없음)·데이터 수집 없음·오프라인, 본문에 액체 재료·바시나주·배율 조정·완성 시각에서 거꾸로 짜는 타임라인·웹 버전. 영어 앱 용어(Liquid/Stiff, Starter)와 맞췄다.
4. 기기 — iPad 네이티브 지원이라 2026-09-11에 '기기 간'으로 고쳤던 동기화 문구를 다시 'iPhone과 iPad 사이'로 썼다.

### 0-11. 커밋

1. 0-13(스크린샷)을 끝내고 여기로 온다. 다시 찍었으면 `cd /Users/narudoc/Claude/Doughmetry && git status --short`에 다시 찍은 `ios/AppStore/screenshots/{ko,en}/{6.9-jpg,13-jpg}/*.jpg`가 ` M`으로 보여야 한다 — 화면이 그대로라 바이트까지 같게 찍힌 장은 나오지 않는다. `??`가 보이면 목록에 없는 파일이다 — `ios/AppStore/preflight.sh shots`로 확인한다.
2. `git add -A` → `git status --short | grep '^??'`(빠뜨린 새 파일)와 `git diff --name-only`(스테이지 안 된 수정)가 둘 다 아무것도 출력하지 않아야 한다. `.gitignore`가 `node_modules/`·`dist/`·`ios/build/`·`xcuserdata`를 막는다.
3. `git commit -m "스토어 스크린샷 다시 찍기 — iPhone 6.9형·iPad 13형, 한/영"`. 푸시는 3-2에서 한다.

### 0-12. 조치 불필요로 확인된 항목 (참고)

- **앱 아이콘 알파 채널**: 소스 PNG는 2026-10-22 아이콘 교체(397b51f) 뒤로 RGB(알파 채널 없음)이고, 컴파일된 `Assets.car`의 AppIcon도 불투명(Opaque)이다(2026-10-28 서명 아카이브로 확인). `ITMS-90717`은 발생하지 않는다. 손대지 말 것. (4-2의 Validate App이 최종 확인.)
- **iCloud App ID/컨테이너 등록 (2026-09-11 재확인)**: 2026-09-06 16:05 프로파일은 옛 번들 ID `com.narudoc.levaincalc`(컨테이너 `iCloud.com.narudoc.levaincalc`) 것이라 개명 후에는 근거가 되지 않는다. 개명 뒤 Xcode가 **2026-09-11 08:28에 새 프로파일 `iOS Team Provisioning Profile: com.narudoc.doughmetry`(UUID `963f121d-931f-4fc1-be5b-24d48474e678`)를 발급**했고, 그 엔타이틀먼트의 `icloud-container-identifiers`·`ubiquity-container-identifiers`·`icloud-container-development-container-identifiers` 3종이 모두 `iCloud.com.narudoc.doughmetry`다. 포털에 없는 컨테이너는 프로파일에 담기지 못하므로 이것이 등록 증거다 → **새 App ID·새 컨테이너 모두 포털 등록 완료**, 1-4는 확인만 하면 된다. `Doughmetry.entitlements`는 이미 새 컨테이너로 고쳐져 있으니 값만 확인하고 `icloud-container-environment`나 `aps-environment`를 **추가하지 말 것**.
- **권한 문구(NSPhotoLibrary/NSCamera)·푸시 엔타이틀먼트**: PhotosPicker(out-of-process)와 로컬 알림만 써서 불필요. 추가하면 오히려 심사 질문거리.
- **스크린샷 알파 채널**: 0-13의 스크립트가 처음부터 JPEG(알파 없음)로 찍으므로 따로 변환하지 않는다.

### 0-13. [필수] 스토어 스크린샷 확인·다시 찍기 (capture-screenshots.sh)

스토어 스크린샷은 `screenshots/{ko,en}/6.9-jpg/`·`{ko,en}/13-jpg/`뿐이다(옛 PNG 세트는 2026-10-05에 지웠고, 지금 세트는 2026-10-28 ec00018에서 그때 UI로 다시 찍었다). 앱 화면이 스크린샷보다 새로우면 2.3(앱과 다른 스크린샷)에 걸린다 — 아래 명령이 보여 주는 커밋과 아직 커밋하지 않은 변경 가운데 **스크린샷에 찍힌 화면**(장면은 [listing.md](listing.md) 스크린샷 표)을 바꾼 것이 있으면, **UI를 바꾸는 작업이 모두 끝난 출시 후보 빌드에서** 다시 찍는다. 찍히지 않는 화면(설정·도구 목록 등)이나 찍힌 장면이 그대로인 수정만 있으면 그대로 둔다.

```bash
cd /Users/narudoc/Claude/Doughmetry
shot=$(git log -1 --format=%h -- ios/AppStore/screenshots); git log -1 --format='%h %ad  마지막으로 찍은 커밋' --date=short $shot
git log --oneline $shot..HEAD -- ios/Doughmetry ios/DoughmetryCore/Sources ios/AppStore/capture-screenshots.sh  # 그 뒤 커밋
git status --short -- ios/Doughmetry ios/DoughmetryCore ios/AppStore/capture-screenshots.sh                    # 커밋하지 않은 변경
```

- 규격: iPhone 6.9형 1320×2868(iPhone 17 Pro Max 시뮬레이터 원본 해상도 — 업스케일 없음)과 iPad 13형 2064×2752(iPad Pro 13-inch (M5)). iPad를 지원하므로 **13형 iPad 스크린샷도 필수**다. 한/영 각 6장(+ 선택 07), JPEG·알파 없음. 6.9형·13형만 있으면 작은 크기는 ASC가 줄여 쓴다.
- 언어는 실행 인자(`-appLanguage`·`-AppleLanguages`·`-AppleLocale`)와 시뮬레이터 시스템 언어로 맞추고, 예시 데이터(레시피 3개·베이킹 로그 4개, 언어별)는 DEBUG 전용 `-uiTestDataDir` 훅으로 넣는다 — 이 훅은 iCloud 동기화도 끈다. 상태 바는 9:41(ko iPad는 기기 시계 — simctl이 '오전 9:41'을 못 넣는다)·충전 표시 없는 배터리 가득·신호 최대. iPad는 멀티태스킹을 '전체 화면 앱'으로 바꿔 찍는다 — 기본값 '윈도우 앱'은 오른쪽 아래 모서리에 창 크기 조절 손잡이가, 상태 바에 앱 이름이 함께 찍힌다.

1. 찍기 (iPhone·iPad × ko·en, 1시간 남짓):

   ```bash
   cd /Users/narudoc/Claude/Doughmetry/ios
   ./AppStore/capture-screenshots.sh              # 전부. 한 세트만: ./AppStore/capture-screenshots.sh iphone en
   ```

   스크립트가 전용 시뮬레이터(`Doughmetry Shots iPhone 6.9`·`Doughmetry Shots iPad 13`)를 만들어 언어마다 지우고 시작한 뒤, 장면마다 무엇을 맞출지 안내한다 — 시뮬레이터 화면을 맞추고 Enter. 찍을 때마다 크기·알파를 검사하고 어긋나면 다시 찍게 한다. 장면 순서·캡션은 [listing.md](listing.md) 스크린샷 표. 다른 도구(UI 테스트 등)로 화면을 움직일 때는 `prepare iphone en` → 화면 맞추기 → `shot iphone en 01-convert`로 한 장씩 찍는다.
2. 한 장씩 열어 본다: 다른 언어 글자(영어 세트에 `편집`·`오전/오후`, 한국어 세트에 영어 메모), `Test` 같은 이름, 키보드·알림 배너, `03-import` 확인 시트 맨 위의 'AI 결과가 규칙 분석과 달라… / The AI result didn't match…' 경고가 없어야 한다. `06-fiche`만 다크 모드다.
3. 폴더에 다른 파일이 섞이지 않았는지 본다 — 올리는 것은 `6.9-jpg/`·`13-jpg/`뿐이다:

   ```bash
   cd /Users/narudoc/Claude/Doughmetry/ios/AppStore/screenshots
   ls ko/6.9-jpg ko/13-jpg en/6.9-jpg en/13-jpg   # 각 6장(+07)
   ../preflight.sh shots                           # 빠진 장·픽셀 크기·알파·목록에 없는 파일 → preflight shots: 통과
   ```

4. 0-11로 돌아가 커밋한다.

---

## 1. 개발자 계정 준비 (약관·인증서·App ID)

### 1-1. Apple 계정과 약관

1. `https://developer.apple.com/account` 에 팀 `G46DT9WHWV`의 Account Holder 계정(`juvesoul@icloud.com`)으로 로그인한다. 2단계 인증(2FA)이 켜져 있어야 하며, 인증 코드를 받을 기기를 옆에 둔다.
2. 페이지 상단에 `The updated Apple Developer Program License Agreement needs to be reviewed` 배너가 있으면 `Review Agreement` → 체크박스 → `I Agree`. (최신 약관은 2026-06-08 WWDC26 직후 판. 등록 시점에 이미 수락했다면 배너가 없다.) 이 배너가 남아 있으면 빌드 업로드와 새 버전 생성이 막힌다.
3. `https://appstoreconnect.apple.com` 에도 로그인해 같은 빨간 배너가 없는지 본다. 있으면 상단 메뉴 `비즈니스 (Business)` → `계약 (Agreements)` 탭에서 대기 중인 항목을 확인한다.
4. **유료 앱 계약 (Paid Apps Agreement)은 필요 없다** — 무료 앱, 인앱 결제 없음. 세금·금융 정보도 입력할 필요 없다.

### 1-2. Xcode 계정

1. Xcode 메뉴 `Xcode > Settings… (⌘,)` → `Accounts` 탭.
2. 왼쪽 목록에 `juvesoul@icloud.com`이 있고, 오른쪽 팀 목록에 `Kiyoung Ha` — 역할 `Account Holder` 또는 `Agent`, **`(Personal Team)` 표시 없음** — 이면 정상.
3. 없으면 왼쪽 아래 `+` → `Apple Account` → 로그인. 프로그램 승인 직후라 팀이 안 보이면 한 번 로그아웃 후 다시 로그인.

### 1-3. 배포 인증서 — 할 일 없음

키체인에는 현재 `Apple Development: juvesoul@icloud.com (6A5ZV7K32M)`만 있고 `Apple Distribution` 인증서는 없다. **정상이다.** 4장에서 "Automatically manage signing"으로 배포하면 Xcode가 클라우드 관리 Apple Distribution 인증서와 App Store 프로비저닝 프로파일을 자동 생성한다(Account Holder는 권한 기본 보유). `Manage Certificates… > + > Apple Distribution`으로 로컬 인증서를 만들지 말 것 — 개인 키 백업 부담만 생긴다.

### 1-4. App ID·iCloud — 확인만

1. **확인만 하면 된다 (2026-09-11 등록 완료).** 번들 ID가 `com.narudoc.doughmetry`로 바뀌자(2026-09-11 08:28:16 스크립트가 `LevainCalc.entitlements`(지금 `Doughmetry.entitlements`)·`project.pbxproj`를 디스크에서 수정, 프로젝트는 Xcode에 열려 있던 상태) Xcode 자동 서명(Update Signing)이 한 번의 실행으로 새 iCloud 컨테이너 `iCloud.com.narudoc.doughmetry`(포털 ID `F5PQF9M9GU`)를 만들고 App ID `XC com narudoc doughmetry`에 iCloud capability로 연결한 뒤 08:28:21에 프로파일을 발급했다 — `Containers`의 `+`를 누른 적도, 기기 빌드도 없었다(DerivedData `Logs/Update Signing/80028A71-….xcactivitylog`에 `POST /v1/cloudContainers` → `POST /v1/bundleIds` → `/v1/profiles` 순서로 기록됨). 2026-09-11 08:28 발급 프로파일 `iOS Team Provisioning Profile: com.narudoc.doughmetry`에 `application-identifier = G46DT9WHWV.com.narudoc.doughmetry`, `icloud-container-identifiers`·`ubiquity-container-identifiers = iCloud.com.narudoc.doughmetry`가 들어 있다. `https://developer.apple.com/account/resources/identifiers/list` 에서 `com.narudoc.doughmetry` 행(Xcode가 붙인 이름 `XC com narudoc doughmetry`, 포털 ID `VH5G2ZZ8QK`)과 `iCloud Containers` 목록의 `iCloud.com.narudoc.doughmetry`를 눈으로 확인만 한다. 옛 `com.narudoc.levaincalc` App ID와 `iCloud.com.narudoc.levaincalc` 컨테이너는 그대로 두어도 무해하다 — 다만 옛 컨테이너의 데이터는 새 앱으로 넘어오지 않는다. 포털(`developer.apple.com`)에서 새로 만들 필요는 없다 — 이미 등록돼 있고, 포털에서 만든 컨테이너도 Xcode가 새로고침으로 읽어 올 뿐 충돌하지 않는다.
2. Xcode: 프로젝트 `Doughmetry` → `TARGETS > Doughmetry` → `Signing & Capabilities` 탭 → 필터 `All`(또는 `Release`):
   - `Signing`: `Automatically manage signing` 체크, `Team` = `Kiyoung Ha (G46DT9WHWV)`, `Bundle Identifier` = `com.narudoc.doughmetry`, 빨간 오류 없음.
   - `iCloud`: `Services`에 `iCloud Documents`만 체크(CloudKit·Key-value storage는 **끄기**), `Containers`에 `iCloud.com.narudoc.doughmetry` 체크, 빨간 `!` 없음.
3. 빨간 `!`가 보이면 `Containers` 아래 원형 화살표(새로고침) 클릭 → 그래도 안 되면 `Automatically manage signing`을 껐다가 다시 켠다. 그래도 안 되면 8장의 `서명 오류 … doesn't include the com.apple.developer.icloud-container-identifiers entitlement` 행 참고.

> **컨테이너가 `Containers` 목록에 빨간색으로 뜨면**: 같은 팀(G46DT9WHWV)이라면 컨테이너는 이미 포털에 있다(2026-09-11 08:28 자동 등록, 위 1번) — 빨간색은 포털 목록을 못 읽어 온 상태이므로 원형 화살표(새로고침)로 다시 읽고, 그래도 남으면 `Automatically manage signing`을 껐다 켜서 자동 서명을 다시 돌린다. 자동 서명은 프로젝트가 열려 있고 계정에 식별자 생성 권한(Account Holder/Admin)이 있으면 `.entitlements`에 적힌 컨테이너 ID를 읽어 App ID와 컨테이너를 **스스로** 포털에 만들고 프로파일을 발급한다 — 번들 ID·capability·entitlements가 바뀌는 순간(09-11 08:28이 그 경우), 실기기·`Any iOS Device (arm64)` 대상 서명 빌드, Archive 때. 시뮬레이터 빌드는 프로비저닝 프로파일이 필요 없고 ad-hoc(`-`) 서명만 하므로 등록·프로파일 발급을 트리거하지 않는다. 목록 아래 `+`는 새 컨테이너 ID를 등록하는 버튼이다(`+` → 시트에 ID 입력, 시트가 `iCloud.` 접두어를 붙인다 → `OK`) — 이 팀에는 이미 있으니 쓸 일이 없다. **다른 팀**에서는 이 프로젝트를 그대로 서명할 수 없다: App ID `com.narudoc.doughmetry`와 컨테이너 ID `iCloud.com.narudoc.doughmetry`는 Apple 전체에서 유일하고 이미 G46DT9WHWV 소유라 자동 서명이든 `+`든 거부된다 — 번들 ID와 entitlements의 컨테이너 ID를 둘 다 그 팀 것으로 바꿔야 하고, 그러면 자동 서명이 새 컨테이너를 만든다(안 되면 `+`). 미등록 상태로 두면 기기 빌드가 `Provisioning profile … doesn't include the com.apple.developer.icloud-container-identifiers entitlement`로 실패한다. 포털(`developer.apple.com > Identifiers > + > iCloud Containers`)에서 먼저 만든 뒤 Xcode의 새로고침으로 읽어 오는 것도 Apple이 문서화한 정식 경로다.

### 1-5. [필수] EU 디지털 서비스법(DSA) 트레이더 상태 신고

Apple은 2024-03-21부터 **새 앱을 제출하려면 EU DSA 트레이더 여부를 먼저 신고**하도록 요구한다(Account Holder·Admin만 가능). 안 해 두면 6-9 제출 단계에서 처음 보는 법적 질문에 막히고, 미신고 앱은 EU 스토어에서 내려간다. 5분이면 끝나니 지금 한다.

1. ASC 상단 `비즈니스 (Business)` → `계약 (Agreements)` 탭 → 아래로 내려 `규정 준수 (Compliance)` 섹션 → `디지털 서비스법 (Digital Services Act)` 옆 `규정 준수 요구 사항 완료 (Complete Compliance Requirements)`.
2. 둘 중 하나를 고른다. **법적 자기 신고라서 본인이 판단해야 하며**, 이 문서는 선택지와 결과만 적는다.
   - `트레이더 계정이 아닙니다 (This is not a trader account)`: 영업·직업 목적이 아닌 개인(취미) 배포에 해당. 무료·광고 없음·인앱 결제 없음인 이 앱의 현재 상태와 맞는 선택지. 추가 입력 없음. 나중에 유료화·광고를 붙이면 트레이더로 바꿔야 한다.
   - `트레이더 계정입니다 (This is a trader account)`: 영업 목적 배포. EU 스토어 앱 페이지에 **주소·전화·이메일이 공개**되고, 2단계 인증과 증빙 서류 확인이 붙는다.
3. `제출 (Submit)` → 상태가 `완료 (Complete)`로 바뀌면 끝. 6-9에서 다시 묻지 않는다.

---

## 2. App Store Connect 앱 등록

첫 업로드 전에 앱 레코드를 만들어 두는 것이 안전하다(Xcode 업로드 중에도 만들 수는 있지만 `No suitable application records were found` 오류를 피하려면 먼저).

0. **[완료 2026-10-28] 새로 만들었다** — 2026-09-10에 `사워도우 브레드 계산기` / `com.narudoc.levaincalc`로 만든 옛 레코드가 10-28에는 앱 목록에 없었다(`앱 없음`, 같은 계정·팀). 그래서 아래 1~5대로 새 레코드를 만들었다: 이름 `도우메트리: 사워도우 계산기`(중복 오류 없음), 기본 언어 한국어, 번들 ID `com.narudoc.doughmetry`(드롭다운에 이것 하나뿐), **SKU `doughmetry`**(옛 레코드가 지워진 것이라면 `levaincalc`는 다시 쓸 수 없어서 — 삭제한 앱의 이름·SKU는 같은 조직에서 재사용 불가, ASC 도움말 "Remove an app"), 전체 액세스. ASC **Apple ID `6827977830`**, iOS 1.0 버전이 `제출 준비 중`. 영어 이름 `Doughmetry: Sourdough Calc`는 6-1에서 넣을 때 중복 검사를 받는다. 번들 ID는 첫 빌드를 올리기 전까지만 바꿀 수 있고 그 뒤 영구 고정된다. 아래 1~5는 다시 만들 일이 생길 때를 위한 절차.
1. `https://appstoreconnect.apple.com` → `앱 (Apps)` 클릭.
2. 왼쪽 위 `+` → `신규 앱 (New App)`.
3. 대화상자 입력:
   - `플랫폼 (Platforms)`: `iOS`만 체크.
   - `이름 (Name)`: `도우메트리: 사워도우 계산기` 입력. (2~30자, App Store 전체에서 고유. 홈 화면 이름 `CFBundleDisplayName`은 `도우메트리`만 — 고정값 표 참고.)
   - `기본 언어 (Primary Language)`: `한국어 (Korean)`.
   - `번들 ID (Bundle ID)`: 드롭다운에서 `com.narudoc.doughmetry`가 붙은 항목(예 `XC com narudoc doughmetry - com.narudoc.doughmetry`) 선택. **`Xcode: Wildcard AppID - *`는 절대 선택하지 말 것.** 목록에 없으면 1-4-1로 돌아가 App ID가 있는지 확인하고 페이지를 새로고침.
   - `SKU`: `doughmetry` (2026-10-28에 쓴 값 — 그 레코드를 지우고 다시 만들면 이것도 다시 쓸 수 없으니 새 값으로).
   - `사용자 액세스 권한 (User Access)`: `전체 액세스 (Full Access)`. 팀에 다른 사용자가 없으면 이 항목이 회색으로 잠겨 있거나 아예 안 보인다 — 그대로 둔다.
4. `생성 (Create)` 클릭. 이름 중복 검사는 이 시점에 일어난다. `The App Name you entered is already being used`가 뜨면 이름만 바꿔 다시 `생성`.
5. 앱 목록에 `도우메트리: 사워도우 계산기`가 `제출 준비 중 (Prepare for Submission)` 상태로 생기면 성공. SKU는 이 시점부터 바꿀 수 없고, 번들 ID는 첫 빌드를 올리기 전까지만 `앱 정보 (App Information) > 일반 정보`에서 바꿀 수 있다(0번 참고) — 첫 빌드 업로드 후에는 영구 고정된다.
6. 영어 이름은 6-1에서 `영어(미국)`·`영어(영국)`·`영어(캐나다)` 현지화를 추가하면서 넣는다.

---

## 3. 개인정보 처리방침·지원 URL 공개

**이 장을 끝내지 않으면 심사에서 5.1.1로 거절된다** (개인정보 처리방침 URL은 필수 입력이고, ASC는 URL 형식만 검사하지만 심사관이 실제로 열어 본다 — 404면 메타데이터 거절). 앱 설정 화면의 링크(0-1)도 같은 주소를 연다.

페이지는 저장소의 `public/privacy.html`·`public/support.html`(한/영)이다. Vite가 `public/`을 그대로 `dist/`로 복사하므로(`base` 무관) main에 푸시하면 GitHub Actions(`deploy.yml`)가 배포한다 → `https://narudoc.github.io/doughmetry/privacy.html`. 배포가 끝났는지는 상태 코드 하나로 판단하지 말고 3-2 5번의 네 줄로 본다.

### 3-1. 페이지 내용 확인 (파일은 이미 있다)

1. `public/privacy.html`과 `ios/AppStore/privacy-policy.md`는 **같은 문구**다 — md는 Pages 배포 전 임시 개인정보 URL(3-2 7번, GitHub 렌더링)로 쓴다. 문구를 고칠 때는 두 파일을 함께 고치고 `최종 갱신 / Last updated` 날짜를 맞춘다. md 본문을 링크 한 줄로 비우지 말 것.
2. 담겨야 할 내용(한/영 모두): 계정 없음 · 데이터는 기기에, iCloud 동기화가 켜져 있으면(**기본 켜짐**) 사용자 본인 iCloud에도 저장 — 동기화가 기본이므로 '기기 안에만'이라고 쓰지 않는다 · 동기화는 앱 안 *도구 탭 → 설정*에서 끄기 · 레시피 가져오기(사진·텍스트 인식)는 기기 안(Apple Vision · Apple Intelligence) · 분석·광고·추적 없음 · 알림은 로컬 · 내보내기·공유는 사용자가 직접 · 보관·삭제 안내 · 웹 버전 문단 · 문의 이메일(고정값 표의 공개 문의 이메일).
3. `public/support.html`: 문의 이메일, GitHub Issues 링크, 웹 버전 링크, 개인정보 처리방침 링크. 지원 URL로 쓰므로 연락처가 반드시 보여야 한다(심사 1.5).

### 3-2. 푸시·배포·확인

1. 남은 변경을 커밋한다: `cd /Users/narudoc/Claude/Doughmetry && git status --short` → `git add -A && git commit -m "…"`.
2. 푸시 전 로컬 확인: `export PATH="$HOME/.local/node/bin:$PATH" && npx vitest run && npm run build && grep -o '/doughmetry/assets/[^"]*' dist/index.html | head -1 && ls dist/privacy.html dist/support.html` — `/doughmetry/assets/…`와 두 파일이 나와야 한다. `vite build`는 작업 트리를 읽으므로, 커밋에 실제로 들어갔는지는 `git status --short`가 비어 있는지로 본다.
3. `git push origin main`.
4. `https://github.com/Narudoc/doughmetry/actions` 에서 `Deploy to GitHub Pages` 실행이 초록색이 될 때까지 기다린다(1~2분). 실패하면 그 실행 로그에서 실패 단계(`npm ci`·vitest·build·deploy)를 본다. 저장소 Settings → Pages의 Source는 `GitHub Actions`여야 한다.
5. 확인 (네 줄 모두 — 앞 두 줄은 정적 페이지, 뒤 두 줄은 사이트 루트가 새 빌드인지):

   ```bash
   curl -sI https://narudoc.github.io/doughmetry/privacy.html | head -1   # HTTP/2 200
   curl -sI https://narudoc.github.io/doughmetry/support.html | head -1   # HTTP/2 200
   curl -s https://narudoc.github.io/doughmetry/ | grep -o '/doughmetry/assets/[^"]*' | head -1
   # → /doughmetry/assets/index-XXXXXXXX.js 가 나와야 한다
   curl -s https://narudoc.github.io/doughmetry/ | grep -o '<title>[^<]*</title>'
   # → <title>도우메트리 · Doughmetry — 사워도우 계산기</title>
   ```

   뒤 두 줄이 비었거나 옛 값이 나오면 배포가 안 됐거나 옛 빌드가 캐시된 것이다 — 4번의 Actions 로그를 보고, 몇 분 뒤 다시 확인한다.
   링크 미리보기·오프라인 파일도 `for f in og.png manifest.webmanifest sw.js; do curl -sI https://narudoc.github.io/doughmetry/$f | head -1; done`로 200인지 본다. 카카오톡 미리보기가 옛 것이면 카카오 개발자 도구의 OG 캐시 초기화로 지운다.
6. Safari에서 **세 URL(privacy.html · support.html · 사이트 루트)**을 열어 앞 두 개는 한국어·영어 본문이, 루트는 계산기 화면이 뜨는지 눈으로 확인. **이 확인 전에는 ASC에 URL을 입력하지 말 것.**
7. 급하게 URL이 먼저 필요하면 `https://github.com/Narudoc/doughmetry/blob/main/ios/AppStore/privacy-policy.md`도 열리지만(GitHub 장식이 붙음), Pages URL로 곧 교체할 것.

---

## 4. Xcode 아카이브 → 업로드

### 4-1. 아카이브

1. `open /Users/narudoc/Claude/Doughmetry/ios/Doughmetry.xcodeproj`.
2. 툴바 스킴이 `Doughmetry`인지 확인. 실행 대상 드롭다운 → `Any iOS Device (arm64)` 선택 (메뉴 `Product > Destination > Any iOS Device`).
3. `TARGETS > Doughmetry > General > Identity`: `Version` = `1.0`, `Build` = `1` 확인 (두 번째 업로드부터는 `Build`를 올린다, 0-4).
4. 저장소·배포 상태 점검 — 저장소와 배포가 출시할 상태인지는 이 스크립트가 기준이다 (작업 트리 깨끗함, HEAD = origin/main, privacy·support 페이지 200, 앱 안 처리방침 링크, PrivacyInfo lint, DoughmetryCore 테스트, 스토어 스크린샷 — 한/영 × iPhone 6.9형·iPad 13형 × 01~06(07은 있으면) 파일·픽셀 크기·알파 없음, 목록에 없는 파일 없음):

   ```bash
   cd /Users/narudoc/Claude/Doughmetry && ios/AppStore/preflight.sh repo   # → preflight repo: 통과
   ```

5. 메뉴 `Product > Archive`. Release 구성으로 빌드된다(수 분). 첫 아카이브에서 macOS 키체인/Apple 계정 인증 창이 뜨면 허용.
6. 끝나면 Organizer가 자동으로 열린다 (안 열리면 `Window > Organizer`, `⌥⇧⌘O`) → 왼쪽 `Archives` → 방금 만든 `Doughmetry 1.0 (1)` 항목이 `iOS Apps` 아래 있는지 확인 (`Other Items` 아래면 스킴 아카이브 설정 문제, 8장).
7. 아카이브 내용 검증 — Organizer의 가장 최근 아카이브를 본다 (ITSAppUsesNonExemptEncryption false, UIDeviceFamily [1,2], UIApplicationSupportsMultipleScenes false, PrivacyInfo.xcprivacy 포함, MinimumOSVersion = 프로젝트의 IPHONEOS_DEPLOYMENT_TARGET):

   ```bash
   ios/AppStore/preflight.sh archive   # → preflight archive: 통과
   ```

   빌드 번호도 눈으로 보려면: `plutil -p "$(ls -td ~/Library/Developer/Xcode/Archives/*/*.xcarchive | head -1)/Products/Applications/Doughmetry.app/Info.plist" | grep -E 'CFBundleVersion|CFBundleShortVersionString'` → `"1"` / `"1.0"`.

8. (선택) Organizer에서 아카이브 우클릭 → `Generate Privacy Report` → `User Defaults / CA92.1` 항목이 보이면 0-2 정상.

### 4-2. Validate App (업로드 없이 ITMS 검사)

1. Organizer에서 아카이브 선택 → 오른쪽 `Validate App` 클릭.
2. `TestFlight & App Store` 기본 선택 그대로 → `Validate`.
3. 처음이면 클라우드 서명 인증서 생성 동의 창이 뜰 수 있다 → 진행. 2FA 코드 요청이 오면 입력.
4. 몇 분 뒤 `App "Doughmetry" successfully validated`가 나오면 통과. 오류가 나오면 8장에서 코드(ITMS-xxxxx)로 찾는다.

### 4-3. Distribute App (업로드) — GUI 경로 (권장)

1. Organizer에서 같은 아카이브 선택 → `Distribute App`.
2. `Select a method for distribution` 시트에서 **`TestFlight & App Store`** 선택 → `Distribute`. (`TestFlight Internal Only`를 고르면 그 빌드는 영영 App Store에 못 붙이니 고르지 말 것. Xcode 버전에 따라 `App Store Connect`로 표시될 수 있음.)
3. 이 기본 흐름은 추가 질문 없이: 빌드 번호 자동 관리 → 클라우드 Apple Distribution 인증서로 재서명 → .ipa + dSYM 업로드 → 완료 화면(ASC 링크 포함)까지 진행한다. 1~5분.
4. 완료 화면에서 `Done`. 몇 분 내에 `juvesoul@icloud.com`으로 "The following build has completed processing" 메일이 온다 (보통 5~30분, 바쁠 때 1~2시간; 24시간 넘으면 비정상).
5. 메일에 `ITMS-91053` 경고가 섞여 있으면 0-2를 빠뜨린 것 — 빌드는 그래도 처리된다. 다음 업로드 전에 추가.

`Custom` 경로 (모든 선택지를 직접 보고 싶을 때): `Distribute App > Custom > App Store Connect > Next > Upload > Next` → 옵션 `Upload your app's symbols` 켬, `Manage Version and Build Number` 켬, `TestFlight internal testing only` **끔**, `Strip Swift symbols` 켬 → `Next` → `Automatically manage signing` → `Next` → 요약(번들 ID, 1.0 (1), 엔타이틀먼트에 iCloud 컨테이너 표시) 확인 → `Upload`.

### 4-3-alt. CLI 경로 (archive.sh)

GUI 대신 쓸 수 있다. 같은 Apple 계정이 Xcode에 로그인돼 있어야 한다(`-allowProvisioningUpdates`가 그 계정을 쓴다).

1. `cd /Users/narudoc/Claude/Doughmetry/ios && ./AppStore/archive.sh` — 먼저 `preflight.sh repo`로 저장소·배포 상태를 보고(어긋나면 아카이브하지 않는다), 아카이브 뒤 업로드 전에 `preflight.sh archive`로 아카이브 내용을 본다. 빌드 번호를 `date +%Y%m%d%H%M`(예 `202609061830`)으로 넣고 `xcodebuild archive` → `-exportArchive`(`AppStore/ExportOptions.plist`: `method=app-store-connect`, `destination=upload`, `signingStyle=automatic`, `teamID=G46DT9WHWV`, `uploadSymbols=true`, `manageAppVersionAndBuildNumber=true`)까지 실행한다. 빌드 번호를 지정하려면 `./AppStore/archive.sh 2`.
2. 종료 코드 0이면 ASC가 패키지를 받은 것. 이후 처리 과정은 GUI와 같다.
3. 참고: `-allowProvisioningUpdates`는 자동 서명 타깃의 프로파일·App ID·인증서를 만들고 갱신한다(Apple 문서). 다만 iCloud 컨테이너까지 만들어 주는지는 확인하지 않았으므로, 1-4처럼 Xcode GUI 서명이 한 번 해결된 상태(지금이 그 상태)에서 쓰는 것이 안전하다.
4. .ipa만 만들어 Transporter 앱으로 올리려면(업로드가 실패했을 때 등) `AppStore/ExportOptions.plist`는 **고치지 말 것** — 작업 트리가 바뀌면 archive.sh의 `preflight.sh repo`가 멈추고, 커밋하면 이후 실행이 모두 업로드 대신 내보내기가 된다. 이미 있는 아카이브(archive.sh가 남긴 `ios/build/Doughmetry.xcarchive`)를 git 밖 사본 설정으로 내보낸다(`ios/build/`는 `.gitignore`):

   ```bash
   cd /Users/narudoc/Claude/Doughmetry/ios
   plutil -replace destination -string export -o build/ExportOptions-export.plist AppStore/ExportOptions.plist
   xcodebuild -exportArchive -archivePath build/Doughmetry.xcarchive \
     -exportOptionsPlist build/ExportOptions-export.plist -exportPath build/export -allowProvisioningUpdates
   ```

   Xcode Organizer의 아카이브라면 `Distribute App` → `Custom` → `App Store Connect` → `Export`로 같은 .ipa를 얻는다. CLI는 `ios/build/export/Doughmetry.ipa`, Organizer는 저장 창에서 고른 폴더(안의 `Doughmetry <날짜 시각>` 폴더)에 .ipa를 만든다. 그 .ipa를 Mac App Store의 `Transporter`(Apple, 무료) → 같은 Apple 계정 로그인 → `+`로 .ipa 추가 → 초록 체크 → `Deliver`.

### 4-4. 수출 규정 (Export Compliance) 답변

0-3을 했으면 아무 질문도 나오지 않고 빌드가 바로 `제출 준비됨 (Ready to Submit)`이 된다. 0-3을 안 했거나 그래도 질문이 나오면:

1. ASC → `앱` → `도우메트리: 사워도우 계산기` → `TestFlight` 탭 → `빌드 (Builds) > iOS` → 빌드 행 상태 `규정 준수 누락 (Missing Compliance)` 옆 `관리 (Manage)` 클릭.
2. 질문 "앱이 암호화를 사용하도록 설계되었거나 암호화를 포함합니까? (Is your app designed to use cryptography or does it contain or incorporate cryptography? — Select Yes even if your app only uses the standard encryption within Apple's operating system)" → **`예 (Yes)`**.
3. "어떤 유형의 암호화 알고리즘을 구현합니까? (What type of encryption algorithms does your app implement?)" → **`위에 언급된 알고리즘 중 해당 사항 없음 (None of the algorithms mentioned above)`** → `저장 (Save)`.
4. 결과: 문서 제출 불필요, 상태가 `제출 준비됨`으로 바뀐다. **절대 "예, 독자 암호화 구현"을 고르지 말 것** — CCATS/프랑스 신고 서류를 요구하며 `수출 규정 심사 대기 중`에 갇힌다.
5. 이전 형식의 2문항(면제 여부)이 나오면: "면제 대상입니까?" → `예` (EAR Category 5 Part 2 면제 — Apple OS 제공 암호화만 사용).
6. 이 답은 키가 없는 한 빌드마다 반복된다. 한 번만 답하려면 0-3의 `ITSAppUsesNonExemptEncryption = NO`가 유일한 방법이다(생성 Info.plist에 `false`로 들어가는 것 확인됨). 앱 수준의 `앱 정보 > 앱 암호화 문서 (App Encryption Documentation)`는 CCATS 서류나 면제 코드(`ITSEncryptionExportComplianceCode`)를 등록하는 곳이라 이 앱에는 해당 없고, 빌드별 질문도 없애 주지 않는다.

---

## 5. TestFlight로 내 아이폰에 설치

내부 테스트는 Beta App Review 없이 처리 완료 즉시 가능하다. 외부 테스트(`외부 테스팅` 탭, 공개 링크)는 첫 빌드마다 약 24시간 심사가 붙으므로 혼자 테스트할 땐 쓰지 않는다.

1. ASC → `앱` → `도우메트리: 사워도우 계산기` → `TestFlight` 탭 → `빌드 > iOS`에서 `1.0 (1)` 상태가 `제출 준비됨 (Ready to Submit)`인지 확인 (`규정 준수 누락`이면 4-4).
2. 왼쪽 사이드바 `내부 테스팅 (Internal Testing)` 옆 `+` → `새 내부 그룹 생성 (Create New Internal Group)` → 그룹 이름 `Narudoc` → `자동 배포 활성화 (Enable automatic distribution)` 체크 유지 → `생성 (Create)`.
3. 그룹 클릭 → `테스터 (Testers)` 옆 `+` 또는 `테스터 초대 (Invite Testers)` → 이 앱에 접근 가능한 ASC 사용자 목록에서 본인(`juvesoul@icloud.com`) 체크 → `추가 (Add)`.
4. **먼저 알아둘 것**: TestFlight 앱에는 별도 로그인이 없다. 아이폰 `설정 > (내 이름) > 미디어 및 구입`에 로그인된 Apple 계정을 그대로 쓴다.
   - 그 계정이 `juvesoul@icloud.com`이면 6번에서 `앱` 목록에 바로 뜬다.
   - `juvesoul@gmail.com` 등 다른 계정이면 순서대로: (a) 3번을 끝내면 icloud 받은편지함에 "You're invited to test 도우메트리: 사워도우 계산기" 메일이 온다 — 이 메일을 **그 아이폰에서** 열어 `View in TestFlight`를 누른다(초대 링크가 기기에 로그인된 계정으로 교환되어 설치된다). (b) 그래도 안 뜨면 `사용자 및 액세스 (Users and Access)` → `사용자 (People)` → `+` → 이름/성/`juvesoul@gmail.com` → `역할 (Roles)`: `개발자 (Developer)` → `앱: 모든 앱 (All Apps)` → `초대 (Invite)` → gmail에서 초대 수락(3일 내) → 3번으로 돌아가 그 사용자를 그룹에 추가.
5. 자동 배포를 켰으면 빌드가 그룹에 자동으로 들어간다. 안 들어갔으면 그룹 → `빌드 (Builds)` → `+` / `빌드 추가 (Add Builds)` → `1.0 (1)` → `다음` → `테스트 내용 (What to Test)`은 내부 그룹에선 선택 → `추가`.
6. 아이폰(iOS 17 이상): App Store에서 `TestFlight`(Apple) 설치 → 열기(로그인 화면 없음, 기기 계정 사용) → `앱` 목록에 `도우메트리: 사워도우 계산기`가 보이면 `설치`. 안 보이면 4번의 초대 메일 → `View in TestFlight` → `Accept` → `Install`. `코드 사용 (Redeem)`은 필요 없다. Xcode로 직접 설치한 빌드는 iCloud 개발 환경, TestFlight 빌드는 프로덕션 환경을 쓰므로 데이터가 서로 안 보이는 것이 정상이다. **번들 ID가 2026-09-11에 `com.narudoc.levaincalc` → `com.narudoc.doughmetry`로 바뀌었으므로 TestFlight 설치본은 옛 앱을 덮어쓰지 않고 별개 앱으로 깔린다** — 홈 화면에 옛 `사워도우 계산기`(Xcode로 직접 설치한 빌드)와 새 `도우메트리`가 나란히 보이면 정상이다. iCloud 컨테이너도 바뀌어 옛 레시피·베이킹 로그는 새 앱으로 넘어오지 않는다. 옮기려면 **옛 앱을 지우기 전에** 옛 앱의 레시피 탭에서 JSON 내보내기 → 새 앱에서 가져오기. 확인이 끝나면 옛 앱을 삭제하고, 옛 컨테이너에 남은 iCloud 사본은 `설정 > (내 이름) > iCloud > 저장 공간 관리`에서 지운다.
7. 실기기 확인 목록 (여기가 첫 프로덕션 iCloud 환경 테스트다):
   - 계산기: 재료 입력 → 하단 요약(총 수분율·PFF·총 무게) 즉시 반영, 배합표 시트 공유, 배율 조정(×2).
   - 변환: 리퀴드↔뒤흐 변환 후 보존 지표 체크.
   - 레시피: 사진 선택 → 가져오기 확인 시트 → 저장. Apple Intelligence가 꺼진 기기에서도 규칙 파서로 동작.
   - 도구 탭 → 설정: `iCloud 동기화` 켜짐, 상태 `마지막 동기화 …`. 두 번째 기기(또는 앱 삭제 후 재설치)에서 **이번에 새로 저장한** 레시피가 내려오는지 — 컨테이너가 `iCloud.com.narudoc.doughmetry`로 새로 바뀌었으므로 개명 전 데이터가 하나도 안 보이는 것이 정상이다(동기화 실패가 아니다).
   - 설정 맨 아래 `개인정보 처리방침`·`지원·문의` 링크 → Safari에서 3장 페이지가 열림, 버전 `1.0 (1)` (0-1 확인).
   - 도구: 타임라인 알림 권한 요청 → 알림 도착.
   - 다크 모드, 영어 전환(영어 용어: Liquid/Stiff levain, Starter).
   - **iPad가 있으면** 같은 그룹으로 TestFlight 설치 → 세로·가로·Split View·창 크기 조절(0-9 6번과 같은 항목)과 두 기기 사이 iCloud 동기화 — 심사관이 iPad로 열 수 있다.
   동기화·저장·가져오기 문제가 생기면 진단 로그를 본다: 아이폰을 Mac에 연결 → Console.app 왼쪽에서 기기 선택 → 검색창에 `subsystem:com.narudoc.doughmetry` → `시작 (Start)`을 누른 **뒤** 문제를 재현한다(`sync`·`storage`·`import`(AI 초안 시간 초과·기각 사유) 카테고리, 개수와 오류 도메인·코드·기각 사유만 남고 레시피 내용은 남지 않는다). 다른 테스터에게서는 sysdiagnose를 받는다. 통합 로그는 기기 밖으로 나가지 않으므로 6-4의 '데이터가 수집되지 않음' 라벨은 그대로다.
8. 빌드는 업로드 90일 후 `만료됨 (Expired)`이 된다. 스토어 버전에는 영향 없다.

---

## 6. 버전 페이지 작성 (1.0)

앱 수준 정보(6-1~6-4)를 먼저 채우고 버전 페이지(6-5~6-9)를 채운다. 각 페이지는 오른쪽 위 `저장 (Save)`을 눌러야 반영된다. 언어 전환은 각 페이지 오른쪽 위 언어 드롭다운.

### 6-1. 앱 정보 (App Information)

`앱 > 도우메트리: 사워도우 계산기 > 왼쪽 사이드바 일반 (General) > 앱 정보 (App Information)`. 현지화는 넷이다 — 한국어(기본)·영어(미국)·영어(영국)·영어(캐나다). 왜 영어가 셋인지는 [listing.md](listing.md) 현지화 표 아래에 적어 두었다(스토어마다 검색에 쓰는 언어가 다르다).

1. `현지화 가능한 정보 (Localizable Information)` — 한국어:
   - `이름 (Name)`: `도우메트리: 사워도우 계산기`
   - `부제목 (Subtitle)`: `르방 변환·수분율·베이커스 퍼센트` (18자)
2. 오른쪽 위 언어 드롭다운 → `+` 또는 목록에서 `영어(미국) (English (U.S.))` 추가 → 영어:
   - `이름`: `Doughmetry: Sourdough Calc` (26자 — 30자 한도). 중복이면 브랜드 `Doughmetry`는 두고 설명어만 바꾼다 — `Doughmetry: Levain Calc`(23자), `Doughmetry — Levain Calculator`(30자). 브랜드를 뺀 옛 이름(`Levain Calc` 등)으로 되돌아가지 않는다.
   - `부제목`: `Levain & hydration calculator` (29자 — 30자 한도)
3. 같은 방법으로 `영어(영국) (English (U.K.))`와 `영어(캐나다) (English (Canada))`를 추가하고 2번과 **같은 이름·부제목**을 넣는다(같은 앱은 현지화마다 같은 이름을 다시 써도 된다). **새 언어를 추가하면 ASC가 기본 언어(한국어)의 이름·부제목·스크린샷을 미리 채워 두므로** 필드마다 영어로 덮어써야 한다 — 그대로 두면 영국·캐나다 등의 스토어에 한국어가 보인다.
4. `일반 정보 (General Information)`:
   - `번들 ID`: `com.narudoc.doughmetry` (자동), `SKU`: `doughmetry` (자동), `Apple ID`: `6827977830` (자동).
   - `기본 언어 (Primary Language)`: `한국어`. 기본 언어는 첫 승인 뒤에만 바꿀 수 있다(Apple 'Change the primary language') — 영어 검색은 위 세 영어 현지화로 해결한다.
   - `카테고리 (Category)`: `기본 (Primary)` = `음식 및 음료 (Food & Drink)`, `보조 (Secondary)` = `유틸리티 (Utilities)`.
   - `콘텐츠 권한 (Content Rights)`: `콘텐츠 권한 정보 설정 (Set Up Content Rights Information)` → `아니요, 타사 콘텐츠를 포함·표시·접근하지 않습니다 (No, it does not contain, show, or access third-party content)` → `완료 (Done)`. (앱이 배포하는 타사 콘텐츠는 없다. 사용자가 직접 가져오는 레시피는 사용자의 기기와 본인 iCloud에만 있다.)
   - `연령 등급 (Age Rating)`: 6-2.
   - `사용권 계약 (License Agreement)`: Apple 표준 EULA 그대로.
5. `저장`.

### 6-2. 연령 등급 설문 (2025년판 — 신규 제출 필수)

`앱 정보` 페이지의 `연령 등급 (Age Rating)` → `연령 등급 설정 (Set Up Age Ratings)` / `편집 (Edit)`.

Apple 도움말 기준 진행 표시줄은 `1 앱 내 제어 및 기능` → 콘텐츠 설명 섹션들 → `5 우연에 기반한 활동` → … → `7 추가 정보` 순이다. 화면의 섹션 이름·순서가 아래와 조금 달라도 신경 쓰지 말고 규칙만 지킨다: **빈도를 고르는 항목은 전부 `없음 (None)`, 예/아니요 항목은 전부 `아니요 (No)`**, `다음`을 눌러 `추가 정보`까지 간 뒤 `연령 카테고리 및 재정의` = `해당 없음 (Not Applicable)`, `연령 적합성 URL` 비움, `계산된 등급 4+` 확인 → `저장`. (아래 2~7번은 예상 화면이다.) 이 앱의 답:

1. `앱 내 제어 및 기능 (In-App Controls & Capabilities)`:
   - `보호자 관리 기능 (Parental Controls)`: `아니요 (No)`
   - `연령 확인 (Age Assurance)`: `아니요`
   - `제한 없는 웹 접근 (Unrestricted Web Access)`: `아니요`
   - `사용자 생성 콘텐츠 (User-Generated Content)`: `아니요` (레시피·로그는 본인 기기/iCloud에만 있고 공개되지 않음)
   - `소셜 미디어 (Social Media)`: `아니요` (하위 질문 "13세 미만 비활성화"는 해당 없음)
   - `메시지 및 채팅 (Messaging and Chat)`: `아니요`
   - `광고 (Advertising)`: `아니요`
   → `다음 (Next)`
2. `폭력 (Violence)`: 만화/판타지 폭력, 사실적 폭력, 장기적·가학적 사실적 폭력, 총기 및 무기 — 전부 `없음 (None)` → `다음`
3. `성인 주제 (Mature Themes)`: 욕설/저속한 유머, 공포/두려움, 술·담배·약물 사용 또는 언급 — 전부 `없음` → `다음`
4. `성적 내용 또는 노출 (Sexuality or Nudity)`: 전부 `없음` → `다음`
5. `의료 또는 웰니스 (Medical or Wellness)`: 의료/치료 정보, 건강/웰니스 주제 — `없음` → `다음`
6. `우연에 기반한 활동 (Chance-Based Activities)`: 모의 도박 `없음`, 콘테스트 `없음`, 도박 `아니요`, 루트 박스 `아니요` → `다음`
7. `추가 정보 (Additional Information)`:
   - `연령 카테고리 및 재정의 (Age Categories and Override)`: `해당 없음 (Not Applicable)`. **`어린이용 (Made for Kids)`는 절대 선택하지 말 것** — 승인 후 되돌릴 수 없고 Kids 카테고리 규정이 붙는다.
   - `연령 적합성 URL (Age Suitability URL)`: 비움.
8. `계산된 등급 (Calculated Rating)` = `4+` 확인 → `저장`.
9. 표의 `대한민국 (Korea)` 행 `RCN 추가`는 GRAC 등급을 받은 게임 전용 — 건너뛴다.

### 6-3. 가격 및 사용 가능 여부 (Pricing and Availability)

`사이드바 수익화 (Monetization) > 가격 및 사용 가능 여부 (Pricing and Availability)` (구 UI에서는 `일반` 아래).

1. `가격 변경 일정 (Price Schedule)` → `가격 추가 (Add Pricing)`.
2. `기준 국가 또는 지역 (Base Country or Region)`: `대한민국` → `가격 (Price)`: 목록 맨 위 `₩0 (무료)` → `다음`.
3. 자동 생성된 다른 국가 가격이 모두 0인지 확인 → `다음` → `확인 (Confirm)`.
4. `사용 가능 여부 (Availability)`: 기본값(175개 전 지역) 유지.
5. 같은 페이지의 `Apple Silicon Mac의 iPhone 및 iPad 앱 (iPhone and iPad Apps on Apple Silicon Macs)`과 `Apple Vision Pro의 iPhone 및 iPad 앱`은 기본 켜짐이다. iPad를 지원하므로 Mac에서는 iPad 앱('Designed for iPad')으로 돈다. 0-9 7번을 하지 않았다면 Mac은 시험하지 않은 환경이고, 이 Mac에는 visionOS 런타임이 없어 Vision Pro도 시험하지 않았다. 그대로 둘지, 1.0에서는 체크를 끄고 확인한 뒤 켤지는 직접 정한다.
6. `저장`.

### 6-4. 앱 개인정보 보호 (App Privacy) — 라벨 + 처리방침 URL

`사이드바 일반 (General) > 앱 개인정보 보호 (App Privacy)`.

1. 맨 위 `개인정보 처리방침 (Privacy Policy)` 블록 → `편집 (Edit)`:
   - `개인정보 처리방침 URL (Privacy Policy URL)`: `https://narudoc.github.io/doughmetry/privacy.html` (3-2에서 200 확인한 것)
   - `사용자 개인정보 선택 URL (User Privacy Choices URL)`: 비움
   - 언어 드롭다운으로 `영어(미국)`·`영어(영국)`·`영어(캐나다)`를 차례로 골라 같은 URL 입력 → `저장`.
2. `데이터 수집 (Data Collection)` 블록 → `시작하기 (Get Started)` → "귀하 또는 타사 파트너가 이 앱에서 데이터를 수집합니까?" → **`아니요, 이 앱에서는 데이터를 수집하지 않습니다 (No, we do not collect data from this app)`** → `저장`.
3. `게시 (Publish)` → 확인 창 `앱 개인정보 보호 응답을 게시하시겠습니까?` → `게시`. 스토어 라벨이 `데이터가 수집되지 않음 (Data Not Collected)`으로 표시된다. **저장만 하고 게시하지 않으면 버전 페이지에 빨간 미완료 표시가 남는다.**
   - 근거: Apple 정의의 "수집"은 개발자/파트너가 접근 가능한 형태로 기기 밖으로 전송하는 것. iCloud Documents 데이터는 사용자 본인 iCloud에만 있고 개발자 접근 불가, 분석·광고·계정 없음. 바이너리에 네트워킹 심볼이 없음이 확인됨.

### 6-5. 버전 페이지 — 스크린샷

`사이드바 iOS 앱 > 1.0 제출 준비 중 (1.0 Prepare for Submission)`. 언어 드롭다운은 `한국어`로 시작. 파일은 0-13에서 찍은 JPEG다.

2026-10-28 ASC 화면 기준(1.0 때 이대로 올렸다): 버전 페이지 '제품 페이지 정보'의 `헤더 및 검색 결과 >`를 눌러 `앱 미리보기 및 스크린샷`으로 바꾸고 `미디어 관리에서 모든 크기 보기`를 연다(미디어 관리 — 맨 위에서 iPhone/iPad와 언어를 고른다). iPhone은 **필수 칸이 `Dynamic Island 지원 iPhone (중형 디스플레이)`**(6.1·6.3형 — 1206×2622 등만 받는다)이고, 우리 1320×2868은 '선택 사항'의 **`Dynamic Island 지원 iPhone (대형 디스플레이)`**(내부 이름 `APP_IPHONE_67`, 2868×1320·2796×1290 등)에 올린다 — 그러면 필수 칸이 `기존 자산 사용`(대형 세트를 줄여 씀)으로 채워진다. 중형 칸이나 그 아래 `Face ID 지원 iPhone (대형 디스플레이)`(6.5형)에 놓으면 '파일 크기가 유효하지 않습니다'로 거부된다.

1. 미디어 관리 `iPhone` · `한국어` → '선택 사항'의 `Dynamic Island 지원 iPhone (대형 디스플레이)`를 펼쳐(설명에 '1320 × 2868px'이 있는 칸) Finder에서 `/Users/narudoc/Claude/Doughmetry/ios/AppStore/screenshots/ko/6.9-jpg/`의 `01-convert.jpg` … `07-scale.jpg`를 이름 순서대로 드래그 (최대 10장). 순서가 틀리면 썸네일을 드래그해 재배열. 필수(중형) 칸에 `기존 자산 사용`이 보이면 된다.
2. 미디어 관리 `iPad` → 필수 칸 `iPad 33.0cm 디스플레이`(13형, 2064×2752)에 `ko/13-jpg/`의 같은 이름 파일들. **iPad를 지원하므로 이 칸이 비어 있으면 제출할 수 없다.**
3. 언어 드롭다운 → `영어(미국)` → iPhone 대형 칸에 `en/6.9-jpg/`, iPad 칸에 `en/13-jpg/`. 이어서 `영어(영국)`·`영어(캐나다)`에도 같은 `en/` 파일을 올린다. 언어마다 Finder 창이 넷이라 헷갈리기 쉽다 — `ko`·`en` 폴더를 바꿔 넣으면 그 스토어에 다른 언어 화면이 보인다(01-convert 썸네일이 '르방 변환'이면 ko, 'Levain conversion'이면 en). 2026-10-28에는 영어 현지화를 스크린샷보다 먼저 만들어 미리 채워진 것이 없었지만, 한국어를 먼저 올린 뒤 언어를 추가하면 한국어 스크린샷이 미리 채워지므로 **지우고** 올린다.
4. 대형 iPhone·13형 iPad만 올리면 작은 크기는 ASC가 줄여 쓴다 — 다른 크기 칸은 비워 둔다.
5. 썸네일에 빨간 `!`나 "alpha channel"·크기 오류가 뜨면 다른 폴더의 파일(iPad 탭에 `6.9-jpg/` 등)이나 저장소 밖의 옛 사본을 올린 것이다 — `ios/AppStore/preflight.sh shots`가 통과하는 0-13의 폴더에서 다시 올린다.

### 6-6. 버전 페이지 — 텍스트

문구의 원본은 [listing.md](listing.md) 하나다 — 여기에 다시 적지 않는다(두 곳이 어긋나지 않게). 언어 드롭다운으로 현지화를 바꿔 가며 아래 표대로 붙여 넣는다. `설명`과 `키워드`는 필수.

| ASC 필드 | 한국어 | 영어(미국) | 영어(영국) | 영어(캐나다) |
|---|---|---|---|---|
| `프로모션 텍스트 (Promotional Text)` (170자, 선택, 심사 없이 수정 가능) | 홍보 문구 KR | 홍보 문구 EN | EN | EN |
| `설명 (Description)` (4000자, 서식 없음) | 설명 (KR) 코드 블록 | Description (EN) 코드 블록 | EN | EN |
| `키워드 (Keywords)` | KR | EN-US | **EN-GB** | **EN-CA** |
| `지원 URL (Support URL)` | `https://narudoc.github.io/doughmetry/support.html` | 같음 | 같음 | 같음 |
| `마케팅 URL (Marketing URL)` (선택) | `https://narudoc.github.io/doughmetry/` | 비움 또는 support.html (웹 계산기는 한국어 화면뿐) | 미국과 같게 | 미국과 같게 |

- 키워드는 **100바이트 이하**로 맞춘다 — Apple 문서가 엇갈린다(App Store 검색 안내는 100자, ASC 도움말은 100바이트). 한글은 글자당 3바이트. 길이 확인: `python3 -c "print(len('<키워드>'.encode()))"`. 쉼표 뒤 공백 없이, 이름·부제의 낱말과 다른 앱 이름은 넣지 않는다(2.3.7). ASC 도움말은 두 글자보다 긴 키워드를 요구하므로, 저장할 때 두 글자 낱말(르뱅·제빵·반죽)이 거부되면 더 긴 변형(예: 르뱅빵)으로 바꾼다.
- `이 버전의 새로운 기능 (What's New)`: 첫 버전에는 필드가 없다(1.0.1부터 네 현지화 모두 필수 — 7-4).

### 6-7. 버전 페이지 — 빌드·일반 정보

1. `빌드 (Build)` 섹션 → `+` / `빌드 추가 (Add Build)` → `1.0 (1)` 선택 → `완료 (Done)`. (여기서 수출 규정 창이 뜨면 4-4의 답.)
2. `일반 앱 정보 (General App Information)`:
   - `앱 아이콘`: 빌드에서 자동.
   - `버전 (Version)`: `1.0` (빌드의 `CFBundleShortVersionString`과 같아야 함).
   - `저작권 (Copyright)`: 고정값 표의 값 (`2026 Kiyoung Ha`) — © 기호는 자동으로 붙는다.
   - `연령 등급`: 6-2에서 계산된 `4+` 표시.
3. `앱 심사 정보 (App Review Information)`:
   - `로그인 필요 (Sign-in required)`: **체크 해제** (계정 없음).
   - `연락처 정보 (Contact Information)`: 고정값 표의 이름·성·전화(`+82 10-…` 국제 형식)·이메일(`juvesoul@icloud.com`)을 그대로 입력.
   - `메모 (Notes)` (4000바이트, 선택이지만 꼭 쓸 것): [listing.md](listing.md) `심사 노트`의 코드 블록을 한/영 그대로 붙여 넣는다(약 2.6 KB). 계정 불필요·오프라인·iPad 지원·가져오기 방식(Apple Intelligence가 없으면 규칙 파서)·본인 iCloud만 사용·로컬 알림·테스트용 레시피가 들어 있다.
   - `첨부 파일 (Attachment)`: 불필요.
4. `App Store 버전 출시 (App Store Version Release)`: 첫 출시는 **`이 버전을 수동으로 출시 (Manually release this version)`** 선택 — 승인 후 스토어 페이지를 확인하고 내가 원하는 시각에 공개. (자동 출시는 `앱 심사가 끝나면 자동으로 이 버전을 출시`.)
5. 오른쪽 위 `저장`.

### 6-8. 미완료 항목 점검

1. 사이드바와 각 섹션 제목의 빨간 점이 모두 사라졌는지 확인. 남아 있다면 대상: 스크린샷(iPhone 6.9형·iPad 13형), 설명, 키워드, 지원 URL, 빌드, 저작권, 연락처, 앱 개인정보 보호(게시), 연령 등급, 가격, 콘텐츠 권한.
2. 언어 드롭다운으로 영어(미국)·영어(영국)·영어(캐나다)를 하나씩 골라 이름·부제(앱 정보)와 스크린샷(iPhone·iPad)·프로모션 텍스트·설명·키워드가 영어인지 눈으로 본다 — 새 언어는 한국어 값으로 미리 채워지므로 빨간 점이 없어도 한국어가 남아 있을 수 있다. 키워드는 영어(영국)·영어(캐나다)가 영어(미국)와 다른 세트다(6-6).

### 6-9. 심사에 추가 → 제출

1. 오른쪽 위 `심사에 추가 (Add for Review)` → `새로운 제출 (New Submission)` 선택 → 상태가 `심사 준비됨 (Ready for Review)`으로 바뀌고 오른쪽 아래 `제출 초안 (Draft Submissions)`에 항목이 생긴다.
2. 그 항목의 `심사를 위해 제출 (Submit for Review)` 클릭 → 확인.
3. 상태: `심사 대기 중 (Waiting for Review)` → `심사 중 (In Review)` → 결과. 이메일로도 통보.

---

## 7. 심사 제출과 이후

### 7-1. 소요 시간과 상태

| 상태 | 뜻 / 보통 걸리는 시간 |
|---|---|
| `심사 대기 중 (Waiting for Review)` | 큐 대기. Apple 공식: 90%가 24시간 내 처리. 첫 제출은 1~3일 잡을 것. |
| `심사 중 (In Review)` | 리뷰어가 보는 중. 보통 수 시간. |
| `개발자 출시 대기 중 (Pending Developer Release)` | 승인됨(수동 출시 선택 시). |
| `배포용 처리 중 (Processing for Distribution)` | 출시 버튼 후 최대 24시간. |
| `배포 준비됨 (Ready for Distribution)` | 스토어에 올라감. 검색 노출은 몇 시간 더 걸릴 수 있음. |
| `거절됨 (Rejected)` / `메타데이터 거절됨 (Metadata Rejected)` | 7-3. |

### 7-2. 승인 후 출시

1. `앱 > 도우메트리: 사워도우 계산기 > 1.0` 페이지 상단 `이 버전 출시 (Release This Version)` → `출시 (Release)`.
2. `배포 준비됨`이 되면 아이폰·아이패드 App Store에서 `도우메트리: 사워도우 계산기` 검색 → 페이지·스크린샷(아이패드에서는 13형 세트)·`데이터가 수집되지 않음` 라벨 확인. 영어로는 `Doughmetry` 검색(미국 계정이 없으면 웹 `apps.apple.com/us/…`·`/gb/…`에서 영어 페이지 확인).
3. TestFlight 빌드는 그대로 90일 유지되지만 스토어 버전을 설치하면 TestFlight 설치본을 대체한다(데이터 유지).
4. 스토어 링크 연결 (새 빌드·웹 배포 필요): `ios/Doughmetry/AppLinks.swift`의 `appStoreID`에 ASC `Apple ID`(숫자)를 넣으면 설정의 앱 평가·공유 행이 나타난다(다음 업데이트에 포함). 웹은 `public/support.html`의 "출시 예정 (coming soon)"을 App Store 링크로 바꾸고, `src/App.tsx` 푸터에 네 번째 링크(App Store)를 더하고, `index.html`에 `<meta name="apple-itunes-app" content="app-id=…">`를 넣은 뒤 3-2대로 푸시·확인한다.

### 7-3. 거절되면

1. ASC 사이드바 `앱 심사 (App Review)` 또는 상단 메시지의 Resolution Center에서 사유(지침 번호)를 읽는다.
2. `메타데이터 거절됨`: 스크린샷·설명·URL·심사 메모만 고치고 다시 제출 — 새 빌드 불필요.
3. `거절됨`(바이너리 문제): 코드 수정 → `Build`를 올려(0-4) 재아카이브·업로드 → 버전 페이지에서 빌드 교체 → 재제출.
4. 리뷰어 판단이 잘못됐다고 보면 같은 스레드에 `회신 (Reply)`으로 근거를 설명한다(예: "가져오기는 온디바이스 처리, 계정 불필요"). 조용히 재제출하는 것보다 스레드 회신이 빠르다.
5. 제출을 되돌리고 싶으면 `심사에서 제출 제거 (Remove Submission from Review)` → 상태 `개발자 거절됨 (Developer Rejected)` → 수정 후 다시 제출.

첫 제출에서 흔한 지침: `2.1` 크래시/미완성 (TestFlight 실기기 테스트로 예방), `5.1.1` 개인정보 처리방침 URL 없음/접속 불가 (3장), `1.5`·`2.3` 지원 URL에 연락처 없음·스크린샷이 앱과 다름, `2.3.7` 키워드에 다른 앱 이름, `4.0` 리뷰어 기기에서의 디자인 문제.

### 7-4. 업데이트(1.0.1 이후) 내는 법

1. 코드 수정 후 Xcode `TARGETS > Doughmetry > General > Identity`: `Version` = `1.0.1` (MARKETING_VERSION), `Build` = 이전보다 큰 수 (예 `2`). 빌드 번호는 항상 증가.
2. `Any iOS Device (arm64)` → `Product > Archive` → Organizer `Distribute App > TestFlight & App Store > Distribute` (4-3과 동일).
3. ASC → `앱 > 도우메트리: 사워도우 계산기` → 사이드바 `iOS 앱` 옆 `+` → `버전 또는 플랫폼 추가` → `iOS` → 버전 `1.0.1` → `생성`.
4. 새 버전 페이지: `이 버전의 새로운 기능 (What's New)` — **이때부터 필수**, 네 현지화(한국어·영어(미국)·영어(영국)·영어(캐나다)) 모두 입력. 스크린샷·설명은 이전 버전에서 복사되므로 바뀐 것만 수정 — UI가 바뀌었으면 0-13으로 다시 찍는다.
5. 처리 완료된 빌드를 `빌드 추가`로 선택 → `저장` → `심사에 추가` → `심사를 위해 제출`.
6. 스토어 이름·부제·키워드는 버전이 `제출 준비 중`일 때만 수정 가능. `심사 대기 중` 이후엔 제출 제거 후 수정.
7. TestFlight 그룹에 자동 배포가 켜져 있으니 업로드마다 내 아이폰에 새 빌드가 뜬다 — 제출 전에 한 번 설치해 본다.
8. 웹앱·iOS 공통 규칙(`CLAUDE.md`): 계산 규칙이나 레시피 스키마가 바뀌면 `dough.ts`↔`Dough.swift`, `storage.ts`↔`Codec.swift`를 함께 고치고 양쪽 테스트 통과 후 아카이브.

---

## 8. 자주 나는 오류와 해결

| 증상 | 원인 / 해결 |
|---|---|
| 업로드 후 메일 `ITMS-91053: Missing API declaration … NSPrivacyAccessedAPICategoryUserDefaults` | PrivacyInfo.xcprivacy 없음. 경고 메일로 그치고 빌드가 처리되는 경우가 많지만 Apple 정책상 거부될 수도 있으므로 0-2를 적용해 재아카이브·재업로드한다. 아카이브 후 `.xcarchive/Products/Applications/Doughmetry.app/PrivacyInfo.xcprivacy`가 있는지 확인. |
| TestFlight 빌드 `규정 준수 누락 (Missing Compliance)` / 빌드 추가 시 수출 규정 창 | `ITSAppUsesNonExemptEncryption` 키 없음. 4-4대로 `예 → 위 알고리즘 해당 없음`으로 답하면 즉시 해제. 근본 해결은 0-3. 키를 넣었는데도 뜨면 값이 Boolean `NO`가 아니라 문자열이거나 다른 타깃에 들어간 것 — `plutil -p … \| grep ITSApp`으로 `=> false` 확인. |
| `ITMS-90717 Invalid App Store Icon … can't be transparent nor contain an alpha channel` | 이 프로젝트에선 **발생하지 않음이 검증됨**(소스 PNG가 397b51f부터 RGB·알파 없음, 2026-10-28 서명 아카이브의 AppIcon Opaque=true — 0-12). 그래도 뜨면: `Preview`로 `ios/Doughmetry/Assets.xcassets/AppIcon.appiconset/AppIcon.png` 열기 → `File > Export…` → `Format: PNG`, `Alpha` 체크 해제 → 같은 경로에 덮어쓰기 → `sips -g hasAlpha AppIcon.png`가 `no` → `Product > Clean Build Folder (⇧⌘K)` → 재아카이브. (ImageMagick은 이 Mac에 없음.) |
| 스크린샷 업로드 거부 (빨간 `!`, `IMAGE_TOOL_FAILURE`, "alpha channel", 크기 오류) | 다른 폴더의 파일이나 저장소 밖의 옛 사본(PNG·알파 채널·6.3형)을 올린 것이다. 0-13의 JPEG(`{ko,en}/6.9-jpg/` 1320×2868, `{ko,en}/13-jpg/` 2064×2752, 알파 없음)를 올린다. 가로로 찍힌 사진은 크기가 뒤바뀌어 거부된다 — 스크립트가 찍을 때 검사한다. |
| 제출 시 `iPad 13형 디스플레이 스크린샷이 필요합니다` (13-inch iPad screenshots required) | iPad 지원 앱은 13형 iPad 스크린샷이 필수다. 0-13의 `{ko,en}/13-jpg/`를 네 현지화의 iPad 탭에 올린다(6-5 2·3번). |
| Xcode 업로드 오류 `No suitable application records were found. Verify your bundle identifier "com.narudoc.doughmetry"…` | 2장 앱 레코드가 없거나 번들 ID가 다르거나 Xcode 계정이 그 앱에 접근권이 없음. 2장을 먼저 끝낸다. 계속되면 `Xcode > Settings > Accounts`에서 로그아웃/로그인(캐시). |
| 서명 오류 `Provisioning profile … doesn't include the com.apple.developer.icloud-container-identifiers entitlement` / `ITMS-90164/90165 Invalid Code Signing Entitlements` | 개명 후 2026-09-11 08:28 발급된 프로파일 `iOS Team Provisioning Profile: com.narudoc.doughmetry`에 `iCloud.com.narudoc.doughmetry` 3종이 들어 있음을 확인했으므로 보통 안 뜬다. 뜨면 ① `Signing & Capabilities > iCloud > Containers`에서 컨테이너가 빨간색인지 본다 → 이 팀(G46DT9WHWV)에는 `iCloud.com.narudoc.doughmetry`가 2026-09-11 08:28 자동 서명 때 이미 포털에 등록돼 있으므로(포털 ID `F5PQF9M9GU`) 빨간색은 목록을 못 읽어 온 상태다 — 먼저 원형 화살표(새로고침)로 다시 읽는다. ② 그래도 빨간색이면 `Automatically manage signing`을 껐다 켜서 자동 서명을 다시 돌린다(09-11에 이 자동 서명이 컨테이너 생성·App ID 연결·프로파일 발급을 스스로 했다). `+`는 새 컨테이너 ID를 등록하는 버튼이라 이 팀에서는 쓸 일이 없다(다른 팀에서는 이 App ID·컨테이너 ID 자체를 쓸 수 없다 — 1-4 상자 참고). ③ 그래도 안 되면 `developer.apple.com/account > Identifiers > com.narudoc.doughmetry > iCloud ✓ > Edit`에서 `iCloud.com.narudoc.doughmetry` 체크 후 `Save`(목록에 컨테이너가 없으면 `Identifiers > + > iCloud Containers`로 `iCloud.com.narudoc.doughmetry`를 등록한 뒤 다시 체크) → Xcode로 돌아가 `Automatically manage signing`을 껐다 켜서 관리 프로파일을 다시 받는다(`Download Manual Profiles`는 수동 관리 프로파일용이라 자동 서명인 이 프로젝트에는 효과가 없다). |
| `Communication with Apple failed` / 클라우드 서명 실패 | 네트워크·VPN·프록시. 다른 네트워크로 재시도. 2FA 코드 요청 창을 놓치지 않았는지 확인. |
| `The bundle version must be higher than the previously uploaded version` / `ITMS-90061` | 같은 1.0에 같은/낮은 빌드 번호 재업로드. `General > Build`를 올리거나 `Manage Version and Build Number`를 켠 채 배포. CLI 타임스탬프 뒤에 GUI 빌드 `1`을 자동 관리 없이 올린 경우가 전형. |
| ASC 배너 `The Apple Developer Program License Agreement has been updated…`, 업로드 시 `You must accept the latest agreement` | Account Holder로 `developer.apple.com/account` → `Review Agreement` → 동의. `ASC > 비즈니스 > 계약`도 확인. 몇 분 뒤 새로고침. |
| 신규 앱 대화상자 `The App Name you entered is already being used` | 스토어 이름 전 세계 고유 (`사워도우 계산기`가 이래서 거부됐고, 브랜드를 앞에 붙인 `도우메트리: 사워도우 계산기`는 겹칠 일이 없다). 영어 제목(`Doughmetry: Sourdough Calc`, 26자)도 중복이면 브랜드 `Doughmetry`는 두고 **30자 한도 안에서** 설명어만 바꾼다 — `Doughmetry: Levain Calc`(23자) 또는 `Doughmetry — Levain Calculator`(30자), 6-1과 동일. `Doughmetry: Sourdough Calculator`는 32자라 한도를 넘어 ASC가 저장을 거부한다. 홈 화면 이름은 그대로. |
| TestFlight에 앱이 안 보임 | 아이폰 Apple 계정 ≠ 초대한 ASC 사용자 이메일. 5-4로 그 이메일을 사용자로 초대하고 그룹에 추가. TestFlight 재설치는 소용없음. |
| TestFlight `테스트에 사용할 수 없음 (Not Available for Testing)` — provisioning profile missing an application identifier | 와일드카드/ad-hoc 프로파일로 서명됨. `TestFlight & App Store` + 자동 서명으로 재업로드. |
| `ITMS-90338 Non-public API usage` | 순수 SwiftUI·서드파티 SDK 없음이라 드묾. 손상된 업로드가 대부분 — `Clean Build Folder`, 빌드 번호 올려 재아카이브·재업로드. 나열된 셀렉터가 내 메서드명과 같으면 그 메서드 이름 변경. |
| `ITMS-90683 Missing purpose string` (NSPhotoLibraryUsageDescription 등) | 이 앱은 PhotosPicker(out-of-process)만 써서 해당 없음이 검증됨. 나중에 카메라 촬영을 추가하면 `Build Settings > Info.plist Values > Privacy - Camera Usage Description`(`INFOPLIST_KEY_NSCameraUsageDescription`)에 한/영 문장 추가. |
| `ITMS-90474 iPad Multitasking support requires these orientations` | iPad 지원(`TARGETED_DEVICE_FAMILY = "1,2"`)이라 `UISupportedInterfaceOrientations~ipad`에 네 방향이 모두 있어야 한다 — `project.pbxproj`의 `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad`(Debug·Release). 0장 "한 번에 확인"의 `~ipad` 줄로 확인. iPhone 키(세로만)는 그대로 둔다. |
| `ITMS-90725 SDK version issue` (iOS 26 SDK 필요) | Xcode 27.0 = iOS 27.0 SDK라 해당 없음. 다른 Mac의 구형 Xcode로 아카이브할 때만. |
| Organizer에서 아카이브가 `Other Items` 아래 | 스킴의 Archive 액션이 앱을 만들지 못함. `Product > Scheme > Edit Scheme… > Archive > Build Configuration: Release`, 대상이 `Any iOS Device`인지 확인. |
| Issue 내비게이터 노란 `Update to recommended settings` | IDE 전용 경고, 배포와 무관. 0-7. |
| 심사 `5.1.1` 개인정보 처리방침 | URL 404 또는 앱 내 링크 없음. 3장 URL 200 확인 + 0-1 앱 내 링크. 심사 메모(listing.md 심사 노트)에 데이터 미수집·온디바이스 처리·사용자 본인 iCloud만 사용이 들어 있다. |
| 심사 `2.1` 크래시/미완성 | 리뷰어 기기가 iOS 18이거나 iPad(가로·Split View)일 수 있음 → 0-9의 3·4·6번(iOS 17/18·iPad) + TestFlight 실기기 확인. 크래시 로그는 Organizer > Crashes(심볼 업로드 켰으므로 읽을 수 있음). |
| 심사 `2.3` 메타데이터 부정확 | 설명이 앱에 없는 기능을 암시하거나("찍거나", 확인할 수 없는 비교·AI 표현 — 0-10에서 정정), 스크린샷이 지금 앱과 다른 경우(옛 UI·다른 언어 화면). 6-6에 listing.md 현재 값이 그대로 들어갔는지, 스크린샷에 찍힌 화면이 지금 빌드와 같은지(0-13 첫 단락) 확인. |
| iOS 17/18 기기에서 `Symbol not found … FoundationModels` | 검증상 발생하지 않음(전부 weak-import). 만약 발생하면 프로젝트 `Frameworks, Libraries` 목록에 FoundationModels가 `Required`로 수동 추가된 것 — 제거(자동 링크만 유지). |

---

## 부록 A. 처음부터 끝까지 체크리스트

- [ ] 고정값 표: 심사 연락처 전화번호를 `+82 10-____-____` 자리에 국제 형식으로 채우기 (6-7에서 그대로 옮겨 적는다) · 공개 문의 이메일 결정 — 기본 `juvesoul@icloud.com`, 바꾸려면 표의 `grep`·`sed`
- [ ] 0장 도입부: 작업 트리 깨끗함 · origin과 같음 · Vitest·tsc·DoughmetryCore 테스트 통과
- [ ] 0장 "한 번에 확인": 0-1 앱 안 개인정보·지원 링크 · 0-2 PrivacyInfo.xcprivacy · 0-3 암호화 키 · UIDeviceFamily `[1,2]` · iPad 네 방향 · 경고 0건
- [ ] 0-9 iOS 17/18 UI 테스트(타깃 전체) 통과 (iPhone SE iOS17 · iPhone 15 iOS18 · iPad Air iOS18) + 손 확인 — 통과 못 하면 최소 버전 18.0으로 (0-9 5번)
- [ ] 0-9 6번 iPad 시뮬레이터 세로·가로·최소 창·Split View 확인
- [x] 0-10 listing.md 문구 — 2026-10-02 정정 완료 (6장에서 listing.md를 그대로 붙여 넣기만)
- [x] 0-13 스크린샷 — 2026-10-28 그때 UI로 다시 찍음 (`{ko,en}/6.9-jpg/`·`{ko,en}/13-jpg/` 각 7장, hasAlpha no, 다른 언어·테스트 이름 없음). 그 뒤 스크린샷에 찍힌 화면을 바꾸면 다시 (0-13 첫 단락)
- [x] 0-11 커밋 (2026-10-28 ec00018 — 푸시는 3)
- [ ] 1-1 약관 배너 없음 · 1-2 Xcode 계정에 `Kiyoung Ha (G46DT9WHWV)` · 1-4 Signing & Capabilities 빨간 표시 없음 · 1-5 EU DSA 트레이더 신고 완료
- [x] 2 ASC 앱 레코드 — 2026-10-28 새로 만듦: `도우메트리: 사워도우 계산기`, 번들 ID `com.narudoc.doughmetry`, SKU `doughmetry`, Apple ID `6827977830`
- [ ] 3 푸시 → privacy.html·support.html 200 **+ 사이트 루트가 `/doughmetry/assets/…`와 새 `<title>`을 내려주는지** (루트 200만으로는 판단 불가)
- [ ] 4-1 직전 `ios/AppStore/preflight.sh repo` 통과
- [ ] 4-1 Archive → 4-2 Validate 통과 → 4-3 Distribute (`TestFlight & App Store`) → 처리 완료 메일
- [ ] 4-4 수출 규정 (키 넣었으면 질문 없음)
- [ ] 5 내부 그룹 `Narudoc` → 내 아이폰(있으면 아이패드도) TestFlight 설치 → 실기기 체크리스트
- [ ] 6-1 앱 정보 (이름·부제: 한국어·영어(미국)·영어(영국)·영어(캐나다), 카테고리, 콘텐츠 권한) · 6-2 연령 등급 4+ · 6-3 무료, Mac·Vision Pro 제공 여부 결정 · 6-4 App Privacy 게시 + 처리방침 URL(네 현지화)
- [ ] 6-5 스크린샷: 네 현지화 × iPhone 6.9형·iPad 13형 (영어 셋은 같은 `en/` 세트, 미리 채워진 한국어 스크린샷 지우기) · 6-6 텍스트 네 현지화 (키워드는 KR·EN-US·EN-GB·EN-CA 따로) · 6-7 빌드·저작권·심사 메모·수동 출시 · 6-8 빨간 점 없음 + 영어 세 현지화에 한국어가 남지 않음
- [ ] 6-9 심사에 추가 → 심사를 위해 제출
- [ ] 7-2 승인 후 `이 버전 출시`

## 부록 B. 이 문서가 근거로 삼은 검증 사실 (요약)

- 2026-10-02: Xcode 27.0 (27A266a), iOS 27.0 SDK. HEAD 82df6d6 기준 시뮬레이터 Release 빌드 경고 0건(2026-10-01 점검). 그 뒤 변경분은 0장 "한 번에 확인"으로 다시 본다. 시뮬레이터 런타임은 iOS 17.5·18.2·26.5·27.0(2026-10-02) — iOS 17/18 실행 확인은 0-9.
- 바이너리: arm64, minOS 17.0, 네트워킹·암호화 프레임워크 링크 없음, FoundationModels는 weak link. 생성 Info.plist에 `INFOPLIST_KEY_*` 빌드 설정이 그대로 들어간다(`ITSAppUsesNonExemptEncryption => false`, `UIDeviceFamily [1,2]`, `UISupportedInterfaceOrientations~ipad` 네 방향 — 2026-10-02 Debug 시뮬레이터 빌드로 확인).
- `ios/Doughmetry/`는 폴더 동기화 그룹 — `PrivacyInfo.xcprivacy`를 두기만 하면 .app 루트에 복사된다.
- 0-13 스크립트(2026-10-02, `prepare`·`shot`으로): iPhone 17 Pro Max(en)는 1320×2868, iPad Pro 13-inch (M5)(ko)는 2064×2752로, 둘 다 RGB·hasAlpha no로 찍히고 상태 바 9:41·앱 언어·시스템 언어가 적용됨을 확인. 한글 가져오기 예시도 시뮬레이터 클립보드에 그대로 들어간다. 예시 library.json(ko·en)은 DoughmetryCore `LibraryStore`로 버려지는 항목 없이 읽힌다(레시피 3·로그 4).
- Xcode 관리 프로파일 2종 확인(2026-09-11): 2026-09-06 16:05 = `com.narudoc.levaincalc`(개명으로 무효), 2026-09-11 08:28 = `com.narudoc.doughmetry` + `iCloud.com.narudoc.doughmetry` 엔타이틀먼트 3종 → 새 App ID·새 컨테이너 포털 등록 완료.
- 앱 아이콘: (옛 아이콘) RGBA 소스와 RGB 소스로 각각 컴파일한 `Assets.car`가 SHA-256까지 동일 → 알파 문제 없음. 2026-10-22 교체(397b51f) 뒤 소스는 RGB(알파 없음), 컴파일된 AppIcon은 Opaque(2026-10-28 확인).
- 키체인에 Apple Distribution 인증서 없음 → 자동 서명이 클라우드 인증서를 만들도록 둔다.
- 스토어 현지화: 한국 스토어는 한국어 + 영어(영국), 미국·일본만 영어(미국), 캐나다는 영어(캐나다) + 프랑스어(캐나다)를 색인한다 (Apple, App Store localizations 표).
- node는 `~/.local/node/bin`(PATH 미등록) — `export PATH="$HOME/.local/node/bin:$PATH"`.
