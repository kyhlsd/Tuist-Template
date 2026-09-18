#!/usr/bin/env bash
# PostToolUse(Edit|Write) 훅 — 검사만 하고 파일을 바꾸지 않습니다.
#
# 훅이 파일을 직접 재포맷하면 Claude의 컨텍스트에 있는 사본이 낡아져
# 이어지는 편집이 실패합니다(그리고 재시도 턴을 낭비합니다).
# 그래서 여기서는 위반만 감지해 exit 2로 돌려주고, 실제 수정은 Claude가 하게 합니다.
set -uo pipefail

payload=$(cat)
log() { printf '[swift-quality] %s\n' "$1" >&2; }

command -v jq >/dev/null 2>&1 || { log "jq 없음 — 검사 건너뜀 (brew install jq)"; exit 0; }

file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')
case "$file" in *.swift) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
problems=""

# 1) 포맷 검사 (변경하지 않음)
if command -v swiftformat >/dev/null 2>&1; then
  if ! swiftformat --lint "$file" >/dev/null 2>&1; then
    problems="포맷 위반: \`swiftformat \"$file\"\`를 실행한 뒤 해당 파일을 다시 읽고 이어가세요."
  fi
fi

# 2) 린트 검사 (error 심각도만 차단)
if command -v swiftlint >/dev/null 2>&1; then
  # --config 를 넘기지 않고 프로젝트 루트에서 실행한다. 그래야 루트 .swiftlint.yml 과
  # 하위 폴더의 중첩 설정(예: 토큰 폴더의 no_magic_numbers 해제)이 함께 적용된다.
  # --config 를 주면 중첩 설정이 무시된다.
  # 경로를 직접 넘기면 excluded 가 무시되므로 --force-exclude 로 다시 적용한다.
  output=$(cd "$project_dir" && swiftlint lint --quiet --force-exclude "$file" 2>/dev/null || true)
  errors=$(printf '%s\n' "$output" | grep -F ': error:' || true)
  if [ -n "$errors" ]; then
    problems="${problems:+$problems
}SwiftLint 에러 — 규칙 억제 없이 코드를 고치세요:
$errors"
  fi
fi

[ -n "$problems" ] || exit 0

printf '%s\n' "$problems" >&2
exit 2
