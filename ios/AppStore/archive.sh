#!/bin/zsh
# App Store 업로드용 아카이브 + 업로드 (개발자 프로그램 승인 + Xcode 계정 로그인 후 사용)
# 사용: cd ios && ./AppStore/archive.sh [빌드번호]
# - Xcode GUI 경로(Product → Archive → Distribute App)가 가장 쉽고, 이 스크립트는 같은 일을 CLI로 한다.
# - 업로드 인증은 Xcode에 로그인된 Apple ID를 쓴다 (-allowProvisioningUpdates).
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD_NUMBER="${1:-$(date +%Y%m%d%H%M)}"
ARCHIVE="build/LevainCalc.xcarchive"

xcodebuild -project LevainCalc.xcodeproj -scheme LevainCalc -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates CURRENT_PROJECT_VERSION="$BUILD_NUMBER" archive

xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist AppStore/ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates

echo "업로드 완료 — App Store Connect → TestFlight에서 처리(10~30분) 후 빌드가 나타납니다."
