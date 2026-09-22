#!/usr/bin/env bash
# 앱 타깃의 빌드 스크립트 단계에서 Crashlytics 로 dSYM 을 올린다.
#
# Release 이고 App/Resources/GoogleService-Info.plist 가 있을 때만 SDK 의 run 스크립트를 실행한다.
# 그 밖에는 경고만 남기고 성공으로 끝난다. plist 를 넣기 전에도 Release 빌드가 깨지지 않게 하기 위해서다.
# Debug 는 dSYM 을 만들지 않는다(DEBUG_INFORMATION_FORMAT = dwarf).
#
# SDK 경로는 Tuist 의 checkouts 다. Xcode SPM 의 SourcePackages 경로는 Tuist 에 없다.
# 이 경로를 읽으려면 앱 타깃의 ENABLE_USER_SCRIPT_SANDBOXING 이 NO 여야 한다(App/Project.swift).
set -euo pipefail

plist="${SRCROOT}/Resources/GoogleService-Info.plist"
run="${SRCROOT}/../Tuist/.build/checkouts/firebase-ios-sdk/Crashlytics/run"

if [[ "${CONFIGURATION:-}" != "Release" ]]; then
    echo "warning: Crashlytics dSYM 업로드를 건너뜁니다(${CONFIGURATION:-알 수 없음} 빌드)."
    exit 0
fi

if [[ ! -f "$plist" ]]; then
    echo "warning: Crashlytics dSYM 업로드를 건너뜁니다(GoogleService-Info.plist 없음)."
    exit 0
fi

if [[ ! -x "$run" ]]; then
    echo "error: Crashlytics run 스크립트가 없습니다: $run (mise exec -- tuist install 을 먼저 돌리세요)"
    exit 1
fi

exec "$run"
