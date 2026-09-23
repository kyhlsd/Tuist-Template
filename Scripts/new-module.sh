#!/usr/bin/env bash
# 새 모듈을 만들고 Module.swift 등록부에 추가한다.
#
#   Scripts/new-module.sh feature Profile --demo
#   Scripts/new-module.sh core Analytics --testing
#   Scripts/new-module.sh <feature|core> <Name> [--demo] [--testing] [--resources]
#
# 파일은 Tuist/Templates/<feature|core> 템플릿으로 만든다(tuist scaffold).
# scaffold 는 기존 파일을 고치지 못하고 조건부 파일도 만들지 못하므로, 이 스크립트가
# 옵션 폴더 정리와 Module.all / Module.withDemoApp 등록을 맡는다.
# 등록 위치는 Module.swift 의 마커 주석 바로 위다.
#
# 실패하면 새 모듈 폴더를 지우고 Module.swift 를 원래대로 되돌린다.
# App/Project.swift 에 의존성을 연결하는 것은 직접 한다(끝에 안내한다).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
module_file="$root/Tuist/ProjectDescriptionHelpers/Module.swift"
marker_all="// new-module.sh 가 이 줄 위에 추가한다. 지우거나 옮기지 않는다."
marker_demo="// new-module.sh 가 이 줄 위에 추가한다(데모 앱). 지우거나 옮기지 않는다."

die() { printf '%s\n' "$*" >&2; exit 1; }
usage() { die "사용법: $0 <feature|core> <Name> [--demo] [--testing] [--resources]"; }

[[ $# -ge 2 ]] || usage
kind="$1"
name="$2"
shift 2

demo=false
testing=false
resources=false
for option in "$@"; do
    case "$option" in
        --demo) demo=true ;;
        --testing) testing=true ;;
        --resources) resources=true ;;
        *) usage ;;
    esac
done

case "$kind" in
    feature) target="$root/Modules/Features/$name" ;;
    core) target="$root/Modules/Core/$name" ;;
    *) usage ;;
esac

# 타깃 이름과 Swift 모듈 이름으로 쓰인다. 기존 모듈처럼 UpperCamel 이다.
[[ "$name" =~ ^[A-Z][A-Za-z0-9]*$ ]] || die "모듈 이름은 대문자로 시작하는 영숫자여야 합니다: $name"

# 템플릿이 만드는 파생 타깃(<Name>Interface, <Name>Testing, <Name>Tests, <Name>Demo)과 이름 공간이 같다.
# 이 접미사로 끝나면 다른 모듈의 파생 타깃(HomeInterface 등)과 겹칠 수 있다.
case "$name" in
    *Interface | *Testing | *Tests | *Demo) die "Interface, Testing, Tests, Demo 로 끝나는 이름은 쓸 수 없습니다: $name" ;;
esac

# 번들 ID 는 소문자로 만들어지고 파일 시스템도 대소문자를 구분하지 않으므로 이름은 소문자로 비교한다.
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
name_lower="$(lower "$name")"

# 같은 이름의 시스템 모듈이 있으면 import 가 자기 모듈로 풀린다(core Testing 이면 템플릿 테스트의 import Testing 이 깨진다).
# Scripts/rename.sh 에 같은 목록이 있다. 바꾸면 함께 바꾼다.
for reserved in swift foundation swiftui uikit combine observation dispatch swiftdata coredata charts xctest testing; do
    [[ "$name_lower" != "$reserved" ]] || die "시스템 모듈과 같은 이름은 쓸 수 없습니다: $name"
done

# 새 모듈과 파생 타깃이 앱 타깃(<앱>, <앱>Tests)과 겹치면 안 된다. Scripts/rename.sh 는 반대 방향을 본다.
app_name="$(perl -ne 'print $1 if /static let appName = "([^"]*)"/' "$root/Tuist/ProjectDescriptionHelpers/AppConstants.swift")"
[[ -n "$app_name" ]] || die "Tuist/ProjectDescriptionHelpers/AppConstants.swift 에서 appName 을 읽지 못했습니다."
app_lower="$(lower "$app_name")"
mine=("$name_lower" "${name_lower}interface" "${name_lower}testing" "${name_lower}tests" "${name_lower}demo")
for derived in "${mine[@]}"; do
    [[ "$derived" != "$app_lower" && "$derived" != "${app_lower}tests" ]] ||
        die "앱($app_name)의 타깃 이름과 겹칩니다: $name"
done

# 이름 끝의 Interface/Testing/Tests/Demo 검사는 대소문자를 구분한다(소문자로 하면 Contests, Protesting 같은 이름까지 막힌다).
# Hometests 처럼 대소문자만 다른 충돌은 기존 모듈의 파생 타깃과 소문자로 직접 비교해 막는다.
for module_dir in "$root"/Modules/Features/*/ "$root"/Modules/Core/*/; do
    [[ -d "$module_dir" ]] || continue
    module="$(lower "$(basename "$module_dir")")"
    for taken in "$module" "${module}interface" "${module}testing" "${module}tests" "${module}demo"; do
        for derived in "${mine[@]}"; do
            [[ "$derived" != "$taken" ]] || die "기존 모듈($(basename "$module_dir"))의 타깃 이름과 겹칩니다: $name"
        done
    done
done

# scaffold 는 이미 있는 파일을 조용히 덮어쓴다. 피처와 Core 는 이름을 공유하지 못하므로 둘 다 본다.
for existing in "$root/Modules/Features/$name" "$root/Modules/Core/$name"; do
    [[ ! -e "$existing" ]] || die "이미 있습니다: ${existing#"$root"/}"
done
! grep -qF "\"$name\"" "$module_file" || die "Module.swift 에 \"$name\" 이 이미 있습니다."

for marker in "$marker_all" "$marker_demo"; do
    count="$(grep -cF -- "$marker" "$module_file" || true)"
    [[ "$count" -eq 1 ]] || die "Module.swift 에 등록 마커가 정확히 한 번 있어야 합니다(${count}번): $marker"
done

cd "$root"

tmp="$(mktemp -d)"
cp "$module_file" "$tmp/Module.swift"
succeeded=false
cleanup() {
    if ! "$succeeded"; then
        rm -rf "$target"
        cp "$tmp/Module.swift" "$module_file"
        printf '%s\n' "실패해서 되돌렸습니다: ${target#"$root"/}, Tuist/ProjectDescriptionHelpers/Module.swift" >&2
    fi
    rm -rf "$tmp"
}
trap cleanup EXIT

# scaffold 는 진행 상황을 길게 출력한다. 실패했을 때만 보여 준다.
if ! mise exec -- tuist scaffold "$kind" \
    --name "$name" \
    --demo "$demo" \
    --testing "$testing" \
    --resources "$resources" \
    -p "$root" >"$tmp/scaffold.log" 2>&1; then
    cat "$tmp/scaffold.log" >&2
    die "scaffold 에 실패했습니다."
fi
[[ -f "$target/Project.swift" ]] || die "scaffold 가 ${target#"$root"/}/Project.swift 를 만들지 않았습니다."

# 템플릿은 옵션 폴더를 모두 만든다. 요청하지 않은 것은 방금 만든 모듈 폴더 안에서만 지운다.
"$demo" || rm -rf "$target/Demo"
"$testing" || rm -rf "$target/Testing"
"$resources" || rm -rf "$target/Resources"

# import 정렬은 모듈 이름에 따라 달라서 템플릿으로 맞출 수 없다. 만든 파일만 포맷한다.
if ! mise exec -- swiftformat "$target" >"$tmp/swiftformat.log" 2>&1; then
    cat "$tmp/swiftformat.log" >&2
    die "swiftformat 에 실패했습니다."
fi

entry=".$kind(\"$name\"),"
insert_above() {
    # 마커 줄의 들여쓰기를 그대로 쓴다.
    perl -pi -e 'BEGIN { ($marker, $entry) = splice(@ARGV, 0, 2) } print "$1$entry\n" if /^(\s*)\Q$marker\E\s*$/' \
        "$1" "$entry" "$module_file"
}
insert_above "$marker_all"
expected=1
if "$demo"; then
    insert_above "$marker_demo"
    expected=2
fi

count="$(grep -cF -- "$entry" "$module_file" || true)"
[[ "$count" -eq "$expected" ]] || die "Module.swift 에 $entry 이 ${expected}번이 아니라 ${count}번 있습니다."

succeeded=true

echo "생성 완료: ${target#"$root"/}"
echo "등록: Module.all$("$demo" && echo ", Module.withDemoApp")"
echo
echo "다음 할 일:"
if [[ "$kind" == feature ]]; then
    echo "  - App/Project.swift 의 dependencies 에 추가한다:"
    echo "      .module(.feature(\"$name\")),"
    echo "      .module(.featureInterface(\"$name\")),"
    echo "    App 이 ${name}Route 를 화면으로 바꾸도록 연결한다."
else
    echo "  - 쓰는 모듈의 매니페스트에 .module(.core(\"$name\")) 를 추가한다."
fi
echo "  - mise exec -- tuist generate"
