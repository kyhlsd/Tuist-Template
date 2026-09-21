//
//  Project.swift
//  TuistAppManifests
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 화면 이동 요청 창구(`Routing`)와 push 가능한 값의 마커(`Route`)를 둔다.
/// 어떤 Route 가 어떤 화면인지는 모른다. 그 매핑과 앱 전체 라우터(`AppRouter`)는 App 이 가진다.
/// 여기의 `Router` 는 피처 데모 앱·프리뷰용 단독 구현이다.
///
/// NavigationTesting 의 SpyRouter 로 뷰모델의 이동 요청을 테스트한다.
let project = Project.core(
    name: "Navigation",
    hasTestingSupport: true,
    isMainActorByDefault: true
)
