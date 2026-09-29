#!/usr/bin/env bash
# 모듈 템플릿(Tuist/Templates)으로 만든 모듈이 그대로 CI 를 통과하는지 확인한다.
#
#   Scripts/verify-templates.sh
#
# 작업 트리를 임시 디렉터리로 복사한 뒤, 그 사본에서 core·feature 모듈을 모든 옵션(--demo --testing --resources)으로 하나씩,
# 옵션 없이 하나씩 만들고 포맷·린트 → generate → 의존성 검사 → 워크스페이스 빌드 → 새 모듈의 테스트를 돌린다.
# 옵션 없는 조합도 만드는 이유: 스텐실에 옵션별 분기(예: --resources 가 없으면 `bundle: .module` 이 빠진다)가 있다.
# 원본 저장소는 건드리지 않는다.
# git 워크트리가 아니라 작업 트리를 복사하므로 커밋하지 않은 템플릿·헬퍼 변경도 검사한다.
#
# 사본은 경로가 달라 DerivedData 를 따로 쓴다. 외부 패키지까지 처음부터 빌드하므로 몇 분 걸린다.
# DerivedData 는 사본 옆 임시 디렉터리에 두고 끝나면 함께 지운다. 기본 위치에 두면 실행마다 수 GB 씩 쌓인다.
# SPM 체크아웃(Tuist/.build)은 원본 것을 링크해 다시 받지 않는다. 원본에 없으면 사본에서 tuist install 을 한다.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 이름: 모든 옵션을 켠 것과 옵션 없는 것.
core_name="VerifyCore"
feature_name="VerifyFeature"
plain_core_name="VerifyPlainCore"
plain_feature_name="VerifyPlainFeature"

die() { printf '%s\n' "$*" >&2; exit 1; }
step() { printf '\n== %s\n' "$*"; }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
work="$scratch/repo"
derived_data="$scratch/DerivedData"

step "작업 트리 복사: $work"
# 생성물과 SPM 체크아웃은 복사하지 않는다(.gitignore 의 생성물과 같다).
rsync -a \
    --exclude .git \
    --exclude '*.xcodeproj' \
    --exclude '*.xcworkspace' \
    --exclude Derived \
    --exclude .build \
    --exclude .claude/worktrees \
    "$root/" "$work/"

cd "$work"
# mise 는 처음 보는 경로의 설정 파일을 믿지 않는다. 원본과 같은 mise.toml 이다.
mise trust --quiet "$work/mise.toml"
if [[ -d "$root/Tuist/.build" ]]; then
    ln -s "$root/Tuist/.build" "$work/Tuist/.build"
else
    step "의존성 설치 (tuist install)"
    mise exec -- tuist install
fi

step "모듈 생성 (모든 옵션: $core_name, $feature_name / 옵션 없음: $plain_core_name, $plain_feature_name)"
Scripts/new-module.sh core "$core_name" --demo --testing --resources >/dev/null
Scripts/new-module.sh feature "$feature_name" --demo --testing --resources >/dev/null
Scripts/new-module.sh core "$plain_core_name" >/dev/null
Scripts/new-module.sh feature "$plain_feature_name" >/dev/null

step "포맷·린트 (새 모듈만)"
modules=(
    "Modules/Core/$core_name" "Modules/Features/$feature_name"
    "Modules/Core/$plain_core_name" "Modules/Features/$plain_feature_name"
)
mise exec -- swiftformat --lint "${modules[@]}"
mise exec -- swiftlint lint --quiet "${modules[@]}"

step "프로젝트 생성 (tuist generate)"
mise exec -- tuist generate --no-open

step "의존성 검사 (tuist inspect dependencies)"
mise exec -- tuist inspect dependencies

# xcbuild.sh 는 CLAUDE_PROJECT_DIR 이 있으면 그 경로를 루트로 쓴다. 원본이 아니라 사본을 빌드하도록 덮어쓴다.
step "워크스페이스 빌드"
CLAUDE_PROJECT_DIR="$work" .claude/scripts/xcbuild.sh build -derivedDataPath "$derived_data"

step "새 모듈 테스트"
CLAUDE_PROJECT_DIR="$work" .claude/scripts/xcbuild.sh test -derivedDataPath "$derived_data" \
    -only-testing:"${core_name}Tests" \
    -only-testing:"${feature_name}Tests" \
    -only-testing:"${plain_core_name}Tests" \
    -only-testing:"${plain_feature_name}Tests"

step "통과: 템플릿으로 만든 모듈이 generate·의존성 검사·빌드·테스트를 통과했습니다."
