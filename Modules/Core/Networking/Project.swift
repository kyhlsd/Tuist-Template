//
//  Project.swift
//  TuistAppManifests
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// OpenAPI 생성 클라이언트, 미들웨어. 토큰 모델·저장소는 Auth 에 있다.
/// 생성물은 `Scripts/openapi-generate.sh` 로 만든다(README 참고).
///
/// NetworkingTesting 에는 `RecordingNetworkActivityObserver` 를 둔다. `InMemoryTokenStore` 는 AuthTesting 에 있다.
let project = Project.core(
    name: "Networking",
    dependencies: [
        .external(name: "OpenAPIRuntime"),
        .external(name: "OpenAPIURLSession"),
        .external(name: "HTTPTypes"),
        .module(.auth),
    ],
    testDependencies: [
        .external(name: "OpenAPIRuntime"), // 미들웨어 테스트가 HTTPBody 를 만든다
        .external(name: "HTTPTypes"),
        .module(.auth),
        .testing(.auth),
    ],
    hasTestingSupport: true
)
