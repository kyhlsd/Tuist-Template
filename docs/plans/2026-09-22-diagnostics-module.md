# Diagnostics 모듈 분리

## 목표

- 진단 타입과 정책을 Domain에서 새 Core 모듈 `Modules/Core/Diagnostics`로 옮긴다. Domain에는 엔티티, 에러, Repository 프로토콜만 남는다.
- 스파이 3개를 `DomainTesting`에서 `DiagnosticsTesting`으로 옮긴다.
- `LoggerDiagnosticSink`를 App에서 Diagnostics로 옮겨 공개 기본 구현으로 둔다.
- **동작은 바뀌지 않는다.** 로그 문구, breadcrumb 형식, 보고 판정, 중복 억제, Firebase 초기화가 모두 그대로다.
- `Modules/Core/Diagnostics/README.md`가 특징과 사용법을 설명한다. 루트 README의 모듈 구조가 갱신된다.
- `./.claude/scripts/xcbuild.sh test`와 `./.claude/scripts/xcbuild.sh build -configuration Release`가 통과한다.

## 범위 밖

- Networking의 구조. `NetworkActivityObserving`, `NetworkRequestRecord`, `RecordingNetworkActivityObserver`와 App의 `NetworkBreadcrumbAdapter`를 그대로 둔다(결정 사항 참고).
- `NetworkFailure`를 `DiagnosticFailure`로 바꾸는 코드의 위치. `RemoteItemRepository`의 `private func report(_:)`에 그대로 둔다.
- Feature와 앱 로직의 에러 보고, 화면 이동 breadcrumb(이전 계획의 범위 밖 항목 그대로).
- Firebase 관련 코드(`FirebaseBootstrap`, `CrashlyticsDiagnosticSink`)의 위치. App에 남는다.

## 전제

### 환경
- iOS 17.0, Swift 6 언어 모드, Xcode 27, Tuist 4.208.0(`mise.toml`).
- `Tuist.swift`에서 `enforceExplicitDependencies: true`이다. import하는 모듈은 해당 타깃의 의존성에 모두 적는다.
- `xcbuild.sh`는 `tuist generate`를 하지 않는다. 파일을 옮기거나 매니페스트를 바꾼 단계에서는 `mise exec -- tuist generate --no-open`을 먼저 돌린다.
- 워크스페이스 스킴은 `Tuist/ProjectDescriptionHelpers/Scheme+Workspace.swift`가 `Module.all`로 만든다. `Project.core`는 모듈이 `Module.all`에 없거나 `hasDemoApp`이 `Module.withDemoApp`과 다르면 생성을 멈춘다(`Module.validateRegistration`).
- `OSAllocatedUnfairLock`(iOS 16+)을 쓴다. `Synchronization.Mutex`는 iOS 18+라 쓸 수 없다. `@unchecked Sendable`은 쓰지 않는다.
- Testing 타깃의 `import os`는 명시적 의존성 검사에 걸리지 않는다(이전 작업에서 `DomainTesting`으로 확인).
- 파일은 `git mv`로 옮겨 이력을 남긴다.

### 옮길 파일 (Domain → Diagnostics)
- `Modules/Core/Domain/Sources/Diagnostics/` 8개: `Breadcrumb`, `BreadcrumbLevel`, `BreadcrumbRecording`, `DiagnosticDefaults`, `DiagnosticEventSink`, `DiagnosticFailure`, `DiagnosticReporter`, `DiagnosticReporting`. 모두 `public`이고 Foundation만 import한다.
- `Modules/Core/Domain/Testing/Sources/`: `SpyBreadcrumbRecorder`, `SpyDiagnosticEventSink`, `SpyDiagnosticReporter`(`import Domain`, `import os`).
- `Modules/Core/Domain/Tests/`: `DiagnosticReporterTests`(`@testable import Domain`, `import DomainTesting`), `DiagnosticFailureTests`(`import Domain`).
- `App/Sources/Diagnostics/LoggerDiagnosticSink.swift:13`: `struct LoggerDiagnosticSink: DiagnosticEventSink, BreadcrumbRecording`(internal). `init(logger: Logger)`(`:16`). `import Domain`, `import os`.

### 참조를 고칠 곳 (`import Domain` → `import Diagnostics`, 필요하면 둘 다)
- `App/Sources/DI/AppContainer.swift:6-10`: `Domain`은 `ItemRepository` 때문에 남기고 `Diagnostics`를 더한다.
- `App/Sources/Diagnostics/CrashlyticsDiagnosticSink.swift:6`, `NetworkBreadcrumbAdapter.swift:6`: `Domain` → `Diagnostics`.
- `App/Tests/CrashlyticsDiagnosticSinkTests.swift:6`, `NetworkBreadcrumbAdapterTests.swift:6`: `Domain` → `Diagnostics`. `AppContainerDiagnosticSinkTests.swift`는 `LoggerDiagnosticSink`를 쓰므로 `import Diagnostics`를 더한다.
- `Modules/Core/Data/Sources/RemoteItemRepository.swift:6-7`: `Domain`은 `Item`, `ItemError` 때문에 남기고 `Diagnostics`를 더한다.
- `Modules/Core/Data/Tests/RemoteItemRepositoryTests.swift:8`: `import DomainTesting`은 `SpyDiagnosticReporter` 때문에만 있다 → `DiagnosticsTesting`으로 바꾼다. `DiagnosticFailure`를 쓰므로 `import Diagnostics`를 더한다.
- 매니페스트:
  - `App/Project.swift:16-22`: `.module(.diagnostics)` 추가
  - `Modules/Core/Data/Project.swift:16-17`: `.module(.diagnostics)` 추가. 테스트 의존성(`:20-`)은 `.testing(.domain)`을 `.testing(.diagnostics)`로 바꾸고 `.module(.diagnostics)`를 더한다
  - `Tuist/ProjectDescriptionHelpers/Module.swift`: `case diagnostics`(`:56` 근처), `name`(`:73` 근처), `path`의 Core 목록(`:81`), `Module.all`(`:109`), 의존 방향 다이어그램(`:24-25`)
- `Modules/Core/Domain/Tests/DomainTests.swift`: 주석을 이전 문구로 되돌린다("UseCase 처럼 Domain 에 로직이 생기면 여기서 테스트한다. 지금의 Domain 은 선언(엔티티, 에러, 프로토콜)뿐이라 검증할 동작이 없다.").

### 바뀌지 않는 것
- Networking 모듈 전체. Networking은 Diagnostics를 모른다.
- `docs/reviews/feat-diagnostics-crashlytics.md`(main에서는 삭제됨)의 결정 D1~D7. 타입 위치만 바뀐다.

## 결정 사항

| 결정 | 선택 | 이유 |
|---|---|---|
| 모듈 분리 | 진단 타입과 `DiagnosticReporter`를 새 Core 모듈 `Diagnostics`로 옮긴다 | 진단은 도메인 개념이 아니라 공통 인프라다. Domain은 `Module.swift`의 정의대로 엔티티·UseCase·Repository 프로토콜만 둔다. 진단 README를 둘 곳도 생긴다 |
| 플랫폼 조사 | 하지 않는다 | 새 Apple API가 없다. 이미 쓰는 `os.Logger`, `OSAllocatedUnfairLock`, Tuist 매니페스트뿐이다(사용자 확인) |
| Networking 의존 | **옵저버를 유지한다.** Networking은 Diagnostics를 모르고, App의 `NetworkBreadcrumbAdapter`가 `NetworkRequestRecord`를 `Breadcrumb`로 바꾼다 | 사용자 결정. Networking을 진단 수단과 무관한 모듈로 둔다. 대가로 옵저버·기록·어댑터 세 타입이 남는다 |
| 변환 위치 | `NetworkFailure` → `DiagnosticFailure` 변환은 Data(`RemoteItemRepository.report`)에 둔다 | 사용자 결정. Networking이 Diagnostics를 모르므로 변환은 둘을 모두 아는 쪽에 있어야 한다 |
| 로그 싱크 위치 | `LoggerDiagnosticSink`를 Diagnostics로 옮겨 `public`으로 둔다 | 사용자 결정. App 전용이 아니라 데모 앱도 쓸 수 있는 기본 구현이다 |
| Diagnostics의 import | Foundation과 `os`를 허용한다 | `LoggerDiagnosticSink`가 `os.Logger`를 쓴다. Domain의 "Foundation만" 규칙은 Domain에만 적용한다. Diagnostics는 UI 프레임워크와 외부 패키지를 import하지 않는다 |
| 테스트 지원 | `hasTestingSupport: true`. 스파이 3개를 `DiagnosticsTesting`으로 옮긴다 | Data와 이후 Feature 테스트가 재사용한다 |
| 데모 앱 | 없음(`hasDemoApp: false`) | 화면이 없는 모듈이다. `Module.withDemoApp`에 넣지 않는다 |
| 모듈 이름 | `Diagnostics`, `Module.diagnostics` | 이미 쓰는 폴더 이름(`Sources/Diagnostics/`)과 같다 |

## 변경 계획

각 단계는 독립적으로 빌드와 테스트가 통과하고, 커밋 하나 분량이다. 작업 브랜치는 `refactor/diagnostics-module`(이미 만듦).

### 1. Diagnostics 모듈 생성과 타입 이동
- 파일:
  - 새 파일: `Modules/Core/Diagnostics/Project.swift`
  - `git mv`: Domain `Sources/Diagnostics/*` 8개 → `Modules/Core/Diagnostics/Sources/`, 스파이 3개 → `Modules/Core/Diagnostics/Testing/Sources/`, 테스트 2개 → `Modules/Core/Diagnostics/Tests/`
  - 수정: `Tuist/ProjectDescriptionHelpers/Module.swift`, `App/Project.swift`, `Modules/Core/Data/Project.swift`, 위 "참조를 고칠 곳"의 Swift 파일들, `Modules/Core/Domain/Tests/DomainTests.swift`
- 변경:
  - `Project.core(name: "Diagnostics", hasTestingSupport: true)`. 주석으로 모듈의 역할(진단 타입, 중복 억제, 기본 로그 싱크)과 "Firebase 같은 전송 수단은 App이 싱크로 꽂는다"를 적는다.
  - 옮긴 파일 헤더의 모듈 이름을 `Domain` → `Diagnostics`, `DomainTesting` → `DiagnosticsTesting`, `DomainTests` → `DiagnosticsTests`로 고친다.
  - 옮긴 테스트의 import: `@testable import Diagnostics`, `import DiagnosticsTesting`.
  - `Module.swift`: `case diagnostics`에 문서 주석(진단 타입, Foundation과 os만), `name`은 `"Diagnostics"`, `path`는 Core, `Module.all`에 추가한다. 다이어그램에 `Data ──→ Diagnostics`, `App ──→ Diagnostics`를 넣는다.
  - `Modules/Core/Domain/Sources/Diagnostics/`와 비게 되는 폴더는 지운다.
- 검증: `tuist generate` 성공. `xcbuild.sh test` 전체 통과(DiagnosticsTests가 워크스페이스 스킴에서 돈다). `grep -rn 'Diagnostic\|Breadcrumb' Modules/Core/Domain`이 0건이다.

### 2. LoggerDiagnosticSink를 Diagnostics로 이동
- 파일: `git mv App/Sources/Diagnostics/LoggerDiagnosticSink.swift Modules/Core/Diagnostics/Sources/LoggerDiagnosticSink.swift`, `App/Sources/DI/AppContainer.swift`(import 확인), `App/Tests/AppContainerDiagnosticSinkTests.swift`
- 변경:
  - `public struct`, `public init(logger:)`, `public func record`, `public func send`로 올린다. `import Domain` → 없음(같은 모듈). `import os`는 유지한다.
  - 파일 헤더의 모듈 이름을 `Diagnostics`로 고친다. 문서 주석의 "Firebase 를 초기화하지 않았을 때" 문구는 "전송 수단을 쓰지 않을 때(Debug, 설정 파일 없음, 데모 앱)"로 넓힌다.
  - `AppContainerDiagnosticSinkTests`에 `import Diagnostics`를 더한다.
- 검증: `xcbuild.sh test -only-testing:TuistAppTests` 통과, `xcbuild.sh build` 통과.

### 3. 문서
- 파일: `Modules/Core/Diagnostics/README.md`(새 파일), `README.md`(루트), `Modules/Core/Networking/README.md`
- 변경:
  - Diagnostics README: 기존 모듈 README(`Modules/Core/Navigation/README.md`)처럼 특징과 사용법 위주로 쓴다. 이력은 쓰지 않는다. 담을 내용:
    - 특징: 서버가 볼 수 없는 에러만 보고, request ID로 서버 로그와 연결, fingerprint(operation × 타입(case) × 코드)별 5분 억제, breadcrumb이 비치명 에러와 크래시 리포트에 붙음, 전송 수단은 싱크로 교체, Debug와 plist가 없을 때는 로그로만 남김, 취소는 info
    - 구성: 이 모듈의 타입, Networking(`NetworkFailure`, `RequestIDMiddleware`, `NetworkActivityObserving`), App(`FirebaseBootstrap`, `CrashlyticsDiagnosticSink`, `NetworkBreadcrumbAdapter`, `AppContainer` 조립)의 위치와 의존 방향
    - 사용법: 새 Repository에서 보고하기(`catch`에서 `NetworkFailure.describe` → `isReportable`이면 `reporter.report`), 테스트에서 `SpyDiagnosticReporter` 쓰기, 새 싱크 만들기(`DiagnosticEventSink & BreadcrumbRecording`), Console에서 보기(subsystem = 번들 ID, category `Networking`/`Diagnostics`)
    - Crashlytics 켜기: `GoogleService-Info.plist`를 `App/Resources/`에 넣는 체크리스트(이전 계획의 "plist를 넣을 때"). 대시보드에서 읽는 법(domain `network.<operation>.<errorType>`, code, userInfo `summary`/`requestID`, 로그 탭)
    - 한도와 주의: 비치명 에러는 세션당 8개이고 다음 실행 때 전송, 로그는 64KB, 연관값이 없는 case는 타입 이름만, refresh 실패는 `refreshToken`으로 보고됨
  - 루트 README "구조"에 `Diagnostics/` 줄을 추가하고, 이미 틀린 `Networking/ HTTPClient`를 "OpenAPI 생성 클라이언트, 미들웨어, 토큰 저장소"로 고친다.
  - Networking README의 `Sources/Diagnostics/` 줄 뒤에 "진단 전체 구조는 `Modules/Core/Diagnostics/README.md`" 링크를 단다.
- 검증: README의 타입 이름과 경로가 실제 코드와 맞는지 grep으로 대조한다. 코드 변경이 없으므로 빌드는 생략한다.

## 테스트 전략

- **새 테스트 없음.** 동작을 바꾸지 않는 이동이다.
- 옮긴 테스트(`DiagnosticReporterTests` 6개, `DiagnosticFailureTests` 4개)가 `DiagnosticsTests` 번들에서 그대로 통과해야 한다.
- import만 바뀌는 기존 테스트: `RemoteItemRepositoryTests`, `CrashlyticsDiagnosticSinkTests`, `NetworkBreadcrumbAdapterTests`, `AppContainerDiagnosticSinkTests`.
- 마지막에 전체 스위트를 한 번 돌리고, 테스트 번들이 8개(기존 7개 + DiagnosticsTests)인지 확인한다. `xcbuild.sh build -configuration Release`도 돌린다.

## 위험 요소

| 위험 | 가능성 | 대응 |
|---|---|---|
| `Module.all` 등록을 빠뜨려 생성이 멈춤 | 저 | 의도한 안전장치다. 1단계에서 case와 함께 등록한다 |
| 명시적 의존성 누락(App 테스트가 `Diagnostics`를 import) | 중 | 앱 테스트는 지금도 앱의 전이 의존성(`HomeInterface`, `Domain`)을 import하고 있다. 실패하면 `Project.app`의 `testDependencies`에 `.module(.diagnostics)`를 넘긴다(구현 중 확인) |
| `git mv` 뒤 `.xcodeproj`에 이전 경로가 남음 | 저 | `.xcodeproj`는 생성물이다. `tuist generate`로 다시 만든다 |
| `@testable import`와 일반 import가 한 테스트 타깃에 섞임 | 저 | Debug 테스트에서는 문제없다. Release 빌드는 워크스페이스 스킴이 테스트 타깃을 빌드하지 않는다 |
| 이전 리뷰 결정 기록의 타입 위치 설명이 틀어짐 | 확실 | 그 기록은 main에서 삭제됐다(이력에만 있음). README가 현재 위치를 설명한다 |

## 롤백

- 단계마다 커밋 하나이므로 역순으로 `git revert`한다.
- 3단계는 문서뿐이다. 2단계를 되돌리면 `LoggerDiagnosticSink`가 App의 internal 타입으로 돌아간다. 1단계를 되돌리면 모듈이 사라지고 타입이 Domain으로 돌아간다(`tuist generate` 필요).
