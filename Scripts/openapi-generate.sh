#!/usr/bin/env bash
# OpenAPI 명세에서 Networking 모듈의 Swift 클라이언트를 만든다.
#
#   Scripts/openapi-generate.sh           # 생성물을 Sources/Generated/ 에 덮어쓴다
#   Scripts/openapi-generate.sh --check   # 커밋된 생성물이 명세와 다르면 exit 1
#
# 생성기는 빌드 플러그인이 아니라 CLI 로 돌린다(Tuist 의 XcodeProj 통합이 플러그인을
# 지원하지 않는다). 생성기 버전은 mise.toml 에 고정되어 있다.
# 생성물은 *.generated.swift 이름으로 저장해 lint/format 제외 규칙을 그대로 받는다.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
module="$root/Modules/Core/Networking"
spec="$module/OpenAPI/openapi.yaml"
config="$module/OpenAPI/openapi-generator-config.yaml"
output="$module/Sources/Generated"

die() { printf '%s\n' "$*" >&2; exit 1; }

check=false
case "${1:-}" in
    "") ;;
    --check) check=true ;;
    *) die "사용법: $0 [--check]" ;;
esac

[[ -f "$spec" ]] || die "명세가 없습니다: ${spec#"$root"/}"
[[ -f "$config" ]] || die "생성기 설정이 없습니다: ${config#"$root"/}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 생성기는 설정 요약을 stderr 로 출력한다. 실패했을 때만 보여 준다.
if ! mise exec -- swift-openapi-generator generate \
    --config "$config" \
    --output-directory "$tmp/raw" \
    "$spec" >"$tmp/generator.log" 2>&1; then
    cat "$tmp/generator.log" >&2
    die "생성에 실패했습니다."
fi

# 생성기는 Types.swift, Types+Components.swift, Client.swift 등 여러 파일을 만든다.
# 모두 *.generated.swift 로 바꾼다.
mkdir -p "$tmp/renamed"
shopt -s nullglob
generated=("$tmp/raw/"*.swift)
[[ ${#generated[@]} -gt 0 ]] || die "생성기가 Swift 파일을 만들지 않았습니다."
for file in "${generated[@]}"; do
    name="$(basename "$file" .swift)"
    mv "$file" "$tmp/renamed/$name.generated.swift"
done

if "$check"; then
    if ! diff -r "$tmp/renamed" "$output" >/dev/null; then
        die "생성물이 명세와 다릅니다. Scripts/openapi-generate.sh 를 실행하고 결과를 커밋하세요."
    fi
    echo "생성물이 명세와 일치합니다."
else
    rm -rf "$output"
    mkdir -p "$output"
    mv "$tmp/renamed/"*.generated.swift "$output/"
    echo "생성 완료: ${output#"$root"/}"
fi
