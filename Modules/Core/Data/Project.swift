//
//  Project.swift
//  TuistAppManifests
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// Domain 의 Repository 프로토콜을 구현한다.
/// Feature 는 이 모듈을 모른다. 연결은 App 이 한다.
let project = Project.core(
    name: "Data",
    dependencies: [
        .module(.domain),
        .module(.diagnostics),
        .module(.networking),
    ],
    testDependencies: [
        .module(.domain),
        .module(.networking), // 테스트 안의 APIProtocol 스텁
        .module(.diagnostics), // 테스트가 DiagnosticFailure 를 직접 만든다
        .testing(.diagnostics), // 보고를 기록하는 SpyDiagnosticReporter
        .external(name: "OpenAPIRuntime"), // 스텁이 만드는 UndocumentedPayload
    ]
)
