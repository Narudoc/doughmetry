#!/bin/zsh
# App Store 스크린샷 캡처 — iPhone 6.9"(1320×2868)·iPad 13"(2064×2752) × 한/영, 원본 해상도 JPEG(알파 없음)
# 사용: cd ios && ./AppStore/capture-screenshots.sh [all|iphone|ipad] [all|ko|en]   # 대화형
#       ./AppStore/capture-screenshots.sh prepare iphone|ipad ko|en     # 준비만 (UDID 출력)
#       ./AppStore/capture-screenshots.sh shot iphone|ipad ko|en 01-convert   # 지금 화면 한 장
#       ./AppStore/capture-screenshots.sh --print-seed ko|en     # 넣을 예시 library.json만 출력
#       ./AppStore/capture-screenshots.sh --print-import ko|en   # 클립보드에 넣을 가져오기 예시만 출력
# - 이 스크립트 전용 시뮬레이터('Doughmetry Shots …')를 만들어 언어마다 지우고(erase) 시작한다. 다른 시뮬레이터는 건드리지 않는다.
# - Debug로 빌드한다: 예시 데이터를 여는 -uiTestDataDir 훅이 DEBUG 전용이고, 그 훅이 iCloud 동기화도 끈다.
# - 대화형에서는 화면 이동을 사람이 한다 — 단계마다 안내대로 시뮬레이터 화면을 맞춘 뒤 Enter (s = 건너뛰기).
# - 결과: AppStore/screenshots/{ko,en}/6.9-jpg/, {ko,en}/13-jpg/ — 파일 이름 순서가 ASC 업로드 순서다 (listing.md 스크린샷 표).
# 환경 변수: APP_PATH(이미 빌드한 Debug .app), DERIVED_DATA(빌드 폴더), SHOTS_OUT(결과 폴더), SIM_RUNTIME(런타임 ID),
#           IPHONE_TYPE·IPAD_TYPE(기기 종류 ID)
set -euo pipefail
PROG=$0
cd "$(dirname "$0")/.."

BUNDLE_ID=com.narudoc.doughmetry
OUT=${SHOTS_OUT:-AppStore/screenshots}
typeset -A DEVICE_TYPE=(
  iphone "${IPHONE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max}"
  ipad "${IPAD_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB}"
)
typeset -A DEVICE_NAME=(iphone "Doughmetry Shots iPhone 6.9" ipad "Doughmetry Shots iPad 13")
typeset -A FOLDER=(iphone 6.9-jpg ipad 13-jpg)
typeset -A SIZE=(iphone 1320x2868 ipad 2064x2752)
typeset -A LOCALE=(ko ko_KR en en_US)
SHOTS=(01-convert 02-calculator 03-import 04-timeline 05-bakelog 06-fiche 07-scale)

# 언어별 예시 라이브러리 (LibraryDocument). 이름·메모가 다른 언어로 섞이면 안 된다 — 스토어 현지화마다 따로 보인다
seed_json() {
  case $1 in
  ko) cat <<'EOF'
{
  "schemaVersion": 1,
  "recipes": [
    {
      "id": "shot-campagne", "schemaVersion": 2, "name": "캉파뉴 T65", "tags": ["캉파뉴", "T65"],
      "note": "오토리즈 1시간 → 스트레치 앤 폴드 3회.\n벌크 26°C 4~5시간, 냉장 12시간.\n250°C 스팀 20분 + 230°C 25분.",
      "createdAt": "2026-08-30T09:00:00.000Z", "updatedAt": "2026-09-27T09:00:00.000Z",
      "flours": [{"id": "shot-f1", "name": "T65", "grams": 800}, {"id": "shot-f2", "name": "통밀", "grams": 100}],
      "water": 610, "bassinage": 30, "salt": 20,
      "levain": {"type": "liquide", "hydration": 1, "grams": 200, "flourName": "T65"},
      "liquids": [], "yeast": {"type": "fresh", "grams": 0}, "extras": [], "pieces": 2
    },
    {
      "id": "shot-baguette", "schemaVersion": 2, "name": "바게트 오 르방", "tags": ["바게트"],
      "note": "르방 뒤흐로 신맛을 줄인 배합. 바시나주는 믹싱 끝에 두 번 나눠 넣는다.",
      "createdAt": "2026-09-02T09:00:00.000Z", "updatedAt": "2026-09-24T09:00:00.000Z",
      "flours": [{"id": "shot-f3", "name": "T65", "grams": 1000}],
      "water": 700, "bassinage": 40, "salt": 24,
      "levain": {"type": "dur", "hydration": 0.5, "grams": 300},
      "liquids": [], "yeast": {"type": "fresh", "grams": 3}, "extras": [], "pieces": 6
    },
    {
      "id": "shot-rye", "schemaVersion": 2, "name": "호밀 캉파뉴", "tags": ["호밀"],
      "createdAt": "2026-09-05T09:00:00.000Z", "updatedAt": "2026-09-15T09:00:00.000Z",
      "flours": [{"id": "shot-f4", "name": "T80", "grams": 600}, {"id": "shot-f5", "name": "호밀", "grams": 250}],
      "water": 600, "bassinage": 0, "salt": 20,
      "levain": {"type": "liquide", "hydration": 1, "grams": 300, "flourName": "호밀"},
      "liquids": [], "yeast": {"type": "fresh", "grams": 0}, "extras": []
    }
  ],
  "logs": [
    {"id": "shot-log-1", "recipeId": "shot-campagne", "bakedAt": "2026-09-27T08:00:00.000Z", "rating": 5,
     "note": "오븐 스프링 최고, 귀가 잘 섰다. 벌크 26°C 4시간 30분.",
     "createdAt": "2026-09-27T08:00:00.000Z", "updatedAt": "2026-09-27T08:00:00.000Z"},
    {"id": "shot-log-2", "recipeId": "shot-campagne", "bakedAt": "2026-09-20T08:00:00.000Z", "rating": 4,
     "note": "냉장 14시간 — 신맛이 조금 강했다. 다음엔 12시간.",
     "createdAt": "2026-09-20T08:00:00.000Z", "updatedAt": "2026-09-20T08:00:00.000Z"},
    {"id": "shot-log-3", "recipeId": "shot-campagne", "bakedAt": "2026-09-13T08:00:00.000Z", "rating": 4,
     "note": "통밀 대신 호밀 10%. 속결이 조금 촘촘해졌다.",
     "createdAt": "2026-09-13T08:00:00.000Z", "updatedAt": "2026-09-13T08:00:00.000Z"},
    {"id": "shot-log-4", "recipeId": "shot-baguette", "bakedAt": "2026-09-24T08:00:00.000Z", "rating": 5,
     "note": "바시나주 40 g을 두 번에 나눠 넣었다. 기공 좋음.",
     "createdAt": "2026-09-24T08:00:00.000Z", "updatedAt": "2026-09-24T08:00:00.000Z"}
  ],
  "deleted": []
}
EOF
  ;;
  en) cat <<'EOF'
{
  "schemaVersion": 1,
  "recipes": [
    {
      "id": "shot-campagne", "schemaVersion": 2, "name": "Pain de campagne", "tags": ["campagne"],
      "note": "Autolyse 1 h, then 3 sets of stretch and folds.\nBulk 4–5 h at 26 °C, cold retard 12 h.\nBake 20 min at 250 °C with steam, then 25 min at 230 °C.",
      "createdAt": "2026-08-30T09:00:00.000Z", "updatedAt": "2026-09-27T09:00:00.000Z",
      "flours": [{"id": "shot-f1", "name": "T65", "grams": 800}, {"id": "shot-f2", "name": "Whole wheat", "grams": 100}],
      "water": 610, "bassinage": 30, "salt": 20,
      "levain": {"type": "liquide", "hydration": 1, "grams": 200, "flourName": "T65"},
      "liquids": [], "yeast": {"type": "fresh", "grams": 0}, "extras": [], "pieces": 2
    },
    {
      "id": "shot-baguette", "schemaVersion": 2, "name": "Baguette au levain", "tags": ["baguette"],
      "note": "Stiff levain keeps the sourness mild. Add the bassinage in two parts at the end of mixing.",
      "createdAt": "2026-09-02T09:00:00.000Z", "updatedAt": "2026-09-24T09:00:00.000Z",
      "flours": [{"id": "shot-f3", "name": "T65", "grams": 1000}],
      "water": 700, "bassinage": 40, "salt": 24,
      "levain": {"type": "dur", "hydration": 0.5, "grams": 300},
      "liquids": [], "yeast": {"type": "fresh", "grams": 3}, "extras": [], "pieces": 6
    },
    {
      "id": "shot-rye", "schemaVersion": 2, "name": "Rye country loaf", "tags": ["rye"],
      "createdAt": "2026-09-05T09:00:00.000Z", "updatedAt": "2026-09-15T09:00:00.000Z",
      "flours": [{"id": "shot-f4", "name": "T80", "grams": 600}, {"id": "shot-f5", "name": "Rye", "grams": 250}],
      "water": 600, "bassinage": 0, "salt": 20,
      "levain": {"type": "liquide", "hydration": 1, "grams": 300, "flourName": "Rye"},
      "liquids": [], "yeast": {"type": "fresh", "grams": 0}, "extras": []
    }
  ],
  "logs": [
    {"id": "shot-log-1", "recipeId": "shot-campagne", "bakedAt": "2026-09-27T08:00:00.000Z", "rating": 5,
     "note": "Best oven spring yet — great ear. Bulk 4 h 30 min at 26 °C.",
     "createdAt": "2026-09-27T08:00:00.000Z", "updatedAt": "2026-09-27T08:00:00.000Z"},
    {"id": "shot-log-2", "recipeId": "shot-campagne", "bakedAt": "2026-09-20T08:00:00.000Z", "rating": 4,
     "note": "14 h cold retard — a little too sour. Try 12 h next time.",
     "createdAt": "2026-09-20T08:00:00.000Z", "updatedAt": "2026-09-20T08:00:00.000Z"},
    {"id": "shot-log-3", "recipeId": "shot-campagne", "bakedAt": "2026-09-13T08:00:00.000Z", "rating": 4,
     "note": "Swapped the whole wheat for 10% rye. Slightly tighter crumb.",
     "createdAt": "2026-09-13T08:00:00.000Z", "updatedAt": "2026-09-13T08:00:00.000Z"},
    {"id": "shot-log-4", "recipeId": "shot-baguette", "bakedAt": "2026-09-24T08:00:00.000Z", "rating": 5,
     "note": "Added the 40 g bassinage in two parts. Open crumb.",
     "createdAt": "2026-09-24T08:00:00.000Z", "updatedAt": "2026-09-24T08:00:00.000Z"}
  ],
  "deleted": []
}
EOF
  ;;
  *) print -u2 "언어는 ko 또는 en"; return 1 ;;
  esac
}

# 03-import에서 '텍스트 붙여넣기'에 붙여 넣을 레시피 — 실행 전에 시뮬레이터 클립보드에 넣어 둔다
import_text() {
  case $1 in
  ko) print -r -- $'통밀 캉파뉴\nT65 밀가루 400g\n통밀가루 100g\n물 350g\n르방 리퀴드 100g\n소금 10g' ;;
  # 이 예시는 기기 안 모델 초안이 규칙 분석과 맞는다 — 어긋나는 예시는 확인 시트 맨 위에 경고가 뜬다
  en) print -r -- $'Country sourdough (2 loaves)\n\n800g bread flour\n200g whole wheat flour\n700g water\n200g levain\n20g salt' ;;
  *) print -u2 "언어는 ko 또는 en"; return 1 ;;
  esac
}

# 단계별 안내 — 앱 라벨은 '한국어 / English'로 적는다
instruction() {
  case $1 in
  01-convert) print -r -- "레시피 / Recipes 탭 → 캉파뉴 T65 / Pain de campagne → 변환기로 보내기(⇄ 아이콘) → 목표 '뒤흐 50% / Stiff 50%', 변환 모드 '르방 질량 고정 / Fixed levain mass' 확인 → '변환 결과 — 재료 / Result — ingredients' 표와 보존 지표(✓) 행이 탭 바 위에 다 보이게 스크롤" ;;
  02-calculator) print -r -- "계산기 / Calculator 탭 → 맨 위로 스크롤, 키보드 닫기. 하단 요약 바가 72.0% / 1740 g / PFF 10%인지 확인 (기본 예시 캉파뉴 / Campagne)" ;;
  03-import) print -r -- "레시피 / Recipes 탭 → 가져오기 버튼 → '텍스트 붙여넣기 / Paste text' → 입력란에 붙여넣기(클립보드에 예시가 있다) → 분석 / Analyze → 확인 시트 맨 위가 Apple Intelligence/규칙 기반 안내인지 확인 — ⚠ 'AI 결과가 규칙 분석과 달라… / The AI result didn't match…' 경고면 취소하고 다시. 이름·밀가루가 보이게 (iPad 13형은 지표까지). 찍은 뒤 시트는 취소" ;;
  04-timeline) print -r -- "도구 / Tools 탭 → 타임라인 / Timeline → 기준 '완성 시각 / Finish time' → 빵이 완성될 시각을 내일 오전 10:00 근처로 → 단계 시각이 보이게. 알림 예약은 누르지 않는다" ;;
  05-bakelog) print -r -- "레시피 / Recipes 탭 → 캉파뉴 T65 / Pain de campagne → 별점·베이킹 로그가 보이게 스크롤. 예시 레시피가 없으면 -uiTestDataDir 훅이 빠진 빌드다 (Debug 빌드·AppModel 확인)" ;;
  06-fiche) print -r -- "(다크 모드로 바꿔 두었다) 레시피 / Recipes 탭 → 캉파뉴 T65 / Pain de campagne → 계산기로 불러오기 / Load into calculator → 하단 요약 바(⌃)를 눌러 배합표 시트 / tap the summary bar to open the formula sheet (처음부터 큰 높이로 열린다)" ;;
  07-scale) print -r -- "(선택) 계산기 / Calculator 탭 → 분할 / Divide 섹션의 '배율 조정 / Scale recipe' → 시트에서 배율 / Factor 1.5 입력, 키보드를 닫아 미리보기 '1760.0 g → 2640.0 g (×1.5)'가 보이게 — 06에서 불러온 캉파뉴 T65 / Pain de campagne 기준 (적용은 누르지 않는다)" ;;
  esac
}

latest_ios_runtime() {
  xcrun simctl list runtimes | grep '^iOS ' | grep -v unavailable | awk '{print $NF}' | tail -1
}

# 이름으로 찾고 없으면 만든다 — 이 스크립트가 만든 기기만 쓴다
device_udid() {
  local kind=$1 name=${DEVICE_NAME[$1]} udid
  udid=$(xcrun simctl list devices | grep -F "    $name (" | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1 || true)
  if [[ -z $udid ]]; then
    udid=$(xcrun simctl create "$name" "${DEVICE_TYPE[$kind]}" "$RUNTIME")
  fi
  print -r -- "$udid"
}

status_bar() {
  local udid=$1 kind=$2
  local args=(--time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100)
  [[ $kind == iphone ]] && args+=(--cellularMode active --cellularBars 4 --operatorName '')
  xcrun simctl status_bar "$udid" override "${args[@]}"
}

# 언어마다 지우고 시작한다 — 앞 언어의 설정·타임라인·클립보드가 섞이지 않게
fresh_boot() {
  local udid=$1 kind=$2 lang=$3
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  xcrun simctl erase "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" >/dev/null
  # 시스템 언어·지역도 맞춘다 — 키보드·시스템 시트·iPad 상태 바의 날짜. 다시 부팅해야 적용된다
  xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array "$lang"
  xcrun simctl spawn "$udid" defaults write -g AppleLocale -string "${LOCALE[$lang]}"
  xcrun simctl shutdown "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" >/dev/null
  xcrun simctl ui "$udid" appearance light
  status_bar "$udid" "$kind"
}

# 대화형에서만 화면 앱을 띄운다 — Xcode 26까지는 Simulator, 27부터는 DeviceHub. 못 열어도 캡처(simctl io)는 된다
show_viewer() {
  open -b com.apple.iphonesimulator --args -CurrentDeviceUDID "$1" 2>/dev/null \
    || open -b com.apple.dt.Devices 2>/dev/null \
    || print -u2 -r -- "  시뮬레이터 화면 앱을 열지 못했습니다 — Xcode > Open Developer Tool에서 직접 엽니다"
}

# 설치 → 예시 데이터 폴더(앱 데이터 컨테이너 안) → 클립보드 → 실행
prepare_and_launch() {
  local udid=$1 lang=$2 data seed
  xcrun simctl install "$udid" "$APP"
  if ! data=$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data 2>/dev/null); then
    xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
    sleep 2
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    data=$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data)
  fi
  seed="$data/Library/StoreShots"
  rm -rf "$seed"
  mkdir -p "$seed"
  seed_json "$lang" > "$seed/library.json"
  # pbcopy는 셸 로캘의 인코딩으로 읽는다 — LANG이 비어 있으면(C) 한글에서 실패한다
  import_text "$lang" | LC_ALL=en_US.UTF-8 xcrun simctl pbcopy "$udid"
  xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" \
    -appLanguage "$lang" -AppleLanguages "($lang)" -AppleLocale "${LOCALE[$lang]}" \
    -uiTestDataDir "$seed" >/dev/null
}

# 찍고 규격(픽셀 크기·알파 없음)을 확인한 뒤에만 결과 폴더로 옮긴다
capture() {
  local udid=$1 dest=$2 want=$3 tmp="$WORK/shot.jpg" w h alpha
  rm -f "$tmp"
  xcrun simctl io "$udid" screenshot --type=jpeg --mask=ignored "$tmp" >/dev/null 2>"$WORK/io.err" \
    || { cat "$WORK/io.err" >&2; return 1; }
  w=$(sips -g pixelWidth "$tmp" | awk '/pixelWidth/ {print $2}')
  h=$(sips -g pixelHeight "$tmp" | awk '/pixelHeight/ {print $2}')
  alpha=$(sips -g hasAlpha "$tmp" | awk '/hasAlpha/ {print $2}')
  if [[ "${w}x${h}" != "$want" || "$alpha" != no ]]; then
    print -u2 -r -- "  규격과 다릅니다: ${w}x${h}, hasAlpha $alpha (기대 $want, no) — 세로 방향인지, 기기 종류(IPHONE_TYPE/IPAD_TYPE)가 맞는지 확인"
    return 1
  fi
  mkdir -p "${dest:h}"
  mv -f "$tmp" "$dest"
  print -r -- "  → $dest (${w}x${h}, hasAlpha no)"
}

run_device() {
  local kind=$1 udid lang shot dest ans
  udid=$(device_udid "$kind")
  print -r -- "== ${DEVICE_NAME[$kind]} ($udid)"
  for lang in $LANGS; do
    print -r -- "-- $lang: 시뮬레이터를 지우고 준비합니다"
    fresh_boot "$udid" "$kind" "$lang"
    show_viewer "$udid"
    prepare_and_launch "$udid" "$lang"
    for shot in $SHOTS; do
      dest="$OUT/$lang/${FOLDER[$kind]}/$shot.jpg"
      [[ $shot == 06-fiche ]] && xcrun simctl ui "$udid" appearance dark
      while true; do
        print -r -- ""
        print -r -- "[$kind/$lang] $shot — $(instruction "$shot")"
        read -r "ans?Enter = 찍기, s = 건너뛰기: "
        [[ $ans == s ]] && break
        if capture "$udid" "$dest" "${SIZE[$kind]}"; then
          read -r "ans?Enter = 다음, r = 다시 찍기: "
          [[ $ans == r ]] || break
        fi
      done
      [[ $shot == 06-fiche ]] && xcrun simctl ui "$udid" appearance light
    done
  done
  xcrun simctl shutdown "$udid" 2>/dev/null || true
}

usage() {
  print -u2 -r -- "사용: $PROG [all|iphone|ipad] [all|ko|en]   # 대화형: 안내대로 화면을 맞추고 Enter
       $PROG prepare iphone|ipad ko|en          # 지우고·예시 데이터·실행까지만, UDID 출력
       $PROG shot iphone|ipad ko|en <이름>      # 지금 화면을 <이름>.jpg로 (규격 확인 포함)"
  exit 2
}

# 대화형·prepare가 쓰는 앱 — APP_PATH가 없으면 Debug로 빌드한다
build_app() {
  if [[ -n ${APP_PATH:-} ]]; then
    APP=$APP_PATH
  else
    local dd=${DERIVED_DATA:-build/screenshots-dd}
    print -u2 -r -- "Debug 빌드 중 ($dd)…"
    xcodebuild -project LevainCalc.xcodeproj -scheme LevainCalc -configuration Debug \
      -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$dd" -quiet build >&2
    APP="$dd/Build/Products/Debug-iphonesimulator/LevainCalc.app"
  fi
  [[ -d $APP ]] || { print -u2 "앱이 없습니다: $APP"; exit 1; }
  if (( ${KINDS[(Ie)ipad]} )) && ! plutil -extract UIDeviceFamily json -o - "$APP/Info.plist" | grep -q 2; then
    print -u2 "이 빌드는 iPad를 지원하지 않습니다 (UIDeviceFamily에 2 없음 — TARGETED_DEVICE_FAMILY 확인)"
    exit 1
  fi
}

kind_arg() { [[ ${1:-} == (iphone|ipad) ]] || usage; }
lang_arg() { [[ ${1:-} == (ko|en) ]] || usage; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/doughmetry-shots.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
RUNTIME=${SIM_RUNTIME:-$(latest_ios_runtime)}
[[ -n $RUNTIME ]] || { print -u2 "iOS 시뮬레이터 런타임이 없습니다"; exit 1; }

case ${1:-all} in
--print-seed) lang_arg "${2:-}"; seed_json "$2"; exit ;;
--print-import) lang_arg "${2:-}"; import_text "$2"; exit ;;
# 화면 이동을 다른 도구(UI 테스트·시뮬레이터 제어)가 맡을 때: prepare → 화면 맞추기 → shot. 06-fiche 전에는
# `xcrun simctl ui <UDID> appearance dark`를 직접 켜고, 찍은 뒤 light로 되돌린다
prepare)
  kind_arg "${2:-}"; lang_arg "${3:-}"
  KINDS=($2)
  build_app
  udid=$(device_udid "$2")
  fresh_boot "$udid" "$2" "$3" >&2
  prepare_and_launch "$udid" "$3" >&2
  print -r -- "$udid"
  exit ;;
shot)
  kind_arg "${2:-}"; lang_arg "${3:-}"
  [[ -n ${4:-} ]] || usage
  udid=$(xcrun simctl list devices | grep -F "    ${DEVICE_NAME[$2]} (" | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1 || true)
  [[ -n $udid ]] || { print -u2 "'${DEVICE_NAME[$2]}' 시뮬레이터가 없습니다 — 먼저 prepare"; exit 1; }
  capture "$udid" "$OUT/$3/${FOLDER[$2]}/${4%.jpg}.jpg" "${SIZE[$2]}"
  exit ;;
all) KINDS=(iphone ipad) ;;
iphone | ipad) KINDS=($1) ;;
*) usage ;;
esac
case ${2:-all} in
all) LANGS=(ko en) ;;
ko | en) LANGS=($2) ;;
*) usage ;;
esac

build_app
for kind in $KINDS; do
  run_device "$kind"
done

print -r -- ""
print -r -- "끝. 결과:"
for kind in $KINDS; do
  for lang in $LANGS; do
    ls -1 "$OUT/$lang/${FOLDER[$kind]}" 2>/dev/null | sed "s|^|  $lang/${FOLDER[$kind]}/|" || true
  done
done
print -r -- "다음: 사진을 한 장씩 열어 다른 언어 글자·테스트 이름이 없는지 본 뒤 submission.md 6-5대로 올린다."
