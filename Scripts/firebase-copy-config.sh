#!/usr/bin/env bash
# 앱 타깃의 빌드 스크립트 단계에서 구성(Staging, Release)에 맞는 GoogleService-Info.plist 를 앱 번들에 복사한다.
#
# 원본: Configurations/Firebase/<구성>/GoogleService-Info.plist
# Firebase 앱은 번들 ID 마다 따로 등록하므로(Staging 은 .stg) 파일도 구성마다 따로 둔다.
# 원본이 없으면 번들의 사본을 지운다. 이전 빌드의 사본이 남으면 파일을 뺐는데도 Firebase 가 켜진다.
# Debug 는 Firebase 를 초기화하지 않으므로(FirebaseBootstrap) 원본을 두지 않는다.
#
# Crashlytics dSYM 업로드(crashlytics-upload-symbols.sh)가 이 사본을 읽으므로 그보다 먼저 돈다(App/Project.swift).
set -euo pipefail

source_plist="${SRCROOT}/../Configurations/Firebase/${CONFIGURATION}/GoogleService-Info.plist"
bundled_plist="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"

if [[ -f "$source_plist" ]]; then
    mkdir -p "$(dirname "$bundled_plist")"
    cp "$source_plist" "$bundled_plist"
else
    rm -f "$bundled_plist"
fi
