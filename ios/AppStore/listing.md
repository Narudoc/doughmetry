# App Store 등록 문구 (원본)

App Store Connect(ASC)에 넣는 텍스트의 원본은 이 파일 하나다. [submission.md](submission.md) 6장은 여기 값을 그대로 붙여 넣으라고만 적는다 — 문구를 바꿀 때는 이 파일만 고친다 (6-1의 이름·부제는 예외 — 이름·부제를 바꾸면 submission.md 6-1도 함께 고친다).

## 현지화 (ASC 언어)

| ASC 언어 | 이름·부제·홍보 문구·설명 | 키워드 | 스크린샷 |
|---|---|---|---|
| 한국어 (기본 언어) | KR | KR | `ko/` |
| 영어(미국) English (U.S.) | EN | EN-US | `en/` |
| 영어(영국) English (U.K.) | EN (같은 글) | EN-GB | `en/` |
| 영어(캐나다) English (Canada) | EN (같은 글) | EN-CA | `en/` |

- 왜 영어가 셋인가: 스토어마다 검색에 쓰는 현지화가 정해져 있다. 한국 스토어는 한국어 + 영어(영국), 미국·일본만 영어(미국), 캐나다는 영어(캐나다) + 프랑스어(캐나다)를 색인한다. 영어(미국)만 두면 한국·영국·유럽·호주 등 약 170개 스토어에서 영어 키워드가 하나도 색인되지 않는다 (Apple, [App Store localizations](https://developer.apple.com/help/app-store-connect/reference/app-store-localizations)).
- 기본 언어는 한국어로 둔다. 기본 언어는 첫 승인 뒤에만 바꿀 수 있다 — 영어 커버리지는 영국·캐나다 현지화로 해결한다.
- 같은 앱은 현지화마다 같은 이름을 다시 써도 된다. 새 언어를 추가하면 ASC가 기본 언어(한국어) 값과 스크린샷을 미리 채워 두므로 전부 덮어써야 한다.

## 이름 (30자)
- KR: 도우메트리: 사워도우 계산기
- EN: Doughmetry: Sourdough Calc

## 부제 (30자)
- KR: 르방 변환·수분율·베이커스 퍼센트 (18자)
- EN: Levain & hydration calculator (29자)

## 홍보 문구 (170자, 심사 없이 수정 가능)
- KR (94자): 총 밀가루 기준 프랑스식 배합 계산기. 르방 리퀴드와 뒤흐를 서로 바꿔도 총 수분율·반죽 무게는 그대로. 구독·광고·계정 없이 무료, 데이터 수집 없음, 완전 오프라인.
- EN (170자): Total-flour sourdough formulas. Switch between liquid and stiff levain with the same hydration and dough weight. Free: no subscription, ads or account; no data collected.
- ASC는 홍보 문구의 `↔`를 거부한다(2026-10-28, `INVALID_CHARACTERS`) — 화살표 같은 기호 대신 말로 쓴다.

## 설명 (KR)
```
르방 리퀴드↔뒤흐를 바꿔도 반죽은 그대로 — 총 밀가루 기준으로 계산하는 프랑스식 사워도우 배합 계산기입니다. 구독·광고·계정 없이 무료이고, 데이터를 수집하지 않으며, 완전히 오프라인으로 동작합니다.

계산
• 재료를 입력하면 총 수분율·소금·PFF·총 반죽 무게를 바로 계산합니다. 모든 %는 총 밀가루(첨가 밀가루 + 르방 속 밀가루) 기준이고, 익숙한 베이커스 퍼센트(첨가 밀가루 = 100%) 표시로도 바꿀 수 있습니다.
• 우유·계란 같은 액체 재료는 수분 함량만큼 총 물에 넣어 계산합니다 (우유 88%, 계란 76%).
• 바시나주(믹싱 후반에 나눠 넣는 물)를 따로 적습니다.
• 르방과 이스트를 함께 — 생이스트↔인스턴트 환산.
• 배율 조정 — ×½·×2, 목표 총 반죽 무게, 개수 × 개당 무게에 맞춰 바시나주·액체·이스트까지 비율 그대로 한 번에 늘리거나 줄입니다.
• N개 분할, 목표 반죽 무게·수분율·PFF에서 거꾸로 역산.

르방 변환
• 리퀴드(100%)↔뒤흐(50%) 르방을 바꾸면서 총 수분율·총 밀가루·총 반죽 무게를 그대로 보존합니다. 르방 질량 고정 / PFF 고정 두 방식을 고를 수 있고, 재료마다 변환 전→후와 증감(g)을 한눈에 보여줍니다.

가져오기
• 책·인스타그램·블로그의 레시피 사진을 고르거나 텍스트를 붙여넣으면 기기 안에서 글자를 인식해 재료와 분량을 채웁니다. Apple Intelligence를 지원하는 iPhone·iPad(iOS·iPadOS 26 이상)에서는 더 정확하게 분석합니다. 저장 전에 확인·수정할 수 있습니다.

일정·기록
• 타임라인 — 빵이 나올 시각에서 거꾸로(또는 시작 시각부터) 단계별 시각을 잡고, 단계마다 알림을 보냅니다. 르방 빌드를 넣으면 르방 먹일 시각과 피크 알림까지.
• 베이킹 로그 — 레시피마다 구운 날짜·별점·메모.
• 르방 빌드 계산기(종 + 밀가루 + 물), 물 온도(DDT) 계산기.

백업·웹 버전
• iCloud 동기화 — iPhone과 iPad 사이에서 레시피와 로그가 자동으로 맞춰집니다.
• JSON 내보내기·가져오기 — 무료 웹 버전(narudoc.github.io/doughmetry — 계산기·변환기·레시피)과 그대로 주고받습니다.

무료·프라이버시
• 구독·광고·계정 없음, 데이터 수집 없음, 완전 오프라인.
• 한국어·영어, 다크 모드.
```

## Description (EN — 영어(미국)·영어(영국)·영어(캐나다) 공통)
```
Swap liquid ↔ stiff levain and keep the same dough — a French-style sourdough formula calculator that works on a total-flour basis. Free, with no subscription, no ads and no account; no data collected; works fully offline.

Calculate
• Enter your ingredients and get total hydration, salt, PFF and total dough weight instantly. Every percentage is of total flour (added flour + flour in the levain), or switch the display to classic baker's % (added flour = 100%).
• Milk, eggs and other liquids count toward total water by their water content (milk 88%, egg 76%).
• Bassinage (water held back and added late in mixing) has its own field.
• Levain plus yeast, with fresh ↔ instant conversion.
• Scale a whole formula — ×½, ×2, to a total dough weight, or to pieces × weight — with bassinage, liquids and yeast kept in proportion.
• Divide into pieces, or solve backwards from a target dough weight, hydration and PFF.

Convert
• Switch between liquid (100%) and stiff (50%) levain while preserving total hydration, total flour and dough weight. Choose fixed levain mass or fixed PFF, and see every ingredient's before → after with the gram difference.

Import
• Choose a photo of a recipe from a book, Instagram or a blog, or paste the text; on-device text recognition fills in the ingredients and amounts, with better accuracy on iPhone and iPad models that support Apple Intelligence (iOS and iPadOS 26 or later). Review and edit before saving.

Plan & log
• Timeline — work back from the time you want the bread out of the oven (or forward from a start time), with an alert at every stage. Add a levain build to see when to feed your levain and get a peak alert.
• Bake log — date, rating and notes for every bake.
• Levain build calculator (starter + flour + water) and water temperature (DDT) calculator in °C or °F.

Backup & web
• iCloud sync keeps recipes and logs in step between your iPhone and iPad.
• JSON export and import work with the free web version (narudoc.github.io/doughmetry — calculator, converter and recipes; Korean interface).

Free & private
• No subscription, no ads, no account, no data collected, works offline.
• Korean & English, dark mode.
```

KR 설명의 물 온도 줄에는 °F를 넣지 않는다 — 한국 사용자에게는 의미가 없다. 두 설명은 앱 안 용어(르방 질량 고정 / PFF 고정 = Fixed levain mass / Fixed PFF, 리퀴드·뒤흐 = Liquid·Stiff, 종 = Starter)를 그대로 써서 스크린샷과 맞춘다. 경쟁 앱 이름·"다른 앱에는 없는" 같은 비교 표현은 쓰지 않는다.

## 키워드 (100바이트 이하, 쉼표 뒤 공백 없음)

이름·부제에 이미 있는 단어(사워도우·계산기·르방·변환·수분율·베이커스·퍼센트 / doughmetry·sourdough·calc·levain·hydration·calculator)는 넣지 않는다 — Apple이 이름·부제를 이미 색인하고 키워드 토큰과 조합해 준다. 복수형도 넣지 않는다.

- KR (38자 / 96바이트): `르뱅,천연발효,발효종,캄파뉴,깜빠뉴,배합표,스타터,제빵,홈베이킹,반죽`
- EN-US (97바이트): `bread,dough,starter,bakers,percentage,ddt,temperature,stiff,formula,timer,schedule,baking,journal`
- EN-GB (100바이트): `bread,dough,starter,bakers,percentage,hydratation,boulangerie,ddt,stiff,formula,timer,baking,journal`
- EN-CA (97바이트): `bread,dough,starter,bakers,percentage,hydratation,boulangerie,pain,ddt,stiff,formula,timer,baking`

- `bakers`·`percentage`는 빼지 말 것 — 부제에서 baker's %가 빠졌으므로 "bakers percentage" 검색은 이 두 토큰의 조합으로만 걸린다.
- EN-GB·EN-CA의 `hydratation`·`boulangerie`·`pain`은 프랑스·벨기에·스위스(영어(영국) 색인)와 퀘벡(영어(캐나다) 색인) 사용자가 치는 말이다. `hydratation`은 앱이 병기하는 프랑스어(*hydratation totale*)이기도 하다.
- 길이 확인: `python3 -c "print(len('<키워드>'.encode()))"` — 한글은 글자당 3바이트. ASC 입력창이 두 글자 단어(르뱅·제빵·반죽)를 거부하면 더 긴 변형(예: 르뱅빵)으로 바꾼다.

## 카테고리
- 주: 음식 및 음료 (Food & Drink) / 부: 유틸리티 (Utilities)

## 연령 등급
- 4+

## 개인정보 라벨 (App Privacy)
- "데이터를 수집하지 않음" — 로그인·분석·광고·추적 없음. iCloud는 사용자 본인 계정 저장.

## 스크린샷 (한/영 × iPhone 6.9"·iPad 13" — 각 6장(+ 선택 07))

[capture-screenshots.sh](capture-screenshots.sh)로 시뮬레이터에서 원본 해상도 JPEG(알파 없음)로 찍는다 — 업스케일·변환 단계 없음. 파일은 `screenshots/{ko,en}/6.9-jpg/`(1320×2868)와 `screenshots/{ko,en}/13-jpg/`(2064×2752)에 같은 이름으로 들어가고, ASC에서는 파일 이름 순서대로 끌어다 놓는다. 영어 세 현지화는 같은 `en/` 세트를 쓴다.

| # | 파일 | 화면 | 캡션 KR | 캡션 EN |
|---|---|---|---|---|
| 1 | `01-convert` | 레시피 탭의 캉파뉴 T65 / Pain de campagne(르방 리퀴드 100%)를 '변환기로 보내기' → 목표 뒤흐 50%, 르방 질량 고정. '변환 결과 — 재료' 표와 보존 지표(✓) 행이 탭 바 위에 다 보이게 스크롤 | 르방만 바꾸고, 반죽은 그대로 | Switch levain. Keep the dough. |
| 2 | `02-calculator` | 계산기: 기본 예시 캉파뉴(T65 900 · 물 620 · 소금 20 · 르방 200 g @100%) + 하단 요약 바 72.0% / 1740.0 g / PFF 10.0% | 총 밀가루 기준, 실시간 계산 | Total-flour math, live |
| 3 | `03-import` | 레시피 탭 → 가져오기 → 텍스트 붙여넣기(스크립트가 클립보드에 넣어 둔 예시) → 분석 → 확인 시트(맨 위가 Apple Intelligence/규칙 기반 안내 — 'AI 결과가 규칙 분석과 달라…' 경고면 다시). 이름·밀가루가 보이게(iPad 13형도 이름·밀가루·르방까지 — 지표는 스크롤 아래) | 사진·텍스트로 레시피 가져오기 | Recipe from a photo or text |
| 4 | `04-timeline` | 도구 → 타임라인, 기준 '완성 시각', 단계 시각·버튼이 UI 언어로 (en은 `2:10 PM` 꼴과 `Edit`, ko는 `오후 2:10` 꼴과 `편집`) | 빵 나올 시각부터 거꾸로 | Plan back from bread time |
| 5 | `05-bakelog` | 레시피 탭 → 캉파뉴 T65 / Pain de campagne 상세: 별점과 베이킹 로그 메모 (스크립트의 예시 데이터) | 굽기마다 별점·메모 | Rate and note every bake |
| 6 | `06-fiche` | 캉파뉴 T65 / Pain de campagne를 계산기로 불러온 뒤 하단 요약 바를 눌러 연 배합표 시트(처음부터 큰 높이 — iPad는 페이지 크기 시트라 재료와 총 수분율·총 반죽 무게까지 한 화면), 다크 모드 | 한 장짜리 배합표 | A one-page fiche technique |
| (7) | `07-scale` | 선택: 계산기 → 분할 섹션의 '배율 조정' 시트(배율 1.5 입력 — 미리보기 '1760.0 g → 2640.0 g (×1.5)'가 보이게 — 06에서 불러온 캉파뉴 T65 / Pain de campagne 기준) | 배합 배율을 한 번에 | Scale any formula in one step |

- 예시 데이터는 언어별로 따로 넣는다: ko는 캉파뉴 T65·바게트 오 르방·호밀 캉파뉴와 한국어 메모, en은 Pain de campagne·Baguette au levain·Rye country loaf와 영어 메모. 다른 언어 이름이 섞이거나 'Test' 같은 이름이 보이면 다시 찍는다.
- 캡션은 지금은 이미지에 넣지 않는다(원본 캡처만 올려도 된다). 나중에 캡션 띠를 붙인다면 bottle `#1E4034` 띠 + paper `#F5F2EA` 글자(Pretendard), brass는 쓰지 않는다(계산 결과값 전용). '무료'·가격은 캡션에 넣지 않는다 (심사 지침 2.3.7) — 부제·설명에서 말한다.

## 심사 노트 (Review Notes)

ASC `앱 심사 정보 > 메모 (Notes)`(4000바이트)에 아래 블록을 그대로 붙여 넣는다 (submission.md 6-7).

```
- 계정·로그인 불필요. 모든 기능이 오프라인으로 동작합니다 (앱은 네트워크 요청을 하지 않고, 설정의 링크만 Safari로 엽니다).
- iPhone·iPad 모두 지원합니다 (iPad는 네 방향과 Split View).
- 레시피 탭의 "사진·텍스트에서 가져오기": 사진은 기기 안 Apple Vision으로 글자를 읽고, 사진·붙여넣은 텍스트 모두 규칙 기반 파서로 재료를 채웁니다. Apple Intelligence를 쓸 수 있는 기기(iOS·iPadOS 26 이상, 지원 하드웨어·설정)에서는 온디바이스 모델로 더 정확하게 분석합니다. 기능은 같고 정확도만 다르며, 어느 경우든 저장 전에 확인 시트를 거칩니다.
- 가져오기 시험용 텍스트: 아래 여섯 줄을 복사해 "텍스트 붙여넣기"에 붙여 넣으세요. 분량은 무게여야 합니다(g — kg·oz·lb는 g으로 바꿉니다). iPad에서는 레시피 목록 막대의 ✦ 아이콘 버튼이 가져오기입니다.
통밀 캉파뉴
T65 밀가루 400g
통밀가루 100g
물 350g
르방 리퀴드 100g
소금 10g
- iCloud는 사용자 본인의 iCloud Documents 컨테이너(iCloud.com.narudoc.doughmetry)만 사용하며 개발자 서버는 없습니다. iCloud에 로그인하지 않아도 앱은 정상 동작합니다.
- 알림은 도구 탭 타임라인의 로컬 알림(UNUserNotificationCenter)만 사용합니다.
- 레시피 탭이 비어 있으면 "예시 레시피 추가" 버튼으로 예시 레시피 4개가 들어가 변환기·계산기를 바로 써 볼 수 있습니다 (레시피 상세에서 베이킹 로그를 새로 기록할 수 있습니다).
- 테스트용 레시피: 계산기 탭에서 밀가루 1000, 물 700, 소금 20, 르방 200(리퀴드 100%)을 입력하면 총 수분율 72.7%, PFF 9.1%, 총 반죽 1920.0 g이 표시됩니다.

- No account or sign-in. Everything works offline (the app makes no network requests; only the links in Settings open Safari).
- Supports iPhone and iPad (iPad in all orientations and Split View).
- "Import from photo or text" in the Recipes tab: photos are read with on-device Apple Vision text recognition, and a rule-based parser fills in the ingredients from photos or pasted text. On devices with Apple Intelligence (iOS/iPadOS 26 or later, supported hardware and settings) an on-device model improves accuracy. The feature is the same either way, and every import goes through a review sheet before saving.
- Sample text for Import: copy the six lines below and use "Paste text". Amounts must be weights (g; kg, oz and lb are converted). On iPad, Import is the ✦ (sparkles) icon button in the Recipes list bar.
Country sourdough (2 loaves)
800g Bread flour
200g Whole wheat flour
700g water
200g levain
20g salt
- iCloud uses only the user's own iCloud Documents container (iCloud.com.narudoc.doughmetry); there is no developer server. The app works without an iCloud sign-in.
- Notifications are local only (timeline stages in the Tools tab).
- If the Recipes tab is empty, "Add sample recipes" adds four recipes so you can try the converter and calculator right away (open one to add a bake-log entry).
- Test recipe: Calculator tab → flour 1000, water 700, salt 20, levain 200 (liquid, 100%) shows total hydration 72.7%, PFF 9.1%, total dough 1920.0 g.
```

(수치 검산: 르방 200 g @100% → 르방 속 밀가루 100, 물 100. 총 밀가루 1100, 총 물 800 → 800/1100 = 72.73%, PFF 100/1100 = 9.09%, 총 반죽 1000 + 700 + 20 + 200 = 1920 g.)
