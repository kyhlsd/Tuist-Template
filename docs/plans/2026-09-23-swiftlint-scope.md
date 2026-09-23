# SwiftLint 검사 범위를 저장소 소스로 좁히기

## 목표

- 메인 체크아웃 루트에서 `mise exec -- swiftlint lint --quiet`의 error가 0개다.
- 출력이 저장소 소스(`App/`, `Modules/`, `Tuist/`, 루트 매니페스트)의 warning만 남아 크게 줄어든다(기준: 6.3MB, error 2360개).
- CI `lint` 잡의 결과가 바뀌지 않는다(검사 대상 파일 집합이 같다).
- 훅(`.claude/hooks/swift-quality.sh`)이 워크트리 안의 파일을 계속 검사한다.

## 범위 밖

- 저장소 소스의 기존 warning 정리.
- `.swiftformat` 변경. 이미 숨김 폴더를 건너뛰어 164개 파일만 본다.
- CI 워크플로 변경(`ci/github-actions` 브랜치에만 있다).

## 전제

### 원인 (조사 결과)
- 저장소 밖 경로는 `~/.cache/swifterpm/sources/<패키지>/...`다. `tuist install`이 만든
  `Tuist/.build/checkouts/<패키지>`가 이 캐시를 가리키는 **심볼릭 링크**다. mise의 `spm:` 백엔드와는 무관하다
  (mise 설치물은 `~/.local/share/mise` 아래에 있고 저장소 안에 링크가 없다).
- 루트 `Tuist/.build`는 `excluded`에 있어 **정상적으로 빠진다**. 새는 곳은 `.claude/worktrees/<이름>/Tuist/.build`다.
  `excluded`의 `Tuist/.build`는 루트 기준 경로라 중첩 워크트리의 같은 폴더와 맞지 않는다.
  워크트리의 `Tuist/.build/tuist-derived/.../TuistBundle+*.swift`도 `swiftlint:disable` 커스텀 규칙에 걸린다.
  워크트리 소스 자체도 중복으로 검사된다.
- 분류(메인 체크아웃, 워크트리 2개): 캐시 경로 error 2355개, 워크트리 tuist-derived error 5개, `Modules/`의 error 0개.
- CI에서 안 보이는 이유: 새 체크아웃에는 `.claude/worktrees/`가 없고, lint 잡은 `tuist install`도 하지 않는다. **로컬 전용 현상이다.**

### SwiftLint 0.65.1 동작 (직접 확인)
- `excluded`에 든 폴더는 그 아래의 심볼릭 링크까지 따라 들어가지 않는다.
- 경로를 직접 넘기면서 `--force-exclude`를 주면 `excluded`는 적용되고 `included`는 **적용되지 않는다**.
  README의 "`included`를 두면 훅이 넘긴 파일이 빠진다"는 걱정은 이 버전에서는 맞지 않다.
  다만 `included` 목록에 없는 새 최상위 폴더는 전체 검사(CI)에서 조용히 빠진다.

### 훅의 함정
- 훅은 `cd "$CLAUDE_PROJECT_DIR"` 후 `--force-exclude "$file"`로 검사한다. 세션 프로젝트 디렉터리가 메인 루트이고
  편집 파일이 `.claude/worktrees/x/...` 안이면, `.claude`를 제외하는 순간 그 파일은 조용히 통과한다.

## 결정 사항

| 결정 | 선택 | 이유 |
|---|---|---|
| 범위 지정 방식 | `excluded`에 `.claude`를 더한다. `included`는 두지 않는다 | 원인 폴더를 정확히 막는다. README의 "`excluded`만 쓴다" 방침과 맞고, 새 최상위 소스 폴더가 CI에서 조용히 빠지지 않는다. `.claude`에는 추적되는 Swift 파일이 없다 |
| 중첩 설정 | 토큰 폴더의 `.swiftlint.yml`은 그대로 둔다 | `disabled_rules`만 있다. 범위 설정은 루트에서만 한다 |
| 훅 실행 위치 | 편집 파일이 속한 git 작업 트리의 최상위에서 실행한다(`git rev-parse --show-toplevel`). 실패하면 `CLAUDE_PROJECT_DIR` | 워크트리 파일을 그 워크트리의 설정으로 검사하게 되고, `.claude` 제외에 걸리지 않는다 |
| SwiftFormat과의 대응 | 바꾸지 않는다 | SwiftFormat은 숨김 폴더를 건너뛴다. 이번 변경으로 SwiftLint도 같은 파일 집합을 본다 |
| 플랫폼 조사 | 하지 않는다 | 도구 설정 변경이라 Apple API가 없다 |

## 변경 계획

### 1. `.swiftlint.yml`에 `.claude` 제외 추가
- 파일: `.swiftlint.yml`의 `excluded:`
- 변경: `- .claude` 추가, 이유 주석. `--strict` 금지 주석은 그대로 둔다
- 검증: 메인 체크아웃 루트에서 `swiftlint lint --quiet --config <이 파일>`의 error 0, 출력 크기 비교.
  워크트리 루트에서 전체 검사한 파일 수가 SwiftFormat 대상과 같은지 확인

### 2. 훅이 파일의 작업 트리 최상위에서 SwiftLint를 돌리게 함
- 파일: `.claude/hooks/swift-quality.sh`
- 변경: `lint_root=$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$project_dir")`
- 검증: 메인 루트를 `CLAUDE_PROJECT_DIR`로 두고 워크트리 파일의 위반을 여전히 잡는지 확인

### 3. README의 SwiftLint 설정 절 갱신
- 파일: `.claude/README.md` "SwiftLint 설정"
- 변경: `.claude` 제외 이유, 훅 실행 위치

## 테스트 전략

Swift 코드 변경이 없어 단위 테스트는 없다. 위 검증 명령으로 확인한다.

## 위험 요소

| 위험 | 가능성 | 대응 |
|---|---|---|
| 훅이 워크트리 파일을 조용히 통과시킴 | 2단계 없이는 높음 | 2단계 |
| 누군가 `.claude` 아래에 Swift 소스를 둠 | 낮음 | 제외 이유를 주석으로 남김 |

## 롤백

커밋을 되돌린다. 설정 파일만 바뀐다.
