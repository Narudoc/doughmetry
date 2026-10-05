#!/bin/zsh
# 출시 전 점검 — 하나라도 어긋나면 멈춘다. archive.sh가 아카이브 앞(repo)·업로드 앞(archive)에서 부른다
# 사용: ios/AppStore/preflight.sh repo | ios/AppStore/preflight.sh archive [경로.xcarchive]
set -euo pipefail
ARCHIVE="${2:-}"
[[ -n "$ARCHIVE" ]] && ARCHIVE="${ARCHIVE:a}"
cd "${0:a:h}/../.."
fail() { print -u2 "preflight: $1"; exit 1 }

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
  shots=(ios/AppStore/screenshots/{ko,en}/{6.9-jpg,13-jpg}/*.jpg(N))
  (( ${#shots} )) || fail "스토어 스크린샷이 없다 (0-13)"
  for f in $shots; do
    [[ "$(sips -g hasAlpha "$f" | awk '/hasAlpha/ {print $2}')" == no ]] || fail "알파 채널: $f"
  done
  ;;
archive)
  [[ -n "$ARCHIVE" ]] || ARCHIVE="$(ls -td ~/Library/Developer/Xcode/Archives/*/*.xcarchive(N) | head -1)"
  APP="$ARCHIVE/Products/Applications/LevainCalc.app"
  [[ -d "$APP" ]] || fail "앱이 없다: $APP"
  [[ "$(plutil -extract ITSAppUsesNonExemptEncryption raw "$APP/Info.plist" 2>/dev/null)" == false ]] || fail "ITSAppUsesNonExemptEncryption이 false가 아니다"
  [[ "$(plutil -extract UIDeviceFamily json -o - "$APP/Info.plist")" == '[1,2]' ]] || fail "UIDeviceFamily가 [1,2]가 아니다"
  [[ -f "$APP/PrivacyInfo.xcprivacy" ]] || fail "PrivacyInfo.xcprivacy가 번들에 없다"
  want="$(grep -m1 -o 'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*' ios/LevainCalc.xcodeproj/project.pbxproj | awk '{print $3}')"
  min="$(plutil -extract MinimumOSVersion raw "$APP/Info.plist")"
  [[ "$min" == "$want" ]] || fail "MinimumOSVersion $min (프로젝트 $want)"
  ;;
*) fail "사용: preflight.sh repo | archive [경로.xcarchive]" ;;
esac
print "preflight $1: 통과"
