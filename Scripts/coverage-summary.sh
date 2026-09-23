#!/usr/bin/env bash
# 테스트 결과 번들(.xcresult)의 라인 커버리지를 타깃별 마크다운 표로 낸다.
#
#   Scripts/coverage-summary.sh <xcresult>
#
# CI 는 출력을 $GITHUB_STEP_SUMMARY 에 붙인다. 커버리지로 실패시키지 않는다(게이트 없음).
# 대상 목록은 워크스페이스 스킴의 codeCoverageTargets(Scheme+Workspace.swift)가 정한다.
# 테스트 번들(.xctest)은 스킴에서 빠져 있지만 여기서도 한 번 더 걸러낸다. 이름(…Tests)으로는 거르지 않는다.
# 이름이 Tests 로 끝나는 구현 모듈이 생기면 표에서 조용히 빠지기 때문이다.
set -euo pipefail

die() { printf '%s\n' "$*" >&2; exit 1; }

[[ $# -eq 1 ]] || die "사용법: $0 <xcresult>"
[[ -d "$1" ]] || die "xcresult 번들이 없습니다: $1"

no_data="### 코드 커버리지

커버리지 데이터가 없습니다."

# 커버리지를 켜지 않고 만든 번들이면 xccov 가 "No coverage data" 로 실패한다. 그 경우만 정상으로 본다.
err="$(mktemp)"
trap 'rm -f "$err"' EXIT
if ! report="$(xcrun xccov view --report --json "$1" 2>"$err")"; then
    grep -q "No coverage data" "$err" || die "$(cat "$err")"
    printf '%s\n' "$no_data"
    exit 0
fi

# 타깃 이름은 "Networking.framework", "TuistApp.app" 처럼 확장자가 붙어 있다. 표에는 확장자를 뗀 이름을 쓴다.
jq -r --arg no_data "$no_data" '
  def pct: . * 1000 | round | "\(. / 10 | floor).\(. % 10)%";
  [ .targets[]?
    | select(.name | endswith(".xctest") | not)
    | .name |= sub("\\.[^.]+$"; "")
    | select(.executableLines > 0) ]
  | sort_by(.lineCoverage) as $targets
  | if ($targets | length) == 0 then
      $no_data
    else
      ($targets | map(.coveredLines) | add) as $covered
      | ($targets | map(.executableLines) | add) as $total
      | ([ "### 코드 커버리지",
           "",
           "전체 라인 커버리지: **\($covered / $total | pct)** (\($covered)/\($total))",
           "",
           "| 타깃 | 라인 커버리지 | 커버/전체 |",
           "|---|---:|---:|" ]
         + ($targets | map("| \(.name) | \(.lineCoverage | pct) | \(.coveredLines)/\(.executableLines) |")))
      | join("\n")
    end
' <<<"$report"
