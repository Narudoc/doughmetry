# 도우메트리: 사워도우 계산기 — App Store 첫 출시 가이드 (Xcode 프로젝트 → TestFlight → 심사 제출)

기준일: 2026-09-06 작성 · 2026-09-11 Doughmetry 개명 반영(번들 ID `com.narudoc.doughmetry`, iCloud 컨테이너 `iCloud.com.narudoc.doughmetry`, 저장소·Pages `doughmetry`, 스토어 이름) · Xcode 26.6 (17F113, iOS 26.5 SDK) · 프로젝트 `ios/LevainCalc.xcodeproj`(타깃·폴더 이름은 호환성 때문에 `LevainCalc` 유지) · 이전 체크리스트를 이 문서로 대체함.

날짜를 붙이지 않은 "확인됨/검증됨" 서술은 2026-09-06 기준이다. 그중 서명·프로비저닝·iCloud 컨테이너·ASC 레코드 항목은 옛 번들 ID `com.narudoc.levaincalc` 기준이라 개명으로 근거가 무효가 됐고, 09-11에 다시 확인한 항목에는 본문에 날짜를 적어 두었다(고정값 표·0-12·1-4·3장 도입부·8장·부록 B). 2장의 2026-09-10과 5장 6번의 2026-09-11은 재확인 날짜가 아니라 각각 ASC 레코드를 만든 날짜와 번들 ID를 바꾼 날짜다.

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
| 최소 iOS | 17.0, iPhone 전용, 세로 방향만 |
| 스토어 이름 | KR `도우메트리: 사워도우 계산기` (15자) / EN `Doughmetry: Sourdough Calc` (26자) — 2026-09-11 결정. ASC에는 2026-09-10에 `사워도우 브레드 계산기`(번들 ID `com.narudoc.levaincalc`)로 만든 레코드가 있으므로 2장에서 이름·번들 ID를 바꾼다. App Store 검색·웹에 `Doughmetry`/`도우메트리` 앱·제품 없음 확인(2026-09-11). |
| 홈 화면 이름 (CFBundleDisplayName) | KR `도우메트리` / EN `Doughmetry` — 브랜드명만. 홈 화면 라벨은 한글 약 8자·영문 약 14자를 넘으면 잘리므로(실측) 설명어는 붙이지 않는다. 스토어 제목과 달라도 된다(비슷하면 됨). |
| SKU | `levaincalc` |
| 기본 언어 | 한국어 |
| 카테고리 | 주 `음식 및 음료 (Food & Drink)` / 부 `유틸리티 (Utilities)` |
| 가격 | 무료 (Tier 0), 전 지역 |
| 연령 등급 | 4+ (설문 전부 "없음") |
| App Privacy | `데이터가 수집되지 않음 (Data Not Collected)` — 6-4에서 "아니요, 이 앱에서는 데이터를 수집하지 않습니다"로 답하고 게시 |
| 개인정보 처리방침 URL | `https://narudoc.github.io/doughmetry/privacy.html` (3장에서 만든다; 저장소 개명 후 첫 푸시·배포가 끝나야 살아난다) |
| 지원 URL | `https://github.com/Narudoc/doughmetry/issues` 또는 `https://narudoc.github.io/doughmetry/support.html` |
| 마케팅 URL (선택) | `https://narudoc.github.io/doughmetry/` |
| 공개 문의 이메일 (privacy.html · support.html · 지원 연락처) | 실제로 확인하는 주소 **하나**로 통일. 이 문서의 기본값은 `juvesoul@icloud.com`. `juvesoul@gmail.com`(git 설정 주소)으로 하려면 3-1 파일을 만든 직후 `cd /Users/narudoc/Claude/Doughmetry && sed -i '' 's/juvesoul@icloud.com/juvesoul@gmail.com/g' public/privacy.html ios/AppStore/privacy-policy.md` 실행 — 0-13에서 `screenshots/`로 디렉터리를 옮겨 온 상태라 `cd` 없이 붙여 넣으면 실패한다. md까지 같이 바꾸는 이유는 3-1 3번의 "세 곳 동일" 원칙(3-2 7번의 임시 개인정보 URL이 이 md의 GitHub 렌더링이다) 때문이고, 세 번째 곳인 3-1 1번 heredoc의 `문의:`·`Contact:` 두 줄은 이 문서를 열어 손으로 고친다 — `submission.md`를 `sed`에 넣지 말 것(고정값 표·1장·4~6장의 `juvesoul@icloud.com`은 Apple 계정이라 바뀌면 안 된다). 3-1 2번의 `support.html`까지 만들었다면 명령 끝에 `public/support.html`을 덧붙이고 그 heredoc의 `mailto:` 줄도 같이 고친다. |
| 심사 연락처 (App Review Information) | 이름(First) `Kiyoung` / 성(Last) `Ha` / 전화 `+82 10-____-____` ← **지금 채워 둘 것.** 국제 형식 필수 — `+`와 국가번호 없이 숫자만 넣으면 저장 거부. 이메일은 위 Apple 계정. |
| 저작권 (Copyright) | `2026 Kiyoung Ha` — ASC는 권리 보유자 이름을 요구하므로 개발 팀 이름과 맞춘다. 필명도 쓰려면 `2026 Kiyoung Ha (Narudoc)`. © 기호는 자동. |
| 스크린샷 | `ios/AppStore/screenshots/{ko,en}/6.9-jpg/01-calculator.jpg … 06-timeline.jpg` (1320×2868, 6.9형) — 0-13에서 PNG를 JPEG로 변환해 만든다 |

## 전체 흐름과 예상 소요 시간

| 단계 | 내용 | 소요 |
|---|---|---|
| 0 | 프로젝트 정리 (privacy manifest, 암호화 키, 앱 내 개인정보 링크, 스크린샷 JPEG 변환) | 30분 |
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

## 0. 아카이브 전 프로젝트 준비 (감사 결과 반영)

프로젝트를 코드 서명 없이 Release 빌드해 본 결과(BUILD SUCCEEDED, 경고 1건 = AppIntents 메타데이터 생략, 무해) 바이너리 자체는 문제없다. 아래는 감사에서 **실제로 확인된** 항목만 모은 것이다. 감사에서 반박(불필요로 판정)된 세 항목(앱 아이콘 알파 채널·iCloud App ID/컨테이너 등록·권한 문구/푸시 엔타이틀먼트)은 0-12에 "조치 불필요"로 적어 두었고, 스크린샷 알파 채널만 예외라 그 뒤 0-13([필수])에서 JPEG로 바꾼다.

먼저 작업 트리를 확인한다.

1. 터미널에서 `cd /Users/narudoc/Claude/Doughmetry && git status --short` 실행.
2. 2026-09-11 개명 작업 때문에 20개 파일이 `M` 상태다: `CLAUDE.md README.md index.html package.json package-lock.json vite.config.ts src/App.tsx src/components/recipes/RecipesPage.tsx src/components/ui/Dialog.tsx ios/README.md ios/AppStore/{listing,privacy-policy,submission}.md ios/LevainCalc.xcodeproj/project.pbxproj ios/LevainCalc/LevainCalc.entitlements ios/LevainCalc/{ko,en}.lproj/InfoPlist.strings ios/LevainCalc/RecipesView.swift ios/LevainCalc/ResultViews.swift ios/LevainCore/Sources/LevainCore/Models.swift`. 이 중 `ResultViews.swift`·`Dialog.tsx`는 2026-09-06의 "저장 시트에서 이름을 바꾸면 덮어쓰기 토글 자동 해제" 수정이고(시뮬레이터·브라우저 동작 확인, `tsc`·Vitest 58개 통과), 나머지 18개는 개명 반영이다(`Models.swift`는 주석의 웹앱 이름 한 줄) — **전부 0-11에서 함께 커밋한다.** (로컬 node는 `~/.local/node/bin`에 있다 — `export PATH="$HOME/.local/node/bin:$PATH"` 후 `npm test`.)

### 0-1. [필수] 앱 안에 개인정보 처리방침 링크 추가 (심사 지침 5.1.1(i))

바이너리를 바꾸는 유일한 항목이라 **아카이브 전에** 넣는다. URL 자체는 3장에서 공개한다.

1. Xcode에서 `ios/LevainCalc/RecipesView.swift`를 열고 `struct SettingsSheet` 안의 `Form { … }`에서 마지막 `Section`(`표시 자릿수` Picker가 있는 것)을 찾는다. 그 Section의 닫는 `}` 바로 뒤, `Form`의 닫는 `}` 앞에 다음을 붙여 넣는다.

   ```swift
                Section {
                    Link(L("개인정보 처리방침"),
                         destination: URL(string: "https://narudoc.github.io/doughmetry/privacy.html")!)
                }
   ```

   붙여 넣은 뒤 그 부분은 이렇게 보여야 한다.

   ```swift
                } footer: {
                    Text(L("내부 계산은 항상 full precision — 반올림은 표시에만 적용됩니다."))
                }
                Section {
                    Link(L("개인정보 처리방침"),
                         destination: URL(string: "https://narudoc.github.io/doughmetry/privacy.html")!)
                }
            }
            .navigationTitle(L("설정"))
   ```

2. `ios/LevainCalc/Localization.swift`를 열고 `private let en: [String: String] = [` 딕셔너리 안, `"iCloud 동기화": "iCloud sync",` 줄(274행 부근) 아래에 한 줄 추가한다.

   ```swift
    "개인정보 처리방침": "Privacy Policy",
   ```

3. Xcode 툴바 실행 대상(destination)을 아무 iPhone 시뮬레이터로 두고 `⌘B`. 빌드 성공 확인.

### 0-2. [필수] PrivacyInfo.xcprivacy 추가

앱이 `UserDefaults`/`@AppStorage`를 쓰므로(AppModel.swift, CloudSync.swift, Localization.swift, TimelineView.swift, ToolsView.swift) Apple의 "required-reason API" 선언이 필요하다. 없으면 업로드마다 `ITMS-91053 Missing API declaration` 메일이 온다. Apple 공식 정책(2024-05-01부터)은 필수 사유 선언이 없는 업로드를 받지 않는다는 것이고, 실제로는 경고 메일로 그치는 경우가 많지만 보장이 없으므로 아카이브 전에 반드시 넣는다. 다른 required-reason API(파일 타임스탬프, 부팅 시간, 디스크 용량, 키보드 목록)는 바이너리에 없음이 확인됐으므로 UserDefaults 한 항목만 선언하면 된다.

프로젝트가 `PBXFileSystemSynchronizedRootGroup`(폴더 동기화 그룹)이라 **`ios/LevainCalc/` 폴더에 파일만 두면 자동으로 타깃에 포함되고 .app 루트로 복사된다** (검증 완료). pbxproj 수정 불필요.

방법 A — 파일 직접 생성 (가장 확실):

1. 터미널에서 아래를 그대로 실행한다.


```bash
cat > /Users/narudoc/Claude/Doughmetry/ios/LevainCalc/PrivacyInfo.xcprivacy <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
EOF
plutil -lint /Users/narudoc/Claude/Doughmetry/ios/LevainCalc/PrivacyInfo.xcprivacy
```

2. 출력이 `... OK`이면 끝. Xcode 프로젝트 내비게이터의 LevainCalc 폴더에 파일이 자동으로 나타난다.

방법 B — Xcode 템플릿: 프로젝트 내비게이터에서 `LevainCalc` 그룹 선택 → 메뉴 `File > New > File from Template…` (`⌘N`) → 상단 `iOS` 탭 → `Resource` 섹션 → `App Privacy` → `Next` → 이름 `PrivacyInfo` 그대로(확장자 자동), `Targets: LevainCalc` 체크 → `Create` → 편집기에서 `Privacy Accessed API Types` 항목 추가 → `Privacy Accessed API Type` = `User Defaults`, `Privacy Accessed API Reasons` = `CA92.1`. `Privacy Tracking Enabled` = NO, 나머지 배열은 비워 둔다.

`CA92.1` = "앱 자신만 접근 가능한 정보를 읽고 쓰기 위해 UserDefaults 사용" — 이 앱에 맞는 사유(앱 그룹·확장 없음).

### 0-3. [권장 — 안 하면 빌드마다 수출 규정 질문] ITSAppUsesNonExemptEncryption = NO

앱에 네트워킹·암호화 코드가 전혀 없고(URLSession, CryptoKit, Security 프레임워크 링크 없음 확인) iCloud Documents는 OS 제공 암호화이므로 값은 `NO`가 맞다. 이 키가 없으면 업로드한 빌드마다 TestFlight에 `규정 준수 누락 (Missing Compliance)`이 떠서 수동으로 답해야 한다 (답하는 법은 4-4에 있으니 빠뜨려도 막히진 않는다).

Info.plist는 빌드 시 생성되므로(`GENERATE_INFOPLIST_FILE = YES`, 소스 Info.plist 없음) **빌드 설정**으로 넣는다.

방법 A — Xcode UI:

1. 프로젝트 내비게이터 맨 위 파란 아이콘 `LevainCalc` 클릭 → 가운데 편집기에서 `TARGETS > LevainCalc` 선택 → `Build Settings` 탭.
2. 필터 버튼을 `All` + `Combined`로 두고 검색창에 `Non-Exempt` 입력.
3. `Info.plist Values` 그룹의 `App Uses Non-Exempt Encryption` 행 값을 `No`로 바꾼다 (Combined 상태에서 바꾸면 Debug/Release 모두 적용. `Levels`로 전환해 두 열 모두 `NO`인지 확인).

방법 B — 텍스트 편집: `ios/LevainCalc.xcodeproj/project.pbxproj`에서 `INFOPLIST_KEY_CFBundleDisplayName = "Doughmetry";` 줄이 **두 번**(Debug 블록 205행 부근, Release 블록 233행 부근) 나온다. 각 줄 바로 아래에 다음 한 줄을 추가한다 (알파벳 순서 유지).

```
				INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;
```

검증 (0-1~0-3을 한 번에):

1. Xcode에서 시뮬레이터 대상으로 `⌘B` 한 번.
2. 터미널:

   ```bash
   APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/LevainCalc-*/Build/Products/Debug-iphonesimulator/LevainCalc.app | head -1)
   plutil -p "$APP/Info.plist" | grep ITSApp        # => "ITSAppUsesNonExemptEncryption" => 0
   ls "$APP/PrivacyInfo.xcprivacy"                  # 파일이 있어야 함
   ```

### 0-4. [선택] 빌드 번호 전략 하나로 정하기

`project.pbxproj`의 `CURRENT_PROJECT_VERSION = 1`과 `ios/AppStore/archive.sh`의 타임스탬프(`date +%Y%m%d%H%M`, 예 `202609061830`) 두 방식이 공존한다. 둘 다 "빌드 번호 자동 관리"가 켜져 있어 충돌은 자동 보정되지만, 첫 출시는 **GUI(Xcode Organizer)만** 쓰기로 정한다. 규칙:

1. 업로드할 때마다 `TARGETS > LevainCalc > General > Identity > Build` 값을 `1`, `2`, `3`… 으로 손으로 올린다 (`Version`은 `1.0` 유지).
2. Organizer 배포 시 "Manage Version and Build Number"는 절대 끄지 않는다 (기본 흐름에서는 보이지도 않고 자동 적용).
3. 나중에 CLI(`archive.sh`)를 섞어 쓸 때 안전한 순서는 GUI 먼저 → CLI. CLI(타임스탬프) 뒤에 GUI(빌드 1)를 자동 관리 없이 올리면 `ITMS-90061`로 거부된다.

### 0-5. [적용됨] 홈 화면 이름은 브랜드명만

스토어 제목(`도우메트리: 사워도우 계산기` / `Doughmetry: Sourdough Calc`)을 그대로 홈 화면 라벨로 쓰면 잘린다(한글 약 8자·영문 약 14자 한계, 시뮬레이터 실측). 그래서 `ko.lproj/InfoPlist.strings`·`en.lproj/InfoPlist.strings`의 `CFBundleDisplayName`/`CFBundleName`은 `도우메트리` / `Doughmetry`로 두었다. 심사와 무관(스토어 제목과 비슷하면 됨).
### 0-6. [선택] Info.plist에 카테고리 넣기

iOS에서는 카테고리를 ASC에서 고르므로 필수 아님. 넣고 싶으면 `Build Settings` 검색 `Application Category` → `Info.plist Values > Application Category` = `Food & Drink` (pbxproj에 `INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.food-and-drink";`가 Debug/Release 두 블록에 추가됨).

### 0-7. [선택] "Update to recommended settings" 경고 없애기

프로젝트가 `LastUpgradeCheck = 1600`이라 Issue 내비게이터(`⌘5`)에 노란 항목이 뜬다. 아카이브·업로드·심사에 영향 없음. 없애려면 프로젝트 선택 → 메뉴 `Editor > Validate Settings…` → 제안 항목(Enable Recommended Warnings, String Catalog Symbol Generation 등 — Swift 동시성 설정은 건드리지 않음) 확인 → `Perform Changes`. 생기는 pbxproj diff는 따로 커밋.

### 0-8. [선택] 스킴 공유

`xcshareddata/xcschemes`가 없지만 Xcode GUI와 `xcodebuild` 모두 메모리에서 스킴을 자동 생성하므로 이 Mac에서는 문제 없음. `xcodebuild -list`를 치면 `Schemes:` 아래가 비어 보이지만 정상이다 — `-scheme LevainCalc`를 넘기면 빌드된다(2026-09-06 확인). `archive.sh`도 같은 이유로 그대로 동작한다. Xcode Cloud/fastlane을 쓸 계획이 생기면: `Product > Scheme > Manage Schemes…` → `LevainCalc` 행 `Shared` 체크 → 생성된 `ios/LevainCalc.xcodeproj/xcshareddata/xcschemes/LevainCalc.xcscheme` 커밋.

### 0-9. [선택, 권장] iOS 17/18에서 실행 확인

FoundationModels(iOS 26 전용)는 weak link + `#available(iOS 26.0, *)` 가드가 전부 확인돼 iOS 17/18에서 크래시하지 않는다(바인딩 57개 전부 weak-import). 다만 이 Mac에는 iOS 26.5 시뮬레이터만 있어서 실제로 돌려 본 적은 없다. 10분이면 확인 가능:

1. `Xcode > Settings… (⌘,) > Components` 탭 → `Platform Support` 섹션 왼쪽 아래 `+` → `iOS` → `iOS 18.5 Simulator` (또는 17.5) → `Download`. CLI 대안: `xcodebuild -downloadPlatform iOS -buildVersion 18.5`.
2. `xcrun simctl list runtimes`로 식별자 확인 후 `xcrun simctl create "iPhone 16 (18.5)" "iPhone 16" com.apple.CoreSimulator.SimRuntime.iOS-18-5`.
3. 그 시뮬레이터로 실행 → 앱 실행됨 / 레시피 탭 사진·텍스트 가져오기가 규칙 파서로 동작하며 확인 다이얼로그가 뜸 / 사진 선택기 열림 / 도구 탭 타임라인 알림 예약됨 — 네 가지 확인.

### 0-10. [적용됨] listing.md 문구 정정 (기록용)

바이너리와 무관한 문서 작업이고 이미 끝나 있다 — 6장에서 붙여 넣을 `listing.md`가 수정 후 값이다.

**2026-09-11에 아래 5건은 이미 적용됐다** — `listing.md`를 그대로 6장에 붙여 넣으면 된다. 기록용으로 남긴다.

1. ~~20행: `레시피를 찍거나 붙여넣으면` → `레시피 사진을 고르거나 텍스트를 붙여넣으면`~~ (앱에 카메라 촬영 경로가 없고 사진 선택기만 있음) — 적용 완료.
2. ~~32행: `snap or paste a recipe…` → `choose a photo of a recipe…, or paste the text`~~ — 적용 완료.
3. ~~24행: `아이폰·아이패드 간 레시피와 로그가` → `기기 간 레시피와 로그가`~~ (iPhone 전용 앱) — 적용 완료.
4. ~~52행: `6.7"` → `6.9" 1320×2868`~~ — 적용 완료.
5. ~~8행: `르방 변환·베이커스 % ·베이킹 로그` → `르방 변환·베이커스 %·베이킹 로그`~~ (`%` 뒤 공백 제거) — 적용 완료.
6. (참고) `screenshots/{ko,en}/*.png`는 iPhone 17 Pro 캡처 1206×2622(6.3형)이고, 6.9형 1320×2868은 `{ko,en}/6.9/` 폴더의 sips 업스케일본이다.

### 0-11. 커밋

1. **먼저 0-13(스크린샷 JPEG 변환)을 끝내고 여기로 돌아온다** — 0-13이 만드는 `ios/AppStore/screenshots/{ko,en}/6.9-jpg/` 12장을 이 커밋에 함께 담기 위해서다(부록 A 체크리스트도 0-13 → 0-11 순서다). 그다음 `cd /Users/narudoc/Claude/Doughmetry && git add -A` — 0-13이 셸을 `ios/AppStore/screenshots/`에 남겨 두므로 `cd`를 붙인다(안 붙여도 `git add -A`는 저장소 전체에 동작하지만 `git status --short`의 경로가 `../../../vite.config.ts`처럼 보여 아래 예시와 달라진다). 0장 도입부의 `M` 파일 20개, 0-1에서 추가로 고친 `ios/LevainCalc/Localization.swift`(21번째 `M`), 그리고 0-2·0-13에서 새로 만든 파일(`ios/LevainCalc/PrivacyInfo.xcprivacy`, `ios/AppStore/screenshots/{ko,en}/6.9-jpg/`)을 한 번에 올린다. `.gitignore`가 `node_modules/`·`dist/`·`ios/build/`·`xcuserdata`를 막으므로 안전하다. 개별로 넣겠다면 **`vite.config.ts`(Pages base)와 `ios/LevainCalc/LevainCalc.entitlements`(iCloud 컨테이너)를 절대 빠뜨리지 말 것** — 빠지면 3-2 푸시 후 `narudoc.github.io/doughmetry/`가 옛 `/levain-calc/` 경로로 애셋을 찾아 빈 화면이 된다. `git add` 후에는 `git diff --name-only`(스테이지 안 된 수정)와 `git status --short | grep '^??'`(빠뜨린 새 파일)가 둘 다 아무것도 출력하지 않아야 한다. `git status --short`에 `M`이 보이는 것은 정상이다 — 첫 칸은 스테이지 상태, 둘째 칸이 작업 트리 상태라서 스테이지된 파일은 `M  vite.config.ts`처럼 첫 칸 `M`으로 계속 표시된다.
2. `git commit -m "출시 준비 — Doughmetry 개명 반영(Pages base·번들 ID·iCloud 컨테이너), privacy manifest, 암호화 면제 키, 앱 내 개인정보 링크"`.
3. 아직 `push`는 하지 않는다 — 3장에서 privacy.html과 함께 한 번에 푸시한다.

### 0-12. 조치 불필요로 확인된 항목 (참고)

- **앱 아이콘 알파 채널**: 소스 PNG는 RGBA지만 픽셀 전부 불투명이고, 실제 업로드되는 `Assets.car`는 RGB로 변환해 컴파일해도 바이트 단위로 동일함이 확인됐다. `ITMS-90717`은 발생하지 않는다. 손대지 말 것. (4-2의 Validate App이 최종 확인.)
- **iCloud App ID/컨테이너 등록 (2026-09-11 재확인)**: 2026-09-06 16:05 프로파일은 옛 번들 ID `com.narudoc.levaincalc`(컨테이너 `iCloud.com.narudoc.levaincalc`) 것이라 개명 후에는 근거가 되지 않는다. 개명 뒤 Xcode가 **2026-09-11 08:28에 새 프로파일 `iOS Team Provisioning Profile: com.narudoc.doughmetry`(UUID `963f121d-931f-4fc1-be5b-24d48474e678`)를 발급**했고, 그 엔타이틀먼트의 `icloud-container-identifiers`·`ubiquity-container-identifiers`·`icloud-container-development-container-identifiers` 3종이 모두 `iCloud.com.narudoc.doughmetry`다. 포털에 없는 컨테이너는 프로파일에 담기지 못하므로 이것이 등록 증거다 → **새 App ID·새 컨테이너 모두 포털 등록 완료**, 1-4는 확인만 하면 된다. `LevainCalc.entitlements`는 이미 새 컨테이너로 고쳐져 있으니 값만 확인하고 `icloud-container-environment`나 `aps-environment`를 **추가하지 말 것**.
- **권한 문구(NSPhotoLibrary/NSCamera)·푸시 엔타이틀먼트**: PhotosPicker(out-of-process)와 로컬 알림만 써서 불필요. 추가하면 오히려 심사 질문거리.
- **스크린샷**은 예외 — 알파 채널 때문에 그대로는 거부될 수 있으므로 0-13에서 JPEG로 바꾼다.

### 0-13. [필수] 스크린샷 알파 채널 제거 (JPEG 변환)

Apple 스크린샷 규격은 "이미지에 알파 채널이나 투명도를 포함할 수 없다"고 명시한다. `sips -g hasAlpha`로 확인하면 `{ko,en}/6.9/*.png` 12장이 전부 `hasAlpha: yes`다 — 픽셀이 불투명해도 채널이 있으면 ASC가 거부할 수 있다. 업로드 전에 JPEG로 바꿔 둔다(2026-09-06 검증, 2026-09-13 재확인: 변환 후 1320×2868 유지, `hasAlpha: no`, 장당 0.4~0.7 MB — 12장 합계 약 7 MB).

```bash
cd /Users/narudoc/Claude/Doughmetry/ios/AppStore/screenshots
for lang in ko en; do
  mkdir -p "$lang/6.9-jpg"
  for f in "$lang"/6.9/*.png; do
    sips -s format jpeg -s formatOptions best "$f" --out "$lang/6.9-jpg/$(basename "${f%.png}").jpg" >/dev/null
  done
done
sips -g pixelWidth -g pixelHeight -g hasAlpha ko/6.9-jpg/01-calculator.jpg   # 1320 / 2868 / no
```

PNG 원본은 그대로 두고(다시 변환할 때 필요) `6.9-jpg/` 12장을 6-5에서 올린다.

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

1. **확인만 하면 된다 (2026-09-11 등록 완료).** 번들 ID가 `com.narudoc.doughmetry`로 바뀌자(2026-09-11 08:28:16 스크립트가 `LevainCalc.entitlements`·`project.pbxproj`를 디스크에서 수정, 프로젝트는 Xcode에 열려 있던 상태) Xcode 자동 서명(Update Signing)이 한 번의 실행으로 새 iCloud 컨테이너 `iCloud.com.narudoc.doughmetry`(포털 ID `F5PQF9M9GU`)를 만들고 App ID `XC com narudoc doughmetry`에 iCloud capability로 연결한 뒤 08:28:21에 프로파일을 발급했다 — `Containers`의 `+`를 누른 적도, 기기 빌드도 없었다(DerivedData `Logs/Update Signing/80028A71-….xcactivitylog`에 `POST /v1/cloudContainers` → `POST /v1/bundleIds` → `/v1/profiles` 순서로 기록됨). 2026-09-11 08:28 발급 프로파일 `iOS Team Provisioning Profile: com.narudoc.doughmetry`에 `application-identifier = G46DT9WHWV.com.narudoc.doughmetry`, `icloud-container-identifiers`·`ubiquity-container-identifiers = iCloud.com.narudoc.doughmetry`가 들어 있다. `https://developer.apple.com/account/resources/identifiers/list` 에서 `com.narudoc.doughmetry` 행(Xcode가 붙인 이름 `XC com narudoc doughmetry`, 포털 ID `VH5G2ZZ8QK`)과 `iCloud Containers` 목록의 `iCloud.com.narudoc.doughmetry`를 눈으로 확인만 한다. 옛 `com.narudoc.levaincalc` App ID와 `iCloud.com.narudoc.levaincalc` 컨테이너는 그대로 두어도 무해하다 — 다만 옛 컨테이너의 데이터는 새 앱으로 넘어오지 않는다. 포털(`developer.apple.com`)에서 새로 만들 필요는 없다 — 이미 등록돼 있고, 포털에서 만든 컨테이너도 Xcode가 새로고침으로 읽어 올 뿐 충돌하지 않는다.
2. Xcode: 프로젝트 `LevainCalc` → `TARGETS > LevainCalc` → `Signing & Capabilities` 탭 → 필터 `All`(또는 `Release`):
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

0. **기존 레코드 수정** — 2026-09-10에 `사워도우 브레드 계산기` / `com.narudoc.levaincalc`로 만든 레코드가 있다. 빌드를 올리기 전이라 이름·번들 ID 모두 바꿀 수 있다: `앱 > 사워도우 브레드 계산기 > 앱 정보 (App Information)` → 현지화 가능한 정보의 `이름`을 `도우메트리: 사워도우 계산기`로 → 일반 정보의 `번들 ID`를 드롭다운에서 `com.narudoc.doughmetry`로 → `저장`. SKU `levaincalc`는 바꿀 수 없지만 어디에도 보이지 않는다. 굳이 바꾸려면 빌드가 없는 지금 앱을 삭제하고 아래 1~5로 새로 만들되, 삭제한 앱의 이름과 SKU는 같은 조직에서 재사용할 수 없으므로(ASC 도움말 "Remove an app") 3번의 SKU를 `doughmetry` 등 새 값으로 넣는다. 영어 이름 `Doughmetry: Sourdough Calc`는 6-1에서 넣을 때 중복 검사를 받는다. **이 단계를 건너뛰면 새 번들 ID의 빌드가 이 레코드에 붙지 못해 업로드가 `No suitable application records were found`로 실패한다(8장). 어떤 레코드든 빌드가 한 번 올라가면 그 레코드의 번들 ID는 영구 고정되므로 업로드 전에 여기서 맞춰 둔다.** 아래 1~5는 새로 만들 때의 절차.
1. `https://appstoreconnect.apple.com` → `앱 (Apps)` 클릭.
2. 왼쪽 위 `+` → `신규 앱 (New App)`.
3. 대화상자 입력:
   - `플랫폼 (Platforms)`: `iOS`만 체크.
   - `이름 (Name)`: `도우메트리: 사워도우 계산기` 입력. (2~30자, App Store 전체에서 고유. 홈 화면 이름 `CFBundleDisplayName`은 `도우메트리`만 — 고정값 표 참고.)
   - `기본 언어 (Primary Language)`: `한국어 (Korean)`.
   - `번들 ID (Bundle ID)`: 드롭다운에서 `com.narudoc.doughmetry`가 붙은 항목(예 `XC com narudoc doughmetry - com.narudoc.doughmetry`) 선택. **`Xcode: Wildcard AppID - *`는 절대 선택하지 말 것.** 목록에 없으면 1-4-1로 돌아가 App ID가 있는지 확인하고 페이지를 새로고침.
   - `SKU`: `levaincalc`.
   - `사용자 액세스 권한 (User Access)`: `전체 액세스 (Full Access)`. 팀에 다른 사용자가 없으면 이 항목이 회색으로 잠겨 있거나 아예 안 보인다 — 그대로 둔다.
4. `생성 (Create)` 클릭. 이름 중복 검사는 이 시점에 일어난다. `The App Name you entered is already being used`가 뜨면 이름만 바꿔 다시 `생성`.
5. 앱 목록에 `도우메트리: 사워도우 계산기`가 `제출 준비 중 (Prepare for Submission)` 상태로 생기면 성공. SKU는 이 시점부터 바꿀 수 없고, 번들 ID는 첫 빌드를 올리기 전까지만 `앱 정보 (App Information) > 일반 정보`에서 바꿀 수 있다(0번 참고) — 첫 빌드 업로드 후에는 영구 고정된다.
6. 영어 이름은 나중에 6장에서 `영어(미국) (English (U.S.))` 현지화를 추가하면서 넣는다.

---

## 3. 개인정보 처리방침·지원 URL 공개

**이 장을 끝내지 않으면 심사에서 5.1.1로 거절된다** (개인정보 처리방침 URL은 필수 입력이고, ASC는 URL 형식만 검사하지만 심사관이 실제로 열어 본다 — 404면 메타데이터 거절). 현재 상태: 저장소를 2026-09-11에 `doughmetry`로 개명했고 `vite.config.ts`의 `base`도 `/doughmetry/`로 바꿨지만 아직 푸시 전이다. 개명 덕에 `https://narudoc.github.io/doughmetry/`는 **이미 200을 돌려주지만 내용은 옛 배포본**이라 `/levain-calc/assets/*.js`(404)를 가리키는 빈 화면이다(2026-09-11 확인) — 상태 코드만 보고 배포가 끝났다고 판단하지 말 것. 정작 필요한 `/doughmetry/privacy.html`은 아직 404이고 첫 푸시·배포가 끝나야 살아난다(옛 `/levain-calc/` 주소는 이제 404). 작업 트리의 변경 20개는 아직 커밋 전이므로 0-11에서 전부 커밋해야 이 주소들이 제대로 뜬다.

계획: 웹앱 저장소의 `public/` 폴더(Vite가 그대로 `dist/`로 복사, `base` 무관)에 정적 HTML을 넣고 푸시 → GitHub Actions(`deploy.yml`)가 자동 배포 → `https://narudoc.github.io/doughmetry/privacy.html`.

### 3-1. privacy.html 만들기

감사에서 나온 문구 수정 6가지(iCloud가 **기본 켜짐**이라는 점, 끄는 위치가 iOS 설정이 아니라 앱 내 설정이라는 점, 보관·삭제 안내 추가, 공유 항목에 배합표 텍스트 추가, 웹 버전 설명 추가, 문의 주소 통일)를 반영한 완성본이다. 문의 이메일은 고정값 표의 결정대로(기본 `juvesoul@icloud.com`, gmail로 바꾸려면 표의 `sed` + 아래 heredoc의 `문의:`·`Contact:` 두 줄).

1. 터미널에서 실행:


```bash
mkdir -p /Users/narudoc/Claude/Doughmetry/public
cat > /Users/narudoc/Claude/Doughmetry/public/privacy.html <<'EOF'
<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>개인정보 처리방침 · 도우메트리 / Privacy Policy · Doughmetry</title>
<style>
  body { max-width: 720px; margin: 2rem auto; padding: 0 1.25rem; font: 16px/1.65 -apple-system, "Pretendard", system-ui, sans-serif; color: #22271F; background: #F5F2EA; }
  h1 { font-size: 1.5rem; } h2 { font-size: 1.2rem; margin-top: 2.5rem; border-top: 1px solid #D9D3C4; padding-top: 1.25rem; }
  li { margin: .4rem 0; } small { color: #555; }
</style>
</head>
<body>
<h1>개인정보 처리방침 / Privacy Policy<br><small>도우메트리 (Doughmetry) — 사워도우 계산기 iOS 앱 및 웹 버전</small></h1>
<p><small>최종 갱신 / Last updated: 2026-09-11</small></p>

<h2>한국어</h2>
<p><strong>도우메트리</strong>는 개인정보를 수집하지 않습니다.</p>
<ul>
  <li>계정·로그인이 없습니다. 이메일, 이름, 위치 등 어떤 개인정보도 요구하거나 저장하지 않습니다.</li>
  <li>레시피, 베이킹 로그, 메모는 <strong>사용자의 기기 안</strong>에만 저장됩니다.</li>
  <li>iCloud 동기화는 기기가 iCloud에 로그인되어 있으면 <strong>기본으로 켜져</strong> 있으며, 같은 데이터가 <strong>사용자 본인의 iCloud 계정</strong>(Apple의 iCloud Documents)에 저장되어 기기 간에 동기화됩니다. 개발자는 이 데이터에 접근할 수 없습니다. 동기화는 앱 안의 <em>레시피 탭 → 설정</em>에서 언제든 끌 수 있습니다.</li>
  <li>AI 레시피 가져오기(사진·텍스트 인식)는 <strong>기기 내부(Apple Vision · Apple Intelligence)</strong>에서만 처리됩니다. 사진이나 텍스트가 외부 서버로 전송되지 않습니다.</li>
  <li>분석 도구, 광고 SDK, 추적 기술을 사용하지 않습니다.</li>
  <li>알림(타임라인 단계 알림)은 기기의 로컬 알림만 사용하며 서버를 거치지 않습니다.</li>
  <li>내보내기·공유(레시피 JSON, 배합표 텍스트)는 사용자가 직접 공유 시트로 보낼 때만 기기 밖으로 나갑니다.</li>
  <li>보관·삭제: 앱에서 레시피나 로그를 삭제하면 기기에서, 그리고 동기화 중이면 iCloud에서도 삭제됩니다. 앱을 삭제하면 기기 안의 모든 데이터가 삭제됩니다. iCloud에 남은 사본은 iOS 설정 → (내 이름) → iCloud → 저장 공간 관리에서 지울 수 있습니다. 앱 안에서 동기화를 끄는 것만으로는 iCloud의 사본이 삭제되지 않습니다.</li>
</ul>
<p><strong>웹 버전</strong>(narudoc.github.io/doughmetry)은 데이터를 브라우저의 로컬 저장소에만 보관하며 서버로 보내지 않습니다. 사진 인식 기능을 처음 사용할 때 인식 라이브러리와 언어 데이터를 CDN에서 내려받지만, 사진 자체는 브라우저 안에서만 처리됩니다.</p>
<p>문의: juvesoul@icloud.com</p>

<h2>English</h2>
<p><strong>Doughmetry</strong> does not collect personal data.</p>
<ul>
  <li>No account or sign-in. We never ask for or store your email, name, location, or any other personal information.</li>
  <li>Recipes, bake logs, and notes are stored <strong>only on your device</strong>.</li>
  <li>iCloud sync is <strong>on by default</strong> when your device is signed in to iCloud; the same data is then stored in <strong>your own iCloud account</strong> (Apple's iCloud Documents) and synced between your devices. The developer cannot access it. You can turn sync off at any time in the app under <em>Recipes → Settings</em>.</li>
  <li>AI recipe import (photo and text recognition) runs <strong>entirely on your device</strong> (Apple Vision · Apple Intelligence). Photos and text are never sent to a server.</li>
  <li>No analytics, ad SDKs, or tracking technologies.</li>
  <li>Timeline alerts use local notifications only — no server involved.</li>
  <li>Exported or shared data (recipe JSON, recipe-sheet text) leaves the device only when you share it yourself.</li>
  <li>Retention and deletion: deleting a recipe or log in the app removes it from the device and, if sync is on, from iCloud. Deleting the app removes all local data. Any remaining iCloud copy can be removed in iOS Settings → (your name) → iCloud → Manage Storage. Turning sync off in the app does not delete the copy stored in iCloud.</li>
</ul>
<p>The <strong>web version</strong> (narudoc.github.io/doughmetry) keeps data only in your browser's local storage and sends nothing to a server. The first time you use photo recognition it downloads the recognition library and language data from a CDN, but the photo itself is processed inside your browser.</p>
<p>Contact: juvesoul@icloud.com</p>
</body>
</html>
EOF
```

2. (선택) 지원 페이지도 같은 방식으로 `public/support.html`을 만든다. 없어도 `https://github.com/Narudoc/doughmetry/issues`가 지원 URL로 동작한다(저장소 공개 확인됨). 만들 경우 내용: 앱 이름, 문의 이메일, 이슈 페이지 링크, 웹앱 링크 네 줄이면 된다.


```bash
cat > /Users/narudoc/Claude/Doughmetry/public/support.html <<'EOF'
<!doctype html>
<html lang="ko">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>지원 · 도우메트리 / Support · Doughmetry</title>
<style>body{max-width:720px;margin:2rem auto;padding:0 1.25rem;font:16px/1.65 -apple-system,system-ui,sans-serif;color:#22271F;background:#F5F2EA}</style></head>
<body>
<h1>도우메트리 지원 / Doughmetry Support</h1>
<p>문의·버그 신고 / Questions and bug reports: <a href="mailto:juvesoul@icloud.com">juvesoul@icloud.com</a></p>
<p>GitHub Issues: <a href="https://github.com/Narudoc/doughmetry/issues">github.com/Narudoc/doughmetry/issues</a></p>
<p>웹 버전 / Web version: <a href="https://narudoc.github.io/doughmetry/">narudoc.github.io/doughmetry</a></p>
<p><a href="privacy.html">개인정보 처리방침 / Privacy Policy</a></p>
</body></html>
EOF
```

3. `ios/AppStore/privacy-policy.md`는 2026-09-11 개명 작업에서 위 heredoc과 **같은 문구로 이미 갱신해 뒀다 — 그대로 둔다**(기본 켜짐 iCloud · 앱 내 *레시피 탭 → 설정*에서 끄기 · 보관·삭제 · 배합표 텍스트 공유 · 웹 버전 문단 · 갱신일 2026-09-11). **본문을 "정식 문서는 …" 링크 한 줄로 비우지 말 것** — 3-2의 7번이 이 파일의 GitHub 렌더링을 Pages 배포 전 임시 개인정보 URL로 쓰기 때문에, 비우면 그 임시 URL이 빈 껍데기가 된다. 앞으로 문구를 고칠 때는 위 1번의 heredoc·`public/privacy.html`·이 md **세 곳을 반드시 함께** 고친다.

### 3-2. 푸시·배포·확인

1. `cd /Users/narudoc/Claude/Doughmetry && git status --short`로 남은 변경을 확인한 뒤 `git add -A && git commit -m "개인정보 처리방침·지원 페이지 공개 (GitHub Pages)"`. 0-11을 건너뛰었다면 **`vite.config.ts`(`base: '/doughmetry/'`)가 반드시 이 커밋에 들어가야 한다** — 빠진 채 푸시하면 Actions가 옛 base로 빌드해 `index.html`이 `/levain-calc/assets/*.js|css`를 가리키고 사이트가 빈 화면이 된다(`public/privacy.html`은 정적 패스스루라 200으로 살아 있어서 아래 `curl`로는 못 잡는다). `package.json`과 `package-lock.json`은 함께 커밋한다 — 이번 변경은 양쪽 다 `name` 필드뿐이라 한쪽만 올려도 `npm ci`는 통과하지만(확인함), 의존성이 바뀐 커밋에서 한쪽만 올리면 lock 불일치로 실패하므로 습관을 들인다.
2. 푸시 전 로컬 확인: `export PATH="$HOME/.local/node/bin:$PATH" && npx vitest run && npm run build && grep -o '/doughmetry/assets/[^"]*' dist/index.html | head -1` — `/doughmetry/assets/...`가 나와야 한다. **단 `vite build`는 작업 트리의 `vite.config.ts`를 읽으므로 이 빌드로는 1번의 커밋 누락을 잡지 못한다.** 커밋에 실제로 들어갔는지는 HEAD를 직접 본다: `git show HEAD:vite.config.ts | grep "base:"`가 `base: '/doughmetry/',`를 출력해야 하고, 옛 `/levain-calc/`가 나오면 `git add vite.config.ts && git commit --amend --no-edit`으로 넣는다. `git show HEAD:ios/LevainCalc/LevainCalc.entitlements | grep -c doughmetry`도 0이 아니어야 한다.
3. `git push origin main`. 로컬에만 있던 커밋들(iOS Phase 1/2, App Store 문서, 스크린샷 약 10 MB)이 함께 공개 저장소에 올라간다 — 의도된 것. 웹 변경은 2번에서 `tsc`·Vitest 통과를 확인했으므로 CI(vitest + build)가 실패할 이유가 없다.
4. `https://github.com/Narudoc/doughmetry/actions` 에서 `Deploy to GitHub Pages` 실행이 초록색이 될 때까지 기다린다(1~2분).
5. 확인 (네 줄 모두 — 앞 두 줄은 새 정적 페이지, 뒤 두 줄은 **사이트 루트**다. 루트는 개명 직후부터 옛 배포본으로 이미 200을 돌려주므로 상태 코드만으로는 배포 성공을 판단할 수 없다):

   ```bash
   curl -sI https://narudoc.github.io/doughmetry/privacy.html | head -1   # HTTP/2 200
   curl -sI https://narudoc.github.io/doughmetry/support.html | head -1   # (만들었다면) 200
   curl -s https://narudoc.github.io/doughmetry/ | grep -o '/doughmetry/assets/[^"]*' | head -1
   # → /doughmetry/assets/index-XXXXXXXX.js 가 나와야 한다
   curl -s https://narudoc.github.io/doughmetry/ | grep -o '<title>[^<]*</title>'
   # → <title>도우메트리 · Doughmetry — 사워도우 계산기</title>
   ```

   뒤 두 줄이 비었거나 옛 값(`/levain-calc/assets/…`, `르방 계산기 · levain-calc`)이 나오면 `vite.config.ts`·`index.html`이 푸시된 커밋에 빠졌거나 Actions 배포가 실패한 것이다 — 루트는 200이지만 스크립트가 404라 빈 화면이 되고 마케팅 URL로 쓸 수 없다. 커밋 누락 여부는 2번과 같은 방식으로 HEAD **트리**를 본다: `git show HEAD:vite.config.ts | grep "base:"`가 `base: '/doughmetry/',`를, `git show HEAD:index.html | grep -o '<title>[^<]*</title>'`가 새 제목을 출력해야 한다(`git show --stat HEAD`는 마지막 커밋 하나의 변경 파일만 보여 주므로 쓰지 말 것 — 두 파일은 0-11 커밋에 들어 있어 3-2 1번 커밋의 stat에는 안 나오는 게 정상이다). 두 값이 모두 새 값인데도 옛 배포본이 내려오면 커밋 누락이 아니라 배포 문제이므로 4번의 Actions 실행 로그(`npm ci`·vitest·build·deploy 중 실패 단계)와 저장소 Settings → Pages의 Source가 `GitHub Actions`인지 확인한다. 옛 값이 나오면 `git add vite.config.ts index.html && git commit -m "Pages base 수정" && git push origin main` 후 4번부터 반복한다.

6. Safari에서 **세 URL(privacy.html · support.html · 사이트 루트)**을 열어 앞 두 개는 한국어·영어 본문이, 루트는 빈 화면이 아니라 계산기 화면이 뜨는지 눈으로 확인. **위 네 줄이 모두 통과하기 전에는 ASC에 URL을 입력하지 말 것** — 루트 주소는 개명 직후부터 200이므로 판단 기준으로 쓰지 말고 반드시 `privacy.html` 본문이 보이는지로 확인한다.
7. 급하게 URL이 먼저 필요하면 푸시 직후부터 `https://github.com/Narudoc/doughmetry/blob/main/ios/AppStore/privacy-policy.md`도 열리지만(GitHub 장식이 붙음), Pages URL로 곧 교체할 것.

---

## 4. Xcode 아카이브 → 업로드

### 4-1. 아카이브

1. `open /Users/narudoc/Claude/Doughmetry/ios/LevainCalc.xcodeproj`.
2. 툴바 스킴이 `LevainCalc`인지 확인. 실행 대상 드롭다운 → `Any iOS Device (arm64)` 선택 (메뉴 `Product > Destination > Any iOS Device`).
3. `TARGETS > LevainCalc > General > Identity`: `Version` = `1.0`, `Build` = `1` 확인 (두 번째 업로드부터는 `Build`를 올린다, 0-4).
4. 메뉴 `Product > Archive`. Release 구성으로 빌드된다(수 분). 첫 아카이브에서 macOS 키체인/Apple 계정 인증 창이 뜨면 허용.
5. 끝나면 Organizer가 자동으로 열린다 (안 열리면 `Window > Organizer`, `⌥⇧⌘O`) → 왼쪽 `Archives` → 방금 만든 `LevainCalc 1.0 (1)` 항목이 `iOS Apps` 아래 있는지 확인 (`Other Items` 아래면 스킴 아카이브 설정 문제, 8장).
6. 아카이브 내용 검증 (선택이지만 첫 번은 권장):

   ```bash
   ARCHIVE=$(ls -td ~/Library/Developer/Xcode/Archives/*/*.xcarchive | head -1); echo "$ARCHIVE"
   plutil -p "$ARCHIVE/Products/Applications/LevainCalc.app/Info.plist" | grep -E 'ITSApp|CFBundleVersion|CFBundleShortVersionString|MinimumOSVersion'
   ls "$ARCHIVE/Products/Applications/LevainCalc.app/PrivacyInfo.xcprivacy"
   ```

   기대값: `ITSAppUsesNonExemptEncryption => 0`, `CFBundleVersion => "1"`, `CFBundleShortVersionString => "1.0"`, `MinimumOSVersion => "17.0"`, PrivacyInfo.xcprivacy 존재.

7. (선택) Organizer에서 아카이브 우클릭 → `Generate Privacy Report` → `User Defaults / CA92.1` 항목이 보이면 0-2 정상.

### 4-2. Validate App (업로드 없이 ITMS 검사)

1. Organizer에서 아카이브 선택 → 오른쪽 `Validate App` 클릭.
2. `TestFlight & App Store` 기본 선택 그대로 → `Validate`.
3. 처음이면 클라우드 서명 인증서 생성 동의 창이 뜰 수 있다 → 진행. 2FA 코드 요청이 오면 입력.
4. 몇 분 뒤 `App "LevainCalc" successfully validated`가 나오면 통과. 오류가 나오면 8장에서 코드(ITMS-xxxxx)로 찾는다.

### 4-3. Distribute App (업로드) — GUI 경로 (권장)

1. Organizer에서 같은 아카이브 선택 → `Distribute App`.
2. `Select a method for distribution` 시트에서 **`TestFlight & App Store`** 선택 → `Distribute`. (`TestFlight Internal Only`를 고르면 그 빌드는 영영 App Store에 못 붙이니 고르지 말 것. Xcode 버전에 따라 `App Store Connect`로 표시될 수 있음.)
3. 이 기본 흐름은 추가 질문 없이: 빌드 번호 자동 관리 → 클라우드 Apple Distribution 인증서로 재서명 → .ipa + dSYM 업로드 → 완료 화면(ASC 링크 포함)까지 진행한다. 1~5분.
4. 완료 화면에서 `Done`. 몇 분 내에 `juvesoul@icloud.com`으로 "The following build has completed processing" 메일이 온다 (보통 5~30분, 바쁠 때 1~2시간; 24시간 넘으면 비정상).
5. 메일에 `ITMS-91053` 경고가 섞여 있으면 0-2를 빠뜨린 것 — 빌드는 그래도 처리된다. 다음 업로드 전에 추가.

`Custom` 경로 (모든 선택지를 직접 보고 싶을 때): `Distribute App > Custom > App Store Connect > Next > Upload > Next` → 옵션 `Upload your app's symbols` 켬, `Manage Version and Build Number` 켬, `TestFlight internal testing only` **끔**, `Strip Swift symbols` 켬 → `Next` → `Automatically manage signing` → `Next` → 요약(번들 ID, 1.0 (1), 엔타이틀먼트에 iCloud 컨테이너 표시) 확인 → `Upload`.

### 4-3-alt. CLI 경로 (archive.sh)

GUI 대신 쓸 수 있다. 같은 Apple 계정이 Xcode에 로그인돼 있어야 한다(`-allowProvisioningUpdates`가 그 계정을 쓴다).

1. `cd /Users/narudoc/Claude/Doughmetry/ios && ./AppStore/archive.sh` — 빌드 번호를 `date +%Y%m%d%H%M`(예 `202609061830`)으로 넣고 `xcodebuild archive` → `-exportArchive`(`AppStore/ExportOptions.plist`: `method=app-store-connect`, `destination=upload`, `signingStyle=automatic`, `teamID=G46DT9WHWV`, `uploadSymbols=true`, `manageAppVersionAndBuildNumber=true`)까지 실행한다. 빌드 번호를 지정하려면 `./AppStore/archive.sh 2`.
2. 종료 코드 0이면 ASC가 패키지를 받은 것. 이후 처리 과정은 GUI와 같다.
3. 참고: `-allowProvisioningUpdates`는 자동 서명 타깃의 프로파일·App ID·인증서를 만들고 갱신한다(Apple 문서). 다만 iCloud 컨테이너까지 만들어 주는지는 확인하지 않았으므로, 1-4처럼 Xcode GUI 서명이 한 번 해결된 상태(지금이 그 상태)에서 쓰는 것이 안전하다.
4. .ipa만 만들고 Transporter 앱으로 올리려면 `ExportOptions.plist`의 `destination`을 `export`로 바꿔 실행 → `ios/build/export/LevainCalc.ipa` → Mac App Store의 `Transporter`(Apple, 무료) → 같은 Apple 계정 로그인 → `+`로 .ipa 추가 → 초록 체크 → `Deliver`.

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
   - 계산기: 재료 입력 → 하단 요약(총 수분율·PFF·총 무게) 즉시 반영, 배합표 시트 공유.
   - 변환: 리퀴드↔뒤흐 변환 후 보존 지표 체크.
   - 레시피: 사진 선택 → 가져오기 확인 다이얼로그 → 저장. Apple Intelligence가 꺼진 기기에서도 규칙 파서로 동작.
   - 레시피 탭 → 설정: `iCloud 동기화` 켜짐, 상태 `마지막 동기화 …`. 두 번째 기기(또는 앱 삭제 후 재설치)에서 **이번에 새로 저장한** 레시피가 내려오는지 — 컨테이너가 `iCloud.com.narudoc.doughmetry`로 새로 바뀌었으므로 개명 전 데이터가 하나도 안 보이는 것이 정상이다(동기화 실패가 아니다).
   - 설정 맨 아래 `개인정보 처리방침` 링크 → Safari에서 3장 페이지가 열림 (0-1 확인).
   - 도구: 타임라인 알림 권한 요청 → 알림 도착.
   - 다크 모드, 영어 전환.
8. 빌드는 업로드 90일 후 `만료됨 (Expired)`이 된다. 스토어 버전에는 영향 없다.

---

## 6. 버전 페이지 작성 (1.0)

앱 수준 정보(6-1~6-4)를 먼저 채우고 버전 페이지(6-5~6-9)를 채운다. 각 페이지는 오른쪽 위 `저장 (Save)`을 눌러야 반영된다. 언어 전환은 각 페이지 오른쪽 위 언어 드롭다운.

### 6-1. 앱 정보 (App Information)

`앱 > 도우메트리: 사워도우 계산기 > 왼쪽 사이드바 일반 (General) > 앱 정보 (App Information)`.

1. `현지화 가능한 정보 (Localizable Information)` — 한국어:
   - `이름 (Name)`: `도우메트리: 사워도우 계산기`
   - `부제목 (Subtitle)`: `르방 변환·베이커스 %·베이킹 로그` (19자)
2. 오른쪽 위 언어 드롭다운 → `+` 또는 목록에서 `영어(미국) (English (U.S.))` 추가 → 영어:
   - `이름`: `Doughmetry: Sourdough Calc` (26자 — 30자 한도). 중복이면 브랜드 `Doughmetry`는 두고 설명어만 바꾼다 — `Doughmetry: Levain Calc`(23자), `Doughmetry — Levain Calculator`(30자). 브랜드를 뺀 옛 이름(`Levain Calc` 등)으로 되돌아가지 않는다.
   - `부제목`: `Levain & baker's % calculator` (29자 — 30자 한도)
3. `일반 정보 (General Information)`:
   - `번들 ID`: `com.narudoc.doughmetry` (자동), `SKU`: `levaincalc` (자동), `Apple ID`: 자동 번호.
   - `기본 언어 (Primary Language)`: `한국어`.
   - `카테고리 (Category)`: `기본 (Primary)` = `음식 및 음료 (Food & Drink)`, `보조 (Secondary)` = `유틸리티 (Utilities)`.
   - `콘텐츠 권한 (Content Rights)`: `콘텐츠 권한 정보 설정 (Set Up Content Rights Information)` → `아니요, 타사 콘텐츠를 포함·표시·접근하지 않습니다 (No, it does not contain, show, or access third-party content)` → `완료 (Done)`. (앱이 배포하는 타사 콘텐츠는 없다. 사용자가 직접 가져오는 레시피는 기기 안에만 있다.)
   - `연령 등급 (Age Rating)`: 6-2.
   - `사용권 계약 (License Agreement)`: Apple 표준 EULA 그대로.
4. `저장`.

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
5. 같은 페이지의 `Apple Silicon Mac의 iPhone 및 iPad 앱 (iPhone and iPad Apps on Apple Silicon Macs)`과 `Apple Vision Pro의 iPhone 및 iPad 앱`은 기본 켜짐 — 그대로 둬도 된다 (`기기 간` 문구가 오히려 정확해진다). 끄고 싶으면 체크 해제.
6. `저장`.

### 6-4. 앱 개인정보 보호 (App Privacy) — 라벨 + 처리방침 URL

`사이드바 일반 (General) > 앱 개인정보 보호 (App Privacy)`.

1. 맨 위 `개인정보 처리방침 (Privacy Policy)` 블록 → `편집 (Edit)`:
   - `개인정보 처리방침 URL (Privacy Policy URL)`: `https://narudoc.github.io/doughmetry/privacy.html` (3-2에서 200 확인한 것)
   - `사용자 개인정보 선택 URL (User Privacy Choices URL)`: 비움
   - 언어 드롭다운으로 `영어(미국)`으로 바꿔 같은 URL 입력 → `저장`.
2. `데이터 수집 (Data Collection)` 블록 → `시작하기 (Get Started)` → "귀하 또는 타사 파트너가 이 앱에서 데이터를 수집합니까?" → **`아니요, 이 앱에서는 데이터를 수집하지 않습니다 (No, we do not collect data from this app)`** → `저장`.
3. `게시 (Publish)` → 확인 창 `앱 개인정보 보호 응답을 게시하시겠습니까?` → `게시`. 스토어 라벨이 `데이터가 수집되지 않음 (Data Not Collected)`으로 표시된다. **저장만 하고 게시하지 않으면 버전 페이지에 빨간 미완료 표시가 남는다.**
   - 근거: Apple 정의의 "수집"은 개발자/파트너가 접근 가능한 형태로 기기 밖으로 전송하는 것. iCloud Documents 데이터는 사용자 본인 iCloud에만 있고 개발자 접근 불가, 분석·광고·계정 없음. 바이너리에 네트워킹 심볼이 없음이 확인됨.

### 6-5. 버전 페이지 — 스크린샷

`사이드바 iOS 앱 > 1.0 제출 준비 중 (1.0 Prepare for Submission)`. 언어 드롭다운은 `한국어`로 시작.

1. `미리보기 및 스크린샷 (App Previews and Screenshots)` → 탭 `iPhone 6.9형 디스플레이 (iPhone 6.9" Display)`.
2. Finder에서 `/Users/narudoc/Claude/Doughmetry/ios/AppStore/screenshots/ko/6.9-jpg/`(0-13에서 만든 JPEG)를 열어 `01-calculator.jpg`, `02-fiche.jpg`, `03-convert.jpg`, `04-import.jpg`, `05-bakelog.jpg`, `06-timeline.jpg`를 순서대로 드래그 (1320×2868, 최대 10장). 순서가 틀리면 썸네일을 드래그해 재배열.
3. 언어 드롭다운 → `영어(미국)` → 같은 탭에 `screenshots/en/6.9-jpg/` 6장 드래그.
4. 6.9형만 있으면 6.5형·6.3형은 ASC가 축소해 쓴다 — `{ko,en}/*.png`(1206×2622)는 올리지 않는다. iPad 탭은 iPhone 전용이라 나타나지 않거나 비워 둔다.
5. 썸네일에 빨간 `!`나 "alpha channel" 오류가 뜨면 PNG 원본을 올린 것 — 0-13의 JPEG로 다시 올린다.

### 6-6. 버전 페이지 — 텍스트 (listing.md, 0-10 수정 반영본)

한국어 먼저, 그다음 `영어(미국)`으로 바꿔 반복. `설명`과 `키워드`는 필수.

한국어:

1. `프로모션 텍스트 (Promotional Text)` (170자, 선택, 심사 없이 수정 가능):
   ```
   프랑스식 총 밀가루 기준 계산에 르방 리퀴드↔뒤흐 변환, 사진으로 레시피 가져오기, 베이킹 로그까지. 전부 무료, 오프라인.
   ```
2. `설명 (Description)` (4000자, 필수, 서식 없는 텍스트):
   ```
   사워도우를 진지하게 굽는 사람을 위한 계산기입니다.

   • 베이커스 퍼센트 계산기 — 재료를 입력하면 총 수분율·소금·PFF·총 반죽 무게를 즉시 계산. 목표 반죽 무게에서 역산하는 모드도 있습니다.
   • 르방 변환 — 리퀴드(100%)와 뒤흐(50%) 르방 사이를 변환하면서 총 수분율·총 밀가루·총 반죽 무게를 그대로 보존합니다. 다른 앱에는 없는 기능.
   • 사진으로 레시피 가져오기 — 책·인스타그램·블로그 레시피 사진을 고르거나 텍스트를 붙여넣으면 기기 안의 AI가 재료를 인식합니다. 저장 전에 확인·수정할 수 있습니다.
   • 베이킹 로그 — 레시피마다 구운 날짜·별점·메모를 남겨 다음 굽기에 참고하세요.
   • 도구 — 르방 빌드 역산(종+밀가루+물), 물 온도(DDT) 계산, 단계별 타임라인과 알림.
   • % 표기 전환 — 프랑스식 총 밀가루 기준 또는 익숙한 베이커스 퍼센트(첨가 밀가루 = 100%).
   • iCloud 동기화 — 기기 간 레시피와 로그가 자동으로 맞춰집니다.
   • 한국어·영어, 다크 모드, 완전 오프라인, 계정 없음, 광고 없음.
   ```
3. `키워드 (Keywords)` (100자 — Apple 문서는 100바이트라고 적지만 ASC 입력창은 글자 수로 센다. 아래 한국어 문자열은 39자/99바이트라 어느 기준이든 통과. 쉼표 뒤 공백 없이, 앱 이름 단어 반복 금지):
   ```
   사워도우,르방,베이커스퍼센트,수분율,빵,제빵,반죽,계산기,발효,홈베이킹
   ```
4. `지원 URL (Support URL)` (필수): `https://github.com/Narudoc/doughmetry/issues` (또는 `https://narudoc.github.io/doughmetry/support.html`).
5. `마케팅 URL (Marketing URL)` (선택): `https://narudoc.github.io/doughmetry/`.
6. `이 버전의 새로운 기능 (What's New)`: 첫 버전에는 필드가 없다 (1.0.1부터 필수).

영어(미국):

1. `Promotional Text`:
   ```
   French total-flour math, levain liquide↔dur conversion, import recipes from a photo, and a bake log. All free, all offline.
   ```
2. `Description`:
   ```
   A calculator for people who take sourdough seriously.

   • Baker's percentage calculator — enter ingredients and get total hydration, salt, PFF and total dough weight instantly. Or solve backwards from a target dough weight.
   • Levain converter — switch between liquid (100%) and stiff (50%) levain while preserving total hydration, total flour and dough weight. No other app does this.
   • Import from a photo — choose a photo of a recipe from a book, Instagram or a blog, or paste the text; on-device AI recognizes the ingredients. Review and edit before saving.
   • Bake log — record date, rating and notes for every bake.
   • Tools — levain build (chef + flour + water), water temperature (DDT), and a stage-by-stage timeline with alerts.
   • Percent display — French total-flour basis or classic baker's % (added flour = 100%).
   • iCloud sync — recipes and logs stay in step across your devices.
   • Korean & English, dark mode, fully offline, no account, no ads.
   ```
3. `Keywords`:
   ```
   sourdough,levain,bakers percentage,hydration,bread,baking,dough,calculator,starter,fermentation
   ```
4. `Support URL` / `Marketing URL`: 한국어와 동일.

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
   - `메모 (Notes)` (4000바이트, 선택이지만 꼭 쓸 것):
     ```
     - 계정·로그인 불필요. 모든 기능 오프라인 동작 (네트워크 요청 없음).
     - "사진으로 가져오기"는 기기 내 Apple Vision OCR + Apple Intelligence로 처리됩니다. Apple Intelligence 미지원 기기(iOS 17/18 또는 미지원 하드웨어/지역)에서는 규칙 기반 파서로 자동 폴백되며 기능은 동일하고 정확도만 차이 납니다.
     - iCloud는 사용자 본인의 iCloud Documents 컨테이너(iCloud.com.narudoc.doughmetry)만 사용하며 개발자 서버는 없습니다. iCloud 미로그인 상태에서도 앱은 정상 동작합니다.
     - 알림은 도구 탭 타임라인의 로컬 알림(UNUserNotificationCenter)만 사용합니다.
     - 테스트용 레시피: 계산기 탭에서 밀가루 1000, 물 700, 소금 20, 르방 200(리퀴드 100%)을 입력하면 총 수분율 72.7%, PFF 9.1%, 총 반죽 1920 g이 표시됩니다.

     - No account or sign-in. Everything works offline (the app makes no network requests).
     - "Import from photo" uses on-device Apple Vision OCR + Apple Intelligence; on devices without Apple Intelligence it falls back to a rule-based parser automatically (same feature, lower accuracy).
     - iCloud uses only the user's own iCloud Documents container; there is no developer server. The app works without an iCloud sign-in.
     - Notifications are local only (timeline stages in the Tools tab).
     - Test recipe: Calculator tab → flour 1000, water 700, salt 20, levain 200 (liquid, 100%) shows total hydration 72.7%, PFF 9.1%, total dough 1920 g.
     ```
     (수치 검산: 르방 200 g@100% → 르방 속 밀가루 100, 물 100. 총 밀가루 1100, 총 물 800 → 800/1100 = 72.73%, PFF 100/1100 = 9.09%, 총 반죽 1000+700+20+200 = 1920 g. 메모 전체 약 1.5 KB / 한도 4000바이트.)
   - `첨부 파일 (Attachment)`: 불필요.
4. `App Store 버전 출시 (App Store Version Release)`: 첫 출시는 **`이 버전을 수동으로 출시 (Manually release this version)`** 선택 — 승인 후 스토어 페이지를 확인하고 내가 원하는 시각에 공개. (자동 출시는 `앱 심사가 끝나면 자동으로 이 버전을 출시`.)
5. 오른쪽 위 `저장`.

### 6-8. 미완료 항목 점검

1. 사이드바와 각 섹션 제목의 빨간 점이 모두 사라졌는지 확인. 남아 있다면 대상: 스크린샷, 설명, 키워드, 지원 URL, 빌드, 저작권, 연락처, 앱 개인정보 보호(게시), 연령 등급, 가격, 콘텐츠 권한.
2. 영어 현지화도 스크린샷·설명·키워드가 비어 있지 않은지 (비어 있으면 기본 언어인 한국어가 대신 보이지만, 영어 이름을 등록했다면 채우는 것이 맞다).

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
2. `배포 준비됨`이 되면 아이폰 App Store에서 `도우메트리: 사워도우 계산기` 검색 → 페이지·스크린샷·`데이터가 수집되지 않음` 라벨·`Designed for iPhone` 표시 확인.
3. TestFlight 빌드는 그대로 90일 유지되지만 스토어 버전을 설치하면 TestFlight 설치본을 대체한다(데이터 유지).

### 7-3. 거절되면

1. ASC 사이드바 `앱 심사 (App Review)` 또는 상단 메시지의 Resolution Center에서 사유(지침 번호)를 읽는다.
2. `메타데이터 거절됨`: 스크린샷·설명·URL·심사 메모만 고치고 다시 제출 — 새 빌드 불필요.
3. `거절됨`(바이너리 문제): 코드 수정 → `Build`를 올려(0-4) 재아카이브·업로드 → 버전 페이지에서 빌드 교체 → 재제출.
4. 리뷰어 판단이 잘못됐다고 보면 같은 스레드에 `회신 (Reply)`으로 근거를 설명한다(예: "AI 기능은 온디바이스, 계정 불필요"). 조용히 재제출하는 것보다 스레드 회신이 빠르다.
5. 제출을 되돌리고 싶으면 `심사에서 제출 제거 (Remove Submission from Review)` → 상태 `개발자 거절됨 (Developer Rejected)` → 수정 후 다시 제출.

첫 제출에서 흔한 지침: `2.1` 크래시/미완성 (TestFlight 실기기 테스트로 예방), `5.1.1` 개인정보 처리방침 URL 없음/접속 불가 (3장), `1.5`·`2.3` 지원 URL에 연락처 없음·스크린샷이 앱과 다름, `2.3.7` 키워드에 다른 앱 이름, `4.0` 리뷰어 기기에서의 디자인 문제.

### 7-4. 업데이트(1.0.1 이후) 내는 법

1. 코드 수정 후 Xcode `TARGETS > LevainCalc > General > Identity`: `Version` = `1.0.1` (MARKETING_VERSION), `Build` = 이전보다 큰 수 (예 `2`). 빌드 번호는 항상 증가.
2. `Any iOS Device (arm64)` → `Product > Archive` → Organizer `Distribute App > TestFlight & App Store > Distribute` (4-3과 동일).
3. ASC → `앱 > 도우메트리: 사워도우 계산기` → 사이드바 `iOS 앱` 옆 `+` → `버전 또는 플랫폼 추가` → `iOS` → 버전 `1.0.1` → `생성`.
4. 새 버전 페이지: `이 버전의 새로운 기능 (What's New)` — **이때부터 필수**, 한국어·영어 각각 입력. 스크린샷·설명은 이전 버전에서 복사되므로 바뀐 것만 수정.
5. 처리 완료된 빌드를 `빌드 추가`로 선택 → `저장` → `심사에 추가` → `심사를 위해 제출`.
6. 스토어 이름·부제·키워드는 버전이 `제출 준비 중`일 때만 수정 가능. `심사 대기 중` 이후엔 제출 제거 후 수정.
7. TestFlight 그룹에 자동 배포가 켜져 있으니 업로드마다 내 아이폰에 새 빌드가 뜬다 — 제출 전에 한 번 설치해 본다.
8. 웹앱·iOS 공통 규칙(`CLAUDE.md`): 계산 규칙이나 레시피 스키마가 바뀌면 `dough.ts`↔`Dough.swift`, `storage.ts`↔`Codec.swift`를 함께 고치고 양쪽 테스트 통과 후 아카이브.

---

## 8. 자주 나는 오류와 해결

| 증상 | 원인 / 해결 |
|---|---|
| 업로드 후 메일 `ITMS-91053: Missing API declaration … NSPrivacyAccessedAPICategoryUserDefaults` | PrivacyInfo.xcprivacy 없음. 경고 메일로 그치고 빌드가 처리되는 경우가 많지만 Apple 정책상 거부될 수도 있으므로 0-2를 적용해 재아카이브·재업로드한다. 아카이브 후 `.xcarchive/Products/Applications/LevainCalc.app/PrivacyInfo.xcprivacy`가 있는지 확인. |
| TestFlight 빌드 `규정 준수 누락 (Missing Compliance)` / 빌드 추가 시 수출 규정 창 | `ITSAppUsesNonExemptEncryption` 키 없음. 4-4대로 `예 → 위 알고리즘 해당 없음`으로 답하면 즉시 해제. 근본 해결은 0-3. 키를 넣었는데도 뜨면 값이 Boolean `NO`가 아니라 문자열이거나 다른 타깃에 들어간 것 — `plutil -p … \| grep ITSApp`으로 `=> 0` 확인. |
| `ITMS-90717 Invalid App Store Icon … can't be transparent nor contain an alpha channel` | 이 프로젝트에선 **발생하지 않음이 검증됨**(컴파일된 Assets.car가 RGB 소스와 바이트 동일, Opaque=true). 그래도 뜨면: `Preview`로 `ios/LevainCalc/Assets.xcassets/AppIcon.appiconset/AppIcon.png` 열기 → `File > Export…` → `Format: PNG`, `Alpha` 체크 해제 → 같은 경로에 덮어쓰기 → `sips -g hasAlpha AppIcon.png`가 `no` → `Product > Clean Build Folder (⇧⌘K)` → 재아카이브. (ImageMagick은 이 Mac에 없음.) |
| 스크린샷 업로드 거부 (빨간 `!`, `IMAGE_TOOL_FAILURE`, "alpha channel") | PNG 원본에 알파 채널이 있어서다(픽셀은 불투명해도 채널이 있으면 거부). 0-13의 JPEG(`{ko,en}/6.9-jpg/`)를 올린다. 크기는 이미 6.9형 규격(1320×2868). |
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
| `ITMS-90474 iPad Multitasking support requires these orientations` | iPhone 전용(`TARGETED_DEVICE_FAMILY = 1`)이라 해당 없음. iPad를 켤 때만 네 방향 모두 지원(또는 deprecated된 `UIRequiresFullScreen`). |
| `ITMS-90725 SDK version issue` (iOS 26 SDK 필요) | Xcode 26.6 = iOS 26.5 SDK라 해당 없음. 다른 Mac의 구형 Xcode로 아카이브할 때만. |
| Organizer에서 아카이브가 `Other Items` 아래 | 스킴의 Archive 액션이 앱을 만들지 못함. `Product > Scheme > Edit Scheme… > Archive > Build Configuration: Release`, 대상이 `Any iOS Device`인지 확인. |
| Issue 내비게이터 노란 `Update to recommended settings` | IDE 전용 경고, 배포와 무관. 0-7. |
| 심사 `5.1.1` 개인정보 처리방침 | URL 404 또는 앱 내 링크 없음. 3장 URL 200 확인 + 0-1 앱 내 링크. 심사 메모에 "데이터 미수집, 온디바이스 AI, 사용자 본인 iCloud만 사용" 명시. |
| 심사 `2.1` 크래시/미완성 | 리뷰어 기기가 iOS 18 등일 수 있음. 0-9의 iOS 17/18 시뮬레이터 확인 + TestFlight 실기기 확인. 크래시 로그는 Organizer > Crashes(심볼 업로드 켰으므로 읽을 수 있음). |
| 심사 `2.3` 메타데이터 부정확 | 설명의 "찍거나"·"아이폰·아이패드 간"처럼 앱에 없는 기능 암시. 0-10에서 이미 정정됨 — 6-6에 listing.md 현재 값이 그대로 들어갔는지만 확인. |
| iOS 17/18 기기에서 `Symbol not found … FoundationModels` | 검증상 발생하지 않음(전부 weak-import). 만약 발생하면 프로젝트 `Frameworks, Libraries` 목록에 FoundationModels가 `Required`로 수동 추가된 것 — 제거(자동 링크만 유지). |

---

## 부록 A. 처음부터 끝까지 체크리스트

- [ ] 고정값 표: 심사 연락처 전화번호를 `+82 10-____-____` 자리에 국제 형식으로 채우기 (6-7에서 그대로 옮겨 적는다) · 공개 문의 이메일 결정 — 기본 `juvesoul@icloud.com`, gmail로 하려면 3-1 직후 표의 `sed` + heredoc 두 줄
- [ ] 0-1 앱 내 개인정보 처리방침 링크 (RecipesView.swift, Localization.swift)
- [ ] 0-2 `ios/LevainCalc/PrivacyInfo.xcprivacy` (UserDefaults / CA92.1)
- [ ] 0-3 `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` (Debug·Release)
- [x] 0-10 listing.md 문구 5곳 — 2026-09-11 적용 완료 (고칠 것 없음, 6장에서 listing.md를 그대로 붙여 넣기만)
- [ ] 0-13 스크린샷 JPEG 변환 (`{ko,en}/6.9-jpg/` 12장, hasAlpha no)
- [ ] 0-11 커밋
- [ ] 1-1 약관 배너 없음 · 1-2 Xcode 계정에 `Kiyoung Ha (G46DT9WHWV)` · 1-4 Signing & Capabilities 빨간 표시 없음 · 1-5 EU DSA 트레이더 신고 완료
- [ ] 2 ASC 기존 레코드 수정: 이름 `사워도우 브레드 계산기` → `도우메트리: 사워도우 계산기`, 번들 ID `com.narudoc.levaincalc` → `com.narudoc.doughmetry` (**첫 빌드 업로드 전에 반드시**)
- [ ] 3 `public/privacy.html` 푸시 → privacy.html 200 **+ 사이트 루트가 `/doughmetry/assets/…`와 새 `<title>`을 내려주는지** (루트 200만으로는 판단 불가)
- [ ] 4-1 Archive → 4-2 Validate 통과 → 4-3 Distribute (`TestFlight & App Store`) → 처리 완료 메일
- [ ] 4-4 수출 규정 (키 넣었으면 질문 없음)
- [ ] 5 내부 그룹 `Narudoc` → 내 아이폰 TestFlight 설치 → 실기기 체크리스트
- [ ] 6-1 앱 정보 (이름·부제 ko/en, 카테고리, 콘텐츠 권한) · 6-2 연령 등급 4+ · 6-3 무료 · 6-4 App Privacy 게시 + 처리방침 URL
- [ ] 6-5 스크린샷 ko/en 6장씩 · 6-6 텍스트 ko/en · 6-7 빌드·저작권·심사 정보·수동 출시 · 6-8 사이드바·섹션 빨간 점 없음 (영어 현지화 스크린샷·설명·키워드 포함)
- [ ] 6-9 심사에 추가 → 심사를 위해 제출
- [ ] 7-2 승인 후 `이 버전 출시`

## 부록 B. 이 문서가 근거로 삼은 검증 사실 (요약)

- Release 빌드(서명 없이) 성공, 경고 1건(AppIntents 메타데이터, 무해). 바이너리: arm64, minOS 17.0, SDK 26.5, 네트워킹·암호화 프레임워크 링크 없음, FoundationModels는 weak link.
- 생성형 Info.plist에 `INFOPLIST_KEY_*` 빌드 설정이 그대로 반영됨을 재빌드로 확인(`ITSAppUsesNonExemptEncryption`, `LSApplicationCategoryType`).
- `ios/LevainCalc/`는 폴더 동기화 그룹 — `PrivacyInfo.xcprivacy`를 두기만 하면 .app 루트에 복사됨(스크래치 빌드로 확인).
- Xcode 관리 프로파일 2종 확인(2026-09-11): 2026-09-06 16:05 = `com.narudoc.levaincalc`(개명으로 무효), 2026-09-11 08:28 = `com.narudoc.doughmetry` + `iCloud.com.narudoc.doughmetry` 엔타이틀먼트 3종 → 새 App ID·새 컨테이너 포털 등록 완료. 새 번들 ID로 서명된 기기 빌드는 아직 없다.
- 앱 아이콘: RGBA 소스와 RGB 소스로 각각 컴파일한 `Assets.car`가 SHA-256까지 동일 → 알파 문제 없음.
- 스크린샷 24장: 크기 정확(6.9형 1320×2868, 6.3형 1206×2622), 픽셀은 전부 불투명이지만 PNG에 알파 채널이 있음 → JPEG 변환 후 1320×2868·hasAlpha no 확인.
- 키체인에 Apple Distribution 인증서 없음 → 자동 서명이 클라우드 인증서를 만들도록 둔다.
- 저장소를 2026-09-11에 `doughmetry`로 개명(Pages `narudoc.github.io/doughmetry/`는 개명 직후부터 200이지만 옛 배포본 — 새 base 빌드와 `privacy.html`은 첫 푸시·배포 후에 뜬다), 저장소 공개, 로컬 main이 origin보다 앞섬, `public/` 없음. node는 `~/.local/node/bin`(PATH 미등록) — Vitest 58개·tsc 통과 확인.
