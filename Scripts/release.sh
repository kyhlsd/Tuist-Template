#!/usr/bin/env bash
# 앱을 아카이브해 TestFlight 에 올린다. .github/workflows/deploy.yml 과 ci.yml 의 release-archive 잡이 쓴다.
# 로직은 여기 두고 워크플로는 얇게 유지한다. 로컬에서도 같은 명령으로 재현할 수 있다.
#
#   Scripts/release.sh preflight                       # 배포 시크릿·Team ID 확인
#   Scripts/release.sh write-secrets                   # p8 키(경로 출력)·ClientKeys.xcconfig 를 파일로 쓴다
#   Scripts/release.sh archive <Release|Staging> [--unsigned]
#   Scripts/release.sh upload <Release|Staging>        # 아카이브를 export 하면서 App Store Connect 에 올린다
#   Scripts/release.sh version <Release|Staging>       # 해당 xcconfig 의 MARKETING_VERSION
#
# 환경변수
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8   App Store Connect API 키(p8 은 PEM 원문). 셋 다 없으면 배포를 건너뛴다.
#   ASC_KEY_PATH                            write-secrets 가 출력한 p8 경로. 서명 archive·upload 에 필요하다.
#   CLIENT_KEYS_XCCONFIG                    Configurations/ClientKeys.xcconfig 내용(선택).
#   BUILD_NUMBER                            CURRENT_PROJECT_VERSION 을 덮어쓴다. 서명 archive 에는 필수.
#   TEAM_ID                                 upload 의 teamID. 없으면 Signing.xcconfig 에서 읽는다.
#   ARCHIVE_PATH                            기본값 ${RUNNER_TEMP:-$TMPDIR}/<앱 이름>-<구성>.xcarchive
#
# 서명은 ASC API 키로 하는 cloud signing 이다(-allowProvisioningUpdates). 인증서·프로필을 따로 두지 않는다.
# 앱 이름은 AppConstants.swift 에서 읽는다. Scripts/rename.sh 뒤에도 고칠 곳이 없다.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
constants="Tuist/ProjectDescriptionHelpers/AppConstants.swift"
signing="Configurations/Signing.xcconfig"
client_keys="Configurations/ClientKeys.xcconfig"
tmp_dir="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
tmp_dir="${tmp_dir%/}"

die() { printf '%s\n' "$*" >&2; exit 1; }

# GitHub Actions 에서는 실행 요약의 Annotations 에 뜨도록 ::warning:: 으로 남긴다.
# stdout 은 write-secrets 의 경로 출력 몫이라 둘 다 stderr 로 쓴다(러너는 stderr 의 명령도 읽는다).
warn() {
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        printf '::warning::%s\n' "$*" >&2
    else
        printf 'warning: %s\n' "$*" >&2
    fi
}

cd "$root"

app_name() {
    local name
    name="$(perl -ne 'print $1 if /static let appName = "([^"]*)"/' "$constants")"
    [[ -n "$name" ]] || die "$constants 에서 appName 을 읽지 못했습니다."
    printf '%s' "$name"
}

# xcconfig 의 `KEY = 값` 한 줄을 읽는다. 값이 비어 있으면 빈 문자열이다.
xcconfig_value() {
    perl -ne 'if (/^\s*'"$2"'\s*=\s*(.*?)\s*$/) { print $1; exit }' "$1"
}

configuration_arg() {
    case "${1:-}" in
        Release | Staging) printf '%s' "$1" ;;
        *) die "구성은 Release 또는 Staging 이어야 합니다: ${1:-(없음)}" ;;
    esac
}

scheme_for() {
    if [[ "$1" == "Release" ]]; then app_name; else printf '%s-Staging' "$(app_name)"; fi
}

archive_path_for() {
    printf '%s' "${ARCHIVE_PATH:-$tmp_dir/$(app_name)-$1.xcarchive}"
}

team_id() {
    local team="${TEAM_ID:-}"
    [[ -n "$team" ]] || team="$(xcconfig_value "$signing" DEVELOPMENT_TEAM)"
    printf '%s' "$team"
}

auth_flags() {
    [[ -n "${ASC_KEY_PATH:-}" && -f "$ASC_KEY_PATH" ]] ||
        die "ASC_KEY_PATH 가 없거나 파일이 아닙니다. write-secrets 출력 경로를 넘기세요."
    [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]] || die "ASC_KEY_ID 와 ASC_ISSUER_ID 가 필요합니다."
    printf '%s\n' -allowProvisioningUpdates \
        -authenticationKeyPath "$ASC_KEY_PATH" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID"
}

# xcbeautify 가 있으면 .claude/scripts/xcbuild.sh 와 같은 방식으로 출력을 줄인다.
run_xcodebuild() {
    if command -v xcbeautify >/dev/null 2>&1; then
        local beautify_flags=(--quiet --disable-logging --disable-colored-output)
        # xcbeautify 는 러너 이미지의 것을 쓰므로, --renderer 를 모르는 버전이면 붙이지 않는다.
        if [[ "${GITHUB_ACTIONS:-}" == "true" ]] && xcbeautify --help 2>/dev/null | grep -- '--renderer' >/dev/null; then
            beautify_flags+=(--renderer github-actions)
        fi
        xcodebuild "$@" 2>&1 | xcbeautify "${beautify_flags[@]}"
    else
        xcodebuild "$@"
    fi
}

# 셋 다 없으면 configured=false 로 성공한다. 새 템플릿 저장소의 CI 가 처음부터 초록이도록 하기 위해서다.
# 일부만 있으면 오설정이므로 실패한다.
cmd_preflight() {
    local present=() missing=() name
    for name in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8; do
        if [[ -n "${!name:-}" ]]; then present+=("$name"); else missing+=("$name"); fi
    done

    local outputs
    if [[ ${#present[@]} -eq 0 ]]; then
        outputs="configured=false"
    elif [[ ${#missing[@]} -gt 0 ]]; then
        die "배포 시크릿 일부가 없습니다: ${missing[*]}"
    else
        # Signing.local.xcconfig 는 CI 에 없으므로 보지 않는다.
        local team
        team="$(xcconfig_value "$signing" DEVELOPMENT_TEAM)"
        [[ -n "$team" ]] || die "$signing 의 DEVELOPMENT_TEAM 이 비어 있습니다. Team ID 를 커밋하세요(README '배포를 켜기 전')."
        outputs="configured=true"$'\n'"team_id=$team"
    fi

    printf '%s\n' "$outputs"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        printf '%s\n' "$outputs" >>"$GITHUB_OUTPUT"
    fi
}

cmd_write_secrets() {
    [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_KEY_P8:-}" ]] || die "ASC_KEY_ID 와 ASC_KEY_P8 이 필요합니다."
    local key_path="$tmp_dir/AuthKey_${ASC_KEY_ID}.p8"
    (
        umask 077
        printf '%s\n' "$ASC_KEY_P8" >"$key_path"
    )

    if [[ -n "${CLIENT_KEYS_XCCONFIG:-}" ]]; then
        # 로컬에서 실행했을 때 개발자의 파일을 덮어쓰지 않는다.
        if [[ -f "$client_keys" ]]; then
            warn "$client_keys 가 이미 있어 CLIENT_KEYS_XCCONFIG 로 덮어쓰지 않습니다."
        else
            printf '%s\n' "$CLIENT_KEYS_XCCONFIG" >"$client_keys"
        fi
    elif [[ ! -f "$client_keys" ]]; then
        warn "CLIENT_KEYS_XCCONFIG 가 없어 클라이언트 키 없이 빌드합니다."
    fi

    printf '%s\n' "$key_path"
}

cmd_archive() {
    local configuration unsigned=false
    configuration="$(configuration_arg "${1:-}")"
    shift
    case "${1:-}" in
        "") ;;
        --unsigned) unsigned=true ;;
        *) die "알 수 없는 옵션: $1" ;;
    esac

    local args=(
        archive
        -workspace "$(app_name).xcworkspace"
        -scheme "$(scheme_for "$configuration")"
        -configuration "$configuration"
        -destination 'generic/platform=iOS'
        -archivePath "$(archive_path_for "$configuration")"
    )
    # 명령줄 빌드 설정은 모든 타깃에 적용되므로 앱과 익스텐션의 번들 버전이 같아진다.
    if [[ -n "${BUILD_NUMBER:-}" ]]; then
        args+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")
    elif [[ "$unsigned" == false ]]; then
        die "서명 아카이브에는 BUILD_NUMBER 가 필요합니다."
    fi

    if [[ "$unsigned" == true ]]; then
        args+=(CODE_SIGNING_ALLOWED=NO)
    else
        local flags
        flags="$(auth_flags)"
        while IFS= read -r flag; do args+=("$flag"); done <<<"$flags"
    fi

    run_xcodebuild "${args[@]}"
}

cmd_upload() {
    local configuration
    configuration="$(configuration_arg "${1:-}")"

    local team
    team="$(team_id)"
    [[ -n "$team" ]] || die "TEAM_ID 가 없고 $signing 의 DEVELOPMENT_TEAM 도 비어 있습니다."

    # Staging 은 QA 전용이라 내부 테스트로만 올린다. Release 는 같은 빌드를 심사에 제출할 수 있어야 한다.
    local internal_only=false
    [[ "$configuration" == "Staging" ]] && internal_only=true

    local work plist
    work="$(mktemp -d "$tmp_dir/export.XXXXXX")"
    plist="$work/ExportOptions.plist"
    local buddy=/usr/libexec/PlistBuddy
    "$buddy" -c "Add :method string app-store-connect" "$plist" >/dev/null
    "$buddy" -c "Add :destination string upload" "$plist"
    "$buddy" -c "Add :teamID string $team" "$plist"
    "$buddy" -c "Add :signingStyle string automatic" "$plist"
    # 빌드 번호는 BUILD_NUMBER 로 정한다. Xcode 가 바꾸면 태그와 어긋난다.
    "$buddy" -c "Add :manageAppVersionAndBuildNumber bool false" "$plist"
    "$buddy" -c "Add :uploadSymbols bool true" "$plist"
    "$buddy" -c "Add :testFlightInternalTestingOnly bool $internal_only" "$plist"

    local args=(
        -exportArchive
        -archivePath "$(archive_path_for "$configuration")"
        -exportOptionsPlist "$plist"
        -exportPath "$work/export"
    )
    local flags
    flags="$(auth_flags)"
    while IFS= read -r flag; do args+=("$flag"); done <<<"$flags"

    run_xcodebuild "${args[@]}"
}

cmd_version() {
    local configuration version
    configuration="$(configuration_arg "${1:-}")"
    version="$(xcconfig_value "Configurations/$configuration.xcconfig" MARKETING_VERSION)"
    [[ -n "$version" ]] || die "Configurations/$configuration.xcconfig 에서 MARKETING_VERSION 을 읽지 못했습니다."
    printf '%s\n' "$version"
}

case "${1:-}" in
    preflight) cmd_preflight ;;
    write-secrets) cmd_write_secrets ;;
    archive) shift; cmd_archive "$@" ;;
    upload) shift; cmd_upload "$@" ;;
    version) shift; cmd_version "$@" ;;
    *) die "사용법: $0 {preflight|write-secrets|archive <Release|Staging> [--unsigned]|upload <Release|Staging>|version <Release|Staging>}" ;;
esac
