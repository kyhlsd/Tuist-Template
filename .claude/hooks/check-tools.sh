#!/usr/bin/env bash
# SessionStart 훅 — 이 프로젝트의 가드레일이 실제로 작동하는지 확인합니다.
# 모두 정상이면 아무것도 출력하지 않습니다(컨텍스트 비용 0).
# 빠진 게 있으면 그 사실을 Claude와 사용자 모두에게 알립니다.
set -uo pipefail

missing=""
add() { missing="${missing:+$missing
}$1"; }

command -v jq          >/dev/null 2>&1 || add "- jq 없음 → 편집 검사 훅이 **전혀 동작하지 않습니다**. \`brew install jq\`"
command -v swiftlint   >/dev/null 2>&1 || add "- swiftlint 없음 → 강제 언래핑·하드코딩 차단이 **동작하지 않습니다**. \`brew install swiftlint\`"
command -v swiftformat >/dev/null 2>&1 || add "- swiftformat 없음 → 포맷 검사가 동작하지 않습니다. \`brew install swiftformat\`"
command -v xcbeautify  >/dev/null 2>&1 || add "- xcbeautify 없음 → 빌드 로그가 그대로 컨텍스트에 쌓입니다. \`brew install xcbeautify\`"
command -v xcodebuild  >/dev/null 2>&1 || add "- xcodebuild 없음 → Xcode 또는 Command Line Tools를 설치하세요."
command -v sourcekit-lsp >/dev/null 2>&1 || add "- sourcekit-lsp 없음 → \`xcode-select --install\`"

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
xcb="$root/.claude/scripts/xcbuild.sh"

# Tuist 프로젝트는 .xcworkspace/.xcodeproj 가 생성물이라 클론 직후에는 없습니다.
if [ -f "$root/Workspace.swift" ] || [ -f "$root/Project.swift" ]; then
  if ! ls "$root"/*.xcworkspace >/dev/null 2>&1; then
    add "- Xcode 워크스페이스가 아직 생성되지 않았습니다 → 빌드·LSP 모두 동작하지 않습니다. \`mise install && tuist install && tuist generate\`"
  fi
fi

# 도구 버전이 mise.toml 의 고정 버전과 다르면 포맷·린트 결과가 팀원마다 달라집니다.
# 훅은 PATH 의 swiftformat/swiftlint 를 그대로 쓰므로(brew 설치본일 수 있음) 여기서 확인합니다.
pinned() { sed -nE "s/^$1[[:space:]]*=[[:space:]]*\"([^\"]+)\".*/\1/p" "$root/mise.toml" 2>/dev/null | head -1; }
if [ -f "$root/mise.toml" ]; then
  want=$(pinned swiftformat)
  have=$(swiftformat --version 2>/dev/null)
  if [ -n "$want" ] && [ -n "$have" ] && [ "$want" != "$have" ]; then
    add "- swiftformat $have 이 PATH 에 있지만 mise.toml 은 $want 입니다 → 포맷 결과가 달라질 수 있습니다. \`mise install\` 후 mise 를 셸에 활성화하세요."
  fi
  want=$(pinned swiftlint)
  have=$(swiftlint version 2>/dev/null)
  if [ -n "$want" ] && [ -n "$have" ] && [ "$want" != "$have" ]; then
    add "- swiftlint $have 이 PATH 에 있지만 mise.toml 은 $want 입니다 → 린트 결과가 달라질 수 있습니다. \`mise install\` 후 mise 를 셸에 활성화하세요."
  fi
fi

# sourcekit-lsp는 .xcodeproj/.xcworkspace의 컴파일 플래그를 스스로 알지 못합니다.
# buildServer.json이 없으면 LSP가 붙어도 심볼 조회가 동작하지 않습니다.
has_xcode_project=""
for candidate in "$root"/*.xcodeproj "$root"/*.xcworkspace; do
  [ -e "$candidate" ] && { has_xcode_project=1; break; }
done

if [ -n "$has_xcode_project" ] && [ ! -f "$root/buildServer.json" ]; then
  # xcbuild.sh 에 적힌 스킴과 워크스페이스로 실제 실행할 명령을 만들어 보여 줍니다.
  scheme=$(sed -nE 's/^SCHEME="([^"]*)".*/\1/p' "$xcb" 2>/dev/null | head -1)
  [ -n "$scheme" ] && [ "$scheme" != "<Scheme>" ] || scheme="<Scheme>"
  workspace=$(cd "$root" && ls -d *.xcworkspace 2>/dev/null | head -1)
  if [ -n "$workspace" ]; then
    config_cmd="xcode-build-server config -workspace $workspace -scheme $scheme"
  else
    config_cmd="xcode-build-server config -project $(cd "$root" && ls -d *.xcodeproj | head -1) -scheme $scheme"
  fi
  if command -v xcode-build-server >/dev/null 2>&1; then
    add "- buildServer.json 없음 → LSP 심볼 조회가 동작하지 않습니다. \`$config_cmd\` 실행"
  else
    add "- buildServer.json 없음 → LSP 심볼 조회가 동작하지 않습니다. \`brew install xcode-build-server\` 후 \`$config_cmd\`"
  fi
fi

if [ -f "$xcb" ] && grep -q 'SCHEME="<Scheme>"' "$xcb"; then
  add "- \`.claude/scripts/xcbuild.sh\`의 SCHEME이 비어 있습니다 → 빌드·테스트 명령이 동작하지 않습니다."
fi

# buildServer.json 이 "있다"는 것만으로는 부족합니다. 그 안의 build_root 는
# DerivedData 경로(프로젝트명-해시)인데, Tuist 가 워크스페이스를 다시 만들면 해시가 바뀝니다.
# 그러면 파일은 그대로 있고 가리키는 곳만 낡아, LSP 가 붙은 채로 심볼 조회만 조용히 실패합니다.
# (정의 이동·참조 찾기가 빈손으로 돌아오고, import 가 "No such module" 로 뜹니다.)
if [ -f "$root/buildServer.json" ] && command -v jq >/dev/null 2>&1; then
  bs_root=$(jq -r '.build_root // empty' "$root/buildServer.json" 2>/dev/null)
  if [ -n "$bs_root" ]; then
    if [ ! -d "$bs_root" ]; then
      add "- buildServer.json 이 가리키는 DerivedData 가 없습니다 → LSP 심볼 조회가 조용히 실패합니다. \`xcode-build-server config\` 를 다시 실행하세요."
    else
      # 같은 프로젝트의 DerivedData 가 여럿이고 그중 최신이 아니면 해시가 바뀐 것이다.
      prefix=${bs_root%-*}
      newest=$(ls -dt "$prefix"-* 2>/dev/null | head -1)
      if [ -n "$newest" ] && [ "$newest" != "$bs_root" ]; then
        add "- buildServer.json 이 오래된 DerivedData 를 가리킵니다(최신: $(basename "$newest")) → LSP 심볼 조회가 조용히 실패합니다. \`xcode-build-server config\` 를 다시 실행하세요."
      fi
    fi
  fi
fi

[ -n "$missing" ] || exit 0

cat <<MSG
프로젝트 설정 미완료: 이 머신에 빠진 도구가 있습니다.

$missing

빠진 도구에 의존하는 검사는 조용히 통과합니다. 위 항목을 설치하기 전까지는
품질 가드레일이 없다고 간주하고, 사용자에게 이 사실을 한 번 알리세요.
MSG
exit 0
