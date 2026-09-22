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
///      │      └───→ Networking ──→ OpenAPIRuntime, OpenAPIURLSession, HTTPTypes (외부)
///      ├──→ Domain, DesignSystem, Navigation, Networking
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
        }
    }

    public var path: ProjectDescription.Path {
        switch self {
        case let .feature(name), let .featureInterface(name):
            .relativeToRoot("Modules/Features/\(name)")
        case .domain, .data, .designSystem, .networking, .navigation:
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
