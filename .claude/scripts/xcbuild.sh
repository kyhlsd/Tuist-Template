#!/usr/bin/env bash
# 빌드/테스트 진입점. 시뮬레이터를 머신마다 한 번만 결정해 캐시합니다.
#
# Claude가 매 세션 `simctl list`를 돌리고 출력을 읽고 기기를 고르는 과정이
# 반복 토큰 비용입니다. 그 결정을 이 스크립트가 한 번만 하고 캐시하면,
# 이후로는 한 줄 명령과 필터링된 출력만 컨텍스트에 들어갑니다.
# destination이 고정되므로 DerivedData 캐시도 재사용됩니다.
#
#   ./.claude/scripts/xcbuild.sh build
#   ./.claude/scripts/xcbuild.sh test
#   ./.claude/scripts/xcbuild.sh test -only-testing:AppTests/PaymentTests
#   ./.claude/scripts/xcbuild.sh destination      # 현재 고정된 기기 확인 (사람이 읽는 형식)
#   ./.claude/scripts/xcbuild.sh udid             # UDID만 출력 (XcodeBuildMCP 등에 그대로 전달)
#   ./.claude/scripts/xcbuild.sh reset            # 캐시 삭제 후 재선택
set -euo pipefail

# ── 여기만 채우세요 ───────────────────────────────────────────────
# Tuist 가 만드는 워크스페이스 스킴. 모든 모듈의 테스트 타깃이 들어 있다.
# (앱 스킴 TuistApp 에는 TuistAppTests 만 있다.)
# 앱 이름을 바꾸면 "<앱 이름>-Workspace" 로 함께 바꾼다.
SCHEME="TuistApp-Workspace"
# .xcworkspace와 .xcodeproj가 함께 있거나 경로가 모호할 때만 채웁니다.
#   예: PROJECT_FLAGS=(-workspace App.xcworkspace)
PROJECT_FLAGS=(-workspace TuistApp.xcworkspace)
# ─────────────────────────────────────────────────────────────────

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cache="$root/.claude/sim.local"

die() { printf '%s\n' "$*" >&2; exit 1; }

[ "$SCHEME" != "<Scheme>" ] || die "xcbuild.sh 상단의 SCHEME을 먼저 채우세요."

pick_simulator() {
  command -v jq >/dev/null 2>&1 || die "jq가 필요합니다: brew install jq"
  xcrun simctl list -j devices available | jq -r '
    [ .devices | to_entries[]
      | select(.key | test("SimRuntime\\.iOS-[0-9]+-[0-9]+"))
      | (.key | capture("iOS-(?<a>[0-9]+)-(?<b>[0-9]+)")) as $v
      | .value[]
      | select(.name | test("^iPhone"))
      | { rank: (($v.a | tonumber) * 1000 + ($v.b | tonumber)), name, udid }
    ]
    | sort_by(.rank) | last | "\(.udid)\t\(.name)"
  '
}

resolve() {
  # 1) 환경변수 우선
  if [ -n "${IOS_SIM_UDID:-}" ]; then printf '%s\t%s\n' "$IOS_SIM_UDID" "(IOS_SIM_UDID)"; return; fi

  # 2) 캐시가 있고 그 기기가 아직 존재하면 재사용
  if [ -f "$cache" ]; then
    local udid name
    IFS=$'\t' read -r udid name < "$cache" || true
    if [ -n "${udid:-}" ] && xcrun simctl list devices available | grep -qF "$udid"; then
      printf '%s\t%s\n' "$udid" "$name"; return
    fi
  fi

  # 3) 새로 고르고 캐시
  local picked; picked=$(pick_simulator)
  [ -n "$picked" ] && [ "$picked" != "null" ] || die "사용 가능한 iPhone 시뮬레이터가 없습니다. Xcode에서 하나 추가하세요."
  printf '%s\n' "$picked" > "$cache"
  printf '%s\n' "$picked"
}

run_xcodebuild() {
  local action="$1"; shift
  local udid name
  IFS=$'\t' read -r udid name <<< "$(resolve)"
  # PROJECT_FLAGS 의 워크스페이스/프로젝트 경로는 루트 기준 상대 경로다.
  # 하위 디렉터리에서 호출해도 같은 결과가 나오도록 여기서 루트로 옮긴다.
  cd "$root"
  if command -v xcbeautify >/dev/null 2>&1; then
    # --disable-logging: 매 실행마다 찍히는 5줄짜리 버전 배너를 없앤다.
    # --disable-colored-output: ANSI 이스케이프는 터미널 밖(= 모델 컨텍스트)에서 순수 낭비다.
    # 성공 빌드 출력이 90바이트에서 16바이트로 줄어든다. 실패 시에는 에러 줄마다 붙던 색상 코드가 빠진다.
    xcodebuild "$action" -scheme "$SCHEME" "${PROJECT_FLAGS[@]+"${PROJECT_FLAGS[@]}"}" \
      -destination "id=$udid" "$@" 2>&1 \
      | xcbeautify --quiet --disable-logging --disable-colored-output
  else
    xcodebuild "$action" -scheme "$SCHEME" "${PROJECT_FLAGS[@]+"${PROJECT_FLAGS[@]}"}" \
      -destination "id=$udid" "$@"
  fi
}

case "${1:-}" in
  build) shift; run_xcodebuild build "$@" ;;
  test)  shift; run_xcodebuild test  "$@" ;;
  destination) IFS=$'\t' read -r udid name <<< "$(resolve)"; printf '%s  (%s)\n' "$name" "$udid" ;;
  udid) IFS=$'\t' read -r udid name <<< "$(resolve)"; printf '%s\n' "$udid" ;;
  reset) rm -f "$cache"; echo "시뮬레이터 캐시를 지웠습니다. 다음 실행에서 다시 선택합니다." ;;
  *) die "사용법: xcbuild.sh {build|test|destination|udid|reset} [xcodebuild 추가 인자]" ;;
esac
