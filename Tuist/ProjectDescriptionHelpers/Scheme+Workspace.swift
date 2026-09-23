//
//  Scheme+Workspace.swift
//  ProjectDescriptionHelpers
//

import ProjectDescription

public extension Scheme {
    /// 워크스페이스 전체를 빌드·테스트하는 스킴(`"\(appName)-Workspace"`). `.claude/scripts/xcbuild.sh` 가 쓴다.
    ///
    /// Tuist 가 자동으로 만드는 워크스페이스 스킴은 테스트 타깃과 외부 패키지 타깃까지 빌드 액션에 넣는다.
    /// 그러면 Release 빌드에서도 테스트 타깃이 컴파일되고, Release 는 `ENABLE_TESTABILITY = NO` 라
    /// `@testable import` 에서 실패한다. 그래서 자동 생성을 끄고 직접 정의한다(`Workspace.swift`).
    ///
    ///   빌드 액션   앱, 모든 모듈 구현 타깃, 데모 앱. 외부 패키지는 필요한 만큼 암시적으로 빌드된다.
    ///   테스트 액션 앱과 모든 모듈의 테스트 타깃. 테스트할 때만 빌드된다.
    ///   커버리지 대상 앱과 모듈 구현 타깃. 수집은 CI 가 `-enableCodeCoverage YES` 로 켠다.
    ///
    /// 모듈 목록은 `Module.all` / `Module.withDemoApp` 에서 읽는다.
    ///
    /// - Important: 배포용 아카이브는 앱 스킴(`AppConstants.appName`)으로 만든다. 빌드 액션의 대상은 모두 아카이브
    ///   대상으로도 표시되므로, 이 스킴으로 Archive 하면 데모 앱까지 묶여 "Generic Xcode Archive" 가 되고 배포할 수 없다.
    static func workspace() -> Scheme {
        let app = TargetReference.project(path: appPath, target: AppConstants.appName)
        let modules = Module.all.map { TargetReference.project(path: $0.path, target: $0.name) }
        let demoApps = Module.withDemoApp.map { TargetReference.project(path: $0.path, target: "\($0.name)Demo") }
        let tests = [TargetReference.project(path: appPath, target: "\(AppConstants.appName)Tests")]
            + Module.all.map { TargetReference.project(path: $0.path, target: "\($0.name)Tests") }

        return .scheme(
            name: "\(AppConstants.appName)-Workspace",
            buildAction: .buildAction(targets: [app] + modules + demoApps),
            testAction: .targets(
                tests.map { .testableTarget(target: $0) },
                options: .options(coverage: false, codeCoverageTargets: [app] + modules)
            ),
            runAction: .runAction(executable: app),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(executable: app),
            analyzeAction: .analyzeAction(configuration: .debug)
        )
    }
}

private let appPath: Path = .relativeToRoot("App")
