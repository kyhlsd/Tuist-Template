//
//  Project+Templates.swift
//  ProjectDescriptionHelpers
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription

public extension Project {
    /// Feature 모듈.
    ///
    /// 한 프로젝트 안에 최대 다섯 타깃을 만든다. 뒤의 둘은 선택이다.
    ///
    ///   {name}Interface  다른 피처에 노출하는 표면. Route, 진입점 타입만.
    ///   {name}           실제 구현. Interface 에 의존한다.
    ///   {name}Tests      단위 테스트.
    ///   {name}Testing    (선택) Interface 의 목/픽스처. 다른 피처의 테스트·데모가 쓴다.
    ///   {name}Demo       (선택) 이 피처만 띄워보는 실행 가능한 앱.
    ///
    /// 피처 간 순환 의존을 끊는 것이 목적이다. Home 이 Transfer 를 쓰더라도
    /// `TransferInterface` 타깃만 참조하므로, Transfer 구현이 바뀌어도
    /// Home 은 재빌드되지 않는다.
    ///
    /// `*Dependencies` 는 enforceExplicitDependencies 때문에 각 타깃이 import 하는
    /// 모듈을 모두 적어야 한다. 템플릿이 자동으로 넣는 것은 같은 프로젝트 안의
    /// 타깃뿐이다. (구현 → Interface, Tests·Demo → 구현·Interface)
    /// 자기 {name}Testing 은 자동으로 연결하지 않는다. 테스트·데모가 import 할 때만
    /// `testDependencies`/`demoDependencies` 에 `.testing(.feature(name))` 로 적는다.
    /// import 하지 않는데 연결하면 `tuist inspect dependencies` 가 중복 의존으로 잡는다.
    static func feature(
        name: String,
        interfaceDependencies: [TargetDependency] = [],
        dependencies: [TargetDependency] = [],
        testDependencies: [TargetDependency] = [],
        hasResources: Bool = false,
        hasTestingSupport: Bool = false,
        testingDependencies: [TargetDependency] = [],
        hasDemoApp: Bool = false,
        demoDependencies: [TargetDependency] = [],
        hasSnapshotTests: Bool = false
    ) -> Project {
        Module.validateRegistration(name: name, hasDemoApp: hasDemoApp)
        let interfaceName = "\(name)Interface"

        Module.validateFeatureDependencies(
            name: name,
            interface: interfaceDependencies,
            implementation: dependencies,
            support: testDependencies + demoDependencies,
            testing: testingDependencies
        )

        var targets: [Target] = [
            .module(
                name: interfaceName,
                sources: ["Interface/Sources/**"],
                dependencies: interfaceDependencies
            ),
            .module(
                name: name,
                sources: ["Sources/**"],
                resources: hasResources ? ["Resources/**"] : nil,
                dependencies: dependencies + [.target(name: interfaceName)]
            ),
        ]

        if hasTestingSupport {
            targets.append(
                .testingSupport(
                    for: name,
                    dependencies: testingDependencies + [.target(name: interfaceName)]
                )
            )
        }

        // 테스트와 데모는 이 피처의 Route(Interface)를 다루므로 함께 연결한다.
        let localSupport: [TargetDependency] = [.target(name: interfaceName)]

        targets.append(
            .testTarget(
                for: name,
                dependencies: testDependencies + localSupport,
                hasSnapshotTests: hasSnapshotTests
            )
        )

        if hasDemoApp {
            targets.append(
                .demoApp(for: name, dependencies: demoDependencies + localSupport)
            )
        }

        return Project(
            name: name,
            organizationName: AppConstants.organizationName,
            settings: .common,
            targets: targets,
            additionalFiles: documentationFiles
        )
    }

    /// Core 계층 모듈 (Domain, Data, DesignSystem, Networking).
    ///
    ///   {name}           실제 구현.
    ///   {name}Tests      단위 테스트.
    ///   {name}Testing    (선택) 이 모듈의 목/스텁. 다른 모듈의 테스트·데모가 쓴다.
    ///                    예: DomainTesting 의 Repository 스텁을 DataTests,
    ///                    HomeTests, HomeDemo 가 함께 쓴다. 복붙하지 않는다.
    ///   {name}Demo       (선택) 이 모듈만 띄워보는 실행 가능한 앱.
    ///
    /// isMainActorByDefault 는 모듈의 모든 타깃(구현, 테스트, 데모)에 적용된다.
    /// `Settings.mainActorByDefault` 참고.
    ///
    /// hasSnapshotTests 는 `Tests/__Snapshots__/*.png` 를 테스트 번들 리소스로 넣는다.
    /// (`Target.testTarget` 참고)
    ///
    /// 자기 {name}Testing 은 테스트·데모에 자동으로 연결하지 않는다. import 할 때만
    /// `testDependencies`/`demoDependencies` 에 `.testing(...)` 로 적는다(예: Domain 의 `.testing(.domain)`).
    /// import 하지 않는데 연결하면 `tuist inspect dependencies` 가 중복 의존으로 잡는다.
    static func core(
        name: String,
        dependencies: [TargetDependency] = [],
        testDependencies: [TargetDependency] = [],
        hasResources: Bool = false,
        hasTestingSupport: Bool = false,
        testingDependencies: [TargetDependency] = [],
        hasDemoApp: Bool = false,
        demoDependencies: [TargetDependency] = [],
        isMainActorByDefault: Bool = false,
        hasSnapshotTests: Bool = false
    ) -> Project {
        Module.validateRegistration(name: name, hasDemoApp: hasDemoApp)

        guard let module = Module.all.first(where: { $0.name == name }) else {
            preconditionFailure("validateRegistration 이 \(name) 의 등록을 보장한다.")
        }
        Module.validateModuleDependencies(
            of: module,
            dependencies: dependencies,
            supportDependencies: testDependencies + demoDependencies,
            testingDependencies: testingDependencies
        )
        var targets: [Target] = [
            .module(
                name: name,
                sources: ["Sources/**"],
                resources: hasResources ? ["Resources/**"] : nil,
                dependencies: dependencies
            ),
            .testTarget(
                for: name,
                dependencies: testDependencies,
                hasSnapshotTests: hasSnapshotTests
            ),
        ]

        if hasTestingSupport {
            targets.append(
                .testingSupport(
                    for: name,
                    dependencies: testingDependencies + [.target(name: name)]
                )
            )
        }

        if hasDemoApp {
            targets.append(.demoApp(for: name, dependencies: demoDependencies))
        }

        return Project(
            name: name,
            organizationName: AppConstants.organizationName,
            settings: isMainActorByDefault ? .mainActorByDefault : .common,
            targets: targets,
            additionalFiles: documentationFiles
        )
    }

    /// 앱 타깃. 번들 ID 접미사는 xcconfig 의 BUNDLE_ID_SUFFIX 에서 온다.
    ///
    /// - Parameters:
    ///   - targetSettings: 앱 타깃에만 적용할 빌드 설정. 공통 xcconfig 에 넣으면 모든 모듈로 퍼지는 값을 여기 둔다.
    ///   - scripts: 앱 타깃의 빌드 스크립트.
    ///   - additionalInfoPlist: 앱 타깃에만 넣을 Info.plist 키. 데모 앱에는 들어가지 않는다.
    ///   - entitlements: 앱 타깃의 엔타이틀먼트. 데모 앱에는 들어가지 않는다.
    ///     값에 `$(APS_ENVIRONMENT)` 처럼 빌드 설정을 쓰면 서명할 때 환경별 값으로 바뀐다.
    ///   - extensions: 앱에 포함할 앱 익스텐션. 앱이 의존하면 Tuist 가 앱 번들의 PlugIns 에 넣는다. `AppExtension` 참고.
    ///
    /// Tuist 가 만드는 앱 스킴(`name`)은 Debug 로 실행하고 Release 로 아카이브한다.
    /// Staging 으로 실행·아카이브하는 스킴(`"\(name)-Staging"`)은 여기서 따로 만든다.
    static func app(
        name: String,
        dependencies: [TargetDependency] = [],
        testDependencies: [TargetDependency] = [],
        targetSettings: SettingsDictionary = [:],
        scripts: [TargetScript] = [],
        additionalInfoPlist: [String: Plist.Value] = [:],
        entitlements: Entitlements? = nil,
        extensions: [AppExtension] = []
    ) -> Project {
        // 테스트 타깃(testDependencies)은 제한하지 않는다.
        Module.validateAppDependencies(dependencies, targetName: name)
        for appExtension in extensions {
            Module.validateAppDependencies(appExtension.dependencies, targetName: appExtension.name)
        }
        let extensionTargets = extensions.map { $0.target(appName: name) }
        return Project(
            name: name,
            organizationName: AppConstants.organizationName,
            settings: .common,
            targets: [
                .target(
                    name: name,
                    destinations: AppConstants.destinations,
                    product: .app,
                    bundleId: "\(AppConstants.bundleID(for: name))$(BUNDLE_ID_SUFFIX)",
                    deploymentTargets: AppConstants.deploymentTargets,
                    infoPlist: .runnable(urlSchemes: [AppConstants.urlScheme], additionalEntries: additionalInfoPlist),
                    sources: ["Sources/**"],
                    resources: ["Resources/**"],
                    entitlements: entitlements,
                    scripts: scripts,
                    dependencies: dependencies + extensions.map { .target(name: $0.name) },
                    settings: .settings(base: targetSettings)
                ),
                .testTarget(for: name, dependencies: testDependencies),
                .uiTestTarget(for: name),
            ] + extensionTargets,
            schemes: [.staging(app: name)],
            additionalFiles: documentationFiles
        )
    }
}

// MARK: - 스킴

private extension Scheme {
    /// 앱을 Staging 구성으로 실행·프로파일·아카이브하는 스킴. QA 배포용 아카이브는 이 스킴으로 만든다.
    ///
    /// 테스트 액션은 두지 않는다. 테스트는 Debug 로 워크스페이스 스킴에서 돈다(`Scheme.workspace()`).
    static func staging(app name: String) -> Scheme {
        let app = TargetReference.target(name)
        return .scheme(
            name: "\(name)-Staging",
            buildAction: .buildAction(targets: [app]),
            runAction: .runAction(configuration: .staging, executable: app),
            archiveAction: .archiveAction(configuration: .staging),
            profileAction: .profileAction(configuration: .staging, executable: app),
            analyzeAction: .analyzeAction(configuration: .staging)
        )
    }
}

// MARK: - 문서

private extension Project {
    /// 모듈 폴더의 문서. 빌드에는 쓰이지 않지만 Xcode 프로젝트 탐색기에 보이도록 넣는다.
    ///
    /// 모듈 바로 아래의 마크다운(README.md 등)과 `docs/` 폴더 전체.
    /// 해당 파일이 없는 모듈에서는 아무것도 추가되지 않는다.
    static let documentationFiles: [FileElement] = [
        "*.md",
        "docs/**",
    ]
}

// MARK: - Target

private extension Target {
    /// 라이브러리 성격의 타깃. 실행 가능한 타깃을 제외한 모든 모듈이 이 형태다.
    static func module(
        name: String,
        sources: SourceFilesList,
        resources: ResourceFileElements? = nil,
        dependencies: [TargetDependency]
    ) -> Target {
        .target(
            name: name,
            destinations: AppConstants.destinations,
            product: .staticFramework,
            bundleId: AppConstants.bundleID(for: name),
            deploymentTargets: AppConstants.deploymentTargets,
            sources: sources,
            resources: resources,
            dependencies: dependencies
        )
    }

    /// 목·스텁 타깃(`{name}Testing`).
    ///
    /// 다른 모듈의 테스트·데모가 import 하므로 테스트 번들이 아니라 일반 모듈이다.
    /// 앱과 구현 타깃은 이 타깃에 의존하지 않는다.
    static func testingSupport(
        for name: String,
        dependencies: [TargetDependency]
    ) -> Target {
        .module(
            name: "\(name)Testing",
            sources: ["Testing/Sources/**"],
            dependencies: dependencies
        )
    }

    /// 단위 테스트 타깃.
    ///
    /// product 는 .unitTests 그대로 두면 Swift Testing 이 동작한다.
    /// enforceExplicitDependencies 가 켜져 있으므로, 테스트에서 import 하는
    /// 모듈은 전부 dependencies 로 명시해야 한다. (예: Domain 픽스처)
    ///
    /// hasSnapshotTests 가 켜지면 스냅샷 기준 이미지를 테스트 번들에 복사한다.
    /// 테스트는 소스 경로가 아니라 번들에서 기준 이미지를 읽는다. 시뮬레이터 프로세스는
    /// 보호된 폴더(예: ~/Desktop, ~/Documents)에 있는 파일 중 자기가 만들지 않은 것을
    /// 읽지 못하므로, 저장소 위치에 따라 테스트 결과가 달라지는 것을 막기 위해서다.
    /// 스냅샷을 쓰지 않는 모듈에서 빈 glob 경고가 나지 않도록 선택으로 둔다.
    static func testTarget(
        for name: String,
        dependencies: [TargetDependency] = [],
        hasSnapshotTests: Bool = false
    ) -> Target {
        .target(
            name: "\(name)Tests",
            destinations: AppConstants.destinations,
            product: .unitTests,
            bundleId: AppConstants.bundleID(for: "\(name)Tests"),
            deploymentTargets: AppConstants.deploymentTargets,
            sources: ["Tests/**"],
            resources: hasSnapshotTests ? ["Tests/__Snapshots__/*.png"] : nil,
            dependencies: dependencies + [.target(name: name)]
        )
    }

    /// 앱의 UI 테스트 타깃(`{name}UITests`). 앱을 실제로 띄워 스모크 테스트만 둔다.
    ///
    /// 테스트는 앱 프로세스 밖에서 돌아 앱 코드를 import 할 수 없다. 그래서 앱과의 약속(launch argument,
    /// 접근성 식별자)을 담은 `UITestLaunchArgument.swift` 를 이 타깃도 함께 컴파일한다.
    /// 딥링크 스킴은 `rename.sh` 가 바꾸는 `AppConstants.urlScheme` 을 Info.plist 로 넘겨 테스트가 읽는다.
    static func uiTestTarget(for name: String) -> Target {
        .target(
            name: "\(name)UITests",
            destinations: AppConstants.destinations,
            product: .uiTests,
            bundleId: AppConstants.bundleID(for: "\(name)UITests"),
            deploymentTargets: AppConstants.deploymentTargets,
            infoPlist: .extendingDefault(with: [
                UITestInfoKey.appURLScheme: .string(AppConstants.urlScheme),
            ]),
            sources: ["UITests/**", "Sources/DI/UITestLaunchArgument.swift"],
            dependencies: [.target(name: name)]
        )
    }

    /// 모듈 하나만 띄워보는 데모 앱. feature, core 어느 모듈이든 가질 수 있다.
    ///
    /// 전체 앱을 빌드하지 않고 이 스킴만 실행하면 되므로 반복 속도가 크게 는다.
    /// 모듈화의 실질적 이득이 대부분 여기서 나온다.
    ///
    /// 대상 모듈에는 자동으로 의존한다. 데모가 주입할 목·스텁이 담긴 모듈
    /// (예: Domain, {name}Testing)은 enforceExplicitDependencies 때문에
    /// dependencies 로 명시해야 한다.
    static func demoApp(
        for name: String,
        dependencies: [TargetDependency] = []
    ) -> Target {
        .target(
            name: "\(name)Demo",
            destinations: AppConstants.destinations,
            product: .app,
            bundleId: "\(AppConstants.bundleID(for: name)).demo",
            deploymentTargets: AppConstants.deploymentTargets,
            infoPlist: .runnable(displayName: "\(name)Demo"),
            sources: ["Demo/Sources/**"],
            dependencies: dependencies + [.target(name: name)]
        )
    }
}

/// UI 테스트 타깃 Info.plist 의 키. 테스트 코드(`TuistAppSmokeUITests`)가 같은 문자열로 읽는다.
private enum UITestInfoKey {
    static let appURLScheme = "APP_URL_SCHEME"
}
