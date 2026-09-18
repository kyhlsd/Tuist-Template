# iOS Claude Code 4단계 스캐폴드

조사 → 계획 → 구현 → 검토를 Claude Code의 각 레이어(skill / subagent / hook / rules / LSP / MCP)에
배치한 프로젝트 설정입니다. 어떤 iOS 프로젝트에도 그대로 얹을 수 있습니다.

> **이 저장소에는 이미 적용되어 있습니다.** 아래 "설치"는 다른 프로젝트에 얹을 때의 절차입니다.
> 이 저장소를 클론한 머신에서 할 일은 "다른 머신에서 쓰기"만 보면 됩니다.

---

## 설치

### 1. 네 개를 프로젝트 루트에 붙여넣기

압축을 풀면 나오는 아래 네 개를 프로젝트 루트(`.xcodeproj`가 있는 폴더)에 그대로 넣습니다.
폴더째로 넣으면 동작하지 않습니다. 이 네 개가 루트에 있어야 합니다.

| 넣을 것 | 무엇인가 |
| --- | --- |
| `CLAUDE.md` | 매 요청 로드되는 프로젝트 컨텍스트 |
| `.claude/` | 스킬·에이전트·훅·규칙 전부 (폴더째) |
| `.swiftlint.yml` | 훅이 참조하는 린트 규칙 |
| `.mcp.json` | XcodeBuildMCP 설정 |

넣은 뒤 루트는 이렇게 됩니다.

```
YourApp/
├── YourApp.xcodeproj
├── CLAUDE.md          ←
├── .swiftlint.yml     ←
├── .mcp.json          ←
└── .claude/           ←
```

**Finder로 옮긴다면** `.`으로 시작하는 세 개는 기본적으로 숨겨져 있습니다.
`Cmd + Shift + .`로 숨김 파일을 표시한 뒤 옮기세요.

**터미널이라면** 압축 푼 폴더 안에서:

```bash
cp -R . /path/to/YourApp/     # 현재 폴더의 내용물을 프로젝트 루트로
```

**이미 `CLAUDE.md`나 `.swiftlint.yml`이 있다면** 덮어쓰지 말고 내용을 병합하세요.

### 2. 실행 권한 확인

```bash
cd /path/to/YourApp
chmod +x .claude/hooks/*.sh .claude/scripts/*.sh
```

Finder로 복사했거나 압축을 푸는 과정에서 권한이 빠지면 훅이 조용히 실패합니다.
`.claude/`를 커밋해두면 이후에는 git이 실행 권한을 보존합니다.

### 3. 채워 넣기

1. `CLAUDE.md`의 `<앱 이름>`, `<최소 지원 버전>`, `<아키텍처>`
2. `.claude/scripts/xcbuild.sh` 상단의 `SCHEME` (Tuist 프로젝트라면 모든 테스트가 들어 있는 `<앱 이름>-Workspace`)
3. `.claude/gitignore.example`의 항목을 프로젝트 `.gitignore`에 추가

### 4. 도구 설치

```bash
brew install swiftformat swiftlint jq xcbeautify
xcode-select --install   # sourcekit-lsp 포함
```

`mise.toml` 로 도구 버전을 고정한 프로젝트라면 swiftformat·swiftlint 는 `mise install` 로 받습니다.
버전이 다르면 같은 코드도 포맷·린트 결과가 달라지므로, 세션 시작 훅이 PATH 의 버전과
`mise.toml` 의 고정 버전을 비교해 다르면 알려줍니다.

1~4를 빠뜨려도 괜찮습니다. 첫 세션에서 훅이 무엇이 빠졌는지 알려줍니다.
경고 없이 조용히 시작하면 설정이 완료된 것입니다.

### 기존 프로젝트에 얹는다면 먼저 한 번 포맷하세요

```bash
swiftformat .
git commit -am "chore: apply swiftformat baseline"
```

훅이 `swiftformat --lint`로 검사하므로, 포맷이 적용된 적 없는 코드베이스에서는 **파일을 건드릴
때마다 포맷 위반이 잡힙니다.** Claude가 그 파일에 `swiftformat`을 돌리면 실제 변경과 무관한
대량의 재포맷 diff가 섞입니다. 베이스라인을 먼저 잡고 커밋해두면 이후 diff가 깨끗합니다.

### LSP 연결

```
/plugin marketplace add anthropics/claude-plugins-official
/plugin install swift-lsp@claude-plugins-official
```

커스터마이즈가 필요하면 동봉된 로컬 플러그인을 씁니다.
`.lsp.json`은 플러그인 폴더 안에서만 읽히므로 저장소 루트에 두면 동작하지 않습니다.

```bash
claude --plugin-dir .claude/lsp-swift
```

LSP 서버는 워크스페이스를 신뢰한 뒤 기동합니다. 첫 세션의 신뢰 다이얼로그를 수락하세요.

### Xcode 프로젝트라면 build server가 추가로 필요합니다

sourcekit-lsp는 각 파일의 컴파일 플래그를 알아야 타입을 해석합니다.
Swift Package(`Package.swift`)는 네이티브로 이해하지만, `.xcodeproj` / `.xcworkspace`는
**별도 build server가 `buildServer.json`을 만들어주지 않으면 동작하지 않습니다.**

```bash
brew install xcode-build-server
xcode-build-server config -project MyApp.xcodeproj -scheme MyApp
# 워크스페이스라면: -workspace MyApp.xcworkspace
# 이 저장소(Tuist):  xcode-build-server config -workspace TuistApp.xcworkspace -scheme TuistApp-Workspace
```

세션 시작 훅이 `xcbuild.sh` 의 `SCHEME` 과 루트의 워크스페이스를 읽어 이 명령을 그대로 만들어 보여줍니다.

`buildServer.json`은 저장소 루트(= LSP 루트)에 있어야 합니다. 로컬 빌드 경로가 들어가므로
커밋하지 않습니다(`.claude/gitignore.example`에 포함돼 있습니다).

sourcekit-lsp는 indexing-while-building 방식이라 **한 번도 빌드하지 않았으면 인덱스가 없습니다.**
정의 이동이나 참조 찾기가 이상하면 `./.claude/scripts/xcbuild.sh build`를 한 번 돌리세요.
세션 시작 훅이 `buildServer.json` 누락을 감지해 알려줍니다.

### 버전 관리

`.claude/`는 커밋해서 팀과 공유하고, `.claude/settings.local.json`은 `.gitignore`에 넣습니다.
훅 스크립트의 실행 권한도 git이 보존하므로, 커밋한 뒤에는 클론만 해도 그대로 돕니다.

### 요구 버전

Claude Code v2.1.218 이상을 권장합니다. 포크 스킬의 `background` 필드가 그 버전부터
동작합니다. 더 낮은 버전에서는 포크 스킬이 항상 턴을 막고 끝날 때까지 기다리므로
결과는 나오지만 병렬 실행은 되지 않습니다.

---

## 다른 머신에서 쓰기

설정은 전부 프로젝트 스코프라 저장소를 클론하면 그대로 따라옵니다.
머신마다 따로 해야 하는 것은 세 가지입니다.

그 전에 Tuist 프로젝트라면 워크스페이스부터 만듭니다. `.xcworkspace` 는 생성물이라 클론에는 없고,
없으면 빌드·LSP 가 모두 동작하지 않습니다. 세션 시작 훅이 이 상태도 감지합니다.

```bash
mise install && tuist install && tuist generate
```

**1. CLI 도구 설치** — `swiftformat`, `swiftlint`, `jq`, `xcbeautify`, Xcode.
이게 빠지면 편집 검사 훅이 조용히 통과합니다. 가드레일이 없는데 있는 것처럼
보이는 상태라 가장 위험한데, `SessionStart` 훅이 세션 시작 시 확인해서
빠진 게 있으면 Claude와 사용자 양쪽에 알립니다. 전부 설치돼 있으면 아무것도 출력하지 않습니다.

**2. LSP 플러그인과 build server** — 마켓플레이스 플러그인은 사용자 스코프에 설치되므로 저장소를
따라오지 않습니다. 새 머신에서 `/plugin install swift-lsp@claude-plugins-official`을 다시 하거나,
저장소에 포함된 `claude --plugin-dir .claude/lsp-swift`를 쓰세요. 후자는 클론만 하면 됩니다.
`buildServer.json`도 로컬 경로를 담고 있어 머신마다 `xcode-build-server config`를 다시 돌려야 합니다.

**3. 신뢰와 승인** — 첫 실행에서 워크스페이스 신뢰 다이얼로그를 수락해야
프로젝트 레벨 훅과 LSP 서버가 기동합니다. `.mcp.json`의 XcodeBuildMCP도
머신마다 한 번 승인이 필요합니다.

그 외에 `npx`를 쓰려면 Node 18 이상이 필요합니다. 없다면
`brew install xcodebuildmcp` 후 `.mcp.json`을 `"command": "xcodebuildmcp", "args": ["mcp"]`로 바꾸세요.

빌드 스크립트는 시뮬레이터를 머신마다 스스로 골라 캐시하므로, 기기 이름을 커밋하지 않아도
머신을 옮겨 다닐 수 있습니다. 캐시 파일 `.claude/sim.local`은 gitignore 대상입니다.

---

## 사용법

```
/ios-platform-research 결제 재시도        ← 백그라운드로 돌기 시작
/ios-research 결제 실패 처리              ← 동시에 포그라운드 실행
/ios-plan 결제 재시도                     → docs/plans/2026-09-14-payment-retry.md
/clear
/ios-implement docs/plans/2026-09-14-payment-retry.md
/ios-review
```

| 순서 | 명령 | 하는 일 | 실행 | 세션 |
| --- | --- | --- | --- | --- |
| 1 | `/ios-platform-research <기능>` | Apple API·프레임워크 조사, 접근법 후보 | 포크·백그라운드 | A |
| 2 | `/ios-research <주제>` | 저장소 구조 조사, 변경 지점과 제약 | 포크·포그라운드 | A |
| 3 | `/ios-plan <작업>` | 두 조사 대조 → 계획 문서 생성 | 인라인 | A |
| 4 | `/ios-implement <계획 파일>` | 단계별 구현 | 인라인 | B |
| 5 | `/ios-review [base-ref]` | 변경분 검토 | 포크·포그라운드 | B |

1을 먼저 띄우면 백그라운드로 도는 동안 2를 돌릴 수 있습니다. 순서를 바꿔도 되지만
이 순서가 대기 시간이 가장 짧습니다.

3에서 계획 문서가 나오면 `/clear`로 세션을 끊고 4를 새 세션에서 시작합니다.
조사 단계에서 읽은 파일들이 구현 내내 컨텍스트를 차지하지 않습니다.

일부 단계만 쓰는 것도 정상입니다. 버그 수정처럼 플랫폼 판단이 필요 없으면 1을 건너뛰고,
한 줄 수정이면 3~4를 건너뛰고 바로 고쳐도 됩니다.

---

## 구성

```
CLAUDE.md                              매 요청 로드. 프로젝트 개요와 빌드 명령
.swiftlint.yml                         훅이 참조. error = 편집 차단
.mcp.json                              XcodeBuildMCP
.claude/
├── README.md                          이 문서
├── gitignore.example                  .gitignore에 추가할 항목
├── settings.json                      훅 등록, 권한 deny
├── lsp-swift/                         선택: 로컬 LSP 플러그인
├── scripts/xcbuild.sh                 빌드·테스트 진입점. 시뮬레이터 고정
├── rules/
│   ├── swift.md                       paths: **/*.swift
│   └── tests.md                       paths: **/*Tests.swift 등
├── agents/
│   ├── ios-researcher.md              저장소 구조. 읽기 전용, model: sonnet
│   ├── ios-platform-researcher.md     Apple API. 읽기 전용, model: inherit
│   └── ios-reviewer.md                변경분 검토. 읽기 전용, model: inherit
├── skills/
│   └── ios-{research,platform-research,plan,implement,review}/SKILL.md
└── hooks/
    ├── check-tools.sh                 SessionStart. 도구 누락 감지
    └── swift-quality.sh               PostToolUse. 검사 전용 (파일을 바꾸지 않음)
```

### 조사가 두 갈래인 이유

"이 저장소를 어디서 고치나"와 "iOS에서 이걸 어떻게 구현하는 게 맞나"는 다른 질문이고
쓰는 도구도 다릅니다. 전자는 LSP와 Grep, 후자는 WebSearch와 Apple 공식 문서입니다.
두 에이전트는 서로를 모른 채 돌고, 대조는 `/ios-plan`의 첫 단계에서 합니다.
두 결과가 어긋나는 지점(플랫폼은 A를 권하는데 코드베이스는 B로 되어 있다)을
덮지 않고 드러내는 것이 계획 문서의 핵심입니다.

### 포그라운드 / 백그라운드

백그라운드 서브에이전트는 축소된 내장 도구 세트로 돌고, 거기에 LSP가 빠집니다
(MCP 도구와 WebSearch/WebFetch는 유지됩니다). 그래서

- LSP가 필요한 `/ios-research`, `/ios-review` → `background: false`
- 웹 검색만 쓰는 `/ios-platform-research` → 백그라운드 기본값

인터랙티브 세션은 fork mode가 기본 on이라, Claude가 Agent 툴로 띄운 서브에이전트는
백그라운드로 갑니다. 포크 스킬로 두고 `background`를 직접 지정해야 포그라운드가 보장됩니다.

### 커스텀 에이전트

내장 `Explore`/`Plan`은 컨텍스트를 아끼려고 CLAUDE.md를 건너뜁니다.
프로젝트 규칙이 조사·검토에 반영돼야 하므로 커스텀 에이전트를 쓰고,
`disallowedTools: Write, Edit, NotebookEdit`으로 읽기 전용을 강제합니다.

### 빌드 진입점

빌드와 테스트는 `.claude/scripts/xcbuild.sh`를 통해서만 실행합니다.

```bash
./.claude/scripts/xcbuild.sh build
./.claude/scripts/xcbuild.sh test [-only-testing:...]
./.claude/scripts/xcbuild.sh destination   # 고정된 기기 확인
./.claude/scripts/xcbuild.sh reset         # 다시 고르기
```

시뮬레이터를 매번 고르는 일이 반복 비용입니다. `xcrun simctl list`를 돌리고 출력을 읽고
어떤 기기를 쓸지 판단하는 과정이 세션마다 반복되면 토큰도 쓰고 결과도 흔들립니다.
스크립트가 최신 iOS 런타임의 iPhone을 한 번 골라 `.claude/sim.local`에 UDID로 고정하고,
이후에는 그 기기가 존재하는 한 재사용합니다. 사라졌으면 알아서 다시 고릅니다.

destination이 고정되면 DerivedData 캐시도 재사용되어 빌드가 빨라집니다.
`IOS_SIM_UDID` 환경변수로 일회성 재정의도 가능합니다.

### 훅

`swift-quality.sh`는 `swiftformat --lint`와 `swiftlint lint`로 검사만 하고,
위반이 있으면 `exit 2`로 메시지를 Claude에게 돌려줍니다. 파일을 직접 고치지 않는 이유는,
훅이 재포맷하면 Claude 컨텍스트의 사본이 낡아져 다음 편집이 실패하기 때문입니다.
감지는 결정론적으로, 수정은 Claude가 하고 파일을 다시 읽게 합니다.

`check-tools.sh`는 세션 시작 시 필요한 CLI 도구가 있는지 확인합니다.
빠진 도구에 의존하는 검사는 조용히 통과하기 때문에, 그 사실 자체를 알리는 것이 목적입니다.
Tuist 워크스페이스 미생성, `mise.toml` 과 다른 도구 버전, `buildServer.json` 누락도 함께 봅니다.

`.swiftlint.yml`에 `included:`가 없는 것은 의도한 것입니다. 디렉터리 이름이 프로젝트와
안 맞으면 훅이 넘긴 파일이 대상에서 빠져 검사가 조용히 통과합니다.
전체를 대상으로 두고 `excluded:`만 씁니다.

`swift-quality.sh`는 SwiftLint 를 `--config` 없이 프로젝트 루트에서 실행합니다. `--config` 를 주면
하위 폴더의 중첩 `.swiftlint.yml`(예: 토큰 폴더에서만 `no_magic_numbers` 해제)이 무시되기 때문입니다.
경로를 직접 넘기면 `excluded:` 도 무시되므로 `--force-exclude` 를 함께 씁니다.
CI 에서 SwiftLint 를 돌릴 때도 같은 방식으로 실행해야 결과가 훅과 같습니다.

### 이름과 호출

스킬 호출명은 디렉터리 이름이 결정합니다. `ios-` 접두사는 번들 스킬과의 충돌을 피하기 위한
것으로, `/code-review`에 `/review` 별칭이 있어 프로젝트 스킬을 `review`로 두면 그쪽이 우선합니다.

모든 스킬에 `disable-model-invocation: true`가 걸려 있어 사용자만 호출할 수 있습니다.
순서가 있는 절차라 Claude가 중간을 건너뛰지 못하게 하고, 스킬 설명이 매 요청
컨텍스트에 실리지 않는 효과도 있습니다.

---

## 토큰 설계

| 비용 지점 | 언제 | 대응 |
| --- | --- | --- |
| CLAUDE.md | 매 요청 | 45줄 이내. 코딩 규약은 `rules/`로 분리 |
| `.claude/rules/*` | 매칭 파일 작업 시에만 | `paths:` frontmatter |
| 스킬 설명 목록 | 매 요청 | `disable-model-invocation: true` |
| 서브에이전트 설명 | 매 요청 | 두 줄 이내 (한도 15,000토큰) |
| 인라인 스킬 본문 | 호출 후 세션 내내 | 본문을 짧게 + 세션 A/B 분리 |
| MCP 도구 스키마 | 사용 시 | tool search + `XCODEBUILDMCP_DYNAMIC_TOOLS` |
| 빌드/테스트 로그 | 구현 중 매번 | MCP 빌드 도구 우선, raw는 `xcbeautify --quiet` |
| 웹 검색 결과 | 플랫폼 조사 중 | 격리된 포크 안에서만 |
| 서브에이전트 보고서 | 단계당 1회 | 코드 500단어 / 플랫폼 600단어 제한 |
| 파일 통독 | 구현 내내 | LSP 심볼 조회로 대체 |
| 시뮬레이터 선택 | 빌드할 때마다 | `xcbuild.sh`가 한 번 고르고 `.claude/sim.local`에 고정 |

계획 문서가 세션 A→B의 인계 수단입니다. 그래서 문서에 `## 전제` 섹션이 있고,
구현에 필요한 사실(변경 지점, 쓰기로 한 API와 도입 버전, 권한 키, 함정)이
대화가 아니라 문서에 적혀 있어야 합니다.

---

## 조정 포인트

**모델** — `ios-researcher`만 `sonnet`입니다. 저장소를 읽고 요약하는 일이라
세션 모델까지 쓸 필요가 없습니다. `ios-platform-researcher`는 `inherit`인데,
API 이름이 틀리면 구현 단계에서 몇 배로 비싸지기 때문입니다.

**effort** — `ios-plan`과 `ios-review`에 `high`. 계획을 더 깊게 하려면
`ios-plan` 본문에 `ultrathink`를 넣거나 `effort: max`로 올립니다.

**린트 강도** — `.swiftlint.yml`의 `severity`로 조절합니다. 훅은 `error`만 차단하므로
막고 싶은 규칙을 `error`로 올리면 되고, 훅 자체는 건드릴 필요가 없습니다.

**MCP 범위** — 특정 단계에만 주려면 `.mcp.json`에서 빼고 해당 에이전트 frontmatter의
`mcpServers:`에 인라인 정의합니다. 메인 대화에는 도구가 로드되지 않습니다.

**에이전트 메모리** — `ios-reviewer`에 `memory: project`를 주면 반복되는 지적 패턴이
`.claude/agent-memory/`에 쌓입니다. 다만 메모리를 켜면 Read/Write/Edit가 자동 활성화되어
`disallowedTools`와 충돌할 수 있으므로, 읽기 전용을 유지하려면 `PreToolUse` 훅으로
agent-memory 밖 쓰기를 막는 방식으로 바꾸세요.

**대규모 작업** — 코드베이스 전체 감사나 대규모 마이그레이션은 `/ios-review` 대신
dynamic workflow를 씁니다. 오케스트레이션이 스크립트로 내려가 중간 결과가 쌓이지 않습니다.

---

## 한계

- `permissions.deny`는 명령 앞부분 매칭입니다. `cd x && git push`처럼 앞에 뭔가 붙으면
  걸리지 않습니다. 실수 방지용이지 샌드박스가 아닙니다.
- `.mcp.json`은 `xcodebuildmcp@<버전>`으로 버전을 고정해 둡니다. `@latest`로 두면 세션마다 npx가
  최신을 확인해 기동이 느려지고, 팀원마다 다른 버전을 쓰게 됩니다. 올릴 때는 버전만 바꿉니다.
  npx 없이 쓰려면 `brew install xcodebuildmcp` 후 `"command": "xcodebuildmcp", "args": ["mcp"]`로 바꾸세요.
- XcodeBuildMCP가 `CONNECTION_CLOSED`로 붙지 않으면 `~/.npm`에 root 소유 파일이 없는지 먼저 봅니다
  (예전에 `sudo npm`을 쓴 흔적). 해결 방법은 저장소 루트 README의 "문제 해결"에 있습니다.
- 훅은 SwiftLint `error`만 차단합니다. `warning`은 통과합니다.
- 훅이 exit 0으로 끝나면서 stderr에 쓴 내용은 디버그 로그에만 남고 Claude는 보지 못합니다.
  Claude에게 전달하려면 exit 2여야 합니다. 훅을 직접 추가할 때 가장 흔히 놓치는 지점입니다.
- `PostToolUse` 훅은 편집을 되돌리지 못합니다. 파일은 이미 써진 뒤이고, 훅이 할 수 있는 일은
  `exit 2`로 "다음 행동은 이걸 고치는 것"이라는 지시를 Claude에게 주입하는 것입니다.
  진짜 차단이 필요하면 `PreToolUse` 훅을 추가해야 합니다.

---

## 점검

```bash
claude plugin validate .claude/skills
claude plugin validate .claude/agents
```

세션 안에서:

| 명령 | 확인하는 것 |
| --- | --- |
| `/skills` | 다섯 개 스킬이 보이는지 |
| `/context` | 무엇이 컨텍스트를 얼마나 차지하는지 |
| `/doctor` | CLAUDE.md가 비대해졌는지 |
| `/skill-doctor` | 안 쓰는 스킬의 컨텍스트 비용 |
| `/tasks` | 서브에이전트의 모델·effort, 포그라운드 여부 |

새 머신이라면 세션을 열었을 때 도구 누락 경고가 뜨지 않는지부터 보세요.
경고가 없으면 가드레일이 전부 살아 있다는 뜻입니다.
