//
//  Project.swift
//  TuistAppManifests
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 앱은 조립만 한다. (App/Sources/DI: 의존성, App/Sources/Navigation: 탭·Route → 화면)
/// 피처는 구현과 Interface 를 모두 연결한다. 구현은 루트 화면을, Interface 는 Route 를 제공한다.
let project = Project.app(
    name: AppConstants.appName,
    dependencies: [
        .module(.feature("Home")),
        .module(.featureInterface("Home")),
        .module(.data),
        .module(.domain),
        .module(.networking),
        .module(.designSystem),
        .module(.navigation),
    ]
)
