# 출시 절차 (개발자 프로그램 승인 후)

## 0. 확인
- Xcode → Settings → Accounts에 Apple ID가 있고, 팀 이름 옆에 "(Personal Team)"이 **사라져** 있으면 승인 완료.

## 1. iCloud 켜기 (1회)
1. `open ios/LevainCalc.xcodeproj`
2. 왼쪽 파란 아이콘 LevainCalc → TARGETS LevainCalc → **Signing & Capabilities**
3. **+ Capability** → **iCloud** 추가 → **iCloud Documents** 체크
4. Containers에서 **+** → `iCloud.com.narudoc.levaincalc` 입력 → 체크
   - Xcode가 `CODE_SIGN_ENTITLEMENTS`를 만든 entitlements 파일로 잡는다. 준비된 `LevainCalc/LevainCalc.entitlements`와 내용이 같으면 그대로, 다르면 Xcode가 만든 파일을 쓰면 된다.
5. 아이폰 두 대(또는 아이폰 + 시뮬레이터 iCloud 로그인)로 실행 → 설정 → iCloud 상태 "대기 중/마지막 동기화" 확인 → 한쪽에서 레시피 저장 → 다른 쪽에 나타나는지 확인

## 2. App Store Connect 앱 등록
1. https://appstoreconnect.apple.com → 나의 앱 → **+** → 신규 앱
2. 플랫폼 iOS, 이름 "사워도우 계산기" (영문 현지화: Sourdough Calculator), 기본 언어 한국어, 번들 ID `com.narudoc.levaincalc`, SKU `levaincalc`
3. 앱 정보·가격(무료)·개인정보 처리방침 URL — `AppStore/privacy-policy.md`를 GitHub Pages 등에 올린 URL
4. 앱 개인정보: "데이터를 수집하지 않음"

## 3. 빌드 업로드
- 쉬운 길: Xcode → 상단 기기 선택을 **Any iOS Device (arm64)** → 메뉴 **Product → Archive** → Organizer에서 **Distribute App → App Store Connect → Upload**
- CLI: `cd ios && ./AppStore/archive.sh`
- 처리 후 App Store Connect → TestFlight 탭에 빌드 등장 → 본인 아이폰에 TestFlight 앱으로 설치 (90일 유지, 7일 재설치 문제 해결)

## 4. 스크린샷·설명
- 스크린샷: `AppStore/screenshots/{ko,en}/` (6.9" 1320×2868, 시뮬레이터 iPhone 17 Pro Max에서 촬영)
- 설명·키워드: `AppStore/listing.md`

## 5. 심사 제출
- 버전 정보 입력 → 빌드 선택 → 심사 노트(listing.md 하단) → **심사를 위해 제출**
- 보통 24~48시간. 로그인 없음·서버 없음이라 리젝 사유가 거의 없다.
