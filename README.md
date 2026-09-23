# TuistApp

Tuist 로 모듈화한 iOS 앱 템플릿. iOS 17 이상, Swift 6 언어 모드, Xcode 27.

Claude Code 설정(스킬·훅·빌드 스크립트)은 [.claude/README.md](.claude/README.md)에 따로 정리되어 있다.

## 처음 실행

```bash
mise install                 # tuist, swiftformat, swiftlint (버전은 mise.toml)
tuist install                # Tuist/Package.swift 의 외부 패키지
cp Configurations/ClientKeys.xcconfig.example Configurations/ClientKeys.xcconfig
tuist generate               # TuistApp.xcworkspace 생성 후 Xcode 로 연다
```

`*.xcodeproj`, `*.xcworkspace`, `Derived/` 는 생성물이라 커밋하지 않는다.
매니페스트(`Project.swift` 등)를 바꾸면 `tuist generate` 를 다시 실행한다.

LSP(정의 이동, 심볼 조회)를 쓰려면 머신마다 한 번 build server 를 설정한다.
`buildServer.json` 은 로컬 경로가 들어가 커밋하지 않는다.

```bash
brew install xcode-build-server
xcode-build-server config -workspace TuistApp.xcworkspace -scheme TuistApp-Workspace
```

**`tuist generate` 를 다시 돌린 뒤에는 이 명령도 다시 돌린다.** DerivedData 경로에
워크스페이스 해시가 들어가서, 재생성하면 새 디렉터리가 만들어지고 `buildServer.json` 은
옛날 것을 계속 가리킨다. 파일은 멀쩡히 있는데 심볼 조회만 조용히 실패하는 상태가 된다.

## 구조

```
App/                        앱 타깃. 모듈을 조립하는 곳
  Sources/DI/               AppContainer(구현 타입 생성), AppConfiguration(Info.plist 설정)
  Sources/Navigation/       탭, 탭별 스택, Route → 화면 매핑
Modules/
  Core/
    Domain/                 엔티티, 에러, Repository 프로토콜 (+ DomainTesting: 스텁·픽스처)
    Data/                   Repository 구현, DTO
    Networking/             OpenAPI 생성 클라이언트, 미들웨어, 토큰 저장소
    Diagnostics/            진단 타입, 중복 억제 보고기, 로그 싱크 (+ DiagnosticsTesting: 스파이)
    Navigation/             Router(스택 상태), Routing(이동 요청) (+ NavigationTesting: SpyRouter)
    DesignSystem/           토큰, 컴포넌트 (+ DesignSystemDemo: 카탈로그 앱)
  Features/
    Home/                   Interface(HomeRoute) / 구현 / Tests / Demo
Configurations/             환경별 xcconfig (Debug, Release, ClientKeys)
Tuist/ProjectDescriptionHelpers/
  AppConstants.swift        앱 이름, 번들 ID 접두사, 배포 타깃
  Module.swift              모듈 목록과 경로, 의존 그래프
  Project+Templates.swift   feature / core / app 템플릿
  Settings+Common.swift     공통 빌드 설정
```

의존 방향과 각 모듈의 역할은 `Module.swift` 상단 주석이 기준이다.

## 화면 이동

MVVM + Router. 최상위는 TabView 이고, 탭마다 `Router` 하나와 `NavigationStack` 하나를 가진다.

```
HomeViewModel.select(item)
  └─ router.push(HomeRoute.detail(id:))      뷰모델은 Routing 프로토콜만 안다
       └─ NavigationStack(path: $router.path)
            └─ .appDestinations(container)    App 이 Route 를 화면으로 바꾼다
                 └─ container.makeView(for: HomeRoute) → HomeDetailView
```

- Route 는 각 피처 Interface 의 `Hashable` enum 이다. 연관값에는 식별자만 담는다.
- 다른 피처로 갈 때도 그 피처 Interface 의 Route 를 push 한다. 피처끼리 구현을 import 하지 않는다.
- Router 는 push/pop 만 다룬다. 시트·다이얼로그는 각 화면이 자기 상태로 띄운다.

**화면을 추가할 때**

1. 피처 Interface 의 Route 에 case 를 더한다.
2. 뷰모델에서 `router.push(...)` 로 요청한다. 테스트는 NavigationTesting 의 `SpyRouter` 로 확인한다.
3. `App/Sources/DI/AppContainer+<Feature>.swift` 의 `makeView(for:)` 에 화면을 연결한다.
4. 새 피처라면 `App/Sources/Navigation/View+AppDestinations.swift` 에 그 Route 타입을 한 줄 등록한다.
   등록하지 않은 Route 는 push 해도 화면이 뜨지 않는다.

**탭을 추가할 때**는 `AppTab` 에 case 를, `TabRootView.root` 에 그 탭의 루트 화면을 더한다.

## 스킴

Tuist 는 프로젝트마다 스킴 하나를 만든다. 데모 타깃은 그 프로젝트 스킴의 실행 대상이다.

| 스킴 | 실행(⌘R) | 테스트(⌘U) |
| --- | --- | --- |
| `TuistApp` | 앱 | 앱 테스트만 |
| `TuistApp-Workspace` | 앱 | 모든 모듈의 테스트 (빌드는 앱·모듈·데모 앱만. `Scheme+Workspace.swift`. 배포 아카이브는 `TuistApp` 스킴으로) |
| `Home` | HomeDemo | HomeTests |
| `DesignSystem` | DesignSystemDemo (카탈로그) | DesignSystemTests |

## CI

`.github/workflows/ci.yml` 이 PR 과 `main` 푸시마다 두 잡을 병렬로 돌린다.
Tuist 계정·시크릿·저장소 변수가 없어도 그대로 동작한다.

| 잡 | 검사 |
| --- | --- |
| `lint` | swiftformat 포맷, SwiftLint(error 만 실패), OpenAPI 생성물이 명세와 일치하는지 |
| `build-test` | `tuist install` → `tuist generate` → 모든 모듈 테스트(Debug) → Release 빌드 |

로컬에서 같은 검사를 재현하려면 저장소 루트에서 다음을 돌린다.

```bash
mise exec -- swiftformat --lint .
mise exec -- swiftlint lint --quiet
Scripts/openapi-generate.sh --check
./.claude/scripts/xcbuild.sh test
./.claude/scripts/xcbuild.sh build -configuration Release
```

- **테스트가 실패하면** 실행 요약 페이지의 Artifacts 에 `TestResults.xcresult` 가 올라간다(7일 보관).
  내려받아 Xcode 로 열면 실패 원인과 첨부를 볼 수 있다.
- **컴파일 에러·경고**는 PR 파일 뷰에 인라인 주석으로도 달린다. **테스트 실패**는 실행 요약 페이지의
  Annotations 에만 보인다. Swift Testing 이 경로 없이 파일 이름만 내보내서 PR 의 파일에 붙지 않는다.
  (러너 이미지의 xcbeautify 를 쓴다. 이미지에 없거나 `--renderer` 를 모르는 버전이면 주석만 빠지고 잡은 그대로 돈다.)
- **러너**는 기본 `xcode-27`(Xcode 27 을 주는 유일한 GitHub 호스티드 러너, preview)이다.
  저장소 변수 `MACOS_RUNNER` 를 만들면 코드 수정 없이 다른 라벨(GA 라벨, 자체 호스팅 등)로 바꿀 수 있다.
- **Xcode 메이저를 올릴 때**는 `Tuist.swift` 의 `compatibleXcodeVersions` 와 `ci.yml` 의 기본 러너 라벨
  (또는 `MACOS_RUNNER`)을 함께 바꾼다. 둘이 어긋나면 `tuist generate` 가 멈춘다.
- **브랜치 보호**에서 `lint`, `build-test` 를 required status check 로 거는 것을 권장한다.
  워크플로를 지우거나 잡 이름을 바꾸기 전에는 이 설정을 먼저 풀어야 PR 이 막히지 않는다.
- macOS 러너는 분당 과금 배수가 크다(비공개 저장소). 같은 PR 에 새 커밋이 오면 이전 실행은 취소된다.
  `main` 푸시는 커밋마다 따로 돌아 연달아 머지해도 모든 커밋에 결과가 남는다.
- 외부 액션은 커밋 SHA 로 고정돼 있다(뒤에 버전 주석). Dependabot(`.github/dependabot.yml`)이 월 1회
  모든 액션을 PR 하나로 묶어 SHA 와 주석을 함께 올린다. 손으로 올릴 때도 둘을 함께 바꾼다.

## 모듈 추가

1. `Module.swift` 에 case 를 추가한다. (피처는 `.feature("Name")` 을 쓰면 되므로 추가할 필요 없다)
   그리고 `Module.all` 에 등록한다. 데모 앱을 켜면 `Module.withDemoApp` 에도 넣는다.
   워크스페이스 스킴이 이 목록으로 빌드·테스트 대상을 정하므로, 빠지거나 어긋나면 `tuist generate` 가 멈춘다.
2. `Modules/Core/<Name>/` 또는 `Modules/Features/<Name>/` 에 `Project.swift` 를 만들고
   `Project.core(...)` / `Project.feature(...)` 를 호출한다.
3. 템플릿이 기대하는 폴더를 만든다. 옵션을 켠 것만 필요하다.

   | 폴더 | 언제 |
   | --- | --- |
   | `Sources/`, `Tests/` | 항상 |
   | `Interface/Sources/` | feature |
   | `Resources/` | `hasResources: true` |
   | `Testing/Sources/` | `hasTestingSupport: true` |
   | `Demo/Sources/` (`@main` 포함) | `hasDemoApp: true` |
   | `README.md` 등 `*.md`, `docs/` | 선택. 있으면 빌드와 무관하게 Xcode 탐색기에 자동으로 보인다 |

4. `enforceExplicitDependencies` 가 켜져 있으므로 import 하는 모듈은 해당 타깃의
   `*Dependencies` 에 모두 적는다. 빠지면 `tuist generate` 가 실패한다.

## 새 앱으로 복제할 때 바꿀 곳

- `Tuist/ProjectDescriptionHelpers/AppConstants.swift`: `appName`, `bundleIDPrefix`, `organizationName`
- `.claude/scripts/xcbuild.sh`: `SCHEME` 과 `PROJECT_FLAGS` 를 `<appName>-Workspace`, `<appName>.xcworkspace` 로
- `App/Tests/`: `@testable import TuistApp` 의 모듈 이름
- `CLAUDE.md`: 개요의 앱 이름
- `.github/workflows/ci.yml`: 바꿀 곳 없음. 스킴·워크스페이스 이름은 `xcbuild.sh` 에서 읽는다.

앱 표시 이름(`APP_DISPLAY_NAME`)은 xcconfig 가 `$(APP_NAME)` 으로 `appName` 을 따라간다.

## 코드 스타일

- 포맷은 swiftformat(`.swiftformat`), 린트는 SwiftLint(`.swiftlint.yml`)가 기준이다.
  둘이 겹치는 규칙(trailing comma, 수식어 순서)은 swiftformat 이 맡는다.
- 저장소는 항상 `swiftformat .` 을 돌린 상태를 유지한다. 규칙을 바꾸면 전체를 다시 포맷해서 별도 커밋으로 남긴다.

## 문제 해결

**`tuist generate` 가 실패한다** — `enforceExplicitDependencies` 가 켜져 있다.
import 하는 모듈이 해당 타깃의 `*Dependencies` 에 빠져 있으면 생성 단계에서 막는다.
에러 메시지가 어느 타깃의 어느 의존성인지 알려준다.

**Xcode 에서 정의 이동이 안 된다** — `buildServer.json` 이 없거나 낡았다.
위 "처음 실행" 의 `xcode-build-server config` 를 다시 실행한 뒤 한 번 빌드한다.

**앱은 빌드되는데 데모 타깃이 깨져 있다** — `TuistApp` 스킴은 앱과 그 의존성만 빌드해서
`HomeDemo` · `DesignSystemDemo` 의 컴파일 에러를 놓친다. `TuistApp-Workspace` 는 데모까지
포함하므로, 커밋 전 검증은 이 스킴으로 한다(`.claude/scripts/xcbuild.sh` 가 쓰는 스킴이다).

Claude Code 쪽 문제(훅이 안 돈다, LSP 가 붙지 않는다 등)는
[.claude/README.md](.claude/README.md) 의 "문제 해결" 을 본다.
