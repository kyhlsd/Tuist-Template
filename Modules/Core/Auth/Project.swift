//
//  Project.swift
//  TuistAppManifests
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 토큰 모델(`AuthTokens`), 저장소(`TokenStore`, `KeychainTokenStore`)와 그 에러.
/// Foundation, Security, os 외에는 import 하지 않는다. API 명세·생성 클라이언트와 엮인 코드
/// (미들웨어, operationId, refresh 호출)는 Networking 에 둔다.
///
/// AuthTesting 에는 `InMemoryTokenStore`, `FailingTokenStore` 를 둔다. Networking 과 Data 테스트가 재사용한다.
///
/// AuthDemo 는 실제 Keychain 에 토큰을 저장·삭제하고 `AuthSession.states()` 전이를 화면에서 보는 앱이다.
let project = Project.core(
    name: "Auth",
    testDependencies: [
        .testing(.auth), // 테스트가 자기 픽스처·대역을 쓴다
    ],
    hasTestingSupport: true,
    hasDemoApp: true,
    demoDependencies: [
        .testing(.auth), // 저장소 선택기가 InMemory·Failing 저장소로 바꿔 끼운다
    ]
)
