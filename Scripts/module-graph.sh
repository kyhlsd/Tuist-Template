#!/usr/bin/env bash
# 모듈 의존 그래프를 SVG 로 만들어 docs/images/module-graph.svg 에 덮어쓴다. README 의 "구조" 절이 이 이미지를 쓴다.
#
#   Scripts/module-graph.sh
#
# 테스트 타깃(-t)과 외부 패키지(-d)는 뺀다. Firebase 타깃이 그래프를 덮어 모듈 구조가 안 보이기 때문이다.
# 모듈이나 의존을 바꾼 PR 에서 다시 돌려 함께 커밋한다. CI 는 그래프가 최신인지 검사하지 않는다.
#
# SVG 렌더링에는 graphviz(dot)가 필요하다. 없으면 tuist 가 Homebrew 로 몰래 설치하므로 여기서 먼저 멈춘다.
# 출력 이름은 graph.svg 가 아니다. .gitignore 가 tuist graph 의 기본 출력(graph.*)을 무시한다.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="$root/docs/images/module-graph.svg"

die() { printf '%s\n' "$*" >&2; exit 1; }

command -v dot >/dev/null 2>&1 || die "graphviz 가 필요합니다: brew install graphviz"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

(cd "$root" && mise exec -- tuist graph --format svg --skip-test-targets --skip-external-dependencies --no-open --output-path "$tmp" >/dev/null)
[[ -f "$tmp/graph.svg" ]] || die "tuist graph 가 $tmp/graph.svg 를 만들지 않았습니다."

mkdir -p "$(dirname "$output")"
mv "$tmp/graph.svg" "$output"
printf '%s\n' "${output#"$root"/}"
