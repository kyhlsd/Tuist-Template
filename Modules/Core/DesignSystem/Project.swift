//
//  Project.swift
//  TuistAppManifests
//
//  Created by 김영훈 on 9/15/26.
//

import ProjectDescription
import ProjectDescriptionHelpers

// hasResources: true 면 Resources/** 가 번들에 포함되고
// Tuist 가 타입 안전한 접근자를 합성해준다. (Bundle.module 기준)
//
// DesignSystemDemo 는 토큰·컴포넌트 카탈로그 앱이다. (Demo/Sources)
//
// 화면만 다루는 모듈이므로 기본 격리를 MainActor 로 둔다.
// 토큰(Theme.standard 등)의 static 프로퍼티가 이 전제로 작성되어 있다.
let project = Project.core(
    name: "DesignSystem",
    hasResources: true,
    hasDemoApp: true,
    isMainActorByDefault: true,
    // 기준 이미지는 테스트 번들에서 읽는다. (Target.testTarget 참고)
    hasSnapshotTests: true
)
