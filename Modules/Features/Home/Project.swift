//
//  Project.swift
//  TuistAppManifests
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.feature(
    name: "Home",
    interfaceDependencies: [
        .module(.domain),
        .module(.navigation),
    ],
    dependencies: [
        .module(.domain),
        .module(.designSystem),
        .module(.navigation),
//        // Transfer 로 이동하려면 Transfer 의 "구현"이 아니라 Interface 의 Route 만 참조한다.
//        // 덕분에 Home <-> Transfer 순환이 생기지 않고,
//        // Transfer 구현이 바뀌어도 Home 은 재빌드되지 않는다.
//        .module(.featureInterface("Transfer")),
    ],
    testDependencies: [
        .module(.domain),
        .testing(.domain),
        .testing(.navigation),
//        // Transfer 쪽 목은 Testing 모듈에서 가져온다. 복붙하지 않는다.
//        .testing(.feature("Transfer")),
    ],
    hasResources: true,
    hasDemoApp: true,
    demoDependencies: [
        .module(.domain),
        .testing(.domain),
        .module(.designSystem),
        .module(.navigation),
    ]
)
