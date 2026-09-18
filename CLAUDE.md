# 프로젝트 컨텍스트

> 매 요청마다 로드됩니다. 짧게 유지하세요. 코딩 규약은 `.claude/rules/`에 있으므로
> 여기에 다시 쓰지 않습니다(중복은 매 요청 비용입니다).

## 개요

- 앱: <TuistApp>
- iOS <17.0> / Swift <6.0> / Xcode <27.0>
- 아키텍처: <MVVM + Router, Clean Architecture, Tuist + 모듈화>

## 빌드 / 테스트

```bash
./.claude/scripts/xcbuild.sh build
./.claude/scripts/xcbuild.sh test
./.claude/scripts/xcbuild.sh test -only-testing:<Target>/<TestClass>
```

시뮬레이터는 스크립트가 머신마다 한 번 골라 `.claude/sim.local`에 고정합니다.
`xcrun simctl list`로 기기를 찾거나 `-destination`을 직접 조립하지 마세요.
바꿔야 하면 `xcbuild.sh reset`을 씁니다.

- XcodeBuildMCP를 쓸 때도 destination은 `xcbuild.sh destination` 값을 그대로 넘깁니다.
- 빌드/테스트 로그 전문을 대화에 붙여넣지 않습니다. 실패 라인만 인용합니다.

## 금지

- `main`에 직접 커밋
- 생성 파일(`*.generated.swift`), `Pods/`, `.build/`, `DerivedData/` 편집
- SwiftLint 규칙 억제(`swiftlint:disable`)

## 작업 흐름

| 순서 | 명령 | 실행 | 세션 |
| --- | --- | --- | --- |
| 1 | `/ios-platform-research <기능>` — Apple API·프레임워크 | 백그라운드 | A |
| 2 | `/ios-research <주제>` — 이 저장소 구조 | 포그라운드 | A |
| 3 | `/ios-plan <주제>` → `docs/plans/*.md` 생성 | 인라인 | A |
| 4 | `/ios-implement <계획 파일>` | 인라인 | B (`/clear` 후) |
| 5 | `/ios-review` | 포그라운드 포크 | B |

1을 먼저 띄우면 백그라운드로 돌면서 2가 동시에 진행됩니다.
두 보고서를 대조해 접근법을 정하는 건 3의 첫 단계입니다.

계획 문서가 A→B 인계 수단입니다. 구현은 대화 이력이 아니라 그 문서만 입력으로 씁니다.
그래서 계획이 끝나면 `/clear`로 조사·계획 컨텍스트를 버리고 새로 시작하는 것이 정상 흐름입니다.
