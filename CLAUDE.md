# 프로젝트 컨텍스트

> 매 요청마다 로드됩니다. 짧게 유지하세요. 코딩 규약은 `.claude/rules/`에 있으므로
> 여기에 다시 쓰지 않습니다(중복은 매 요청 비용입니다).

## 개요

- 앱: TuistApp
- iOS 17.0 / Swift 6.0 / Xcode 27.0
- 아키텍처: MVVM + Router, Clean Architecture, Tuist + 모듈화
- 최소 지원 버전의 출처는 `Tuist/ProjectDescriptionHelpers/AppConstants.swift`입니다
  (`.xcodeproj`는 생성물이라 여기서 읽지 마세요).

## 빌드 / 테스트

```bash
./.claude/scripts/xcbuild.sh build
./.claude/scripts/xcbuild.sh test
./.claude/scripts/xcbuild.sh test -only-testing:<Target>/<TestClass>
```

시뮬레이터는 스크립트가 머신마다 한 번 골라 `.claude/sim.local`에 고정합니다.
`xcrun simctl list`로 기기를 찾거나 `-destination`을 직접 조립하지 마세요.
바꿔야 하면 `xcbuild.sh reset`을 씁니다.

시뮬레이터 UDID가 필요한 다른 도구(앱 실행, 스크린샷 등)에는
`./.claude/scripts/xcbuild.sh udid` 출력을 넘깁니다. 같은 기기를 써야 DerivedData 캐시가
한 벌로 유지됩니다. `destination`은 사람이 읽는 형식이라 그대로 넘길 수 없습니다.

빌드/테스트 로그 전문을 대화에 붙여넣지 않습니다. 실패 라인만 인용합니다.

## 금지

- `main`에 직접 커밋 (`PreToolUse` 훅이 차단합니다. 작업 브랜치를 먼저 만드세요)
- 생성 파일(`*.generated.swift`), `Pods/`, `.build/`, `DerivedData/` 편집
- 파일·블록 단위 SwiftLint 억제(`swiftlint:disable`). 불가피한 한 줄은
  `swiftlint:disable:next`로 좁히고 이유를 주석에 남깁니다.

## 작업 흐름

기능 작업은 `/ios-platform-research` → `/ios-research` → `/ios-plan` → `/clear` →
`/ios-implement` → `/ios-review` 순서입니다. 계획 문서가 세션 인계 수단이라 구현은
대화 이력이 아니라 그 문서만 입력으로 씁니다. 각 스킬이 끝날 때 다음 단계를 안내합니다.
자세한 건 `.claude/README.md`(컨텍스트에 실리지 않습니다).
