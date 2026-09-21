#!/usr/bin/env bash
# 리뷰 기준 스냅샷(트리 해시)을 출력합니다. `/ios-review`가 라운드마다 한 번 부릅니다.
#
#   ./.claude/scripts/review-snapshot.sh
#
# 추적되지 않은 새 파일까지 담기 위해 실제 인덱스를 임시 파일로 복사해 `git add -A`와
# `git write-tree`를 돌립니다. 실제 인덱스·작업 트리·ref는 건드리지 않고 객체만 만듭니다.
# `.gitignore`에 걸린 파일은 담기지 않습니다.
#
# `git stash create`는 새 파일을 담지 못하고, `git add -N`이 섞이면 실패하므로 쓰지 않습니다.
# 명령을 스크립트 하나로 묶은 이유: 리뷰 에이전트에서 `$(...)` 치환이나 `GIT_INDEX_FILE=` 접두 명령은
# 권한 승인에서 막히지만, 이 스크립트 경로는 `.claude/settings.json`에서 허용해 둘 수 있습니다.
set -euo pipefail

# 루트는 스크립트가 있는 체크아웃에서 git 에 묻는다. CLAUDE_PROJECT_DIR 는 워크트리에서 실행해도
# 원래 체크아웃을 가리킬 수 있어, 리뷰하는 트리가 아닌 다른 트리의 해시가 나올 수 있다.
root="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$root"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

cp "$(git rev-parse --git-path index)" "$tmp"
GIT_INDEX_FILE="$tmp" git add -A
GIT_INDEX_FILE="$tmp" git write-tree
