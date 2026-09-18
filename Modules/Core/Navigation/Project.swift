//
//  Project.swift
//  TuistAppManifests
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 화면 이동(push/pop) 상태를 다룬다. 어떤 Route 가 어떤 화면인지는 모른다.
/// 그 매핑은 App 이 한다.
///
/// NavigationTesting 의 SpyRouter 로 뷰모델의 이동 요청을 테스트한다.
let project = Project.core(
    name: "Navigation",
    hasTestingSupport: true,
    isMainActorByDefault: true
)
