#!/usr/bin/env bash
# PreToolUse(Bash) 훅 — 기본 브랜치 직접 커밋을 실제로 차단합니다.
#
# CLAUDE.md 의 "금지" 세 항목 중 나머지 둘(생성 파일 편집, 규칙 억제)은
# .swiftlint.yml 의 excluded/custom_rules 가 기계적으로 막고 있는데,
# 이 항목만 문장으로만 존재했습니다.
#
# permissions.deny 로는 부족합니다. deny 는 커맨드 문자열만 보므로
# "지금 어느 브랜치인가"를 조건에 넣을 수 없고, `git -C . commit` 같은
# 변형에도 걸리지 않습니다. 여기서는 실제 브랜치를 읽고 판단합니다.
set -uo pipefail

payload=$(cat)

command -v jq >/dev/null 2>&1 || exit 0

cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

# commit 이 "서브커맨드 위치"에 있을 때만 잡는다.
# git 바로 뒤(또는 -C <경로> / -c <키=값> 옵션 뒤)의 첫 단어가 commit 인 경우만이다.
# 이렇게 좁히지 않으면 `git log --grep "commit"` 처럼 commit 이 인자로 등장하는 명령까지 막힌다.
# 절대 경로 호출(/usr/bin/git)과 파이프·&&·서브셸 뒤의 git 도 함께 본다.
git_re='(^|[;&|(]|\$\()[[:space:]]*([^[:space:]]*/)?git([[:space:]]+-[cC][[:space:]]*[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'
printf '%s' "$cmd" | grep -Eq "$git_re" || exit 0

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
branch=$(cd "$root" && git symbolic-ref --quiet --short HEAD 2>/dev/null) || exit 0
[ -n "$branch" ] || exit 0

# 기본 브랜치 이름은 origin/HEAD 에서 읽고, 없으면 main/master 로 본다.
default=$(cd "$root" && git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
[ -n "$default" ] || default="main"

case "$branch" in
  "$default"|main|master) ;;
  *) exit 0 ;;
esac

cat >&2 <<MSG
'$branch' 브랜치에 직접 커밋하려 했습니다. CLAUDE.md 의 금지 항목입니다.

작업 브랜치를 먼저 만드세요:

  git switch -c <브랜치명>

그 뒤 같은 커밋을 다시 실행하면 됩니다.
MSG
exit 2
