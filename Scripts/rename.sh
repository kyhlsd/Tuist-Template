#!/usr/bin/env bash
# 이 저장소를 새 앱 이름·번들 ID 접두사·조직 이름으로 바꾼다. 템플릿으로 새 앱을 만들 때 쓴다.
#
#   Scripts/rename.sh <NewName> <bundlePrefix> [<organizationName>]
#   Scripts/rename.sh Sample com.example "Example Inc"
#
# 옛 값은 Tuist/ProjectDescriptionHelpers/AppConstants.swift 에서 읽는다. 그래서 여러 번 실행해도 된다.
# URL 스킴은 새 이름을 소문자로 바꾼 값이다. organizationName 을 생략하면 바꾸지 않는다.
#
# git 이 추적하는 텍스트 파일 전부에서 대소문자를 구분해 부분 문자열을 치환한다(헤더 주석 포함).
# 제외: docs/plans/(당시 기록), *.generated.swift(생성물), 바이너리.
# 경로에 옛 이름이 들어간 파일은 git mv 로 옮긴다.
#
# 작업 트리가 깨끗할 때만 실행한다. 결과는 git diff 로 검토하고, 되돌리려면 git reset --hard 한다.
# Firebase 설정, ClientKeys.xcconfig, 번들 ID 등록, 저장소 폴더 이름은 바꾸지 않는다(끝에 안내한다).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
constants="Tuist/ProjectDescriptionHelpers/AppConstants.swift"

die() { printf '%s\n' "$*" >&2; exit 1; }

[[ $# -eq 2 || $# -eq 3 ]] || die "사용법: $0 <NewName> <bundlePrefix> [<organizationName>]"
new_name="$1"
new_prefix="$2"

# 타깃 이름·@testable import(Swift 식별자), 번들 ID(영숫자·-·.), URL 스킴(영문자로 시작)의 교집합이다.
[[ "$new_name" =~ ^[A-Za-z][A-Za-z0-9]*$ ]] || die "앱 이름은 영문자로 시작하는 영숫자여야 합니다: $new_name"
# CFBundleIdentifier 허용 문자(영숫자, -, .). 빈 구간은 안 된다.
[[ "$new_prefix" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*$ ]] || die "번들 ID 접두사 형식이 아닙니다: $new_prefix"

cd "$root"

# 앱 타깃(<이름>, <이름>Tests), 번들 ID, @testable import 가 기존 모듈과 겹치면 생성·빌드가 깨진다.
# 모듈의 파생 타깃(<모듈>Interface, <모듈>Testing, <모듈>Tests, <모듈>Demo)도 같은 이름 공간이다.
# 번들 ID 는 소문자로 만들어지므로 대소문자를 무시하고 비교한다.
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
new_lower="$(lower "$new_name")"

# 앱 이름은 앱 타깃의 Swift 모듈 이름이 된다. 시스템 모듈과 같으면 import 가 자기 모듈로 풀린다.
# Scripts/new-module.sh 에 같은 목록이 있다. 바꾸면 함께 바꾼다.
for reserved in swift foundation swiftui uikit combine observation dispatch swiftdata coredata charts xctest testing; do
    [[ "$new_lower" != "$reserved" ]] || die "시스템 모듈과 같은 이름은 쓸 수 없습니다: $new_name"
done
for module_dir in Modules/Features/*/ Modules/Core/*/; do
    [[ -d "$module_dir" ]] || continue
    module="$(lower "$(basename "$module_dir")")"
    for taken in "$module" "${module}interface" "${module}testing" "${module}tests" "${module}demo"; do
        [[ "$new_lower" != "$taken" && "${new_lower}tests" != "$taken" ]] ||
            die "기존 모듈(${module_dir%/})의 타깃 이름과 겹칩니다: $new_name"
    done
done

[[ -z "$(git status --porcelain)" ]] || die "작업 트리가 깨끗하지 않습니다. 커밋하거나 치운 뒤 실행하세요."

read_constant() {
    perl -ne 'print $1 if /static let '"$1"' = "([^"]*)"/' "$constants"
}
old_name="$(read_constant appName)"
old_prefix="$(read_constant bundleIDPrefix)"
old_org="$(read_constant organizationName)"
old_scheme="$(read_constant urlScheme)"
[[ -n "$old_name" && -n "$old_prefix" && -n "$old_org" && -n "$old_scheme" ]] ||
    die "$constants 에서 appName, bundleIDPrefix, organizationName, urlScheme 을 모두 읽지 못했습니다."

new_org="${3:-$old_org}"
# Swift 문자열 리터럴 안에 그대로 들어간다.
[[ -n "$new_org" && "$new_org" != *'"'* && "$new_org" != *'\'* ]] ||
    die "조직 이름은 비어 있지 않고 \" 와 \\ 를 포함하지 않아야 합니다."
new_scheme="$new_lower"

if [[ "$new_name" == "$old_name" && "$new_prefix" == "$old_prefix" &&
    "$new_org" == "$old_org" && "$new_scheme" == "$old_scheme" ]]; then
    echo "바꿀 것이 없습니다."
    exit 0
fi

echo "앱 이름:   $old_name → $new_name"
echo "URL 스킴:  $old_scheme → $new_scheme"
echo "번들 접두사: $old_prefix → $new_prefix"
echo "조직:      $old_org → $new_org"

# 치환 대상: 추적 중인 텍스트 파일 중 옛 값이 하나라도 들어 있는 것.
targets=()
while IFS= read -r -d '' file; do
    case "$file" in
        docs/plans/* | *.generated.swift) continue ;;
    esac
    [[ -f "$file" && ! -L "$file" ]] || continue
    grep -Iq . "$file" || continue
    grep -qF -e "$old_name" -e "$old_scheme" -e "$old_prefix" -e "$old_org" "$file" || continue
    targets+=("$file")
done < <(git ls-files -z)

if [[ ${#targets[@]} -gt 0 ]]; then
    occurrences="$(grep -ohF -e "$old_name" -e "$old_scheme" -e "$old_prefix" -e "$old_org" "${targets[@]}" | wc -l | tr -d ' ')"
    echo "치환: 파일 ${#targets[@]}개, ${occurrences}곳"

    # 한 파일을 한 번에 훑는다. 옛 이름이 새 이름의 부분 문자열이어도(App → MyApp) 두 번 치환되지 않는다.
    # 같은 위치에서는 앞의 것이 이긴다: 조직 → 번들 접두사 → 앱 이름 → 스킴.
    OLD_ORG="$old_org" NEW_ORG="$new_org" \
        OLD_PREFIX="$old_prefix" NEW_PREFIX="$new_prefix" \
        OLD_NAME="$old_name" NEW_NAME="$new_name" \
        OLD_SCHEME="$old_scheme" NEW_SCHEME="$new_scheme" \
        perl -pi -e '
            BEGIN {
                my @pairs = grep { $_->[0] ne $_->[1] } (
                    [$ENV{OLD_ORG}, $ENV{NEW_ORG}],
                    [$ENV{OLD_PREFIX}, $ENV{NEW_PREFIX}],
                    [$ENV{OLD_NAME}, $ENV{NEW_NAME}],
                    [$ENV{OLD_SCHEME}, $ENV{NEW_SCHEME}],
                );
                %map = map { $_->[0] => $_->[1] } reverse @pairs;
                $pattern = join "|", map { quotemeta $_->[0] } @pairs;
            }
            s/($pattern)/$map{$1}/g if length $pattern;
        ' "${targets[@]}"
fi

# 파일명 = 타입명 규칙을 지키도록 경로도 옮긴다(예: <앱 이름>App.swift, <앱 이름>Tests.swift).
moved=0
if [[ "$new_name" != "$old_name" ]]; then
    while IFS= read -r -d '' file; do
        case "$file" in
            docs/plans/*) continue ;;
        esac
        [[ "$file" == *"$old_name"* ]] || continue
        # 앱 이름은 영숫자와 _ 뿐이라 패턴 문자가 없다.
        destination="${file//$old_name/$new_name}"
        mkdir -p "$(dirname "$destination")"
        git mv "$file" "$destination"
        moved=$((moved + 1))
    done < <(git ls-files -z)
fi
echo "파일 이동: ${moved}개"

# 옛 값이 남았는지 본다. 새 값이 옛 값을 포함하면(App → MyApp) 이 검사는 의미가 없어 건너뛴다.
leftover_patterns=()
[[ "$new_name" == *"$old_name"* ]] || leftover_patterns+=(-e "$old_name")
[[ "$new_scheme" == *"$old_scheme"* ]] || leftover_patterns+=(-e "$old_scheme")
if [[ ${#leftover_patterns[@]} -gt 0 ]]; then
    # git grep 은 일치 없음이 1, 오류가 2 이상이다. 오류를 "남은 것 없음"으로 읽지 않는다.
    status=0
    leftovers="$(git grep -I -l "${leftover_patterns[@]}" -- ':!docs/plans' ':!*.generated.swift')" || status=$?
    if [[ "$status" -eq 0 ]]; then
        printf '%s\n' "옛 이름이 남은 파일:" "$leftovers" >&2
        die "치환이 끝나지 않았습니다. 위 파일을 확인하세요. 되돌리려면 git reset --hard 합니다."
    fi
    [[ "$status" -eq 1 ]] || die "git grep 이 실패했습니다(exit $status). 치환 결과를 git diff 로 직접 확인하세요."
fi

echo
echo "완료. git diff 로 검토한다. 되돌리려면 git reset --hard 한다."
echo
echo "다음 할 일:"
echo "  - mise exec -- tuist install && mise exec -- tuist generate"
echo "  - 옛 워크스페이스 삭제: rm -rf $old_name.xcworkspace"
echo "  - 스크립트가 바꾸지 않는 것:"
echo "      Firebase GoogleService-Info.plist (새 번들 ID 로 다시 받는다)"
echo "      Configurations/ClientKeys.xcconfig"
echo "      App Store Connect / 개발자 계정의 번들 ID 등록"
echo "      저장소 폴더 이름"
