# 결정 기록: chore/ci-uitests-dependency-hygiene

계획: [`docs/plans/2026-09-29-ci-uitests-dependency-hygiene.md`](../plans/2026-09-29-ci-uitests-dependency-hygiene.md)

리뷰어는 아래 "확정 결정"을 다시 제안하지 않는다. 뒤집어야 하면 `번복 제안` 으로 이유를 적는다.

## 확정 결정

| # | 결정 | 이유 |
| --- | --- | --- |
| D1 | `tuist inspect dependencies` 는 `release-build` 잡의 셋업 뒤에 둔다. lint·build-test 가 아니다 | lint 는 `tuist install` 을 하지 않아 외부 의존 그래프를 읽지 못한다. build-test 에 두면 검사가 실패할 때 테스트 결과가 빠진다 |
| D2 | `enforceExplicitDependencies` 는 유지한다 | generate 시점에 빠진 의존을 로컬에서 바로 막는다. Tuist 4.208.0 의 generate 에 deprecation 경고가 없었다. inspect 는 CI 보완이다 |
| D3 | 자기 `*Testing` 은 템플릿이 테스트·데모에 자동으로 연결하지 않는다. 쓰는 모듈만 `.testing(...)` 으로 적는다 | "import 하는 것만 적는다" 한 규칙으로 통일한다. 자동 연결은 새 모듈 스캐폴드에서도 중복 의존을 만든다 |
| D4 | 자기 `*Testing` 은 테스트·데모만 규칙 없이 쓸 수 있다. `*Testing` 타깃이 자기 자신을 가리키면 매니페스트에서 멈춘다 (R1-6) | Core 는 `.testing(.domain)` 이 자기 자신으로 풀려 `mayDepend` 에 걸린다. `*Testing` 의 자기 참조는 Tuist 의 순환 오류보다 이유가 드러나는 곳에서 막는다. 피처의 `*Testing` 은 Interface 로 풀리므로 타깃 이름으로 비교한다 |
| D5 | UI 테스트 스텁은 App 의 `#if DEBUG` `UITestItemRepository` 로 둔다. `StubItemRepository`(DomainTesting)를 쓰지 않는다 | 앱은 `*Testing` 에 의존할 수 없다는 규칙을 유지하고 Release 에 테스트 코드를 싣지 않는다 |
| D6 | UI 테스트는 XCTest 로 쓴다 | `XCUIApplication` 기반 UI 테스트는 Swift Testing 으로 쓸 수 없다. `tests.md` 의 "새 테스트는 Swift Testing" 규약의 예외다 |
| D7 | UI 테스트는 탭을 한국어 라벨로 찾고 `-AppleLanguages (ko)` 로 언어를 고정한다 (R1-5) | 탭 바 항목에 접근성 식별자를 붙이는 것보다 변경이 작다. 번역이 추가돼도 CI 시뮬레이터 언어와 상관없이 같은 라벨이 나온다 |
| D8 | Renovate 는 swift·mise 만 다루고 월 1회 PR 하나로 묶는다(`separateMajorMinor: false`). firebase-ios-sdk 는 `allowedVersions: "<13"` 으로 12.x 안에서만 올린다 (R1-4) | Actions 는 Dependabot 이 맡는다. `separateMajorMinor: false` 에서는 가장 높은 버전 하나만 제안하므로, 메이저를 `enabled: false` 로 끄면 12.x 업데이트까지 막힌다 |
| D9 | 템플릿 검증은 git 워크트리가 아니라 작업 트리 사본에서 돌리고, DerivedData 도 사본 옆 임시 디렉터리에 두어 함께 지운다 (R1-1) | 커밋하지 않은 템플릿 변경도 검사한다. 기본 DerivedData 에 두면 실행마다 수 GB 가 쌓인다 |
| D10 | 템플릿 검증은 모든 옵션을 켠 조합과 옵션 없는 조합을 core·feature 에 하나씩 만든다 (R1-7) | 스텐실에 옵션별 분기(`bundle: .module` 등)가 있다. 네 모듈 모두 같은 워크스페이스 빌드에 들어가 추가 비용은 컴파일뿐이다 |
| D11 | Templates 워크플로는 경로 필터로 돌고 required check 로 걸지 않는다. 스캐폴드가 쓰는 모듈 API 경로(DesignSystem Sources, Navigation)와 스크립트가 부르는 xcbuild.sh·setup 액션을 필터에 넣는다 (R1-2) | 관련 없는 PR 에서 macOS 러너 비용을 쓰지 않는다. 필터가 있으면 required 로 걸 때 PR 이 대기 상태로 막힌다 |
| D12 | feature 스캐폴드는 Home 과 같은 MVVM + Router 골격(`<Name>ViewModel`, `SpyRouter` 테스트)이다 | 선언한 의존을 모두 실제로 쓰게 하고, 새 피처가 템플릿의 아키텍처 패턴으로 시작하게 한다 |

## 라운드 이력

### 1라운드 — 스냅샷 `78ab222fdfa1d83bbab4f3f5a0c27ece6530ec16`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R1-1 (Should fix) 템플릿 검증 DerivedData 누적 | 반영 | D9. `-derivedDataPath` 를 사본 옆 임시 디렉터리로 두고 trap 이 함께 지운다 |
| R1-2 (Should fix) Templates 경로 필터 누락 | 반영 | D11. `Modules/Core/DesignSystem/Sources/**`, `Modules/Core/Navigation/**`, `.claude/scripts/xcbuild.sh`, `.github/actions/setup/**` 추가 |
| R1-3 (Should fix) `<앱>UITests` 이름 충돌 검사 | 반영 | `new-module.sh`, `rename.sh` 비교와 주석. `new-module.sh core TuistAppUI` 가 거부되는 것을 확인 |
| R1-4 Renovate 메이저 분리 | 반영 | D8. 반영하면서 Firebase 규칙이 12.x 업데이트까지 막는 문제를 찾아 `allowedVersions` 로 바꿨다. 공식 검증기 통과 |
| R1-5 UI 테스트 언어 고정 | 반영 | D7 |
| R1-6 `*Testing` 자기 참조 오류 | 반영 | D4. Domain 에 `testingDependencies: [.testing(.domain)]` 를 임시로 넣었을 때 `Domain/Project.swift` 매니페스트에서 멈추는 것을 확인하고 되돌렸다 |
| R1-7 옵션 조합 | 반영 | D10 |
| R1-8 xcbuild.sh 주석 | 반영 | 앱 스킴 테스트 대상에 `TuistAppUITests` 를 적었다 |

### 2라운드 — 스냅샷 `c90d64a8ffc70d291538cf96e80154f20239570f`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R2-1 (Consider) 도달하지 않는 `.implementation` 분기의 틀린 주석 | 반영 | `break` 를 `preconditionFailure` 로 바꿔 도달하지 않는다는 것을 코드로 드러냈다. 위쪽 검사 순서가 바뀌면 조용히 `mayDepend` 로 넘어가지 않고 멈춘다 |

### 3라운드 — 스냅샷 `11e885ea5479fe538ce0a9698f5bc77778267861`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R3-1 (Consider) `preconditionFailure` 메시지 형식 | 반영 | 파일의 다른 오류처럼 `ErrorText.prefix` 와 `targetName → target` 을 붙여, 실행되면 어느 타깃인지 드러나게 했다 |
