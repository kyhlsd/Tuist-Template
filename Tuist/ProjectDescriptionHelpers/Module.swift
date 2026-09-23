//
//  Module.swift
//  ProjectDescriptionHelpers
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription

/// 프로젝트의 모듈 목록.
///
/// 의존성을 문자열로 적지 않기 위한 타입. 새 모듈을 추가하면 case 를 더하고,
/// 경로 규칙은 `path` 한 곳에서만 관리한다.
///
/// 의존 방향은 항상 아래로만 흐른다.
///
///     App ──→ Feature ──→ FeatureInterface ──→ Domain
///      │         │                 └──────→ Navigation (Route 프로토콜)
///      │         ├──────→ Domain
///      │         ├──────→ DesignSystem
///      │         └──────→ Navigation
///      ├──→ FeatureInterface   (Route 를 화면으로 바꾸기 위해)
///      ├──→ Data ──→ Domain
///      │      ├───→ Diagnostics
///      │      └───→ Networking ──→ OpenAPIRuntime, OpenAPIURLSession, HTTPTypes (외부)
///      ├──→ Domain, DesignSystem, Navigation, Networking, Diagnostics
///
/// Feature 는 Data 나 Networking 을 모른다. Domain 의 프로토콜만 알고,
/// 실제 구현을 꽂아주는 것은 App 의 역할이다.
///
/// 화면 이동도 같다. Feature 는 이동할 곳의 Route(다른 피처라면 그 Interface 의 값)를
/// `Routing` 에 push 할 뿐이고, Route 를 실제 화면으로 바꾸는 것은 App 이다.
///
/// `{name}Testing` 은 그 모듈의 목·스텁이다. 테스트와 데모 타깃만 의존하며,
/// `.testing(_:)` 으로 참조한다. 앱과 구현 타깃은 절대 의존하지 않는다.
///
/// 앱은 모듈이 아니므로 여기에 없다. 앱에 의존하는 모듈은 존재할 수 없다.
///
/// 이 규칙은 `mayDepend(on:)` 이 generate 시점에 강제한다. 위 그림과 어긋나면 코드가 기준이다.
public enum Module: Sendable {
    // MARK: Feature

    /// 화면 구현. 다른 피처는 이 타깃을 참조하지 않는다.
    case feature(String)
    /// 다른 피처에 노출하는 최소 표면. Route, 진입점 타입 선언만 담는다.
    case featureInterface(String)

    // MARK: Core

    /// 엔티티, UseCase, Repository 프로토콜. Foundation 외에는 import 하지 않는다.
    case domain
    /// Repository 구현, DTO, 영속성. Domain 의 프로토콜을 구현한다.
    case data
    case designSystem
    /// OpenAPI 생성 클라이언트, 미들웨어(로그·재시도·인증), 토큰 저장소.
    case networking
    /// 이동 요청 창구(`Routing`), push 가능한 값의 마커(`Route`), 데모용 단독 `Router`.
    /// FeatureInterface 도 `Route` 를 채택하기 위해 의존한다.
    case navigation
    /// 진단 타입, 중복 억제 보고기, 기본 로그 싱크. Foundation 과 os 외에는 import 하지 않는다.
    /// 전송 수단(Crashlytics 등)은 App 이 싱크로 꽂는다.
    case diagnostics
    /// 이름으로 가리키는 Core 모듈(`Modules/Core/<name>`).
    ///
    /// 새 Core 모듈은 이 case 로 추가한다(`Scripts/new-module.sh core <Name>`).
    /// 다른 모듈이 의존하게 되면 `mayDepend(on:)` 에 `(.feature, .core("<Name>"))` 같은 허용 규칙을 더한다.
    /// 이 모듈이 다른 모듈에 의존할 때도(테스트·데모의 `.testing(_:)` 포함) `(.core("<Name>"), .domain)` 같은 규칙이 필요하다.
    /// 규칙이 없으면 generate 가 문구 없이 멈춘다(Tuist 가 `fatalError` 문구를 보여 주지 않는다).
    /// 기존 모듈은 위의 이름 있는 case 를 유지한다.
    case core(String)

    public var name: String {
        switch self {
        case let .feature(name):
            name
        case let .featureInterface(name):
            "\(name)Interface"
        case .domain:
            "Domain"
        case .data:
            "Data"
        case .designSystem:
            "DesignSystem"
        case .networking:
            "Networking"
        case .navigation:
            "Navigation"
        case .diagnostics:
            "Diagnostics"
        case let .core(name):
            name
        }
    }

    public var path: ProjectDescription.Path {
        switch self {
        case let .feature(name), let .featureInterface(name):
            .relativeToRoot("Modules/Features/\(name)")
        case .domain, .data, .designSystem, .networking, .navigation, .diagnostics, .core:
            .relativeToRoot("Modules/Core/\(name)")
        }
    }
}

public extension TargetDependency {
    /// 모듈 간 의존성. 문자열 하드코딩을 대신한다.
    static func module(_ module: Module) -> TargetDependency {
        .project(target: module.name, path: module.path)
    }

    /// 모듈의 테스트 지원 타깃(`{name}Testing`). 테스트·데모 타깃에서만 쓴다.
    ///
    /// 피처는 `.feature(_:)` 로 넘긴다. (`.testing(.feature("Home"))` → HomeTesting)
    /// 해당 모듈이 `hasTestingSupport: true` 여야 생성 시점에 타깃이 존재한다.
    static func testing(_ module: Module) -> TargetDependency {
        .project(target: "\(module.name)Testing", path: module.path)
    }
}

// MARK: - 등록부

public extension Module {
    /// 워크스페이스 스킴이 빌드·테스트하는 모듈 전체. 새 모듈 프로젝트를 만들면 여기에 더한다.
    ///
    /// 피처는 `.feature(_:)` 하나로 프로젝트 전체(Interface, Testing, Demo 포함)를 가리킨다.
    /// 빠뜨리면 `Project.core`/`Project.feature` 가 생성 단계에서 멈춘다.
    static let all: [Module] = [
        .domain,
        .data,
        .designSystem,
        .networking,
        .navigation,
        .diagnostics,
        .feature("Home"),
        // new-module.sh 가 이 줄 위에 추가한다. 지우거나 옮기지 않는다.
    ]

    /// 데모 앱(`{name}Demo`)을 가진 모듈. 모듈 매니페스트의 `hasDemoApp` 과 같아야 한다.
    ///
    /// 워크스페이스 스킴이 데모 앱도 빌드하도록 여기서 목록을 읽는다.
    /// 둘이 어긋나면 `Project.core`/`Project.feature` 가 생성 단계에서 멈춘다.
    static let withDemoApp: [Module] = [
        .designSystem,
        .feature("Home"),
        // new-module.sh 가 이 줄 위에 추가한다(데모 앱). 지우거나 옮기지 않는다.
    ]

    /// 모듈 매니페스트의 선언이 등록부와 맞는지 확인한다. 어긋나면 생성을 멈춘다.
    ///
    /// 등록부에 없는 모듈은 워크스페이스 스킴에서 빠져 빌드·테스트되지 않는다. 조용히 빠지는 것을 막는다.
    internal static func validateRegistration(name: String, hasDemoApp: Bool) {
        guard all.contains(where: { $0.name == name }) else {
            fatalError("\(name) 모듈이 Module.all 에 없습니다. Tuist/ProjectDescriptionHelpers/Module.swift 에 추가하세요.")
        }
        let registeredDemo = withDemoApp.contains { $0.name == name }
        guard registeredDemo == hasDemoApp else {
            fatalError(
                "\(name) 의 hasDemoApp(\(hasDemoApp))이 Module.withDemoApp 과 다릅니다. "
                    + "Tuist/ProjectDescriptionHelpers/Module.swift 를 함께 고치세요."
            )
        }
    }
}

// MARK: - 의존 규칙

public extension Module {
    /// 이 모듈의 구현 타깃이 `other` 에 의존해도 되는지. 나열하지 않은 조합은 모두 금지다.
    ///
    /// 테스트·Testing·데모 타깃은 여기서 허용한 모듈과 그 모듈들의 `*Testing` 에 의존할 수 있다.
    ///
    /// 위반하면 generate 가 멈추지만 Tuist(4.208.0)는 매니페스트의 stderr 를 버려서
    /// `fatalError` 문구가 보이지 않고, 실패한 `Project.swift` 경로만 나온다.
    /// 문구는 Tuist 오류에 찍힌 `xcrun swift ... Project.swift --tuist-dump` 명령을 그대로 실행하면 보인다.
    func mayDepend(on other: Module) -> Bool {
        switch (self, other) {
        case (.feature, .featureInterface),
             (.feature, .domain),
             (.feature, .designSystem),
             (.feature, .navigation):
            true
        case (.featureInterface, .domain),
             (.featureInterface, .navigation):
            true
        case (.data, .domain),
             (.data, .diagnostics),
             (.data, .networking):
            true
        default:
            false
        }
    }
}

extension Module {
    /// 타깃이 모듈 규칙상 맡는 역할.
    enum DependencyRole {
        /// 모듈 구현과 Interface. `*Testing` 에 의존할 수 없다.
        case implementation
        /// 테스트, Testing, 데모 타깃. 허용된 모듈의 `*Testing` 에도 의존할 수 있다.
        case support
    }

    /// `.project` 의존의 대상 이름을 등록부의 모듈로 되돌린다. 등록부 밖이면 `nil`.
    ///
    /// 피처의 `{name}Testing` 은 Interface 의 목이고 Interface 에만 의존하므로
    /// `.featureInterface(name)` 의 Testing 으로 본다. 그래야 다른 피처의 테스트·데모가 쓸 수 있다.
    static func resolve(target: String) -> (module: Module, isTesting: Bool)? {
        for module in all {
            switch module {
            case let .feature(name):
                let interface = Module.featureInterface(name)
                if target == module.name {
                    return (module, false)
                }
                if target == interface.name {
                    return (interface, false)
                }
                if target == "\(module.name)Testing" {
                    return (interface, true)
                }
            default:
                if target == module.name {
                    return (module, false)
                }
                if target == "\(module.name)Testing" {
                    return (module, true)
                }
            }
        }
        return nil
    }

    /// 모듈 타깃의 모듈 간 의존이 `mayDepend(on:)` 을 따르는지 확인한다. 어긋나면 생성을 멈춘다.
    ///
    /// `.project` 만 검사한다. 같은 프로젝트 안의 `.target`, `.external`, `.sdk` 는 대상이 아니다.
    static func validateDependencies(
        of owner: Module,
        role: DependencyRole,
        targetName: String,
        dependencies: [TargetDependency]
    ) {
        for dependency in dependencies {
            guard case let .project(target, _, _, _) = dependency else { continue }
            guard let resolved = resolve(target: target) else {
                fatalError("\(ErrorText.prefix)\(targetName) → \(target): Module.all 에 없는 모듈입니다. \(ErrorText.ruleLocation)")
            }
            if role == .implementation, resolved.isTesting {
                fatalError(
                    "\(ErrorText.prefix)\(targetName) → \(target): 구현 타깃은 *Testing 에 의존할 수 없습니다. "
                        + "테스트·데모 타깃의 의존성으로 옮기세요."
                )
            }
            guard owner.mayDepend(on: resolved.module) else {
                fatalError("\(ErrorText.prefix)\(targetName) → \(target) 의존은 허용되지 않습니다. \(ErrorText.ruleLocation)")
            }
        }
    }

    /// 모듈 구현 타깃과 지원 타깃(테스트, Testing, 데모)을 함께 검사한다.
    static func validateModuleDependencies(
        of owner: Module,
        dependencies: [TargetDependency],
        supportDependencies: [TargetDependency]
    ) {
        validateDependencies(of: owner, role: .implementation, targetName: owner.name, dependencies: dependencies)
        validateDependencies(
            of: owner,
            role: .support,
            targetName: "\(owner.name)Tests/Testing/Demo",
            dependencies: supportDependencies
        )
    }

    /// 피처의 Interface, 구현, 지원 타깃을 함께 검사한다.
    static func validateFeatureDependencies(
        name: String,
        interface interfaceDependencies: [TargetDependency],
        implementation dependencies: [TargetDependency],
        support supportDependencies: [TargetDependency]
    ) {
        let interface = Module.featureInterface(name)
        validateDependencies(
            of: interface,
            role: .implementation,
            targetName: interface.name,
            dependencies: interfaceDependencies
        )
        validateModuleDependencies(
            of: .feature(name),
            dependencies: dependencies,
            supportDependencies: supportDependencies
        )
    }

    /// 앱 본 타깃은 어떤 모듈이든 의존할 수 있지만 `*Testing` 에는 의존할 수 없다.
    static func validateAppDependencies(_ dependencies: [TargetDependency], targetName: String) {
        for dependency in dependencies {
            guard case let .project(target, _, _, _) = dependency else { continue }
            if resolve(target: target)?.isTesting == true {
                fatalError(
                    "\(ErrorText.prefix)\(targetName) → \(target): 앱은 *Testing 에 의존할 수 없습니다. "
                        + "앱 테스트 타깃의 의존성으로 옮기세요."
                )
            }
        }
    }
}

private enum ErrorText {
    static let prefix = "[의존 규칙] "
    static let ruleLocation = "규칙은 Tuist/ProjectDescriptionHelpers/Module.swift 의 mayDepend(on:) 에 있습니다."
}
