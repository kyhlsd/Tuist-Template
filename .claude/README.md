# iOS Claude Code 스캐폴드

조사 → 계획 → 구현 → 검토를 Claude Code의 각 레이어(skill / subagent / hook / rules / LSP)에
배치한 프로젝트 설정입니다. 어떤 iOS 프로젝트에도 그대로 얹을 수 있습니다.

| | |
| --- | --- |
| **5단계 흐름** | 조사 두 갈래 → 계획 문서 → 구현 → 검토. 각 단계가 슬래시 명령 하나 |
| **격리된 조사** | 조사·검토는 포크에서 돌고 요약만 돌아옵니다. 읽은 파일이 본 대화에 쌓이지 않습니다 |
| **결정론적 가드레일** | 포맷·린트 위반과 기본 브랜치 커밋은 훅이 막습니다. 모델의 판단에 맡기지 않습니다 |
| **고정된 빌드 진입점** | 시뮬레이터를 한 번 골라 캐시합니다. 로그는 한 줄로 줄입니다 |
| **LSP 내장** | SourceKit-LSP 플러그인이 동봉돼 있어 클론만 하면 심볼 조회가 됩니다 |
| **컨텍스트 예산 관리** | 매 요청 실리는 것을 최소로 유지합니다 (아래 "컨텍스트 설계") |

> 이 저장소에는 이미 적용돼 있습니다. 클론한 머신에서 할 일은 "머신마다 해야 할 것"에만
> 있고, "설치"는 다른 프로젝트에 얹을 때의 절차입니다.

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

**3에서 계획 문서가 나오면 `/clear`로 세션을 끊고 4를 새 세션에서 시작합니다.**
계획 문서가 세션 A→B의 인계 수단입니다. 그래서 문서에 `## 전제` 섹션이 있고,
구현에 필요한 사실(변경 지점, 쓰기로 한 API와 도입 버전, 권한 키, 함정)이
대화가 아니라 문서에 적혀 있어야 합니다. 조사 단계에서 읽은 파일들이 구현 내내
컨텍스트를 차지하지 않습니다.

일부 단계만 쓰는 것도 정상입니다. 버그 수정처럼 플랫폼 판단이 필요 없으면 1을 건너뛰고,
한 줄 수정이면 3~4를 건너뛰고 바로 고쳐도 됩니다.

### 조사가 두 갈래인 이유

"이 저장소를 어디서 고치나"와 "iOS에서 이걸 어떻게 구현하는 게 맞나"는 다른 질문이고
쓰는 도구도 다릅니다. 전자는 LSP와 Grep, 후자는 WebSearch와 Apple 공식 문서입니다.
두 에이전트는 서로를 모른 채 돌고, 대조는 `/ios-plan`의 첫 단계에서 합니다.
두 결과가 어긋나는 지점(플랫폼은 A를 권하는데 코드베이스는 B로 되어 있다)을
덮지 않고 드러내는 것이 계획 문서의 핵심입니다.

### 스킬 호출

모든 스킬에 `disable-model-invocation: true`가 걸려 있어 **사용자만 호출할 수 있습니다.**
순서가 있는 절차라 Claude가 중간을 건너뛰지 못하게 하고, 스킬 설명이 매 요청
컨텍스트에 실리지 않는 효과도 있습니다.

호출명은 디렉터리 이름이 결정합니다. `ios-` 접두사는 번들 스킬과의 충돌을 피하기 위한
것으로, `/code-review`에 `/review` 별칭이 있어 프로젝트 스킬을 `review`로 두면 그쪽이 우선합니다.

---

## 구성

```
CLAUDE.md                              매 요청 로드. 프로젝트 개요와 빌드 명령
.swiftlint.yml                         훅이 참조. error = 편집 차단
.claude/
├── README.md                          이 문서
├── gitignore.example                  .gitignore에 추가할 항목
├── settings.json                      훅 등록, 권한 deny
├── scripts/xcbuild.sh                 빌드·테스트 진입점. 시뮬레이터 고정
├── rules/
│   ├── swift.md                       paths: **/*.swift
│   └── tests.md                       paths: **/*Tests.swift, Testing/Sources 등
├── agents/
│   ├── ios-researcher.md              저장소 구조. 읽기 전용, model: sonnet
│   ├── ios-platform-researcher.md     Apple API. 읽기 전용, model: inherit
│   └── ios-reviewer.md                변경분 검토. 읽기 전용, model: inherit
├── skills/
│   ├── ios-{research,platform-research,plan,implement,review}/SKILL.md
│   └── lsp-swift/                     로컬 LSP 플러그인. skills-dir 규칙으로 자동 로드
└── hooks/
    ├── check-tools.sh                 SessionStart. 도구·설정 누락 감지
    ├── guard-git.sh                   PreToolUse(Bash). 기본 브랜치 직접 커밋 차단
    └── swift-quality.sh               PostToolUse. 검사 전용 (파일을 바꾸지 않음)
```

### 커스텀 에이전트

내장 `Explore`/`Plan`은 컨텍스트를 아끼려고 CLAUDE.md를 건너뜁니다.
프로젝트 규칙이 조사·검토에 반영돼야 하므로 커스텀 에이전트를 쓰고,
`disallowedTools: Write, Edit, NotebookEdit`으로 읽기 전용을 강제합니다.

### 포그라운드 / 백그라운드

백그라운드 서브에이전트는 축소된 내장 도구 세트로 돌고, 거기에 LSP가 빠집니다
(WebSearch/WebFetch는 유지됩니다). 그래서

- LSP가 필요한 `/ios-research`, `/ios-review` → `background: false`
- 웹 검색만 쓰는 `/ios-platform-research` → 백그라운드 기본값

인터랙티브 세션은 fork mode가 기본 on이라, Claude가 Agent 툴로 띄운 서브에이전트는
백그라운드로 갑니다. 포크 스킬로 두고 `background`를 직접 지정해야 포그라운드가 보장됩니다.

---

## 가드레일

문서로 적어둔 규칙은 지켜질 때도 있고 아닐 때도 있습니다. 여기서는 지켜야 하는 것을
전부 기계가 검사합니다.

| 무엇 | 어떻게 | 언제 |
| --- | --- | --- |
| 포맷 위반 | `swiftformat --lint` | `.swift` 편집 직후 |
| 강제 언래핑, `as!`, `try!`, IUO | SwiftLint `error` | 〃 |
| 하드코딩된 URL·시크릿, `print` | 커스텀 규칙 `error` | 〃 |
| `@unchecked Sendable` | 커스텀 규칙 `error` | 〃 |
| 파일 단위 `swiftlint:disable` | 커스텀 규칙 `error` (`:next`만 허용) | 〃 |
| 기본 브랜치 직접 커밋 | `guard-git.sh` | `git commit` 실행 직전 |
| 도구·설정 누락 | `check-tools.sh` | 세션 시작 |

**`swift-quality.sh`(PostToolUse)는 검사만 하고 파일을 바꾸지 않습니다.** 훅이 재포맷하면
Claude 컨텍스트의 사본이 낡아져 다음 편집이 실패하기 때문입니다. 위반이 있으면 `exit 2`로
메시지를 돌려주고, 수정은 Claude가 한 뒤 파일을 다시 읽습니다.

**`guard-git.sh`(PreToolUse)는 실제로 명령을 막습니다.** 기본 브랜치에서 `git commit`을
시도하면 차단하고 브랜치를 만들라고 돌려줍니다. 실제 `git symbolic-ref` 결과를 읽으므로
`git -C . commit` 같은 변형도 걸립니다. 기본 브랜치 이름은 `origin/HEAD`에서 가져오고,
없으면 `main`/`master`로 봅니다.

**`check-tools.sh`(SessionStart)는 정상이면 아무것도 출력하지 않습니다.** 빠진 도구에
의존하는 검사는 조용히 통과하기 때문에, 그 사실 자체를 알리는 것이 목적입니다.
CLI 도구 누락, Tuist 워크스페이스 미생성, `mise.toml`과 다른 도구 버전,
`buildServer.json` 누락·낡음을 함께 봅니다.

### SwiftLint 설정

- `included:`를 두지 않습니다. 디렉터리 이름이 프로젝트와 안 맞으면 훅이 넘긴 파일이
  대상에서 빠져 검사가 조용히 통과합니다. 전체를 대상으로 두고 `excluded:`만 씁니다.
- 훅은 `--config` 없이 프로젝트 루트에서 실행합니다. `--config`를 주면 하위 폴더의
  중첩 `.swiftlint.yml`(예: 토큰 폴더에서만 `no_magic_numbers` 해제)이 무시됩니다.
  경로를 직접 넘기면 `excluded:`도 무시되므로 `--force-exclude`를 함께 씁니다.
  **CI에서도 같은 방식으로 실행해야 결과가 훅과 같습니다.**
- 훅은 `error`만 차단합니다. `warning`은 통과합니다.

---

## 빌드 진입점

빌드와 테스트는 `.claude/scripts/xcbuild.sh`를 통해서만 실행합니다.

```bash
./.claude/scripts/xcbuild.sh build
./.claude/scripts/xcbuild.sh test [-only-testing:Target/TestClass]
./.claude/scripts/xcbuild.sh destination   # 고정된 기기 확인 (사람이 읽는 형식)
./.claude/scripts/xcbuild.sh udid          # UDID만 출력 (다른 도구에 그대로 전달)
./.claude/scripts/xcbuild.sh reset         # 다시 고르기
```

시뮬레이터를 매번 고르는 일이 반복 비용입니다. `xcrun simctl list`를 돌리고 출력을 읽고
기기를 판단하는 과정이 세션마다 반복되면 토큰도 쓰고 결과도 흔들립니다. 스크립트가
최신 iOS 런타임의 iPhone을 한 번 골라 `.claude/sim.local`에 UDID로 고정하고, 이후에는
그 기기가 존재하는 한 재사용합니다. 사라졌으면 알아서 다시 고릅니다.
`IOS_SIM_UDID` 환경변수로 일회성 재정의도 가능합니다.

destination이 고정되면 DerivedData 캐시도 재사용되어 빌드가 빨라집니다. 그래서 UDID가
필요한 다른 도구에도 `udid` 출력을 넘겨 같은 기기를 쓰게 해야 합니다.

---

## 컨텍스트 설계

| 비용 지점 | 언제 | 대응 |
| --- | --- | --- |
| CLAUDE.md | 매 요청 | 45줄 이내. 코딩 규약은 `rules/`로 분리 |
| `.claude/rules/*` | 매칭 파일 Read 시에만 | `paths:` frontmatter |
| 스킬 설명 목록 | 매 요청 | `disable-model-invocation: true` → 목록에서 빠짐 |
| 서브에이전트 설명 | 매 요청 | 두 줄 이내 (한도 15,000토큰) |
| MCP 서버 지침·도구 | 매 세션 | 서버를 두지 않음 (아래) |
| 세션 시작 훅 출력 | 매 세션 | 정상이면 무출력 |
| 인라인 스킬 본문 | 호출 후 세션 내내 | 본문을 짧게 + 세션 A/B 분리 |
| 빌드/테스트 로그 | 구현 중 매번 | `xcbeautify --quiet --disable-logging --disable-colored-output` |
| 웹 검색 결과 | 플랫폼 조사 중 | 격리된 포크 안에서만 |
| 서브에이전트 보고서 | 단계당 1회 | 산문 단어 수 대신 **항목 수**로 제한 |
| 파일 통독 | 구현 내내 | LSP 심볼 조회로 대체 |
| 시뮬레이터 선택 | 빌드할 때마다 | `sim.local`에 UDID 고정 |
| 린트 규약 재확인 | 검토 단계 | `/ios-review`가 `swiftlint`를 직접 실행 |

`.claude/README.md`와 `.swiftlint.yml`은 합쳐 33KB지만 **컨텍스트에 들어가지 않습니다.**
길게 써도 비용이 없는 자리이므로, 설명은 여기에 두고 CLAUDE.md는 짧게 유지합니다.

보고서 분량을 "500단어 이내" 같은 산문 제한으로 걸면 표가 상한을 뚫습니다
(10행 표는 산문 500단어보다 깁니다). 항목 수로 거는 편이 실효가 있습니다.

### MCP 서버

기본값은 **서버 없음**입니다. MCP 서버를 `.mcp.json`에 두면 그 서버의 지침과 도구 목록이
매 세션 컨텍스트에 실립니다. 이 흐름은 빌드·테스트를 `xcbuild.sh`로만 하고, 시뮬레이터
UI 확인(스크린샷·탭)은 Claude 데스크톱 앱에 내장된 시뮬레이터 도구로 됩니다.

터미널 `claude`를 쓰거나 LLDB·커버리지·녹화가 필요하면 루트에 `.mcp.json`을 만듭니다.
버전은 고정하세요. `@latest`는 세션마다 npx가 최신을 확인해 기동이 느려지고
팀원마다 다른 버전을 쓰게 됩니다.

```json
{
  "mcpServers": {
    "XcodeBuildMCP": { "command": "npx", "args": ["-y", "xcodebuildmcp@2.7.0", "mcp"] }
  }
}
```

`npx`에는 Node 18 이상이 필요합니다. 없다면 `brew install xcodebuildmcp` 후
`"command": "xcodebuildmcp", "args": ["mcp"]`로 바꾸세요. 도구 스키마를 줄이려면
`settings.json`의 `env`에 `XCODEBUILDMCP_DYNAMIC_TOOLS: "true"`를 둡니다.

도구를 특정 단계에만 주고 싶으면 `.mcp.json` 대신 해당 에이전트 frontmatter의
`mcpServers:`에 인라인 정의합니다. 메인 대화에는 로드되지 않습니다.

---

## 설치 (다른 프로젝트에 얹기)

### 1. 세 개를 프로젝트 루트에 붙여넣기

| 넣을 것 | 무엇인가 |
| --- | --- |
| `CLAUDE.md` | 매 요청 로드되는 프로젝트 컨텍스트 |
| `.claude/` | 스킬·에이전트·훅·규칙·LSP 플러그인 전부 (폴더째) |
| `.swiftlint.yml` | 훅이 참조하는 린트 규칙 |

```
YourApp/
├── YourApp.xcodeproj
├── CLAUDE.md          ←
├── .swiftlint.yml     ←
└── .claude/           ←
```

폴더째로 감싸 넣으면 동작하지 않습니다. 이 셋이 루트에 있어야 합니다.
Finder로 옮긴다면 `Cmd + Shift + .`로 숨김 파일을 먼저 표시하세요.
이미 `CLAUDE.md`나 `.swiftlint.yml`이 있다면 덮어쓰지 말고 병합하세요.

### 2. 실행 권한 확인

```bash
chmod +x .claude/hooks/*.sh .claude/scripts/*.sh
```

Finder로 복사했거나 압축을 푸는 과정에서 권한이 빠지면 훅이 조용히 실패합니다.
`.claude/`를 커밋해두면 이후에는 git이 실행 권한을 보존합니다.

### 3. 채워 넣기

1. `CLAUDE.md`의 앱 이름, 최소 지원 버전, 아키텍처
2. `.claude/scripts/xcbuild.sh` 상단의 `SCHEME`과 `PROJECT_FLAGS`
   (Tuist라면 모든 테스트가 들어 있는 `<앱 이름>-Workspace`)
3. `.claude/gitignore.example`의 항목을 프로젝트 `.gitignore`에 추가

### 4. 도구 설치

아래 "머신마다 해야 할 것"과 같습니다. 팀원 각자가 한 번씩 합니다.

1~4를 빠뜨려도 괜찮습니다. 첫 세션에서 훅이 무엇이 빠졌는지 알려줍니다.
**경고 없이 조용히 시작하면 설정이 완료된 것입니다.**

### 5. 기존 프로젝트라면 포맷 베이스라인부터

```bash
swiftformat .
git commit -am "chore: apply swiftformat baseline"
```

훅이 `swiftformat --lint`로 검사하므로, 포맷이 적용된 적 없는 코드베이스에서는 파일을
건드릴 때마다 포맷 위반이 잡히고, 실제 변경과 무관한 대량의 재포맷 diff가 섞입니다.

### 요구 버전

Claude Code v2.1.218 이상을 권장합니다. 포크 스킬의 `background` 필드가 그 버전부터
동작합니다. 더 낮은 버전에서는 포크 스킬이 항상 턴을 막고 끝날 때까지 기다리므로
결과는 나오지만 병렬 실행은 되지 않습니다.

---

## 머신마다 해야 할 것

설정은 전부 프로젝트 스코프라 저장소를 클론하면 그대로 따라옵니다.
머신마다 따로 해야 하는 것은 세 가지입니다.

Tuist 프로젝트라면 워크스페이스부터 만듭니다. `.xcworkspace`는 생성물이라 클론에는 없고,
없으면 빌드·LSP가 모두 동작하지 않습니다. 세션 시작 훅이 이 상태도 감지합니다.

```bash
mise install && tuist install && tuist generate
```

**1. CLI 도구**

```bash
brew install swiftformat swiftlint jq xcbeautify xcode-build-server
xcode-select --install   # sourcekit-lsp 포함
```

`mise.toml`로 버전을 고정한 프로젝트라면 swiftformat·swiftlint는 `mise install`로 받습니다.
버전이 다르면 같은 코드도 포맷·린트 결과가 달라지므로, 세션 시작 훅이 PATH의 버전과
`mise.toml`의 고정 버전을 비교해 다르면 알려줍니다.

**2. build server** — `buildServer.json`은 로컬 빌드 경로를 담고 있어 머신마다 다시 만듭니다.
저장소 루트(= LSP 루트)에 있어야 하고, 커밋하지 않습니다.

```bash
xcode-build-server config -workspace TuistApp.xcworkspace -scheme TuistApp-Workspace
# .xcodeproj 뿐이라면: -project MyApp.xcodeproj -scheme MyApp
```

세션 시작 훅이 `xcbuild.sh`의 `SCHEME`과 루트의 워크스페이스를 읽어 이 명령을 만들어 줍니다.

**3. 신뢰 다이얼로그** — 첫 실행에서 워크스페이스를 신뢰해야 프로젝트 레벨 훅과
LSP 서버가 기동합니다.

빌드 스크립트는 시뮬레이터를 머신마다 스스로 골라 캐시하므로, 기기 이름을 커밋하지 않아도
머신을 옮겨 다닐 수 있습니다.

---

## LSP

`.claude/skills/lsp-swift/`의 로컬 플러그인이 **추가 설치 없이 자동으로 붙습니다.**
`.claude/skills/<이름>/`에 `.claude-plugin/plugin.json`이 있으면 Claude Code가 이를
`<이름>@skills-dir` 플러그인으로 읽습니다. 마켓플레이스도 `--plugin-dir`도 필요 없고,
클론한 모든 머신에서 그대로 동작합니다. (`.lsp.json`은 플러그인 폴더 안에서만 읽힙니다.)

플러그인을 새로 놓거나 고친 뒤에는 `/reload-plugins`면 충분합니다. 새 세션을 열 필요가
없고, `1 plugin LSP server`가 찍히면 붙은 것입니다.

공식 마켓플레이스 버전을 쓰려면 이쪽입니다(머신마다 한 번씩 설치해야 합니다).

```
/plugin marketplace add anthropics/claude-plugins-official
/plugin install swift-lsp@claude-plugins-official
```

sourcekit-lsp는 각 파일의 컴파일 플래그를 알아야 타입을 해석합니다. Swift Package는
네이티브로 이해하지만 `.xcodeproj` / `.xcworkspace`는 `buildServer.json`이 있어야 합니다
("머신마다 해야 할 것" 2번). 또 indexing-while-building 방식이라 **한 번도 빌드하지 않았으면
인덱스가 없습니다.**

### 붙었는지 확인하기

`sourcekit-lsp` 바이너리와 `buildServer.json`이 둘 다 있으면서 플러그인만 안 붙은 상태가
가능하고, 세션 시작 훅은 이걸 감지하지 못합니다(훅은 세션의 도구 목록을 볼 수 없습니다).
조사·구현 스킬은 LSP가 있다고 가정하고 씌어 있으므로, 안 붙은 채로 돌리면 파일 통독으로
조용히 대체되면서 토큰만 더 씁니다.

가장 확실한 확인은 Claude에게 직접 시키는 것입니다 — "이 심볼의 참조를 전부 찾아줘"라고 하고
LSP를 썼는지 grep으로 했는지 물어보세요.

---

## 문제 해결

**참조 찾기가 빈손으로 돌아오고 `import`가 `No such module`로 뜬다**
(hover와 documentSymbol은 되는데 참조 찾기만 안 되는 경우)

인덱스는 있고 컴파일 플래그만 없는 상태입니다. `xcode-build-server`는 빌드 로그에서
파일별 컴파일 인자를 캐내는데, 고칠 게 없어 즉시 끝난 증분 빌드의 로그에는 그게 없습니다.
클린 빌드로 채웁니다.

```bash
xcodebuild clean -scheme <스킴> -workspace <워크스페이스> \
  -destination "id=$(./.claude/scripts/xcbuild.sh udid)"
./.claude/scripts/xcbuild.sh build
```

**`tuist generate`를 다시 돌린 뒤 LSP가 이상하다**

DerivedData 경로에 워크스페이스 해시가 들어가서, 재생성하면 새 디렉터리가 만들어지고
`buildServer.json`은 옛날 것을 계속 가리킵니다. 파일은 멀쩡히 있으므로 "없음" 검사로는
못 잡습니다. 세션 시작 훅이 `build_root`가 실재하는지, 같은 프로젝트의 최신
DerivedData인지까지 확인해 낡았으면 알려줍니다. `xcode-build-server config`를 다시 돌리세요.

**훅이 아무 일도 안 하는 것 같다**

`chmod +x .claude/hooks/*.sh`를 확인하고, `jq`가 설치돼 있는지 보세요.
`jq`가 없으면 편집 검사 훅이 통째로 건너뜁니다(세션 시작 훅이 알려줍니다).

---

## 점검

```bash
claude plugin validate .claude/skills/lsp-swift
```

인자는 **플러그인 디렉터리**(`.claude-plugin/plugin.json`이 있는 폴더)입니다.
`.claude`는 플러그인이 아니므로 `.claude/skills`나 `.claude/agents`를 넘기면 동작하지 않습니다.
프로젝트의 스킬·에이전트는 아래 세션 명령으로 확인합니다.

| 명령 | 확인하는 것 |
| --- | --- |
| `/skills` | 다섯 개 스킬이 보이는지 |
| `/context` | 무엇이 컨텍스트를 얼마나 차지하는지. 커스텀 에이전트도 여기 뜹니다 |
| `/plugin` | Errors 탭이 비어 있는지 = LSP 서버가 기동했는지 |
| `/tasks` | 서브에이전트의 모델·effort, 포그라운드 여부 |
| `/doctor` | CLAUDE.md가 비대해졌는지 |
| `/skill-doctor` | 안 쓰는 스킬의 컨텍스트 비용 |

`/doctor`, `/skill-doctor`, `/permissions`, `/hooks`는 터미널 패널을 여는 명령이라
**데스크톱 앱(Code 탭) 세션에서는 쓸 수 없습니다.** 터미널에서 `claude`를 띄워 실행하세요.

새 머신이라면 세션을 열었을 때 도구 누락 경고가 뜨지 않는지부터 보세요.
경고가 없으면 가드레일이 전부 살아 있다는 뜻입니다.

---

## 조정 포인트

**모델** — `ios-researcher`만 `sonnet`입니다. 저장소를 읽고 요약하는 일이라
세션 모델까지 쓸 필요가 없습니다. `ios-platform-researcher`는 `inherit`인데,
API 이름이 틀리면 구현 단계에서 몇 배로 비싸지기 때문입니다.

**effort** — `ios-plan`과 `ios-review`에 `high`. 계획을 더 깊게 하려면
`ios-plan` 본문에 `ultrathink`를 넣거나 `effort: max`로 올립니다.

**린트 강도** — `.swiftlint.yml`의 `severity`로 조절합니다. 훅은 `error`만 차단하므로
막고 싶은 규칙을 `error`로 올리면 되고, 훅 자체는 건드릴 필요가 없습니다.

**에이전트 메모리** — `ios-reviewer`에 `memory: project`를 주면 반복되는 지적 패턴이
`.claude/agent-memory/`에 쌓입니다. 다만 메모리를 켜면 Read/Write/Edit가 자동 활성화되어
`disallowedTools`와 충돌할 수 있으므로, 읽기 전용을 유지하려면 `PreToolUse` 훅으로
agent-memory 밖 쓰기를 막는 방식으로 바꾸세요.

**대규모 작업** — 코드베이스 전체 감사나 대규모 마이그레이션은 `/ios-review` 대신
dynamic workflow를 씁니다. 오케스트레이션이 스크립트로 내려가 중간 결과가 쌓이지 않습니다.

---

## 알아둘 동작

- **`permissions.deny`는 실수 방지용이지 샌드박스가 아닙니다.** 서브셸·커맨드 치환·제어문
  본문까지 포함해 어떤 서브커맨드가 걸리든 적용되므로 `cd x && git push`는 막힙니다.
  뚫리는 쪽은 같은 일을 하는 다른 표기입니다 — `git -C . push`, `git 'push'`,
  `/usr/bin/git push`는 `Bash(git push *)`에 걸리지 않습니다.
  브랜치처럼 커맨드 문자열 밖의 조건이 필요하면 `PreToolUse` 훅을 써야 합니다.
- **경로 스코프 규칙(`rules/*.md`의 `paths:`)은 Read 시점에 걸립니다.** `git diff` 출력처럼
  Bash로 읽은 내용에는 붙지 않으므로, 검토 흐름에서는 규칙이 자동으로 들어오지 않습니다.
  그래서 `/ios-review`는 규칙을 눈으로 대조하는 대신 `swiftlint`를 직접 돌립니다.
- **`PostToolUse` 훅은 편집을 되돌리지 못합니다.** 파일은 이미 써진 뒤이고, 훅이 할 수 있는
  일은 `exit 2`로 "다음 행동은 이걸 고치는 것"이라는 지시를 주입하는 것입니다.
  진짜 차단이 필요하면 `PreToolUse` 훅을 써야 합니다.
- **훅을 직접 추가한다면**, exit 0으로 끝나면서 stderr에 쓴 내용은 디버그 로그에만 남고
  Claude는 보지 못합니다. 전달하려면 exit 2여야 합니다. 가장 흔히 놓치는 지점입니다.

---

## 버전 관리

`.claude/`는 커밋해서 팀과 공유합니다. 훅 스크립트의 실행 권한도 git이 보존하므로,
커밋한 뒤에는 클론만 해도 그대로 돕니다.

아래는 머신마다 다른 값이 들어가므로 `.gitignore`에 넣습니다
(`.claude/gitignore.example` 참고).

```
.claude/settings.local.json
.claude/sim.local
buildServer.json
.compile
```
