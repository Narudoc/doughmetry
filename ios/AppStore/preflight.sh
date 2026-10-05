#!/bin/zsh
# 출시 전 점검 — 하나라도 어긋나면 멈춘다. archive.sh가 아카이브 앞(repo)·업로드 앞(archive)에서 부른다
# 사용: ios/AppStore/preflight.sh repo | ios/AppStore/preflight.sh archive [경로.xcarchive]
#       ios/AppStore/preflight.sh shots   # 스토어 스크린샷만 (0-13 뒤)
set -euo pipefail
ARCHIVE="${2:-}"
[[ -n "$ARCHIVE" ]] && ARCHIVE="${ARCHIVE:a}"
cd "${0:a:h}/../.."
fail() { print -u2 "preflight: $1"; exit 1 }

# 스토어 스크린샷 한 벌 — 한/영 × iPhone·iPad 폴더 × 장면마다 파일, 픽셀 크기, 알파 없음.
# 목록·규격은 capture-screenshots.sh가 기준이다 (--check-shots·--print-shots는 시뮬레이터 없이 돈다).
# 선택 장면은 없어도 되지만, 있으면 네 폴더 모두에 있어야 한다 — 현지화·기기마다 장수가 달라진다
check_shots() {
  local capture=ios/AppStore/capture-screenshots.sh rel size need f shot
  local -a listed dirs optional present
  env -u SHOTS_OUT $capture --check-shots || fail "스토어 스크린샷이 빠졌거나 규격과 다르다 (0-13)"
  while read -r rel size need; do
    listed+=(ios/AppStore/screenshots/$rel)
    dirs+=(ios/AppStore/screenshots/${rel:h})
    if [[ $need == optional ]]; then
      optional+=(${rel:t:r})
      [[ -f ios/AppStore/screenshots/$rel ]] && present+=(${rel:t:r})
    fi
  done < <(env -u SHOTS_OUT $capture --print-shots)
  (( ${#listed} )) || fail "$capture --print-shots가 빈 목록이다"
  # 폴더째 끌어다 올리므로 다른 파일(옛 이름·다시 찍기 전 사본)이 섞이면 안 된다
  for f in ${^${(u)dirs}}/*(N.); do
    (( ${listed[(Ie)$f]} )) || fail "목록에 없는 파일: $f"
  done
  for shot in ${(u)optional}; do
    (( ${#${(@M)present:#$shot}} % 4 == 0 )) || fail "선택 장면 $shot이 네 폴더 중 일부에만 있다 — 모두 찍거나 모두 지운다"
  done
}

case "${1:-}" in
repo)
  [[ -z "$(git status --porcelain)" ]] || fail "커밋하지 않은 변경·새 파일이 있다"
  git fetch -q
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail "HEAD가 origin/main과 다르다 — 푸시·배포 먼저"
  for page in privacy support; do
    curl -sfo /dev/null "https://narudoc.github.io/doughmetry/$page.html" || fail "$page.html이 아직 배포되지 않았다 (3장)"
  done
  grep -rq 'doughmetry/privacy.html' ios/LevainCalc || fail "앱 안 개인정보 처리방침 링크가 없다"
  plutil -lint -s ios/LevainCalc/PrivacyInfo.xcprivacy || fail "PrivacyInfo.xcprivacy"
  (cd ios/LevainCore && swift test -q) || fail "LevainCore 테스트 실패"
  check_shots
  ;;
shots) check_shots ;;
archive)
  [[ -n "$ARCHIVE" ]] || ARCHIVE="$(ls -td ~/Library/Developer/Xcode/Archives/*/*.xcarchive(N) | head -1)"
  APP="$ARCHIVE/Products/Applications/LevainCalc.app"
  [[ -d "$APP" ]] || fail "앱이 없다: $APP"
  [[ "$(plutil -extract ITSAppUsesNonExemptEncryption raw "$APP/Info.plist" 2>/dev/null)" == false ]] || fail "ITSAppUsesNonExemptEncryption이 false가 아니다"
  [[ "$(plutil -extract UIDeviceFamily json -o - "$APP/Info.plist")" == '[1,2]' ]] || fail "UIDeviceFamily가 [1,2]가 아니다"
  [[ "$(plutil -extract UIApplicationSceneManifest.UIApplicationSupportsMultipleScenes raw "$APP/Info.plist" 2>/dev/null)" == false ]] ||
    fail "UIApplicationSupportsMultipleScenes가 false가 아니다 (LevainCalc-Info.plist)"
  [[ -f "$APP/PrivacyInfo.xcprivacy" ]] || fail "PrivacyInfo.xcprivacy가 번들에 없다"
  want="$(grep -m1 -o 'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*' ios/LevainCalc.xcodeproj/project.pbxproj | awk '{print $3}')"
  min="$(plutil -extract MinimumOSVersion raw "$APP/Info.plist")"
  [[ "$min" == "$want" ]] || fail "MinimumOSVersion $min (프로젝트 $want)"
  ;;
*) fail "사용: preflight.sh repo | archive [경로.xcarchive] | shots" ;;
esac
print "preflight $1: 통과"
